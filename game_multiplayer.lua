-- game_multiplayer.lua
-- Modo de juego multijugador para 2 jugadores

local GameMultiplayer = {}

local Red = require("network")

-- Los 3 mapas disponibles
local allMaps = {
    require("systems.maps.map"),
    require("systems.maps.map_volcano"),
    require("systems.maps.map_snow"),
}

-- Globales
Map = nil
Tank = require("entities.tank")
Bullet = require("entities.bullet")
Effects = require("systems.effects")
Tracks = require("systems.tracks")
Audio = require("systems.audio")
Camera = {x=0, y=0}   -- Cámara que sigue al tanque

-- Canvas de resolución fija
local GAME_W, GAME_H = 1920, 1080
local gameCanvas = nil
GameView = { scale = 1, ox = 0, oy = 0 }

local function recalcView()
    local sw, sh = love.graphics.getDimensions()
    local s = math.min(sw / GAME_W, sh / GAME_H)
    GameView.scale = s
    GameView.ox = math.floor((sw - GAME_W * s) / 2)
    GameView.oy = math.floor((sh - GAME_H * s) / 2)
end

-- Estado multijugador
local otherTanks = {} -- {player_id: {x, y, angulo, turretAngle, target_x, target_y, target_angulo}}
local subsystemsLoaded = false

-- Suavizado de interpolación
local INTERP_SPEED = 10  -- Velocidad de interpolación (mayor = más rápido)

-- Sprites para tanques enemigos
local otherTankSprites = {}

function GameMultiplayer.load(mapIdx)
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    Map = allMaps[mapIdx or 1]
    Map.load()
    Camera = {x=0, y=0}  -- Reiniciar cámara

    -- Obtener spawn point basado en ID de jugador
    local spawns = Map.getSpawns()
    local myPlayerId = Red.id_jugador or 1
    local spawnIndex = ((myPlayerId - 1) % #spawns) + 1  -- Ciclar entre spawns
    local spawn = spawns[spawnIndex]

    print(string.format("[MULTIPLAYER] Spawning player %d at spawn point %d: (%.0f, %.0f)",
        myPlayerId, spawnIndex, spawn.x, spawn.y))

    if not subsystemsLoaded then
        Tank.load(spawn.x, spawn.y)
        Bullet.load()
        Effects.load()
        Tracks.load()
        subsystemsLoaded = true

        -- Cargar sprites para otros tanques
        otherTankSprites.tracks = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
        otherTankSprites.hull = love.graphics.newImage("assets/images/PNG/Hulls_Color_B/Hull_01.png")
        otherTankSprites.weapon = love.graphics.newImage("assets/images/PNG/Weapon_Color_B/Gun_01.png")
    else
        Tank.load(spawn.x, spawn.y)
    end

    Audio.load(mapIdx or 1)

    -- La red ya está inicializada desde el lobby
    print("[MULTIPLAYER] Juego iniciado")
end

function GameMultiplayer.update(dt)
    -- Actualizar tanque local
    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)

    -- Actualizar cámara para seguir al tanque
    local mapSize = Map.getSize()
    local tx, ty = Tank.getPosition()
    Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
    Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))

    -- Enviar posición a servidor
    local x, y, angle = Tank.getPosition()
    local _, turretAngle = Tank.getAngles()
    Red.update(dt, x, y, angle)

    -- Recibir posiciones de otros jugadores
    local otherPlayers = Red.obtener_otros_jugadores()

    -- Debug: contar otros jugadores
    local count = 0
    for _ in pairs(otherPlayers) do count = count + 1 end
    if count > 0 then
        print(string.format("[MULTIPLAYER] %d otro(s) jugador(es) detectado(s)", count))
    end

    -- Actualizar posiciones objetivo de otros jugadores
    for pid, pdata in pairs(otherPlayers) do
        if not otherTanks[pid] then
            -- Nuevo jugador: crear con posición inicial
            print(string.format("[MULTIPLAYER] Nuevo jugador detectado: ID=%d, pos=(%.0f, %.0f)",
                pid, pdata.x, pdata.y))
            otherTanks[pid] = {
                x = pdata.x,
                y = pdata.y,
                angulo = pdata.angulo,
                turretAngle = pdata.angulo,
                target_x = pdata.x,
                target_y = pdata.y,
                target_angulo = pdata.angulo
            }
        else
            -- Actualizar objetivos
            otherTanks[pid].target_x = pdata.x
            otherTanks[pid].target_y = pdata.y
            otherTanks[pid].target_angulo = pdata.angulo
        end
    end

    -- Interpolar suavemente hacia las posiciones objetivo
    for pid, tank in pairs(otherTanks) do
        if otherPlayers[pid] then
            -- Interpolar posición
            tank.x = tank.x + (tank.target_x - tank.x) * INTERP_SPEED * dt
            tank.y = tank.y + (tank.target_y - tank.y) * INTERP_SPEED * dt

            -- Interpolar ángulo (tomar el camino más corto)
            local diff = tank.target_angulo - tank.angulo
            -- Normalizar diferencia al rango [-π, π]
            while diff > math.pi do diff = diff - 2 * math.pi end
            while diff < -math.pi do diff = diff + 2 * math.pi end
            tank.angulo = tank.angulo + diff * INTERP_SPEED * dt

            -- Actualizar ángulo de torreta
            tank.turretAngle = tank.angulo
        end
    end

    -- Eliminar jugadores desconectados
    for pid, _ in pairs(otherTanks) do
        if not otherPlayers[pid] then
            otherTanks[pid] = nil
        end
    end

    -- Recibir y crear balas de otros jugadores
    local balas_recibidas = Red.obtener_balas_recibidas()
    for _, bala in ipairs(balas_recibidas) do
        Bullet.spawn(bala.x, bala.y, bala.angulo, bala.tipo)
    end
end

function GameMultiplayer.draw()
    -- Renderizar al canvas con cámara aplicada
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.10, 0.10, 0.10)
    love.graphics.push()
    love.graphics.translate(-math.floor(Camera.x), -math.floor(Camera.y))

    Map.drawGround()
    Tracks.draw()

    -- Dibujar tanques enemigos
    GameMultiplayer.drawOtherTanks()

    -- Dibujar tanque local
    Tank.draw()

    Bullet.draw()
    Effects.draw()
    Map.drawAbove()

    love.graphics.pop()

    -- HUD multijugador (sin cámara)
    GameMultiplayer.drawHUD()

    -- Dibujar canvas escalado a pantalla
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy, 0, GameView.scale, GameView.scale)
end

function GameMultiplayer.drawOtherTanks()
    local escala = 0.3

    -- Debug: mostrar cuántos tanques hay que dibujar
    local count = 0
    for _ in pairs(otherTanks) do count = count + 1 end

    for pid, tank in pairs(otherTanks) do
        love.graphics.push()
        love.graphics.translate(tank.x, tank.y)

        -- Tracks
        love.graphics.push()
        love.graphics.rotate(tank.angulo + math.pi/2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            otherTankSprites.tracks,
            0, 0,
            0,
            escala, escala,
            otherTankSprites.tracks:getWidth()/2,
            otherTankSprites.tracks:getHeight()/2
        )
        love.graphics.pop()

        -- Hull
        love.graphics.push()
        love.graphics.rotate(tank.angulo + math.pi/2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            otherTankSprites.hull,
            0, 0,
            0,
            escala, escala,
            otherTankSprites.hull:getWidth()/2,
            otherTankSprites.hull:getHeight()/2
        )
        love.graphics.pop()

        -- Weapon
        love.graphics.push()
        love.graphics.rotate(tank.turretAngle + math.pi/2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            otherTankSprites.weapon,
            15 * math.cos(tank.turretAngle),
            15 * math.sin(tank.turretAngle),
            0,
            escala, escala,
            otherTankSprites.weapon:getWidth()/2,
            otherTankSprites.weapon:getHeight()/2
        )
        love.graphics.pop()

        -- ID del jugador
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("P" .. pid, 0 - 10, -50)

        love.graphics.pop()
    end
end

function GameMultiplayer.drawHUD()
    love.graphics.setColor(1, 1, 1)
    local UI = require("systems.ui")
    if UI.fonts and UI.fonts.small then
        love.graphics.setFont(UI.fonts.small)
    end

    local playerCount = 1 -- nosotros
    for _ in pairs(otherTanks) do
        playerCount = playerCount + 1
    end

    local myId = Red.id_jugador or "?"
    love.graphics.print("MULTIJUGADOR | Tu ID: " .. myId .. " | Jugadores: " .. playerCount, 10, 10)

    -- Debug info
    local tx, ty = Tank.getPosition()
    love.graphics.print(string.format("Mi pos: (%.0f, %.0f) | Conectado: %s",
        tx, ty, Red.esta_conectado() and "SI" or "NO"), 10, 30)

    -- Listar otros tanques
    local y = 50
    for pid, tank in pairs(otherTanks) do
        love.graphics.print(string.format("  P%d: (%.0f, %.0f)", pid, tank.x, tank.y), 10, y)
        y = y + 20
    end

    love.graphics.setColor(1, 1, 1)
end

function GameMultiplayer.keypressed(key, goMenu)
    if key == "escape" then
        Red.desconectar()
        goMenu()
    end
end

function GameMultiplayer.mousepressed(x, y, button)
    if button == 1 then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, "light")
        Effects.spawnSmoke(bx, by, angle)
        Red.enviar_bala(bx, by, angle, "light")
    end
end

function GameMultiplayer.stopAudio()
    Audio.pararMusica()
end

return GameMultiplayer
