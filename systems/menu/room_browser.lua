-- Explorador de salas disponibles
-- Muestra lista de salas con filtro de búsqueda

local Base = require("systems.menu.base")
local UI = require("systems.ui")
local Red = require("network")

local RoomBrowser = {}
local searchInput = ""
local selectedRoom = 1
local scrollOffset = 0
local refreshTimer = 0
local fonts = {
    big = nil,
    medium = nil,
    small = nil,
    tiny = nil
}

local gameModeNames = {
    ["1v1"] = "1 vs 1",
    ["ffa"] = "Todos vs Todos",
    ["2v2"] = "Equipos 2v2"
}

local statusNames = {
    waiting = { text = "Esperando", color = {0, 1, 0} },
    playing = { text = "En juego", color = {1, 1, 0} },
    full = { text = "Llena", color = {1, 0, 0} }
}

function RoomBrowser.load(escena)
    searchInput = ""
    selectedRoom = 1
    scrollOffset = 0
    refreshTimer = 0

    local H = love.graphics.getHeight()
    fonts.big = love.graphics.newFont(math.floor(H * 0.06))
    fonts.medium = love.graphics.newFont(math.floor(H * 0.04))
    fonts.small = love.graphics.newFont(math.floor(H * 0.025))
    fonts.tiny = love.graphics.newFont(math.floor(H * 0.02))

    -- Inicializar red y solicitar lista
    Red.init("217.78.237.7", 12345)
    Red.solicitar_lista_salas()
end

function RoomBrowser.update(dt, escena)
    refreshTimer = refreshTimer + dt

    -- Auto-refresh cada 1 segundo (más frecuente)
    if refreshTimer >= 1.0 then
        Red.solicitar_lista_salas()
        refreshTimer = 0
    end

    -- Recibir respuestas del servidor (llamar con dt para procesar)
    if Red.udp then
        Red.recibir()
    end
end

function RoomBrowser.getFilteredRooms()
    local rooms = Red.obtener_salas()
    if searchInput == "" then
        return rooms
    end

    local filtered = {}
    local searchLower = searchInput:lower()
    for _, room in ipairs(rooms) do
        if room.room_id:lower():find(searchLower, 1, true) then
            table.insert(filtered, room)
        end
    end
    return filtered
end

function RoomBrowser.draw(escena)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local tiempo = escena.getTiempo()

    -- Fondo parallax
    UI.drawParallax(escena.fondos(), tiempo)

    -- Titulo
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4
    UI.titleBanner(escena.tituloImg(), "SALAS DISPONIBLES", yT, tiempo)

    -- Panel superior - Búsqueda
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", W * 0.1, H * 0.15, W * 0.8, H * 0.08, 10, 10)

    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Buscar:", W * 0.12, H * 0.17)

    -- Input box búsqueda
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", W * 0.22, H * 0.165, W * 0.6, H * 0.04, 5, 5)

    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(searchInput, W * 0.23, H * 0.167)

    -- Botón refrescar
    love.graphics.setFont(fonts.tiny)
    love.graphics.setColor(0.3, 0.3, 0.8, 0.8)
    love.graphics.rectangle("fill", W * 0.84, H * 0.165, W * 0.05, H * 0.04, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("🔄", W * 0.84, H * 0.172, W * 0.05, "center")

    -- Panel lista de salas
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", W * 0.1, H * 0.25, W * 0.8, H * 0.58, 10, 10)

    -- Encabezados
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("SALA", W * 0.13, H * 0.27)
    love.graphics.print("MODO", W * 0.42, H * 0.27)
    love.graphics.print("JUGADORES", W * 0.60, H * 0.27)
    love.graphics.print("ESTADO", W * 0.76, H * 0.27)

    -- Línea separadora
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(W * 0.11, H * 0.295, W * 0.89, H * 0.295)

    -- Lista de salas
    local rooms = RoomBrowser.getFilteredRooms()
    local startY = H * 0.31
    local rowHeight = H * 0.075
    local maxVisible = 6

    if #rooms == 0 then
        love.graphics.setFont(fonts.medium)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.printf("No hay salas disponibles", 0, H * 0.45, W, "center")
        love.graphics.setFont(fonts.small)
        love.graphics.printf("Crea una nueva sala o espera a que alguien cree una", 0, H * 0.50, W, "center")
    else
        for i = 1, math.min(maxVisible, #rooms) do
            local roomIndex = i + scrollOffset
            if roomIndex > #rooms then break end

            local room = rooms[roomIndex]
            local y = startY + (i - 1) * rowHeight
            local selected = roomIndex == selectedRoom

            -- Fondo de fila
            local isFull = room.status == "full"
            if selected and not isFull then
                love.graphics.setColor(0.2, 0.5, 0.7, 0.5)
                love.graphics.rectangle("fill", W * 0.11, y - 3, W * 0.78, rowHeight - 6, 5, 5)
            elseif isFull then
                love.graphics.setColor(0.3, 0.1, 0.1, 0.4)
                love.graphics.rectangle("fill", W * 0.11, y - 3, W * 0.78, rowHeight - 6, 5, 5)
            end

            -- Nombre sala
            love.graphics.setFont(fonts.medium)
            love.graphics.setColor(isFull and 0.5 or 1, isFull and 0.5 or 1, isFull and 0.5 or 1)
            local nameY = y + (rowHeight - fonts.medium:getHeight()) / 2 - 5
            love.graphics.print(room.room_id, W * 0.13, nameY)

            -- Modo
            love.graphics.setFont(fonts.small)
            local infoY = y + (rowHeight - fonts.small:getHeight()) / 2 - 3
            local modeName = gameModeNames[room.game_mode] or room.game_mode
            love.graphics.print(modeName, W * 0.42, infoY)

            -- Jugadores
            local playerText = string.format("%d / %d", room.player_count, room.max_players)
            love.graphics.print(playerText, W * 0.62, infoY)

            -- Estado
            local statusInfo = statusNames[room.status] or statusNames.waiting
            love.graphics.setColor(statusInfo.color)
            love.graphics.print(statusInfo.text, W * 0.76, infoY)
        end

        -- Indicador de scroll
        if #rooms > maxVisible then
            love.graphics.setFont(fonts.tiny)
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.printf(string.format("Mostrando %d-%d de %d",
                scrollOffset + 1,
                math.min(scrollOffset + maxVisible, #rooms),
                #rooms),
                0, H * 0.78, W, "center")
        end
    end

    -- Instrucciones
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("[↑↓] Navegar  |  [ENTER] Unirse  |  [F5] Refrescar  |  [ESC] Volver", 0, H * 0.90, W, "center")
end

function RoomBrowser.keypressed(key, escena)
    if key == "escape" then
        Red.desconectar()
        escena.volver()

    elseif key == "up" then
        local rooms = RoomBrowser.getFilteredRooms()
        if #rooms > 0 then
            selectedRoom = selectedRoom - 1
            if selectedRoom < 1 then selectedRoom = #rooms end
            -- Ajustar scroll
            if selectedRoom <= scrollOffset then
                scrollOffset = math.max(0, selectedRoom - 1)
            end
        end

    elseif key == "down" then
        local rooms = RoomBrowser.getFilteredRooms()
        if #rooms > 0 then
            selectedRoom = selectedRoom + 1
            if selectedRoom > #rooms then selectedRoom = 1 end
            -- Ajustar scroll
            if selectedRoom > scrollOffset + 6 then
                scrollOffset = selectedRoom - 6
            end
        end

    elseif key == "return" or key == "kpenter" then
        local rooms = RoomBrowser.getFilteredRooms()
        if #rooms > 0 and rooms[selectedRoom] then
            local room = rooms[selectedRoom]
            -- No unirse si está llena
            if room.status == "full" then
                return
            end
            -- Unirse a la sala seleccionada
            escena.navegarA("lobby_join", { room_name = room.room_id, game_mode = room.game_mode })
        end

    elseif key == "f5" then
        Red.solicitar_lista_salas()
        refreshTimer = 0

    elseif key == "backspace" then
        searchInput = searchInput:sub(1, -2)
        selectedRoom = 1
        scrollOffset = 0

    elseif #key == 1 then
        if key:match("[%w_]") and #searchInput < 20 then
            searchInput = searchInput .. key
            selectedRoom = 1
            scrollOffset = 0
        end
    end
end

function RoomBrowser.mousemoved(x, y, escena)
    -- Detectar hover sobre filas
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local startY = H * 0.31
    local rowHeight = H * 0.075
    local rooms = RoomBrowser.getFilteredRooms()

    for i = 1, math.min(6, #rooms) do
        local roomIndex = i + scrollOffset
        if roomIndex > #rooms then break end

        local rowY = startY + (i - 1) * rowHeight
        if x >= W * 0.11 and x <= W * 0.89 and y >= rowY - 3 and y <= rowY + rowHeight - 6 then
            selectedRoom = roomIndex
            break
        end
    end
end

function RoomBrowser.mousepressed(x, y, btn, escena)
    if btn ~= 1 then return end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Click en botón refrescar
    if x >= W * 0.84 and x <= W * 0.89 and y >= H * 0.165 and y <= H * 0.205 then
        Red.solicitar_lista_salas()
        refreshTimer = 0
        return
    end

    -- Click en fila de sala (unirse)
    local rooms = RoomBrowser.getFilteredRooms()
    if #rooms > 0 and rooms[selectedRoom] then
        local startY = H * 0.31
        local rowHeight = H * 0.075

        for i = 1, math.min(6, #rooms) do
            local roomIndex = i + scrollOffset
            if roomIndex > #rooms then break end

            local rowY = startY + (i - 1) * rowHeight
            if x >= W * 0.11 and x <= W * 0.89 and y >= rowY - 3 and y <= rowY + rowHeight - 6 then
                local room = rooms[roomIndex]
                -- No unirse si está llena
                if room.status ~= "full" then
                    escena.navegarA("lobby_join", { room_name = room.room_id, game_mode = room.game_mode })
                end
                break
            end
        end
    end
end

return RoomBrowser
