-- systems/menu/personalizar.lua
-- Pantalla de perfiles: crear / cargar sesión / editar color del tanque.

local Settings = require("systems.settings")
local UI       = require("systems.ui")
local Base     = require("systems.menu.base")
local Audio    = require("systems.audio")
local Perfil   = require("systems.perfil")

local Personalizar = {}

-- Modo activo: "inicio" | "nuevo" | "cargar" | "perfil"
local modo = "inicio"

-- ── Formulario de texto (modos nuevo / cargar) ────────────────────────────
local campos     = {}       -- {id, label, text, secret}
local campoActivo = 1
local cursorTimer = 0

-- ── Modo perfil ───────────────────────────────────────────────────────────
local colorR, colorG, colorB = 1.0, 0.7, 0.2
local arrastrando  = nil    -- nil | "r" | "g" | "b"
local opcionPerfil = 1      -- 1=Guardar 2=Cerrar sesion 3=Volver

-- ── Menú inicio ───────────────────────────────────────────────────────────
local opcionInicio = 1

-- ── Mensajes ──────────────────────────────────────────────────────────────
local msg      = ""
local msgTimer = 0
local msgOk    = false

local function setMsg(texto, ok)
    msg      = texto or ""
    msgTimer = 3.5
    msgOk    = ok == true
end

-- ── Helpers de geometría ──────────────────────────────────────────────────

-- Devuelve items dinámicos para el menú de inicio
local function itemsInicio()
    local list = {
        { "Nuevo Perfil",  "New Profile",  "nuevo"  },
        { "Cargar Perfil", "Load Profile", "cargar" },
    }
    if Perfil.activo then
        table.insert(list, { "Editar Perfil", "Edit Profile", "editar" })
    end
    table.insert(list, { "Volver", "Back", "back" })
    return list
end

-- Geometría de un campo de texto (idx 1-based)
local function geomCampo(idx, W, H)
    local f    = UI.font("button")
    local padY = math.floor(f:getHeight() * 0.55)
    local bh   = f:getHeight() + padY * 2
    local bw   = W * 0.40
    -- cada fila ocupa bh (campo) + fHeight + 4 (label encima) + H*0.025 (margen)
    local rowH = bh + f:getHeight() + 4 + H * 0.025
    local baseY = H * 0.30
    local y    = baseY + (idx - 1) * rowH
    local x    = W / 2 - bw / 2
    return x, y, bw, bh, rowH
end

-- Geometría de la barra del slider de color (row 0/1/2)
local function geomColorRow(row, W, H)
    local f    = UI.font("button")
    local padY = math.floor(f:getHeight() * 0.55)
    local bh   = f:getHeight() + padY * 2   -- alto del "botón" que muestra label+valor
    local slH  = 8
    local rowH = bh + slH + 6 + H * 0.018
    local baseY = H * 0.28
    local bw   = W * 0.40
    local x    = W / 2 - bw / 2
    local y    = baseY + row * rowH
    local barY = y + bh + 4
    return x, y, bw, bh, barY, slH, rowH
end

-- ── Dibujado de un campo de texto ─────────────────────────────────────────
local function drawCampo(idx, campo, focused, W, H)
    local x, y, bw, bh = geomCampo(idx, W, H)
    local f    = UI.font("button")
    local padX = math.floor(f:getHeight() * 1.0)

    -- Fondo estilo sliderBg
    love.graphics.setColor(UI.colors.sliderBg)
    love.graphics.rectangle("fill", x, y, bw, bh, 4)

    -- Borde: dorado si activo, apagado si no
    if focused then
        love.graphics.setColor(UI.colors.goldDark)
    else
        love.graphics.setColor(0.35, 0.30, 0.20, 0.65)
    end
    love.graphics.rectangle("line", x, y, bw, bh, 4)

    -- Etiqueta encima del campo
    love.graphics.setFont(f)
    love.graphics.setColor(UI.colors.khaki)
    love.graphics.print(campo.label, x, y - f:getHeight() - 4)

    -- Texto (con cursor parpadeante si activo)
    local display = campo.secret and string.rep("*", #campo.text) or campo.text
    local showCursor = focused and (math.floor(cursorTimer * 2) % 2 == 0)
    local cursor = showCursor and "|" or ""
    love.graphics.setColor(UI.colors.cream)
    love.graphics.print(display .. cursor, x + padX, y + bh / 2 - f:getHeight() / 2)

    love.graphics.setColor(1, 1, 1)
end

-- ── Dibujado de una fila de slider de color ───────────────────────────────
local function drawColorRow(row, label, val, sel, tiempo, escena)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local x, y, bw, bh, barY, slH = geomColorRow(row, W, H)
    local f    = UI.font("button")
    local padX = math.floor(f:getHeight() * 1.2)
    local valStr = math.floor(val * 255) .. ""

    -- Botón con label + valor usando buttonConfig
    UI.buttonConfig(
        escena.botonImg(), escena.botonExitImg(),
        W / 2 - bw / 2, y, bw, bh + 4,
        label, valStr, sel, tiempo, false
    )

    if sel then UI.drawSelector(W / 2 - bw / 2, y, bh, tiempo) end

    -- Slider debajo
    UI.drawSlider(x, barY, bw, slH, val)
end

-- ── Lógica del formulario ─────────────────────────────────────────────────
local function resetForm(m)
    campoActivo = 1
    cursorTimer = 0
    msg         = ""
    msgTimer    = 0
    if m == "nuevo" then
        campos = {
            { id = "gamertag", label = "GAMERTAG",  text = "", secret = false },
            { id = "password", label = "CONTRASENA", text = "", secret = true  },
            { id = "confirm",  label = "CONFIRMAR",  text = "", secret = true  },
        }
    elseif m == "cargar" then
        campos = {
            { id = "gamertag", label = "GAMERTAG",  text = "", secret = false },
            { id = "password", label = "CONTRASENA", text = "", secret = true  },
        }
    end
end

local function ejecutarForm(escena)
    if modo == "nuevo" then
        local gt   = campos[1].text
        local pw   = campos[2].text
        local conf = campos[3].text
        if pw ~= conf then
            setMsg("Las contrasenas no coinciden")
            return
        end
        local ok, err = Perfil.registrar(gt, pw)
        if ok then
            Perfil.activo = Perfil.autenticar(gt, pw)
            setMsg("Perfil creado: " .. gt, true)
            modo = "inicio"
        else
            setMsg(err or "Error al crear perfil")
        end

    elseif modo == "cargar" then
        local gt = campos[1].text
        local pw = campos[2].text
        local perfil, err = Perfil.autenticar(gt, pw)
        if perfil then
            Perfil.activo = perfil
            colorR = perfil.colorR
            colorG = perfil.colorG
            colorB = perfil.colorB
            setMsg("Bienvenido, " .. gt, true)
            modo = "inicio"
        else
            setMsg(err or "Credenciales incorrectas")
        end
    end
end

-- ── API pública ───────────────────────────────────────────────────────────

function Personalizar.load(escena)
    modo         = "inicio"
    opcionInicio = 1
    msg          = ""
    msgTimer     = 0
    Base.resetHover()
    Perfil.init()
end

function Personalizar.update(dt, escena)
    cursorTimer = cursorTimer + dt
    if msgTimer > 0 then
        msgTimer = msgTimer - dt
        if msgTimer <= 0 then msg = "" end
    end
end

function Personalizar.draw(escena)
    local W, H   = love.graphics.getWidth(), love.graphics.getHeight()
    local tiempo = escena.getTiempo()
    local yT     = H * 0.04 + math.sin(tiempo * 2) * 4

    UI.drawParallax(escena.fondos(), tiempo)
    UI.titleBanner(escena.tituloImg(), Base.tr("personalizar"), yT, tiempo)

    -- ── Modo inicio ───────────────────────────────────────────────────────
    if modo == "inicio" then
        local items = itemsInicio()
        local bw    = W * 0.40
        local bh    = H * 0.10 * 0.72
        for i, item in ipairs(items) do
            local y     = H * 0.28 + (i - 1) * H * 0.10
            local sel   = i == opcionInicio
            local esExit = item[3] == "back"
            UI.button(
                escena.botonImg(), W / 2 - bw / 2, y, bw, bh,
                Base.itemLabel(item), sel, tiempo, esExit, escena.botonExitImg()
            )
            if sel then UI.drawSelector(W / 2 - bw / 2, y, bh, tiempo) end
        end

        -- Gamertag activo en la parte inferior
        if Perfil.activo then
            local f = UI.font("small")
            love.graphics.setFont(f)
            love.graphics.setColor(UI.colors.goldDark)
            local txt = "SESION: " .. Perfil.activo.gamertag
            love.graphics.print(txt, W / 2 - f:getWidth(txt) / 2, H * 0.87)
            love.graphics.setColor(1, 1, 1)
        end

    -- ── Modos nuevo / cargar ──────────────────────────────────────────────
    elseif modo == "nuevo" or modo == "cargar" then
        for i, c in ipairs(campos) do
            drawCampo(i, c, i == campoActivo, W, H)
        end

        -- Botones Aceptar / Cancelar
        local _, _, _, _, rowH = geomCampo(1, W, H)
        local yBtn = H * 0.30 + #campos * rowH + H * 0.01
        local btnW = W * 0.18
        local btnH = H * 0.10 * 0.72
        local gap  = W * 0.04
        local x1   = W / 2 - btnW - gap / 2
        local x2   = W / 2 + gap / 2
        local acLabel = modo == "nuevo" and "CREAR" or "ENTRAR"

        UI.button(escena.botonImg(),     x1, yBtn, btnW, btnH,
                  acLabel,    false, tiempo, false, nil)
        UI.button(escena.botonExitImg(), x2, yBtn, btnW, btnH,
                  "CANCELAR", false, tiempo, true,  escena.botonExitImg())

    -- ── Modo perfil ───────────────────────────────────────────────────────
    elseif modo == "perfil" then
        local rowLabels = { "R", "G", "B" }
        local rowVals   = { colorR, colorG, colorB }
        for row = 0, 2 do
            drawColorRow(row, rowLabels[row + 1], rowVals[row + 1],
                         opcionPerfil == (row + 1), tiempo, escena)
        end

        -- Preview de color del tanque
        local _, _, _, _, _, _, rowH = geomColorRow(0, W, H)
        local previewX = W * 0.72
        local previewY = H * 0.28
        local previewS = rowH * 2.5
        love.graphics.setColor(colorR, colorG, colorB, 1)
        love.graphics.rectangle("fill", previewX, previewY, previewS, previewS, 6)
        love.graphics.setColor(UI.colors.goldDark)
        love.graphics.rectangle("line", previewX, previewY, previewS, previewS, 6)
        love.graphics.setColor(1, 1, 1)

        -- Botones de acción
        local baseY = H * 0.28 + 3 * rowH + H * 0.03
        local bw    = W * 0.40
        local bh    = H * 0.09 * 0.72
        local bLabels  = { "GUARDAR", "CERRAR SESION", "VOLVER" }
        local bExit    = { false, true, true }
        for i = 1, 3 do
            local y   = baseY + (i - 1) * H * 0.09
            local sel = opcionPerfil == (i + 3)
            UI.button(
                bExit[i] and escena.botonExitImg() or escena.botonImg(),
                W / 2 - bw / 2, y, bw, bh,
                bLabels[i], sel, tiempo, bExit[i], escena.botonExitImg()
            )
            if sel then UI.drawSelector(W / 2 - bw / 2, y, bh, tiempo) end
        end
    end

    -- Mensaje de estado
    if msg ~= "" then
        local f = UI.font("small")
        love.graphics.setFont(f)
        love.graphics.setColor(msgOk and {0.45, 0.85, 0.30, 1} or {0.90, 0.30, 0.25, 1})
        love.graphics.print(msg, W / 2 - f:getWidth(msg) / 2, H * 0.83)
        love.graphics.setColor(1, 1, 1)
    end

    UI.vignette(0.45)
    UI.footer()
    love.graphics.setColor(1, 1, 1)
end

-- ── Entrada de texto (delegado desde love.textinput) ─────────────────────

function Personalizar.textinput(t)
    if modo ~= "nuevo" and modo ~= "cargar" then return end
    local c = campos[campoActivo]
    if c and #c.text < 24 then
        c.text    = c.text .. t
        cursorTimer = 0
    end
end

-- ── Teclado ───────────────────────────────────────────────────────────────

function Personalizar.keypressed(key, escena)
    if modo == "inicio" then
        local items = itemsInicio()

        if key == "up" then
            local nueva = (opcionInicio - 2) % #items + 1
            if nueva ~= opcionInicio then Audio.hoverMenu() end
            opcionInicio = nueva

        elseif key == "down" then
            local nueva = opcionInicio % #items + 1
            if nueva ~= opcionInicio then Audio.hoverMenu() end
            opcionInicio = nueva

        elseif key == "return" or key == "kpenter" then
            local ac = items[opcionInicio][3]
            if ac == "back" then
                Audio.volverMenu(); escena.volver()
            elseif ac == "nuevo" then
                resetForm("nuevo"); modo = "nuevo"; Audio.clickMenu()
            elseif ac == "cargar" then
                resetForm("cargar"); modo = "cargar"; Audio.clickMenu()
            elseif ac == "editar" and Perfil.activo then
                colorR = Perfil.activo.colorR
                colorG = Perfil.activo.colorG
                colorB = Perfil.activo.colorB
                opcionPerfil = 1; modo = "perfil"; Audio.clickMenu()
            end

        elseif key == "escape" then
            Audio.volverMenu(); escena.volver()
        end

    elseif modo == "nuevo" or modo == "cargar" then
        if key == "tab" then
            campoActivo = campoActivo % #campos + 1
            cursorTimer = 0; Audio.hoverMenu()

        elseif key == "backspace" then
            local c = campos[campoActivo]
            if c and #c.text > 0 then
                c.text = c.text:sub(1, -2)
                cursorTimer = 0
            end

        elseif key == "return" or key == "kpenter" then
            if campoActivo < #campos then
                campoActivo = campoActivo + 1
                cursorTimer = 0
            else
                ejecutarForm(escena)
            end

        elseif key == "up" then
            campoActivo = math.max(1, campoActivo - 1)
            cursorTimer = 0; Audio.hoverMenu()

        elseif key == "down" then
            campoActivo = math.min(#campos, campoActivo + 1)
            cursorTimer = 0; Audio.hoverMenu()

        elseif key == "escape" then
            Audio.volverMenu(); modo = "inicio"
        end

    elseif modo == "perfil" then
        -- 1..3 = sliders, 4..6 = botones
        local total = 6
        if key == "up" then
            opcionPerfil = math.max(1, opcionPerfil - 1); Audio.hoverMenu()

        elseif key == "down" then
            opcionPerfil = math.min(total, opcionPerfil + 1); Audio.hoverMenu()

        elseif key == "right" then
            local step = 0.04
            if     opcionPerfil == 1 then colorR = math.min(1, colorR + step); Audio.clickMenu()
            elseif opcionPerfil == 2 then colorG = math.min(1, colorG + step); Audio.clickMenu()
            elseif opcionPerfil == 3 then colorB = math.min(1, colorB + step); Audio.clickMenu()
            end

        elseif key == "left" then
            local step = 0.04
            if     opcionPerfil == 1 then colorR = math.max(0, colorR - step); Audio.clickMenu()
            elseif opcionPerfil == 2 then colorG = math.max(0, colorG - step); Audio.clickMenu()
            elseif opcionPerfil == 3 then colorB = math.max(0, colorB - step); Audio.clickMenu()
            end

        elseif key == "return" or key == "kpenter" then
            if opcionPerfil == 4 then           -- Guardar
                if Perfil.activo then
                    Perfil.actualizarColor(Perfil.activo.gamertag,
                        { colorR = colorR, colorG = colorG, colorB = colorB })
                end
                setMsg("Color guardado", true)
            elseif opcionPerfil == 5 then       -- Cerrar sesion
                Perfil.activo = nil
                Audio.volverMenu(); modo = "inicio"
            elseif opcionPerfil == 6 then       -- Volver
                Audio.volverMenu(); modo = "inicio"
            end

        elseif key == "escape" then
            Audio.volverMenu(); modo = "inicio"
        end
    end
end

-- ── Ratón ─────────────────────────────────────────────────────────────────

function Personalizar.mousemoved(mx, my, escena)
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    if modo == "inicio" then
        local items = itemsInicio()
        for i = 1, #items do
            local y = H * 0.28 + (i - 1) * H * 0.10
            if my > y and my < y + H * 0.10 then
                if opcionInicio ~= i then Audio.hoverMenu() end
                opcionInicio = i
                break
            end
        end

    elseif modo == "perfil" and arrastrando then
        local row = arrastrando == "r" and 0 or arrastrando == "g" and 1 or 2
        local sx, _, sw = geomColorRow(row, W, H)
        local val = math.max(0, math.min(1, (mx - sx) / sw))
        if     arrastrando == "r" then colorR = val
        elseif arrastrando == "g" then colorG = val
        else                           colorB = val end
    end
end

function Personalizar.mousepressed(mx, my, btn, escena)
    if btn ~= 1 then return end
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()

    if modo == "inicio" then
        local items = itemsInicio()
        local bh    = H * 0.10 * 0.72
        for i, item in ipairs(items) do
            local y = H * 0.28 + (i - 1) * H * 0.10
            if my >= y and my <= y + bh then
                local ac = item[3]
                Audio.clickMenu()
                if ac == "back" then
                    Audio.volverMenu(); escena.volver()
                elseif ac == "nuevo" then
                    resetForm("nuevo"); modo = "nuevo"
                elseif ac == "cargar" then
                    resetForm("cargar"); modo = "cargar"
                elseif ac == "editar" and Perfil.activo then
                    colorR = Perfil.activo.colorR
                    colorG = Perfil.activo.colorG
                    colorB = Perfil.activo.colorB
                    opcionPerfil = 1; modo = "perfil"
                end
                break
            end
        end

    elseif modo == "nuevo" or modo == "cargar" then
        -- Activar campo al hacer clic
        for i = 1, #campos do
            local x, y, bw, bh = geomCampo(i, W, H)
            if mx >= x and mx <= x + bw and my >= y and my <= y + bh then
                if campoActivo ~= i then Audio.hoverMenu() end
                campoActivo = i; cursorTimer = 0
                break
            end
        end

        -- Botones Aceptar / Cancelar
        local _, _, _, _, rowH = geomCampo(1, W, H)
        local yBtn = H * 0.30 + #campos * rowH + H * 0.01
        local btnW = W * 0.18
        local btnH = H * 0.10 * 0.72
        local gap  = W * 0.04
        local x1   = W / 2 - btnW - gap / 2
        local x2   = W / 2 + gap / 2
        if my >= yBtn and my <= yBtn + btnH then
            if mx >= x1 and mx <= x1 + btnW then
                ejecutarForm(escena); Audio.clickMenu()
            elseif mx >= x2 and mx <= x2 + btnW then
                Audio.volverMenu(); modo = "inicio"
            end
        end

    elseif modo == "perfil" then
        local f  = UI.font("button")
        local bh = f:getHeight() + math.floor(f:getHeight() * 0.55) * 2

        -- Clic en slider bars
        local clavesSlider = { "r", "g", "b" }
        for row = 0, 2 do
            local sx, sy, sw, _, barY, slH = geomColorRow(row, W, H)
            if mx >= sx and mx <= sx + sw and my >= barY and my <= barY + slH + 4 then
                arrastrando = clavesSlider[row + 1]
                local val = math.max(0, math.min(1, (mx - sx) / sw))
                if     row == 0 then colorR = val
                elseif row == 1 then colorG = val
                else                 colorB = val end
                opcionPerfil = row + 1
                Audio.clickMenu()
                return
            end
            -- Clic en la zona del botón de la fila (label+valor) también selecciona
            if mx >= sx and mx <= sx + sw and my >= sy and my <= sy + bh then
                opcionPerfil = row + 1
                Audio.hoverMenu()
                return
            end
        end

        -- Botones Guardar / Cerrar sesion / Volver
        local _, _, _, _, _, _, rowH = geomColorRow(0, W, H)
        local baseY = H * 0.28 + 3 * rowH + H * 0.03
        local btnW  = W * 0.40
        local btnH  = H * 0.09 * 0.72
        for i = 1, 3 do
            local y = baseY + (i - 1) * H * 0.09
            if my >= y and my <= y + btnH and mx >= W/2 - btnW/2 and mx <= W/2 + btnW/2 then
                opcionPerfil = i + 3
                Audio.clickMenu()
                if i == 1 then      -- Guardar
                    if Perfil.activo then
                        Perfil.actualizarColor(Perfil.activo.gamertag,
                            { colorR = colorR, colorG = colorG, colorB = colorB })
                    end
                    setMsg("Color guardado", true)
                elseif i == 2 then  -- Cerrar sesion
                    Perfil.activo = nil
                    Audio.volverMenu(); modo = "inicio"
                elseif i == 3 then  -- Volver
                    Audio.volverMenu(); modo = "inicio"
                end
                break
            end
        end
    end
end

function Personalizar.mousereleased(_, _, btn)
    if btn == 1 then arrastrando = nil end
end

return Personalizar
