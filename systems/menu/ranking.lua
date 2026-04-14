-- systems/menu/ranking.lua
-- Pantalla de ranking con datos reales del servidor.

local Base        = require("systems.menu.base")
local UI          = require("systems.ui")
local Audio       = require("systems.audio")
local leaderboard = require("systems.leaderboard")
local Perfil      = require("systems.perfil")

local Ranking = {}

local datos      = {}
local cargando   = false
local error_msg  = nil
local modoActual = "total"  -- "total", "local", "multi"

-- ── Parser JSON minimalista para el array del ranking ─────────────────────
local function parseRanking(jsonStr)
    if not jsonStr then return {} end
    local result = {}
    for obj in jsonStr:gmatch("{(.-)}") do
        local row = {}
        row.gamertag         = obj:match('"gamertag"%s*:%s*"([^"]*)"')         or "?"
        row.kills            = tonumber(obj:match('"kills"%s*:%s*([%d]+)'))    or 0
        row.muertes          = tonumber(obj:match('"muertes"%s*:%s*([%d]+)'))  or 0
        row.victorias        = tonumber(obj:match('"victorias"%s*:%s*([%d]+)')) or 0
        row.puntuacion_total = tonumber(obj:match('"puntuacion_total"%s*:%s*([%d]+)')) or 0
        row.kd_ratio         = tonumber(obj:match('"kd_ratio"%s*:%s*([%d%.]+)'))       or 0
        table.insert(result, row)
    end
    return result
end

local function cargarDatos()
    cargando  = true
    error_msg = nil
    datos     = {}
    local raw = leaderboard.getRanking(15, modoActual)
    if raw then
        datos = parseRanking(raw)
    else
        error_msg = "No se pudo conectar al servidor"
    end
    cargando = false
end

-- ── API pública ───────────────────────────────────────────────────────────

function Ranking.load(escena)
    Base.resetHover()
    modoActual = "total"
    cargarDatos()
end

function Ranking.draw(escena)
    local W      = love.graphics.getWidth()
    local H      = love.graphics.getHeight()
    local tiempo = escena.getTiempo and escena.getTiempo() or 0
    local yT     = H * 0.04 + math.sin(tiempo * 2) * 4

    UI.drawParallax(escena.fondos(), tiempo)
    UI.titleBanner(escena.tituloImg(), Base.tr("ranking"), yT, tiempo)
    UI.vignette(0.45)

    -- ── Tabla ─────────────────────────────────────────────────────────────
    local tableX = W * 0.08
    local tableY = H * 0.22
    local tableW = W * 0.84
    local rowH   = H * 0.058

    local cols = {
        { label = "#",         w = 0.06 },
        { label = "GAMERTAG",  w = 0.30 },
        { label = "KILLS",     w = 0.14 },
        { label = "K/D",       w = 0.14 },
        { label = "VICTORIAS", w = 0.18 },
        { label = "PUNTOS",    w = 0.18 },
    }

    local font = UI.font and UI.font("small") or love.graphics.getFont()
    love.graphics.setFont(font)

    -- Cabecera
    love.graphics.setColor(0.15, 0.15, 0.20, 0.92)
    love.graphics.rectangle("fill", tableX, tableY, tableW, rowH, 6, 6)
    love.graphics.setColor(0.9, 0.75, 0.2)
    local cx = tableX
    for _, col in ipairs(cols) do
        local cw = tableW * col.w
        love.graphics.printf(col.label, cx + 8, tableY + rowH * 0.28, cw - 16, "center")
        cx = cx + cw
    end

    -- Contenido
    if cargando then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.printf("Cargando...", tableX, tableY + rowH * 1.5, tableW, "center")

    elseif error_msg then
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf(error_msg, tableX, tableY + rowH * 1.5, tableW, "center")

    elseif #datos == 0 then
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.printf("Sin datos todavia. Juega una partida!", tableX, tableY + rowH * 1.5, tableW, "center")

    else
        local miGamertag = Perfil.activo and Perfil.activo.gamertag:lower() or ""

        for i, row in ipairs(datos) do
            local ry    = tableY + i * rowH
            local esMio = row.gamertag:lower() == miGamertag

            if esMio then
                love.graphics.setColor(0.2, 0.45, 0.2, 0.85)
            elseif i % 2 == 0 then
                love.graphics.setColor(0.12, 0.12, 0.18, 0.80)
            else
                love.graphics.setColor(0.08, 0.08, 0.14, 0.80)
            end
            love.graphics.rectangle("fill", tableX, ry, tableW, rowH - 2, 4, 4)

            local pos     = i == 1 and "1." or i == 2 and "2." or i == 3 and "3." or tostring(i) .. "."
            local valores = {
                pos,
                row.gamertag,
                tostring(row.kills),
                string.format("%.2f", row.kd_ratio),
                tostring(row.victorias),
                tostring(row.puntuacion_total),
            }

            if esMio then
                love.graphics.setColor(0.4, 1, 0.4)
            elseif i <= 3 then
                love.graphics.setColor(1, 0.92, 0.5)
            else
                love.graphics.setColor(0.9, 0.9, 0.9)
            end

            cx = tableX
            for j, col in ipairs(cols) do
                local cw    = tableW * col.w
                local align = j == 2 and "left" or "center"
                local px    = j == 2 and (cx + 12) or cx
                love.graphics.printf(valores[j], px, ry + rowH * 0.25, cw - 16, align)
                cx = cx + cw
            end
        end
    end

    -- ── Toggle TOTAL / LOCAL / MULTI ──────────────────────────────────────
    local toggleOpciones = { "total", "local", "multi" }
    local toggleLabels   = { "TOTAL", "LOCAL", "MULTI" }
    local toggleW = W * 0.18
    local toggleH = H * 0.055
    local toggleY = H * 0.80
    local totalW  = toggleW * 3 + 12
    local startX  = W / 2 - totalW / 2

    for i, modo in ipairs(toggleOpciones) do
        local tx  = startX + (i - 1) * (toggleW + 6)
        local sel = modoActual == modo
        if sel then
            love.graphics.setColor(0.9, 0.75, 0.2, 0.95)
        else
            love.graphics.setColor(0.15, 0.15, 0.22, 0.85)
        end
        love.graphics.rectangle("fill", tx, toggleY, toggleW, toggleH, 6, 6)
        love.graphics.setColor(sel and 0.08 or 0.80, sel and 0.08 or 0.80, sel and 0.08 or 0.80)
        love.graphics.printf(toggleLabels[i], tx, toggleY + toggleH * 0.22, toggleW, "center")
    end

    -- ── Botón Volver ──────────────────────────────────────────────────────
    local bw = W * 0.22
    local bh = H * 0.07
    local bx = W / 2 - bw / 2
    local by = H * 0.88
    UI.button(escena.botonExitImg(), bx, by, bw, bh, "Volver", true, tiempo, true, escena.botonExitImg())

    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

function Ranking.keypressed(key, escena)
    if key == "escape" or key == "return" or key == "kpenter" then
        Audio.volverMenu()
        escena.volver()
    elseif key == "r" or key == "f5" then
        cargarDatos()
    end
end

function Ranking.mousemoved(_, my, escena) end

function Ranking.mousepressed(x, my, btn, escena)
    if btn ~= 1 then return end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Click en toggle
    local toggleOpciones = { "total", "local", "multi" }
    local toggleW = W * 0.18
    local toggleH = H * 0.055
    local toggleY = H * 0.80
    local totalW  = toggleW * 3 + 12
    local startX  = W / 2 - totalW / 2

    for i, modo in ipairs(toggleOpciones) do
        local tx = startX + (i - 1) * (toggleW + 6)
        if x > tx and x < tx + toggleW and my > toggleY and my < toggleY + toggleH then
            if modoActual ~= modo then
                modoActual = modo
                if Audio.clickMenu then Audio.clickMenu() end
                cargarDatos()
            end
            return
        end
    end

    -- Click en Volver
    local bw = W * 0.22
    local bh = H * 0.07
    local bx = W / 2 - bw / 2
    local by = H * 0.88
    if x > bx and x < bx + bw and my > by and my < by + bh then
        Audio.volverMenu()
        escena.volver()
    end
end

return Ranking
