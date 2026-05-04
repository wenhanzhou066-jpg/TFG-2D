-- systems/http.lua
-- Cliente HTTP mínimo para LÖVE usando LuaSocket.
-- Las llamadas son síncronas (bloquean el frame) pero solo ocurren en menús.

local socket_http = require("socket.http")
local ltn12       = require("ltn12")
local json        = require("systems.json")

local Http = {}

Http.BASE_URL = "http://217.78.237.7:8080"
Http.TIMEOUT  = 5  -- segundos

-- GET  →  devuelve tabla Lua decodificada, o nil + mensaje de error
function Http.get(ruta)
    local respuesta = {}
    local ok, codigo = socket_http.request({
        url     = Http.BASE_URL .. ruta,
        sink    = ltn12.sink.table(respuesta),
        headers = { ["Accept"] = "application/json" },
    })
    if not ok then return nil, "Sin conexion" end
    local cuerpo = table.concat(respuesta)
    local exito, datos = pcall(json.decode, cuerpo)
    if not exito then return nil, "Respuesta invalida" end
    return datos, codigo
end

-- POST / PUT  →  devuelve tabla Lua decodificada, o nil + mensaje de error
local function enviar(metodo, ruta, payload)
    local cuerpo_out = json.encode(payload or {})
    local respuesta  = {}
    local ok, codigo = socket_http.request({
        url     = Http.BASE_URL .. ruta,
        method  = metodo,
        headers = {
            ["Content-Type"]   = "application/json",
            ["Content-Length"] = tostring(#cuerpo_out),
            ["Accept"]         = "application/json",
        },
        source = ltn12.source.string(cuerpo_out),
        sink   = ltn12.sink.table(respuesta),
    })
    if not ok then return nil, "Sin conexion" end
    local cuerpo = table.concat(respuesta)
    local exito, datos = pcall(json.decode, cuerpo)
    if not exito then return nil, "Respuesta invalida" end
    return datos, codigo
end

function Http.post(ruta, payload) return enviar("POST", ruta, payload) end
function Http.put(ruta, payload)  return enviar("PUT",  ruta, payload) end

return Http
