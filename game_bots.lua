-- game_bots.lua
-- Modo practica: jugador contra bots con dificultad elegida.

local GameBots = {}

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
local Pausa = require("systems.pausa")

local GAME_W, GAME_H = 1920, 1080
local gameCanvas = nil 
GameView = { scale=1, ox=0, oy=0 }

local pausado = false
local subsystemsLoaded = false
local nivelDif = 2

local function recalcView()
    local sw, sh = love.graphics.getDimensions()
    local s = math.min(sw/GAME_W, sh/GAME_H)
    GameView.scale = s
    GameView.ox = math.floor((sw - GAME_W*s) / 2)
    GameView.oy = math.floor((sh - GAME_H*s) / 2)
end

function GameBots.load(mapIdx, dificultad)
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    nivelDif = dificultad or 2
    Map = allMaps[mapIdx or 1]
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

    Audio.load(mapIdx or 1)
    Pausa.load()
    Bot.setDificultad(nivelDif)
    Bot.load()
    pausado = false
end

function GameBots.update(dt)
    if pausado then
        Pausa.update(dt)
        local accion = Pausa.getAccion()
        if accion == "reanudar" then
            pausado = false
        elseif accion == "reiniciar" then
            GameBots.load(nil, nivelDif)
        elseif accion == "menu" then
            GameBots._onEscape()
        end
        return
    end

    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
    Bot.update(dt)

    local mapSize = Map.getSize and Map.getSize() or {w=1920, h=1080}
    local tx, ty  = Tank.getPosition()
    Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
    Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))
end

function GameBots.draw()
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
    GameBots.drawHUD()
    love.graphics.setCanvas()

    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy, 0, GameView.scale, GameView.scale)

    if pausado then Pausa.draw() end
end

function GameBots.drawHUD()
    local UI = require("systems.ui")
    local font = UI.font("small")
    love.graphics.setFont(font)

    local dificultades = Bot.getDificultades()
    local nombreDif = dificultades[nivelDif] or "Normal"

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print("Dificultad: " .. nombreDif, 20, 20)
    love.graphics.print("Bots: " .. Bot.contarVivos(), 20, 52) -- increased y for better spacing

    if Bot.contarVivos() == 0 then
        love.graphics.setFont(UI.font("button")) -- Use a larger font for victory
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", GAME_W/2-260, GAME_H/2-40, 520, 80, 8, 8)
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.printf("¡Todos los bots eliminados!", GAME_W/2-260, GAME_H/2-14, 520, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function GameBots.keypressed(key, onEscape)
    GameBots._onEscape = onEscape
    if pausado then Pausa.keypressed(key); return end
    if key == "escape" then Pausa.open(); pausado = true end
end

function GameBots.mousepressed(x, y, button)
    if pausado then Pausa.mousepressed(x, y, button); return end
    if button == 1 then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, nil, "player")
    end
end

function GameBots.mousemoved(x, y)
    if pausado then Pausa.mousemoved(x, y) end
end

function GameBots.stopAudio()
    Audio.pararMusica()
end

return GameBots