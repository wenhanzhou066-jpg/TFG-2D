-- Submenu de practica con bots: elige dificultad y modo
local Base = require("systems.menu.base")

local Practicar = {}
local opcion = 1

local items = {
    { "Fácil — Un jugador",   "Easy — One player",   "bots_facil"   },
    { "Normal — Un jugador",  "Normal — One player",  "bots_normal"  },
    { "Difícil — Un jugador", "Hard — One player",   "bots_dificil" },
    { "Volver",               "Back",                "back"         },
}

function Practicar.load(escena)
    opcion = 1
    Base.resetHover()
end

function Practicar.draw(escena)
    Base.draw(items, opcion, escena, "practicar")
end

function Practicar.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Practicar.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Practicar.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Practicar