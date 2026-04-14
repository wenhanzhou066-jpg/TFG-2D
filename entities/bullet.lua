-- entities/bullet.lua
-- Pool de balas activas. Cada bala tiene posicion, velocidad, angulo,
-- tiempo de vida y owner ("player" o "bot").

local Effects = require("systems.effects")

local Bullet = {}

-- Referencia a GameMultiplayer (se setea desde game_multiplayer.lua)
GameMultiplayer = nil

-- Sprites y pools
local sprites = {}
local spritesLoaded = false
local active = {}
local inactive = {} -- Pool de balas inactivas
local count  = 0
local SPEED      = 600
local LIFE       = 2.5
local DRAW_SCALE = 0.4

local Bot = nil
local opponentChecker = nil  -- funcion(bx,by) para colision contra rival online
local playerShellKey = "light"

-- Tipos de balas
local BulletTypes = {
    light =   { speed = 600, life = 2.5, damage = 10, radius = 5, trail = false },
    medium =  { speed = 700, life = 2.0, damage = 20, radius = 7, trail = false },
    heavy =   { speed = 500, life = 3.0, damage = 40, radius = 10, trail = true },
    sniper =  { speed = 1200, life = 1.5, damage = 35, radius = 4, trail = true },
    plasma =  { speed = 450, life = 4.0, damage = 50, radius = 12, trail = true },
    laser =   { speed = 2000, life = 0.5, damage = 15, radius = 3, trail = false },
    granade = { speed = 400, life = 2.0, damage = 60, radius = 15, trail = false },
    shotgun = { speed = 800, life = 0.8, damage = 12, radius = 5, trail = false },
}

-- mapeo: indice de arma (1-8) → clave de sprite de bala
local WEAPON_TO_SHELL = {
    "light",   -- 1: Viper
    "heavy",   -- 2: Thunder
    "sniper",  -- 3: Railgun
    "plasma",  -- 4: Inferno
    "medium",  -- 5: Cyclone
    "laser",   -- 6: Nova
    "granade", -- 7: Hellfire
    "shotgun", -- 8: Oblivion
}

-- registrar funcion de colision contra rival online
function Bullet.setOpponentChecker(fn)
    opponentChecker = fn
end

-- establecer el arma del jugador (1-8)
function Bullet.setPlayerWeapon(weaponModel)
    playerShellKey = WEAPON_TO_SHELL[weaponModel] or "light"
end

function Bullet.load()
    if not spritesLoaded then
        local base = "assets/images/PNG/Effects/"
        sprites.light   = love.graphics.newImage(base.."Light_Shell.png")
        sprites.heavy   = love.graphics.newImage(base.."Heavy_Shell.png")
        sprites.medium  = love.graphics.newImage(base.."Medium_Shell.png")
        sprites.sniper  = love.graphics.newImage(base.."Sniper_Shell.png")
        sprites.granade = love.graphics.newImage(base.."Granade_Shell.png")
        sprites.shotgun = love.graphics.newImage(base.."Shotgun_Shells.png")
        sprites.plasma  = love.graphics.newImage(base.."Plasma.png")
        sprites.laser   = love.graphics.newImage(base.."Laser.png")
        spritesLoaded = true
    end
    active = {}
    inactive = {}
    count  = 0
end

-- Crea una bala nueva o reutiliza una del pool
local function createBullet(x, y, angle, tipo, ownerId, ownerType, damage)
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
    b.damage = damage or t.damage
    b.radius = t.radius
    b.trail = t.trail
    b.ownerId = ownerId or "local"
    b.owner = ownerType or "player" -- manteniendo "player" o "bot" para compatibilidad
    b.spawnTime = 0
    return b
end

-- Spawnea una bala (Integrando sistemas de ambos)
function Bullet.spawn(x, y, angle, tipo, owner, damage)
    if Audio then Audio.disparo() end
    
    -- Determinar tipo si no se proporciona
    if not tipo then
        tipo = (owner == "player") and playerShellKey or "light"
    end
    
    local ownerId = (owner == "player") and "local" or "bot"
    local b = createBullet(x, y, angle, tipo, ownerId, owner, damage)
    
    count = count + 1
    active[count] = b
end

-- Chequea colision bala-tanque circular
local function checkTankHit(bx, by, bradius)
    local Tank = require("entities.tank") -- cargamos aquí para evitar circulares
    if not Tank or not Tank.getPosition then return false end
    if Tank.estaMuerto and Tank.estaMuerto() then return false end
    if Tank.isInvulnerable and Tank.isInvulnerable() then return false end

    local tx, ty, tradius = Tank.getBounds()
    local dx = bx - tx
    local dy = by - ty
    local distSq = dx*dx + dy*dy
    local sumRadius = (bradius + tradius) * 1.2

    return distSq < sumRadius*sumRadius
end

-- Chequea colision con otros tanques (multiplayer
local function checkOtherTanksHit(bx, by, bradius)
    if not GameMultiplayer or not GameMultiplayer.getOtherTanks then
        return false, nil
    end

    local otherTanks = GameMultiplayer.getOtherTanks()
    local tankRadius = 30

    for pid, tank in pairs(otherTanks) do
        local tx = tank.target_x or tank.x
        local ty = tank.target_y or tank.y

        local dx = bx - tx
        local dy = by - ty
        local distSq = dx*dx + dy*dy
        local sumRadius = (bradius + tankRadius) * 1.2

        if distSq < sumRadius*sumRadius then
            return true, pid, tx, ty
        end
    end

    return false, nil
end

function Bullet.update(dt)
    if not Bot then
        local ok, m = pcall(require, "entities.bot")
        if ok then Bot = m end
    end
    
    local Tank = require("entities.tank")

    local i = 1
    while i <= count do
        local b = active[i]
        b.x    = b.x + b.vx * dt
        b.y    = b.y + b.vy * dt
        b.life = b.life - dt
        b.spawnTime = b.spawnTime + dt

        local destroyed = false

        -- Colision con mapa
        if Map.bulletHit(b.x, b.y, b.radius or 5) then
            destroyed = true
        
        -- Colision con Tanque Local
        elseif b.spawnTime > 0.05 and b.ownerId ~= "local" and checkTankHit(b.x, b.y, b.radius or 5) then
            if Tank and Tank.takeDamage then
                Tank.takeDamage(b.damage)
            elseif Tank and Tank.checkHit then
                Tank.checkHit(b.x, b.y, b.damage)
            end
            destroyed = true

        -- Colision con Bots (Tu sistema IA)
        elseif b.owner == "player" and Bot then
            if Bot.checkHit(b.x, b.y, b.damage) then
                destroyed = true
            end

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

        -- Colision con otros tanques (Multiplayer)
        elseif b.spawnTime > 0.1 and b.ownerId == "local" then
            local hit, pid, hitx, hity = checkOtherTanksHit(b.x, b.y, b.radius or 5)
            if hit then
                destroyed = true
            end
        
        -- Vida agotada
        elseif b.life <= 0 then
            destroyed = true
        end

        if destroyed then
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.explosion() end
            
            -- Pool Logic 
            table.insert(inactive, b)
            active[i] = active[count]
            active[count] = nil
            count = count - 1
        else
            i = i + 1
        end
    end
end

function Bullet.draw()
    love.graphics.setColor(1, 1, 1)
    for i = 1, count do
        local b = active[i]
        love.graphics.draw(b.img, b.x, b.y, b.angle + math.pi/2, DRAW_SCALE, DRAW_SCALE, b.ox, b.oy)
    end
end

return Bullet