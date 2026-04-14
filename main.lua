-- Punto de entrada del juego.
-- Gestiona las escenas: menu, juego, multiplayer, oleadas, bots.

local Menu            = require("systems.menu.init")
local Game            = require("game")
local GameMultiplayer = require("game_multiplayer")
local GameOleadas     = require("game_oleadas")
local GameBots        = require("game_bots")

local escena = "menu"

local mapActual = 1
local modoOleadas = "solo"

local function startGame(mapIdx)
    Menu.stopMusic()
    Game.load(mapIdx)
    escena = "juego"
end

local function startMultiplayer(mapIdx)
    Menu.stopMusic()
    GameMultiplayer.load(mapIdx or 1)
    escena = "multiplayer"
end

local function startOleadas(modo, mapIdx)
    Menu.stopMusic()
    GameOleadas.load(mapIdx or mapActual, modo)
    escena = "oleadas"
end

local function startBots(dificultad, mapIdx)
    Menu.stopMusic()
    GameBots.load(mapIdx or mapActual, dificultad)
    escena = "bots"
end

local function goMenu()
    if     escena == "juego"       then Game.stopAudio()
    elseif escena == "multiplayer" then GameMultiplayer.stopAudio()
    elseif escena == "oleadas"     then GameOleadas.stopAudio()
    elseif escena == "bots"        then GameBots.stopAudio()
    end
    escena = "menu"
    Menu.load()
end

function love.load()
    local sw, sh = love.window.getDesktopDimensions()
    love.window.setMode(sw, sh, {
        fullscreen     = true,
        fullscreentype = "desktop",
        resizable      = false,
        vsync          = 1,
    })
    Menu.load()
end

function love.update(dt)
    if escena == "menu" then
        Menu.update(dt)
        local action = Menu.getAction()
        if action then
            Menu.clearAction()
            if     action == "play_map_1"        then startGame(1)
            elseif action == "play_map_2"        then startGame(2)
            elseif action == "play_map_3"        then startGame(3)
            elseif action == "play_map_4"        then startGame(4)
            elseif action == "play_multiplayer"  then startMultiplayer(1)
            elseif action == "oleadas_solo"      then startOleadas("solo", mapActual)
            elseif action == "oleadas_coop"      then startOleadas("coop", mapActual)
            elseif action == "bots_facil"        then startBots(1, mapActual)
            elseif action == "bots_normal"       then startBots(2, mapActual)
            elseif action == "bots_dificil"      then startBots(3, mapActual)
            end
        end

    elseif escena == "juego"       then Game.update(dt)
    elseif escena == "multiplayer" then GameMultiplayer.update(dt)
    elseif escena == "oleadas"     then GameOleadas.update(dt)
    elseif escena == "bots"        then GameBots.update(dt)
    end
end

function love.draw()
    if     escena == "menu"        then Menu.draw()
    elseif escena == "juego"       then Game.draw()
    elseif escena == "multiplayer" then GameMultiplayer.draw()
    elseif escena == "oleadas"     then GameOleadas.draw()
    elseif escena == "bots"        then GameBots.draw()
    end
end

function love.keypressed(key)
    if     escena == "menu"        then Menu.keypressed(key)
    elseif escena == "juego"       then Game.keypressed(key, goMenu)
    elseif escena == "multiplayer" then GameMultiplayer.keypressed(key, goMenu)
    elseif escena == "oleadas"     then GameOleadas.keypressed(key, goMenu)
    elseif escena == "bots"        then GameBots.keypressed(key, goMenu)
    end
end

function love.mousemoved(x, y)
    if     escena == "menu"    then Menu.mousemoved(x, y)
    elseif escena == "oleadas" then GameOleadas.mousemoved(x, y)
    elseif escena == "bots"    then GameBots.mousemoved(x, y)
    end
end

function love.mousepressed(x, y, button)
    if     escena == "menu"        then Menu.mousepressed(x, y, button)
    elseif escena == "juego"       then Game.mousepressed(x, y, button)
    elseif escena == "multiplayer" then GameMultiplayer.mousepressed(x, y, button)
    elseif escena == "oleadas"     then GameOleadas.mousepressed(x, y, button)
    elseif escena == "bots"        then GameBots.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if escena == "menu" then Menu.mousereleased(x, y, button) end
end

function love.textinput(t)
    if escena == "menu" then Menu.textinput(t) end
end

function love.resize(w, h)
    if escena == "menu" then Menu.resize(w, h) end
end