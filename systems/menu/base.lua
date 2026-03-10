
-- Base para los submenus

local Settings = require("systems.settings")
local UI       = require("systems.ui")

local T = {
    ES = {
        principal    = "MENU PRINCIPAL",
        jugar        = "JUGAR",
        mapas        = "SELECCIONAR MAPA",
        multijugador = "MULTIJUGADOR",
        dificultad   = "DIFICULTAD",
        personalizar = "PERSONALIZAR",
        ranking      = "RANKING",
        configuracion= "CONFIGURACION",
    },
    EN = {
        principal    = "MAIN MENU",
        jugar        = "PLAY",
        mapas        = "SELECT MAP",
        multijugador = "MULTIPLAYER",
        dificultad   = "DIFFICULTY",
        personalizar = "CUSTOMIZE",
        ranking      = "RANKING",
        configuracion= "SETTINGS",
    },
}

local Base = {}

-- Devuelve el titulo de una pantalla en el idioma activo.
function Base.tr(key)
    local t = T[Settings.idioma] or T.ES
    return t[key] or string.upper(key)
end

-- Devuelve el label del item en el idioma activo.
function Base.itemLabel(item)
    return Settings.idioma == "EN" and item[2] or item[1]
end

-- Ejuecuta la accion que tenga el item seleccionado
function Base.ejecutar(accion, escena)
    if not accion then return end

    if accion == "back" then
        escena.volver()
    elseif accion == "quit" then
        love.event.quit()
    elseif accion:sub(1, 1) == ">" then
        escena.navegarA(accion:sub(2))
    elseif accion == "fullscreen" then
        Settings.pantallaCompleta = not Settings.pantallaCompleta
        love.window.setFullscreen(Settings.pantallaCompleta)
        Settings.guardar()
    elseif accion == "lang" then
        Settings.idioma = Settings.idioma == "ES" and "EN" or "ES"
        Settings.guardar()
    else
        escena.setAction(accion)
    end
end

-- Dibuja una lista de botones por defecto 
function Base.draw(items, opcionSeleccionada, escena, nombre)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local separacion    = H * 0.10
    local mitad  = W / 2
    local bw, bh = W * 0.40, separacion * 0.72
    local tiempo = escena.getTiempo()
    local yT     = H * 0.04 + math.sin(tiempo * 2) * 4

    UI.drawParallax(escena.fondos(), tiempo)
    UI.titleBanner(escena.tituloImg(), Base.tr(nombre), yT, tiempo)

    for i, item in ipairs(items) do
        local y   = H * 0.28 + (i - 1) * separacion
        local sel = i == opcionSeleccionada
        UI.button(escena.botonImg(), mitad - bw/2, y, bw, bh, Base.itemLabel(item), sel, tiempo)
    end

    UI.vignette(0.45)
    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

-- Navegacion con teclado
function Base.keypressed(key, items, opcionSeleccionada, escena, accionExtra)
    if key == "up" then
        return (opcionSeleccionada - 2) % #items + 1
    elseif key == "down" then
        return opcionSeleccionada % #items + 1
    elseif key == "return" then
        Base.ejecutar(items[opcionSeleccionada][3], escena)
    elseif key == "escape" then
        escena.volver()
    end
    return opcionSeleccionada
end

-- Hover con raton 
function Base.mousemoved(my, items)
    local H   = love.graphics.getHeight()
    local separacion = H * 0.10
    for i = 1, #items do
        local y = H * 0.28 + (i - 1) * separacion
        if my > y and my < y + separacion then return i end
    end
    return nil
end

return Base