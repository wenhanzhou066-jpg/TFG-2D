-- Modulo de interfaz: colores, fuentes, botones, titulo, parallax y utilidades

local UI = {}

UI.GAME_TITLE = "OPERATION: BLACK STEEL"

UI.colors = {
    cream = {0.95, 0.90, 0.75, 1.0},
    creamDim = {0.65, 0.60, 0.50, 1.0},
    goldDark = {0.80, 0.65, 0.20, 1.0},
    khaki = {0.70, 0.65, 0.45, 1.0},
    black = {0.00, 0.00, 0.00, 1.0},
    white = {1.00, 1.00, 1.00, 1.0},
    sliderBg = {0.20, 0.18, 0.12, 0.85},
    sliderFg = {0.75, 0.60, 0.20, 1.00},
}

local fuentes = {}
local fontPath = "assets/menu/Military Poster.ttf"

-- Dibuja una estrella militar
local function dibujarEstrella(cx, cy, r, color)
    love.graphics.setColor(color)
    local puntos = {}
    for i = 0, 4 do
        local a_ext = math.rad(-90 + i * 72)
        local a_int = math.rad(-90 + i * 72 + 36)
        table.insert(puntos, cx + r * math.cos(a_ext))
        table.insert(puntos, cy + r * math.sin(a_ext))
        table.insert(puntos, cx + r * 0.4 * math.cos(a_int))
        table.insert(puntos, cy + r * 0.4 * math.sin(a_int))
    end
    love.graphics.polygon("fill", puntos)
end

-- Dibuja una cadena de tanque horizontal
local function dibujarCadena(x1, x2, y, alpha)
    local paso = 10
    for x = x1, x2 - paso, paso do
        love.graphics.setColor(0.30, 0.26, 0.16, alpha)
        love.graphics.rectangle("fill", x, y, paso - 1, 4)
        love.graphics.setColor(0.50, 0.44, 0.28, alpha)
        love.graphics.rectangle("fill", x, y, paso - 1, 2)
        love.graphics.setColor(0.20, 0.18, 0.10, alpha)
        love.graphics.rectangle("fill", x + paso/2 - 1, y - 1, 2, 6)
    end
end

-- Titulo
function UI.drawGameTitle(y, tiempo)
    local W = love.graphics.getWidth()
    local f = UI.font("title")
    local texto = UI.GAME_TITLE
    local tw = f:getWidth(texto)
    local th = f:getHeight()
    local tx = W/2 - tw/2
    local margenCadena = 14

    -- Parpadeo
    local flicker = 1.0 - math.abs(math.sin(tiempo * 47)) * 0.04

    -- Sombra larga desplazada (efecto profundidad)
    love.graphics.setFont(f)
    for i = 4, 1, -1 do
        local alpha = (5 - i) * 0.04 * flicker
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.print(texto, tx + i, y + i)
    end

    -- Capa de color base (verde militar oscuro)
    love.graphics.setColor(0.15, 0.25, 0.10, 0.6 * flicker)
    love.graphics.print(texto, tx + 1, y + 1)

    -- Texto principal dorado
    love.graphics.setColor(0.85, 0.68, 0.18, flicker)
    love.graphics.print(texto, tx, y)

    --lineas horizontales semitransparentes
    local scanAlpha = 0.18 * flicker
    for ly = y, y + th, 3 do
        love.graphics.setColor(0, 0, 0, scanAlpha)
        love.graphics.rectangle("fill", tx - 4, ly, tw + 8, 1)
    end

    -- Destello horizontal que recorre el texto de izquierda a derecha
    local barrida = (tiempo * 0.6) % 1.0
    local bx = tx + barrida * (tw + 60) - 30
    local canvas_w = 60
    for dx = 0, canvas_w do
        local t = dx / canvas_w
        local a = math.exp(-((t - 0.5)^2) / 0.05) * 0.35 * flicker
        love.graphics.setColor(1, 0.95, 0.7, a)
        love.graphics.rectangle("fill", bx + dx, y, 1, th)
    end

    -- Cadenas de tanque arriba y abajo del titulo
    local cadenaY_arriba = y - margenCadena
    local cadenaY_abajo  = y + th + margenCadena - 4
    local cadenaAlpha = 0.75 + math.sin(tiempo * 1.5) * 0.15
    dibujarCadena(tx - 10, tx + tw + 10, cadenaY_arriba, cadenaAlpha)
    dibujarCadena(tx - 10, tx + tw + 10, cadenaY_abajo,  cadenaAlpha)

    -- Estrellas militares a los lados (parpadeo lento independiente)
    local starAlpha = 0.7 + math.sin(tiempo * 2.3) * 0.3
    local starR = th * 0.28
    local margenStar = starR * 2.2
    dibujarEstrella(tx - margenStar,      y + th/2, starR, {0.85, 0.68, 0.18, starAlpha})
    dibujarEstrella(tx + tw + margenStar, y + th/2, starR, {0.85, 0.68, 0.18, starAlpha})

    love.graphics.setColor(1, 1, 1)
end

function UI.loadFonts()
    local H = love.graphics.getHeight()
    fuentes.title  = love.graphics.newFont(fontPath, math.floor(H * 0.085))
    fuentes.button = love.graphics.newFont(fontPath, math.floor(H * 0.038))
    fuentes.small  = love.graphics.newFont(fontPath, math.floor(H * 0.022))
end

function UI.font(nombre)
    return fuentes[nombre] or fuentes.button
end

-- Dibuja las capas del fondo con efecto parallax
function UI.drawParallax(fondos, tiempo)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    for i, fondo in ipairs(fondos) do
        local velocidad = i * 15
        local fw = fondo:getWidth()
        local escala = W / fw
        local anchoReal = fw * escala
        local offset = (tiempo * velocidad) % anchoReal
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(fondo, -offset, 0, 0, escala, H / fondo:getHeight())
        love.graphics.draw(fondo, anchoReal - offset, 0, 0, escala, H / fondo:getHeight())
    end
end

-- Dibuja el banner del titulo ajustado al texto
function UI.titleBanner(img, texto, y, tiempo)
    if not texto then return end
    local W = love.graphics.getWidth()
    local f = UI.font("title")
    local padX = math.floor(f:getHeight() * 1.2)
    local padY = math.floor(f:getHeight() * 0.5)
    local tw = f:getWidth(texto)
    local th = f:getHeight()
    local bw = tw + padX * 2
    local bh = th + padY * 2
    local bx = W/2 - bw/2

    love.graphics.setColor(1, 1, 1, 0.95)
    if img then
        love.graphics.draw(img, bx, y, 0,
            bw / img:getWidth(),
            bh / img:getHeight())
    else
        love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
        love.graphics.rectangle("fill", bx, y, bw, bh)
    end

    local tx = W/2 - tw/2
    local ty = y + bh/2 - th/2

    love.graphics.setFont(f)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(texto, tx + 2, ty + 2)
    love.graphics.setColor(UI.colors.cream)
    love.graphics.print(texto, tx, ty)
    love.graphics.setColor(1, 1, 1)
end

-- Dibuja un boton cuyo sprite se ajusta al texto
function UI.button(img, x, y, w, h, texto, sel, tiempo, esExit, imgExit)
    local escalaAnim = sel and (1 + math.sin(tiempo * 4) * 0.01) or 1
    local spriteUsar = (esExit and imgExit) and imgExit or img

    local bw, bh
    if texto and texto ~= "" then
        local f = UI.font("button")
        local padX = math.floor(f:getHeight() * 2.5)
        local padY = math.floor(f:getHeight() * 0.55)
        bw = math.min(f:getWidth(texto) + padX * 2, w)
        bh = f:getHeight() + padY * 2
    else
        bw, bh = w, h
    end

    local bx = x + (w - bw) / 2
    local ox = bw * (1 - escalaAnim) / 2

    if esExit then
        love.graphics.setColor(sel and {0.55, 0.65, 0.40, 1} or {0.38, 0.45, 0.28, 0.85})
    elseif sel then
        love.graphics.setColor(1.0, 0.95, 0.7, 1.0)
    else
        love.graphics.setColor(0.7, 0.65, 0.55, 0.85)
    end

    if spriteUsar then
        love.graphics.draw(spriteUsar, bx + ox, y, 0,
            (bw * escalaAnim) / spriteUsar:getWidth(),
            bh / spriteUsar:getHeight())
    else
        love.graphics.rectangle("fill", bx + ox, y, bw * escalaAnim, bh)
    end

    if texto and texto ~= "" then
        local f = UI.font("button")
        local col = sel and UI.colors.cream or UI.colors.creamDim
        love.graphics.setFont(f)
        love.graphics.setColor(col)
        love.graphics.print(texto,
            bx + bw/2 - f:getWidth(texto)/2,
            y + bh/2 - f:getHeight()/2)
    end

    love.graphics.setColor(1, 1, 1)
end

-- Boton especial para configuracion: label a la izquierda, valor a la derecha
-- Devuelve bx y bh para que configuracion.lua pueda posicionar el slider
function UI.buttonConfig(img, imgExit, x, y, w, h, label, valor, sel, tiempo, esExit)
    local escalaAnim = sel and (1 + math.sin(tiempo * 4) * 0.01) or 1
    local spriteUsar = (esExit and imgExit) and imgExit or img
    local f = UI.font("button")
    local padX = math.floor(f:getHeight() * 1.2)
    local padY = math.floor(f:getHeight() * 0.55)

    -- Ancho basado en label + separacion + valorr
    local contenido = valor ~= "" and (label .. "    " .. valor) or label
    local bw = math.min(f:getWidth(contenido) + padX * 2, w)
    local bh = f:getHeight() + padY * 2
    local bx = x + (w - bw) / 2
    local ox = bw * (1 - escalaAnim) / 2
    local ty = y + bh/2 - f:getHeight()/2

    if esExit then
        love.graphics.setColor(sel and {0.55, 0.65, 0.40, 1} or {0.38, 0.45, 0.28, 0.85})
    elseif sel then
        love.graphics.setColor(1.0, 0.95, 0.7, 1.0)
    else
        love.graphics.setColor(0.7, 0.65, 0.55, 0.85)
    end

    if spriteUsar then
        love.graphics.draw(spriteUsar, bx + ox, y, 0,
            (bw * escalaAnim) / spriteUsar:getWidth(),
            bh / spriteUsar:getHeight())
    else
        love.graphics.rectangle("fill", bx + ox, y, bw * escalaAnim, bh)
    end

    local col = sel and UI.colors.cream or UI.colors.creamDim
    love.graphics.setFont(f)
    love.graphics.setColor(col)

    if valor ~= "" then
        -- Label izquierda, valor derecha
        love.graphics.print(label, bx + bw*0.25 - f:getWidth(label)/2, ty)
        love.graphics.print(valor, bx + bw*0.75 - f:getWidth(valor)/2, ty)
    else
        love.graphics.print(label, bx + bw/2 - f:getWidth(label)/2, ty)
    end

    love.graphics.setColor(1, 1, 1)
    return bx, bh
end

-- Dibuja el indicador de seleccion a la izquierda del boton activo
function UI.drawSelector(bx, by, bh, tiempo)
    local f = UI.font("button")
    local texto = ">"
    local tw = f:getWidth(texto)
    local th = f:getHeight()
    local bounce = math.sin(tiempo * 6) * 4
    local x = bx - tw - 10 + bounce
    local y = by + bh/2 - th/2

    love.graphics.setFont(f)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(texto, x + 1, y + 1)
    love.graphics.setColor(UI.colors.goldDark)
    love.graphics.print(texto, x, y)
    love.graphics.setColor(1, 1, 1)
end

-- Dibuja una barra de slider para el volumen
function UI.drawSlider(x, y, w, h, val)
    love.graphics.setColor(UI.colors.sliderBg)
    love.graphics.rectangle("fill", x, y, w, h, 3)
    love.graphics.setColor(UI.colors.sliderFg)
    love.graphics.rectangle("fill", x, y, w * val, h, 3)
    love.graphics.setColor(0.5, 0.4, 0.15, 0.8)
    love.graphics.rectangle("line", x, y, w, h, 3)
    love.graphics.setColor(1, 1, 1)
end

-- Detecta click en la barra del slider activo
function UI.sliderClick(mx, my, opcion, items, escena)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local sep = H * 0.10
    local mitad = W / 2
    local bw, bh = W * 0.40, sep * 0.72
    local y = H * 0.28 + (opcion - 1) * sep
    local sy = y + bh + 4
    local sx = mitad - bw/2
    if mx >= sx and mx <= sx + bw and my >= sy and my <= sy + 10 then
        return math.max(0, math.min(1, (mx - sx) / bw))
    end
    return nil
end

function UI.text(texto, x, y, color)
    love.graphics.setColor(color or UI.colors.cream)
    love.graphics.print(texto, x, y)
    love.graphics.setColor(1, 1, 1)
end

function UI.textCentered(texto, y, color)
    local W = love.graphics.getWidth()
    local f = love.graphics.getFont()
    local tw = f:getWidth(texto)
    UI.text(texto, W/2 - tw/2, y, color)
end

function UI.vignette(intensidad)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, intensidad * 0.5)
    love.graphics.rectangle("fill", 0, H * 0.85, W, H * 0.15)
    love.graphics.setColor(1, 1, 1)
end

function UI.footer()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local f = UI.font("small")
    local texto = "MENU V.1.0"
    love.graphics.setFont(f)
    love.graphics.setColor(0.5, 0.5, 0.4, 0.6)
    love.graphics.print(texto, W/2 - f:getWidth(texto)/2, H * 0.96)
    love.graphics.setColor(1, 1, 1)
end

return UI