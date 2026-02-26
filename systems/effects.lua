-- systems/effects.lua
-- Gestiona efectos visuales animados (explosiones,
-- llamas, flashes). Los frames se cargan en listas
-- y se reproducen en secuencia hasta terminar.

local Effects = {}

local anims  = {}   -- frames cargados por tipo
local active = {}   -- efectos activos en pantalla

local function loadFrames(prefix, count, useLetters)
    local frames = {}
    local letters = {"A","B","C","D","E","F","G","H"}
    for i = 1, count do
        local suffix = useLetters and letters[i] or string.format("%02d", i)
        local path = "assets/images/PNG/Effects/" .. prefix .. suffix .. ".png"
        frames[i] = love.graphics.newImage(path)
    end
    return frames
end

function Effects.load()
    -- Letras A-H (8 frames)
    anims.explosion = loadFrames("Explosion_", 8, true)
    anims.flame      = loadFrames("Flame_",     8, true)
    -- Números 01-05 (5 frames)
    anims.flash_a    = loadFrames("Flash_A_",   5, false)
    anims.flash_b    = loadFrames("Flash_B_",   5, false)
end

-- Función genérica para lanzar cualquier efecto
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

-- Atajos para los efectos más usados
function Effects.spawnExplosion(x, y) Effects.spawn("explosion", x, y) end
function Effects.spawnFlash(x, y)     Effects.spawn("flash_a", x, y, 0.04) end

function Effects.update(dt)
    for i = #active, 1, -1 do
        local e = active[i]
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
        if e.frames[e.current] then
            love.graphics.draw(e.frames[e.current], e.x, e.y, 0, 1, 1, e.ox, e.oy)
        end
    end
end

return Effects