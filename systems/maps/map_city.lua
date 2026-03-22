-- systems/map_city.lua
-- Mapa: Ciudad. Sin río. Grid de carreteras, bloques urbanos con edificios
-- destruibles y muros de hormigón. Activos del pack game_background_2.

local MapCity = {}

local W, H = 1920, 1080

local imgs = {}

-- ── Tablas de geometría ────────────────────────────────────────
local rivers  = {}   -- vacío: no hay río en este mapa
local roads   = {}
local bridges = {}   -- vacío: no hay puentes
local walls   = {}
local covers  = {}

-- ── Puntos de spawn ───────────────────────────────────────────
local spawns = {
    { x = 170,  y = 180 },  -- NW
    { x = 1750, y = 180 },  -- NE
    { x = 170,  y = 900 },  -- SW
    { x = 1750, y = 900 },  -- SE
}

-- ── Constantes de diseño ───────────────────────────────────────
local RW = 68   -- ancho de carretera

-- Grid: 3 horizontales + 3 verticales → 6 bloques urbanos
local RY_MID = 490   -- carretera horizontal central
local RX_L   = 76    -- carretera vertical izquierda
local RX_C   = 926   -- carretera vertical central (centro del mapa)
local RX_R   = 1776  -- carretera vertical derecha

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
function MapCity.load()
    rivers, roads, bridges, walls, covers = {}, {}, {}, {}, {}

    local p = "assets/images/PNG/game_background_2/layers/"

    imgs.bg    = love.graphics.newImage(p .. "main_bg.png")
    imgs.roadH = love.graphics.newImage(p .. "road_6.png")
    imgs.roadV = love.graphics.newImage(p .. "road_5.png")

    imgs.buildings = {}
    for i = 1, 9 do
        imgs.buildings[i] = love.graphics.newImage(p .. "decor_" .. i .. ".png")
    end
    imgs.stones = {}
    for i = 1, 9 do
        imgs.stones[i] = love.graphics.newImage(p .. "stone_" .. i .. ".png")
    end

    -- ══ RED DE CARRETERAS (grid urbano) ══════════════════════
    local function road(x, y, w, h, dir)
        roads[#roads+1] = { x=x, y=y, w=w, h=h, dir=dir }
    end

    -- Horizontales: superior, central, inferior
    road(0,   80,  W, RW, "h")   -- perimetro norte
    road(0,  RY_MID, W, RW, "h") -- eje central
    road(0,  932, W, RW, "h")    -- perimetro sur

    -- Verticales: izquierda, centro, derecha (full height)
    road(RX_L, 148, RW, 932-148, "v")   -- flanco izq.
    road(RX_C, 148, RW, 932-148, "v")   -- eje central
    road(RX_R, 148, RW, 932-148, "v")   -- flanco der.

    -- Carriles diagonales-horizontales extra (varían la táctica dentro de cada bloque)
    -- Bloque NW: corredor interno
    road(220, 295, RX_C - 220, RW, "h")
    -- Bloque NE: corredor interno (distinto Y para asimetría)
    road(RX_C + RW, 215, RX_R - (RX_C+RW), RW, "h")
    -- Bloque SW: corredor interno
    road(220, 750, RX_C - 220, RW, "h")
    -- Bloque SE: corredor interno
    road(RX_C + RW, 820, RX_R - (RX_C+RW), RW, "h")

    -- ══ MUROS SÓLIDOS ══════════════════════════════════════════
    local function wall(x, y, w, h)
        walls[#walls+1] = { x=x, y=y, w=w, h=h, dest=false, hp=0 }
    end
    local function dest(x, y, w, h)
        walls[#walls+1] = { x=x, y=y, w=w, h=h, dest=true,  hp=3 }
    end

    -- Bastiones en 4 esquinas
    wall(40,   40,  85, 70)    wall(1795,  40,  85, 70)
    wall(40,  970,  85, 70)    wall(1795, 970,  85, 70)

    -- ── BLOQUE NOROESTE (x: 144→926, y: 148→490) ──
    -- Manzana norte NW: muros en L formando esquina protegida
    wall(220, 195, 110, 75)    -- pared norte de la manzana
    wall(220, 270,  18, 130)   -- pared oeste (vertical)
    wall(370, 195,  18, 185)   -- pared este (conecta al corredor)
    -- Manzana sur NW (sobre corredor y=295): bloque bajo
    wall(220, 390, 100, 70)

    -- ── BLOQUE NORESTE (x: 994→1776, y: 148→490) ──
    -- Manzana norte NE: configuración diferente (L invertida)
    wall(1610, 195, 100, 75)   -- pared norte
    wall(1692, 270,  18, 130)  -- pared este
    wall(1540, 195,  18, 180)  -- pared oeste
    -- Manzana sur NE
    wall(1610, 390, 100, 65)

    -- ── BLOQUE CENTRAL NORTE (x: 144→926 y x: 994→1776, franja central) ──
    -- Control del cruce central: bloques a ambos lados del eje central
    wall(820, 200, 90, 65)    wall(1010, 200, 90, 65)
    wall(820, 410, 70, 80)    wall(1010, 410, 70, 80)

    -- ── BLOQUE SUROESTE (x: 144→926, y: 558→932) ──
    wall(220, 800, 110, 70)
    wall(220, 730,  18, 130)
    wall(370, 610,  18, 170)  -- bloque sobre corredor sur
    wall(220, 595, 100, 70)

    -- ── BLOQUE SURESTE (x: 994→1776, y: 558→932) ──
    wall(1610, 800, 100, 70)
    wall(1692, 730,  18, 130)
    wall(1540, 620,  18, 160)
    wall(1610, 605, 100, 65)

    -- ── BLOQUE CENTRAL SUR ──
    wall(820, 820, 90, 65)    wall(1010, 820, 90, 65)
    wall(820, 620, 70, 80)    wall(1010, 620, 70, 80)

    -- ══ EDIFICIOS DESTRUIBLES (12) ════════════════════════════
    -- Bloque NW
    dest(290, 175, 65, 55)    dest(490, 195, 75, 60)
    -- Bloque NE
    dest(1070, 175, 65, 55)   dest(1430, 195, 75, 60)
    -- Centro norte
    dest(530, 180, 80, 60)    dest(1310, 180, 80, 60)
    -- Bloque SW
    dest(290, 855, 65, 55)    dest(490, 825, 75, 60)
    -- Bloque SE
    dest(1070, 855, 65, 55)   dest(1430, 825, 75, 60)
    -- Centro sur
    dest(530, 860, 80, 60)    dest(1310, 860, 80, 60)

    -- ══ COBERTURA (escombros urbanos) ════════════════════════
    local function cover(x, y, w, h)
        covers[#covers+1] = { x=x, y=y, w=w, h=h }
    end

    -- Bordes de mapa junto a carretera perimetral
    for i = 0, 5 do
        cover(210 + i*255, 151, 52, 32)
        cover(210 + i*255, 897, 52, 32)
    end

    -- Zona de spawn (cobertura próxima para salida segura)
    cover(158, 151, 46, 32)   cover(1716, 151, 46, 32)
    cover(158, 900, 46, 32)   cover(1716, 900, 46, 32)

    -- Intersecciones clave del grid (cobertura en cruces de carretera)
    -- Cruce NW: eje central x con horizontal 295
    cover(870, 270, 46, 32)   cover(960, 270, 46, 32)
    -- Cruce NE
    cover(870, 192, 46, 32)   cover(960, 192, 46, 32)
    -- Cruce SW
    cover(870, 730, 46, 32)   cover(960, 730, 46, 32)
    -- Cruce SE
    cover(870, 800, 46, 32)   cover(960, 800, 46, 32)

    -- Flancos laterales (entre carretera y bastión)
    for i = 0, 3 do
        cover(155, 215 + i*165, 44, 32)
        cover(1721, 215 + i*165, 44, 32)
    end

    -- ── Asignar sprites ────────────────────────────────────────
    local si = 0
    for _, w in ipairs(walls) do
        if not w.dest then
            w.sprite = imgs.stones[si % 9 + 1]
            si = si + 1
        else
            w.sprite = imgs.buildings[si % 9 + 1]
            si = si + 1
        end
    end
    local ci = 0
    for _, c in ipairs(covers) do
        c.sprite = imgs.stones[ci % 9 + 1]
        ci = ci + 1
    end
end

-- ── Draw layers ────────────────────────────────────────────────
function MapCity.drawGround()
    -- 1. Fondo
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(imgs.bg, 0, 0)

    -- 2. Carreteras
    love.graphics.setColor(1, 1, 1)
    for _, r in ipairs(roads) do
        if r.dir == "h" then
            drawTiledH(imgs.roadH, r.x, r.y, r.w, r.h)
        else
            drawTiledV(imgs.roadV, r.x, r.y, r.w, r.h)
        end
    end

    -- 3. Coberturas
    love.graphics.setColor(1, 1, 1)
    for _, c in ipairs(covers) do
        drawFit(c.sprite, c.x, c.y, c.w, c.h)
    end

    -- 4. Muros y edificios destruibles
    for _, w in ipairs(walls) do
        if not w.dest then
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)

        elseif w.hp <= 0 then
            -- Escombros urbanos
            love.graphics.setColor(0.28, 0.25, 0.22)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.18, 0.16, 0.14)
            love.graphics.setLineWidth(2)
            love.graphics.line(w.x+6,       w.y+4,       w.x+w.w*0.7, w.y+w.h-5)
            love.graphics.line(w.x+w.w-8,   w.y+5,       w.x+w.w*0.2, w.y+w.h-4)
            love.graphics.line(w.x+4,       w.y+w.h*0.5, w.x+w.w-5,   w.y+w.h*0.6)

        elseif w.hp == 1 then
            love.graphics.setColor(0.60, 0.28, 0.18)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.0, 0.0, 0.0, 0.52)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        elseif w.hp == 2 then
            love.graphics.setColor(1.0, 0.65, 0.35)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.0, 0.0, 0.0, 0.22)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)

        else
            love.graphics.setColor(1, 1, 1)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function MapCity.drawAbove()
    love.graphics.setColor(1, 1, 1)
end

-- ── API de colisión y spawn ────────────────────────────────────
function MapCity.getWalls()   return walls   end
function MapCity.getRivers()  return rivers  end
function MapCity.getBridges() return bridges end
function MapCity.getSpawns()  return spawns  end

function MapCity.bulletHit(x, y)
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

function MapCity.isBlocked(x, y)
    for _, w in ipairs(walls) do
        if not (w.dest and w.hp <= 0) then
            if x >= w.x and x <= w.x+w.w and y >= w.y and y <= w.y+w.h then
                return true
            end
        end
    end
    -- Sin río: solo muros bloquean
    return false
end

return MapCity
