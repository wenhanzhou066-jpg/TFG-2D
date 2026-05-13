-- Colision compartida entre tanque y bots.
-- Evita duplicar la logica de isBlocked() en cada entidad.

local Collision = {}

local function circleVsPoly(cx, cy, r, poly)
    local n = #poly
    local inside = false
    local j = n
    for i = 1, n do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        if ((yi > cy) ~= (yj > cy)) and
           (cx < (xj - xi) * (cy - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    if inside then return true end
    j = n
    for i = 1, n do
        local ax, ay = poly[j].x, poly[j].y
        local bx, by = poly[i].x, poly[i].y
        local dx, dy = bx - ax, by - ay
        local lenSq  = dx*dx + dy*dy
        local t = lenSq > 0
            and math.max(0, math.min(1, ((cx-ax)*dx + (cy-ay)*dy) / lenSq))
            or 0
        local ex, ey = ax + t*dx - cx, ay + t*dy - cy
        if ex*ex + ey*ey < r*r then return true end
        j = i
    end
    return false
end

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
            if nx+r >= w.x and nx-r <= w.x+w.w and
               ny+r >= w.y and ny-r <= w.y+w.h then
                local hit = not w.polygon or circleVsPoly(nx, ny, r, w.polygon)
                if hit then return true end
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
                local inRiver = not rv.polygon or circleVsPoly(px, py, 1, rv.polygon)
                if inRiver then
                    local enPuente = false
                    for m = 1, #bridges do
                        local br = bridges[m]
                        if px >= br.x and px <= br.x+br.w and
                           py >= br.y and py <= br.y+br.h then
                            local onBridge = not br.polygon or circleVsPoly(px, py, 1, br.polygon)
                            if onBridge then enPuente = true; break end
                        end
                    end
                    if not enPuente then return true end
                end
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
                if px >= w.x and px <= w.x+w.w and
                   py >= w.y and py <= w.y+w.h then
                    local hit = not w.polygon or circleVsPoly(px, py, 1, w.polygon)
                    if hit then return false end
                end
            end
        end
    end
    return true
end

return Collision