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

function Tracks.spawn(x, y, angle)
    local idx = (#active % 2) + 1   -- alternar entre los dos sprites
    local img = sprites[idx]
    table.insert(active, {
        x     = x,
        y     = y,
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
    for _, t in ipairs(active) do
        local alpha = t.life / FADE_TIME  -- 1.0 → 0.0
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(t.img, t.x, t.y, t.angle + math.pi/2, 1, 1, t.ox, t.oy)
    end
    love.graphics.setColor(1, 1, 1)  -- restaurar
end

return Tracks