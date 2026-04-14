-- Menu de pausa

local Settings = require("systems.settings")
local UI = require("systems.ui")

local Pause = {}

local opcion = 1
local accion = nil
local subEstado = "opciones"
local tiempo = 0
local botonImg

local opcionesPausa_ES = { "Reanudar", "Reiniciar", "Configuración", "Volver al menú" }
local opcionesPausa_EN = { "Resume", "Restart", "Settings", "Back to menu" }
local opcionesConfig_ES = { "Volumen música", "Volumen efectos", "Idioma", "Volver" }
local opcionesConfig_EN = { "Music volume", "SFX volume", "Language", "Back" }

function Pause.load()
    accion = nil
    opcion = 1
    subEstado = "opciones"
    tiempo = 0
    UI.loadFonts()
    botonImg = love.graphics.newImage("assets/menu/boton_normal.png")
end

function Pause.open()
    accion = nil
    opcion = 1
    subEstado = "opciones"
    tiempo = 0
end

function Pause.update(dt)
    tiempo = (tiempo or 0) + (dt or 0)
end

function Pause.draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- overlay oscuro
    love.graphics.setColor(0, 0, 0, 0.72)
    love.graphics.rectangle("fill", 0, 0, W, H)
    UI.vignette(0.6)

    local panelW = W * 0.38
    local panelH = H * 0.72
    local panelX = W/2 - panelW/2
    local panelY = H * 0.12
    local separacion = H * 0.095
    local anchoBoton = panelW * 0.85
    local altoBoton = separacion * 0.72
    local mitad = W / 2

    if subEstado == "opciones" then
        local opciones = Settings.idioma == "EN" and opcionesPausa_EN or opcionesPausa_ES
        for i, texto in ipairs(opciones) do
            local y = panelY + panelH * 0.18 + (i-1) * separacion
            local sel = i == opcion
            local esExit = i == #opciones
            UI.button(botonImg, mitad - anchoBoton/2, y, anchoBoton, altoBoton, texto, sel, tiempo, esExit, botonImg)
            if sel then UI.drawSelector(mitad - anchoBoton/2, y, altoBoton, tiempo) end
        end

    elseif subEstado == "configuracion" then
        local opciones = Settings.idioma == "EN" and opcionesConfig_EN or opcionesConfig_ES
        for i, texto in ipairs(opciones) do
            local y = panelY + panelH * 0.18 + (i-1) * separacion
            local sel = i == opcion
            local valor = ""
            if i == 1 then
                valor = math.floor((Settings.volumen or 1) * 100) .. "%"
            elseif i == 2 then
                valor = math.floor((Settings.volumenSfx or 0.7) * 100) .. "%"
            elseif i == 3 then
                valor = Settings.idioma
            end
            local etiqueta = texto .. (valor ~= "" and "   " .. valor or "")
            UI.button(botonImg, mitad - anchoBoton/2, y, anchoBoton, altoBoton, etiqueta, sel, tiempo, false, botonImg)
            if sel then UI.drawSelector(mitad - anchoBoton/2, y, altoBoton, tiempo) end
        end
    end

    love.graphics.setColor(1, 1, 1)
end

local function ejecutarOpcionPausa()
    if opcion == 1 then
        accion = "reanudar"
    elseif opcion == 2 then
        accion = "reiniciar"
    elseif opcion == 3 then
        subEstado = "configuracion"
        opcion = 1
    elseif opcion == 4 then
        accion = "menu"
    end
end

local function ejecutarOpcionConfig(key)
    if key == "return" then
        if opcion == 3 then
            Settings.idioma = Settings.idioma == "ES" and "EN" or "ES"
            Settings.guardar()
        elseif opcion == 4 then
            subEstado = "opciones"
            opcion = 1
        end
    elseif key == "right" then
        if opcion == 1 then
            Settings.volumen = math.min(1, (Settings.volumen or 1) + 0.05)
            Settings.guardar()
        elseif opcion == 2 then
            Settings.volumenSfx = math.min(1, (Settings.volumenSfx or 0.7) + 0.05)
            Settings.guardar()
        end
    elseif key == "left" then
        if opcion == 1 then
            Settings.volumen = math.max(0, (Settings.volumen or 1) - 0.05)
            Settings.guardar()
        elseif opcion == 2 then
            Settings.volumenSfx = math.max(0, (Settings.volumenSfx or 0.7) - 0.05)
            Settings.guardar()
        end
    end
end

function Pause.keypressed(key)
    if subEstado == "opciones" then
        local n = #opcionesPausa_ES
        if key == "up" then
            opcion = opcion - 1; if opcion < 1 then opcion = n end
        elseif key == "down" then
            opcion = opcion + 1; if opcion > n then opcion = 1 end
        elseif key == "return" then
            ejecutarOpcionPausa()
        elseif key == "escape" then
            accion = "reanudar"
        end

    elseif subEstado == "configuracion" then
        local n = #opcionesConfig_ES
        if key == "up" then
            opcion = opcion - 1; if opcion < 1 then opcion = n end
        elseif key == "down" then
            opcion = opcion + 1; if opcion > n then opcion = 1 end
        elseif key == "escape" then
            subEstado = "opciones"; opcion = 1
        else
            ejecutarOpcionConfig(key)
        end
    end
end

function Pause.mousemoved(mx, my)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local panelH = H * 0.72
    local panelY = H * 0.12
    local separacion = H * 0.095
    local altoBoton = separacion * 0.72
    local anchoBoton = W * 0.38 * 0.85
    local mitad = W / 2
    local n = subEstado == "opciones" and #opcionesPausa_ES or #opcionesConfig_ES
    for i = 1, n do
        local y = panelY + panelH * 0.18 + (i-1) * separacion
        if mx >= mitad - anchoBoton/2 and mx <= mitad + anchoBoton/2 and
           my >= y and my <= y + altoBoton then
            opcion = i
        end
    end
end

function Pause.mousepressed(_, _, btn)
    if btn ~= 1 then return end
    if subEstado == "opciones" then
        ejecutarOpcionPausa()
    elseif subEstado == "configuracion" then
        ejecutarOpcionConfig("return")
    end
end

function Pause.getAccion()
    return accion
end

return Pause