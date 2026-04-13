-- systems/effects.lua
-- Gestiona efectos visuales animados (explosiones, humo, flashes).

local Effects = {}

local anims  = {}
local active = {}
local damageNumbers = {}
local trailParticles = {}

-- Screen shake
local shakeAmount = 0
local shakeDecay = 5

local function loadFrames(prefix, count, useLetters)
    local frames  = {}
    local letters = {"A","B","C","D","E","F","G","H"}
    for i = 1, count do
        local suffix = useLetters and letters[i] or string.format("%02d", i)
        local path = "assets/images/PNG/Effects/" .. prefix .. suffix .. ".png"
        frames[i] = love.graphics.newImage(path)
    end
    return frames
end

function Effects.load()
    anims.explosion = loadFrames("Explosion_", 8, true)
    anims.flame      = loadFrames("Flame_",     8, true)
    anims.flash_a    = loadFrames("Flash_A_",   5, false)
    anims.flash_b    = loadFrames("Flash_B_",   5, false)
    -- Humo del disparo: 3 frames (A, B, C)
    anims.smoke      = loadFrames("Smoke_",     3, true)
end

-- Lanza un efecto genérico centrado en (x, y)
function Effects.spawn(animName, x, y, speed)
    local frames = anims[animName]
    if not frames then return end
    table.insert(active, {
        frames  = frames,
        current = 1,
        x = x, y = y,
        timer = 0,
        speed = speed or 0.07,
        ox = frames[1]:getWidth()  / 2,
        oy = frames[1]:getHeight() / 2,
    })
end

-- Atajos para efectos frecuentes
function Effects.spawnExplosion(x, y) Effects.spawn("explosion", x, y) end
function Effects.spawnFlash(x, y)     Effects.spawn("flash_a", x, y, 0.04) end

-- Humo de disparo: aparece en el cañón y deriva en la dirección de disparo
function Effects.spawnSmoke(x, y, angle)
    local frames = anims.smoke
    if not frames then return end
    -- Deriva lenta en la dirección del disparo
    local speed = 35
    table.insert(active, {
        frames  = frames,
        current = 1,
        x = x, y = y,
        angle = angle,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        timer = 0,
        speed = 0.10,   -- 0.1 s por frame → ~0.3 s total
        ox = frames[1]:getWidth()  / 2,
        oy = frames[1]:getHeight() / 2,
        isSmoke = true,
    })
end

-- Trail de particulas para balas plasma
function Effects.spawnTrail(x, y, bulletType)
    table.insert(trailParticles, {
        x = x,
        y = y,
        alpha = 1.0,
        life = 0.3,
        size = bulletType == "plasma" and 4 or 3
    })
end

-- Numero de daño flotante
function Effects.spawnDamageNumber(x, y, damage)
    table.insert(damageNumbers, {
        x = x,
        y = y,
        damage = math.floor(damage),
        alpha = 1.0,
        life = 1.0,
        vy = -50  -- sube
    })
end

-- Screen shake
function Effects.shake(amount)
    shakeAmount = math.max(shakeAmount, amount)
end

function Effects.getShakeOffset()
    if shakeAmount <= 0 then return 0, 0 end
    local angle = love.math.random() * math.pi * 2
    local dist = love.math.random() * shakeAmount
    return math.cos(angle) * dist, math.sin(angle) * dist
end

function Effects.update(dt)
    -- Animaciones
    for i = #active, 1, -1 do
        local e = active[i]

        -- Deriva (humo)
        if e.vx then
            e.x = e.x + e.vx * dt
            e.y = e.y + e.vy * dt
        end

        e.timer = e.timer + dt
        if e.timer >= e.speed then
            e.timer   = 0
            e.current = e.current + 1
            if e.current > #e.frames then
                table.remove(active, i)
            end
        end
    end

    -- Damage numbers
    for i = #damageNumbers, 1, -1 do
        local d = damageNumbers[i]
        d.life = d.life - dt
        d.y = d.y + d.vy * dt
        d.alpha = d.life

        if d.life <= 0 then
            table.remove(damageNumbers, i)
        end
    end

    -- Trail particles
    for i = #trailParticles, 1, -1 do
        local p = trailParticles[i]
        p.life = p.life - dt
        p.alpha = p.life / 0.3

        if p.life <= 0 then
            table.remove(trailParticles, i)
        end
    end

    -- Screen shake decay
    if shakeAmount > 0 then
        shakeAmount = math.max(0, shakeAmount - shakeDecay * dt)
    end
end

function Effects.draw()
    love.graphics.setColor(1, 1, 1)

    -- Trail particles
    for _, p in ipairs(trailParticles) do
        love.graphics.setColor(1, 0.5, 1, p.alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end

    -- Animaciones
    love.graphics.setColor(1, 1, 1)
    for _, e in ipairs(active) do
        local frame = e.frames[e.current]
        if frame then
            if e.isSmoke then
                -- El humo rota según la dirección del cañón (+pi/2 = sprite apunta arriba)
                love.graphics.draw(frame, e.x, e.y, (e.angle or 0) + math.pi/2, 1, 1, e.ox, e.oy)
            else
                love.graphics.draw(frame, e.x, e.y, 0, 1, 1, e.ox, e.oy)
            end
        end
    end

    -- Damage numbers
    for _, d in ipairs(damageNumbers) do
        love.graphics.setColor(1, 1, 0, d.alpha)
        love.graphics.print("-" .. d.damage, d.x - 10, d.y)
    end

    love.graphics.setColor(1, 1, 1)
end

return Effects
