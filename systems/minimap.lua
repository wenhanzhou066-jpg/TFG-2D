-- systems/minimap.lua
-- Minimapa + Niebla de guerra (Fog of War)
--
-- Visión actual: círculo suavizado centrado en el jugador.
-- TODO (compañero): reemplazar el bloque marcado en Minimap.update() por el
-- polígono de raycasting una vez esté listo Raycast.getVisionPolygon().

local Minimap = {}

local MINI_W  = 250     -- ancho del minimapa en pantalla (px)
local FOG_RES = 0.125   -- 1/8 del mundo → canvas 480×272, círculos de 50 px (suaves)

local fogCanvas = nil
local miniCanvas = nil
local mapCanvas  = nil   -- textura estática pre-renderizada del mapa (una vez en load)
local playerPos  = { x = 0, y = 0 }

local worldW = 3840
local worldH = 2176
local miniH  = 142   -- recalculado en load() según proporción real del mapa

local function fogW() return math.ceil(worldW * FOG_RES) end
local function fogH() return math.ceil(worldH * FOG_RES) end

-- ── Carga / reset ─────────────────────────────────────────────────────────────

function Minimap.load()
    -- Leer dimensiones reales del mapa cargado
    if Map and Map.getSize then
        local s = Map.getSize()
        worldW, worldH = s.w, s.h
    end
    miniH = math.max(1, math.floor(MINI_W * worldH / worldW))

    fogCanvas  = love.graphics.newCanvas(fogW(), fogH())
    fogCanvas:setFilter("linear", "linear")   -- interpolación suave al escalar
    miniCanvas = love.graphics.newCanvas(MINI_W, miniH)

    -- Pre-renderizar el mapa completo al tamaño del minimapa (solo una vez)
    mapCanvas = love.graphics.newCanvas(MINI_W, miniH)
    love.graphics.setCanvas(mapCanvas)
    love.graphics.clear(0.05, 0.10, 0.05, 1)
    love.graphics.push()
    love.graphics.scale(MINI_W / worldW, miniH / worldH)
    if Map and Map.drawGround then Map.drawGround() end
    love.graphics.pop()
    love.graphics.setCanvas()

    Minimap.reset()
end

-- Borra la niebla (llamar también al reiniciar partida)
function Minimap.reset()
    if not fogCanvas then return end
    love.graphics.setCanvas(fogCanvas)
    love.graphics.clear(0, 0, 0, 1)   -- negro opaco = todo oculto
    love.graphics.setCanvas()
end

-- ── Update ────────────────────────────────────────────────────────────────────

function Minimap.update(tx, ty)
    playerPos.x, playerPos.y = tx, ty
    if not fogCanvas then return end

    love.graphics.setCanvas(fogCanvas)
    love.graphics.setBlendMode("replace")

    -- ── ZONA DE VISIÓN ────────────────────────────────────────────────────────
    -- TODO: cuando el compañero entregue Raycast.getVisionPolygon(),
    -- sustituir este bloque por el polígono de raycasting:
    --
    --   local poly = Raycast.getVisionPolygon(tx, ty, 400, Map.getWalls())
    --   local scaled = {}
    --   for i = 1, #poly, 2 do
    --       scaled[#scaled + 1] = poly[i]     * FOG_RES
    --       scaled[#scaled + 1] = poly[i + 1] * FOG_RES
    --   end
    --   love.graphics.setColor(0, 0, 0, 0)
    --   love.graphics.polygon("fill", scaled)
    --
    -- Círculo provisional con borde suavizado (sin oclusión por paredes):
    -- blendMode("replace") → el último círculo dibujado gana en cada píxel.
    -- Dibujamos de mayor a menor: el más exterior queda en los píxeles del borde,
    -- el interior va sobreescribiendo hasta llegar a alpha=0 en el centro.
    local fx, fy = tx * FOG_RES, ty * FOG_RES
    local r = 400 * FOG_RES
    local zones = {
        { mul = 1.00, alpha = 0.82 },
        { mul = 0.84, alpha = 0.58 },
        { mul = 0.70, alpha = 0.32 },
        { mul = 0.56, alpha = 0.12 },
        { mul = 0.42, alpha = 0.00 },
    }
    for _, z in ipairs(zones) do
        love.graphics.setColor(0, 0, 0, z.alpha)
        love.graphics.circle("fill", fx, fy, r * z.mul)
    end
    -- ── FIN ZONA DE VISIÓN ────────────────────────────────────────────────────

    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
end

-- ── Draw ──────────────────────────────────────────────────────────────────────

-- Aplica la máscara de niebla al gameCanvas.
-- Llamar dentro del gameCanvas DESPUÉS de love.graphics.pop() de cámara.
function Minimap.drawFogToCurrentCanvas(camX, camY)
    if not fogCanvas then return end
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fogCanvas,
        -camX, -camY,
        0, 1 / FOG_RES, 1 / FOG_RES)
end

-- Dibuja el HUD del minimapa en la esquina superior derecha de la pantalla.
-- Llamar FUERA del gameCanvas (después de love.graphics.setCanvas()).
function Minimap.drawHUD(camX, camY, gameView)
    if not miniCanvas or not fogCanvas then return end

    local sw     = love.graphics.getWidth()
    local margin = 20
    local hudX   = sw - MINI_W - margin
    local hudY   = margin
    local scaleX = MINI_W / worldW
    local scaleY = miniH  / worldH

    -- Dibujar en el miniCanvas: mapa + niebla + marcadores
    love.graphics.setCanvas(miniCanvas)

    -- Fondo: textura pre-renderizada del mapa real
    if mapCanvas then
        love.graphics.setBlendMode("alpha")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(mapCanvas, 0, 0)
    else
        -- Fallback si el mapa no pudo pre-renderizarse
        love.graphics.clear(0.05, 0.05, 0.05, 1)
        if Map then
            love.graphics.push()
            love.graphics.scale(scaleX, scaleY)
            love.graphics.setColor(0.1, 0.3, 0.6)
            for _, r in ipairs(Map.getRivers() or {}) do
                love.graphics.rectangle("fill", r.x, r.y, r.w, r.h)
            end
            love.graphics.setColor(0.4, 0.4, 0.4)
            for _, w in ipairs(Map.getWalls() or {}) do
                if not (w.dest and w.hp <= 0) then
                    love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
                end
            end
            love.graphics.pop()
        end
    end

    -- Niebla encima del mapa (misma lógica que en el mundo)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(fogCanvas, 0, 0, 0,
        MINI_W / fogW(),
        miniH  / fogH())

    -- Punto verde del jugador
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill",
        playerPos.x * scaleX,
        playerPos.y * scaleY, 4)

    -- Rectángulo de viewport (qué ve la cámara)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line",
        camX * scaleX, camY * scaleY,
        1920 * scaleX, 1080 * scaleY)

    love.graphics.setCanvas()

    -- Fondo oscuro + imagen + borde en pantalla
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", hudX - 2, hudY - 2, MINI_W + 4, miniH + 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(miniCanvas, hudX, hudY)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", hudX, hudY, MINI_W, miniH)
    love.graphics.setColor(1, 1, 1)
end

return Minimap
