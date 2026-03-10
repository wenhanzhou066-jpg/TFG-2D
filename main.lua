-- main.lua
-- Punto de entrada del juego.
-- Gestiona dos escenas: "menu" y "juego".
-- La seleccion de mapa ocurre dentro del menu (systems/menu/mapas.lua).

local Menu = require("systems.menu.init")
local Game = require("game")

local escena = "menu"   -- "menu" | "juego"

-- Arranca la partida con el mapa elegido y para la musica del menu
local function startGame(mapIdx)
    Menu.stopMusic()
    Game.load(mapIdx)
    escena = "juego"
end

-- Vuelve al menu principal y reinicia musica
local function goMenu()
    if Audio then Audio.stopMusic() end
    escena = "menu"
    Menu.load()
end

-- ── Ciclo principal ────────────────────────────────────────────

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
            if     action == "play_map_1" then startGame(1)
            elseif action == "play_map_2" then startGame(2)
            elseif action == "play_map_3" then startGame(3)
            end
        end

    elseif escena == "juego" then
        Game.update(dt)
    end
end

function love.draw()
    if escena == "menu" then
        Menu.draw()
    elseif escena == "juego" then
        Game.draw()
    end
end

function love.keypressed(key)
    if escena == "menu" then
        Menu.keypressed(key)
    elseif escena == "juego" then
        Game.keypressed(key, goMenu)
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
    end
end

function love.resize(w, h)
    if escena == "menu" then
        Menu.resize(w, h)
    end
end
