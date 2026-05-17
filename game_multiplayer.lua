-- game_multiplayer.lua
-- Modo de juego multijugador para 2 jugadores

local GameMultiplayer = {}

local Settings = require("systems.settings")
local leaderboard = require("systems.leaderboard")
local Minimap     = require("systems.minimap")
local Perfil      = require("systems.perfil")
local Pausa       = require("systems.pausa")

local stats = { kills = 0, muertes = 0, victoria = false }
local pausado = false

local MAX_MUERTES = 3
local eliminado = false
local elimGoMenu = nil  -- guardado en keypressed/mousepressed para usarlo desde el overlay

local Red = require("network")

-- Mapa activo (STI). Los mapas procedurales están deshabilitados temporalmente.
local allMaps = {
    require("systems.maps.map"),
    require("systems.maps.map_volcan"),
    require("systems.maps.map_nieve"),
}

-- Globales
Map = nil
Tank = require("entities.tank")
Bullet = require("entities.bullet")
Powerup = require("entities.powerup")
Effects = require("systems.effects")
Tracks = require("systems.tracks")
Audio = require("systems.audio")
Camera = {x=0, y=0}   -- Cámara que sigue al tanque

-- Exponer GameMultiplayer a Bullet para collision check
_G.GameMultiplayer = GameMultiplayer

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
local otherTanks = {} -- {player_id: {x, y, angulo, turretAngle, target_x, target_y, target_angulo, hp, maxHp}}
local subsystemsLoaded = false

-- Sistema de notificaciones de powerups
local powerupNotification = {
    active = false,
    text = "",
    timer = 0,
    duration = 3.0,  -- Mostrar por 3 segundos
    powerupTimer = 0,  -- Tiempo restante del powerup
    powerupDuration = 0  -- Duración total del powerup
}

-- Suavizado de interpolación
local INTERP_SPEED = 15  -- Velocidad de interpolación (mayor = más rápido, menos lag)

-- Exponer otherTanks para collision detection
function GameMultiplayer.getOtherTanks()
    return otherTanks
end

-- Aplicar daño predictivo local a otro tanque (para feedback visual inmediato)
-- Retorna true si mata al tanque
function GameMultiplayer.damageOtherTank(pid, damage)
    if otherTanks[pid] then
        local oldHp = otherTanks[pid].hp
        otherTanks[pid].hp = math.max(0, oldHp - damage)

        -- Checar si murió
        if oldHp > 0 and otherTanks[pid].hp <= 0 then
            Effects.spawnExplosion(otherTanks[pid].x, otherTanks[pid].y)
            return true  -- Kill confirmado
        end
    end
    return false
end

-- Mostrar notificación de powerup recogido
function GameMultiplayer.showPowerupNotification(powerupType, duration)
    local names = Settings.idioma == "EN" and {
        health = "MEDKIT",
        ammo = "RAPID FIRE",
        shield = "SHIELD",
        speed = "SPEED"
    } or {
        health = "KIT MÉDICO",
        ammo = "DISPARO RÁPIDO",
        shield = "ESCUDO",
        speed = "VELOCIDAD"
    }
    powerupNotification.text = names[powerupType] or (Settings.idioma == "EN" and "UPGRADE" or "MEJORA")
    powerupNotification.active = true
    powerupNotification.timer = 0
    powerupNotification.powerupTimer = duration or 0
    powerupNotification.powerupDuration = duration or 0
end

-- Sprites para tanques enemigos
local otherTankSprites = {}

function GameMultiplayer.addKill()   stats.kills   = stats.kills   + 1 end
function GameMultiplayer.addMuerte()
    stats.muertes = stats.muertes + 1
    if stats.muertes >= MAX_MUERTES then
        eliminado = true
    end
end

function GameMultiplayer.load(mapIdx)
    stats = { kills = 0, muertes = 0, victoria = false }
    eliminado = false
    elimGoMenu = nil
    otherTanks = {}
    powerupNotification.active = false
    powerupNotification.timer = 0
    Red.in_game = true
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    Map = allMaps[mapIdx or 1] or allMaps[1]
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
        Bullet.setPlayerWeapon(Perfil.activo and Perfil.activo.weaponIdx or 1)
        Powerup.load()
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

    -- Override ammo to finite clip for multiplayer (single-player keeps 999)
    local tanks = Tank.getTanks()
    if tanks[1] then
        tanks[1].maxAmmo = 6
        tanks[1].ammo = 6
        tanks[1].reloadDuration = 2.0
    end

    -- Spawnar power-ups
    Powerup.clear()
    local powerupSpawns = Map.getPowerupSpawns()
    for _, sp in ipairs(powerupSpawns) do
        Powerup.spawn(sp.type, sp.x, sp.y)
    end

    Audio.load(mapIdx or 1)
    Minimap.load()
    Pausa.load()

    -- La red ya está inicializada desde el lobby
    print("[MULTIPLAYER] Juego iniciado")
end

function GameMultiplayer.update(dt)
    if eliminado then return end
    if pausado then
        Pausa.update(dt)
        return
    end

    -- Actualizar tanque local
    Tank.update(dt)
    Bullet.update(dt)
    Powerup.update(dt)
    Effects.update(dt)
    Tracks.update(dt)

    -- Actualizar notificación de powerup
    if powerupNotification.active then
        powerupNotification.timer = powerupNotification.timer + dt
        if powerupNotification.powerupDuration > 0 then
            powerupNotification.powerupTimer = math.max(0, powerupNotification.powerupTimer - dt)
        end
        if powerupNotification.timer >= powerupNotification.duration then
            powerupNotification.active = false
        end
    end

    -- Actualizar cámara para seguir al tanque
    local mapSize = Map.getSize()
    local tx, ty = Tank.getPosition()
    Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
    Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))
    Minimap.update(tx, ty)

    -- Enviar posición y HP a servidor
    local x, y, angle = Tank.getPosition()
    local _, turretAngle = Tank.getAngles()
    local hp, maxHp = Tank.getHP()
    Red.update(dt, x, y, angle, hp)

    -- Recibir posiciones de otros jugadores
    local otherPlayers = Red.obtener_otros_jugadores()

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
                target_angulo = pdata.angulo,
                hp = 100,
                maxHp = 100
            }
        else
            -- Actualizar objetivos
            otherTanks[pid].target_x = pdata.x
            otherTanks[pid].target_y = pdata.y
            otherTanks[pid].target_angulo = pdata.angulo
            otherTanks[pid].hp = pdata.hp or 100
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
        Bullet.spawn(bala.x, bala.y, bala.angulo, bala.tipo, "network")
    end

    -- Procesar eventos de powerup del servidor (AUTH mode)
    for _, ev in ipairs(Red.get_powerup_events()) do
        if ev.kind == "collected" then
            Powerup.removeByIndex(ev.index)
            if ev.player_id == Red.id_jugador then
                GameMultiplayer.showPowerupNotification(ev.powerup_type, 15)
            end
        elseif ev.kind == "spawn" then
            Powerup.respawnByIndex(ev.index)
        end
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
    Powerup.draw()

    -- Dibujar tanques enemigos
    GameMultiplayer.drawOtherTanks()

    -- Dibujar tanque local
    Tank.draw()

    Bullet.draw()
    Effects.draw()
    Map.drawAbove()

    love.graphics.pop()
    Minimap.drawFogToCurrentCanvas(Camera.x, Camera.y)

    -- HUD multijugador (sin cámara)
    GameMultiplayer.drawHUD()

    -- Dibujar canvas escalado a pantalla
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy, 0, GameView.scale, GameView.scale)

    if eliminado then
        GameMultiplayer.drawEliminacionOverlay()
    end

    if pausado then
        Pausa.draw()
        local Remap = require("systems.controls_remap")
        if Remap.isVisible() then
            love.graphics.push()
            love.graphics.translate(GameView.ox, GameView.oy)
            love.graphics.scale(GameView.scale, GameView.scale)
            Remap.draw()
            love.graphics.pop()
        end
    end
end

function GameMultiplayer.drawEliminacionOverlay()
    local sw, sh = love.graphics.getDimensions()
    local UI = require("systems.ui")

    -- Fondo oscuro semitransparente
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    -- Panel central
    local pw, ph = 520, 320
    local px, py = sw/2 - pw/2, sh/2 - ph/2
    love.graphics.setColor(0.08, 0.05, 0.05, 0.97)
    love.graphics.rectangle("fill", px, py, pw, ph, 12, 12)
    love.graphics.setColor(0.7, 0.1, 0.1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", px, py, pw, ph, 12, 12)
    love.graphics.setLineWidth(1)

    -- Título
    local titleFont = UI.font("title") or UI.font("button") or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.9, 0.15, 0.15, 1)
    love.graphics.printf(Settings.idioma == "EN" and "ELIMINATED" or "ELIMINADO", px, py + 30, pw, "center")

    -- Subtítulo
    local bodyFont = UI.font("button") or love.graphics.getFont()
    love.graphics.setFont(bodyFont)
    love.graphics.setColor(0.85, 0.85, 0.85, 1)
    love.graphics.printf(Settings.idioma == "EN" and "You died " .. MAX_MUERTES .. " times" or "Has muerto " .. MAX_MUERTES .. " veces", px, py + 95, pw, "center")

    -- Stats
    local smallFont = UI.font("small") or love.graphics.getFont()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.printf(
        string.format(Settings.idioma == "EN" and "Kills: %d   |   Deaths: %d" or "Bajas: %d   |   Muertes: %d", stats.kills, stats.muertes),
        px, py + 145, pw, "center")

    -- Botón volver al menú
    local bw, bh = 260, 50
    local bx, by = sw/2 - bw/2, py + 230
    local mx, my = love.mouse.getPosition()
    local hover = mx >= bx and mx <= bx+bw and my >= by and my <= by+bh

    love.graphics.setColor(hover and 0.85 or 0.65, hover and 0.15 or 0.1, hover and 0.15 or 0.1, 1)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(bodyFont)
    love.graphics.printf(Settings.idioma == "EN" and "Back to menu" or "Volver al menú", bx, by + 13, bw, "center")

    love.graphics.setColor(1, 1, 1)
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
        love.graphics.translate(15 * math.cos(tank.turretAngle), 15 * math.sin(tank.turretAngle))
        love.graphics.rotate(tank.turretAngle + math.pi/2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(
            otherTankSprites.weapon,
            0, 0,
            0,
            escala, escala,
            otherTankSprites.weapon:getWidth()/2,
            otherTankSprites.weapon:getHeight()/2
        )
        love.graphics.pop()

        -- ID del jugador
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("P" .. pid, 0 - 10, -50)

        -- Barra de vida
        local barW = 60
        local barH = 6
        local barX = -barW/2
        local barY = -50

        local hpPercent = tank.hp / tank.maxHp

        -- Fondo negro
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", barX-1, barY-1, barW+2, barH+2)

        -- Barra HP con color
        local r, g, b
        if hpPercent > 0.6 then
            r, g, b = 0.2, 0.8, 0.2
        elseif hpPercent > 0.3 then
            r, g, b = 1.0, 0.8, 0.0
        else
            r, g, b = 1.0, 0.2, 0.2
        end

        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", barX, barY, barW * hpPercent, barH)

        -- Borde
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", barX-1, barY-1, barW+2, barH+2)

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

    -- Stats K/D
    love.graphics.print(string.format(Settings.idioma == "EN" and "Kills: %d | Deaths: %d" or "Kills: %d | Muertes: %d", stats.kills, stats.muertes), 10, 10)

    -- Notificación de powerup (centrada arriba)
    if powerupNotification.active then
        local W = GAME_W
        local font = UI.font("button") or love.graphics.getFont()
        love.graphics.setFont(font)

        local text = powerupNotification.text
        if powerupNotification.powerupDuration > 0 then
            text = text .. string.format(" (%.1fs)", powerupNotification.powerupTimer)
        end

        local tw = font:getWidth(text)
        local th = font:getHeight()
        local nx = W/2 - tw/2
        local ny = 100

        -- Fondo semi-transparente
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", nx - 20, ny - 10, tw + 40, th + 20, 8)

        -- Borde dorado
        love.graphics.setColor(0.85, 0.68, 0.18, 1)
        love.graphics.rectangle("line", nx - 20, ny - 10, tw + 40, th + 20, 8)

        -- Texto
        love.graphics.setColor(0.2, 1.0, 0.2)
        love.graphics.print(text, nx, ny)
    end

    -- Ammo HUD (bottom-center)
    local font = UI.font("button") or love.graphics.getFont()
    love.graphics.setFont(font)

    local ammo, maxAmmo, reloading, reloadTimer, reloadDuration = Tank.getAmmo()
    local W = GAME_W
    local H = GAME_H
    local boxW, boxH, gap = 24, 28, 6
    local totalW = maxAmmo * boxW + (maxAmmo - 1) * gap
    local startX = W/2 - totalW/2
    local boxY = H - 70

    if reloading then
        local progress = 1 - (reloadTimer / reloadDuration)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", startX - 6, boxY - 6, totalW + 12, boxH + 12, 6)
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", startX, boxY, totalW * progress, boxH, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", startX, boxY, totalW, boxH, 4)
        local txt = "RELOADING..."
        local tw = font:getWidth(txt)
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.print(txt, W/2 - tw/2, boxY - 30)
    else
        for i = 1, maxAmmo do
            local x = startX + (i - 1) * (boxW + gap)
            if i <= ammo then
                love.graphics.setColor(1.0, 0.85, 0.2, 1)
                love.graphics.rectangle("fill", x, boxY, boxW, boxH, 3)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.rectangle("line", x, boxY, boxW, boxH, 3)
            else
                love.graphics.setColor(0.2, 0.2, 0.2, 0.7)
                love.graphics.rectangle("fill", x, boxY, boxW, boxH, 3)
                love.graphics.setColor(0.6, 0.6, 0.6, 1)
                love.graphics.rectangle("line", x, boxY, boxW, boxH, 3)
            end
        end
        local txt = string.format(Settings.idioma == "EN" and "AMMO  %d / %d" or "MUNICIÓN  %d / %d", ammo, maxAmmo)
        local tw = font:getWidth(txt)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(txt, W/2 - tw/2, boxY - 30)
    end

    love.graphics.setColor(1, 1, 1)
end

local function goMenuEliminado()
    if Perfil.activo then
        leaderboard.enviarPartida(
            Perfil.activo.gamertag,
            stats.kills,
            stats.muertes,
            false,
            "multi"
        )
    end
    Red.desconectar()
    eliminado = false
    if elimGoMenu then elimGoMenu() end
end

function GameMultiplayer.keypressed(key, goMenu)
    elimGoMenu = goMenu or elimGoMenu
    if eliminado then
        if key == "escape" or key == "return" or key == "space" then
            goMenuEliminado()
        end
        return
    end
    if pausado then
        Pausa.keypressed(key)
        local accion = Pausa.getAccion()

        if accion == "reanudar" then
            pausado = false
        elseif accion == "reiniciar" then
            -- No permitir reinicio en multijugador, solo reanudar
            pausado = false
        elseif accion == "menu" then
            if Perfil.activo then
                leaderboard.enviarPartida(
                    Perfil.activo.gamertag,
                    stats.kills,
                    stats.muertes,
                    stats.victoria,
                    "multi"
                )
            end
            Red.desconectar()
            pausado = false
            goMenu()
        end
        return
    end

    if key == "r" then
        Tank.reload()
        return
    end

    if key == "escape" then
        pausado = true
        Pausa.open()
    end
end

function GameMultiplayer.mousepressed(x, y, button, goMenu)
    elimGoMenu = goMenu or elimGoMenu
    if eliminado then
        if button == 1 then
            local sw, sh = love.graphics.getDimensions()
            local pw, ph = 520, 320
            local px, py = sw/2 - pw/2, sh/2 - ph/2
            local bw, bh = 260, 50
            local bx, by = sw/2 - bw/2, py + 230
            if x >= bx and x <= bx+bw and y >= by and y <= by+bh then
                goMenuEliminado()
            end
        end
        return
    end
    if pausado then
        Pausa.mousepressed(x, y, button)
        local accion = Pausa.getAccion()

        if accion == "reanudar" then
            pausado = false
        elseif accion == "reiniciar" then
            -- No permitir reinicio en multijugador, solo reanudar
            pausado = false
        elseif accion == "menu" then
            if Perfil.activo then
                leaderboard.enviarPartida(
                    Perfil.activo.gamertag,
                    stats.kills,
                    stats.muertes,
                    stats.victoria,
                    "multi"
                )
            end
            Red.desconectar()
            pausado = false
            if goMenu then goMenu() end
        end
        return
    end

    if button == 1 and Tank.shoot() then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, "light", "local")
        Effects.spawnSmoke(bx, by, angle)
        Red.enviar_bala(bx, by, angle, "light")
    end
end

function GameMultiplayer.mousemoved(x, y)
    if pausado then
        Pausa.mousemoved(x, y)
    end
end

function GameMultiplayer.stopAudio()
    Audio.pararMusica()
end

return GameMultiplayer
