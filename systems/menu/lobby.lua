-- Lobby/Hub de espera multijugador
-- Muestra estado de conexion y espera a que 2 jugadores se conecten

local Base = require("systems.menu.base")
local Red = require("network")
local UI = require("systems.ui")

local Lobby = {}
local estado = "room_select" -- "room_select", "connecting", "waiting", "ready", "error"
local mensajes = {}
local playerCount = 0
local myPlayerId = nil
local myRoomId = nil
local countdown = 0
local roomInput = "room1"  -- Default room name
local cursorBlink = 0

-- Fonts locales
local fonts = {
    big = nil,
    medium = nil,
    small = nil
}

local function addMessage(msg)
    table.insert(mensajes, 1, msg)
    if #mensajes > 8 then
        table.remove(mensajes)
    end
end

function Lobby.load(escena)
    estado = "room_select"
    mensajes = {}
    playerCount = 0
    myPlayerId = nil
    myRoomId = nil
    countdown = 0
    roomInput = "room1"
    cursorBlink = 0

    -- Cargar fonts
    local H = love.graphics.getHeight()
    fonts.big = love.graphics.newFont(math.floor(H * 0.06))
    fonts.medium = love.graphics.newFont(math.floor(H * 0.04))
    fonts.small = love.graphics.newFont(math.floor(H * 0.025))

    addMessage("Escribe el nombre de la sala")
end

function Lobby.connectToRoom(room_id)
    estado = "connecting"
    myRoomId = room_id
    addMessage("Conectando a sala: " .. room_id)

    local success = Red.init("217.78.237.7", 12345)

    if success then
        Red.conectar(room_id)
        addMessage("Conexión iniciada")
        estado = "waiting"
    else
        addMessage("ERROR: No se pudo inicializar red")
        estado = "error"
    end
end

function Lobby.update(dt, escena)
    cursorBlink = cursorBlink + dt

    -- Actualizar red (sin posicion de tanque)
    if estado ~= "error" and estado ~= "room_select" then
        Red.update(dt, 0, 0, 0)

        -- Comprobar si conectamos
        if Red.esta_conectado() and myPlayerId == nil then
            myPlayerId = Red.id_jugador
            myRoomId = Red.id_sala or "default"
            addMessage("¡Conectado! ID: " .. myPlayerId)
            if Red.id_sala then
                addMessage("Sala: " .. myRoomId)
            end
            estado = "waiting"
        end

        -- Contar jugadores
        local otherPlayers = Red.obtener_otros_jugadores()
        playerCount = 1 -- nosotros
        for _ in pairs(otherPlayers) do
            playerCount = playerCount + 1
        end

        -- Si hay 2 jugadores, empezar cuenta atras
        if playerCount >= 2 and estado == "waiting" then
            estado = "ready"
            countdown = 3
            addMessage("¡2 jugadores conectados!")
            addMessage("Comenzando en 3...")
        end

        -- Cuenta atras
        if estado == "ready" then
            countdown = countdown - dt
            if countdown <= 0 then
                -- Iniciar juego multijugador
                escena.setAction("play_multiplayer")
            end
        end
    end
end

function Lobby.draw(escena)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local tiempo = escena.getTiempo()

    -- Fondo parallax
    UI.drawParallax(escena.fondos(), tiempo)

    -- Titulo
    local yT = H * 0.04 + math.sin(tiempo * 2) * 4
    UI.titleBanner(escena.tituloImg(), "SALA MULTIJUGADOR", yT, tiempo)

    -- Panel central
    love.graphics.setColor(0, 0, 0, 0.8)
    local pw, ph = W * 0.6, H * 0.6
    love.graphics.rectangle("fill", W/2 - pw/2, H/2 - ph/2, pw, ph, 10, 10)

    if estado == "room_select" then
        -- Room selection screen
        love.graphics.setFont(fonts.big)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("SELECCIONA SALA", 0, H * 0.30, W, "center")

        love.graphics.setFont(fonts.medium)
        love.graphics.printf("Nombre de la sala:", 0, H * 0.42, W, "center")

        -- Input box
        love.graphics.setColor(0.2, 0.2, 0.2)
        local boxW, boxH = 400, 60
        love.graphics.rectangle("fill", W/2 - boxW/2, H * 0.50, boxW, boxH, 5, 5)

        -- Input text
        love.graphics.setColor(1, 1, 1)
        local cursor = (cursorBlink % 1.0 < 0.5) and "|" or ""
        love.graphics.printf(roomInput .. cursor, 0, H * 0.51, W, "center")

        -- Instructions
        love.graphics.setFont(fonts.small)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.printf("Escribe el nombre y presiona ENTER", 0, H * 0.65, W, "center")
        love.graphics.printf("Salas sugeridas: room1, room2, room3", 0, H * 0.70, W, "center")
        love.graphics.printf("[ESC] Volver", 0, H * 0.90, W, "center")
        return
    end

    -- Estado
    love.graphics.setFont(fonts.big)
    local statusText = ""
    local statusColor = {1, 1, 1}

    if estado == "connecting" then
        statusText = "CONECTANDO..."
        statusColor = {1, 1, 0}
    elseif estado == "waiting" then
        statusText = "ESPERANDO JUGADORES..."
        statusColor = {0.5, 0.5, 1}
    elseif estado == "ready" then
        statusText = string.format("¡COMENZANDO EN %d!", math.ceil(countdown))
        statusColor = {0, 1, 0}
    elseif estado == "error" then
        statusText = "ERROR DE CONEXIÓN"
        statusColor = {1, 0, 0}
    end

    love.graphics.setColor(statusColor)
    love.graphics.printf(statusText, 0, H * 0.35, W, "center")

    -- Contador de jugadores
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    local playerText = string.format("Jugadores: %d / 2", playerCount)
    love.graphics.printf(playerText, 0, H * 0.45, W, "center")

    if myPlayerId then
        love.graphics.printf("Tu ID: " .. myPlayerId, 0, H * 0.50, W, "center")
    end

    if myRoomId then
        love.graphics.printf("Sala: " .. myRoomId, 0, H * 0.55, W, "center")
    end

    -- Mensajes de log
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(0.7, 0.7, 0.7)
    for i, msg in ipairs(mensajes) do
        love.graphics.printf(msg, 0, H * 0.60 + (i-1) * 20, W, "center")
    end

    -- Boton volver
    love.graphics.setFont(fonts.medium)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("[ESC] Volver al menú", 0, H * 0.90, W, "center")
end

function Lobby.keypressed(key, escena)
    if key == "escape" then
        if estado == "room_select" then
            escena.volver()
        else
            Red.desconectar()
            escena.volver()
        end
    elseif estado == "room_select" then
        if key == "return" or key == "kpenter" then
            -- Connect to room
            if roomInput ~= "" then
                Lobby.connectToRoom(roomInput)
            end
        elseif key == "backspace" then
            -- Remove last character
            roomInput = roomInput:sub(1, -2)
        elseif #key == 1 then
            -- Add character (letters, numbers only)
            if key:match("[%w]") and #roomInput < 20 then
                roomInput = roomInput .. key
            end
        end
    end
end

function Lobby.mousemoved(x, y, escena)
    -- No hacer nada
end

function Lobby.mousepressed(x, y, btn, escena)
    -- No hacer nada
end

return Lobby
