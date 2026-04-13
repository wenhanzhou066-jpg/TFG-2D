-- Sistema de power-ups

local Powerup = {}

local active = {}
local sprites = {}

-- Tipos de power-ups
local PowerupTypes = {
    health = {
        img = "Pickup_health.png",
        color = {0.2, 1.0, 0.2},
        radius = 20,
        effect = function()
            if Tank and Tank.heal then
                Tank.heal(30)
            end
        end
    },
    ammo = {
        img = "Pickup_ammo.png",
        color = {1.0, 0.8, 0.2},
        radius = 20,
        effect = function()
            -- TODO: implementar sistema de munición
            print("[POWERUP] Ammo recogido")
        end
    },
    shield = {
        img = "Pickup_shield.png",
        color = {0.3, 0.5, 1.0},
        radius = 20,
        effect = function()
            -- TODO: implementar escudo temporal
            print("[POWERUP] Escudo activado")
        end
    },
    speed = {
        img = "Pickup_speed.png",
        color = {1.0, 0.3, 1.0},
        radius = 20,
        effect = function()
            -- TODO: implementar boost de velocidad
            print("[POWERUP] Speed boost activado")
        end
    }
}

-- Carga sprites (usar sprites genéricos si no existen los específicos)
function Powerup.load()
    -- Intentar cargar sprites específicos, fallback a círculos de colores
    for tipo, datos in pairs(PowerupTypes) do
        local path = "assets/images/PNG/Effects/" .. datos.img
        local ok, img = pcall(love.graphics.newImage, path)
        if ok then
            sprites[tipo] = img
        else
            -- No sprite, usaremos círculos de colores en draw()
            sprites[tipo] = nil
        end
    end
end

-- Spawna un power-up en posición específica
function Powerup.spawn(tipo, x, y)
    if not PowerupTypes[tipo] then
        print("[ERROR] Tipo de powerup desconocido: " .. tostring(tipo))
        return
    end

    table.insert(active, {
        tipo = tipo,
        x = x,
        y = y,
        radius = PowerupTypes[tipo].radius,
        bobTimer = 0,  -- Para animación de flotación
        collected = false,
        respawnTimer = 0,
        respawnDelay = 15.0  -- Respawn después de 15 segundos
    })
end

-- Update: animación y detección de colisión con tanque
function Powerup.update(dt)
    for i = #active, 1, -1 do
        local p = active[i]

        if p.collected then
            -- Esperando respawn
            p.respawnTimer = p.respawnTimer + dt
            if p.respawnTimer >= p.respawnDelay then
                p.collected = false
                p.respawnTimer = 0
            end
        else
            -- Animación de flotación
            p.bobTimer = p.bobTimer + dt

            -- Colisión con tanque del jugador
            if Tank and Tank.getBounds and not Tank.isDead() then
                local tx, ty, tr = Tank.getBounds()
                local dx = p.x - tx
                local dy = p.y - ty
                local distSq = dx*dx + dy*dy
                local sumRadius = p.radius + tr

                if distSq < sumRadius*sumRadius then
                    -- Recoger power-up
                    Powerup.collect(i)
                end
            end
        end
    end
end

-- Recoger power-up
function Powerup.collect(index)
    local p = active[index]
    if p.collected then return end

    local pType = PowerupTypes[p.tipo]
    if pType.effect then
        pType.effect()
    end

    p.collected = true
    p.respawnTimer = 0

    -- Efecto visual
    if Effects then
        Effects.spawnFlash(p.x, p.y)
    end

    -- Sonido (si existe)
    if Audio and Audio.powerup then
        Audio.powerup()
    end

    print("[POWERUP] Recogido: " .. p.tipo)
end

-- Dibujar power-ups
function Powerup.draw()
    for _, p in ipairs(active) do
        if not p.collected then
            local pType = PowerupTypes[p.tipo]

            -- Offset de flotación (sube y baja)
            local bobOffset = math.sin(p.bobTimer * 3) * 5

            local sprite = sprites[p.tipo]
            if sprite then
                -- Dibujar sprite
                love.graphics.setColor(1, 1, 1)
                local ox = sprite:getWidth() / 2
                local oy = sprite:getHeight() / 2
                love.graphics.draw(sprite, p.x, p.y + bobOffset, 0, 0.5, 0.5, ox, oy)
            else
                -- Dibujar círculo de color si no hay sprite
                love.graphics.setColor(pType.color[1], pType.color[2], pType.color[3], 0.8)
                love.graphics.circle("fill", p.x, p.y + bobOffset, p.radius)

                -- Borde blanco
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle("line", p.x, p.y + bobOffset, p.radius)
            end

            -- Icono de tipo (letra)
            love.graphics.setColor(1, 1, 1)
            local label = string.upper(string.sub(p.tipo, 1, 1))
            love.graphics.print(label, p.x - 5, p.y + bobOffset - 8)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

-- Limpiar todos los power-ups
function Powerup.clear()
    active = {}
end

-- Obtener power-ups activos (para multiplayer sync)
function Powerup.getActive()
    return active
end

return Powerup
