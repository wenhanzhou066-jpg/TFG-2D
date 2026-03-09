-- Primera vista del juego, menu principal


local Menu = require("systems.menu.init") 
local escena = "menu"

function love.load()

    -- Obtener la resolucion real del monitor
    local screenWidth, screenHeight = love.window.getDesktopDimensions()

    -- Forzar pantalla completa usando la resolucion del monitor
    love.window.setMode(screenWidth, screenHeight, {
        fullscreen     = true,     -- activar fullscreen
        fullscreentype = "desktop",-- usar modo escritorio el cual no cambia la resolucion real 
        resizable      = false,    -- impedir que la ventana cambie de tamaño
        vsync          = 1         -- sincronizar con los FPS del monitor
    })

    -- Cargar el menu principal
    Menu.load()
end


function love.update(dt)
    if escena == "menu" then
        Menu.update(dt)
    end
end


function love.draw()
    if escena == "menu" then
        Menu.draw()
    end
end


function love.keypressed(key)
    -- esc en el menu principal cerrara el juego
    if escena == "menu" then
        Menu.keypressed(key)
    end
end


function love.mousemoved(x, y)

    -- Detectar movimiento del raton en el menu
    if escena == "menu" then
        Menu.mousemoved(x, y)
    end
end


function love.mousepressed(x, y, button)

    -- Detectar clicks del raton en el menu
    if escena == "menu" then
        Menu.mousepressed(x, y, button)
    end
end


function love.resize(w, h)

    -- Reajustar elementos del menu si cambia la resolucion
    if escena == "menu" then
        Menu.resize(w, h)
    end
end