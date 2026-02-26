-- entities/bullet.lua
-- Pool de balas activas. Cada bala tiene posición,
-- velocidad, ángulo y tiempo de vida.

local Effects = require("systems.effects")

local Bullet = {}

local sprites = {}
local active  = {}
local SPEED   = 600
local LIFE    = 2.5   -- segundos antes de desaparecer

function Bullet.load()
    sprites.light  = love.graphics.newImage("assets/images/PNG/Effects/Light_Shell.png")
    sprites.heavy  = love.graphics.newImage("assets/images/PNG/Effects/Heavy_Shell.png")
    sprites.plasma = love.graphics.newImage("assets/images/PNG/Effects/Plasma.png")
end

function Bullet.spawn(x, y, angle, type)
    type = type or "light"
    table.insert(active, {
        x     = x,
        y     = y,
        vx    = math.cos(angle) * SPEED,
        vy    = math.sin(angle) * SPEED,
        angle = angle,
        img   = sprites[type],
        life  = LIFE,
    })
end

function Bullet.update(dt)
    for i = #active, 1, -1 do
        local b = active[i]
        b.x    = b.x + b.vx * dt
        b.y    = b.y + b.vy * dt
        b.life = b.life - dt

        -- Impacto en muro o edificio destruible
        if Map.bulletHit(b.x, b.y) then
            Effects.spawnExplosion(b.x, b.y)
            table.remove(active, i)
        elseif b.life <= 0 then
            Effects.spawnExplosion(b.x, b.y)
            table.remove(active, i)
        end
    end
end

function Bullet.draw()
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(active) do
        local ox = b.img:getWidth()  / 2
        local oy = b.img:getHeight() / 2
        love.graphics.draw(b.img, b.x, b.y, b.angle, 1, 1, ox, oy)
    end
end

return Bullet