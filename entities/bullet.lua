-- entities/bullet.lua
-- Pool de balas activas. Cada bala tiene posicion, velocidad, angulo,
-- tiempo de vida y owner ("player" o "bot").

local Effects = require("systems.effects")

local Bullet = {}

local sprites = {}
local spritesLoaded = false
local active = {}
local count  = 0
local SPEED      = 600
local LIFE       = 2.5
local DRAW_SCALE = 0.4

local Bot = nil
local opponentChecker = nil  -- funcion(bx,by) para colision contra rival online
local playerShellKey = "light"

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
    count  = 0
end

function Bullet.spawn(x, y, angle, tipo, owner, damage)
    owner  = owner  or "player"
    damage = damage or 1
    if not tipo then
        tipo = (owner == "player") and playerShellKey or "light"
    end
    count = count + 1
    active[count] = {
        x      = x,
        y      = y,
        vx     = math.cos(angle) * SPEED,
        vy     = math.sin(angle) * SPEED,
        angle  = angle,
        img    = sprites[tipo] or sprites.light,
        life   = LIFE,
        owner  = owner,
        damage = damage,
    }
end

function Bullet.update(dt)
    -- carga lazy del modulo bot para evitar dependencia circular
    if not Bot then
        local ok, m = pcall(require, "entities.bot")
        if ok then Bot = m end
    end

    local i = 1
    while i <= count do
        local b = active[i]
        b.x    = b.x + b.vx * dt
        b.y    = b.y + b.vy * dt
        b.life = b.life - dt

        local hit = false

        if Map.bulletHit(b.x, b.y) then
            hit = true

        elseif b.owner == "player" and Bot then
            if Tank and Tank.isExplosive and Tank.isExplosive() then
                if Bot.checkHitArea(b.x, b.y, 60, b.damage) then hit = true end
            elseif Bot.checkHit(b.x, b.y, b.damage) then
                hit = true
            end

        elseif b.owner == "player" and opponentChecker and opponentChecker(b.x, b.y) then
            hit = true

        elseif (b.owner == "bot" or b.owner == "opponent") and Tank.checkHit and Tank.checkHit(b.x, b.y, b.damage) then
            hit = true

        elseif b.life <= 0 then
            hit = true
        end

        if hit then
            Effects.spawnExplosion(b.x, b.y)
            -- swap-and-pop: reemplaza con el ultimo elemento
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
        local ox = b.img:getWidth()  / 2
        local oy = b.img:getHeight() / 2
        love.graphics.draw(b.img, b.x, b.y, b.angle + math.pi/2, DRAW_SCALE, DRAW_SCALE, ox, oy)
    end
end

return Bullet