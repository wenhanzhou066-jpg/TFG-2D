-- systems/map.lua
-- Mapa: terreno, ríos, puentes, carreteras,
-- muros sólidos, edificios destruibles y cobertura.
-- Fondo y elementos visuales con assets PNG.

local Map = {}

local W, H = 1920, 1080

-- ── Sprites PNG ────────────────────────────────────────────────
local imgs = {}

-- ── Paleta (solo para edificios destruibles, procedural) ───────
local C = {
    wallDest = { 0.60, 0.50, 0.36 },
    wallLine = { 0.24, 0.22, 0.19 },
}

-- ── Tablas de geometría ────────────────────────────────────────
local rivers  = {}   -- {x,y,w,h}
local roads   = {}   -- {x,y,w,h, dir="h"|"v"}
local bridges = {}   -- {x,y,w,h, dir="h"|"v"}
local walls   = {}   -- {x,y,w,h, dest=bool, hp, sprite?}
local covers  = {}   -- {x,y,w,h, sprite}

-- ── Constantes de diseño ───────────────────────────────────────
local RW   = 68     -- ancho de carretera
local RY   = 490    -- Y inicio del río central
local RH   = 80     -- alto del río central

-- Posiciones X de los 3 puentes
local BR = {
    { x = 270,  w = 110 },
    { x = 905,  w = 110 },
    { x = 1540, w = 110 },
}

-- ── Helpers de tiling ──────────────────────────────────────────
-- Tila img horizontalmente escalada a la altura rh, recortada a (rx,ry,rw,rh)
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

-- Tila img verticalmente escalada al ancho rw, recortada a (rx,ry,rw,rh)
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

-- Escala img para rellenar exactamente (rx,ry,rw,rh)
local function drawFit(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.draw(img, rx, ry, 0, rw / iw, rh / ih)
end

-- ── Carga ──────────────────────────────────────────────────────
function Map.load()
    -- Limpiar tablas (permite recargar al cambiar de mapa)
    rivers, roads, bridges, walls, covers = {}, {}, {}, {}, {}

    local p = "assets/images/PNG/game_background_4/layers/"

    imgs.bg     = love.graphics.newImage(p .. "main_bg.png")
    imgs.bridge = love.graphics.newImage(p .. "bridge.png")
    imgs.roadH    = love.graphics.newImage(p .. "road_6.png")  -- recta horizontal
    imgs.roadV    = love.graphics.newImage(p .. "road_5.png")  -- recta vertical
    imgs.river    = love.graphics.newImage(p .. "river_1.png")
    imgs.building = love.graphics.newImage(p .. "decor_1.png") -- casa/edificio

    imgs.bushes = {}
    for i = 1, 5 do
        imgs.bushes[i] = love.graphics.newImage(p .. "bush_" .. i .. ".png")
    end
    imgs.stones = {}
    for i = 1, 5 do
        imgs.stones[i] = love.graphics.newImage(p .. "stone_" .. i .. ".png")
    end

    -- ══ RÍO CENTRAL (horizontal) ══════════════════════════════
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

    road(0,   80,  W,  RW, "h")
    road(0,   920, W,  RW, "h")
    for _, b in ipairs(BR) do
        road(b.x, RY + math.floor((RH-RW)/2), b.w, RW, "h")
    end
    for _, b in ipairs(BR) do
        local bx = b.x + math.floor((b.w - RW) / 2)
        road(bx, 80+RW,  RW, RY - (80+RW),   "v")
        road(bx, RY+RH,  RW, 920 - (RY+RH),  "v")
    end

    -- ══ MUROS SÓLIDOS (indestructibles) ══════════════════════
    local function wall(x, y, w, h)
        walls[#walls+1] = { x=x, y=y, w=w, h=h, dest=false, hp=0 }
    end
    local function dest(x, y, w, h)
        walls[#walls+1] = { x=x, y=y, w=w, h=h, dest=true,  hp=3 }
    end

    -- Bunkers en esquinas
    wall(60,   60,  90, 70)    wall(1770,  60,  90, 70)
    wall(60,  950,  90, 70)    wall(1770, 950,  90, 70)
    -- Bloques zona norte
    wall(520,  170, 90, 70)    wall(1310, 170,  90, 70)
    wall(520,  350, 70, 90)    wall(1310, 350,  70, 90)
    -- Bloques zona sur
    wall(520,  800, 90, 70)    wall(1310, 800,  90, 70)
    wall(520,  660, 70, 90)    wall(1310, 660,  70, 90)
    -- Muros laterales largos
    wall(140,  200, 20, 280)   wall(1760, 200,  20, 280)
    wall(140,  600, 20, 280)   wall(1760, 600,  20, 280)
    -- Bloques centrales norte y sur
    wall(760,  200, 80, 70)    wall(1080, 200,  80, 70)
    wall(760,  810, 80, 70)    wall(1080, 810,  80, 70)

    -- ══ EDIFICIOS DESTRUIBLES ═════════════════════════════════
    dest(680,  310, 100, 75)   dest(1140, 310, 100, 75)
    dest(850,  250,  80, 65)   dest(990,  250,  80, 65)
    dest(680,  700, 100, 75)   dest(1140, 700, 100, 75)
    dest(850,  765,  80, 65)   dest(990,  765,  80, 65)

    -- ══ COBERTURA (arbustos) ══════════════════════════════════
    local function cover(x, y, w, h)
        covers[#covers+1] = { x=x, y=y, w=w, h=h }
    end

    for i = 0, 5 do
        cover(120 + i*300, 160, 55, 35)
        cover(120 + i*300, 885, 55, 35)
    end
    for i = 0, 2 do
        cover(60,   250 + i*200, 45, 32)
        cover(1815, 250 + i*200, 45, 32)
    end
    cover(610,  280, 52, 35)   cover(1258, 280, 52, 35)
    cover(810,  370, 52, 35)   cover(1058, 370, 52, 35)
    cover(610,  740, 52, 35)   cover(1258, 740, 52, 35)
    cover(810,  650, 52, 35)   cover(1058, 650, 52, 35)
    for _, b in ipairs(BR) do
        cover(b.x - 70,       RY - 55,       55, 35)
        cover(b.x + b.w + 15, RY - 55,       55, 35)
        cover(b.x - 70,       RY + RH + 20,  55, 35)
        cover(b.x + b.w + 15, RY + RH + 20,  55, 35)
    end

    -- ── Asignar sprites (cíclico, reproducible) ───────────────
    local si = 0
    for _, w in ipairs(walls) do
        if not w.dest then
            w.sprite = imgs.stones[si % 5 + 1]
            si = si + 1
        else
            w.sprite = imgs.building   -- edificio destruible
        end
    end
    local bi = 0
    for _, c in ipairs(covers) do
        c.sprite = imgs.bushes[bi % 5 + 1]
        bi = bi + 1
    end
end

-- ── Draw layers ────────────────────────────────────────────────
function Map.drawGround()
    -- 1. Fondo PNG (1920×1080 exacto)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.bg, 0, 0)

    -- 2. Ríos (tiles horizontales de agua)
    love.graphics.setColor(1, 1, 1)
    for _, r in ipairs(rivers) do
        drawTiledH(imgs.river, r.x, r.y, r.w, r.h)
    end

    -- 3. Carreteras (tiles)
    love.graphics.setColor(1, 1, 1)
    for _, r in ipairs(roads) do
        if r.dir == "h" then
            drawTiledH(imgs.roadH, r.x, r.y, r.w, r.h)
        else
            drawTiledV(imgs.roadV, r.x, r.y, r.w, r.h)
        end
    end

    -- 4. Puentes (encima del río y la carretera; el tanque pasa POR ENCIMA)
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(bridges) do
        drawFit(imgs.bridge, b.x, b.y, b.w, b.h)
    end

    -- 5. Coberturas (sprites de arbusto)
    love.graphics.setColor(1, 1, 1)
    for _, c in ipairs(covers) do
        drawFit(c.sprite, c.x, c.y, c.w, c.h)
    end

    -- 7. Muros sólidos (sprites de piedra) y edificios destruibles (sprite + tint)
    for _, w in ipairs(walls) do
        if not w.dest then
            -- ── Indestructible: sprite de piedra ──────────────
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)

        elseif w.hp <= 0 then
            -- ── Fase 4: ESCOMBROS (procedural) ────────────────
            love.graphics.setColor(0.26, 0.21, 0.14)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.20, 0.16, 0.10)
            love.graphics.setLineWidth(2)
            love.graphics.line(w.x+6,       w.y+4,       w.x+w.w*0.7, w.y+w.h-5)
            love.graphics.line(w.x+w.w-8,   w.y+5,       w.x+w.w*0.2, w.y+w.h-4)
            love.graphics.line(w.x+4,       w.y+w.h*0.5, w.x+w.w-5,   w.y+w.h*0.6)

        elseif w.hp == 1 then
            -- ── Fase 3: ARDIENDO (tint rojo oscuro + sombra) ──
            love.graphics.setColor(0.60, 0.28, 0.18)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.0, 0.0, 0.0, 0.50)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        elseif w.hp == 2 then
            -- ── Fase 2: DAÑADO (tint naranja fuego) ───────────
            love.graphics.setColor(1.0, 0.65, 0.35)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.0, 0.0, 0.0, 0.22)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        else
            -- ── Fase 1: INTACTO (sprite normal) ───────────────
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function Map.drawAbove()
    -- Reservado para elementos que van encima del tanque (árboles, etc.)
    love.graphics.setColor(1, 1, 1)
end

-- ── API de colisión ────────────────────────────────────────────
function Map.getWalls()   return walls   end
function Map.getRivers()  return rivers  end
function Map.getBridges() return bridges end

function Map.bulletHit(x, y)
    for _, w in ipairs(walls) do
        if x >= w.x and x <= w.x+w.w and y >= w.y and y <= w.y+w.h then
            if w.dest then
                if w.hp > 0 then
                    w.hp = w.hp - 1
                    return true
                end
            else
                return true
            end
        end
    end
    return false
end

function Map.isBlocked(x, y)
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

return Map
