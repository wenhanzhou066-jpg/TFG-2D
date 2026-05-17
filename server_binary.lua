#!/usr/bin/env lua
--[[
Servidor UDP con protocolo binario para Tank Game
Versión Lua usando LuaSocket
Soporta: posiciones, HP, balas, lobbies/rooms
]]

local socket = require("socket")
local binary_protocol = require("binary_protocol")

local HOST = "*"  -- Todas las interfaces
local PORT = 12345

-- Room/Lobby de juego
local Room = {}
Room.__index = Room

function Room.new(room_id, metadata)
    local self = setmetatable({}, Room)
    self.room_id = room_id
    self.clients = {}  -- {addr_key = player_id}
    self.players = {}  -- {player_id = {x, y, angle, hp, last_seen}}
    self.profiles = {}  -- {player_id = {gamertag, color_body_*, color_turret_*, color_ammo_*, weapon_idx}}
    self.next_player_id = 1
    self.metadata = metadata or {game_mode = "ffa", max_players = 8}
    return self
end

function Room:add_client(addr_key)
    if not self.clients[addr_key] then
        local player_id = self.next_player_id
        self.next_player_id = self.next_player_id + 1
        self.clients[addr_key] = player_id
        self.players[player_id] = {
            x = 960, y = 540, angle = 0, hp = 100,
            last_seen = socket.gettime()
        }
        return player_id
    end
    return self.clients[addr_key]
end

function Room:remove_client(addr_key)
    if self.clients[addr_key] then
        local player_id = self.clients[addr_key]
        self.clients[addr_key] = nil
        self.players[player_id] = nil
        self.profiles[player_id] = nil
    end
end

function Room:update_player(addr_key, x, y, angle, hp)
    if self.clients[addr_key] then
        local player_id = self.clients[addr_key]
        self.players[player_id] = {
            x = x, y = y, angle = angle, hp = hp,
            last_seen = socket.gettime()
        }
    end
end

function Room:get_status()
    local count = 0
    for _ in pairs(self.clients) do count = count + 1 end

    local max_players = self.metadata.max_players or 8
    if count >= max_players then
        return "full"
    elseif count > 0 then
        return "playing"
    end
    return "waiting"
end

function Room:is_empty()
    for _ in pairs(self.clients) do
        return false
    end
    return true
end

-- Servidor principal
local GameServer = {}
GameServer.__index = GameServer

function GameServer.new()
    local self = setmetatable({}, GameServer)

    self.udp = socket.udp()
    self.udp:setsockname(HOST, PORT)
    self.udp:settimeout(0)  -- Sin bloqueo

    self.rooms = {}  -- {room_id = Room}
    self.addr_to_room = {}  -- {addr_key = room_id}

    print(string.format("[SERVER] Started on %s:%d", HOST == "*" and "0.0.0.0" or HOST, PORT))
    print("[SERVER] Binary protocol active")

    return self
end

function GameServer:addr_key(ip, port)
    return ip .. ":" .. port
end

function GameServer:run()
    while true do
        local data, ip, port = self.udp:receivefrom()

        if data then
            self:handle_message(data, ip, port)
        else
            -- Sin datos, esperar brevemente
            socket.sleep(0.001)
        end
    end
end

function GameServer:handle_message(data, ip, port)
    local addr_key = self:addr_key(ip, port)

    if #data < 1 then return end

    local msg_type = string.byte(data, 1)

    if msg_type == binary_protocol.MSG_CONNECT then
        self:handle_connect(data, ip, port, addr_key)
    elseif msg_type == binary_protocol.MSG_UPDATE then
        self:handle_update(data, ip, port, addr_key)
    elseif msg_type == binary_protocol.MSG_BULLET then
        self:handle_bullet(data, ip, port, addr_key)
    elseif msg_type == binary_protocol.MSG_DISCONNECT then
        self:handle_disconnect(addr_key)
    elseif msg_type == binary_protocol.MSG_LIST_ROOMS then
        self:handle_list_rooms(ip, port)
    elseif msg_type == binary_protocol.MSG_PROFILE then
        self:handle_profile(data, ip, port, addr_key)
    end
end

function GameServer:handle_connect(data, ip, port, addr_key)
    local success, msg = pcall(function()
        return binary_protocol.decode(data)
    end)

    if not success then
        print("[ERROR] Connect decode failed: " .. tostring(msg))
        return
    end

    local room_id = msg.room_id or "default"
    local metadata = msg.metadata

    -- Crear room si no existe
    if not self.rooms[room_id] then
        self.rooms[room_id] = Room.new(room_id, metadata)
        print(string.format("[ROOM] Created '%s' (mode: %s, max: %d)",
            room_id,
            metadata and metadata.game_mode or "default",
            metadata and metadata.max_players or 8))
    end

    local room = self.rooms[room_id]

    -- VERIFICAR: ¿Sala llena?
    local current_count = 0
    for _ in pairs(room.clients) do current_count = current_count + 1 end
    local max_players = room.metadata.max_players or 8

    if current_count >= max_players and not room.clients[addr_key] then
        print(string.format("[RECHAZAR] Sala '%s' llena (%d/%d) - rechazando %s:%d",
            room_id, current_count, max_players, ip, port))
        -- Enviar rechazo (el cliente manejará esto)
        return
    end

    local player_id = room:add_client(addr_key)
    self.addr_to_room[addr_key] = room_id

    -- Contar jugadores en sala
    local count = 0
    for _ in pairs(room.clients) do count = count + 1 end

    print(string.format("[CONNECT] Player %d joined room '%s' from %s:%d (total in room: %d/%d)",
        player_id, room_id, ip, port, count, max_players))

    -- Enviar welcome
    local response = binary_protocol.encode({
        type = "welcome",
        player_id = player_id,
        room_id = room_id
    })

    self.udp:sendto(response, ip, port)

    -- Reenviar perfiles ya conocidos al recién llegado
    for known_pid, prof in pairs(room.profiles) do
        if known_pid ~= player_id then
            local p_msg = binary_protocol.encode({
                type = "profile",
                player_id = known_pid,
                gamertag = prof.gamertag,
                color_body_r = prof.color_body_r, color_body_g = prof.color_body_g, color_body_b = prof.color_body_b,
                color_turret_r = prof.color_turret_r, color_turret_g = prof.color_turret_g, color_turret_b = prof.color_turret_b,
                color_ammo_r = prof.color_ammo_r, color_ammo_g = prof.color_ammo_g, color_ammo_b = prof.color_ammo_b,
                weapon_idx = prof.weapon_idx,
            })
            self.udp:sendto(p_msg, ip, port)
        end
    end

    -- Broadcast updated player list so existing clients see the new joiner immediately
    self:broadcast_state(room)
end

function GameServer:handle_profile(data, ip, port, addr_key)
    local success, msg = pcall(function() return binary_protocol.decode(data) end)
    if not success or not msg then return end

    local room_id = self.addr_to_room[addr_key]
    if not room_id then return end
    local room = self.rooms[room_id]
    if not room then return end

    local player_id = room.clients[addr_key]
    if not player_id then return end

    room.profiles[player_id] = {
        gamertag = msg.gamertag or "",
        color_body_r = msg.color_body_r, color_body_g = msg.color_body_g, color_body_b = msg.color_body_b,
        color_turret_r = msg.color_turret_r, color_turret_g = msg.color_turret_g, color_turret_b = msg.color_turret_b,
        color_ammo_r = msg.color_ammo_r, color_ammo_g = msg.color_ammo_g, color_ammo_b = msg.color_ammo_b,
        weapon_idx = msg.weapon_idx,
    }

    print(string.format("[PROFILE] Player %d -> '%s' (weapon %d)",
        player_id, room.profiles[player_id].gamertag, room.profiles[player_id].weapon_idx or 1))

    -- Reenviar a todos los otros clientes de la sala
    local out = binary_protocol.encode({
        type = "profile",
        player_id = player_id,
        gamertag = room.profiles[player_id].gamertag,
        color_body_r = room.profiles[player_id].color_body_r,
        color_body_g = room.profiles[player_id].color_body_g,
        color_body_b = room.profiles[player_id].color_body_b,
        color_turret_r = room.profiles[player_id].color_turret_r,
        color_turret_g = room.profiles[player_id].color_turret_g,
        color_turret_b = room.profiles[player_id].color_turret_b,
        color_ammo_r = room.profiles[player_id].color_ammo_r,
        color_ammo_g = room.profiles[player_id].color_ammo_g,
        color_ammo_b = room.profiles[player_id].color_ammo_b,
        weapon_idx = room.profiles[player_id].weapon_idx,
    })

    for other_addr, _ in pairs(room.clients) do
        if other_addr ~= addr_key then
            local oip, oport = other_addr:match("([^:]+):(%d+)")
            self.udp:sendto(out, oip, tonumber(oport))
        end
    end
end

function GameServer:handle_update(data, ip, port, addr_key)
    local success, msg = pcall(function()
        return binary_protocol.decode(data)
    end)

    if not success then
        print("[ERROR] Update decode failed: " .. tostring(msg))
        return
    end

    if self.addr_to_room[addr_key] then
        local room_id = self.addr_to_room[addr_key]
        local room = self.rooms[room_id]

        room:update_player(addr_key, msg.x, msg.y, msg.angle, msg.hp or 100)
        self:broadcast_state(room)
    end
end

function GameServer:handle_bullet(data, ip, port, addr_key)
    local success, msg = pcall(function()
        return binary_protocol.decode(data)
    end)

    if not success then
        print("[ERROR] Bullet decode failed: " .. tostring(msg))
        return
    end

    if self.addr_to_room[addr_key] then
        local room_id = self.addr_to_room[addr_key]
        local room = self.rooms[room_id]
        local player_id = room.clients[addr_key]

        -- Reenviar bala a otros jugadores en la sala
        local bullet_msg = binary_protocol.encode({
            type = "bullet",
            player_id = player_id,
            x = msg.x,
            y = msg.y,
            angle = msg.angle,
            bullet_type = msg.bullet_type
        })

        for other_addr_key, _ in pairs(room.clients) do
            if other_addr_key ~= addr_key then
                local other_ip, other_port = other_addr_key:match("([^:]+):(%d+)")
                other_port = tonumber(other_port)

                local sent, err = self.udp:sendto(bullet_msg, other_ip, other_port)
                if not sent and err then
                    -- Ignorar errores de envío
                end
            end
        end
    end
end

function GameServer:handle_disconnect(addr_key)
    if self.addr_to_room[addr_key] then
        local room_id = self.addr_to_room[addr_key]
        local room = self.rooms[room_id]
        local player_id = room.clients[addr_key]

        room:remove_client(addr_key)
        self.addr_to_room[addr_key] = nil

        print(string.format("[DISCONNECT] Player %d left room '%s'", player_id, room_id))

        -- Eliminar rooms vacías
        if room:is_empty() then
            self.rooms[room_id] = nil
            print(string.format("[ROOM] Deleted empty room '%s'", room_id))
        end
    end
end

function GameServer:handle_list_rooms(ip, port)
    local rooms_list = {}

    for room_id, room in pairs(self.rooms) do
        local player_count = 0
        for _ in pairs(room.clients) do
            player_count = player_count + 1
        end

        local status = room:get_status()

        table.insert(rooms_list, {
            room_id = room_id,
            game_mode = room.metadata.game_mode or "ffa",
            player_count = player_count,
            max_players = room.metadata.max_players or 8,
            status = status
        })
    end

    local response = binary_protocol.encode({
        type = "rooms_list",
        rooms = rooms_list
    })

    self.udp:sendto(response, ip, port)
end

function GameServer:broadcast_state(room)
    -- Construir estado del juego
    local players = {}

    for player_id, pdata in pairs(room.players) do
        players[tostring(player_id)] = {
            x = pdata.x,
            y = pdata.y,
            angle = pdata.angle,
            hp = pdata.hp
        }
    end

    local state_msg = binary_protocol.encode({
        type = "state",
        players = players
    })

    -- Enviar a todos los clientes en la sala
    for addr_key, _ in pairs(room.clients) do
        local client_ip, client_port = addr_key:match("([^:]+):(%d+)")
        client_port = tonumber(client_port)

        local sent, err = self.udp:sendto(state_msg, client_ip, client_port)
        if not sent and err then
            -- Ignorar errores de envío
        end
    end
end

-- Iniciar servidor
local server = GameServer.new()

print("[SERVER] Press Ctrl+C to stop")
print("[SERVER] Waiting for connections...")
print("[DEBUG] Rooms are ISOLATED - players only see others in same room_id")

local success, err = pcall(function()
    server:run()
end)

if not success then
    print("\n[SERVER] Error: " .. tostring(err))
    print("[SERVER] Shutting down...")
end
