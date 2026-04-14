-- game.lua
-- Modulo del juego en partida.
-- Exporta Game.load(mapIdx), Game.update, Game.draw,
-- Game.keypressed y Game.mousepressed.

local Game = {}

local leaderboard = require("systems.leaderboard")
local Minimap     = require("systems.minimap")
local Perfil      = require("systems.perfil")

-- Contadores de la partida actual
local stats = { kills = 0, muertes = 0, victoria = false }

-- Los 4 mapas disponibles
local allMaps = {
    require("systems.maps.map"),
    require("systems.maps.map_volcano"),
    require("systems.maps.map_snow"),
    require("systems.maps.map_city"),
}

-- Globales que tank/bullet/effects leen internamente
Map     = nil
Tank    = require("entities.tank")
Bullet  = require("entities.bullet")
Powerup = require("entities.powerup")
Effects = require("systems.effects")
Tracks  = require("systems.tracks")
Audio   = require("systems.audio")
Camera  = {x=0, y=0}   -- cámara que sigue al tanque (coords mundo)

local subsystemsLoaded = false

-- Canvas de resolución fija; escala al monitor en draw()
local GAME_W, GAME_H = 1920, 1080
local gameCanvas = nil
GameView = { scale = 1, ox = 0, oy = 0 }   -- global; tank.lua lo lee para el ratón

local function recalcView()
    local sw, sh = love.graphics.getDimensions()
    local s = math.min(sw / GAME_W, sh / GAME_H)
    GameView.scale = s
    GameView.ox    = math.floor((sw - GAME_W * s) / 2)
    GameView.oy    = math.floor((sh - GAME_H * s) / 2)
end

-- Carga (o recarga) el juego con el mapa indicado (1, 2, 3 o 4).
function Game.load(mapIdx)
    stats = { kills = 0, muertes = 0, victoria = false }
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    Map = allMaps[mapIdx or 1]
    Map.load()
    Minimap.load()
    Camera = {x=0, y=0}   -- reiniciar cámara al cargar mapa

    -- Usar el primer punto de spawn del mapa para el jugador
    local sp = Map.getSpawns()[1]

    if not subsystemsLoaded then
        Tank.load(sp.x, sp.y)
        Bullet.load()
        Powerup.load()
        Effects.load()
        Tracks.load()
        subsystemsLoaded = true
    else
        Tank.load(sp.x, sp.y)
    end

    -- Spawnar power-ups en el mapa
    Powerup.clear()
    local spawns = Map.getPowerupSpawns()
    for _, sp in ipairs(spawns) do
        Powerup.spawn(sp.type, sp.x, sp.y)
    end

    Audio.load(mapIdx or 1)
end

function Game.addKill()   stats.kills   = stats.kills   + 1 end
function Game.addMuerte() stats.muertes = stats.muertes + 1 end

function Game.update(dt)
    Tank.update(dt)
    Bullet.update(dt)
    Powerup.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
    -- Actualizar cámara para seguir al tanque, clampeada a los límites del mapa
    local mapSize = Map.getSize()
    local tx, ty  = Tank.getPosition()
    Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
    Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))
    Minimap.update(tx, ty)
end

function Game.draw()
    -- Renderizar al canvas 1920×1080 con la cámara aplicada
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.10, 0.10, 0.10)
    love.graphics.push()

    -- Aplicar screen shake
    local shakeX, shakeY = Effects.getShakeOffset()
    love.graphics.translate(-math.floor(Camera.x) + shakeX, -math.floor(Camera.y) + shakeY)

    Map.drawGround()
    Tracks.draw()
    Powerup.draw()
    Tank.draw()
    Bullet.draw()
    Effects.draw()
    Map.drawAbove()
    love.graphics.pop()
    Minimap.drawFogToCurrentCanvas(Camera.x, Camera.y)
    love.graphics.setCanvas()

    -- Escalar el canvas al monitor con letterbox negro
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy,
                       0, GameView.scale, GameView.scale)

    Minimap.drawHUD(Camera.x, Camera.y, GameView)
end

-- onEscape: funcion que main.lua pasa para volver al menu
function Game.keypressed(key, onEscape)
    if key == "escape" then
        if Perfil.activo then
            leaderboard.enviarPartida(
                Perfil.activo.gamertag,
                stats.kills,
                stats.muertes,
                stats.victoria,
                "local"
            )
        end
        onEscape()
    end
end

function Game.mousepressed(x, y, button)
    if button == 1 and Tank.shoot() then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, "light", "local")
        Effects.spawnSmoke(bx, by, angle)
    end
end

-- Para el audio al salir de la partida
function Game.stopAudio()
    Audio.pararMusica()
end

return Game
