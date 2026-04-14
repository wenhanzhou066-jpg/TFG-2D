-- systems/minimap.lua
-- Sistema de minimapa y niebla de guerra (Fog of War)

local Minimap = {}

local WORLD_W, WORLD_H = 3840, 2160
local MINI_SIZE = 250 -- Tamaño del minimapa en pantalla (cuadrado)
local FOG_RES = 0.05  -- Resolución del canvas de niebla (1/20 del tamaño real)

local fogCanvas = nil
local miniCanvas = nil
local playerPos = {x = 0, y = 0}

function Minimap.load()
    -- Crear canvas de niebla (resolución reducida para rendimiento)
    -- Lo usamos para "pintar" donde ha estado el jugador
    fogCanvas = love.graphics.newCanvas(WORLD_W * FOG_RES, WORLD_H * FOG_RES)
    
    -- Inicializar con negro (todo oculto)
    love.graphics.setCanvas(fogCanvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setCanvas()
    
    -- Canvas para el dibujo del minimapa UI
    miniCanvas = love.graphics.newCanvas(MINI_SIZE, MINI_SIZE)
end

function Minimap.update(tx, ty)
    playerPos.x, playerPos.y = tx, ty
    
    -- Revelar área alrededor del jugador en el canvas de niebla
    love.graphics.setCanvas(fogCanvas)
    love.graphics.setBlendMode("replace")
    love.graphics.setColor(0, 0, 0, 0) -- Transparente = revelado
    
    -- Círculo de visión (ajustar radio según se desee)
    local visionRadius = 400 * FOG_RES
    love.graphics.circle("fill", tx * FOG_RES, ty * FOG_RES, visionRadius)
    
    love.graphics.setBlendMode("alpha")
    love.graphics.setCanvas()
end

-- Dibuja la máscara de niebla sobre el mundo (oscureciendo lo no visitado)
function Minimap.drawFogToCurrentCanvas(camX, camY)
    if not fogCanvas then return end
    
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Dibujar el canvas de niebla escalado al tamaño del mundo
    love.graphics.draw(fogCanvas, 0, 0, 0, 1/FOG_RES, 1/FOG_RES)
    
    love.graphics.setBlendMode("alpha")
end

-- Dibuja el elemento de UI (minimapa en la esquina)
function Minimap.drawHUD(camX, camY, gameView)
    local sw, sh = love.graphics.getDimensions()
    local margin = 20
    local mx = sw - MINI_SIZE - margin
    local my = margin
    
    -- 1. Fondo del minimapa
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", mx - 2, my - 2, MINI_SIZE + 4, MINI_SIZE + 4, 4)
    
    -- 2. Dibujar contenido en el miniCanvas
    love.graphics.setCanvas(miniCanvas)
    love.graphics.clear(0.05, 0.05, 0.05, 1)
    
    local scale = MINI_SIZE / WORLD_W
    
    -- Dibujar representación simplificada del mapa
    -- (Solo si Map.drawGround existe y es eficiente, si no, dibujamos algo simple)
    if Map and Map.drawGround then
        love.graphics.push()
        love.graphics.scale(scale, scale)
        -- Map.drawGround() -- Podría ser demasiado pesado para cada frame en el HUD
        
        -- En su lugar, dibujamos el rio y muros básicos
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
    
    -- Dibujar niebla actual sobre el minimapa
    love.graphics.setBlendMode("multiply", "premultiplied")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.draw(fogCanvas, 0, 0, 0, MINI_SIZE / (WORLD_W * FOG_RES), MINI_SIZE / (WORLD_H * FOG_RES))
    love.graphics.setBlendMode("alpha")
    
    -- 3. Dibujar iconos de jugadores/objetivos
    -- Jugador local (punto verde)
    love.graphics.setColor(0, 1, 0)
    love.graphics.circle("fill", playerPos.x * scale, playerPos.y * scale, 4)
    
    -- Viewport (rectángulo blanco indicando qué ve la cámara)
    local vw = 1920 * scale
    local vh = 1080 * scale
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", camX * scale, camY * scale, vw, vh)
    
    love.graphics.setCanvas()
    
    -- 4. Volcar a pantalla
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(miniCanvas, mx, my)
    
    -- Borde final
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", mx, my, MINI_SIZE, MINI_SIZE)
end

return Minimap
