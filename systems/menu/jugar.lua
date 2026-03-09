
-- Submenu de modos de juego.

local Base = require("systems.menu.base")
local Jugar = {}
local opcion = 1
local items = {
    { "Oleadas","Waves"},
    { "Cooperativo","Cooperative"},
    { "Multijugador","Multiplayer",">multijugador"},
    { "Practicar con bots", "Practice with bots",">dificultad"},
    { "Volver","Back","back"},
}

function Jugar.load(escena)  opcion = 1 end

function Jugar.draw(escena)
    Base.draw(items, opcion, escena, "jugar")
end

function Jugar.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Jugar.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Jugar.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Jugar