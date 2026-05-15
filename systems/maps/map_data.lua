-- systems/maps/map_data.lua
-- Cargador de datos de mapa en Lua puro (sin dependencias de Love2D)
-- Parsea exportación Tiled-Lua y devuelve datos de colisión/spawn para cliente y servidor

local MapData = {}

function MapData.load()
    -- Cargar exportación Tiled (tabla Lua pura, sin Love2D)
    local tiledMap = require("systems.maps.map.mapa_black_steel")

    local walls = {}
    local rivers = {}
    local bridges = {}
    local spawns = {}
    local powerupSpawns = {}
    local size = {
        w = (tiledMap.width or 60) * (tiledMap.tilewidth or 64),
        h = (tiledMap.height or 34) * (tiledMap.tileheight or 64)
    }

    -- Parsear objetos de colisión
    for _, layer in ipairs(tiledMap.layers or {}) do
        if layer.type == "objectgroup" and layer.name == "colisiones" then
            for _, obj in ipairs(layer.objects or {}) do
                local t = obj.type or ""

                if t == "wall" then
                    walls[#walls+1] = {
                        x = obj.x,
                        y = obj.y,
                        w = obj.width,
                        h = obj.height,
                        dest = false,
                        hp = 0,
                        terrain = false
                    }
                elseif t == "destructible" then
                    local hp = 3
                    if obj.properties and obj.properties.hp then
                        hp = obj.properties.hp
                    end
                    walls[#walls+1] = {
                        x = obj.x,
                        y = obj.y,
                        w = obj.width,
                        h = obj.height,
                        dest = true,
                        hp = hp,
                        terrain = false
                    }
                elseif t == "river" then
                    rivers[#rivers+1] = {
                        x = obj.x,
                        y = obj.y,
                        w = obj.width,
                        h = obj.height
                    }
                elseif t == "bridge" then
                    bridges[#bridges+1] = {
                        x = obj.x,
                        y = obj.y,
                        w = obj.width,
                        h = obj.height
                    }
                end
            end
        end
    end

    -- Parsear objetos de spawn
    for _, layer in ipairs(tiledMap.layers or {}) do
        if layer.type == "objectgroup" and layer.name == "spawns" then
            local playerList = {}

            for _, obj in ipairs(layer.objects or {}) do
                local t = obj.type or ""

                if t == "player" then
                    local pid = 0
                    if obj.properties and obj.properties.id then
                        pid = obj.properties.id
                    end
                    playerList[#playerList+1] = {x = obj.x, y = obj.y, id = pid}

                elseif t == "powerup" then
                    local kind = "health"
                    if obj.properties and obj.properties.kind then
                        kind = obj.properties.kind
                    end
                    powerupSpawns[#powerupSpawns+1] = {
                        type = kind,
                        x = obj.x,
                        y = obj.y
                    }
                end
            end

            -- Ordenar spawns por ID
            table.sort(playerList, function(a, b) return a.id < b.id end)
            for _, p in ipairs(playerList) do
                spawns[#spawns+1] = {x = p.x, y = p.y}
            end
        end
    end

    return {
        walls = walls,
        rivers = rivers,
        bridges = bridges,
        spawns = spawns,
        powerupSpawns = powerupSpawns,
        size = size
    }
end

return MapData
