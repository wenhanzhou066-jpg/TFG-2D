-- server/sim_tank.lua
-- Simulación del tanque en el lado del servidor
-- Constantes y lógica de movimiento copiadas de entities/tank.lua:75-212

local collision = require("server.collision")

-- Operaciones bit a bit (compatible con LuaJIT)
local bit = bit or bit32 or require("bit")

local SimTank = {}
SimTank.__index = SimTank

-- Constantes de movimiento (de entities/tank.lua:75-78, 208)
local ACCEL = 300
local VEL_MAX = 150
local FRICTION = 200
local TURN_SPEED = 2
local TANK_RADIUS = 24  -- Radio de colisión

-- Bits de máscara de entrada
local BIT_UP = 0
local BIT_DOWN = 1
local BIT_LEFT = 2
local BIT_RIGHT = 3
local BIT_FIRE = 4
local BIT_TURRET_L = 5
local BIT_TURRET_R = 6

function SimTank.new(pid, spawn, map)
    local self = setmetatable({}, SimTank)
    self.pid = pid
    self.x = spawn.x
    self.y = spawn.y
    self.angle = 0
    self.turretAngle = 0
    self.velocity = 0
    self.hp = 100
    self.isDead = false
    self.invuln = false
    self.invulnTimer = 0
    self.map = map
    return self
end

local function bit_test(bits, bit_pos)
    return bit.band(bits, bit.lshift(1, bit_pos)) ~= 0
end

function SimTank:apply_input(input_bits, turret_angle, dt, other_tanks)
    if self.isDead then return end

    -- Extraer bits de entrada
    local up = bit_test(input_bits, BIT_UP)
    local down = bit_test(input_bits, BIT_DOWN)
    local left = bit_test(input_bits, BIT_LEFT)
    local right = bit_test(input_bits, BIT_RIGHT)

    -- Actualizar velocidad (de tank.lua:183-193)
    if up then
        self.velocity = math.min(self.velocity + ACCEL * dt, VEL_MAX)
    elseif down then
        self.velocity = math.max(self.velocity - ACCEL * dt, -VEL_MAX / 2)
    else
        if self.velocity > 0 then
            self.velocity = math.max(self.velocity - FRICTION * dt, 0)
        elseif self.velocity < 0 then
            self.velocity = math.min(self.velocity + FRICTION * dt, 0)
        end
    end

    -- Calcular nueva posición (de tank.lua:195-196)
    local nx = self.x + math.cos(self.angle) * self.velocity * dt
    local ny = self.y + math.sin(self.angle) * self.velocity * dt

    -- B6: Colisión deslizante por eje con comprobaciones tanque-tanque
    local oldx, oldy = self.x, self.y
    if not collision.isBlocked(nx, ny, TANK_RADIUS, self.map, other_tanks, self.pid) then
        self.x, self.y = nx, ny
    else
        if not collision.isBlocked(nx, self.y, TANK_RADIUS, self.map, other_tanks, self.pid) then
            self.x = nx
        elseif not collision.isBlocked(self.x, ny, TANK_RADIUS, self.map, other_tanks, self.pid) then
            self.y = ny
        end
    end

    -- Girar solo al moverse (de tank.lua:208-212)
    if math.abs(self.velocity) > 5 then
        if left then
            self.angle = self.angle - TURN_SPEED * dt
        end
        if right then
            self.angle = self.angle + TURN_SPEED * dt
        end
    end

    -- Actualizar ángulo de torreta desde entrada del cliente
    self.turretAngle = turret_angle

    -- Actualizar temporizador de invulnerabilidad
    if self.invulnTimer > 0 then
        self.invulnTimer = self.invulnTimer - dt
        if self.invulnTimer <= 0 then
            self.invuln = false
        end
    end
end

function SimTank:take_damage(damage)
    if self.isDead or self.invuln then return 0 end

    self.hp = math.max(0, self.hp - damage)
    if self.hp <= 0 then
        self.isDead = true
        return damage
    end
    return damage
end

function SimTank:respawn(spawn)
    self.x = spawn.x
    self.y = spawn.y
    self.angle = 0
    self.turretAngle = 0
    self.velocity = 0
    self.hp = 100
    self.isDead = false
    self.invuln = true
    self.invulnTimer = 2.0  -- 2s de invulnerabilidad tras reaparición (de tank.lua:473)
end

-- Fase 5: Aplicar efectos de powerup
function SimTank:apply_powerup(powerup_type)
    if self.isDead then return end

    if powerup_type == "health" then
        -- Curar 50 HP (coincide con entities/powerup.lua)
        self.hp = math.min(100, self.hp + 50)

    elseif powerup_type == "ammo" then
        -- Sin sistema de munición en la implementación actual
        -- Reduciría el cooldown de disparo temporalmente
        -- Omitido por ahora

    elseif powerup_type == "shield" then
        -- Conceder invulnerabilidad temporal
        self.invuln = true
        self.invulnTimer = 5.0  -- 5 segundos de escudo

    elseif powerup_type == "speed" then
        -- El boost de velocidad modificaría VEL_MAX temporalmente
        -- No implementado en la simulación actual (sin temporizadores de boost)
        -- Omitido por ahora
    end
end

return SimTank
