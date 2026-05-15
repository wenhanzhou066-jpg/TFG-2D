-- server/sim_bullet.lua
-- Simulación de balas en el lado del servidor
-- Constantes de armas copiadas de entities/bullet.lua:28-49

local collision = require("server.collision")

local SimBullet = {}
SimBullet.__index = SimBullet

-- Tipos y constantes de armas (de entities/bullet.lua:28-49)
local WEAPON_TYPES = {
    "light",   -- 1: Viper
    "heavy",   -- 2: Thunder
    "sniper",  -- 3: Railgun
    "plasma",  -- 4: Inferno
    "medium",  -- 5: Cyclone
    "laser",   -- 6: Nova
    "granade", -- 7: Hellfire
    "shotgun", -- 8: Oblivion
}

local WEAPON_STATS = {
    light =   { speed = 600,  life = 2.5, damage = 10, radius = 5 },
    medium =  { speed = 700,  life = 2.0, damage = 20, radius = 7 },
    heavy =   { speed = 500,  life = 3.0, damage = 40, radius = 10 },
    sniper =  { speed = 1200, life = 1.5, damage = 35, radius = 4 },
    plasma =  { speed = 450,  life = 4.0, damage = 50, radius = 12 },
    laser =   { speed = 2000, life = 0.5, damage = 15, radius = 3 },
    granade = { speed = 400,  life = 2.0, damage = 60, radius = 15 },
    shotgun = { speed = 800,  life = 0.8, damage = 12, radius = 5 },
}

-- B7: Cooldowns de disparo por arma (indexados 1-8)
local WEAPON_COOLDOWNS = {
    0.5,  -- 1: Viper (light)
    0.8,  -- 2: Thunder (heavy)
    1.2,  -- 3: Railgun (sniper)
    0.6,  -- 4: Inferno (plasma)
    0.4,  -- 5: Cyclone (medium)
    0.3,  -- 6: Nova (laser)
    1.5,  -- 7: Hellfire (granade)
    0.2,  -- 8: Oblivion (shotgun)
}

function SimBullet.new(bullet_id, owner_pid, x, y, angle, weapon_idx)
    local self = setmetatable({}, SimBullet)

    self.id = bullet_id
    self.owner = owner_pid
    self.x = x
    self.y = y
    self.angle = angle
    self.weapon_idx = weapon_idx

    local weapon_type = WEAPON_TYPES[weapon_idx] or "light"
    local stats = WEAPON_STATS[weapon_type]

    self.speed = stats.speed
    self.damage = stats.damage
    self.radius = stats.radius
    self.lifetime = stats.life
    self.age = 0
    self.active = true

    return self
end

function SimBullet:tick(dt, map, sim_tanks)
    if not self.active then return end

    self.age = self.age + dt

    -- Comprobar tiempo de vida
    if self.age >= self.lifetime then
        self.active = false
        return "expired"
    end

    -- Mover bala
    self.x = self.x + math.cos(self.angle) * self.speed * dt
    self.y = self.y + math.sin(self.angle) * self.speed * dt

    -- Comprobar colisión con pared
    if collision.isBlocked(self.x, self.y, self.radius, map) then
        self.active = false
        return "wall"
    end

    -- Comprobar colisión con tanque
    for pid, tank in pairs(sim_tanks) do
        if pid ~= self.owner and not tank.isDead then
            local dx = self.x - tank.x
            local dy = self.y - tank.y
            local dist_sq = dx * dx + dy * dy
            local hit_radius = self.radius + 24  -- Radio del tanque de sim_tank.lua

            if dist_sq < hit_radius * hit_radius then
                self.active = false
                return "tank", pid, self.damage
            end
        end
    end

    return nil
end

-- B7: Obtener cooldown para arma específica
function SimBullet.get_shoot_cooldown(weapon_idx)
    return WEAPON_COOLDOWNS[weapon_idx] or 0.5  -- Por defecto 0.5s si el índice es inválido
end

return SimBullet
