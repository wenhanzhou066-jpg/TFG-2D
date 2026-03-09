--Interfaz 

local UI = {}

UI.GAME_TITLE = "OPERATION: BLACK STEEL"

--Colores
-- Usamos una tabla de colores 
UI.colors = {
    cream    = {0.95, 0.90, 0.75, 1.0},   -- texto seleccionado
    creamDim = {0.65, 0.60, 0.50, 1.0},   -- texto no seleccionado
    goldDark = {0.80, 0.65, 0.20, 1.0},   -- subtitulo dorado
    khaki    = {0.70, 0.65, 0.45, 1.0},   -- texto descriptivo
    black    = {0.00, 0.00, 0.00, 1.0},
    white    = {1.00, 1.00, 1.00, 1.0},
}

--Fuentes
local fuentes = {}

-- Carga las fuentes segun el tamaño de pantalla actual.
function UI.loadFonts()
    local H = love.graphics.getHeight()
    fuentes.title  = love.graphics.newFont(math.floor(H * 0.07))
    fuentes.button = love.graphics.newFont(math.floor(H * 0.04))
    fuentes.small  = love.graphics.newFont(math.floor(H * 0.025))
end

-- Devuelve la fuente por nombre
function UI.font(nombre)
    return fuentes[nombre] or fuentes.button
end

--Fondo parallax
-- Dibuja las capas del fondo
function UI.drawParallax(fondos, tiempo)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    for i, fondo in ipairs(fondos) do
        local velocidad = i * 15
        local fw = fondo:getWidth()
        local offset = (tiempo * velocidad) % fw

        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(fondo, -offset,    0, 0, W / fw, H / fondo:getHeight())
        love.graphics.draw(fondo, fw - offset, 0, 0, W / fw, H / fondo:getHeight())
    end
end

--Banner de titulo
-- Dibuja el panel de fondo del titulo y el texto centrado encima.
function UI.titleBanner(img, texto, y, tiempo)
    if not texto then return end
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local bw = W * 0.55
    local bh = H * 0.10

    love.graphics.setColor(1, 1, 1, 0.9)
    if img then
        love.graphics.draw(img, W/2 - bw/2, y, 0, bw / img:getWidth(), bh / img:getHeight())
    else
        -- Si no hay imagen, dibujamos un rectangulo oscuro
        love.graphics.setColor(0.1, 0.1, 0.1, 0.8)
        love.graphics.rectangle("fill", W/2 - bw/2, y, bw, bh)
    end

    -- Texto del titulo centrado sobre el banner
    love.graphics.setFont(UI.font("title"))
    local tw = UI.font("title"):getWidth(texto)
    local th = UI.font("title"):getHeight()
    love.graphics.setColor(UI.colors.cream)
    love.graphics.print(texto, W/2 - tw/2, y + bh/2 - th/2)

    love.graphics.setColor(1, 1, 1)
end

--Boton
function UI.button(img, x, y, w, h, texto, sel, tiempo)
    -- Efecto de pulso suave en el boton seleccionado
    local escala = sel and (1 + math.sin(tiempo * 4) * 0.01) or 1
    local ox = w * (1 - escala) / 2

    if sel then
        love.graphics.setColor(1.0, 0.95, 0.7, 1.0)
    else
        love.graphics.setColor(0.7, 0.65, 0.55, 0.85)
    end

    if img then
        love.graphics.draw(img, x + ox, y, 0,
            (w * escala) / img:getWidth(),
            h / img:getHeight())
    else
        love.graphics.rectangle("fill", x + ox, y, w * escala, h)
    end

    if texto and texto ~= "" then
        love.graphics.setFont(UI.font("button"))
        local f  = UI.font("button")
        local tw = f:getWidth(texto)
        local th = f:getHeight()
        local col = sel and UI.colors.cream or UI.colors.creamDim
        love.graphics.setColor(col)
        love.graphics.print(texto, x + w/2 - tw/2, y + h/2 - th/2)
    end

    love.graphics.setColor(1, 1, 1)
end

--Texto 
function UI.text(texto, x, y, color)
    love.graphics.setColor(color or UI.colors.cream)
    love.graphics.print(texto, x, y)
    love.graphics.setColor(1, 1, 1)
end

function UI.textCentered(texto, y, color)
    local W  = love.graphics.getWidth()
    local f  = love.graphics.getFont()
    local tw = f:getWidth(texto)
    UI.text(texto, W/2 - tw/2, y, color)
end

--  Estilo viñeta
function UI.vignette(intensidad)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local mesh = love.graphics.newMesh({
        {0, 0, 0, 0, 0, 0, 0, intensidad},
        {W, 0, 0, 0, 0, 0, 0, intensidad},
        {W, H, 0, 0, 0, 0, 0, intensidad},
        {0, H, 0, 0, 0, 0, 0, intensidad},
    }, "fan")
    love.graphics.setColor(0, 0, 0, intensidad * 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H * 0.15)
    love.graphics.rectangle("fill", 0, H * 0.85, W, H * 0.15)
    love.graphics.setColor(1, 1, 1)
end

--Pie de pagina
function UI.footer()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    love.graphics.setFont(UI.font("small"))
    love.graphics.setColor(0.5, 0.5, 0.4, 0.6)
    local texto = "MENU V.1.0"
    local tw    = UI.font("small"):getWidth(texto)
    love.graphics.print(texto, W/2 - tw/2, H * 0.96)
    love.graphics.setColor(1, 1, 1)
end

return UI