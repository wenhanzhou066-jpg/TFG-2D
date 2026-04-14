-- systems/leaderboard.lua
-- Sistema de ranking local y gestión de estadísticas.
-- Mantiene un archivo 'ranking.json' en el directorio de guardado de LÖVE.

local json = require("systems.json")

local Leaderboard = {}
local RANKING_FILE = "ranking.json"

-- Estructura de un registro:
-- {
--   gamertag = "nombre",
--   kills = 0,
--   muertes = 0,
--   victorias = 0,
--   puntuacion_total = 0,
--   kd_ratio = 0.0,
--   partidas_local = 0,
--   partidas_multi = 0
-- }

-- Carga el ranking desde disco
local function cargarRanking()
    if not love.filesystem.getInfo(RANKING_FILE) then
        return {}
    end
    local contenido = love.filesystem.read(RANKING_FILE)
    if not contenido then return {} end
    
    local ok, datos = pcall(json.decode, contenido)
    return ok and datos or {}
end

-- Guarda el ranking a disco
local function guardarRanking(datos)
    local ok, contenido = pcall(json.encode, datos)
    if ok then
        love.filesystem.write(RANKING_FILE, contenido)
    end
end

-- Calcula el K/D y la puntuación
local function recalcularStats(row)
    row.kills = row.kills or 0
    row.muertes = row.muertes or 0
    row.victorias = row.victorias or 0
    
    if row.muertes == 0 then
        row.kd_ratio = row.kills
    else
        row.kd_ratio = row.kills / row.muertes
    end
    
    -- Fórmula simple de puntuación total
    row.puntuacion_total = (row.kills * 100) + (row.victorias * 500) - (row.muertes * 50)
    if row.puntuacion_total < 0 then row.puntuacion_total = 0 end
end

-- ── API pública ───────────────────────────────────────────────────────────

-- Registra un nuevo jugador si no existe
function Leaderboard.registrar(gamertag)
    local datos = cargarRanking()
    
    -- Buscar si ya existe
    local existe = false
    for _, row in ipairs(datos) do
        if row.gamertag:lower() == gamertag:lower() then
            existe = true
            break
        end
    end
    
    if not existe then
        table.insert(datos, {
            gamertag = gamertag,
            kills = 0,
            muertes = 0,
            victorias = 0,
            puntuacion_total = 0,
            kd_ratio = 0.0,
            partidas_local = 0,
            partidas_multi = 0
        })
        guardarRanking(datos)
    end
    return true
end

-- Envía los resultados de una partida
function Leaderboard.enviarPartida(gamertag, kills, muertes, victoria, modo)
    local datos = cargarRanking()
    local registro = nil
    
    for _, row in ipairs(datos) do
        if row.gamertag:lower() == gamertag:lower() then
            registro = row
            break
        end
    end
    
    -- Si no existe, lo creamos
    if not registro then
        registro = {
            gamertag = gamertag,
            kills = 0,
            muertes = 0,
            victorias = 0,
            puntuacion_total = 0,
            kd_ratio = 0.0,
            partidas_local = 0,
            partidas_multi = 0
        }
        table.insert(datos, registro)
    end
    
    -- Actualizar acumulados
    registro.kills = registro.kills + (kills or 0)
    registro.muertes = registro.muertes + (muertes or 0)
    if victoria then
        registro.victorias = registro.victorias + 1
    end
    
    if modo == "multi" then
        registro.partidas_multi = (registro.partidas_multi or 0) + 1
    else
        registro.partidas_local = (registro.partidas_local or 0) + 1
    end
    
    recalcularStats(registro)
    guardarRanking(datos)
    return true
end

-- Devuelve el ranking formateado como JSON para systems/menu/ranking.lua
-- ranking.lua usa un parser rústico: jsonStr:gmatch("{(.-)}")
function Leaderboard.getRanking(limit, mode)
    local datos = cargarRanking()
    
    -- En esta implementación simple "local", el modo filtra pero mostramos todo el acumulado.
    -- Podríamos filtrar por partidas_local > 0 o partidas_multi > 0.
    local filtrados = {}
    for _, row in ipairs(datos) do
        local incluir = true
        if mode == "local" and (row.partidas_local or 0) == 0 then incluir = false end
        if mode == "multi" and (row.partidas_multi or 0) == 0 then incluir = false end
        
        if incluir then
            table.insert(filtrados, row)
        end
    end
    
    -- Ordenar por puntuación total descendente
    table.sort(filtrados, function(a, b)
        return (a.puntuacion_total or 0) > (b.puntuacion_total or 0)
    end)
    
    -- Limitar resultados
    local final = {}
    limit = limit or 15
    for i = 1, math.min(#filtrados, limit) do
        table.insert(final, filtrados[i])
    end
    
    -- Devolver JSON procesado por json.encode
    -- El parser de ranking.lua funcionará porque json.encode genera objetos { "k": "v" }
    return json.encode(final)
end

return Leaderboard
