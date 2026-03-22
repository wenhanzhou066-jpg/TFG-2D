-- Punto de entrada del juego.
-- Gestiona tres escenas: "menu", "juego" y "multiplayer".

local Menu            = require("systems.menu.init")
local Game            = require("game")
local GameMultiplayer = require("game_multiplayer")

local escena = "menu"   -- "menu", "juego", o "multiplayer"

-- Arranca la partida con el mapa elegido y para la musica del menu
local function startGame(mapIdx)
    Menu.stopMusic()
    Game.load(mapIdx)
    escena = "juego"
end

-- Arranca partida multijugador
local function startMultiplayer(mapIdx)
    Menu.stopMusic()
    GameMultiplayer.load(mapIdx or 1)
    escena = "multiplayer"
end

-- Vuelve al menu principal y reinicia musica
local function goMenu()
    if escena == "juego" then
        Game.stopAudio()
    elseif escena == "multiplayer" then
        GameMultiplayer.stopAudio()
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

        -- Comprobar si el menu lanzo una accion de inicio de partida
        local action = Menu.getAction()
        if action then
            Menu.clearAction()
            if     action == "play_map_1"       then startGame(1)
            elseif action == "play_map_2"       then startGame(2)
            elseif action == "play_map_3"       then startGame(3)
            elseif action == "play_map_4"       then startGame(4)
            elseif action == "play_multiplayer" then startMultiplayer(1)
            end
        end

    elseif escena == "juego" then
        Game.update(dt)

    elseif escena == "multiplayer" then
        GameMultiplayer.update(dt)
    end
end

function love.draw()
    if escena == "menu" then
        Menu.draw()
    elseif escena == "juego" then
        Game.draw()
    elseif escena == "multiplayer" then
        GameMultiplayer.draw()
    end
end

function love.keypressed(key)
    if escena == "menu" then
        Menu.keypressed(key)
    elseif escena == "juego" then
        Game.keypressed(key, goMenu)
    elseif escena == "multiplayer" then
        GameMultiplayer.keypressed(key, goMenu)
    end
end

function love.mousemoved(x, y)
    if escena == "menu" then
        Menu.mousemoved(x, y)
    end
end

function love.mousepressed(x, y, button)
    if escena == "menu" then
        Menu.mousepressed(x, y, button)
    elseif escena == "juego" then
        Game.mousepressed(x, y, button)
    elseif escena == "multiplayer" then
        GameMultiplayer.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if escena == "menu" then
        Menu.mousereleased(x, y, button)
    end
end

function love.textinput(t)
    if escena == "menu" then
        Menu.textinput(t)
    end
end

function love.resize(w, h)
    if escena == "menu" then
        Menu.resize(w, h)
    end
end
