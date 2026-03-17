-- Base compartida para todos los submenus
-- Navegacion, traduccion, dibujo de botones y sonidos de interfaz

local Settings = require("systems.settings")
local UI = require("systems.ui")
local Audio = require("systems.audio")

-- Textos traducidos de cada pantalla
local T = {
    ES = {
        principal = "MENU PRINCIPAL",
        jugar = "JUGAR",
        mapas = "SELECCIONAR MAPA",
        multijugador = "MULTIJUGADOR",
        dificultad = "DIFICULTAD",
        personalizar = "PERSONALIZAR",
        ranking = "RANKING",
        configuracion= "CONFIGURACION",
        creditos = "CREDITOS",
    },
    EN = {
        principal = "MAIN MENU",
        jugar = "PLAY",
        mapas = "SELECT MAP",
        multijugador = "MULTIPLAYER",
        dificultad = "DIFFICULTY",
        personalizar = "CUSTOMIZE",
        ranking = "RANKING",
        configuracion= "SETTINGS",
        creditos = "CREDITS",
    },
}

local Base = {}

-- Ultimo boton sobre el que estuvo el raton (para no repetir hover)
local ultimoHover = nil

-- Devuelve el titulo de la pantalla en el idioma activo
function Base.tr(clave)
    local t = T[Settings.idioma] or T.ES
    return t[clave] or string.upper(clave)
end

-- Devuelve el texto del item segun el idioma
function Base.itemLabel(item)
    return Settings.idioma == "EN" and item[2] or item[1]
end

-- Ejecuta la accion del item seleccionado
function Base.ejecutar(accion, escena)
    if not accion then return end

    if accion == "back" then
        Audio.volverMenu()
        escena.volver()

    elseif accion == "quit" then
        Audio.confirmMenu()
        love.event.quit()

    elseif accion:sub(1, 1) == ">" then
        -- Navegar a otra pantalla del menu
        Audio.confirmMenu()
        escena.navegarA(accion:sub(2))

    elseif accion == "lang" then
        -- Cambiar idioma entre ES y EN
        Audio.clickMenu()
        Settings.idioma = Settings.idioma == "ES" and "EN" or "ES"
        Settings.guardar()

    else
        Audio.clickMenu()
        escena.setAction(accion)
    end
end

-- Dibuja la lista de botones estandar de cualquier submenu
function Base.draw(items, opcionSeleccionada, escena, nombre)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local sep = H * 0.10
    local mitad = W / 2
    local bw, bh = W * 0.40, sep * 0.72
    local tiempo = escena.getTiempo()
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4

    -- Fondo parallax y titulo
    UI.drawParallax(escena.fondos(), tiempo)
    UI.titleBanner(escena.tituloImg(), Base.tr(nombre), yT, tiempo)

    for i, item in ipairs(items) do
        local y = H * 0.28 + (i - 1) * sep
        local sel = i == opcionSeleccionada
        local esExit = item[3] == "quit" or item[3] == "back"

        UI.button(escena.botonImg(), mitad - bw/2, y, bw, bh,
                  Base.itemLabel(item), sel, tiempo, esExit, escena.botonExitImg())

        -- Indicador de seleccion a la izquierda del boton activo
        if sel then
            UI.drawSelector(mitad - bw/2, y, bh, tiempo)
        end
    end

    UI.vignette(0.45)
    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

-- Navegacion con teclado, devuelve la nueva opcion seleccionada
function Base.keypressed(key, items, opcionSeleccionada, escena)
    if key == "up" then
        local nueva = (opcionSeleccionada - 2) % #items + 1
        if nueva ~= opcionSeleccionada then Audio.hoverMenu() end
        return nueva

    elseif key == "down" then
        local nueva = opcionSeleccionada % #items + 1
        if nueva ~= opcionSeleccionada then Audio.hoverMenu() end
        return nueva

    elseif key == "return" or key == "kpenter" then
        Base.ejecutar(items[opcionSeleccionada][3], escena)

    elseif key == "escape" then
        Audio.volverMenu()
        escena.volver()
    end

    return opcionSeleccionada
end

-- Detecta si el raton esta sobre un boton y dispara hover si cambia
function Base.mousemoved(my, items)
    local H = love.graphics.getHeight()
    local sep = H * 0.10
    for i = 1, #items do
        local y = H * 0.28 + (i - 1) * sep
        if my > y and my < y + sep then
            -- Solo suena si cambiamos de boton
            if ultimoHover ~= i then
                ultimoHover = i
                Audio.hoverMenu()
            end
            return i
        end
    end
    return nil
end

-- Resetea el hover al entrar a un menu (evita sonido falso)
function Base.resetHover()
    ultimoHover = nil
end

return Base