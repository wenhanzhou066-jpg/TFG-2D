-- main.lua
-- Punto de entrada del juego.
-- Teclas 1/2/3 cambian entre los 3 mapas disponibles.

-- Módulos de mapa disponibles
local allMaps = {
    require("systems.map"),          -- 1: Bosque
    require("systems.map_volcano"),  -- 2: Volcán
    require("systems.map_snow"),     -- 3: Nieve
}
local mapNames  = { "Bosque", "Volcan", "Nieve" }
local currentMapIdx = 1

-- Mapa activo (global para que tank y bullet lo lean)
Map     = allMaps[1]
Tank    = require("entities.tank")
Bullet  = require("entities.bullet")
Effects = require("systems.effects")
Tracks  = require("systems.tracks")

local font
local mapLabel  = ""
local labelTimer = 0
local LABEL_DUR  = 2.5   -- segundos que se muestra el nombre del mapa

local function switchMap(n)
    currentMapIdx = n
    Map = allMaps[n]
    Map.load()
    Tank.load()
    mapLabel   = "Mapa: " .. mapNames[n]
    labelTimer = LABEL_DUR
end

function love.load()
    font = love.graphics.newFont(22)
    switchMap(1)
    Bullet.load()
    Effects.load()
    Tracks.load()
end

function love.update(dt)
    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
    if labelTimer > 0 then labelTimer = labelTimer - dt end
end

function love.draw()
    love.graphics.clear(0.10, 0.10, 0.10)
    Map.drawGround()
    Tracks.draw()        -- 1. Huellas
    Tank.draw()          -- 2. Tanque
    Bullet.draw()        -- 3. Balas
    Effects.draw()       -- 4. Explosiones
    Map.drawAbove()      -- 5. Árboles y elementos encima del tanque

    -- Nombre del mapa al cambiar (desvanece)
    if labelTimer > 0 then
        local alpha = math.min(1, labelTimer)
        love.graphics.setFont(font)
        love.graphics.setColor(0, 0, 0, alpha * 0.65)
        love.graphics.rectangle("fill", 14, 14, 230, 36)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print(mapLabel, 22, 21)
    end

    -- Indicador permanente (esquina superior derecha)
    love.graphics.setFont(font)
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 1680, 14, 230, 36)
    love.graphics.setColor(0.95, 0.95, 0.95, 0.9)
    love.graphics.print("[1] Bosque  [2] Lava  [3] Nieve", 1686, 21)

    love.graphics.setColor(1, 1, 1)
end

-- Input: disparo
function love.mousepressed(x, y, button)
    if button == 1 then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle)
    end
end

-- Input: teclado
function love.keypressed(key)
    if     key == "escape" then love.event.quit()
    elseif key == "1"      then switchMap(1)
    elseif key == "2"      then switchMap(2)
    elseif key == "3"      then switchMap(3)
    end
end
