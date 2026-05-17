-- systems/oleadas.lua
-- 10 oleadas con dificultad progresiva.

local Settings = require("systems.settings")

local Oleadas = {}

local OLEADAS = {
    { botCount=3,  hp=20, speedMult=0.7,  shootMult=1.6,  aimError=0.30,
      leadShots=false, canStrafe=false, canDodge=false, canRetreat=false,
      etiqueta="Oleada 1 — Exploradores", etiqueta_en="Wave 1 — Scouts" },
    { botCount=4,  hp=20, speedMult=0.8,  shootMult=1.4,  aimError=0.25,
      leadShots=false, canStrafe=false, canDodge=false, canRetreat=false,
      etiqueta="Oleada 2 — Patrulla ligera", etiqueta_en="Wave 2 — Light Patrol" },
    { botCount=4,  hp=30, speedMult=0.85, shootMult=1.2,  aimError=0.20,
      leadShots=false, canStrafe=true,  canDodge=false, canRetreat=false,
      etiqueta="Oleada 3 — Escuadrón táctico", etiqueta_en="Wave 3 — Tactical Squad" },
    { botCount=5,  hp=30, speedMult=0.9,  shootMult=1.1,  aimError=0.15,
      leadShots=false, canStrafe=true,  canDodge=false, canRetreat=false,
      etiqueta="Oleada 4 — Vanguardia", etiqueta_en="Wave 4 — Vanguard" },
    { botCount=5,  hp=40, speedMult=1.0,  shootMult=1.0,  aimError=0.12,
      leadShots=false, canStrafe=true,  canDodge=false, canRetreat=true,
      etiqueta="Oleada 5 — Fuerza blindada", etiqueta_en="Wave 5 — Armored Force" },
    { botCount=6,  hp=40, speedMult=1.0,  shootMult=0.9,  aimError=0.10,
      leadShots=true,  canStrafe=true,  canDodge=false, canRetreat=true,
      etiqueta="Oleada 6 — Artilleros expertos", etiqueta_en="Wave 6 — Expert Gunners" },
    { botCount=6,  hp=50, speedMult=1.1,  shootMult=0.85, aimError=0.08,
      leadShots=true,  canStrafe=true,  canDodge=true,  canRetreat=true,
      etiqueta="Oleada 7 — Élite mecánica", etiqueta_en="Wave 7 — Mechanical Elite" },
    { botCount=7,  hp=50, speedMult=1.15, shootMult=0.75, aimError=0.06,
      leadShots=true,  canStrafe=true,  canDodge=true,  canRetreat=true,
      etiqueta="Oleada 8 — Batallón pesado", etiqueta_en="Wave 8 — Heavy Battalion" },
    { botCount=8,  hp=60, speedMult=1.2,  shootMult=0.65, aimError=0.04,
      leadShots=true,  canStrafe=true,  canDodge=true,  canRetreat=true,
      etiqueta="Oleada 9 — Asalto final", etiqueta_en="Wave 9 — Final Assault" },
    { botCount=10, hp=70, speedMult=1.3,  shootMult=0.55, aimError=0.03,
      leadShots=true,  canStrafe=true,  canDodge=true,  canRetreat=true,
      etiqueta="Oleada 10 — Armagedón", etiqueta_en="Wave 10 — Armageddon" },
}

local TIEMPO_CUENTA_ATRAS = 4
local TOTAL_OLEADAS = #OLEADAS

local estado = "idle"
local numOleada = 0
local cuentaAtras = 0
local ModBot = nil

-- inicia el sistema de oleadas
function Oleadas.init(moduloBot)
    ModBot = moduloBot
    numOleada = 0
    estado = "cuenta_atras"
    cuentaAtras = TIEMPO_CUENTA_ATRAS
end

function Oleadas.update(dt)
    if estado == "idle" or estado == "victoria" then return end

    if estado == "cuenta_atras" then
        cuentaAtras = cuentaAtras - dt
        if cuentaAtras <= 0 then
            numOleada = numOleada + 1
            if numOleada > TOTAL_OLEADAS then
                estado = "victoria"
                return
            end
            ModBot.spawnOleada(OLEADAS[numOleada])
            estado = "activa"
        end

    elseif estado == "activa" then
        if ModBot.contarVivos() <= 0 then
            estado = "completada"
        end

    elseif estado == "completada" then
        if numOleada >= TOTAL_OLEADAS then
            estado = "victoria"
        else
            estado = "cuenta_atras"
            cuentaAtras = TIEMPO_CUENTA_ATRAS
        end
    end
end

function Oleadas.getEstado()
    return estado
end

function Oleadas.getNumOleada()
    return numOleada
end

function Oleadas.getCuentaAtras()
    return estado == "cuenta_atras" and cuentaAtras or 0
end

function Oleadas.esVictoria()
    return estado == "victoria"
end

function Oleadas.getEtiqueta()
    local def = OLEADAS[numOleada]
    if not def then return "" end
    if Settings.idioma == "EN" and def.etiqueta_en then
        return def.etiqueta_en
    end
    return def.etiqueta or ""
end

function Oleadas.getTotalOleadas()
    return TOTAL_OLEADAS
end

function Oleadas.reset()
    estado = "idle"
    numOleada = 0
    cuentaAtras = 0
end

return Oleadas