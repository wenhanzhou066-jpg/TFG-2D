-- systems/map_snow.lua
-- Mapa nevado: lago helado central, pinos sobre el tanque, ruinas de piedra.
-- Red perimetral de carreteras + 2 pasos de hielo en los flancos.
-- Activos del pack game_background_3.

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
local treeDeco = {}

-- ── Constantes ────────────────────────────────────────────────
local RW = 68
local RY = 455
local RH = 95

-- 2 pasos de hielo en los flancos
local BR = {
    { x = 320,  w = 110 },
    { x = 1490, w = 110 },
}

-- ── Puntos de spawn ───────────────────────────────────────────
local spawns = {
    { x = 170,  y = 185 },  -- NW
    { x = 1750, y = 185 },  -- NE
    { x = 170,  y = 895 },  -- SW
    { x = 1750, y = 895 },  -- SE
}

local powerupSpawns = {
    {type="health", x=960,  y=300},   -- Centro norte
    {type="health", x=960,  y=780},   -- Centro sur
    {type="shield", x=400,  y=540},   -- Oeste centro
    {type="speed",  x=1520, y=540},   -- Este centro
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

    -- ══ LAGO HELADO ═══════════════════════════════════════════
    local px = 0
    for _, b in ipairs(BR) do
        if b.x > px then
            rivers[#rivers+1] = { x = px, y = RY, w = b.x - px, h = RH }
        end
        px = b.x + b.w
    end
    rivers[#rivers+1] = { x = px, y = RY, w = W - px, h = RH }

    -- ══ PASOS DE HIELO ════════════════════════════════════════
    for _, b in ipairs(BR) do
        bridges[#bridges+1] = { x=b.x, y=RY, w=b.w, h=RH, dir="h" }
    end

    -- ══ CARRETERAS ════════════════════════════════════════════
    local function road(x, y, w, h, dir)
        roads[#roads+1] = { x=x, y=y, w=w, h=h, dir=dir }
    end

    -- Perimetro horizontal
    road(0,  80, W, RW, "h")
    road(0, 932, W, RW, "h")

    -- Flancos verticales
    road(76, 148, RW, RY - 148,       "v")
    road(76, RY+RH, RW, 932-(RY+RH),  "v")
    road(1776, 148, RW, RY - 148,     "v")
    road(1776, RY+RH, RW, 932-(RY+RH),"v")

    -- Pasos sobre el hielo
    for _, b in ipairs(BR) do
        local ry = b.y + math.floor((b.h - RW) / 2)
        road(b.x, ry, b.w, RW, "h")
    end

    -- Conectores verticales norte y sur en cada paso
    for _, b in ipairs(BR) do
        local bx = b.x + math.floor((b.w - RW) / 2)
        road(bx, 148,   RW, RY - 148,       "v")
        road(bx, RY+RH, RW, 932 - (RY+RH),  "v")
    end

    -- Carretera diagonal-horizontal en zona sur (diferencia táctica con norte)
    road(600, 720, 720, RW, "h")   -- corredor sur adicional

    -- ══ MUROS SÓLIDOS ══════════════════════════════════════════
    local function wall(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=false,hp=0} end
    local function dest(x, y, w, h) walls[#walls+1]={x=x,y=y,w=w,h=h,dest=true, hp=3} end

    -- Bastiones en esquinas
    wall(45,  45,  85, 70)    wall(1790, 45,  85, 70)
    wall(45,  965, 85, 70)    wall(1790, 965, 85, 70)

    -- Escudos de flanco
    wall(155, 220, 18, 225)   wall(1747, 220, 18, 225)  -- norte
    wall(155, 625, 18, 230)   wall(1747, 625, 18, 230)  -- sur

    -- Zona norte: control del paso de hielo izquierdo (x=320)
    wall(195, 205, 80, 65)    -- guardia oeste
    wall(195, 400, 80, 60)    -- guardia sobre lago

    -- Zona norte: bloques centrales (amplio lago central sin paso)
    wall(700,  205, 90, 70)   wall(1130, 205, 90, 70)
    wall(700,  390, 70, 90)   wall(1130, 390, 70, 90)
    wall(920,  175, 80, 65)   -- bloque central norte (control del lago)

    -- Zona norte: control del paso de hielo derecho (x=1490)
    wall(1645, 205, 80, 65)
    wall(1645, 400, 80, 60)

    -- Zona sur (más abierta, más agresiva)
    wall(195,  810, 80, 65)   wall(1645, 810, 80, 65)
    wall(195,  620, 80, 60)   wall(1645, 620, 80, 60)
    wall(700,  810, 90, 70)   wall(1130, 810, 90, 70)
    wall(700,  615, 70, 90)   wall(1130, 615, 70, 90)

    -- ══ RUINAS DESTRUIBLES (10) ══════════════════════════════
    -- Norte
    dest(660,  295, 100, 75)  dest(1160, 295, 100, 75)
    dest(370,  165,  85, 65)  dest(1465, 165,  85, 65)
    dest(860,  240,  85, 65)  dest(975,  240,  85, 65)
    -- Sur
    dest(660,  710, 100, 75)  dest(1160, 710, 100, 75)
    dest(370,  855,  85, 65)  dest(1465, 855,  85, 65)

    -- ══ COBERTURA (piedras nevadas) ════════════════════════════
    local function cover(x, y, w, h) covers[#covers+1]={x=x,y=y,w=w,h=h} end

    for i = 0, 5 do
        cover(210 + i*255, 152, 55, 40)
        cover(210 + i*255, 893, 55, 40)
    end
    for i = 0, 3 do
        cover(152, 220 + i*163, 50, 38)
        cover(1718, 220 + i*163, 50, 38)
    end
    cover(620, 270, 55, 40)   cover(1245, 270, 55, 40)
    cover(810, 365, 55, 40)   cover(1055, 365, 55, 40)
    cover(620, 748, 55, 40)   cover(1245, 748, 55, 40)
    cover(810, 648, 55, 40)   cover(1055, 648, 55, 40)
    for _, b in ipairs(BR) do
        cover(b.x - 75, RY - 60, 55, 40)
        cover(b.x + b.w + 20, RY - 60, 55, 40)
        cover(b.x - 75, RY + RH + 20, 55, 40)
        cover(b.x + b.w + 20, RY + RH + 20, 55, 40)
    end
    -- Cobertura en corredor sur adicional
    cover(600, 705, 52, 38)   cover(800, 705, 52, 38)
    cover(1050, 705, 52, 38)  cover(1290, 705, 52, 38)

    -- ══ ÁRBOLES DECORATIVOS (encima del tanque) ═══════════════
    local function tree(x, y, s, v)
        treeDeco[#treeDeco+1] = { x=x, y=y, s=s, img=imgs.trees[v] }
    end

    -- Bordes norte y sur (densos)
    for i = 0, 6 do
        tree( 50 + i*145,  18, 0.42, 1)
        tree( 50 + i*145, 1062, 0.42, 2)
        tree(1000 + i*145,  18, 0.38, 2)
        tree(1000 + i*145, 1062, 0.38, 1)
    end
    -- Flancos izquierdo y derecho
    for i = 0, 4 do
        tree( 18, 140 + i*175, 0.40, 1)
        tree(1902, 140 + i*175, 0.40, 2)
    end
    -- Zona de combate: árboles que limitan línea de visión
    tree(490,  325, 0.36, 2)   tree(1430, 325, 0.36, 1)
    tree(490,  745, 0.36, 1)   tree(1430, 745, 0.36, 2)
    tree(710,  430, 0.34, 2)   tree(1210, 430, 0.34, 1)
    tree(710,  640, 0.34, 1)   tree(1210, 640, 0.34, 2)
    -- Árboles extra alrededor del lago
    tree(500,  490, 0.32, 1)   tree(1420, 490, 0.32, 2)
    tree(500,  510, 0.30, 2)   tree(1420, 510, 0.30, 1)

    -- ── Asignar sprites ────────────────────────────────────────
    local si = 0
    for _, w in ipairs(walls) do
        if not w.dest then
            w.sprite = imgs.stones[si % 7 + 1]
            si = si + 1
        else
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

    -- Lago helado
    for _, r in ipairs(rivers) do
        love.graphics.setColor(C.ice)
        love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
        love.graphics.setColor(C.iceEdge)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", r.x, r.y, r.w, r.h)
    end

    -- Sprite del lago como decoración central
    love.graphics.setColor(1, 1, 1)
    local lakeImg = imgs.lake
    local lakeTargetW = 1020
    local lakeTargetH = 110
    local ls = math.min(lakeTargetW / lakeImg:getWidth(),
                        lakeTargetH / lakeImg:getHeight())
    drawCentered(lakeImg, W / 2, RY + RH / 2, ls)

    -- Pasos de hielo (road tiles sobre el lago)
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

    -- Coberturas
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

-- ── API de colisión y spawn ────────────────────────────────────
function MapSnow.getWalls()   return walls   end
function MapSnow.getRivers()  return rivers  end
function MapSnow.getBridges() return bridges end
function MapSnow.getSpawns()  return spawns  end
function MapSnow.getPowerupSpawns() return powerupSpawns end

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
