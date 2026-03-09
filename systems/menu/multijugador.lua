
-- Submenu de modos multijugador.

local Base = require("systems.menu.base")
local Multijugador = {}
local opcion = 1
local items = {
    { "1 vs 1",         "1 vs 1"       },
    { "Equipos 2v2",    "Teams 2v2"    },
    { "Todos vs Todos", "Free for All" },
    { "Volver",         "Back", "back" },
}

function Multijugador.load(escena)  opcion = 1 end

function Multijugador.draw(escena)
    Base.draw(items, opcion, escena, "multijugador")
end

function Multijugador.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Multijugador.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Multijugador.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Multijugador