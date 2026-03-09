
-- Pantalla del menu principal

local Settings = require("systems.settings")
local UI = require("systems.ui")
local Base = require("systems.menu.base")

local Principal = {}
local opcion = 1
local items = {
    {"Jugar", "Play", ">jugar"},
    {"Personalizar", "Customize", ">personalizar" },
    {"Ranking", "Ranking", ">ranking"},
    {"Configuracion", "Settings", ">configuracion"},
    {"Salir", "Quit", "quit"},
}

function Principal.load(escena) opcion = 1 end

function Principal.draw(escena)
    local H = love.graphics.getHeight()
    local tiempo = escena.getTiempo()
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4

    -- Dibujamos los botones con la base generica
    Base.draw(items, opcion, escena, "principal")

    -- El menu principal tiene extras: nombre del juego
    love.graphics.setFont(UI.font("small"))
    UI.textCentered(UI.GAME_TITLE, yT + H * 0.14, UI.colors.goldDark)
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