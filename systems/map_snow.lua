-- systems/map_snow.lua
-- Mapa nevado: lago helado central, pinos sobre el tanque,
-- ruinas de piedra. Activos del pack game_background_3.

local MapSnow = {}

local W, H = 1920, 1080

local imgs = {}

-- ── Paleta ─────────────────────────────────────────────────────
local C = {
    ice     = { 0.62, 0.82, 0.96 },
    iceEdge = { 0.38, 0.58, 0.80 },
}

-- ── Tablas de geometría ────────────────────────────────────────
local rivers   = {}
local roads    = {}
local bridges  = {}
local walls    = {}
local covers   = {}
local treeDeco = {}   -- árboles dibujados encima del tanque

-- ── Constantes ────────────────────────────────────────────────
local RW = 68
local RY = 455
local RH = 95   -- lago helado (banda un poco más alta)

-- 2 pasos de hielo en los flancos (sin sprite de puente)
local BR = {
    { x = 360,  w = 110 },
    { x = 1450, w = 110 },
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

local function drawCentered(img, cx, cy, s)
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.draw(img, cx, cy, 0, s, s, iw / 2, ih / 2)
end

-- ── Carga ──────────────────────────────────────────────────────
function MapSnow.load()
    rivers, roads, bridges, walls, covers, treeDeco = {}, {}, {}, {}, {}, {}

    local p = "assets/images/PNG/game_background_3/layers/"

    imgs.bg    = love.graphics.newImage(p .. "main_bg.png")
    imgs.lake  = love.graphics.newImage(p .. "lake.png")
    imgs.roadH = love.graphics.newImage(p .. "road_6.png")
    imgs.roadV = love.graphics.newImage(p .. "road_5.png")
    imgs.trees = {
        love.graphics.newImage(p .. "tree_1.png"),
        love.graphics.newImage(p .. "tree_2.png"),
    }
    imgs.stones = {}
    for i = 1, 7 do
        imgs.stones[i] = love.graphics.newImage(p .. "stone_" .. i .. ".png")
    end

    -- ══ LAGO HELADO (funciona como río en la colisión) ════════
    local px = 0
    for _, b in ipairs(BR) do
        if b.x > px then
            rivers[#rivers+1] = { x = px, y = RY, w = b.x - px, h = RH }
        end
        px = b.x + b.w
    end
    rivers[#rivers+1] = { x = px, y = RY, w = W - px, h = RH }

    -- ══ PASOS DE HIELO (zona de cruce sin sprite de puente) ═══
    -- El paso es ligeramente más ancho que el RW para ser visible
    for _, b in ipairs(BR) do
        bridges[#bridges+1] = { x=b.x, y=RY, w=b.w, h=RH, dir="h" }
    end

    -- ══ CARRETERAS ════════════════════════════════════════════
    local function road(x, y, w, h, dir)
        roads[#roads+1] = { x=x, y=y, w=w, h=h, dir=dir }
    end

    road(0,   80,  W, RW, "h")
    road(0,  932,  W, RW, "h")
    for _, b in ipairs(BR) do
        road(b.x, RY + math.floor((RH-RW)/2), b.w, RW, "h")
    end
    for _, b in ipairs(BR) do
        local bx = b.x + math.floor((b.w - RW) / 2)
        road(bx, 80+RW,  RW, RY - (80+RW),  "v")
        road(bx, RY+RH,  RW, 932 - (RY+RH), "v")
    end

    -- ══ MUROS SÓLIDOS (rocas nevadas) ═════════════════════════
    local function wall(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=false,hp=0} end
    local function dest(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=true, hp=3} end

    -- Bastiones en esquinas
    wall(50,   50,  90, 70)   wall(1780,  50,  90, 70)
    wall(50,  960,  90, 70)   wall(1780, 960,  90, 70)
    -- Rocas zona norte
    wall(580,  185,  80, 65)  wall(1260, 185,  80, 65)
    wall(580,  375,  65, 80)  wall(1260, 375,  65, 80)
    -- Rocas zona sur
    wall(580,  820,  80, 65)  wall(1260, 820,  80, 65)
    wall(580,  635,  65, 80)  wall(1260, 635,  65, 80)
    -- Muros laterales
    wall(135, 190, 20, 280)   wall(1765, 190, 20, 280)
    wall(135, 610, 20, 280)   wall(1765, 610, 20, 280)
    -- Bloques centrales
    wall(760,  210,  85, 65)  wall(1075, 210,  85, 65)
    wall(760,  810,  85, 65)  wall(1075, 810,  85, 65)

    -- ══ RUINAS DESTRUIBLES (montones de nieve/piedra) ═════════
    dest(660,  295, 100, 75)  dest(1160, 295, 100, 75)
    dest(840,  240,  85, 65)  dest(995,  240,  85, 65)
    dest(660,  710, 100, 75)  dest(1160, 710, 100, 75)
    dest(840,  775,  85, 65)  dest(995,  775,  85, 65)

    -- ══ COBERTURA (piedras nevadas pequeñas) ══════════════════
    local function cover(x, y, w, h) covers[#covers+1]={x=x,y=y,w=w,h=h} end

    for i = 0, 5 do
        cover(120 + i*300, 158, 55, 40)
        cover(120 + i*300, 882, 55, 40)
    end
    for i = 0, 2 do
        cover(58,  255 + i*205, 50, 38)
        cover(1812,255 + i*205, 50, 38)
    end
    cover(615, 270, 55, 40)  cover(1250, 270, 55, 40)
    cover(800, 360, 55, 40)  cover(1065, 360, 55, 40)
    cover(615, 745, 55, 40)  cover(1250, 745, 55, 40)
    cover(800, 655, 55, 40)  cover(1065, 655, 55, 40)
    for _, b in ipairs(BR) do
        cover(b.x - 75, RY - 60, 55, 40)
        cover(b.x + b.w + 20, RY - 60, 55, 40)
        cover(b.x - 75, RY + RH + 20, 55, 40)
        cover(b.x + b.w + 20, RY + RH + 20, 55, 40)
    end

    -- ══ ÁRBOLES DECORATIVOS (se dibujan encima del tanque) ════
    local function tree(x, y, s, v)
        treeDeco[#treeDeco+1] = { x=x, y=y, s=s, img=imgs.trees[v] }
    end

    -- Bordes norte y sur
    for i = 0, 5 do
        tree( 60 + i*170,  20, 0.42, 1)
        tree( 60 + i*170, 1058, 0.42, 2)
        tree(960 + i*170,  20, 0.38, 2)
        tree(960 + i*170, 1058, 0.38, 1)
    end
    -- Flancos izquierdo y derecho
    for i = 0, 3 do
        tree( 20, 150 + i*220, 0.40, 1)
        tree(1900,150 + i*220, 0.40, 2)
    end
    -- Zona de combate (árboles que crean línea de visión limitada)
    tree(500, 330, 0.36, 2)   tree(1420, 330, 0.36, 1)
    tree(500, 740, 0.36, 1)   tree(1420, 740, 0.36, 2)
    tree(720, 430, 0.34, 2)   tree(1200, 430, 0.34, 1)
    tree(720, 650, 0.34, 1)   tree(1200, 650, 0.34, 2)

    -- ── Asignar sprites ────────────────────────────────────────
    local si = 0
    for _, w in ipairs(walls) do
        if not w.dest then
            w.sprite = imgs.stones[si % 7 + 1]
            si = si + 1
        else
            -- Ruinas: stone_3 o stone_1 (montones de nieve más grandes)
            w.sprite = imgs.stones[(si % 2) + 1]
            si = si + 1
        end
    end
    local ci = 0
    for _, c in ipairs(covers) do
        c.sprite = imgs.stones[ci % 3 + 1]
        ci = ci + 1
    end
end

-- ── Draw layers ────────────────────────────────────────────────
function MapSnow.drawGround()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.bg, 0, 0)

    -- Lago helado (fill azul hielo)
    for _, r in ipairs(rivers) do
        love.graphics.setColor(C.ice)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        love.graphics.setColor(C.iceEdge)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    end

    -- Sprite del lago como decoración central (entre los 2 puentes)
    love.graphics.setColor(1, 1, 1)
    local lakeImg = imgs.lake
    local lakeTargetW = 940
    local lakeTargetH = 110
    local ls = math.min(lakeTargetW / lakeImg:getWidth(),
                        lakeTargetH / lakeImg:getHeight())
    drawCentered(lakeImg, W / 2, RY + RH / 2, ls)

    -- Pasos de hielo: road tiles sobre el lago (sin bridge sprite)
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(bridges) do
        local ry = b.y + math.floor((b.h - RW) / 2)
        drawTiledH(imgs.roadH, b.x, ry, b.w, RW)
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

    -- Coberturas (rocas nevadas)
    love.graphics.setColor(1, 1, 1)
    for _, c in ipairs(covers) do
        drawFit(c.sprite, c.x, c.y, c.w, c.h)
    end

    -- Muros y ruinas
    for _, w in ipairs(walls) do
        if not w.dest then
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)

        elseif w.hp <= 0 then
            -- Escombros de nieve/piedra
            love.graphics.setColor(0.55, 0.62, 0.68)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.35, 0.40, 0.48)
            love.graphics.setLineWidth(2)
            love.graphics.line(w.x+6,       w.y+4,       w.x+w.w*0.7, w.y+w.h-5)
            love.graphics.line(w.x+w.w-8,   w.y+5,       w.x+w.w*0.2, w.y+w.h-4)
            love.graphics.line(w.x+4,       w.y+w.h*0.5, w.x+w.w-5,   w.y+w.h*0.6)

        elseif w.hp == 1 then
            love.graphics.setColor(0.72, 0.82, 0.92)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.48)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        elseif w.hp == 2 then
            love.graphics.setColor(0.88, 0.94, 1.0)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.20)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        else
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function MapSnow.drawAbove()
    -- Árboles de pino encima del tanque (efecto de profundidad)
    love.graphics.setColor(1, 1, 1)
    for _, t in ipairs(treeDeco) do
        drawCentered(t.img, t.x, t.y, t.s)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ── API de colisión ────────────────────────────────────────────
function MapSnow.getWalls()   return walls   end
function MapSnow.getRivers()  return rivers  end
function MapSnow.getBridges() return bridges end

function MapSnow.bulletHit(x, y)
    for _, w in ipairs(walls) do
        if x >= w.x and x <= w.x+w.w and y >= w.y and y <= w.y+w.h then
            if w.dest then
                if w.hp > 0 then w.hp = w.hp - 1; return true end
            else return true end
        end
    end
    return false
end

function MapSnow.isBlocked(x, y)
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

return MapSnow
