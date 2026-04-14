-- Submenu de seleccion de modo oleadas
local Base = require("systems.menu.base")

local Oleadas = {}
local opcion = 1

local items = {
    { "Un jugador", "One player", "oleadas_solo" },
    { "Cooperativo", "Cooperative", "oleadas_coop" },
    { "Volver", "Back", "back" },
}

function Oleadas.load(escena)
    opcion = 1
    Base.resetHover()
end

function Oleadas.draw(escena)
    Base.draw(items, opcion, escena, "oleadas")
end

function Oleadas.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Oleadas.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Oleadas.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Oleadas