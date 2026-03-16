
-- Sistema de balas para tanques 
local Effects = require("systems.effects")

local Bullet = {}

-- Sprites y pools
local sprites  = {}
local active   = {}
local inactive = {}  -- Pool de balas inactivas

-- Definición de tipos de balas
local BulletTypes = {
    light = { speed = 600, life = 2.5, img = "Light_Shell.png", damage = 10, radius = 16, trail = false },
    heavy = { speed = 400, life = 3.0, img = "Heavy_Shell.png", damage = 25, radius = 32, trail = false },
    plasma = { speed = 800, life = 1.5, img = "Plasma.png", damage = 15, radius = 12, trail = true },
}

-- Cargar sprites (llamar desde love.load)
function Bullet.load()
    for type, data in pairs(BulletTypes) do
        local ok, img = pcall(love.graphics.newImage, "assets/images/PNG/Effects/" .. data.img)
        if ok then
            sprites[type] = img
        else
            error("No se pudo cargar el sprite de bala: " .. data.img)
        end
    end
end

-- Crear 
local function createBullet(x, y, angle, type)
    local t = BulletTypes[type] or BulletTypes.light
    local sprite = sprites[type] or sprites["light"]  -- fallback seguro

    local b = table.remove(inactive) or {}
    b.x = x
    b.y = y
    b.angle = angle
    b.vx = math.cos(angle) * t.speed
    b.vy = math.sin(angle) * t.speed
    b.img = sprite
    b.ox = sprite:getWidth()  / 2
    b.oy = sprite:getHeight() / 2
    b.life = t.life
    b.type = type
    b.damage = t.damage
    b.radius = t.radius
    b.trail = t.trail
    return b
end

-- Spawnear bala
function Bullet.spawn(x, y, angle, type)
    if Audio then Audio.playShot() end
    local b = createBullet(x, y, angle, type)
    table.insert(active, b)
end

-- Actualizar todas las balas
function Bullet.update(dt)
    local newActive = {}
    for _, b in ipairs(active) do
        -- Movimiento
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt

        -- Trail para balas rápidas como plasma
        if b.trail and Effects.spawnTrail then
            Effects.spawnTrail(b.x, b.y, b.type)
        end

        -- Colisión con mapa o vida agotada
        if Map.bulletHit(b.x, b.y, b.radius) or b.life <= 0 then
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.playExplosion() end
            table.insert(inactive, b)  -- devolver al pool
        else
            table.insert(newActive, b)
        end
    end
    active = newActive
end

-- Dibujar balas
function Bullet.draw()
    love.graphics.setColor(1,1,1)
    for _, b in ipairs(active) do
        local rotationOffset = -math.pi/-2  -- rota -90° para que el proyectil no salga en vertical , que es la posición que tiene el sprite 
        love.graphics.draw(b.img, b.x, b.y, b.angle + rotationOffset, 1, 1, b.ox, b.oy)
    end
end

-- Limpiar todas las balas , por ejemplo al reiniciar la partida
function Bullet.clear()
    for _, b in ipairs(active) do
        table.insert(inactive, b)
    end
    active = {}
end

return Bullet