-- systems/maps/map.lua  –  Mapa Bosque (STI + Tiled)
-- Mundo 3840x2176  (60x34 tiles a 64px)
-- Capas Tiled: terreno | caminos | rio | decoracion | arboles | colisiones | spawns

local sti = require("libs.sti")

local Map = {}
local W, H = 3840, 2176

local stiMap        = nil
local walls         = {}   -- {x,y,w,h, dest,hp, terrain}
local rivers        = {}   -- {x,y,w,h}
local bridges       = {}   -- {x,y,w,h}
local spawns        = {}   -- {x,y}
local powerupSpawns = {}   -- {type,x,y}
local ruinsImg      = nil  -- imagen de edificio destruido

function Map.getSize() return {w=W, h=H} end

local GROUND_LAYERS = {"terreno", "caminos", "rio", "decoracion"}
local ABOVE_LAYERS  = {"arboles"}

-- ── Carga ─────────────────────────────────────────────────────
function Map.load()
    walls, rivers, bridges, spawns, powerupSpawns = {},{},{},{},{}

    if love.filesystem.getInfo("assets/images/edificio_destruido.png") then
        ruinsImg = love.graphics.newImage("assets/images/edificio_destruido.png")
    end

    stiMap = sti("systems/maps/map/mapa_black_steel.lua")

    -- Capa de colisiones
    local col = stiMap.layers["colisiones"]
    if col and col.objects then
        for _, obj in ipairs(col.objects) do
            local t = obj.type or obj.class or ""
            if t == "wall" then
                walls[#walls+1] = {
                    x=obj.x, y=obj.y, w=obj.width, h=obj.height,
                    dest=false, hp=0, terrain=false
                }
            elseif t == "destructible" then
                local hp = (obj.properties and obj.properties.hp) or 3
                walls[#walls+1] = {
                    x=obj.x, y=obj.y, w=obj.width, h=obj.height,
                    dest=true, hp=hp, terrain=false
                }
            elseif t == "river" then
                rivers[#rivers+1] = {x=obj.x, y=obj.y, w=obj.width, h=obj.height}
            elseif t == "bridge" then
                bridges[#bridges+1] = {x=obj.x, y=obj.y, w=obj.width, h=obj.height}
            end
        end
    end

    -- Capa de spawns
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

    -- Verificacion de consola
    local nWall, nDest = 0, 0
    for _, w in ipairs(walls) do
        if w.dest then nDest = nDest + 1 else nWall = nWall + 1 end
    end
    print(string.format(
        "[Map] Cargado: %d walls, %d destructible, %d rivers, %d bridges, %d spawns, %d powerups",
        nWall, nDest, #rivers, #bridges, #spawns, #powerupSpawns))
end

-- ── Dibujo ────────────────────────────────────────────────────
function Map.drawGround()
    love.graphics.setColor(1, 1, 1)
    for _, name in ipairs(GROUND_LAYERS) do
        local layer = stiMap.layers[name]
        if layer then stiMap:drawLayer(layer) end
    end

    -- Overlay de daño en edificios destruibles
    for _, w in ipairs(walls) do
        if w.dest then
            if w.hp <= 0 then
                if ruinsImg then
                    local iw, ih = ruinsImg:getDimensions()
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.draw(ruinsImg, w.x, w.y, 0, w.w / iw, w.h / ih)
                end
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

-- ── API de colision ───────────────────────────────────────────
function Map.getWalls()         return walls         end
function Map.getRivers()        return rivers        end
function Map.getBridges()       return bridges       end
function Map.getSpawns()        return spawns        end
function Map.getPowerupSpawns() return powerupSpawns end

function Map.bulletHit(x, y, r)
    r = r or 1
    for _, w in ipairs(walls) do
        if w.terrain then goto next_bh end
        if x+r >= w.x and x-r <= w.x+w.w and
           y+r >= w.y and y-r <= w.y+w.h then
            if w.dest then
                if w.hp > 0 then w.hp = w.hp - 1; return true end
            else
                return true
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
            if x >= w.x and x <= w.x+w.w and
               y >= w.y and y <= w.y+w.h then
                return true
            end
        end
        ::next_ib::
    end
    for _, rv in ipairs(rivers) do
        if x >= rv.x and x <= rv.x+rv.w and
           y >= rv.y and y <= rv.y+rv.h then
            for _, b in ipairs(bridges) do
                if x >= b.x and x <= b.x+b.w and
                   y >= b.y and y <= b.y+b.h then
                    return false
                end
            end
            return true
        end
    end
    return false
end

return Map
