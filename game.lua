-- game.lua
-- Modulo del juego en partida.
-- Exporta Game.load(mapIdx), Game.update, Game.draw,
-- Game.keypressed y Game.mousepressed.

local Game = {}

-- Los 3 mapas disponibles
local allMaps = {
    require("systems.map"),
    require("systems.map_volcano"),
    require("systems.map_snow"),
}

-- Globales que tank/bullet/effects leen internamente
Map     = nil
Tank    = require("entities.tank")
Bullet  = require("entities.bullet")
Effects = require("systems.effects")
Tracks  = require("systems.tracks")
Audio   = require("systems.audio")

local subsystemsLoaded = false

-- Carga (o recarga) el juego con el mapa indicado (1, 2 o 3).
function Game.load(mapIdx)
    Map = allMaps[mapIdx or 1]
    Map.load()

    if not subsystemsLoaded then
        -- Primera vez: cargar sprites/assets de todos los subsistemas
        Tank.load()
        Bullet.load()
        Effects.load()
        Tracks.load()
        subsystemsLoaded = true
    else
        -- Cambio de mapa: solo resetear posicion del tanque
        Tank.load()
    end

    Audio.load(mapIdx or 1)
end

function Game.update(dt)
    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
end

function Game.draw()
    love.graphics.clear(0.10, 0.10, 0.10)
    Map.drawGround()
    Tracks.draw()
    Tank.draw()
    Bullet.draw()
    Effects.draw()
    Map.drawAbove()
end

-- onEscape: funcion que main.lua pasa para volver al menu
function Game.keypressed(key, onEscape)
    if key == "escape" then
        onEscape()
    end
end

function Game.mousepressed(x, y, button)
    if button == 1 then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, "plasma")  -- o "light"/"heavy"
    end
end

return Game
