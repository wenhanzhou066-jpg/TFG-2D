-- Submenu de modos multijugador

local Base = require("systems.menu.base")

local Multijugador = {}
local opcion = 1
local items = {
    { "Crear Sala", "Create Room", ">room_config"},
    { "Unirse a Sala", "Join Room", ">room_browser"},
    { "Volver", "Back", "back"},
}

function Multijugador.load(escena)
    opcion = 1
    Base.resetHover()
end

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