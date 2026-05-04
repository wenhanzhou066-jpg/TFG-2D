-- systems/perfil.lua
-- Perfiles de jugador: archivo local (primario) + sincronización con servidor.

local Leaderboard = require("systems.leaderboard")
local Http        = require("systems.http")

local Perfil = {}

local function hashPwd(pw)
    local raw = love.data.hash("sha256", pw)
    local hex = ""
    for i = 1, #raw do hex = hex .. string.format("%02x", string.byte(raw, i)) end
    return hex
end

local function rutaPerfil(gamertag)
    return "perfil_" .. gamertag:lower() .. ".lua"
end

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

function Perfil.disponible() return true end
function Perfil.init()       return true end

function Perfil.existe(gamertag)
    return love.filesystem.getInfo(rutaPerfil(gamertag)) ~= nil
end

function Perfil.registrar(gamertag, password, datos)
    if #gamertag < 3 then return false, "Minimo 3 caracteres" end
    if #password < 4  then return false, "Contrasena minimo 4 caracteres" end
    if Perfil.existe(gamertag) then return false, "Gamertag ya en uso" end

    datos = datos or {}
    local registro = {
        gamertag        = gamertag,
        pass_hash       = hashPwd(password),
        color_body_r    = datos.colorBodyR   or 1.0,
        color_body_g    = datos.colorBodyG   or 0.7,
        color_body_b    = datos.colorBodyB   or 0.2,
        color_turret_r  = datos.colorTurretR or 0.9,
        color_turret_g  = datos.colorTurretG or 0.9,
        color_turret_b  = datos.colorTurretB or 0.9,
        color_ammo_r    = datos.colorAmmoR   or 1.0,
        color_ammo_g    = datos.colorAmmoG   or 0.8,
        color_ammo_b    = datos.colorAmmoB   or 0.2,
    }

    -- Guardar localmente
    local ok = love.filesystem.write(rutaPerfil(gamertag), serializar(registro))
    if not ok then return false, "Error al guardar" end

    -- Registrar en ranking local + servidor
    Leaderboard.registrar(gamertag)

    -- Sincronizar perfil con servidor (best-effort)
    Http.post("/perfil", {
        gamertag       = registro.gamertag,
        pass_hash      = registro.pass_hash,
        color_body_r   = registro.color_body_r,
        color_body_g   = registro.color_body_g,
        color_body_b   = registro.color_body_b,
        color_turret_r = registro.color_turret_r,
        color_turret_g = registro.color_turret_g,
        color_turret_b = registro.color_turret_b,
        color_ammo_r   = registro.color_ammo_r,
        color_ammo_g   = registro.color_ammo_g,
        color_ammo_b   = registro.color_ammo_b,
    })

    return true, nil
end

-- Valida credenciales usando el hash local (no envía la contraseña al servidor)
function Perfil.autenticar(gamertag, password)
    local datos = leerPerfil(gamertag)
    if not datos then return nil, "Gamertag o contrasena incorrectos" end
    if datos.pass_hash ~= hashPwd(password) then
        return nil, "Gamertag o contrasena incorrectos"
    end
    return {
        gamertag      = datos.gamertag,
        colorBodyR    = datos.color_body_r   or 1.0,
        colorBodyG    = datos.color_body_g   or 0.7,
        colorBodyB    = datos.color_body_b   or 0.2,
        colorTurretR  = datos.color_turret_r or 0.9,
        colorTurretG  = datos.color_turret_g or 0.9,
        colorTurretB  = datos.color_turret_b or 0.9,
        colorAmmoR    = datos.color_ammo_r   or 1.0,
        colorAmmoG    = datos.color_ammo_g   or 0.8,
        colorAmmoB    = datos.color_ammo_b   or 0.2,
    }
end

function Perfil.actualizarPersonalizacion(gamertag, nuevoDatos)
    local datos = leerPerfil(gamertag)
    if not datos then return false end

    datos.color_body_r   = nuevoDatos.colorBodyR   or datos.color_body_r
    datos.color_body_g   = nuevoDatos.colorBodyG   or datos.color_body_g
    datos.color_body_b   = nuevoDatos.colorBodyB   or datos.color_body_b
    datos.color_turret_r = nuevoDatos.colorTurretR or datos.color_turret_r
    datos.color_turret_g = nuevoDatos.colorTurretG or datos.color_turret_g
    datos.color_turret_b = nuevoDatos.colorTurretB or datos.color_turret_b
    datos.color_ammo_r   = nuevoDatos.colorAmmoR   or datos.color_ammo_r
    datos.color_ammo_g   = nuevoDatos.colorAmmoG   or datos.color_ammo_g
    datos.color_ammo_b   = nuevoDatos.colorAmmoB   or datos.color_ammo_b

    local ok = love.filesystem.write(rutaPerfil(gamertag), serializar(datos))
    if not ok then return false end

    -- Actualizar caché en Perfil.activo
    if Perfil.activo and Perfil.activo.gamertag == gamertag then
        Perfil.activo.colorBodyR   = datos.color_body_r
        Perfil.activo.colorBodyG   = datos.color_body_g
        Perfil.activo.colorBodyB   = datos.color_body_b
        Perfil.activo.colorTurretR = datos.color_turret_r
        Perfil.activo.colorTurretG = datos.color_turret_g
        Perfil.activo.colorTurretB = datos.color_turret_b
        Perfil.activo.colorAmmoR   = datos.color_ammo_r
        Perfil.activo.colorAmmoG   = datos.color_ammo_g
        Perfil.activo.colorAmmoB   = datos.color_ammo_b
    end

    -- Sincronizar colores con servidor (best-effort)
    Http.put("/perfil/" .. gamertag, {
        color_body_r   = datos.color_body_r,
        color_body_g   = datos.color_body_g,
        color_body_b   = datos.color_body_b,
        color_turret_r = datos.color_turret_r,
        color_turret_g = datos.color_turret_g,
        color_turret_b = datos.color_turret_b,
        color_ammo_r   = datos.color_ammo_r,
        color_ammo_g   = datos.color_ammo_g,
        color_ammo_b   = datos.color_ammo_b,
    })

    return true
end

function Perfil.actualizarColor(gamertag, nuevoDatos)
    return Perfil.actualizarPersonalizacion(gamertag, {
        colorBodyR = nuevoDatos.colorR,
        colorBodyG = nuevoDatos.colorG,
        colorBodyB = nuevoDatos.colorB,
    })
end

Perfil.activo = nil

return Perfil
