-- entities/bullet.lua
-- Pool de balas activas. Cada bala tiene posicion, velocidad, angulo,
-- tiempo de vida y owner ("player" o "bot").

local Effects = require("systems.effects")
local Perfil  = require("systems.perfil")

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
    b.tintR = 1
    b.tintG = 1
    b.tintB = 1
    return b
end

-- Spawnea una bala (Integrando sistemas de ambos)
function Bullet.spawn(x, y, angle, tipo, owner, damage)
    if Audio then Audio.disparo() end
    
    -- Determinar tipo si no se proporciona (usar el arma del jugador si es 'player' o 'local')
    if not tipo then
        tipo = (owner == "player" or owner == "local") and playerShellKey or "light"
    end
    -- Unificar identificador de 'local' o 'player' para el sistema de colisiones
    local ownerId = (owner == "player" or owner == "local") and "local" or "bot"
    local b = createBullet(x, y, angle, tipo, ownerId, owner, damage)
    if owner == "player" and Perfil.activo then
        b.tintR = Perfil.activo.colorAmmoR or 1
        b.tintG = Perfil.activo.colorAmmoG or 1
        b.tintB = Perfil.activo.colorAmmoB or 1
    end
    
    count = count + 1
    active[count] = b
end

local function checkTankHit(bx, by, bradius)
    local Tank = require("entities.tank") -- cargamos aquí para evitar circulares
    if not Tank or not Tank.getTanks then return false, nil end
    
    for id, datos in pairs(Tank.getTanks()) do
        if not datos.isDead and not datos.invulnerable then
            local tx, ty, tradius = datos.x, datos.y, datos.radio
            local dx = bx - tx
            local dy = by - ty
            local distSq = dx*dx + dy*dy
            local sumRadius = (bradius + tradius) * 1.2

            if distSq < sumRadius*sumRadius then
                return true, id
            end
        end
    end
    
    return false, nil
end

-- Chequea colision con otros tanques (multiplayer
local function checkOtherTanksHit(bx, by, bradius)
    if not GameMultiplayer or not GameMultiplayer.getOtherTanks then
        return false, nil
    end

    local otherTanks = GameMultiplayer.getOtherTanks()
    local tankRadius = 30

    for pid, tank in pairs(otherTanks) do
        -- Usar posición visual (interpolada) para colisión, coincidiendo con lo que ve el jugador
        local tx = tank.x
        local ty = tank.y

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

        -- 1. Colisión con mapa
        if not destroyed and Map.bulletHit(b.x, b.y, b.radius or 5) then
            destroyed = true
        end

        -- 2. Colisión con Tanques Locales (si la bala no es nuestra)
        if not destroyed and b.spawnTime > 0.05 and b.ownerId ~= "local" then
            local hit, hitId = checkTankHit(b.x, b.y, b.radius or 5)
            if hit then
                if Tank and Tank.takeDamage then
                    Tank.takeDamage(b.damage, hitId)
                elseif Tank and Tank.checkHit then
                    Tank.checkHit(b.x, b.y, b.damage, hitId)
                end
                destroyed = true
            end
        end

        -- 3. Colisión con otros tanques (Multiplayer)
        if not destroyed and b.ownerId == "local" then
            local hit, pid, hitx, hity = checkOtherTanksHit(b.x, b.y, b.radius or 5)
        -- Colision con Bots
        elseif b.owner == "player" and Bot then
            if Bot.checkHit(b.x, b.y, b.damage) then
                destroyed = true
            end

        -- Colision con otros tanques (multiplayer, solo balas propias para visual feedback)
        elseif b.spawnTime > 0.1 and b.ownerId == "local" then
            local hit, pid, hitx, hity = checkOtherTanksHit(b.x, b.y, b.radius)
            if hit then
                -- Feedback visual inmediato e intuitivo
                Effects.spawnExplosion(hitx or b.x, hity or b.y, b.type, b.radius)
                Effects.spawnDamageNumber(hitx or b.x, (hity or b.y) - 30, b.damage)
                if Audio then Audio.explosion() end

                -- Actualización "optimista" de HP
                if GameMultiplayer and GameMultiplayer.damageOtherTank then
                    GameMultiplayer.damageOtherTank(pid, b.damage)
                end
                destroyed = true
            end
        end

        -- 4. Colisión con Bots (IA local)
        if not destroyed and (b.owner == "player" or b.owner == "local") and Bot then
            if Bot.checkHit(b.x, b.y, b.damage) then
                destroyed = true
            end
        end

        -- 5. Vida agotada
        if not destroyed and b.life <= 0 then
            destroyed = true
        end

        -- Procesar destrucción
        if destroyed then
            Effects.spawnExplosion(b.x, b.y, b.type, b.radius)
            if Audio then Audio.explosion() end
            
            -- Lógica de Pool (mover bala inactiva)
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
    for i = 1, count do
        local b = active[i]
        love.graphics.setColor(b.tintR or 1, b.tintG or 1, b.tintB or 1)
        love.graphics.draw(b.img, b.x, b.y, b.angle + math.pi/2, DRAW_SCALE, DRAW_SCALE, b.ox, b.oy)
    end
    love.graphics.setColor(1, 1, 1)
end

return Bullet