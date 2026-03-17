-- Pantalla de seleccion de mapa antes de empezar la partida
-- Cada opcion lanza la accion "play_map_N" que main.lua interpreta

local Base = require("systems.menu.base")

local Mapas = {}
local opcion = 1
local items = {
    { "Bosque", "Forest", "play_map_1" },
    { "Volcan", "Volcano", "play_map_2" },
    { "Nieve",  "Snow", "play_map_3" },
    { "Volver", "Back", "back"},
}

function Mapas.load(escena)
    opcion = 1
    Base.resetHover()
end

function Mapas.draw(escena)
    Base.draw(items, opcion, escena, "mapas")
end

function Mapas.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Mapas.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Mapas.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Mapas