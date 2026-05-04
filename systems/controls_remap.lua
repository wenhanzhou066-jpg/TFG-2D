-- Panel de remapeo de teclas para ambos jugadores locales.

local Controls = require("systems.controls")

local Remap = {}

local visible = false
local waitingFor = nil
local errorMsg = nil
local errorTimer = 0

local GAME_W, GAME_H = 1920, 1080

-- Dimensiones del panel
local BOX_W = 920
local BOX_H = 620
local BX = (GAME_W - BOX_W) / 2
local BY = (GAME_H - BOX_H) / 2

local COL_W = (BOX_W - 60) / 2  -- ancho de cada columna
local ROW_H = 46
local ROWS_Y = BY + 148
local COL1_X = BX + 20
local COL2_X = BX + BOX_W / 2 + 10

local function rowRect(colIdx, rowIdx)
    local x = colIdx == 1 and COL1_X or COL2_X
    local y = ROWS_Y + (rowIdx - 1) * ROW_H
    return x, y, COL_W - 20, ROW_H - 4
end

local function acceptBtnRect()  return BX + BOX_W/2 - 100, BY + BOX_H - 62, 200, 44 end
local function resetBtnRect()   return BX + 20,             BY + BOX_H - 62, 180, 44 end

-- Comprueba si una tecla ya está asignada a algún jugador/acción
local function findDuplicates(newKey, exceptPid, exceptAction)
    for pid = 1, 2 do
        local order = Controls.actionOrder[pid]
        local binds = Controls.getAll(pid)
        for _, action in ipairs(order) do
            if not (pid == exceptPid and action == exceptAction) then
                if binds[action] == newKey then
                    local label = Controls.actionLabels[action] or action
                    return pid, label
                end
            end
        end
    end
    return nil
end


function Remap.open()
    visible = true
    waitingFor = nil
    errorMsg = nil
    errorTimer = 0
end

function Remap.close()
    visible = false
    waitingFor = nil
    errorMsg = nil
end

function Remap.isVisible()
    return visible
end

function Remap.update(dt)
    if not visible then return end
    if errorTimer > 0 then
        errorTimer = errorTimer - dt
        if errorTimer <= 0 then
            errorMsg   = nil
            errorTimer = 0
        end
    end
end

function Remap.keypressed(key)
    if not visible then return false end

    if waitingFor then
        if key == "escape" then
            waitingFor = nil
            return true
        end

        -- Comprobar duplicado
        local dupPid, dupLabel = findDuplicates(key, waitingFor.pid, waitingFor.action)
        if dupPid then
            local who = dupPid == waitingFor.pid and "este jugador" or ("Jugador " .. dupPid)
            errorMsg   = "\"" .. key .. "\" ya está asignada a [" .. dupLabel .. "] de " .. who
            errorTimer = 2.5
            waitingFor = nil
            return true
        end

        Controls.set(waitingFor.pid, waitingFor.action, key)
        waitingFor = nil
        return true
    end

    if key == "escape" then
        Remap.close()
        return true
    end

    return true
end

function Remap.mousepressed(mx, my, btn)
    if not visible then return false end
    if btn ~= 1 then return true end

    -- Cancelar espera con clic
    if waitingFor then
        waitingFor = nil
        return true
    end

    -- Botón Aceptar
    local ax, ay, aw, ah = acceptBtnRect()
    if mx >= ax and mx <= ax+aw and my >= ay and my <= ay+ah then
        Remap.close()
        return true
    end

    -- Botón Restablecer
    local rx, ry, rw, rh = resetBtnRect()
    if mx >= rx and mx <= rx+rw and my >= ry and my <= ry+rh then
        Controls.reset()
        errorMsg = nil
        return true
    end

    -- Filas de acciones
    for pidIdx = 1, 2 do
        local order = Controls.actionOrder[pidIdx]
        for ai, action in ipairs(order) do
            local fx, fy, fw, fh = rowRect(pidIdx, ai)
            if mx >= fx and mx <= fx+fw and my >= fy and my <= fy+fh then
                waitingFor = { pid = pidIdx, action = action }
                errorMsg   = nil
                return true
            end
        end
    end

    return true
end

--Dibujo

function Remap.draw()
    if not visible then return end

    local UI      = require("systems.ui")
    local fontBtn = UI.font("button")
    local fontSm  = UI.font("small")
    local lineH   = fontSm:getHeight()

    -- Fondo oscuro
    love.graphics.setColor(0, 0, 0, 0.88)
    love.graphics.rectangle("fill", 0, 0, GAME_W, GAME_H)

    -- Panel
    love.graphics.setColor(0.07, 0.09, 0.15, 0.97)
    love.graphics.rectangle("fill", BX, BY, BOX_W, BOX_H, 14, 14)
    love.graphics.setColor(0.25, 0.55, 1.0, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", BX, BY, BOX_W, BOX_H, 14, 14)
    love.graphics.setLineWidth(1)

    -- Título
    love.graphics.setFont(fontBtn)
    love.graphics.setColor(0.9, 0.85, 1.0)
    love.graphics.printf("CONFIGURAR CONTROLES", BX, BY + 18, BOX_W, "center")

    love.graphics.setFont(fontSm)

    -- Subtítulo de ayuda
    love.graphics.setColor(0.50, 0.50, 0.50)
    love.graphics.printf("Haz clic en una acción y pulsa la nueva tecla · Escape para cancelar", BX, BY + 62, BOX_W, "center")

    -- Separador horizontal
    love.graphics.setColor(0.25, 0.55, 1.0, 0.4)
    love.graphics.line(BX + 20, BY + 90, BX + BOX_W - 20, BY + 90)

    -- Cabeceras de columna
    local hdrY = BY + 100

    -- Fondo cabecera J1
    love.graphics.setColor(0.10, 0.22, 0.40, 0.85)
    love.graphics.rectangle("fill", COL1_X, hdrY, COL_W - 20, 34, 6, 6)
    love.graphics.setColor(0.3, 0.8, 1.0)
    love.graphics.printf("JUGADOR 1", COL1_X, hdrY + (34 - lineH) / 2, COL_W - 20, "center")

    -- Fondo cabecera J2
    love.graphics.setColor(0.35, 0.18, 0.05, 0.85)
    love.graphics.rectangle("fill", COL2_X, hdrY, COL_W - 20, 34, 6, 6)
    love.graphics.setColor(1.0, 0.65, 0.2)
    love.graphics.printf("JUGADOR 2", COL2_X, hdrY + (34 - lineH) / 2, COL_W - 20, "center")

    -- Separador vertical entre columnas
    love.graphics.setColor(0.25, 0.55, 1.0, 0.25)
    love.graphics.line(BX + BOX_W/2, BY + 90, BX + BOX_W/2, BY + BOX_H - 78)

    -- ── Filas de acciones ──
    for pidIdx = 1, 2 do
        local order  = Controls.actionOrder[pidIdx]
        local binds  = Controls.getAll(pidIdx)

        for ai, action in ipairs(order) do
            local fx, fy, fw, fh = rowRect(pidIdx, ai)
            local isWaiting = waitingFor and
                              waitingFor.pid == pidIdx and
                              waitingFor.action == action

            -- Alternado sutil de fila
            if ai % 2 == 0 then
                love.graphics.setColor(1, 1, 1, 0.03)
                love.graphics.rectangle("fill", fx, fy, fw, fh, 4, 4)
            end

            -- Resalte si está esperando tecla
            if isWaiting then
                love.graphics.setColor(0.9, 0.55, 0.05, 0.25)
                love.graphics.rectangle("fill", fx, fy, fw, fh, 4, 4)
                love.graphics.setColor(1.0, 0.75, 0.2, 0.7)
                love.graphics.setLineWidth(1.5)
                love.graphics.rectangle("line", fx, fy, fw, fh, 4, 4)
                love.graphics.setLineWidth(1)
            end

            -- Label de la acción (izquierda)
            local label = Controls.actionLabels[action] or action
            love.graphics.setColor(0.80, 0.80, 0.80)
            love.graphics.print(label, fx + 10, fy + (fh - lineH) / 2)

            -- Tecla asignada (derecha)
            local keyBoxW = 160
            local keyBoxX = fx + fw - keyBoxW - 8
            local keyBoxY = fy + 4
            local keyBoxH = fh - 8

            if isWaiting then
                love.graphics.setColor(1.0, 0.85, 0.3)
                love.graphics.printf("[ presiona tecla ]", keyBoxX, fy + (fh - lineH) / 2, keyBoxW, "center")
            else
                local currentKey = binds[action] or "?"
                love.graphics.setColor(0.15, 0.18, 0.30, 0.95)
                love.graphics.rectangle("fill", keyBoxX, keyBoxY, keyBoxW, keyBoxH, 5, 5)
                love.graphics.setColor(0.35, 0.55, 0.90, 0.8)
                love.graphics.rectangle("line", keyBoxX, keyBoxY, keyBoxW, keyBoxH, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(currentKey, keyBoxX, fy + (fh - lineH) / 2, keyBoxW, "center")
            end
        end
    end

    -- ── Mensaje de error ──
    if errorMsg and errorTimer > 0 then
        local alpha = math.min(1, errorTimer / 0.4)
        local emW = BOX_W - 60
        local emX = BX + 30
        local emY = BY + BOX_H - 105

        love.graphics.setColor(0.6, 0.10, 0.10, 0.90 * alpha)
        love.graphics.rectangle("fill", emX, emY, emW, 32, 6, 6)
        love.graphics.setColor(1.0, 0.35, 0.35, alpha)
        love.graphics.rectangle("line", emX, emY, emW, 32, 6, 6)
        love.graphics.setColor(1, 0.90, 0.90, alpha)
        love.graphics.printf("" .. errorMsg, emX, emY + (32 - lineH) / 2, emW, "center")
    end

    -- ── Botones ──
    local rx, ry, rw, rh = resetBtnRect()
    love.graphics.setColor(0.22, 0.22, 0.40, 0.90)
    love.graphics.rectangle("fill", rx, ry, rw, rh, 8, 8)
    love.graphics.setColor(0.55, 0.55, 0.80)
    love.graphics.rectangle("line", rx, ry, rw, rh, 8, 8)
    love.graphics.setColor(0.80, 0.80, 1.0)
    love.graphics.printf("Restablecer", rx, ry + (rh - lineH) / 2, rw, "center")

    local ax, ay, aw, ah = acceptBtnRect()
    love.graphics.setColor(0.12, 0.42, 0.15, 0.90)
    love.graphics.rectangle("fill", ax, ay, aw, ah, 8, 8)
    love.graphics.setColor(0.35, 0.75, 0.40)
    love.graphics.rectangle("line", ax, ay, aw, ah, 8, 8)
    love.graphics.setColor(0.75, 1.0, 0.78)
    love.graphics.printf("Aceptar", ax, ay + (ah - lineH) / 2, aw, "center")

    love.graphics.setColor(1, 1, 1)
end

return Remap
