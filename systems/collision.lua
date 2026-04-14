-- Colision compartida entre tanque y bots.
-- Evita duplicar la logica de isBlocked() en cada entidad.

local Collision = {}

function Collision.isBlocked(nx, ny, r)
    if not Map then return false end
    local mw, mh = 1920, 1080
    if Map and Map.getSize then
        local sz = Map.getSize(); mw = sz.w; mh = sz.h
    end

    if nx - r < 0 or nx + r > mw or
       ny - r < 0 or ny + r > mh then
        return true
    end

    local walls = Map.getWalls()
    for j = 1, #walls do
        local w = walls[j]
        if not (w.dest and w.hp <= 0) then
            local cx = math.max(w.x, math.min(nx, w.x + w.w))
            local cy = math.max(w.y, math.min(ny, w.y + w.h))
            if (nx - cx)^2 + (ny - cy)^2 < r * r then
                return true
            end
        end
    end

    -- rios: bloqueantes salvo donde hay puente
    local rivers  = Map.getRivers()
    local bridges = Map.getBridges()
    local offsets = { {r,0}, {-r,0}, {0,r}, {0,-r} }
    for k = 1, 4 do
        local px = nx + offsets[k][1]
        local py = ny + offsets[k][2]
        for j = 1, #rivers do
            local rv = rivers[j]
            if px >= rv.x and px <= rv.x+rv.w and
               py >= rv.y and py <= rv.y+rv.h then
                local enPuente = false
                for m = 1, #bridges do
                    local br = bridges[m]
                    if px >= br.x and px <= br.x+br.w and
                       py >= br.y and py <= br.y+br.h then
                        enPuente = true; break
                    end
                end
                if not enPuente then return true end
            end
        end
    end

    return false
end

-- raycasting simple paso a paso contra muros
function Collision.lineOfSight(x1, y1, x2, y2)
    if not Map then return true end
    local walls = Map.getWalls and Map.getWalls() or {}
    local dist = math.sqrt((x2-x1)^2 + (y2-y1)^2)
    local pasos = math.max(1, math.floor(dist / 10))
    local dx = (x2 - x1) / pasos
    local dy = (y2 - y1) / pasos

    for p = 1, pasos do
        local px = x1 + dx * p
        local py = y1 + dy * p
        for i = 1, #walls do
            local w = walls[i]
            if not(w.dest and w.hp <= 0) then
                if px >= w.x and px <= w.x + w.w and
                   py >= w.y and py <= w.y + w.h then
                    return false -- bloqueado
                end
            end
        end
    end
    return true
end

return Collision