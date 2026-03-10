-- entities/tank.lua
-- Gestiona el jugador: carga de sprites, movimiento,
-- rotación de torreta hacia el ratón y huellas.

local Tracks = require("systems.tracks")

local Tank = {}

local sprites = {}
local data    = {}
local GRAVITY = 0
local TRACK_INTERVAL = 0.08
local SCALE  = 0.3   -- escala del sprite (1 = tamaño original)
local MAP_W  = 1920
local MAP_H  = 1080

-- ── Colisión ────────────────────────────────────────────────────
-- Devuelve true si un círculo de radio r centrado en (nx,ny)
-- colisiona con los límites del mapa, muros o ríos sin puente.
local function isBlocked(nx, ny, r)
    -- Límites del mapa
    if nx - r < 0 or nx + r > MAP_W or
       ny - r < 0 or ny + r > MAP_H then
        return true
    end

    -- Muros y edificios (AABB vs círculo simplificado; ignorar destruidos)
    for _, w in ipairs(Map.getWalls()) do
        if not (w.dest and w.hp <= 0) then
            local cx = math.max(w.x, math.min(nx, w.x + w.w))
            local cy = math.max(w.y, math.min(ny, w.y + w.h))
            if (nx - cx)^2 + (ny - cy)^2 < r * r then
                return true
            end
        end
    end

    -- Ríos: bloqueantes salvo donde hay puente
    local pts = { {nx+r,ny},{nx-r,ny},{nx,ny+r},{nx,ny-r} }
    for _, p in ipairs(pts) do
        for _, rv in ipairs(Map.getRivers()) do
            if p[1] >= rv.x and p[1] <= rv.x+rv.w and
               p[2] >= rv.y and p[2] <= rv.y+rv.h then
                local onBridge = false
                for _, br in ipairs(Map.getBridges()) do
                    if p[1] >= br.x and p[1] <= br.x+br.w and
                       p[2] >= br.y and p[2] <= br.y+br.h then
                        onBridge = true; break
                    end
                end
                if not onBridge then return true end
            end
        end
    end

    return false
end

function Tank.load()
    sprites.tracks = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
    sprites.hull   = love.graphics.newImage("assets/images/PNG/Hulls_Color_A/Hull_01.png")
    sprites.weapon = love.graphics.newImage("assets/images/PNG/Weapon_Color_A/Gun_01.png")

    -- Radio del hitbox basado en el sprite escalado (75 % del radio real)
    local r = math.floor(sprites.hull:getWidth() * SCALE / 2 * 0.75)

    data = {
        x = 400, y = 300,
        angle = 0, turretAngle = 0,
        speed = 150,
        radius = r,
        trackTimer = 0,
        isMoving = false,
    }
end

function Tank.update(dt)
    data.isMoving = false
    local r = data.radius

    -- Calcular posición candidata
    local nx, ny = data.x, data.y
    if love.keyboard.isDown("w") then
        nx = nx + math.cos(data.angle) * data.speed * dt
        ny = ny + math.sin(data.angle) * data.speed * dt
    end
    if love.keyboard.isDown("s") then
        nx = nx - math.cos(data.angle) * data.speed * dt
        ny = ny - math.sin(data.angle) * data.speed * dt
    end

    -- Aplicar movimiento con deslizamiento en muros
    local oldx, oldy = data.x, data.y
    if not isBlocked(nx, ny, r) then
        data.x, data.y = nx, ny
    else
        -- Deslizamiento: intentar solo X, luego solo Y
        if not isBlocked(nx, data.y, r) then
            data.x = nx
        elseif not isBlocked(data.x, ny, r) then
            data.y = ny
        end
    end
    data.isMoving = (data.x ~= oldx or data.y ~= oldy)

    if love.keyboard.isDown("a") then
        data.angle = data.angle - 2 * dt
    end
    if love.keyboard.isDown("d") then
        data.angle = data.angle + 2 * dt
    end

    -- Torreta apunta al ratón
    local mx, my = love.mouse.getPosition()
    data.turretAngle = math.atan2(my - data.y, mx - data.x)

    -- Sonido de motor
    if Audio then Audio.updateEngine(data.isMoving) end

    -- Huellas de oruga
    if data.isMoving then
        data.trackTimer = data.trackTimer + dt
        if data.trackTimer >= TRACK_INTERVAL then
            data.trackTimer = 0
            Tracks.spawn(data.x, data.y, data.angle)
        end
    end
end

function Tank.draw()
    local function drawSprite(img, angle)
        local ox = img:getWidth()  / 2
        local oy = img:getHeight() / 2
        love.graphics.draw(img, data.x, data.y, angle, SCALE, SCALE, ox, oy)
    end

    love.graphics.setColor(1, 1, 1)
    drawSprite(sprites.tracks, data.angle        + math.pi/2)  -- orugas
    drawSprite(sprites.hull,   data.angle        + math.pi/2)  -- casco
    drawSprite(sprites.weapon, data.turretAngle  + math.pi/2)  -- torreta
end

-- Devuelve la posición del cañón para spawn de balas
function Tank.getMuzzlePos()
    local dist = 40  -- distancia desde el centro hasta la boca del cañón
    local bx = data.x + math.cos(data.turretAngle) * dist
    local by = data.y + math.sin(data.turretAngle) * dist
    return bx, by, data.turretAngle
end

return Tank