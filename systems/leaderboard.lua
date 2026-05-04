-- systems/leaderboard.lua
-- Ranking local (JSON) + sincronización con servidor webdock.
-- El servidor es la fuente principal; el archivo local actúa como caché/fallback.

local json = require("systems.json")
local Http = require("systems.http")

local Leaderboard = {}
local RANKING_FILE = "ranking.json"

local function nuevaFila(gamertag)
    return {
        gamertag         = gamertag,
        kills            = 0,
        muertes          = 0,
        victorias        = 0,
        partidas_jugadas = 0,
        puntuacion_total = 0,
        fecha_registro   = os.date("%Y-%m-%d %H:%M:%S"),
        kills_local      = 0,
        muertes_local    = 0,
        victorias_local  = 0,
        puntuacion_local = 0,
        kills_multi      = 0,
        muertes_multi    = 0,
        victorias_multi  = 0,
        puntuacion_multi = 0,
    }
end

local function cargarRanking()
    if not love.filesystem.getInfo(RANKING_FILE) then return {} end
    local contenido = love.filesystem.read(RANKING_FILE)
    if not contenido then return {} end
    local ok, datos = pcall(json.decode, contenido)
    return ok and datos or {}
end

local function guardarRanking(datos)
    local ok, contenido = pcall(json.encode, datos)
    if ok then love.filesystem.write(RANKING_FILE, contenido) end
end

local function calcularPuntuacion(kills, muertes, victorias)
    return math.max(0, (kills * 100) + (victorias * 500) - (muertes * 50))
end

-- ── API pública ───────────────────────────────────────────────────────────

function Leaderboard.registrar(gamertag)
    -- Local
    local datos = cargarRanking()
    local existe = false
    for _, row in ipairs(datos) do
        if row.gamertag:lower() == gamertag:lower() then existe = true; break end
    end
    if not existe then
        table.insert(datos, nuevaFila(gamertag))
        guardarRanking(datos)
    end

    -- Servidor (best-effort, sin bloquear si falla)
    Http.post("/registro", { gamertag = gamertag })

    return true
end

function Leaderboard.enviarPartida(gamertag, kills, muertes, victoria, modo)
    kills   = kills   or 0
    muertes = muertes or 0

    -- ── Local ──────────────────────────────────────────────────────────────
    local datos = cargarRanking()
    local reg = nil
    for _, row in ipairs(datos) do
        if row.gamertag:lower() == gamertag:lower() then reg = row; break end
    end
    if not reg then
        reg = nuevaFila(gamertag)
        table.insert(datos, reg)
    end

    reg.kills_local      = reg.kills_local      or 0
    reg.muertes_local    = reg.muertes_local    or 0
    reg.victorias_local  = reg.victorias_local  or 0
    reg.puntuacion_local = reg.puntuacion_local or 0
    reg.kills_multi      = reg.kills_multi      or 0
    reg.muertes_multi    = reg.muertes_multi    or 0
    reg.victorias_multi  = reg.victorias_multi  or 0
    reg.puntuacion_multi = reg.puntuacion_multi or 0
    reg.partidas_jugadas = reg.partidas_jugadas or 0

    reg.kills            = reg.kills   + kills
    reg.muertes          = reg.muertes + muertes
    if victoria then reg.victorias = reg.victorias + 1 end
    reg.partidas_jugadas = reg.partidas_jugadas + 1

    if modo == "multi" then
        reg.kills_multi   = reg.kills_multi   + kills
        reg.muertes_multi = reg.muertes_multi + muertes
        if victoria then reg.victorias_multi = reg.victorias_multi + 1 end
        reg.puntuacion_multi = calcularPuntuacion(
            reg.kills_multi, reg.muertes_multi, reg.victorias_multi)
    else
        reg.kills_local   = reg.kills_local   + kills
        reg.muertes_local = reg.muertes_local + muertes
        if victoria then reg.victorias_local = reg.victorias_local + 1 end
        reg.puntuacion_local = calcularPuntuacion(
            reg.kills_local, reg.muertes_local, reg.victorias_local)
    end
    reg.puntuacion_total = calcularPuntuacion(reg.kills, reg.muertes, reg.victorias)
    guardarRanking(datos)

    -- ── Servidor ───────────────────────────────────────────────────────────
    Http.post("/partida", {
        gamertag = gamertag,
        kills    = kills,
        muertes  = muertes,
        victoria = victoria == true,
        modo     = modo or "local",
    })

    return true
end

-- Devuelve JSON para ranking.lua.
-- Intenta el servidor primero; si falla usa el caché local.
function Leaderboard.getRanking(limit, mode)
    limit = limit or 15
    mode  = mode  or "total"

    local ruta = string.format("/ranking?limit=%d&modo=%s", limit, mode)
    local datos_srv = Http.get(ruta)
    if datos_srv and type(datos_srv) == "table" and #datos_srv > 0 then
        return json.encode(datos_srv)
    end

    -- Fallback local
    local datos = cargarRanking()
    local filtrados = {}
    for _, row in ipairs(datos) do
        local incluir = true
        if mode == "local" and (row.kills_local or 0) == 0
                           and (row.victorias_local or 0) == 0 then incluir = false end
        if mode == "multi" and (row.kills_multi or 0) == 0
                           and (row.victorias_multi or 0) == 0 then incluir = false end
        if incluir then table.insert(filtrados, row) end
    end
    table.sort(filtrados, function(a, b)
        return (a.puntuacion_total or 0) > (b.puntuacion_total or 0)
    end)
    local final = {}
    for i = 1, math.min(#filtrados, limit) do
        local r  = filtrados[i]
        local kd = (r.muertes or 0) == 0 and (r.kills or 0)
                   or (r.kills / r.muertes)
        table.insert(final, {
            gamertag         = r.gamertag,
            kills            = r.kills            or 0,
            muertes          = r.muertes          or 0,
            victorias        = r.victorias        or 0,
            puntuacion_total = r.puntuacion_total or 0,
            kd_ratio         = math.floor(kd * 100) / 100,
        })
    end
    return json.encode(final)
end

return Leaderboard
