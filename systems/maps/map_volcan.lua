-- systems/maps/map_volcan.lua  –  Mapa Volcán (STI + Tiled)
-- Mundo 3840x2176  (60x34 tiles a 64px)
-- Capas Tiled: terreno | caminos | rio | decoracion | arboles | colisiones | spawns

local sti = require("libs.sti")

local Map = {}
local W, H = 3840, 2176

local stiMap        = nil
local walls         = {}
local rivers        = {}
local bridges       = {}
local spawns        = {}
local powerupSpawns = {}

function Map.getSize() return {w=W, h=H} end

local GROUND_LAYERS = {"terreno", "caminos", "rio", "decoracion"}
local ABOVE_LAYERS  = {"arboles"}

-- Incluye "arboles" porque algunos sprites de edificio (tejados altos) se
-- colocan ahí para quedar por encima del overlay de escombros.
local BUILDING_TILE_LAYERS = {decoracion = true, arboles = true}

local function objBounds(obj)
    if obj.polygon then
        local minx, miny, maxx, maxy = math.huge, math.huge, -math.huge, -math.huge
        for _, pt in ipairs(obj.polygon) do
            if pt.x < minx then minx = pt.x end
            if pt.y < miny then miny = pt.y end
            if pt.x > maxx then maxx = pt.x end
            if pt.y > maxy then maxy = pt.y end
        end
        return minx, miny, maxx - minx, maxy - miny
    end
    return obj.x, obj.y, obj.width, obj.height
end

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

-- terreno.tsx / tilemap_64x64_clean.tsx / ts_small.tsx / ts_large.tsx
-- son tilesets del proyecto antiguo no incluidos; se descartan automáticamente.
local KNOWN_TILESETS = {
    ["64x64.tsx"]   = "../../assets/maps/volcan/64x64.tsx",
    ["128x128.tsx"] = "../../assets/maps/volcan/128x128.tsx",
    ["256x256.tsx"] = "../../assets/maps/volcan/256x256.tsx",
}

local function fixMapTilesets(data)
    if type(data) ~= "table" or not data.tilesets then return data end
    local kept = {}
    for _, ts in ipairs(data.tilesets) do
        if ts.filename then
            local fname = ts.filename:match("([^/\\]+%.tsx)$")
            local fixed = fname and KNOWN_TILESETS[fname]
            if fixed then
                ts.filename = fixed
                kept[#kept+1] = ts
            end
        else
            kept[#kept+1] = ts
        end
    end
    data.tilesets = kept
    return data
end

local function clearBuildingTiles(w)
    if not stiMap then return end
    local baseH = stiMap.tileheight
    for _, instances in pairs(stiMap.tileInstances) do
        for _, inst in ipairs(instances) do
            if inst.layer and BUILDING_TILE_LAYERS[inst.layer.name]
               and inst.batch and inst.id then
                local td = stiMap.tiles[inst.gid]
                local tw = (td and td.width)  or stiMap.tilewidth
                local th = (td and td.height) or stiMap.tileheight
                local clear
                if th > baseH then
                    local y1 = w.y - (th - baseH)
                    clear = inst.x < w.x + w.w and inst.x + tw > w.x and
                            inst.y < w.y + w.h  and inst.y + th > y1
                else
                    clear = inst.x < w.x + w.w and inst.x + tw > w.x and
                            inst.y < w.y + w.h  and inst.y + th > w.y
                end
                if clear then
                    inst.batch:set(inst.id, inst.x, inst.y, inst.r, 0, 0)
                end
            end
        end
    end
end

local MAP_FILE = "systems/maps/mapa_black_steel_volcano.lua"

function Map.load()
    walls, rivers, bridges, spawns, powerupSpawns = {},{},{},{},{}

    local origLoad = love.filesystem.load
    love.filesystem.load = function(path)
        local fn = origLoad(path)
        if path == MAP_FILE then
            return function()
                return fixMapTilesets(fn())
            end
        end
        return fn
    end
    stiMap = sti(MAP_FILE)
    love.filesystem.load = origLoad

    local col = stiMap.layers["colisiones"]
    if col and col.objects then
        for _, obj in ipairs(col.objects) do
            local t = obj.type or obj.class or ""
            local bx, by, bw, bh = objBounds(obj)
            local poly = nil
            if obj.polygon then
                poly = {}
                for _, pt in ipairs(obj.polygon) do
                    poly[#poly+1] = {x = pt.x, y = pt.y}
                end
            end
            if t == "wall" or t == "" then
                walls[#walls+1] = {x=bx, y=by, w=bw, h=bh, polygon=poly, dest=false, hp=0, terrain=false}
            elseif t == "destructible" then
                local hp = (obj.properties and obj.properties.hp) or 3
                walls[#walls+1] = {x=bx, y=by, w=bw, h=bh, polygon=poly, dest=true, hp=hp, terrain=false}
            elseif t == "river" then
                rivers[#rivers+1] = {x=bx, y=by, w=bw, h=bh, polygon=poly}
            elseif t == "bridge" then
                bridges[#bridges+1] = {x=bx, y=by, w=bw, h=bh, polygon=poly}
            end
        end
    end

    local sp = stiMap.layers["spawns"]
    if sp and sp.objects then
        local playerList = {}
        for _, obj in ipairs(sp.objects) do
            local t = obj.type or obj.class or ""
            if t == "player" then
                local pid = (obj.properties and obj.properties.id) or 0
                playerList[#playerList+1] = {x=obj.x, y=obj.y, id=pid}
            elseif t == "powerup" then
                local kind = (obj.properties and obj.properties.kind) or "health"
                powerupSpawns[#powerupSpawns+1] = {type=kind, x=obj.x, y=obj.y}
            end
        end
        table.sort(playerList, function(a, b) return a.id < b.id end)
        for _, p in ipairs(playerList) do
            spawns[#spawns+1] = {x=p.x, y=p.y}
        end
    end

    local nWall, nDest = 0, 0
    for _, w in ipairs(walls) do
        if w.dest then nDest = nDest + 1 else nWall = nWall + 1 end
    end
    print(string.format(
        "[MapVolcan] Cargado: %d walls, %d destructible, %d rivers, %d bridges, %d spawns, %d powerups",
        nWall, nDest, #rivers, #bridges, #spawns, #powerupSpawns))
end

local function drawDestroyedOverlay(w)
    love.graphics.setColor(0.25, 0.2, 0.15, 0.7)
    love.graphics.rectangle("fill", w.x + w.w*0.1, w.y + w.h*0.15, w.w*0.35, w.h*0.3)
    love.graphics.rectangle("fill", w.x + w.w*0.5, w.y + w.h*0.5,  w.w*0.4,  w.h*0.35)
    love.graphics.setColor(0.18, 0.14, 0.1, 0.5)
    love.graphics.rectangle("fill", w.x + w.w*0.3, w.y + w.h*0.35, w.w*0.25, w.h*0.25)
    love.graphics.setColor(1, 1, 1)
end

function Map.drawGround()
    love.graphics.setColor(1, 1, 1)
    for _, name in ipairs(GROUND_LAYERS) do
        local layer = stiMap.layers[name]
        if layer then stiMap:drawLayer(layer) end
    end
    for _, w in ipairs(walls) do
        if w.dest then
            if w.hp <= 0 then
                drawDestroyedOverlay(w)
            elseif w.hp == 1 then
                love.graphics.setColor(0, 0, 0, 0.55)
                love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            elseif w.hp == 2 then
                love.graphics.setColor(0, 0, 0, 0.22)
                love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
            end
            love.graphics.setColor(1, 1, 1)
        end
    end
end

function Map.drawAbove()
    love.graphics.setColor(1, 1, 1)
    for _, name in ipairs(ABOVE_LAYERS) do
        local layer = stiMap.layers[name]
        if layer then stiMap:drawLayer(layer) end
    end
end

function Map.getWalls()         return walls         end
function Map.getRivers()        return rivers        end
function Map.getBridges()       return bridges       end
function Map.getSpawns()        return spawns        end
function Map.getPowerupSpawns() return powerupSpawns end

local debugCollision = false
function Map.toggleDebug() debugCollision = not debugCollision end

function Map.drawDebug()
    if not debugCollision then return end
    love.graphics.setLineWidth(2)
    for _, w in ipairs(walls) do
        if w.dest then
            if w.hp <= 0 then
                love.graphics.setColor(0.4, 0.4, 0.4, 0.8)
            else
                love.graphics.setColor(1, 0.4, 0, 0.8)
            end
        else
            love.graphics.setColor(1, 0, 0, 0.8)
        end
        if w.polygon then
            local verts = {}
            for _, pt in ipairs(w.polygon) do
                verts[#verts+1] = pt.x
                verts[#verts+1] = pt.y
            end
            love.graphics.polygon("line", verts)
        else
            love.graphics.rectangle("line", w.x, w.y, w.w, w.h)
        end
    end
    for _, rv in ipairs(rivers) do
        love.graphics.setColor(0, 0.5, 1, 0.6)
        if rv.polygon then
            local verts = {}
            for _, pt in ipairs(rv.polygon) do verts[#verts+1]=pt.x; verts[#verts+1]=pt.y end
            love.graphics.polygon("line", verts)
        else
            love.graphics.rectangle("line", rv.x, rv.y, rv.w, rv.h)
        end
    end
    for _, br in ipairs(bridges) do
        love.graphics.setColor(0, 1, 0.5, 0.6)
        if br.polygon then
            local verts = {}
            for _, pt in ipairs(br.polygon) do verts[#verts+1]=pt.x; verts[#verts+1]=pt.y end
            love.graphics.polygon("line", verts)
        else
            love.graphics.rectangle("line", br.x, br.y, br.w, br.h)
        end
    end
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

function Map.bulletHit(x, y, r)
    r = r or 1
    for _, w in ipairs(walls) do
        if w.terrain then goto next_bh end
        if x+r >= w.x and x-r <= w.x+w.w and
           y+r >= w.y and y-r <= w.y+w.h then
            local hit = not w.polygon or circleVsPoly(x, y, r, w.polygon)
            if hit then
                if w.dest then
                    if w.hp > 0 then
                        w.hp = w.hp - 1
                        if w.hp <= 0 then clearBuildingTiles(w) end
                        return true
                    end
                else
                    return true
                end
            end
        end
        ::next_bh::
    end
    return false
end

function Map.isBlocked(x, y)
    for _, w in ipairs(walls) do
        if w.terrain then goto next_ib end
        if not (w.dest and w.hp <= 0) then
            if x+1 >= w.x and x-1 <= w.x+w.w and
               y+1 >= w.y and y-1 <= w.y+w.h then
                local hit = not w.polygon or circleVsPoly(x, y, 1, w.polygon)
                if hit then return true end
            end
        end
        ::next_ib::
    end
    for _, rv in ipairs(rivers) do
        if x >= rv.x and x <= rv.x+rv.w and
           y >= rv.y and y <= rv.y+rv.h then
            local inRiver = not rv.polygon or circleVsPoly(x, y, 1, rv.polygon)
            if inRiver then
                for _, b in ipairs(bridges) do
                    if x >= b.x and x <= b.x+b.w and
                       y >= b.y and y <= b.y+b.h then
                        local onBridge = not b.polygon or circleVsPoly(x, y, 1, b.polygon)
                        if onBridge then return false end
                    end
                end
                return true
            end
        end
    end
    return false
end

return Map
