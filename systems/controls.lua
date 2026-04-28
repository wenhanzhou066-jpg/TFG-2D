-- Mapeo de teclas configurable para cada jugador local.

local Controls = {}

-- Acciones disponibles y valores por defecto
local defaults = {
    [1] = {
        up = "w",
        down = "s",
        left = "a",
        right = "d",
    },
    [2] = {
        up = "up",
        down = "down",
        left = "left",
        right = "right",
        turretLeft  = "j",
        turretRight = "k",
        fire = "l",
    },
}

local bindings = {}

-- Nombres legibles para las acciones en la UI
Controls.actionLabels = {
    up = "Avanzar",
    down = "Retroceder",
    left = "Girar izq.",
    right = "Girar der.",
    turretLeft  = "Torreta izq.",
    turretRight = "Torreta der.",
    fire = "Disparar",
}

-- Orden de acciones por jugador
Controls.actionOrder = {
    [1] = { "up", "down", "left", "right" },
    [2] = { "up", "down", "left", "right", "turretLeft", "turretRight", "fire" },
}

-- Restaurar valores predeterminados
function Controls.reset()
    bindings = {}
    for pid, acts in pairs(defaults) do
        bindings[pid] = {}
        for action, key in pairs(acts) do
            bindings[pid][action] = key
        end
    end
end

-- Inicializar al cargar el módulo
Controls.reset()

function Controls.get(pid, action)
    return bindings[pid] and bindings[pid][action]
end

function Controls.set(pid, action, key)
    if not bindings[pid] then bindings[pid] = {} end
    bindings[pid][action] = key
end

function Controls.getAll(pid)
    return bindings[pid] or {}
end

return Controls
