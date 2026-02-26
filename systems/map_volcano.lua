-- systems/map_volcano.lua
-- Mapa volcánico: lava, edificios oscuros, roca volcánica.
-- Activos del pack game_background_1.

local MapVolcano = {}

local W, H = 1920, 1080

local imgs = {}

-- ── Paleta ─────────────────────────────────────────────────────
local C = {
    lava     = { 0.92, 0.36, 0.04 },
    lavaEdge = { 0.55, 0.12, 0.02 },
}

-- ── Tablas de geometría ────────────────────────────────────────
local rivers  = {}
local roads   = {}
local bridges = {}
local walls   = {}
local covers  = {}

-- ── Constantes ────────────────────────────────────────────────
local RW = 68
local RY = 480
local RH = 100   -- canal de lava más ancho

-- Solo 2 puentes → cruzar la lava es más peligroso
local BR = {
    { x = 420,  w = 110 },
    { x = 1390, w = 110 },
}

-- ── Helpers de tiling ──────────────────────────────────────────
local function drawTiledH(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    local scale  = rh / ih
    local tw     = iw * scale
    love.graphics.setScissor(math.floor(rx), math.floor(ry),
                             math.ceil(rw),  math.ceil(rh))
    local x = rx
    while x < rx + rw do
        love.graphics.draw(img, math.floor(x), math.floor(ry), 0, scale, scale)
        x = x + tw
    end
    love.graphics.setScissor()
end

local function drawTiledV(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    local scale  = rw / iw
    local th     = ih * scale
    love.graphics.setScissor(math.floor(rx), math.floor(ry),
                             math.ceil(rw),  math.ceil(rh))
    local y = ry
    while y < ry + rh do
        love.graphics.draw(img, math.floor(rx), math.floor(y), 0, scale, scale)
        y = y + th
    end
    love.graphics.setScissor()
end

local function drawFit(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.draw(img, rx, ry, 0, rw / iw, rh / ih)
end

-- ── Carga ──────────────────────────────────────────────────────
function MapVolcano.load()
    rivers, roads, bridges, walls, covers = {}, {}, {}, {}, {}

    local p = "assets/images/PNG/game_background_1/layers/"

    imgs.bg       = love.graphics.newImage(p .. "main_bg.png")
    imgs.bridge   = love.graphics.newImage(p .. "bridge.png")
    imgs.roadH    = love.graphics.newImage(p .. "road_6.png")
    imgs.roadV    = love.graphics.newImage(p .. "road_5.png")
    imgs.building = love.graphics.newImage(p .. "decor_2.png")  -- casa oscura
    imgs.stones   = {}
    for i = 1, 6 do
        imgs.stones[i] = love.graphics.newImage(p .. "stone_" .. i .. ".png")
    end

    -- ══ LAVA CENTRAL ══════════════════════════════════════════
    local px = 0
    for _, b in ipairs(BR) do
        if b.x > px then
            rivers[#rivers+1] = { x = px, y = RY, w = b.x - px, h = RH }
        end
        px = b.x + b.w
    end
    rivers[#rivers+1] = { x = px, y = RY, w = W - px, h = RH }

    -- ══ PUENTES ════════════════════════════════════════════════
    for _, b in ipairs(BR) do
        bridges[#bridges+1] = { x=b.x-4, y=RY-8, w=b.w+8, h=RH+16, dir="h" }
    end

    -- ══ CARRETERAS ════════════════════════════════════════════
    local function road(x, y, w, h, dir)
        roads[#roads+1] = { x=x, y=y, w=w, h=h, dir=dir }
    end

    road(0,   60,  W, RW, "h")
    road(0,  952,  W, RW, "h")
    for _, b in ipairs(BR) do
        road(b.x, RY + math.floor((RH-RW)/2), b.w, RW, "h")
    end
    for _, b in ipairs(BR) do
        local bx = b.x + math.floor((b.w - RW) / 2)
        road(bx, 60+RW,  RW, RY - (60+RW),  "v")
        road(bx, RY+RH,  RW, 952 - (RY+RH), "v")
    end

    -- ══ MUROS SÓLIDOS (roca volcánica) ════════════════════════
    local function wall(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=false,hp=0} end
    local function dest(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=true, hp=3} end

    -- Bastiones en esquinas
    wall(40,   40, 100, 80)   wall(1780,  40, 100, 80)
    wall(40,  960, 100, 80)   wall(1780, 960, 100, 80)
    -- Bloques zona norte (asimétrico)
    wall(340,  190,  80, 65)  wall(1500, 190,  80, 65)
    wall(340,  380,  65, 85)  wall(1500, 380,  65, 85)
    -- Bloques zona sur
    wall(340,  810,  80, 65)  wall(1500, 810,  80, 65)
    wall(340,  640,  65, 85)  wall(1500, 640,  65, 85)
    -- Muros laterales largos
    wall(155, 190, 20, 290)   wall(1745, 190, 20, 290)
    wall(155, 600, 20, 290)   wall(1745, 600, 20, 290)
    -- Bloques centrales (control del puente)
    wall(700, 210, 90, 70)    wall(1130, 210, 90, 70)
    wall(700, 800, 90, 70)    wall(1130, 800, 90, 70)
    wall(900, 175, 80, 60)    wall(940,  845, 80, 60)

    -- ══ EDIFICIOS DESTRUIBLES ═════════════════════════════════
    dest(590,  300, 110, 80)  dest(1220, 300, 110, 80)
    dest(770,  245,  90, 70)  dest(1060, 245,  90, 70)
    dest(590,  700, 110, 80)  dest(1220, 700, 110, 80)
    dest(770,  760,  90, 70)  dest(1060, 760,  90, 70)

    -- ══ COBERTURA (rocas volcánicas pequeñas) ═════════════════
    local function cover(x, y, w, h) covers[#covers+1]={x=x,y=y,w=w,h=h} end

    for i = 0, 5 do
        cover(120 + i*300, 148, 52, 38)
        cover(120 + i*300, 894, 52, 38)
    end
    for i = 0, 2 do
        cover(58,  238 + i*215, 48, 38)
        cover(1814,238 + i*215, 48, 38)
    end
    cover(545, 265, 52, 38)  cover(1323, 265, 52, 38)
    cover(775, 355, 52, 38)  cover(1095, 355, 52, 38)
    cover(545, 755, 52, 38)  cover(1323, 755, 52, 38)
    cover(775, 660, 52, 38)  cover(1095, 660, 52, 38)
    for _, b in ipairs(BR) do
        cover(b.x - 75, RY - 60, 52, 38)
        cover(b.x + b.w + 20, RY - 60, 52, 38)
        cover(b.x - 75, RY + RH + 20, 52, 38)
        cover(b.x + b.w + 20, RY + RH + 20, 52, 38)
    end

    -- ── Asignar sprites ────────────────────────────────────────
    local si = 0
    for _, w in ipairs(walls) do
        if not w.dest then
            w.sprite = imgs.stones[si % 6 + 1]
            si = si + 1
        else
            w.sprite = imgs.building
        end
    end
    local ci = 0
    for _, c in ipairs(covers) do
        c.sprite = imgs.stones[ci % 6 + 1]
        ci = ci + 1
    end
end

-- ── Draw layers ────────────────────────────────────────────────
function MapVolcano.drawGround()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.bg, 0, 0)

    -- Lava (fill naranja vivo + borde rojo oscuro)
    for _, r in ipairs(rivers) do
        love.graphics.setColor(C.lava)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        love.graphics.setColor(C.lavaEdge)
        love.graphics.setLineWidth(5)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    end

    -- Carreteras
    love.graphics.setColor(1, 1, 1)
    for _, r in ipairs(roads) do
        if r.dir == "h" then
            drawTiledH(imgs.roadH, r.x, r.y, r.w, r.h)
        else
            drawTiledV(imgs.roadV, r.x, r.y, r.w, r.h)
        end
    end

    -- Puentes (tanque pasa por encima)
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(bridges) do
        drawFit(imgs.bridge, b.x, b.y, b.w, b.h)
    end

    -- Coberturas (rocas volcánicas)
    love.graphics.setColor(1, 1, 1)
    for _, c in ipairs(covers) do
        drawFit(c.sprite, c.x, c.y, c.w, c.h)
    end

    -- Muros y edificios
    for _, w in ipairs(walls) do
        if not w.dest then
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)

        elseif w.hp <= 0 then
            -- Escombros volcánicos
            love.graphics.setColor(0.18, 0.09, 0.04)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.12, 0.06, 0.02)
            love.graphics.setLineWidth(2)
            love.graphics.line(w.x+6,       w.y+4,       w.x+w.w*0.7, w.y+w.h-5)
            love.graphics.line(w.x+w.w-8,   w.y+5,       w.x+w.w*0.2, w.y+w.h-4)
            love.graphics.line(w.x+4,       w.y+w.h*0.5, w.x+w.w-5,   w.y+w.h*0.6)

        elseif w.hp == 1 then
            love.graphics.setColor(0.65, 0.20, 0.05)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        elseif w.hp == 2 then
            love.graphics.setColor(1.0, 0.50, 0.18)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        else
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function MapVolcano.drawAbove()
    love.graphics.setColor(1, 1, 1)
end

-- ── API de colisión ────────────────────────────────────────────
function MapVolcano.getWalls()   return walls   end
function MapVolcano.getRivers()  return rivers  end
function MapVolcano.getBridges() return bridges end

function MapVolcano.bulletHit(x, y)
    for _, w in ipairs(walls) do
        if x >= w.x and x <= w.x+w.w and y >= w.y and y <= w.y+w.h then
            if w.dest then
                if w.hp > 0 then w.hp = w.hp - 1; return true end
            else return true end
        end
    end
    return false
end

function MapVolcano.isBlocked(x, y)
    for _, w in ipairs(walls) do
        if not (w.dest and w.hp <= 0) then
            if x >= w.x and x <= w.x+w.w and y >= w.y and y <= w.y+w.h then
                return true
            end
        end
    end
    for _, r in ipairs(rivers) do
        if x >= r.x and x <= r.x+r.w and y >= r.y and y <= r.y+r.h then
            for _, b in ipairs(bridges) do
                if x >= b.x and x <= b.x+b.w and y >= b.y and y <= b.y+b.h then
                    return false
                end
            end
            return true
        end
    end
    return false
end

return MapVolcano
