-- server/collision.lua
-- Funciones de colisión en Lua puro (sin dependencias de Love2D)
-- Espeja systems/collision.lua pero opera sobre map_data en crudo

local Collision = {}

local TANK_RADIUS = 24  -- Debe coincidir con sim_tank.lua

-- Comprobación de colisión círculo-AABB
-- B6: Extendido para soportar colisión tanque contra tanque
function Collision.isBlocked(nx, ny, r, map, other_tanks, self_pid)
    -- Comprobar límites del mapa
    if nx - r < 0 or nx + r > map.size.w or
       ny - r < 0 or ny + r > map.size.h then
        return true
    end

    -- Comprobar paredes (círculo a AABB)
    for _, w in ipairs(map.walls) do
        if not (w.dest and w.hp <= 0) then
            local cx = math.max(w.x, math.min(nx, w.x + w.w))
            local cy = math.max(w.y, math.min(ny, w.y + w.h))
            if (nx - cx)^2 + (ny - cy)^2 < r * r then
                return true
            end
        end
    end

    -- Comprobar ríos (bloqueado salvo en puente)
    local offsets = { {r,0}, {-r,0}, {0,r}, {0,-r} }
    for k = 1, 4 do
        local px = nx + offsets[k][1]
        local py = ny + offsets[k][2]

        for _, rv in ipairs(map.rivers) do
            if px >= rv.x and px <= rv.x + rv.w and
               py >= rv.y and py <= rv.y + rv.h then
                local onBridge = false
                for _, br in ipairs(map.bridges) do
                    if px >= br.x and px <= br.x + br.w and
                       py >= br.y and py <= br.y + br.h then
                        onBridge = true
                        break
                    end
                end
                if not onBridge then
                    return true
                end
            end
        end
    end

    -- B6: Comprobar colisión tanque contra tanque
    if other_tanks and self_pid then
        for pid, tank in pairs(other_tanks) do
            if pid ~= self_pid and not tank.isDead then
                local dx = nx - tank.x
                local dy = ny - tank.y
                local dist_sq = dx * dx + dy * dy
                local sum_radius = r + TANK_RADIUS

                if dist_sq < sum_radius * sum_radius then
                    return true
                end
            end
        end
    end

    return false
end

return Collision
