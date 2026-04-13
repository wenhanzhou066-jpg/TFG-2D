-- systems/maps/map.lua  –  Mapa Bosque
-- Mundo 3840x2160, viewport 1920x1080 (camara sigue al tanque)
--
-- RIO DIAGONAL: de a2 (NE) a b1 (SW) en forma de Z
--   Seg A (H, NE):  x=2200..3840, y=540..635
--   V_AB (V):       x=2200..2295, y=635..1100
--   Seg B (H, mid): x=1000..2295, y=1100..1195
--   V_BC (V):       x=1000..1095, y=1195..1700
--   Seg C (H, SW):  x=0..1095,   y=1700..1795
--
-- COLISIONES: solo piedras, edificios destruibles y arboles.
-- El campo (hierba/tierra) es libremente transitable.

local Map = {}

local W, H = 3840, 2160
function Map.getSize() return {w=W, h=H} end

local RW = 86    -- ancho de via (road sprite a escala 0.5)
local CS = 128   -- tamano curva (256x256 @ 0.5)

-- Esquinas perimetrales
local TL_X, TL_Y = 0,    0
local TR_X, TR_Y = W-CS, 0
local BL_X, BL_Y = 0,    H-CS
local BR_X, BR_Y = W-CS, H-CS

-- Carreteras perimetrales
local TOP_Y   = 0
local BOT_Y   = H - RW       -- 2074
local LEFT_X  = 0
local RIGHT_X = W - RW       -- 3754

-- Carreteras internas H
local IH1_Y = 250    -- norte alto
local IH2_Y = 800    -- norte bajo  (cruza V_AB)
local IH3_Y = 1350   -- sur alto    (cruza V_BC)
local IH4_Y = 1900   -- sur bajo

-- Carreteras internas V
local IV1_X = 700    -- west   (cruza Seg C)
local IV2_X = 1500   -- c-west (cruza Seg B)
local IV3_X = 2400   -- c-east (cruza Seg A)
local IV4_X = 3200   -- east   (cruza Seg A)

-- ── Rio (5 segmentos formando diagonal NE→SW) ─────────────────
local RH = 95  -- grosor del rio

local A_X1, A_X2 = 2200, W
local A_Y1, A_Y2 = 540,  540+RH   -- 540..635

local AB_X1, AB_X2 = 2200, 2200+RH  -- 2200..2295
local AB_Y1, AB_Y2 = A_Y2, 1100     -- 635..1100

local B_X1, B_X2 = 1000, AB_X2      -- 1000..2295
local B_Y1, B_Y2 = 1100, 1100+RH    -- 1100..1195

local BC_X1, BC_X2 = 1000, 1000+RH  -- 1000..1095
local BC_Y1, BC_Y2 = B_Y2, 1700     -- 1195..1700

local C_X1, C_X2 = 0,    BC_X2      -- 0..1095
local C_Y1, C_Y2 = 1700, 1700+RH    -- 1700..1795

-- ── Spawns ────────────────────────────────────────────────────
local spawns = {
    {x=43,   y=400},   -- NW
    {x=3797, y=400},   -- NE
    {x=43,   y=1820},  -- SW
    {x=3797, y=1820},  -- SE
}

-- ── Power-up spawns ───────────────────────────────────────────
local powerupSpawns = {
    {type="health", x=1920, y=500},   -- Centro norte
    {type="health", x=1920, y=1660},  -- Centro sur
    {type="ammo",   x=800,  y=1080},  -- Oeste centro
    {type="ammo",   x=3040, y=1080},  -- Este centro
    {type="shield", x=600,  y=600},   -- NW interior
    {type="speed",  x=3240, y=1560},  -- SE interior
}

-- ── Tablas ────────────────────────────────────────────────────
local imgs        = {}
local rivers      = {}
local bridges     = {}
local walls       = {}
local covers      = {}
local skullDeco   = {}
local treeDeco    = {}
local roadPieces  = {}
local riverPieces = {}
local bridgePieces= {}

-- ── Helpers de dibujo ─────────────────────────────────────────
local function camX() return Camera and Camera.x or 0 end
local function camY() return Camera and Camera.y or 0 end

local function drawFit(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.draw(img, rx, ry, 0, rw/iw, rh/ih)
end

local function drawTiledH(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = rh / ih
    local tw = iw * sc
    love.graphics.setScissor(
        math.floor(rx - camX()), math.floor(ry - camY()),
        math.ceil(rw), math.ceil(rh))
    local x = rx
    while x < rx + rw do
        love.graphics.draw(img, math.floor(x), math.floor(ry), 0, sc, sc)
        x = x + tw
    end
    love.graphics.setScissor()
end

local function drawTiledV(img, rx, ry, rw, rh)
    local iw, ih = img:getWidth(), img:getHeight()
    local sc = rw / iw
    local th = ih * sc
    love.graphics.setScissor(
        math.floor(rx - camX()), math.floor(ry - camY()),
        math.ceil(rw), math.ceil(rh))
    local y = ry
    while y < ry + rh do
        love.graphics.draw(img, math.floor(rx), math.floor(y), 0, sc, sc)
        y = y + th
    end
    love.graphics.setScissor()
end

local function drawCentered(img, cx, cy, sc)
    local iw, ih = img:getWidth(), img:getHeight()
    love.graphics.draw(img, cx, cy, 0, sc, sc, iw/2, ih/2)
end

-- ── Carga ─────────────────────────────────────────────────────
function Map.load()
    rivers, bridges, walls, covers, skullDeco, treeDeco,
    roadPieces, riverPieces, bridgePieces = {},{},{},{},{},{},{},{},{}

    local p = "assets/images/PNG/game_background_4/layers/"
    imgs.bg     = love.graphics.newImage(p.."main_bg.png")
    imgs.bridge = love.graphics.newImage(p.."bridge.png")
    imgs.decor1 = love.graphics.newImage(p.."decor_1.png")
    imgs.decor2 = love.graphics.newImage(p.."decor_2.png")
    imgs.roads  = {}; for i=1,10 do imgs.roads[i] = love.graphics.newImage(p.."road_"..i..".png")  end
    imgs.rivs   = {}; for i=1,6  do imgs.rivs[i]  = love.graphics.newImage(p.."river_"..i..".png") end
    imgs.bushes = {}; for i=1,5  do imgs.bushes[i] = love.graphics.newImage(p.."bush_"..i..".png")  end
    imgs.stones = {}; for i=1,5  do imgs.stones[i] = love.graphics.newImage(p.."stone_"..i..".png") end
    imgs.trees  = {}; for i=1,4  do imgs.trees[i]  = love.graphics.newImage(p.."tree_"..i..".png")  end

    local function rFit(img, x, y, w, h)
        roadPieces[#roadPieces+1] = {mode="fit", img=img, x=x, y=y, w=w, h=h}
    end
    local function rH(idx, x, y, w, h)
        roadPieces[#roadPieces+1] = {mode="H", img=imgs.roads[idx], x=x, y=y, w=w, h=h}
    end
    local function rV(idx, x, y, w, h)
        roadPieces[#roadPieces+1] = {mode="V", img=imgs.roads[idx], x=x, y=y, w=w, h=h}
    end
    -- Escala uniforme para T-intersecciones (road_9: 341x260 nativo)
    local SC_RD = RW / 171
    local TJ_H  = math.floor(260 * SC_RD)   -- ≈ 130 (profundidad del T)
    local function rRot(img, cx, cy, angle)
        roadPieces[#roadPieces+1] = {mode="rot", img=img, cx=cx, cy=cy, angle=angle, sc=SC_RD}
    end
    local function rvH(idx, x, y, w, h)
        riverPieces[#riverPieces+1] = {mode="H", img=imgs.rivs[idx], x=x, y=y, w=w, h=h}
    end
    local function rvV(idx, x, y, w, h)
        riverPieces[#riverPieces+1] = {mode="V", img=imgs.rivs[idx], x=x, y=y, w=w, h=h}
    end
    -- Misma escala que los tramos rectos (river_5/6 miden 142px en el eje cruzado)
    local CRV_W = math.floor(239 * RH / 142)  -- ≈ 159
    local CRV_H = math.floor(242 * RH / 142)  -- ≈ 161

    local function rvCurve(idx, x, y)
        -- rot=-pi/2 : girar el sprite 90° a la izquierda (sentido antihorario)
        riverPieces[#riverPieces+1] = {mode="fit", img=imgs.rivs[idx], x=x, y=y, w=CRV_W, h=CRV_H, rot=-math.pi/2}
    end

    -- ── CARRETERAS ─────────────────────────────────────────────

    -- Curvas de esquina perimetrales (a1↔a2, b1↔b2 intercambiados)
    rFit(imgs.roads[1], TL_X, TL_Y, CS, CS)
    rFit(imgs.roads[2], TR_X, TR_Y, CS, CS)
    rFit(imgs.roads[3], BL_X, BL_Y, CS, CS)
    rFit(imgs.roads[4], BR_X, BR_Y, CS, CS)

    -- H perimetrales (entre esquinas)
    rH(6, CS, TOP_Y, W-2*CS, RW)
    rH(6, CS, BOT_Y, W-2*CS, RW)

    -- V perimetral izquierda: dividida en Seg C (y=1700..1795)
    rV(5, LEFT_X, CS,   RW, C_Y1 - CS)
    rV(5, LEFT_X, C_Y2, RW, (H-CS) - C_Y2)

    -- V perimetral derecha: dividida en Seg A (y=540..635)
    rV(5, RIGHT_X, CS,   RW, A_Y1 - CS)
    rV(5, RIGHT_X, A_Y2, RW, (H-CS) - A_Y2)

    -- H internas
    -- IH1 (y=250): sin cruce de rio
    rH(6, 0, IH1_Y, W, RW)

    -- IH2 (y=800): cruza V_AB (x=2200..2295)
    rH(6, 0,     IH2_Y, AB_X1,   RW)
    rH(6, AB_X2, IH2_Y, W-AB_X2, RW)

    -- IH3 (y=1350): cruza V_BC (x=1000..1095)
    rH(6, 0,     IH3_Y, BC_X1,   RW)
    rH(6, BC_X2, IH3_Y, W-BC_X2, RW)

    -- IH4 (y=1900): sin cruce de rio
    rH(6, 0, IH4_Y, W, RW)

    -- V internas: cada una dividida en su cruce con el rio
    -- IV1 (x=700): cruza Seg C (y=1700..1795)
    rV(5, IV1_X, CS,   RW, C_Y1 - CS)
    rV(5, IV1_X, C_Y2, RW, (H-CS) - C_Y2)

    -- IV2 (x=1500): cruza Seg B (y=1100..1195)
    rV(5, IV2_X, CS,   RW, B_Y1 - CS)
    rV(5, IV2_X, B_Y2, RW, (H-CS) - B_Y2)

    -- IV3 (x=2400): cruza Seg A (y=540..635)
    rV(5, IV3_X, CS,   RW, A_Y1 - CS)
    rV(5, IV3_X, A_Y2, RW, (H-CS) - A_Y2)

    -- IV4 (x=3200): cruza Seg A (y=540..635)
    rV(5, IV4_X, CS,   RW, A_Y1 - CS)
    rV(5, IV4_X, A_Y2, RW, (H-CS) - A_Y2)

    -- ── INTERSECCIONES T (road_9) ───────────────────────────────
    -- road_9 nativo: barra horizontal + tallo apuntando hacia abajo
    -- angle=pi  → tallo arriba (correcto para perimetro TOP, entra por el sur)
    -- angle=0   → tallo abajo  (correcto para perimetro BOT, entra por el norte)
    -- angle=pi/2 → tallo derecha (correcto para perimetro LEFT, entra por el este)
    -- angle=-pi/2 → tallo izquierda (correcto para perimetro RIGHT, entra por el oeste)

    -- TOP: carreteras V internas × perimetro H superior
    for _, ivx in ipairs({IV1_X, IV2_X, IV3_X, IV4_X}) do
        rRot(imgs.roads[9], ivx + RW/2, TJ_H/2, math.pi)
    end
    -- BOT: carreteras V internas × perimetro H inferior
    for _, ivx in ipairs({IV1_X, IV2_X, IV3_X, IV4_X}) do
        rRot(imgs.roads[9], ivx + RW/2, H - TJ_H/2, 0)
    end
    -- LEFT: carreteras H internas × perimetro V izquierdo
    for _, ihy in ipairs({IH1_Y, IH2_Y, IH3_Y, IH4_Y}) do
        rRot(imgs.roads[9], TJ_H/2, ihy + RW/2, math.pi/2)
    end
    -- RIGHT: carreteras H internas × perimetro V derecho
    for _, ihy in ipairs({IH1_Y, IH2_Y, IH3_Y, IH4_Y}) do
        rRot(imgs.roads[9], W - TJ_H/2, ihy + RW/2, -math.pi/2)
    end

    -- ── RIO visual ─────────────────────────────────────────────
    -- Los tramos rectos se CORTAN antes de cada curva.
    -- Seg A  →  empieza en AB_X1+CRV_W (después de la curva Bend1)
    -- V_AB   →  empieza en A_Y1+CRV_H  y termina en B_Y2-CRV_H
    -- Seg B  →  empieza en BC_X1+CRV_W y termina en AB_X2-CRV_W
    -- V_BC   →  empieza en B_Y1+CRV_H  y termina en C_Y2-CRV_H
    -- Seg C  →  termina en BC_X2-CRV_W

    local segA_x0  = AB_X1 + CRV_W        -- 2359
    local vab_y0   = A_Y1  + CRV_H        -- 701
    local vab_y1   = B_Y2  - CRV_H        -- 1034
    local segB_x0  = BC_X1 + CRV_W        -- 1159
    local segB_x1  = AB_X2 - CRV_W        -- 2136
    local vbc_y0   = B_Y1  + CRV_H        -- 1261
    local vbc_y1   = C_Y2  - CRV_H        -- 1634
    local segC_x1  = BC_X2 - CRV_W        -- 936

    -- Seg A: gaps en IV3_X, IV4_X, RIGHT_X
    local aBr = {IV3_X, IV4_X, RIGHT_X}
    local px = segA_x0
    for _, bx in ipairs(aBr) do
        if bx > px then rvH(5, px, A_Y1, bx-px, RH) end
        px = bx + RW
    end
    if px < A_X2 then rvH(5, px, A_Y1, A_X2-px, RH) end

    -- V_AB: gap en IH2_Y
    local py = vab_y0
    if IH2_Y > py then rvV(6, AB_X1, py, RH, IH2_Y-py) end
    py = IH2_Y + RW
    if py < vab_y1 then rvV(6, AB_X1, py, RH, vab_y1-py) end

    -- Seg B: gap en IV2_X
    px = segB_x0
    if IV2_X > px then rvH(5, px, B_Y1, IV2_X-px, RH) end
    px = IV2_X + RW
    if px < segB_x1 then rvH(5, px, B_Y1, segB_x1-px, RH) end

    -- V_BC: gap en IH3_Y
    py = vbc_y0
    if IH3_Y > py then rvV(6, BC_X1, py, RH, IH3_Y-py) end
    py = IH3_Y + RW
    if py < vbc_y1 then rvV(6, BC_X1, py, RH, vbc_y1-py) end

    -- Seg C: gaps en LEFT_X y IV1_X
    local cBr = {LEFT_X, IV1_X}
    px = C_X1
    for _, bx in ipairs(cBr) do
        if bx > px then rvH(5, px, C_Y1, bx-px, RH) end
        px = bx + RW
    end
    if px < segC_x1 then rvH(5, px, C_Y1, segC_x1-px, RH) end

    -- ── CURVAS DEL RIO ──────────────────────────────────────────
    -- river_2: outer-corner TOP-LEFT   → codos RIGHT→DOWN  (Bend 1 y 3)
    -- river_3: outer-corner BOTTOM-RIGHT → codos DOWN→LEFT (Bend 2 y 4)

    -- Bend 1 (NE): Seg A gira abajo en V_AB → river_2, anchor TL
    rvCurve(2, AB_X1,           A_Y1)
    -- Bend 2: V_AB gira izquierda en Seg B → river_3, anchor BR
    rvCurve(3, AB_X2 - CRV_W,  B_Y2 - CRV_H)
    -- Bend 3: Seg B gira abajo en V_BC → river_2, anchor TL
    rvCurve(2, BC_X1,           B_Y1)
    -- Bend 4 (SW): V_BC gira izquierda en Seg C → river_3, anchor BR
    rvCurve(3, BC_X2 - CRV_W,  C_Y2 - CRV_H)

    -- ── PUENTES ────────────────────────────────────────────────
    -- bridgePieces: {img, x, y, w, h}  → drawFit(img, x, y, w, h)
    -- H-bridge (V road sobre H river): w=RW, h=RH
    -- V-bridge (H road sobre V connector): w=RH, h=RW

    -- rot=0: puente horizontal (H-road sobre V-river, sprite nativo paisaje)
    -- rot=1: puente vertical   (V-road sobre H-river, sprite rotado 90°)
    local function addBridge(bx, by, bw, bh, rot)
        bridgePieces[#bridgePieces+1] = {img=imgs.bridge, x=bx, y=by, w=bw, h=bh, rot=rot or 0}
        bridges[#bridges+1] = {x=bx, y=by, w=bw, h=bh}
    end

    -- V roads sobre Seg A (carretera vertical cruza rio horizontal → rot=1)
    addBridge(IV3_X,   A_Y1, RW, RH, 1)
    addBridge(IV4_X,   A_Y1, RW, RH, 1)
    addBridge(RIGHT_X, A_Y1, RW, RH, 1)

    -- H road sobre V_AB (carretera horizontal cruza conector vertical → rot=0)
    addBridge(AB_X1, IH2_Y, RH, RW, 0)

    -- V road sobre Seg B (carretera vertical cruza rio horizontal → rot=1)
    addBridge(IV2_X, B_Y1, RW, RH, 1)

    -- H road sobre V_BC (carretera horizontal cruza conector vertical → rot=0)
    addBridge(BC_X1, IH3_Y, RH, RW, 0)

    -- V roads sobre Seg C (carretera vertical cruza rio horizontal → rot=1)
    addBridge(LEFT_X, C_Y1, RW, RH, 1)
    addBridge(IV1_X,  C_Y1, RW, RH, 1)

    -- ── COLISIONES del rio ─────────────────────────────────────
    rivers[#rivers+1] = {x=A_X1,  y=A_Y1,  w=A_X2-A_X1,   h=RH}
    rivers[#rivers+1] = {x=AB_X1, y=AB_Y1, w=RH,           h=AB_Y2-AB_Y1}
    rivers[#rivers+1] = {x=B_X1,  y=B_Y1,  w=B_X2-B_X1,   h=RH}
    rivers[#rivers+1] = {x=BC_X1, y=BC_Y1, w=RH,           h=BC_Y2-BC_Y1}
    rivers[#rivers+1] = {x=C_X1,  y=C_Y1,  w=C_X2-C_X1,   h=RH}

    -- ── PIEDRAS (indestructibles, con colision) ─────────────────
    local stoneIdx = 0
    local function stone(x, y)
        stoneIdx = stoneIdx + 1
        local img = imgs.stones[(stoneIdx-1) % 5 + 1]
        walls[#walls+1] = {
            x=x, y=y, w=img:getWidth(), h=img:getHeight(),
            dest=false, hp=0, terrain=false, sprite=img
        }
    end

    -- Agrupaciones de piedras: offsets fijos para crear formaciones naturales
    local cOff = {
        {-38,-12},{18,-35},{42,8},{-8,38},{28,22},
        {-42,20},{10,-42},{36,-18},{-22,32},{0,0},
    }
    local function stoneCluster(cx, cy, n)
        n = n or 4
        local seed = (cx + cy * 3) % #cOff
        for i = 1, n do
            local o = cOff[(seed + i - 1) % #cOff + 1]
            stone(cx + o[1], cy + o[2])
        end
    end

    -- Zonas de roca agrupadas (centro = centro del grupo)
    local clusters = {
        -- NW
        {420,250,4},{680,450,4},{280,780,3},{870,710,4},
        -- NE encima rio A
        {2650,230,4},{3080,190,4},{3400,420,3},{2820,680,4},
        -- zona norte centro
        {1280,240,3},{1620,390,4},{1900,470,3},{1150,620,4},
        -- SE entre rios A y B
        {2530,870,4},{2870,980,4},{3280,840,4},{2380,1040,3},{3640,960,3},
        -- zona centro entre B y C
        {1330,1340,4},{1760,1430,4},{2000,1290,3},{2580,1390,4},
        {2880,1470,4},{3180,1260,3},{3540,1420,4},
        -- SW debajo rio C
        {350,1940,4},{600,2040,4},{860,1870,3},{280,2110,3},
        -- SE baja
        {2380,1970,4},{2700,2030,4},{3060,1910,4},{3480,2060,3},{3700,1820,3},
    }
    for _, c in ipairs(clusters) do stoneCluster(c[1], c[2], c[3]) end

    -- ── EDIFICIOS DESTRUIBLES (decor_1, ~110x110, HP=3) ────────
    local HW, HH = 110, 110
    local function build(x, y)
        walls[#walls+1] = {
            x=x, y=y, w=HW, h=HH,
            dest=true, hp=3, terrain=false, sprite=imgs.decor1
        }
    end

    local buildPos = {
        -- NW
        {160,350},{420,300},{160,700},{460,650},
        -- NE encima A
        {2350,200},{2700,300},{3050,250},{3450,150},
        -- norte centro
        {1250,400},{1750,350},{1950,550},
        -- SE entre A y B
        {2450,800},{2950,750},{3350,950},{2250,980},{3650,800},
        -- centro entre B y C
        {1350,1280},{1850,1200},{2250,1420},{2750,1300},{3150,1200},
        -- SW
        {160,1900},{430,2000},{160,2050},
        -- SE baja
        {2450,1900},{2950,2050},{3350,1850},
    }
    for _, b in ipairs(buildPos) do build(b[1], b[2]) end

    -- ── ARBOLES con colision (caja ~50x50 invisible) ────────────
    local treeCollisionR = 30
    local function tree(x, y, sc, v)
        treeDeco[#treeDeco+1] = {x=x, y=y, s=sc, img=imgs.trees[v]}
        -- Caja de colision centrada en el tronco
        walls[#walls+1] = {
            x=x-treeCollisionR, y=y-treeCollisionR,
            w=treeCollisionR*2, h=treeCollisionR*2,
            dest=false, hp=0, terrain=false, sprite=nil
        }
    end

    -- Árbol solo si no choca con carretera ni con acceso a puentes
    local TREE_BUF   = treeCollisionR + 12
    local BRIDGE_BUF = treeCollisionR + 50
    local bridgeZones = {
        {IV3_X,   A_Y1,  RW, RH}, {IV4_X,   A_Y1,  RW, RH}, {RIGHT_X, A_Y1, RW, RH},
        {AB_X1,   IH2_Y, RH, RW},
        {IV2_X,   B_Y1,  RW, RH},
        {BC_X1,   IH3_Y, RH, RW},
        {LEFT_X,  C_Y1,  RW, RH}, {IV1_X,   C_Y1,  RW, RH},
    }
    -- Comprueba solo proximidad a puentes (sin restricción de carreteras)
    local function nearBridge(x, y)
        for _, b in ipairs(bridgeZones) do
            if x > b[1]-BRIDGE_BUF and x < b[1]+b[3]+BRIDGE_BUF and
               y > b[2]-BRIDGE_BUF and y < b[2]+b[4]+BRIDGE_BUF then return true end
        end
        return false
    end

    local function treeBlocked(x, y)
        -- Bordes del mapa (carreteras perimetrales)
        if x < RW + TREE_BUF or x > W - RW - TREE_BUF then return true end
        if y < RW + TREE_BUF or y > H - RW - TREE_BUF then return true end
        -- Carreteras H internas
        for _, hy in ipairs({IH1_Y, IH2_Y, IH3_Y, IH4_Y}) do
            if y > hy - TREE_BUF and y < hy + RW + TREE_BUF then return true end
        end
        -- Carreteras V internas
        for _, vx in ipairs({IV1_X, IV2_X, IV3_X, IV4_X}) do
            if x > vx - TREE_BUF and x < vx + RW + TREE_BUF then return true end
        end
        -- Puentes y accesos
        for _, b in ipairs(bridgeZones) do
            if x > b[1]-BRIDGE_BUF and x < b[1]+b[3]+BRIDGE_BUF and
               y > b[2]-BRIDGE_BUF and y < b[2]+b[4]+BRIDGE_BUF then return true end
        end
        return false
    end

    -- Bordes exteriores (se omiten árboles sobre puentes perimetrales)
    for i = 0, 14 do
        local tx, ty
        tx, ty = CS + i*250, 28;    if not nearBridge(tx, ty) then tree(tx, ty, 0.40, (i%4)+1) end
        tx, ty = CS + i*250, H-28;  if not nearBridge(tx, ty) then tree(tx, ty, 0.38, ((i+1)%4)+1) end
    end
    for i = 0, 10 do
        local tx, ty
        tx, ty = 18,   CS + i*180;  if not nearBridge(tx, ty) then tree(tx, ty, 0.42, ((i+2)%4)+1) end
        tx, ty = W-20, CS + i*180;  if not nearBridge(tx, ty) then tree(tx, ty, 0.40, ((i+3)%4)+1) end
    end

    -- Zonas de campo (evitamos carreteras y rio)
    local fieldZones = {
        {x1=RW,    y1=RW,    x2=IV2_X,  y2=IH1_Y},  -- NW norte
        {x1=RW,    y1=IH1_Y+RW, x2=IV1_X, y2=A_Y1}, -- NW medio
        {x1=AB_X2, y1=RW,    x2=IV3_X,  y2=A_Y1},   -- norte centro
        {x1=IV3_X+RW, y1=RW, x2=RIGHT_X, y2=A_Y1},  -- NE norte
        {x1=AB_X2, y1=A_Y2,  x2=RIGHT_X, y2=B_Y1},  -- SE entre A y B
        {x1=B_X1,  y1=B_Y2,  x2=IV2_X,  y2=C_Y1},  -- centro-W entre B y C
        {x1=IV2_X+RW, y1=B_Y2, x2=RIGHT_X, y2=IH4_Y}, -- centro-E
        {x1=RW,    y1=C_Y2,  x2=IV2_X,  y2=BOT_Y},  -- SW
        {x1=BC_X2, y1=C_Y2,  x2=RIGHT_X, y2=BOT_Y}, -- SE baja
    }

    local treeCount = 0
    for _, z in ipairs(fieldZones) do
        local zw = z.x2 - z.x1
        local zh = z.y2 - z.y1
        if zw > 100 and zh > 100 then
            local cols = math.max(1, math.floor(zw/210))
            local rows = math.max(1, math.floor(zh/210))
            for r = 0, rows-1 do
                for c = 0, cols-1 do
                    treeCount = treeCount + 1
                    local tx = z.x1 + (c+0.5)*(zw/cols) + ((treeCount*13)%40)-20
                    local ty = z.y1 + (r+0.5)*(zh/rows) + ((treeCount*7) %30)-15
                    tx = math.floor(tx)
                    ty = math.floor(ty)
                    if not treeBlocked(tx, ty) then
                        tree(tx, ty, 0.35 + (treeCount%5)*0.02, (treeCount%4)+1)
                    end
                end
            end
        end
    end

    -- ── CALAVERAS decorativas (sin colision) ───────────────────
    local function skull(x, y)
        skullDeco[#skullDeco+1] = {x=x, y=y, img=imgs.decor2}
    end
    local skullPos = {
        {350,450},{750,300},{1100,500},{1500,200},{1800,600},
        {2600,450},{3000,300},{3400,500},
        {500,1200},{900,1400},{1300,1500},{1700,1300},
        {2300,1200},{2700,1400},{3100,1300},
        {400,1950},{700,2100},{1000,2000},
        {2500,2000},{3000,1950},
    }
    for _, s in ipairs(skullPos) do skull(s[1], s[2]) end

    -- ── ARBUSTOS (cobertura sin colision) ──────────────────────
    local function bush(x, y, idx)
        covers[#covers+1] = {x=x, y=y, sprite=imgs.bushes[idx]}
    end

    -- Junto a las H-roads
    for hi, hy in ipairs({IH1_Y, IH2_Y, IH3_Y, IH4_Y}) do
        for i = 0, 14 do
            bush(CS + i*256, hy - 28,     ((hi+i)   % 5)+1)
            bush(CS + i*256, hy + RW + 4, ((hi+i+2) % 5)+1)
        end
    end

    -- A lo largo de los margenes del rio
    local riverMargins = {
        {x=A_X1,  y=A_Y1-28, w=A_X2-A_X1},
        {x=B_X1,  y=B_Y1-28, w=B_X2-B_X1},
        {x=C_X1,  y=C_Y1-28, w=C_X2-C_X1},
    }
    for _, rm in ipairs(riverMargins) do
        for i = 0, math.floor(rm.w/150) do
            bush(rm.x + i*150, rm.y,        (i%5)+1)
            bush(rm.x + i*150, rm.y+RH+8,   ((i+2)%5)+1)
        end
    end
end

-- ── Dibujo ────────────────────────────────────────────────────
function Map.drawGround()
    love.graphics.setColor(1, 1, 1)

    -- 1. Fondo
    local bw, bh = imgs.bg:getWidth(), imgs.bg:getHeight()
    love.graphics.draw(imgs.bg, 0, 0, 0, W/bw, H/bh)

    -- 2. Carreteras
    for _, p in ipairs(roadPieces) do
        if     p.mode=="V"   then drawTiledV(p.img, p.x, p.y, p.w, p.h)
        elseif p.mode=="H"   then drawTiledH(p.img, p.x, p.y, p.w, p.h)
        elseif p.mode=="fit" then drawFit(p.img, p.x, p.y, p.w, p.h)
        elseif p.mode=="rot" then
            local iw, ih = p.img:getWidth(), p.img:getHeight()
            love.graphics.draw(p.img, p.cx, p.cy, p.angle, p.sc, p.sc, iw/2, ih/2)
        end
    end

    -- 3. Rio (encima de carreteras)
    for _, p in ipairs(riverPieces) do
        if     p.mode=="H"   then drawTiledH(p.img, p.x, p.y, p.w, p.h)
        elseif p.mode=="V"   then drawTiledV(p.img, p.x, p.y, p.w, p.h)
        elseif p.mode=="fit" then
            if p.rot and p.rot ~= 0 then
                -- Curva rotada (±pi/2): sx/sy se intercambian para rellenar el rectángulo
                local iw, ih = p.img:getWidth(), p.img:getHeight()
                love.graphics.draw(p.img,
                    math.floor(p.x + p.w/2), math.floor(p.y + p.h/2),
                    p.rot,
                    p.h / iw, p.w / ih,
                    iw/2, ih/2)
            else
                drawFit(p.img, p.x, p.y, p.w, p.h)
            end
        end
    end

    -- 4. Puentes (encima del rio)
    for _, p in ipairs(bridgePieces) do
        if p.rot == 1 then
            -- Puente vertical: sprite nativo es paisaje (ancho>alto), rotar 90° para carretera N-S
            local iw, ih = p.img:getWidth(), p.img:getHeight()
            local sx = p.h / iw   -- escala: el ancho del rio cabe en el alto del sprite
            local sy = p.w / ih   -- escala: el ancho de la carretera cabe en el alto del sprite
            -- pivot en centro del sprite, colocar en centro del puente
            love.graphics.draw(p.img,
                p.x + p.w/2, p.y + p.h/2,
                math.pi/2,
                sx, sy,
                iw/2, ih/2)
        else
            drawFit(p.img, p.x, p.y, p.w, p.h)
        end
    end

    -- 5. Calaveras
    for _, s in ipairs(skullDeco) do
        love.graphics.draw(s.img, s.x, s.y)
    end

    -- 6. Arbustos
    for _, c in ipairs(covers) do
        love.graphics.draw(c.sprite, c.x, c.y)
    end

    -- 7. Muros (piedras y edificios)
    for _, w in ipairs(walls) do
        if w.terrain then goto skip_w end
        love.graphics.setColor(1, 1, 1)   -- resetear color antes de cada muro
        if not w.dest then
            if w.sprite then
                love.graphics.draw(w.sprite, w.x, w.y)
            end
            -- sprite=nil → solo colision (arboles, caja invisible)
        elseif w.hp <= 0 then
            love.graphics.setColor(0.26, 0.21, 0.14)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            love.graphics.setColor(0.20, 0.16, 0.10)
            love.graphics.setLineWidth(2)
            love.graphics.line(w.x+5,      w.y+4,       w.x+w.w*0.7, w.y+w.h-4)
            love.graphics.line(w.x+w.w-6,  w.y+5,       w.x+w.w*0.25,w.y+w.h-3)
        elseif w.hp == 1 then
            love.graphics.setColor(0.65, 0.28, 0.15)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.55)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
        elseif w.hp == 2 then
            love.graphics.setColor(1.0, 0.62, 0.30)
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
            love.graphics.setColor(0, 0, 0, 0.22)
            love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
        else
            drawFit(w.sprite, w.x, w.y, w.w, w.h)
        end
        ::skip_w::
    end
    love.graphics.setColor(1, 1, 1)
end

function Map.drawAbove()
    love.graphics.setColor(1, 1, 1)
    for _, t in ipairs(treeDeco) do
        drawCentered(t.img, t.x, t.y, t.s)
    end
    love.graphics.setColor(1, 1, 1)
end

-- ── API de colision ───────────────────────────────────────────
function Map.getWalls()   return walls   end
function Map.getRivers()  return rivers  end
function Map.getBridges() return bridges end
function Map.getSpawns()  return spawns  end
function Map.getPowerupSpawns() return powerupSpawns end

function Map.bulletHit(x, y, r)
    r = r or 1
    for _, w in ipairs(walls) do
        if w.terrain then goto next_bh end
        if x+r >= w.x and x-r <= w.x+w.w and
           y+r >= w.y and y-r <= w.y+w.h then
            if w.dest then
                if w.hp > 0 then w.hp = w.hp - 1; return true end
            else
                return true
            end
        end
        ::next_bh::
    end
    return false
end

function Map.isBlocked(x, y)
    for _, w in ipairs(walls) do
        if w.terrain then goto next_ib end
        if not (w.dest and w.hp <= 0) then
            if x >= w.x and x <= w.x+w.w and
               y >= w.y and y <= w.y+w.h then
                return true
            end
        end
        ::next_ib::
    end
    for _, rv in ipairs(rivers) do
        if x >= rv.x and x <= rv.x+rv.w and
           y >= rv.y and y <= rv.y+rv.h then
            for _, b in ipairs(bridges) do
                if x >= b.x and x <= b.x+b.w and
                   y >= b.y and y <= b.y+b.h then
                    return false
                end
            end
            return true
        end
    end
    return false
end

return Map
