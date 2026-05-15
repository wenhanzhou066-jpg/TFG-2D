-- binary_protocol.lua
-- Protocolo binario para comunicación cliente-servidor (3-5x más rápido que JSON)
-- Reduce lag significativamente mediante serialización eficiente

-- Operaciones bit a bit (compatible con Lua 5.1)
local bit = bit or bit32 or require("bit")

local BinaryProtocol = {}

-- Versión del protocolo
BinaryProtocol.VERSION = 2
BinaryProtocol.VERSION_BYTE = 0xF0  -- Centinela para mensajes v2

-- Tipos de mensaje (1 byte)
BinaryProtocol.MSG_CONNECT = 0x01
BinaryProtocol.MSG_WELCOME = 0x02
BinaryProtocol.MSG_UPDATE = 0x03
BinaryProtocol.MSG_STATE = 0x04
BinaryProtocol.MSG_BULLET = 0x05
BinaryProtocol.MSG_DISCONNECT = 0x06
BinaryProtocol.MSG_LIST_ROOMS = 0x07
BinaryProtocol.MSG_ROOMS_LIST = 0x08
BinaryProtocol.MSG_POWERUP_COLLECT = 0x09  -- Cliente → Servidor: solicitar recolección de powerup
BinaryProtocol.MSG_POWERUP_COLLECTED = 0x0A  -- Servidor → Clientes: powerup fue recogido
BinaryProtocol.MSG_POWERUP_SPAWN = 0x0B  -- Servidor → Clientes: powerup reapareció

-- Fase 2: Mensajes protocolo V2 (prefijados con VERSION_BYTE = 0xF0)
BinaryProtocol.MSG_INPUT = 0x10  -- Cliente → Servidor: estado de entrada
BinaryProtocol.MSG_SNAPSHOT = 0x11  -- Servidor → Clientes: snapshot del mundo

-- Fase 4: Mensajes de autoridad de balas
BinaryProtocol.MSG_FIRE_INTENT = 0x12  -- Cliente → Servidor: solicitud de disparo
BinaryProtocol.MSG_BULLET_SPAWN = 0x13  -- Servidor → Clientes: bala generada
BinaryProtocol.MSG_BULLET_DESPAWN = 0x14  -- Servidor → Clientes: bala eliminada
BinaryProtocol.MSG_HIT = 0x15  -- Servidor → Clientes: bala impactó tanque
BinaryProtocol.MSG_DEATH = 0x16  -- Servidor → Clientes: tanque murió
BinaryProtocol.MSG_RESPAWN = 0x17  -- Servidor → Clientes: tanque reapareció

-- Helpers para empaquetar/desempaquetar bytes
local function pack_byte(value)
    return string.char(value)
end

local function unpack_byte(data, offset)
    return string.byte(data, offset), offset + 1
end

local function pack_short(value)
    -- 2 bytes sin signo (0-65535)
    local b1 = math.floor(value / 256) % 256
    local b2 = value % 256
    return string.char(b1, b2)
end

local function unpack_short(data, offset)
    local b1, b2 = string.byte(data, offset, offset + 1)
    return b1 * 256 + b2, offset + 2
end

local function pack_float(value)
    -- Empaquetar float de 32 bits (IEEE 754)
    -- Simplificado: usar int16 para coordenadas (suficiente para 1920x1080)
    local scaled = math.floor(value)
    if scaled < -32768 then scaled = -32768 end
    if scaled > 32767 then scaled = 32767 end

    local unsigned = scaled >= 0 and scaled or (65536 + scaled)
    return pack_short(unsigned)
end

local function unpack_float(data, offset)
    local unsigned, new_offset = unpack_short(data, offset)
    local value = unsigned > 32767 and (unsigned - 65536) or unsigned
    return value, new_offset
end

local function pack_angle(angle)
    -- Ángulo en radianes, convertir a byte (0-255 = 0-2π)
    local normalized = (angle % (2 * math.pi)) / (2 * math.pi)
    local byte_val = math.floor(normalized * 255)
    return pack_byte(byte_val)
end

local function unpack_angle(data, offset)
    local byte_val, new_offset = unpack_byte(data, offset)
    local angle = (byte_val / 255) * (2 * math.pi)
    return angle, new_offset
end

local function pack_string(str, max_len)
    max_len = max_len or 64
    str = str or ""
    local len = math.min(#str, max_len)
    local result = pack_byte(len) .. string.sub(str, 1, len)
    return result
end

local function unpack_string(data, offset)
    local len, new_offset = unpack_byte(data, offset)
    if len == 0 then
        return "", new_offset
    end
    local str = string.sub(data, new_offset, new_offset + len - 1)
    return str, new_offset + len
end

-- Fase 2: Helpers adicionales de empaquetado/desempaquetado para protocolo v2
local function pack_int(value)
    -- 4 bytes sin signo (0-4294967295)
    local b1 = math.floor(value / 16777216) % 256
    local b2 = math.floor(value / 65536) % 256
    local b3 = math.floor(value / 256) % 256
    local b4 = value % 256
    return string.char(b1, b2, b3, b4)
end

local function unpack_int(data, offset)
    local b1, b2, b3, b4 = string.byte(data, offset, offset + 3)
    return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4, offset + 4
end

local function pack_turret_angle(angle)
    -- Punto fijo: radianes * 1000, almacenado como short con signo
    local scaled = math.floor(angle * 1000)
    if scaled < -32768 then scaled = -32768 end
    if scaled > 32767 then scaled = 32767 end
    local unsigned = scaled >= 0 and scaled or (65536 + scaled)
    return pack_short(unsigned)
end

local function unpack_turret_angle(data, offset)
    local unsigned, new_offset = unpack_short(data, offset)
    local scaled = unsigned > 32767 and (unsigned - 65536) or unsigned
    return scaled / 1000.0, new_offset
end

-- ENCODE: convertir mensaje Lua a bytes

function BinaryProtocol.encode(msg)
    local msg_type = msg.type

    if msg_type == "connect" then
        -- [type:1][room_id_len:1][room_id:N][has_metadata:1][metadata...]
        local result = pack_byte(BinaryProtocol.MSG_CONNECT)
        result = result .. pack_string(msg.room_id or "default", 32)

        -- Metadata simplificado (game_mode, max_players, map_idx)
        if msg.metadata then
            result = result .. pack_byte(1)  -- has_metadata
            result = result .. pack_string(msg.metadata.game_mode or "ffa", 16)
            result = result .. pack_byte(msg.metadata.max_players or 8)
            result = result .. pack_byte(msg.metadata.map_idx or 1)
        else
            result = result .. pack_byte(0)  -- no metadata
        end

        return result

    elseif msg_type == "welcome" then
        -- [type:1][player_id:2][room_id_len:1][room_id:N][map_idx:1]
        local result = pack_byte(BinaryProtocol.MSG_WELCOME)
        result = result .. pack_short(msg.player_id)
        result = result .. pack_string(msg.room_id or "default", 32)
        result = result .. pack_byte(msg.map_idx or 1)
        return result

    elseif msg_type == "update" then
        -- [type:1][x:2][y:2][angle:1][hp:1]
        local result = pack_byte(BinaryProtocol.MSG_UPDATE)
        result = result .. pack_float(msg.x or 0)
        result = result .. pack_float(msg.y or 0)
        result = result .. pack_angle(msg.angle or 0)
        result = result .. pack_byte(math.floor(msg.hp or 100))
        return result

    elseif msg_type == "state" then
        -- [type:1][player_count:1][[player_id:2][x:2][y:2][angle:1][hp:1]]...
        local result = pack_byte(BinaryProtocol.MSG_STATE)

        -- Contar jugadores
        local player_count = 0
        for _ in pairs(msg.players or {}) do
            player_count = player_count + 1
        end
        result = result .. pack_byte(player_count)

        -- Empaquetar cada jugador
        for pid, pdata in pairs(msg.players or {}) do
            local player_id = tonumber(pid)
            result = result .. pack_short(player_id)
            result = result .. pack_float(pdata.x or 0)
            result = result .. pack_float(pdata.y or 0)
            result = result .. pack_angle(pdata.angle or 0)
            result = result .. pack_byte(math.floor(pdata.hp or 100))
        end

        return result

    elseif msg_type == "bullet" then
        -- [type:1][player_id:2][x:2][y:2][angle:1][bullet_type_len:1][bullet_type:N]
        local result = pack_byte(BinaryProtocol.MSG_BULLET)
        result = result .. pack_short(msg.player_id or 0)
        result = result .. pack_float(msg.x or 0)
        result = result .. pack_float(msg.y or 0)
        result = result .. pack_angle(msg.angle or 0)
        result = result .. pack_string(msg.bullet_type or "plasma", 16)
        return result

    elseif msg_type == "disconnect" then
        -- [type:1]
        return pack_byte(BinaryProtocol.MSG_DISCONNECT)

    elseif msg_type == "list_rooms" then
        -- [type:1]
        return pack_byte(BinaryProtocol.MSG_LIST_ROOMS)

    elseif msg_type == "rooms_list" then
        -- [type:1][room_count:1][[room_id:str][game_mode:str][player_count:1][max_players:1][status:1]]...
        local result = pack_byte(BinaryProtocol.MSG_ROOMS_LIST)
        result = result .. pack_byte(#(msg.rooms or {}))

        for _, room in ipairs(msg.rooms or {}) do
            result = result .. pack_string(room.room_id or "", 32)
            result = result .. pack_string(room.game_mode or "ffa", 16)
            result = result .. pack_byte(room.player_count or 0)
            result = result .. pack_byte(room.max_players or 8)

            -- Estado: 0=esperando, 1=jugando, 2=lleno
            local status_byte = 0
            if room.status == "playing" then status_byte = 1
            elseif room.status == "full" then status_byte = 2 end
            result = result .. pack_byte(status_byte)
        end

        return result

    elseif msg_type == "powerup_collect" then
        -- [type:1][powerup_index:2]
        local result = pack_byte(BinaryProtocol.MSG_POWERUP_COLLECT)
        result = result .. pack_short(msg.powerup_index or 0)
        return result

    elseif msg_type == "powerup_collected" then
        -- [type:1][powerup_index:2][player_id:2][powerup_type:str]
        local result = pack_byte(BinaryProtocol.MSG_POWERUP_COLLECTED)
        result = result .. pack_short(msg.powerup_index or 0)
        result = result .. pack_short(msg.player_id or 0)
        result = result .. pack_string(msg.powerup_type or "health", 16)
        return result

    elseif msg_type == "powerup_spawn" then
        -- [type:1][powerup_index:2]
        local result = pack_byte(BinaryProtocol.MSG_POWERUP_SPAWN)
        result = result .. pack_short(msg.powerup_index or 0)
        return result

    elseif msg_type == "input" then
        -- Fase 2: [ver:1][type:1][seq:2][input_bits:1][turret_angle:2][dt_ms:1]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_INPUT)
        result = result .. pack_short(msg.seq or 0)
        result = result .. pack_byte(msg.input_bits or 0)
        result = result .. pack_turret_angle(msg.turret_angle or 0)
        result = result .. pack_byte(math.min(255, math.floor(msg.dt_ms or 16)))
        return result

    elseif msg_type == "snapshot" then
        -- Fase 2: [ver:1][type:1][server_tick:4][last_input_seq:2][count:1][[pid:2,x:2,y:2,angle:1,turret:1,hp:1,flags:1]*N]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_SNAPSHOT)
        result = result .. pack_int(msg.server_tick or 0)
        result = result .. pack_short(msg.last_input_seq or 0)

        local tanks = msg.tanks or {}
        result = result .. pack_byte(#tanks)

        for _, tank in ipairs(tanks) do
            result = result .. pack_short(tank.pid)
            result = result .. pack_float(tank.x)
            result = result .. pack_float(tank.y)
            result = result .. pack_angle(tank.angle)
            result = result .. pack_angle(tank.turret)
            result = result .. pack_byte(math.floor(tank.hp or 100))

            local flags = 0
            if tank.isDead then flags = bit.bor(flags, 1) end
            if tank.invuln then flags = bit.bor(flags, 2) end
            result = result .. pack_byte(flags)
        end

        return result

    elseif msg_type == "fire_intent" then
        -- Fase 4: [ver:1][type:1][seq:2][turret_angle:2][weapon_idx:1]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_FIRE_INTENT)
        result = result .. pack_short(msg.seq or 0)
        result = result .. pack_turret_angle(msg.turret_angle or 0)
        result = result .. pack_byte(msg.weapon_idx or 1)
        return result

    elseif msg_type == "bullet_spawn" then
        -- Fase 4: [ver:1][type:1][bullet_id:2][owner_pid:2][x:2][y:2][angle:1][weapon_idx:1]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_BULLET_SPAWN)
        result = result .. pack_short(msg.bullet_id)
        result = result .. pack_short(msg.owner_pid)
        result = result .. pack_float(msg.x)
        result = result .. pack_float(msg.y)
        result = result .. pack_angle(msg.angle)
        result = result .. pack_byte(msg.weapon_idx)
        return result

    elseif msg_type == "bullet_despawn" then
        -- Fase 4: [ver:1][type:1][bullet_id:2][reason:1]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_BULLET_DESPAWN)
        result = result .. pack_short(msg.bullet_id)
        result = result .. pack_byte(msg.reason or 0)
        return result

    elseif msg_type == "hit" then
        -- Fase 4: [ver:1][type:1][bullet_id:2][victim_pid:2][damage:1][new_hp:1]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_HIT)
        result = result .. pack_short(msg.bullet_id)
        result = result .. pack_short(msg.victim_pid)
        result = result .. pack_byte(math.floor(msg.damage or 0))
        result = result .. pack_byte(math.floor(msg.new_hp or 0))
        return result

    elseif msg_type == "death" then
        -- Fase 4: [ver:1][type:1][victim_pid:2]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_DEATH)
        result = result .. pack_short(msg.victim_pid)
        return result

    elseif msg_type == "respawn" then
        -- Fase 4: [ver:1][type:1][pid:2][x:2][y:2]
        local result = pack_byte(BinaryProtocol.VERSION_BYTE)
        result = result .. pack_byte(BinaryProtocol.MSG_RESPAWN)
        result = result .. pack_short(msg.pid)
        result = result .. pack_float(msg.x)
        result = result .. pack_float(msg.y)
        return result
    end

    -- Tipo desconocido - fallback vacío
    return pack_byte(0xFF)
end

-- DECODE: convertir bytes a mensaje Lua

function BinaryProtocol.decode(data)
    if not data or #data < 1 then
        return nil, "datos vacíos"
    end

    local first_byte = unpack_byte(data, 1)

    -- Verificar protocolo v2
    if first_byte == BinaryProtocol.VERSION_BYTE then
        -- Fase 2: Ruta protocolo V2
        if #data < 2 then
            return nil, "mensaje v2 demasiado corto"
        end

        local msg_type, offset = unpack_byte(data, 2)

        if msg_type == BinaryProtocol.MSG_INPUT then
            -- [ver:1][type:1][seq:2][input_bits:1][turret_angle:2][dt_ms:1]
            local seq, input_bits, turret_angle, dt_ms
            seq, offset = unpack_short(data, offset)
            input_bits, offset = unpack_byte(data, offset)
            turret_angle, offset = unpack_turret_angle(data, offset)
            dt_ms, offset = unpack_byte(data, offset)

            return {
                type = "input",
                seq = seq,
                input_bits = input_bits,
                turret_angle = turret_angle,
                dt_ms = dt_ms
            }

        elseif msg_type == BinaryProtocol.MSG_SNAPSHOT then
            -- [ver:1][type:1][server_tick:4][last_input_seq:2][count:1][[pid:2,x:2,y:2,angle:1,turret:1,hp:1,flags:1]*N]
            local server_tick, last_input_seq, count
            server_tick, offset = unpack_int(data, offset)
            last_input_seq, offset = unpack_short(data, offset)
            count, offset = unpack_byte(data, offset)

            local tanks = {}
            for i = 1, count do
                local pid, x, y, angle, turret, hp, flags
                pid, offset = unpack_short(data, offset)
                x, offset = unpack_float(data, offset)
                y, offset = unpack_float(data, offset)
                angle, offset = unpack_angle(data, offset)
                turret, offset = unpack_angle(data, offset)
                hp, offset = unpack_byte(data, offset)
                flags, offset = unpack_byte(data, offset)

                tanks[i] = {
                    pid = pid,
                    x = x,
                    y = y,
                    angle = angle,
                    turret = turret,
                    hp = hp,
                    isDead = bit.band(flags, 1) ~= 0,
                    invuln = bit.band(flags, 2) ~= 0
                }
            end

            return {
                type = "snapshot",
                server_tick = server_tick,
                last_input_seq = last_input_seq,
                tanks = tanks
            }

        elseif msg_type == BinaryProtocol.MSG_FIRE_INTENT then
            -- Fase 4: [ver:1][type:1][seq:2][turret_angle:2][weapon_idx:1]
            local seq, turret_angle, weapon_idx
            seq, offset = unpack_short(data, offset)
            turret_angle, offset = unpack_turret_angle(data, offset)
            weapon_idx, offset = unpack_byte(data, offset)

            return {
                type = "fire_intent",
                seq = seq,
                turret_angle = turret_angle,
                weapon_idx = weapon_idx
            }

        elseif msg_type == BinaryProtocol.MSG_BULLET_SPAWN then
            -- Fase 4: [ver:1][type:1][bullet_id:2][owner_pid:2][x:2][y:2][angle:1][weapon_idx:1]
            local bullet_id, owner_pid, x, y, angle, weapon_idx
            bullet_id, offset = unpack_short(data, offset)
            owner_pid, offset = unpack_short(data, offset)
            x, offset = unpack_float(data, offset)
            y, offset = unpack_float(data, offset)
            angle, offset = unpack_angle(data, offset)
            weapon_idx, offset = unpack_byte(data, offset)

            return {
                type = "bullet_spawn",
                bullet_id = bullet_id,
                owner_pid = owner_pid,
                x = x,
                y = y,
                angle = angle,
                weapon_idx = weapon_idx
            }

        elseif msg_type == BinaryProtocol.MSG_BULLET_DESPAWN then
            -- Fase 4: [ver:1][type:1][bullet_id:2][reason:1]
            local bullet_id, reason
            bullet_id, offset = unpack_short(data, offset)
            reason, offset = unpack_byte(data, offset)

            return {
                type = "bullet_despawn",
                bullet_id = bullet_id,
                reason = reason
            }

        elseif msg_type == BinaryProtocol.MSG_HIT then
            -- Fase 4: [ver:1][type:1][bullet_id:2][victim_pid:2][damage:1][new_hp:1]
            local bullet_id, victim_pid, damage, new_hp
            bullet_id, offset = unpack_short(data, offset)
            victim_pid, offset = unpack_short(data, offset)
            damage, offset = unpack_byte(data, offset)
            new_hp, offset = unpack_byte(data, offset)

            return {
                type = "hit",
                bullet_id = bullet_id,
                victim_pid = victim_pid,
                damage = damage,
                new_hp = new_hp
            }

        elseif msg_type == BinaryProtocol.MSG_DEATH then
            -- Fase 4: [ver:1][type:1][victim_pid:2]
            local victim_pid
            victim_pid, offset = unpack_short(data, offset)

            return {
                type = "death",
                victim_pid = victim_pid
            }

        elseif msg_type == BinaryProtocol.MSG_RESPAWN then
            -- Fase 4: [ver:1][type:1][pid:2][x:2][y:2]
            local pid, x, y
            pid, offset = unpack_short(data, offset)
            x, offset = unpack_float(data, offset)
            y, offset = unpack_float(data, offset)

            return {
                type = "respawn",
                pid = pid,
                x = x,
                y = y
            }
        end

        return nil, "tipo de mensaje v2 desconocido: " .. tostring(msg_type)
    end

    -- Ruta heredada (v1)
    local msg_type = first_byte
    local offset = 2

    if msg_type == BinaryProtocol.MSG_CONNECT then
        local room_id, has_metadata, game_mode, max_players
        room_id, offset = unpack_string(data, offset)
        has_metadata, offset = unpack_byte(data, offset)

        local msg = {type = "connect", room_id = room_id}

        if has_metadata == 1 then
            local map_idx
            game_mode, offset = unpack_string(data, offset)
            max_players, offset = unpack_byte(data, offset)
            map_idx, offset = unpack_byte(data, offset)
            msg.metadata = {
                game_mode = game_mode,
                max_players = max_players,
                map_idx = map_idx
            }
        end

        return msg

    elseif msg_type == BinaryProtocol.MSG_WELCOME then
        local player_id, room_id, map_idx
        player_id, offset = unpack_short(data, offset)
        room_id, offset = unpack_string(data, offset)
        map_idx, offset = unpack_byte(data, offset)

        return {
            type = "welcome",
            player_id = player_id,
            room_id = room_id,
            map_idx = map_idx or 1
        }

    elseif msg_type == BinaryProtocol.MSG_UPDATE then
        local x, y, angle, hp
        x, offset = unpack_float(data, offset)
        y, offset = unpack_float(data, offset)
        angle, offset = unpack_angle(data, offset)
        hp, offset = unpack_byte(data, offset)

        return {
            type = "update",
            x = x,
            y = y,
            angle = angle,
            hp = hp
        }

    elseif msg_type == BinaryProtocol.MSG_STATE then
        local player_count
        player_count, offset = unpack_byte(data, offset)

        local players = {}
        for i = 1, player_count do
            local pid, x, y, angle, hp
            pid, offset = unpack_short(data, offset)
            x, offset = unpack_float(data, offset)
            y, offset = unpack_float(data, offset)
            angle, offset = unpack_angle(data, offset)
            hp, offset = unpack_byte(data, offset)

            players[tostring(pid)] = {x = x, y = y, angle = angle, hp = hp}
        end

        return {
            type = "state",
            players = players
        }

    elseif msg_type == BinaryProtocol.MSG_BULLET then
        local player_id, x, y, angle, bullet_type
        player_id, offset = unpack_short(data, offset)
        x, offset = unpack_float(data, offset)
        y, offset = unpack_float(data, offset)
        angle, offset = unpack_angle(data, offset)
        bullet_type, offset = unpack_string(data, offset)

        return {
            type = "bullet",
            player_id = player_id,
            x = x,
            y = y,
            angle = angle,
            bullet_type = bullet_type
        }

    elseif msg_type == BinaryProtocol.MSG_DISCONNECT then
        return {type = "disconnect"}

    elseif msg_type == BinaryProtocol.MSG_LIST_ROOMS then
        return {type = "list_rooms"}

    elseif msg_type == BinaryProtocol.MSG_ROOMS_LIST then
        local room_count
        room_count, offset = unpack_byte(data, offset)

        local rooms = {}
        for i = 1, room_count do
            local room_id, game_mode, player_count, max_players, status_byte
            room_id, offset = unpack_string(data, offset)
            game_mode, offset = unpack_string(data, offset)
            player_count, offset = unpack_byte(data, offset)
            max_players, offset = unpack_byte(data, offset)
            status_byte, offset = unpack_byte(data, offset)

            local status = "waiting"
            if status_byte == 1 then status = "playing"
            elseif status_byte == 2 then status = "full" end

            table.insert(rooms, {
                room_id = room_id,
                game_mode = game_mode,
                player_count = player_count,
                max_players = max_players,
                status = status
            })
        end

        return {
            type = "rooms_list",
            rooms = rooms
        }

    elseif msg_type == BinaryProtocol.MSG_POWERUP_COLLECT then
        local powerup_index
        powerup_index, offset = unpack_short(data, offset)
        return {
            type = "powerup_collect",
            powerup_index = powerup_index
        }

    elseif msg_type == BinaryProtocol.MSG_POWERUP_COLLECTED then
        local powerup_index, player_id, powerup_type
        powerup_index, offset = unpack_short(data, offset)
        player_id, offset = unpack_short(data, offset)
        powerup_type, offset = unpack_string(data, offset)
        return {
            type = "powerup_collected",
            powerup_index = powerup_index,
            player_id = player_id,
            powerup_type = powerup_type
        }

    elseif msg_type == BinaryProtocol.MSG_POWERUP_SPAWN then
        local powerup_index
        powerup_index, offset = unpack_short(data, offset)
        return {
            type = "powerup_spawn",
            powerup_index = powerup_index
        }
    end

    return nil, "tipo de mensaje desconocido: " .. tostring(msg_type)
end

return BinaryProtocol
