-- systems/tracks.lua
-- Huellas de oruga que se dejan en el suelo.
-- Se dibujan antes que el tanque (debajo) y
-- desaparecen gradualmente con alpha fade.

local Tracks = {}

local sprites    = {}
local active     = {}
local FADE_TIME  = 3.0   -- segundos hasta desaparecer

function Tracks.load()
    sprites[1] = love.graphics.newImage("assets/images/PNG/Effects/Tire_Track_01.png")
    sprites[2] = love.graphics.newImage("assets/images/PNG/Effects/Tire_Track_02.png")
end

local TRACK_SPAWN_OFFSET = 18 -- distance from center to trailing edge
local TRACK_WIDTH = 14        -- reduced lateral distance to keep tracks inside hull

function Tracks.spawn(x, y, angle, isReverse)
    local dir = isReverse and 1 or -1
    -- Calculate position slightly behind the tank based on its orientation
    local offsetX = math.cos(angle) * TRACK_SPAWN_OFFSET * dir
    local offsetY = math.sin(angle) * TRACK_SPAWN_OFFSET * dir
    
    local idx = (#active % 2) + 1   -- alternar entre los dos sprites
    local img = sprites[idx]
    table.insert(active, {
        x     = x + offsetX,
        y     = y + offsetY,
        angle = angle,
        life  = FADE_TIME,
        img   = img,
        ox    = img:getWidth()  / 2,
        oy    = img:getHeight() / 2,
    })
end

function Tracks.update(dt)
    for i = #active, 1, -1 do
        active[i].life = active[i].life - dt
        if active[i].life <= 0 then
            table.remove(active, i)
        end
    end
end

function Tracks.draw()
    local s = 0.45 -- escala ajustada para que no sobresalga lateralmente
    for _, t in ipairs(active) do
        local alpha = t.life / FADE_TIME  -- 1.0 → 0.0
        love.graphics.setColor(1, 1, 1, alpha)
        
        -- Calcular el vector perpendicular para las dos huellas paralelas
        local perpX = math.sin(t.angle) * TRACK_WIDTH
        local perpY = -math.cos(t.angle) * TRACK_WIDTH
        
        -- Huella Izquierda
        love.graphics.draw(t.img, t.x + perpX, t.y + perpY, t.angle + math.pi/2, s, s, t.ox, t.oy)
        -- Huella Derecha
        love.graphics.draw(t.img, t.x - perpX, t.y - perpY, t.angle + math.pi/2, s, s, t.ox, t.oy)
    end
    love.graphics.setColor(1, 1, 1)  -- restaurar
end

return Tracks