-- game_bots.lua
-- Modo practica: jugador contra bots con dificultad elegida.

local GameBots = {}

local Settings = require("systems.settings")
local leaderboard = require("systems.leaderboard")
local Minimap     = require("systems.minimap")
local Perfil      = require("systems.perfil")
local stats       = { kills = 0, muertes = 0 }

-- Mapa activo (STI). Los mapas procedurales están deshabilitados temporalmente.
local allMaps = {
    require("systems.maps.map"),
    require("systems.maps.map_volcan"),
    require("systems.maps.map_nieve"),
}

Map = nil
Tank = require("entities.tank")
Bullet = require("entities.bullet")
Powerup = require("entities.powerup")
Effects = require("systems.effects")
Tracks = require("systems.tracks")
Audio = require("systems.audio")
Camera = {x=0, y=0}

local Bot = require("entities.bot")
local Pausa = require("systems.pausa")
local Remap = require("systems.controls_remap")

local GAME_W, GAME_H = 1920, 1080
local gameCanvas = nil 
GameView = { scale=1, ox=0, oy=0 }

local pausado = false
local subsystemsLoaded = false
local nivelDif = 2

local function recalcView()
    local sw, sh = love.graphics.getDimensions()
    local s = math.min(sw/GAME_W, sh/GAME_H)
    GameView.scale = s
    GameView.ox = math.floor((sw - GAME_W*s) / 2)
    GameView.oy = math.floor((sh - GAME_H*s) / 2)
end

function GameBots.load(mapIdx, dificultad)
    recalcView()
    if not gameCanvas then
        gameCanvas = love.graphics.newCanvas(GAME_W, GAME_H)
    end

    nivelDif = dificultad or 2
    Map = allMaps[mapIdx or 1] or allMaps[1]
    Map.load()
    Camera = {x=0, y=0}

    local sp = Map.getSpawns()[1]
    if not subsystemsLoaded then
        Tank.load(sp.x, sp.y)
        Bullet.load()
        Effects.load()
        Tracks.load()
        subsystemsLoaded = true
    else
        Tank.load(sp.x, sp.y)
    end
    Bullet.setPlayerWeapon(Perfil.activo and Perfil.activo.weaponIdx or 1)

    local tanks = Tank.getTanks()
    if tanks[1] then tanks[1].maxAmmo = 6; tanks[1].ammo = 6; tanks[1].reloadDuration = 2.0 end

    if Tank.setWeaponIdx then
        Tank.setWeaponIdx((Perfil.activo and Perfil.activo.weaponIdx) or 1, 1)
    end

    Audio.load(mapIdx or 1)
    Minimap.load()
    Pausa.load()
    Bot.setDificultad(nivelDif)
    Bot.load()
    pausado = false

    stats = { kills = 0, muertes = 0 }
    Bot.onKillCallback = function() stats.kills   = stats.kills   + 1 end
    Tank.onDieCallback = function() stats.muertes = stats.muertes + 1 end
end

function GameBots.update(dt)
    Remap.update(dt)
    
    if pausado then
        Pausa.update(dt)
        local accion = Pausa.getAccion()
        if accion == "reanudar" then
            pausado = false
        elseif accion == "reiniciar" then
            GameBots.load(nil, nivelDif)
        elseif accion == "menu" then
            if Perfil.activo then
                local victoria = Bot.contarVivos() == 0
                leaderboard.enviarPartida(
                    Perfil.activo.gamertag,
                    stats.kills,
                    stats.muertes,
                    victoria,
                    "local"
                )
            end
            GameBots._onEscape()
        end
        return
    end

    Tank.update(dt)
    Bullet.update(dt)
    Effects.update(dt)
    Tracks.update(dt)
    Bot.update(dt)

    local mapSize = Map.getSize and Map.getSize() or {w=1920, h=1080}
    local tx, ty  = Tank.getPosition()
    Camera.x = math.max(0, math.min(tx - GAME_W/2, mapSize.w - GAME_W))
    Camera.y = math.max(0, math.min(ty - GAME_H/2, mapSize.h - GAME_H))
    Minimap.update(tx, ty)
end

function GameBots.draw()
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear(0.10, 0.10, 0.10)
    love.graphics.push()
    love.graphics.translate(-math.floor(Camera.x), -math.floor(Camera.y))

    Map.drawGround()
    Tracks.draw()
    Tank.draw()
    Bot.draw()
    Bullet.draw()
    Effects.draw()
    Map.drawAbove()

    love.graphics.pop()
    Minimap.drawFogToCurrentCanvas(Camera.x, Camera.y)
    GameBots.drawHUD()
    love.graphics.setCanvas()

    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, GameView.ox, GameView.oy, 0, GameView.scale, GameView.scale)
    Minimap.drawHUD(Camera.x, Camera.y, GameView)

    if pausado then 
        Pausa.draw() 
        if Remap.isVisible() then
            love.graphics.push()
            love.graphics.translate(GameView.ox, GameView.oy)
            love.graphics.scale(GameView.scale, GameView.scale)
            Remap.draw()
            love.graphics.pop()
        end
    end
end

function GameBots.drawHUD()
    local UI = require("systems.ui")
    local font = UI.font("small")
    love.graphics.setFont(font)

    local dificultades = Bot.getDificultades()
    local nombreDif = dificultades[nivelDif] or "Normal"

    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print((Settings.idioma == "EN" and "Difficulty: " or "Dificultad: ") .. nombreDif, 20, 20)
    love.graphics.print("Bots: " .. Bot.contarVivos(), 20, 52) -- y incrementado para mejor espaciado

    if Bot.contarVivos() == 0 then
        love.graphics.setFont(UI.font("button")) -- Usar una fuente más grande para la pantalla de victoria
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", GAME_W/2-260, GAME_H/2-40, 520, 80, 8, 8)
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.printf(Settings.idioma == "EN" and "All bots eliminated!" or "¡Todos los bots eliminados!", GAME_W/2-260, GAME_H/2-14, 520, "center")
    end

    -- Ammo HUD
    local ammo, maxAmmo, reloading, reloadTimer, reloadDuration = Tank.getAmmo()
    local fontA = UI.font("button") or love.graphics.getFont()
    love.graphics.setFont(fontA)
    local boxW, boxH, gap = 24, 28, 6
    local totalW = maxAmmo * boxW + (maxAmmo - 1) * gap
    local startX = GAME_W/2 - totalW/2
    local boxY = GAME_H - 70
    if reloading then
        local progress = 1 - (reloadTimer / reloadDuration)
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", startX - 6, boxY - 6, totalW + 12, boxH + 12, 6)
        love.graphics.setColor(0.9, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", startX, boxY, totalW * progress, boxH, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("line", startX, boxY, totalW, boxH, 4)
        local txt = "RELOADING..."
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.print(txt, GAME_W/2 - fontA:getWidth(txt)/2, boxY - 30)
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
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(txt, GAME_W/2 - fontA:getWidth(txt)/2, boxY - 30)
    end

    love.graphics.setColor(1, 1, 1)
end

function GameBots.keypressed(key, onEscape)
    GameBots._onEscape = onEscape
    if pausado then Pausa.keypressed(key); return end
    if key == "r" then Tank.reload(); return end
    if key == "escape" then Pausa.open(); pausado = true end
end

function GameBots.mousepressed(x, y, button)
    if pausado then Pausa.mousepressed(x, y, button); return end
    if button == 1 and Tank.shoot() then
        local bx, by, angle = Tank.getMuzzlePos()
        Bullet.spawn(bx, by, angle, nil, "player")
    end
end

function GameBots.mousemoved(x, y)
    if pausado then Pausa.mousemoved(x, y) end
end

function GameBots.stopAudio()
    Audio.pararMusica()
end

return GameBots