-- systems/effects.lua
-- Gestiona efectos visuales animados (explosiones, humo, flashes).

local Effects = {}

local anims  = {}
local active = {}

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

function Effects.update(dt)
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
end

function Effects.draw()
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
end

return Effects
