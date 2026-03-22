-- systems/perfil.lua
-- Perfiles de jugador guardados como archivos en el directorio de LÖVE.
-- No requiere librerías externas.

local Perfil = {}

-- SHA-256 via love.data.hash (LÖVE 11.x incluido)
local function hashPwd(pw)
    local raw = love.data.hash("sha256", pw)
    local hex = ""
    for i = 1, #raw do hex = hex .. string.format("%02x", string.byte(raw, i)) end
    return hex
end

-- Ruta del archivo de un perfil dado su gamertag
local function rutaPerfil(gamertag)
    return "perfil_" .. gamertag:lower() .. ".lua"
end

-- Serializa una tabla simple a una cadena cargable con load()
local function serializar(t)
    local s = "return {\n"
    for k, v in pairs(t) do
        if type(v) == "string" then
            s = s .. string.format("  %s = %q,\n", k, v)
        elseif type(v) == "number" then
            s = s .. string.format("  %s = %s,\n", k, tostring(v))
        end
    end
    return s .. "}\n"
end

-- Lee un perfil desde disco; devuelve tabla o nil
local function leerPerfil(gamertag)
    local ruta = rutaPerfil(gamertag)
    if not love.filesystem.getInfo(ruta) then return nil end
    local contenido = love.filesystem.read(ruta)
    if not contenido then return nil end
    local fn, err = load(contenido)
    if not fn then return nil end
    local ok, datos = pcall(fn)
    return ok and datos or nil
end

-- ── API pública ───────────────────────────────────────────────────────────

-- Siempre disponible (no depende de librerías externas)
function Perfil.disponible()
    return true
end

-- No necesita inicialización especial
function Perfil.init()
    return true
end

-- Comprueba si un gamertag ya existe
function Perfil.existe(gamertag)
    return love.filesystem.getInfo(rutaPerfil(gamertag)) ~= nil
end

-- Crea un nuevo perfil. Devuelve ok, mensajeError
function Perfil.registrar(gamertag, password, datos)
    if #gamertag < 3 then return false, "Minimo 3 caracteres" end
    if #password < 4  then return false, "Contrasena minimo 4 caracteres" end
    if Perfil.existe(gamertag) then return false, "Gamertag ya en uso" end

    datos = datos or {}
    local registro = {
        gamertag  = gamertag,
        pass_hash = hashPwd(password),
        color_r   = datos.colorR or 1.0,
        color_g   = datos.colorG or 0.7,
        color_b   = datos.colorB or 0.2,
    }
    local ok = love.filesystem.write(rutaPerfil(gamertag), serializar(registro))
    return ok, ok and nil or "Error al guardar"
end

-- Valida credenciales y devuelve la tabla del perfil (o nil, mensajeError)
function Perfil.autenticar(gamertag, password)
    local datos = leerPerfil(gamertag)
    if not datos then return nil, "Gamertag o contrasena incorrectos" end
    if datos.pass_hash ~= hashPwd(password) then
        return nil, "Gamertag o contrasena incorrectos"
    end
    return {
        gamertag = datos.gamertag,
        colorR   = datos.color_r,
        colorG   = datos.color_g,
        colorB   = datos.color_b,
    }
end

-- Actualiza solo el color del perfil activo (no requiere contraseña)
function Perfil.actualizarColor(gamertag, nuevoDatos)
    local datos = leerPerfil(gamertag)
    if not datos then return false end
    datos.color_r = nuevoDatos.colorR
    datos.color_g = nuevoDatos.colorG
    datos.color_b = nuevoDatos.colorB
    local ok = love.filesystem.write(rutaPerfil(gamertag), serializar(datos))
    if ok and Perfil.activo and Perfil.activo.gamertag == gamertag then
        Perfil.activo.colorR = nuevoDatos.colorR
        Perfil.activo.colorG = nuevoDatos.colorG
        Perfil.activo.colorB = nuevoDatos.colorB
    end
    return ok
end

-- Perfil cargado en la sesión actual (nil = sin sesión)
Perfil.activo = nil

return Perfil
