
-- Submenu de ranking.

local Base = require("systems.menu.base")
local Ranking = {}
local opcion = 1
local items = {
    { "Global", "Global"        },
    { "Amigos", "Friends"       },
    { "Local",  "Local"         },
    { "Volver", "Back", "back"  },
}

function Ranking.load(escena)  opcion = 1 end

function Ranking.draw(escena)
    Base.draw(items, opcion, escena, "ranking")
end

function Ranking.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Ranking.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Ranking.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Ranking