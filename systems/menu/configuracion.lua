-- Submenu de configuracion

local Settings = require("systems.settings")
local UI = require("systems.ui")
local Base = require("systems.menu.base")
local Audio = require("systems.audio")

local Configuracion = {}
local opcion = 1
local arrastrando = false  -- si el raton esta arrastrando el slider

local items = {
    { "Volumen musica", "Music volume", "vol_musica" },
    { "Volumen efectos", "SFX volume", "vol_sfx" },
    { "Idioma", "Language", "lang" },
    { "Volver", "Back", "back" },
}

-- Calcula geometria del slider del item indicado
-- Devuelve bx, sy, bw2, sliderH  (o nil si el item no tiene slider)
local function geometriaSlider(idx)
    local ac = items[idx][3]
    if ac ~= "vol_musica" and ac ~= "vol_sfx" then return nil end

    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local sep = H * 0.10
    local mitad = W / 2
    local bw = W * 0.40
    local y = H * 0.28 + (idx - 1) * sep
    local label = Base.itemLabel(items[idx])
    local valor = ac == "vol_musica"
        and (math.floor(Settings.volumen * 100) .. "%")
        or  (math.floor(Settings.volumenSfx * 100) .. "%")
    local f = UI.font("button")
    local padX = math.floor(f:getHeight() * 1.2)
    local padY = math.floor(f:getHeight() * 0.55)
    local contenido = label .. "    " .. valor
    local bw2 = math.min(f:getWidth(contenido) + padX * 2, bw)
    local bx = mitad - bw/2 + (bw - bw2) / 2
    local bhReal = f:getHeight() + padY * 2
    local sy = y + bhReal + 4
    return bx, sy, bw2, 8
end

-- Aplica un valor de slider (0-1) al setting correspondiente
local function aplicarSlider(mx, escena)
    local ac = items[opcion][3]
    local bx, sy, bw2 = geometriaSlider(opcion)
    if not bx then return end
    local vol = math.max(0, math.min(1, (mx - bx) / bw2))
    if ac == "vol_musica" then
        Settings.volumen = vol
        local musica = escena.getMusica()
        if musica then musica:setVolume(vol) end
    elseif ac == "vol_sfx" then
        Settings.volumenSfx = vol
    end
    Settings.guardar()
end

function Configuracion.load(escena)
    opcion = 1
    Base.resetHover()
end

function Configuracion.draw(escena)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local sep = H * 0.10
    local mitad = W / 2
    local bw = W * 0.40
    local tiempo = escena.getTiempo()
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4

    UI.drawParallax(escena.fondos(), tiempo)
    UI.titleBanner(escena.tituloImg(), Base.tr("configuracion"), yT, tiempo)

    for i, item in ipairs(items) do
        local y = H * 0.28 + (i - 1) * sep
        local sel = i == opcion
        local esExit = item[3] == "back"
        local ac = item[3]
        local label = Base.itemLabel(item)

        -- Valor actual de cada opcion
        local valor = ""
        if ac == "vol_musica" then
            valor = math.floor(Settings.volumen * 100) .. "%"
        elseif ac == "vol_sfx" then
            valor = math.floor(Settings.volumenSfx * 100) .. "%"
        elseif ac == "lang" then
            valor = Settings.idioma
        end

        -- Usamos buttonConfig para que el sprite se ajuste a label + valor
        -- bx y bhReal son el x y alto reales del boton dibujado
        local bx, bhReal = UI.buttonConfig(
            escena.botonImg(), escena.botonExitImg(),
            mitad - bw/2, y, bw, sep * 0.72,
            label, valor, sel, tiempo, esExit
        )

        -- Indicador de seleccion
        if sel then UI.drawSelector(bx, y, bhReal, tiempo) end

        -- Slider del mismo ancho que el boton, justo debajo
        if sel and (ac == "vol_musica" or ac == "vol_sfx") then
            local vol = ac == "vol_musica" and Settings.volumen or Settings.volumenSfx
            -- bw2: ancho real del boton (igual que buttonConfig)
            local f = UI.font("button")
            local padX = math.floor(f:getHeight() * 1.2)
            local contenido = label .. "    " .. valor
            local bw2 = math.min(f:getWidth(contenido) + padX * 2, bw)
            UI.drawSlider(bx, y + bhReal + 4, bw2, 8, vol)
        end
    end

    UI.vignette(0.45)
    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

function Configuracion.keypressed(key, escena)
    local musica = escena.getMusica()
    local ac = items[opcion][3]

    if key == "up" then
        local nueva = (opcion - 2) % #items + 1
        if nueva ~= opcion then Audio.hoverMenu() end
        opcion = nueva

    elseif key == "down" then
        local nueva = opcion % #items + 1
        if nueva ~= opcion then Audio.hoverMenu() end
        opcion = nueva

    elseif key == "return" or key == "kpenter" then
        Base.ejecutar(ac, escena)

    elseif key == "escape" then
        Audio.volverMenu()
        escena.volver()

    elseif key == "right" then
        if ac == "vol_musica" then
            Settings.volumen = math.min(1, Settings.volumen + 0.05)
            if musica then musica:setVolume(Settings.volumen) end
            Settings.guardar()
            Audio.clickMenu()
        elseif ac == "vol_sfx" then
            Settings.volumenSfx = math.min(1, (Settings.volumenSfx or 0.7) + 0.05)
            Settings.guardar()
            Audio.clickMenu()
        end

    elseif key == "left" then
        if ac == "vol_musica" then
            Settings.volumen = math.max(0, Settings.volumen - 0.05)
            if musica then musica:setVolume(Settings.volumen) end
            Settings.guardar()
            Audio.clickMenu()
        elseif ac == "vol_sfx" then
            Settings.volumenSfx = math.max(0, (Settings.volumenSfx or 0.7) - 0.05)
            Settings.guardar()
            Audio.clickMenu()
        end
    end
end

function Configuracion.mousemoved(mx, my, escena)
    -- Si estamos arrastrando, actualizamos el slider en tiempo real
    if arrastrando then
        aplicarSlider(mx, escena)
        return
    end
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Configuracion.mousepressed(mx, my, btn, escena)
    if btn ~= 1 then return end
    local ac = items[opcion][3]

    -- Comprobar si el click cayo dentro del slider
    local bx, sy, bw2, sliderH = geometriaSlider(opcion)
    if bx and mx >= bx and mx <= bx + bw2 and my >= sy and my <= sy + sliderH then
        arrastrando = true
        aplicarSlider(mx, escena)
        Audio.clickMenu()
        return
    end

    Base.ejecutar(ac, escena)
end

function Configuracion.mousereleased(_, _, btn)
    -- Soltamos el arrastre al soltar el boton del raton
    if btn == 1 then arrastrando = false end
end

return Configuracion