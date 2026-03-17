-- Sistema de balas para tanques

local Effects = require("systems.effects")

local Bullet = {}

-- Sprites y pools
local sprites = {}
local active = {}
local inactive = {}

-- Tipos de balas
local BulletTypes = {
    light  = { speed = 600, life = 2.5, img = "Light_Shell.png", damage = 10, radius = 16, trail = false },
    heavy  = { speed = 400, life = 3.0, img = "Heavy_Shell.png", damage = 25, radius = 32, trail = false },
    plasma = { speed = 800, life = 1.5, img = "Plasma.png",       damage = 15, radius = 12, trail = true  },
}

-- Cargar sprites
function Bullet.load()
    for tipo, datos in pairs(BulletTypes) do
        local ok, img = pcall(love.graphics.newImage, "assets/images/PNG/Effects/" .. datos.img)
        if ok then
            sprites[tipo] = img
        else
            error("No se pudo cargar el sprite de bala: " .. datos.img)
        end
    end
end

-- Crea una bala nueva o reutiliza una del pool
local function createBullet(x, y, angle, tipo)
    local t = BulletTypes[tipo] or BulletTypes.light
    local sprite = sprites[tipo] or sprites["light"]

    local b = table.remove(inactive) or {}
    b.x = x
    b.y = y
    b.angle = angle
    b.vx = math.cos(angle) * t.speed
    b.vy = math.sin(angle) * t.speed
    b.img = sprite
    b.ox = sprite:getWidth() / 2
    b.oy = sprite:getHeight() / 2
    b.life = t.life
    b.type = tipo
    b.damage = t.damage
    b.radius = t.radius
    b.trail = t.trail
    return b
end

-- Spawnea una bala y reproduce el sonido de disparo
function Bullet.spawn(x, y, angle, tipo)
    if Audio then Audio.disparo() end
    local b = createBullet(x, y, angle, tipo)
    table.insert(active, b)
end

-- Actualiza todas las balas activas
function Bullet.update(dt)
    local newActive = {}
    for _, b in ipairs(active) do

        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt

        -- Trail para balas rapidas como plasma
        if b.trail and Effects.spawnTrail then
            Effects.spawnTrail(b.x, b.y, b.type)
        end

        -- Colision con mapa o vida agotada
        if Map.bulletHit(b.x, b.y, b.radius) or b.life <= 0 then
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.explosion() end
            table.insert(inactive, b)
        else
            table.insert(newActive, b)
        end
    end
    active = newActive
end

-- Dibuja todas las balas activas
function Bullet.draw()
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(active) do
        -- Rotamos -90° porque el sprite apunta en vertical por defecto
        love.graphics.draw(b.img, b.x, b.y, b.angle + math.pi/2, 1, 1, b.ox, b.oy)
    end
end

-- Limpia todas las balas (al reiniciar partida)
function Bullet.clear()
    for _, b in ipairs(active) do
        table.insert(inactive, b)
    end
    active = {}
end

return Bullet