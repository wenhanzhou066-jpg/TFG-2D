-- Sistema de balas para tanques

local Effects = require("systems.effects")

local Bullet = {}

-- Referencia a GameMultiplayer (se setea desde game_multiplayer.lua)
GameMultiplayer = nil

-- Sprites y pools
local sprites = {}
local active = {}
local inactive = {}

-- Tipos de balas
local BulletTypes = {
    light  = { speed = 600, life = 2.5, img = "Light_Shell.png", damage = 10, radius = 16, trail = false },
    heavy  = { speed = 400, life = 3.0, img = "Heavy_Shell.png", damage = 25, radius = 32, trail = false },
    plasma = { speed = 800, life = 1.5, img = "Plasma.png",       damage = 15, radius = 12, trail = true  },
}

-- Cargar sprites
function Bullet.load()
    for tipo, datos in pairs(BulletTypes) do
        local ok, img = pcall(love.graphics.newImage, "assets/images/PNG/Effects/" .. datos.img)
        if ok then
            sprites[tipo] = img
        else
            error("No se pudo cargar el sprite de bala: " .. datos.img)
        end
    end
end

-- Crea una bala nueva o reutiliza una del pool
local function createBullet(x, y, angle, tipo, ownerId)
    local t = BulletTypes[tipo] or BulletTypes.light
    local sprite = sprites[tipo] or sprites["light"]

    local b = table.remove(inactive) or {}
    b.x = x
    b.y = y
    b.angle = angle
    b.vx = math.cos(angle) * t.speed
    b.vy = math.sin(angle) * t.speed
    b.img = sprite
    b.ox = sprite:getWidth() / 2
    b.oy = sprite:getHeight() / 2
    b.life = t.life
    b.type = tipo
    b.damage = t.damage
    b.radius = t.radius
    b.trail = t.trail
    b.ownerId = ownerId or "local"  -- ID del jugador que disparó
    b.spawnTime = 0  -- Tiempo desde spawn (para ignorar colisión inicial)
    return b
end

-- Spawnea una bala y reproduce el sonido de disparo
function Bullet.spawn(x, y, angle, tipo, ownerId)
    if Audio then Audio.disparo() end
    local b = createBullet(x, y, angle, tipo, ownerId)
    table.insert(active, b)
end

-- Chequea colision bala-tanque circular
local function checkTankHit(bx, by, bradius)
    if not Tank then return false end
    if Tank.isDead and Tank.isDead() then return false end
    if Tank.isInvulnerable and Tank.isInvulnerable() then return false end

    local tx, ty, tradius = Tank.getBounds()
    local dx = bx - tx
    local dy = by - ty
    local distSq = dx*dx + dy*dy
    local sumRadius = (bradius + tradius) * 1.2  -- 20% more forgiving

    return distSq < sumRadius*sumRadius
end

-- Chequea colision con otros tanques (multiplayer)
local function checkOtherTanksHit(bx, by, bradius)
    -- Solo en multiplayer
    if not GameMultiplayer or not GameMultiplayer.getOtherTanks then
        return false, nil
    end

    local otherTanks = GameMultiplayer.getOtherTanks()
    local tankRadius = 30  -- Radio aproximado del tanque (escala 0.3)

    for pid, tank in pairs(otherTanks) do
        -- Usar target position (real) en vez de interpolated
        local tx = tank.target_x or tank.x
        local ty = tank.target_y or tank.y

        local dx = bx - tx
        local dy = by - ty
        local distSq = dx*dx + dy*dy
        local sumRadius = (bradius + tankRadius) * 1.2  -- 20% more forgiving

        if distSq < sumRadius*sumRadius then
            return true, pid, tx, ty
        end
    end

    return false, nil
end

-- Actualiza todas las balas activas
function Bullet.update(dt)
    local newActive = {}
    for _, b in ipairs(active) do

        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        b.spawnTime = b.spawnTime + dt

        -- Trail para balas rapidas como plasma
        if b.trail and Effects.spawnTrail then
            Effects.spawnTrail(b.x, b.y, b.type)
        end

        local destroyed = false

        -- Colision con tanque del jugador (solo después de 0.1s y si no es propia)
        if b.spawnTime > 0.1 and b.ownerId ~= "local" and checkTankHit(b.x, b.y, b.radius) then
            if Tank.takeDamage then
                Tank.takeDamage(b.damage)
            end
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.explosion() end
            destroyed = true

        -- Colision con otros tanques (multiplayer, solo balas propias para visual feedback)
        elseif b.spawnTime > 0.1 and b.ownerId == "local" then
            local hit, pid, hitx, hity = checkOtherTanksHit(b.x, b.y, b.radius)
            if hit then
                -- Visual feedback + optimistic HP update
                Effects.spawnExplosion(hitx or b.x, hity or b.y, b.type, b.radius)
                Effects.spawnDamageNumber(hitx or b.x, (hity or b.y) - 30, b.damage)
                if Audio then Audio.explosion() end

                -- Predict HP drop locally (server will send authoritative value later)
                if GameMultiplayer and GameMultiplayer.damageOtherTank then
                    GameMultiplayer.damageOtherTank(pid, b.damage)
                end

                destroyed = true
            end
        end

        -- Colision con mapa o vida agotada
        if not destroyed and (Map.bulletHit(b.x, b.y, b.radius) or b.life <= 0) then
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.explosion() end
            destroyed = true
        end

        if destroyed then
            table.insert(inactive, b)
        else
            table.insert(newActive, b)
        end
    end
    active = newActive
end

-- Dibuja todas las balas activas
function Bullet.draw()
    love.graphics.setColor(1, 1, 1)
    for _, b in ipairs(active) do
        -- Rotamos -90° porque el sprite apunta en vertical por defecto
        love.graphics.draw(b.img, b.x, b.y, b.angle + math.pi/2, 1, 1, b.ox, b.oy)
    end
end

-- Limpia todas las balas (al reiniciar partida)
function Bullet.clear()
    for _, b in ipairs(active) do
        table.insert(inactive, b)
    end
    active = {}
end

return Bullet