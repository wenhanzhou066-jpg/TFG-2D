-- Submenu de configuracion

local Settings = require("systems.settings")
local UI = require("systems.ui")
local Base = require("systems.menu.base")

local Configuracion = {}
local opcion = 1
local items = {
    { "Volumen", "Volume", "vol"},
    { "Pantalla completa","Full screen", "fullscreen" },
    { "Idioma", "Language", "lang"},
    { "Volver", "Back", "back"},
}

-- Cargar submenu de configuracion
function Configuracion.load(escena)
    -- Reiniciar seleccion al entrar al menu
    opcion = 1
end


function Configuracion.draw(escena)

    -- Obtener tamaño de pantalla actual
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    -- Separacion vertical entre botones
    local sep = H * 0.10

    -- Centro horizontal de pantalla
    local mitad = W / 2

    -- Tamaño de botones
    local bw, bh = W * 0.40, sep * 0.72

    -- Tiempo usado para animaciones
    local tiempo = escena.getTiempo()

    -- Pequeña animacion vertical del titulo
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4

    -- Dibujar fondo con efecto parallax
    UI.drawParallax(escena.fondos(), tiempo)

    -- Dibujar banner del titulo
    UI.titleBanner(escena.tituloImg(), Base.tr("configuracion"), yT, tiempo)

    -- Dibujar cada boton del menu
    for i, item in ipairs(items) do

        -- Posicion vertical del boton
        local y = H * 0.28 + (i - 1) * sep

        -- Detectar si esta seleccionado
        local sel = i == opcion

        -- Dibujar boton
        UI.button(escena.botonImg(), mitad - bw/2, y, bw, bh, "", sel, tiempo)

        -- Fuente usada en botones
        local f = UI.font("button")

        -- Posicion vertical del texto
        local textY = y + bh/2 - f:getHeight()/2

        -- Color dependiendo si esta seleccionado
        local col = sel and UI.colors.cream or UI.colors.creamDim

        love.graphics.setFont(f)

        -- Obtener texto traducido del item
        local label = Base.itemLabel(item)

        -- Dibujar nombre de la opcion en el lado izquierdo del boton
        UI.text(label, mitad - bw/2 + bw*0.25 - f:getWidth(label)/2, textY, col)

        -- Valor actual de la opcion en el cuarto derecho del boton
        local valor = ""
        local ac = item[3]

        -- Mostrar volumen actual
        if ac == "vol" then
            valor = math.floor(Settings.volumen * 100) .. "%"
        end

        -- Mostrar estado de pantalla completa
        if ac == "fullscreen" then
            valor = Settings.pantallaCompleta and "ON" or "OFF"
        end

        -- Mostrar idioma actual
        if ac == "lang" then
            valor = Settings.idioma
        end

        -- Dibujar valor si existe
        if valor ~= "" then
            UI.text(valor, mitad - bw/2 + bw*0.75 - f:getWidth(valor)/2, textY, col)
        end
    end

    -- Oscurecer bordes de pantalla
    UI.vignette(0.45)

    -- Dibujar footer del menu
    UI.footer()

    -- Restaurar color por defecto
    love.graphics.setColor(1, 1, 1)
end


function Configuracion.keypressed(key, escena)

    -- Obtener musica actual del menu
    local musica = escena.getMusica()

    -- Mover seleccion hacia arriba
    if key == "up" then
        opcion = (opcion - 2) % #items + 1

    -- Mover seleccion hacia abajo
    elseif key == "down" then
        opcion = opcion % #items + 1

    -- Ejecutar opcion seleccionada
    elseif key == "return" then
        Base.ejecutar(items[opcion][3], escena)

    -- Volver al menu anterior
    elseif key == "escape" then
        escena.volver()

    -- Aumentar volumen con flecha derecha
    elseif key == "right" and items[opcion][3] == "vol" then

        -- Subir volumen 10% (max 100%)
        Settings.volumen = math.min(1, Settings.volumen + 0.1)

        -- Aplicar volumen a la musica
        musica:setVolume(Settings.volumen)

        -- Guardar configuracion
        Settings.guardar()

    -- Bajar volumen con flecha izquierda
    elseif key == "left" and items[opcion][3] == "vol" then

        -- Bajar volumen 10% (min 0%)
        Settings.volumen = math.max(0, Settings.volumen - 0.1)

        -- Aplicar volumen a la musica
        musica:setVolume(Settings.volumen)

        -- Guardar configuracion
        Settings.guardar()
    end
end


function Configuracion.mousemoved(_, my, escena)

    -- Detectar si el raton esta sobre otro boton
    local nuevo = Base.mousemoved(my, items)

    -- Cambiar opcion seleccionada
    if nuevo then
        opcion = nuevo
    end
end


function Configuracion.mousepressed(_, _, btn, escena)

    -- Solo aceptar click izquierdo
    if btn ~= 1 then return end

    -- Ejecutar opcion seleccionada
    Base.ejecutar(items[opcion][3], escena)
end


return Configuracion