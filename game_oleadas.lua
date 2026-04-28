-- game_oleadas.lua
-- Modo oleadas: 1 jugador o cooperativo local contra bots en oleadas

local GameOleadas = {}

local allMaps = {
    require("systems.maps.map"),
    require("systems.maps.map_volcano"),
    require("systems.maps.map_snow"),
    require("systems.maps.map_city"),
}

Map = nil
Tank = require("entities.tank")
Bullet = require("entities.bullet")
Effects = require("systems.effects")
Tracks = require("systems.tracks")
Audio = require("systems.audio")
Camera = {x=0, y=0}

local Bot = require("entities.bot")
local Oleadas = require("systems.oleadas")
local Pausa = require("systems.pausa")
local Controls = require("systems.controls")
local Remap = require("systems.controls_remap")

local GAME_W, GAME_H = 1920, 1080
local gameCanvas = nil
GameView = { scale=1, ox=0, oy=0 }

local modo     = "solo"
local pausado  = false
local subsystemsLoaded = false

-- Pantalla de controles al inicio
local showControls  = false
local controlsAlpha = 0

-- Márgenes de cámara coop
local CAM_MARGIN_X = 120
local CAM_MARGIN_Y = 90

-- Botón "Configurar controles" dentro del overlay
local function cfgBtnRect()
    return GAME_W/2 - 160, GAME_H/2 + 115, 320, 48
end

local function recalcView()
    local sw, sh = love.graphics.getDimensions()
    local s = math.min(sw/GAME_W, sh/GAME_H)
    GameView.scale = s
    GameView.ox = math.floor((sw - GAME_W*s) / 2)
    GameView.oy = math.floor((sh - GAME_H*s) / 2)
end

function GameOleadas.load(mapIdx, modoJuego)
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    modo = modoJuego or "solo"
    Map  = allMaps[mapIdx or 1]
    Map.load()
    Camera = {x=0, y=0}

    local sp = Map.getSpawns()[1]
    if not subsystemsLoaded then
        Tank.load(sp.x, sp.y)
        Bullet.load()
        Effects.load()
        Tracks.load()
        subsystemsLoaded = true
    else
        Tank.load(sp.x, sp.y)
    end

    if modo == "coop" then
        Tank.loadCoop(sp.x + 80, sp.y)
        showControls  = true
        controlsAlpha = 0
    else
        showControls = false
    end

    Audio.load(mapIdx or 1)
    Pausa.load()
    Oleadas.init(Bot)
    pausado = false
end

function GameOleadas.update(dt)
    if showControls then
        controlsAlpha = math.min(1, controlsAlpha + dt * 3)
    end

    Remap.update(dt)

    if pausado then
        Pausa.update(dt)
        local accion = Pausa.getAccion()
        if accion == "reanudar" then
            pausado = false
        elseif accion == "reiniciar" then
            Oleadas.reset()
            GameOleadas.load(nil, modo)
        elseif accion == "menu" then
            GameOleadas._onEscape()
        end
        return
    end

    -- Con overlay o remap abierto, el juego no avanza
    if showControls or Remap.isVisible() then return end

    if Oleadas.getEstado() == "victoria" then return end

    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
    Oleadas.update(dt)
    Bot.update(dt)

    --Cámara
    local mapSize = Map.getSize and Map.getSize() or {w=1920, h=1080}

    if modo == "coop" and Tank.hasPlayer2() then
        local allTanks = Tank.getTanks()
        local t1, t2  = allTanks[1], allTanks[2]

        local pts = {}
        if not t1.isDead then pts[#pts+1] = {x=t1.x, y=t1.y} end
        if not t2.isDead then pts[#pts+1] = {x=t2.x, y=t2.y} end

        if #pts > 0 then
            local minX, maxX = pts[1].x, pts[1].x
            local minY, maxY = pts[1].y, pts[1].y
            for _, p in ipairs(pts) do
                minX = math.min(minX, p.x);  maxX = math.max(maxX, p.x)
                minY = math.min(minY, p.y);  maxY = math.max(maxY, p.y)
            end

            local camX = (minX + maxX) / 2 - GAME_W / 2
            local camY = (minY + maxY) / 2 - GAME_H / 2

            local camXmin = maxX - GAME_W + CAM_MARGIN_X
            local camXmax = minX - CAM_MARGIN_X
            local camYmin = maxY - GAME_H + CAM_MARGIN_Y
            local camYmax = minY - CAM_MARGIN_Y

            if camXmin <= camXmax then camX = math.max(camXmin, math.min(camXmax, camX)) end
            if camYmin <= camYmax then camY = math.max(camYmin, math.min(camYmax, camY)) end

            Camera.x = math.max(0, math.min(camX, mapSize.w - GAME_W))
            Camera.y = math.max(0, math.min(camY, mapSize.h - GAME_H))
        end
    else
        local tx, ty = Tank.getPosition(1)
        Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
        Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))
    end
end

function GameOleadas.draw()
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.10, 0.10, 0.10)
    love.graphics.push()
    love.graphics.translate(-math.floor(Camera.x), -math.floor(Camera.y))

    Map.drawGround()
    Tracks.draw()
    Tank.draw()
    Bot.draw()
    Bullet.draw()
    Effects.draw()
    Map.drawAbove()

    love.graphics.pop()
    GameOleadas.drawHUD()

    if showControls then GameOleadas.drawControlsOverlay() end

    love.graphics.setCanvas()

    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy, 0, GameView.scale, GameView.scale)

    if pausado then Pausa.draw() end

    -- Remap siempre encima de todo
    if Remap.isVisible() then
        love.graphics.push()
        love.graphics.translate(GameView.ox, GameView.oy)
        love.graphics.scale(GameView.scale, GameView.scale)
        Remap.draw()
        love.graphics.pop()
    end
end

function GameOleadas.drawControlsOverlay()
    local a  = controlsAlpha
    local W, H   = GAME_W, GAME_H
    local boxW, boxH = 860, 480
    local bx = (W - boxW) / 2
    local by = (H - boxH) / 2

    -- Fondo oscuro
    love.graphics.setColor(0, 0, 0, 0.78 * a)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Panel
    love.graphics.setColor(0.08, 0.10, 0.16, 0.96 * a)
    love.graphics.rectangle("fill", bx, by, boxW, boxH, 14, 14)
    love.graphics.setColor(0.25, 0.55, 1.0, 0.85 * a)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", bx, by, boxW, boxH, 14, 14)
    love.graphics.setLineWidth(1)

    local UI     = require("systems.ui")
    local fontT  = UI.font("button")
    local fontSm = UI.font("small")

    -- Título
    love.graphics.setFont(fontT)
    love.graphics.setColor(0.9, 0.85, 1.0, a)
    love.graphics.printf("MODO COOPERATIVO", bx, by + 22, boxW, "center")

    love.graphics.setFont(fontSm)

    -- Separador
    love.graphics.setColor(0.25, 0.55, 1.0, 0.5 * a)
    love.graphics.line(bx + 30, by + 72, bx + boxW - 30, by + 72)

    -- Columna J1
    local col1X = bx + 60
    local rowY  = by + 90

    love.graphics.setColor(0.3, 0.8, 1.0, a)
    love.graphics.print("JUGADOR 1", col1X, rowY)
    rowY = rowY + 36
    love.graphics.setColor(0.85, 0.85, 0.85, a)

    local b1 = Controls.getAll(1)
    love.graphics.print("Mover:      " .. (b1.up or "w") .. " / " .. (b1.left or "a") .. " / " .. (b1.down or "s") .. " / " .. (b1.right or "d"), col1X, rowY)
    rowY = rowY + 28
    love.graphics.print("Apuntar:    Ratón", col1X, rowY)
    rowY = rowY + 28
    love.graphics.print("Disparar:   Click izquierdo", col1X, rowY)

    -- Columna J2
    local col2X = bx + boxW / 2 + 20
    rowY = by + 90

    love.graphics.setColor(1.0, 0.65, 0.2, a)
    love.graphics.print("JUGADOR 2", col2X, rowY)
    rowY = rowY + 36
    love.graphics.setColor(0.85, 0.85, 0.85, a)

    local b2 = Controls.getAll(2)
    love.graphics.print("Mover:      " .. (b2.up or "up") .. " / " .. (b2.left or "left") .. " / " .. (b2.down or "down") .. " / " .. (b2.right or "right"), col2X, rowY)
    rowY = rowY + 28
    love.graphics.print("Torreta:    " .. (b2.turretLeft or "j") .. " / " .. (b2.turretRight or "k"), col2X, rowY)
    rowY = rowY + 28
    love.graphics.print("Disparar:   " .. (b2.fire or "l"), col2X, rowY)

    -- Separador vertical
    love.graphics.setColor(0.25, 0.55, 1.0, 0.4 * a)
    love.graphics.line(bx + boxW/2, by + 80, bx + boxW/2, by + boxH - 110)

    -- Botón Configurar controles
    local cbx, cby, cbw, cbh = cfgBtnRect()
    love.graphics.setColor(0.15, 0.35, 0.65, 0.9 * a)
    love.graphics.rectangle("fill", cbx, cby, cbw, cbh, 10, 10)
    love.graphics.setColor(0.4, 0.75, 1.0, a)
    love.graphics.rectangle("line", cbx, cby, cbw, cbh, 10, 10)
    love.graphics.setColor(0.9, 0.95, 1.0, a)
    love.graphics.printf("Configurar controles", cbx, cby + (cbh - fontSm:getHeight()) / 2, cbw, "center")

    -- Pie
    love.graphics.setColor(0.55, 0.55, 0.55, a)
    local blink = math.floor(love.timer.getTime() * 2) % 2 == 0
    if blink then
        love.graphics.printf("Pulsa cualquier tecla o haz clic para comenzar", bx, by + boxH - 50, boxW, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function GameOleadas.drawHUD()
    local UI   = require("systems.ui")
    local font = UI.font("small")
    love.graphics.setFont(font)

    local estado    = Oleadas.getEstado()
    local numOleada = Oleadas.getNumOleada()
    local total     = Oleadas.getTotalOleadas()

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Oleada: " .. numOleada .. "/" .. total, 20, 20)
    love.graphics.print("Bots: " .. Bot.contarVivos(), 20, 52)

    if modo == "coop" then
        local hp1, mhp1 = Tank.getHP(1)
        local hp2, mhp2 = Tank.getHP(2)
        love.graphics.setColor(0.3, 0.8, 1.0, 0.9)
        love.graphics.print("P1 HP: " .. math.ceil(hp1) .. "/" .. mhp1, 20, 90)
        love.graphics.setColor(1.0, 0.65, 0.2, 0.9)
        love.graphics.print("P2 HP: " .. math.ceil(hp2) .. "/" .. mhp2, 20, 120)
        love.graphics.setColor(1, 1, 1, 0.9)
    else
        local hp, mhp = Tank.getHP(1)
        love.graphics.print("HP: " .. math.ceil(hp) .. "/" .. mhp, 20, 90)
    end

    if estado == "cuenta_atras" then
        love.graphics.setFont(UI.font("button"))
        local cd      = math.ceil(Oleadas.getCuentaAtras())
        local etiqueta = Oleadas.getEtiqueta()
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", GAME_W/2-260, GAME_H/2-50, 520, 100, 8, 8)
        love.graphics.setColor(1, 0.9, 0.3)
        if etiqueta ~= "" then
            love.graphics.printf(etiqueta, GAME_W/2-260, GAME_H/2-38, 520, "center")
        end
        love.graphics.printf("Siguiente oleada en " .. cd .. "s", GAME_W/2-260, GAME_H/2+10, 520, "center")
    end

    if estado == "victoria" then
        love.graphics.setFont(UI.font("button"))
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", GAME_W/2-260, GAME_H/2-40, 520, 80, 8, 8)
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.printf("¡VICTORIA! Todas las oleadas completadas", GAME_W/2-260, GAME_H/1.96, 520, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function GameOleadas.keypressed(key, onEscape)
    GameOleadas._onEscape = onEscape

    if Remap.isVisible() then
        Remap.keypressed(key)
        return
    end

    if showControls then
        if key == "escape" then
            GameOleadas._onEscape()
        end
        if key ~= "escape" then
            showControls = false
        end
        return
    end

    if pausado then Pausa.keypressed(key); return end
    if key == "escape" then Pausa.open(); pausado = true; return end

    -- Disparo J2
    if modo == "coop" then
        local fireKey = Controls.get(2, "fire") or "l"
        if key == fireKey then
            if Tank.canShoot(2) and Tank.shoot(2) then
                local bx, by, angle = Tank.getMuzzlePos(2)
                Bullet.spawn(bx, by, angle, nil, "player")
            end
        end
    end
end

function GameOleadas.mousepressed(x, y, button)
    -- Coordenadas en espacio del canvas
    local cx = (x - GameView.ox) / GameView.scale
    local cy = (y - GameView.oy) / GameView.scale

    if Remap.isVisible() then
        Remap.mousepressed(cx, cy, button)
        return
    end

    -- Overlay de controles
    if showControls then
        if button == 1 then
            local cbx, cby, cbw, cbh = cfgBtnRect()
            if cx >= cbx and cx <= cbx + cbw and cy >= cby and cy <= cby + cbh then
                Remap.open()
            else
                showControls = false
            end
        end
        return
    end

    if pausado then Pausa.mousepressed(x, y, button); return end
    if button == 1 then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, nil, "player")
    end
end

function GameOleadas.mousemoved(x, y)
    if pausado then Pausa.mousemoved(x, y) end
end

function GameOleadas.stopAudio()
    Audio.pararMusica()
end

return GameOleadas