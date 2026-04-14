-- Configuración de sala antes de crearla
-- Permite elegir modo de juego y número máximo de jugadores

local Base = require("systems.menu.base")
local UI = require("systems.ui")

local RoomConfig = {}
local selectedMode = 1
local roomInput = ""
local creatingRoom = false  -- Prevenir doble-click

local gameModes = {
    { id = "1v1", name = "1 vs 1", name_en = "1 vs 1", max_players = 2, desc = "Duelo individual" },
    { id = "ffa", name = "Todos vs Todos", name_en = "Free for All", max_players = 8, desc = "Batalla campal" },
    { id = "2v2", name = "Equipos 2v2", name_en = "Teams 2v2", max_players = 4, desc = "2 equipos de 2" },
}

local fonts = {
    big = nil,
    medium = nil,
    small = nil
}

function RoomConfig.load(escena)
    selectedMode = 1
    roomInput = "sala_" .. math.random(1000, 9999)
    creatingRoom = false  -- Reset flag

    local H = love.graphics.getHeight()
    fonts.big = love.graphics.newFont(math.floor(H * 0.06))
    fonts.medium = love.graphics.newFont(math.floor(H * 0.04))
    fonts.small = love.graphics.newFont(math.floor(H * 0.025))
end

function RoomConfig.update(dt, escena)
    -- No se necesitan animaciones
end

function RoomConfig.draw(escena)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local tiempo = escena.getTiempo()

    -- Fondo parallax
    UI.drawParallax(escena.fondos(), tiempo)

    -- Titulo
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4
    UI.titleBanner(escena.tituloImg(), "CONFIGURAR SALA", yT, tiempo)

    -- Panel central
    love.graphics.setColor(0, 0, 0, 0.8)
    local pw, ph = W * 0.6, H * 0.75
    local panelX = W/2 - pw/2
    local panelY = H/2 - ph/2
    love.graphics.rectangle("fill", panelX, panelY, pw, ph, 10, 10)

    -- Calcular posiciones relativas al panel
    local contentStartY = panelY + ph * 0.1

    -- Nombre de sala
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Nombre de la Sala:", 0, contentStartY, W, "center")

    -- Input box nombre
    love.graphics.setColor(0.2, 0.2, 0.2)
    local boxW, boxH = 400, 50
    local boxX, boxY = W/2 - boxW/2, contentStartY + 35
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fonts.medium)
    local textHeight = fonts.medium:getHeight()
    love.graphics.printf(roomInput, boxX, boxY + (boxH - textHeight) / 2, boxW, "center")

    -- Modo de juego
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Modo de Juego:", 0, contentStartY + 110, W, "center")

    -- Botones de modo HORIZONTALES
    local buttonW, buttonH = 280, 90
    local buttonY = contentStartY + 150
    local spacing = 15
    local totalWidth = (#gameModes * buttonW) + ((#gameModes - 1) * spacing)
    local startX = W/2 - totalWidth/2

    for i, mode in ipairs(gameModes) do
        local buttonX = startX + (i - 1) * (buttonW + spacing)
        local selected = i == selectedMode

        -- Boton
        if selected then
            love.graphics.setColor(0.2, 0.6, 0.2, 0.9)
        else
            love.graphics.setColor(0.15, 0.15, 0.15, 0.8)
        end
        love.graphics.rectangle("fill", buttonX, buttonY, buttonW, buttonH, 10, 10)

        -- Border
        if selected then
            love.graphics.setColor(0, 1, 0)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", buttonX, buttonY, buttonW, buttonH, 10, 10)

        -- Texto centrado - solo el nombre del modo
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(fonts.medium)
        local textHeight = fonts.medium:getHeight()
        love.graphics.printf(mode.name, buttonX, buttonY + (buttonH - textHeight) / 2, buttonW, "center")
    end

    -- Instrucciones
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("[←→] Cambiar modo  |  [ENTER] Crear sala  |  [ESC] Volver", 0, H * 0.90, W, "center")
end

function RoomConfig.keypressed(key, escena)
    if key == "escape" then
        escena.volver()

    elseif key == "left" then
        selectedMode = selectedMode - 1
        if selectedMode < 1 then selectedMode = #gameModes end

    elseif key == "right" then
        selectedMode = selectedMode + 1
        if selectedMode > #gameModes then selectedMode = 1 end

    elseif key == "return" or key == "kpenter" then
        if roomInput ~= "" and not creatingRoom then
            creatingRoom = true  -- Prevenir múltiples creaciones
            -- Crear sala con configuración
            local mode = gameModes[selectedMode]
            local metadata = {
                game_mode = mode.id,
                max_players = mode.max_players
            }
            escena.navegarA("lobby_create", { room_name = roomInput, metadata = metadata })
        end

    elseif key == "backspace" then
        roomInput = roomInput:sub(1, -2)

    elseif #key == 1 then
        if key:match("[%w_]") and #roomInput < 20 then
            roomInput = roomInput .. key
        end
    end
end

function RoomConfig.mousemoved(x, y, escena)
    -- Detectar hover sobre botones de modo HORIZONTALES
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local pw, ph = W * 0.6, H * 0.75
    local panelY = H/2 - ph/2
    local contentStartY = panelY + ph * 0.1

    local buttonW, buttonH = 280, 90
    local buttonY = contentStartY + 150
    local spacing = 15
    local totalWidth = (#gameModes * buttonW) + ((#gameModes - 1) * spacing)
    local startX = W/2 - totalWidth/2

    for i = 1, #gameModes do
        local btnX = startX + (i - 1) * (buttonW + spacing)

        if x >= btnX and x <= btnX + buttonW and y >= buttonY and y <= buttonY + buttonH then
            selectedMode = i
            break
        end
    end
end

function RoomConfig.mousepressed(x, y, btn, escena)
    if btn == 1 then
        -- Verificar si clickeó en un botón de modo HORIZONTAL
        local W = love.graphics.getWidth()
        local H = love.graphics.getHeight()
        local pw, ph = W * 0.6, H * 0.75
        local panelY = H/2 - ph/2
        local contentStartY = panelY + ph * 0.1

        local buttonW, buttonH = 280, 90
        local buttonY = contentStartY + 150
        local spacing = 15
        local totalWidth = (#gameModes * buttonW) + ((#gameModes - 1) * spacing)
        local startX = W/2 - totalWidth/2

        for i = 1, #gameModes do
            local btnX = startX + (i - 1) * (buttonW + spacing)

            if x >= btnX and x <= btnX + buttonW and y >= buttonY and y <= buttonY + buttonH then
                selectedMode = i
                -- Crear sala inmediatamente al hacer click (con protección anti-doble-click)
                if roomInput ~= "" and not creatingRoom then
                    creatingRoom = true  -- Prevenir múltiples creaciones
                    local mode = gameModes[selectedMode]
                    local metadata = {
                        game_mode = mode.id,
                        max_players = mode.max_players
                    }
                    escena.navegarA("lobby_create", { room_name = roomInput, metadata = metadata })
                end
                break
            end
        end
    end
end

return RoomConfig
