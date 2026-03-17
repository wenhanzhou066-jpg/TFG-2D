-- Pantalla del menu principal

local Settings = require("systems.settings")
local UI       = require("systems.ui")
local Base     = require("systems.menu.base")

local Principal = {}
local opcion = 1
local items = {
    { "Jugar", "Play", ">jugar" },
    { "Personalizar", "Customize", ">personalizar"},
    { "Ranking", "Ranking", ">ranking"},
    { "Configuracion", "Settings", ">configuracion"},
    { "Salir", "Quit", "quit"},
}

function Principal.load(escena)
    opcion = 1
    Base.resetHover()
end

function Principal.draw(escena)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local sep = H * 0.10
    local mitad = W / 2
    local bw, bh = W * 0.40, sep * 0.72
    local tiempo = escena.getTiempo()
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4

    -- Fondo parallax
    UI.drawParallax(escena.fondos(), tiempo)

    -- Titulo del juego con efecto CRT, cadenas y estrellas (sin banner)
    UI.drawGameTitle(yT, tiempo)

    -- Botones
    for i, item in ipairs(items) do
        local y = H * 0.28 + (i - 1) * sep
        local sel = i == opcion
        local esExit = item[3] == "quit"
        UI.button(escena.botonImg(), mitad - bw/2, y, bw, bh,
            Base.itemLabel(item), sel, tiempo, esExit, escena.botonExitImg())
        if sel then UI.drawSelector(mitad - bw/2, y, bh, tiempo) end
    end

    UI.vignette(0.45)
    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

function Principal.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Principal.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Principal.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Principal