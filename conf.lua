-- conf.lua
-- LÖVE lo ejecuta automáticamente antes que main.lua.
-- Configura la ventana y los módulos activos.

function love.conf(t)
    t.title          = "Tank Game"
    t.version        = "11.4"

    t.window.width   = 1920
    t.window.height  = 1080
    t.window.vsync   = 1
    t.window.resizable = false
end