-- binary_protocol.lua
-- Protocolo binario para comunicación cliente-servidor (3-5x más rápido que JSON)
-- Reduce lag significativamente mediante serialización eficiente

local BinaryProtocol = {}

-- Tipos de mensaje (1 byte)
BinaryProtocol.MSG_CONNECT = 0x01
BinaryProtocol.MSG_WELCOME = 0x02
BinaryProtocol.MSG_UPDATE = 0x03
BinaryProtocol.MSG_STATE = 0x04
BinaryProtocol.MSG_BULLET = 0x05
BinaryProtocol.MSG_DISCONNECT = 0x06
BinaryProtocol.MSG_LIST_ROOMS = 0x07
BinaryProtocol.MSG_ROOMS_LIST = 0x08

-- Helpers para empaquetar/desempaquetar bytes
local function pack_byte(value)
    return string.char(value)
end

local function unpack_byte(data, offset)
    return string.byte(data, offset), offset + 1
end

local function pack_short(value)
    -- 2 bytes unsigned (0-65535)
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

-- ENCODE: convertir mensaje Lua a bytes

function BinaryProtocol.encode(msg)
    local msg_type = msg.type

    if msg_type == "connect" then
        -- [type:1][room_id_len:1][room_id:N][has_metadata:1][metadata...]
        local result = pack_byte(BinaryProtocol.MSG_CONNECT)
        result = result .. pack_string(msg.room_id or "default", 32)

        -- Metadata simplificado (solo game_mode y max_players)
        if msg.metadata then
            result = result .. pack_byte(1)  -- has_metadata
            result = result .. pack_string(msg.metadata.game_mode or "ffa", 16)
            result = result .. pack_byte(msg.metadata.max_players or 8)
        else
            result = result .. pack_byte(0)  -- no metadata
        end

        return result

    elseif msg_type == "welcome" then
        -- [type:1][player_id:2][room_id_len:1][room_id:N]
        local result = pack_byte(BinaryProtocol.MSG_WELCOME)
        result = result .. pack_short(msg.player_id)
        result = result .. pack_string(msg.room_id or "default", 32)
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

            -- Status: 0=waiting, 1=playing, 2=full
            local status_byte = 0
            if room.status == "playing" then status_byte = 1
            elseif room.status == "full" then status_byte = 2 end
            result = result .. pack_byte(status_byte)
        end

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

    local msg_type, offset = unpack_byte(data, 1)

    if msg_type == BinaryProtocol.MSG_CONNECT then
        local room_id, has_metadata, game_mode, max_players
        room_id, offset = unpack_string(data, offset)
        has_metadata, offset = unpack_byte(data, offset)

        local msg = {type = "connect", room_id = room_id}

        if has_metadata == 1 then
            game_mode, offset = unpack_string(data, offset)
            max_players, offset = unpack_byte(data, offset)
            msg.metadata = {
                game_mode = game_mode,
                max_players = max_players
            }
        end

        return msg

    elseif msg_type == BinaryProtocol.MSG_WELCOME then
        local player_id, room_id
        player_id, offset = unpack_short(data, offset)
        room_id, offset = unpack_string(data, offset)

        return {
            type = "welcome",
            player_id = player_id,
            room_id = room_id
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
    end

    return nil, "tipo de mensaje desconocido: " .. tostring(msg_type)
end

return BinaryProtocol
