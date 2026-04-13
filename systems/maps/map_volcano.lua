-- systems/map_volcano.lua
-- Mapa volcánico: lava central, 2 puentes (cruce peligroso), layout asimétrico.
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
    { x = 390,  w = 110 },
    { x = 1420, w = 110 },
}

-- ── Puntos de spawn ───────────────────────────────────────────
local spawns = {
    { x = 170,  y = 180 },  -- NW
    { x = 1750, y = 180 },  -- NE
    { x = 170,  y = 900 },  -- SW
    { x = 1750, y = 900 },  -- SE
}

local powerupSpawns = {
    {type="health", x=960,  y=300},   -- Centro norte
    {type="health", x=960,  y=780},   -- Centro sur
    {type="speed",  x=400,  y=540},   -- Oeste centro
    {type="ammo",   x=1520, y=540},   -- Este centro
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
    imgs.building = love.graphics.newImage(p .. "decor_2.png")
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

    -- Perimetro horizontal
    road(0,  60, W, RW, "h")
    road(0, 952, W, RW, "h")

    -- Flanco izquierdo vertical (2 segmentos por el río)
    road(76, 128, RW, RY - 128,       "v")
    road(76, RY+RH, RW, 952-(RY+RH),  "v")

    -- Flanco derecho vertical
    road(1776, 128, RW, RY - 128,     "v")
    road(1776, RY+RH, RW, 952-(RY+RH),"v")

    -- Carretera sobre puentes
    for _, b in ipairs(BR) do
        road(b.x, RY + math.floor((RH-RW)/2), b.w, RW, "h")
    end

    -- Conectores verticales norte y sur en cada puente
    for _, b in ipairs(BR) do
        local bx = b.x + math.floor((b.w - RW) / 2)
        road(bx, 128,   RW, RY - 128,       "v")
        road(bx, RY+RH, RW, 952 - (RY+RH),  "v")
    end

    -- Carretera transversal en zona centro-norte (asimetría táctica)
    road(500, 295, 920, RW, "h")   -- sólo en norte, crea zona de control lateral

    -- ══ MUROS SÓLIDOS ══════════════════════════════════════════
    local function wall(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=false,hp=0} end
    local function dest(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=true, hp=3} end

    -- Bastiones en esquinas
    wall(40,  40, 90, 75)    wall(1790, 40,  90, 75)
    wall(40,  965, 90, 75)   wall(1790, 965, 90, 75)

    -- Escudos de flanco
    wall(155, 210, 18, 230)  wall(1747, 210, 18, 230)  -- norte
    wall(155, 620, 18, 235)  wall(1747, 620, 18, 235)  -- sur

    -- Zona norte: control de puentes (asimétrico)
    -- Puente izquierdo (x=390): más protegido con muros extra
    wall(200, 200, 80, 65)   -- guardia oeste del puente izq.
    wall(200, 405, 80, 65)   -- guardia sobre lava, oeste
    wall(315, 178, 60, 95)   -- bloqueo del carril interno norte
    -- Centro norte (puentes más separados → espacio central abierto)
    wall(770, 195, 95, 70)   wall(1055, 195, 95, 70)
    wall(770, 390, 70, 95)   wall(1055, 390, 70, 95)
    -- Puente derecho (x=1420): menos protegido (jugadores deben elegir)
    wall(1640, 200, 80, 65)
    wall(1640, 405, 80, 65)

    -- Zona sur (más abierta, más peligrosa)
    wall(200, 810, 80, 65)   wall(1640, 810, 80, 65)
    wall(200, 615, 80, 65)   wall(1640, 615, 80, 65)
    wall(770, 810, 95, 70)   wall(1055, 810, 95, 70)
    wall(770, 615, 70, 95)   wall(1055, 615, 70, 95)
    -- Bloqueo extra sur-derecha (asimetría)
    wall(1330, 830, 65, 90)

    -- ══ EDIFICIOS DESTRUIBLES (10) ════════════════════════════
    -- Norte
    dest(600,  295, 110, 80)  dest(1210, 295, 110, 80)
    dest(385,  160,  90, 65)  dest(1470, 160,  90, 65)
    dest(870,  240,  90, 70)  dest(960,  240,  90, 70)
    -- Sur
    dest(600,  700, 110, 80)  dest(1210, 700, 110, 80)
    dest(385,  855,  90, 65)  dest(1470, 855,  90, 65)

    -- ══ COBERTURA (rocas volcánicas) ══════════════════════════
    local function cover(x, y, w, h) covers[#covers+1]={x=x,y=y,w=w,h=h} end

    for i = 0, 5 do
        cover(210 + i*255, 125, 52, 38)
        cover(210 + i*255, 917, 52, 38)
    end
    for i = 0, 3 do
        cover(152, 215 + i*163, 48, 38)
        cover(1720, 215 + i*163, 48, 38)
    end
    cover(550, 260, 52, 38)   cover(1318, 260, 52, 38)
    cover(780, 370, 52, 38)   cover(1088, 370, 52, 38)
    cover(550, 755, 52, 38)   cover(1318, 755, 52, 38)
    cover(780, 660, 52, 38)   cover(1088, 660, 52, 38)
    for _, b in ipairs(BR) do
        cover(b.x - 75, RY - 65, 52, 38)
        cover(b.x + b.w + 20, RY - 65, 52, 38)
        cover(b.x - 75, RY + RH + 22, 52, 38)
        cover(b.x + b.w + 20, RY + RH + 22, 52, 38)
    end
    -- Cobertura en zona transversal norte
    cover(500, 270, 50, 36)   cover(730, 270, 50, 36)
    cover(1100, 270, 50, 36)  cover(1380, 270, 50, 36)

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

    -- Lava
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

    -- Puentes
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(bridges) do
        drawFit(imgs.bridge, b.x, b.y, b.w, b.h)
    end

    -- Coberturas
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

-- ── API de colisión y spawn ────────────────────────────────────
function MapVolcano.getWalls()   return walls   end
function MapVolcano.getRivers()  return rivers  end
function MapVolcano.getBridges() return bridges end
function MapVolcano.getSpawns()  return spawns  end
function MapVolcano.getPowerupSpawns() return powerupSpawns end

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
