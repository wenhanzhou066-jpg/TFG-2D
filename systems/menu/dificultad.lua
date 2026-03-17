-- Submenu de seleccion de dificultad

local Base = require("systems.menu.base")

local Dificultad = {}
local opcion = 1
local items = {
    { "Facil", "Easy"},
    { "Normal", "Normal"},
    { "Dificil", "Hard"},
    { "Volver", "Back", "back"},
}

function Dificultad.load(escena)
    opcion = 1
    Base.resetHover()
end

function Dificultad.draw(escena)
    Base.draw(items, opcion, escena, "dificultad")
end

function Dificultad.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Dificultad.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Dificultad.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Dificultad