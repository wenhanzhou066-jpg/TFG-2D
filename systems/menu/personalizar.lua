local Base = require("systems.menu.base")
local Personalizar = {}
local opcion = 1
local items = {
    { "Tanque",  "Tank"          },
    { "Color",   "Color"         },
    { "Emblema", "Emblem"        },
    { "Volver",  "Back", "back"  },
}

function Personalizar.load(escena)  opcion = 1 end

function Personalizar.draw(escena)
    Base.draw(items, opcion, escena, "personalizar")
end

function Personalizar.keypressed(key, escena)
    opcion = Base.keypressed(key, items, opcion, escena)
end

function Personalizar.mousemoved(_, my, escena)
    local nuevo = Base.mousemoved(my, items)
    if nuevo then opcion = nuevo end
end

function Personalizar.mousepressed(_, _, btn, escena)
    if btn ~= 1 then return end
    Base.ejecutar(items[opcion][3], escena)
end

return Personalizar