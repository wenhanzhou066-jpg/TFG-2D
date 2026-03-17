-- systems/json.lua
-- Minimal JSON encoder/decoder for network communication

local json = {}

-- Encode Lua table to JSON string
function json.encode(val)
    local t = type(val)

    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    elseif t == "table" then
        local is_array = true
        local count = 0

        -- Check if it's an array or object
        for k, v in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k ~= count then
                is_array = false
                break
            end
        end

        if is_array and count > 0 then
            -- Array
            local parts = {}
            for i = 1, count do
                parts[i] = json.encode(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            -- Object
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, json.encode(tostring(k)) .. ":" .. json.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        error("Cannot encode type: " .. t)
    end
end

-- Decode JSON string to Lua table
function json.decode(str)
    local pos = 1

    local function skip_whitespace()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c ~= " " and c ~= "\t" and c ~= "\n" and c ~= "\r" then
                break
            end
            pos = pos + 1
        end
    end

    local function decode_value()
        skip_whitespace()

        local c = str:sub(pos, pos)

        if c == '"' then
            -- String
            pos = pos + 1
            local start = pos
            while pos <= #str do
                local char = str:sub(pos, pos)
                if char == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then
                    local result = str:sub(start, pos - 1)
                    result = result:gsub('\\"', '"'):gsub('\\\\', '\\'):gsub('\\n', '\n')
                    pos = pos + 1
                    return result
                end
                pos = pos + 1
            end
            error("Unterminated string")

        elseif c == '{' then
            -- Object
            pos = pos + 1
            local obj = {}
            skip_whitespace()

            if str:sub(pos, pos) == '}' then
                pos = pos + 1
                return obj
            end

            while true do
                skip_whitespace()
                local key = decode_value()
                skip_whitespace()

                if str:sub(pos, pos) ~= ':' then
                    error("Expected ':'")
                end
                pos = pos + 1

                local value = decode_value()
                obj[key] = value

                skip_whitespace()
                local next_char = str:sub(pos, pos)
                if next_char == '}' then
                    pos = pos + 1
                    return obj
                elseif next_char == ',' then
                    pos = pos + 1
                else
                    error("Expected ',' or '}'")
                end
            end

        elseif c == '[' then
            -- Array
            pos = pos + 1
            local arr = {}
            skip_whitespace()

            if str:sub(pos, pos) == ']' then
                pos = pos + 1
                return arr
            end

            while true do
                table.insert(arr, decode_value())
                skip_whitespace()

                local next_char = str:sub(pos, pos)
                if next_char == ']' then
                    pos = pos + 1
                    return arr
                elseif next_char == ',' then
                    pos = pos + 1
                else
                    error("Expected ',' or ']'")
                end
            end

        elseif c == 't' then
            -- true
            if str:sub(pos, pos + 3) == "true" then
                pos = pos + 4
                return true
            end
            error("Invalid value")

        elseif c == 'f' then
            -- false
            if str:sub(pos, pos + 4) == "false" then
                pos = pos + 5
                return false
            end
            error("Invalid value")

        elseif c == 'n' then
            -- null
            if str:sub(pos, pos + 3) == "null" then
                pos = pos + 4
                return nil
            end
            error("Invalid value")

        elseif c == '-' or (c >= '0' and c <= '9') then
            -- Number
            local start = pos
            if c == '-' then pos = pos + 1 end

            while pos <= #str do
                local char = str:sub(pos, pos)
                if (char < '0' or char > '9') and char ~= '.' then
                    break
                end
                pos = pos + 1
            end

            return tonumber(str:sub(start, pos - 1))
        else
            error("Unexpected character: " .. c)
        end
    end

    return decode_value()
end

return json
