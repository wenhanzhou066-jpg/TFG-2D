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
local roomInput = "room1"  -- Nombre de sala por defecto
local mode = "join" -- "create" o "join"
local leaveButtonHover = false
local startButtonHover = false
local gameMode = nil -- "1v1", "ffa", "2v2"
local myTeam = 1 -- Para 2v2: 1 o 2
local teamButtonHover = {false, false}
local isHost = false -- Jugador que creó la sala
local connectionTimeout = 0 -- Temporizador de timeout de conexión
local CONNECTION_TIMEOUT_SECONDS = 10 -- 10 segundos para conectar


local function addMessage(msg)
    table.insert(mensajes, 1, msg)
    if #mensajes > 8 then
        table.remove(mensajes)
    end
end

function Lobby.load(escena, lobbyMode, params)
    estado = "connecting"
    mensajes = {}
    playerCount = 0
    myPlayerId = nil
    myRoomId = nil
    countdown = 0
    leaveButtonHover = false
    startButtonHover = false
    teamButtonHover = {false, false}
    myTeam = 1
    mode = lobbyMode or "join" -- "create" o "join"
    params = params or {}
    gameMode = nil
    isHost = (mode == "create") -- El creador es el anfitrión
    connectionTimeout = 0

    UI.loadFonts()

    -- Conectar directamente con los parámetros recibidos
    if mode == "create" and params.room_name and params.metadata then
        roomInput = params.room_name
        myRoomId = params.room_name
        gameMode = params.metadata.game_mode
        params.metadata.map_idx = love.math.random(1, 3)

        local success = Red.init("217.78.237.7", 12345)
        if success then
            Red.conectar(params.room_name, params.metadata)
            addMessage("Creando sala '" .. params.room_name .. "'...")
            addMessage("Modo: " .. gameMode)
            -- estado permanece "connecting" hasta recibir bienvenida del servidor
        else
            addMessage("ERROR: No se pudo inicializar red")
            estado = "error"
        end

    elseif mode == "join" and params.room_name then
        roomInput = params.room_name
        myRoomId = params.room_name
        gameMode = params.game_mode or "ffa" -- Obtener desde metadatos de la sala

        local success = Red.init("217.78.237.7", 12345)
        if success then
            Red.conectar(params.room_name)
            addMessage("Uniéndose a sala '" .. params.room_name .. "'...")
            -- estado permanece "connecting" hasta recibir bienvenida del servidor
        else
            addMessage("ERROR: No se pudo inicializar red")
            estado = "error"
        end
    else
        addMessage("ERROR: Parámetros inválidos")
        estado = "error"
    end
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
    -- Actualizar red (sin posicion de tanque)
    if estado ~= "error" and estado ~= "room_select" then
        Red.update(dt, 0, 0, 0)

        -- Verificar timeout de conexión
        if estado == "connecting" then
            connectionTimeout = connectionTimeout + dt
            if connectionTimeout > CONNECTION_TIMEOUT_SECONDS then
                addMessage("ERROR: Tiempo de conexión agotado")
                addMessage("El servidor no responde en 217.78.237.7:12345")
                addMessage("Verifica que el servidor esté corriendo")
                Red.desconectar()
                estado = "error"
            end
        end

        -- Comprobar si conectamos
        if Red.esta_conectado() and myPlayerId == nil then
            myPlayerId = Red.id_jugador
            myRoomId = Red.id_sala or "default"
            estado = "waiting"
            Red.in_game = true  -- trigger position sends so server broadcasts state to all clients
            addMessage("¡Conectado exitosamente!")
            addMessage("Tu ID de jugador: " .. myPlayerId)
        end

        -- Contar jugadores
        local otherPlayers = Red.obtener_otros_jugadores()
        playerCount = 1 -- nosotros
        for _ in pairs(otherPlayers) do
            playerCount = playerCount + 1
        end

        -- Auto-iniciar cuando haya suficientes jugadores (igual umbral que el botón START del host)
        local minPlayers = (gameMode == "1v1" and 2) or (gameMode == "2v2" and 4) or 2
        if playerCount >= minPlayers and estado == "waiting" then
            estado = "ready"
            countdown = 3
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
    local pw, ph = W * 0.7, H * 0.75
    local panelX = W/2 - pw/2
    local panelY = H/2 - ph/2
    love.graphics.rectangle("fill", panelX, panelY, pw, ph, 10, 10)

    if false then  -- room_select eliminado
        -- Pantalla de selección de sala
        love.graphics.setFont(UI.font("title"))
        love.graphics.setColor(1, 1, 1)
        local titleText = mode == "create" and "CREAR SALA" or "UNIRSE A SALA"
        love.graphics.printf(titleText, 0, H * 0.30, W, "center")

        love.graphics.setFont(UI.font("button"))
        love.graphics.printf("Nombre de la sala:", 0, H * 0.42, W, "center")

        -- Caja de entrada
        love.graphics.setColor(0.2, 0.2, 0.2)
        local boxW, boxH = 400, 60
        love.graphics.rectangle("fill", W/2 - boxW/2, H * 0.50, boxW, boxH, 5, 5)

        -- Texto de entrada
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(roomInput, 0, H * 0.51, W, "center")

        -- Instrucciones
        love.graphics.setFont(UI.font("small"))
        love.graphics.setColor(0.7, 0.7, 0.7)
        if mode == "create" then
            love.graphics.printf("Presiona ENTER para crear la sala", 0, H * 0.65, W, "center")
            love.graphics.printf("Los jugadores podrán unirse usando este nombre", 0, H * 0.70, W, "center")
        else
            love.graphics.printf("Escribe el nombre y presiona ENTER", 0, H * 0.65, W, "center")
            love.graphics.printf("Salas sugeridas: room1, room2, room3", 0, H * 0.70, W, "center")
        end
        love.graphics.printf("[ESC] Volver", 0, H * 0.90, W, "center")
        return
    end

    -- Estado
    love.graphics.setFont(UI.font("title"))
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

    -- Panel de lista de jugadores (lado derecho) — calculado primero para saber cuánto espacio queda
    local listPanelW = W * 0.22
    local listPanelH = ph * 0.8
    local listPanelX = panelX + pw - listPanelW - 20
    local listPanelY = panelY + 20

    -- Columna izquierda: desde el inicio del panel hasta el panel de lista
    local leftColX = panelX
    local leftColW = listPanelX - panelX - 20

    -- Calcular posiciones de contenido relativas al panel
    local contentY = panelY + ph * 0.15

    love.graphics.setColor(statusColor)
    love.graphics.printf(statusText, leftColX, contentY, leftColW, "center")

    -- ID del jugador
    if myPlayerId then
        love.graphics.setFont(UI.font("button"))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("ID: " .. myPlayerId, leftColX, contentY + 70, leftColW, "center")
    end

    -- Modo de juego
    local modeNames = { ["1v1"] = "1 vs 1", ["ffa"] = "Todos vs Todos", ["2v2"] = "2v2" }
    if gameMode then
        love.graphics.setFont(UI.font("button"))
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("Modo: " .. (modeNames[gameMode] or gameMode), leftColX, contentY + 120, leftColW, "center")
    end

    -- Selección de equipo para 2v2
    if gameMode == "2v2" and myPlayerId then
        love.graphics.setFont(UI.font("button"))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("Selecciona tu equipo:", leftColX, contentY + 170, leftColW, "center")

        local buttonW, buttonH = 160, 60
        local spacing = 20
        local centerX = leftColX + leftColW / 2
        local team1X = centerX - buttonW - spacing/2
        local team2X = centerX + spacing/2
        local buttonY = contentY + 215

        -- Botón Equipo 1
        if teamButtonHover[1] or myTeam == 1 then
            love.graphics.setColor(0.2, 0.6, 0.9, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        love.graphics.rectangle("fill", team1X, buttonY, buttonW, buttonH, 10, 10)

        if myTeam == 1 then
            love.graphics.setColor(0, 0.8, 1)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", team1X, buttonY, buttonW, buttonH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.font("button"))
        local textHeight = UI.font("button"):getHeight()
        love.graphics.printf("EQUIPO 1", team1X, buttonY + (buttonH - textHeight) / 2, buttonW, "center")

        -- Botón Equipo 2
        if teamButtonHover[2] or myTeam == 2 then
            love.graphics.setColor(0.9, 0.2, 0.2, 0.9)
        else
            love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        end
        love.graphics.rectangle("fill", team2X, buttonY, buttonW, buttonH, 10, 10)

        if myTeam == 2 then
            love.graphics.setColor(1, 0.2, 0.2)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", team2X, buttonY, buttonW, buttonH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.font("button"))
        love.graphics.printf("EQUIPO 2", team2X, buttonY + (buttonH - textHeight) / 2, buttonW, "center")
    end

    -- Contador de jugadores
    local infoStartY = gameMode == "2v2" and contentY + 295 or contentY + 180
    love.graphics.setFont(UI.font("button"))
    love.graphics.setColor(1, 1, 1)
    local maxPlayers = (gameMode == "1v1" and 2) or (gameMode == "2v2" and 4) or 8
    local playerText = string.format("Jugadores: %d / %d", playerCount, maxPlayers)
    love.graphics.printf(playerText, leftColX, infoStartY, leftColW, "center")

    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", listPanelX, listPanelY, listPanelW, listPanelH, 8, 8)

    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", listPanelX, listPanelY, listPanelW, listPanelH, 8, 8)

    -- Título
    love.graphics.setFont(UI.font("button"))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("JUGADORES", listPanelX, listPanelY + 15, listPanelW, "center")

    -- Línea separadora
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(listPanelX + 15, listPanelY + 50, listPanelX + listPanelW - 15, listPanelY + 50)

    -- Lista de jugadores
    love.graphics.setFont(UI.font("small"))
    local playerListY = listPanelY + 60
    local lineHeight = 35

    -- Agregar jugador local
    if myPlayerId then
        love.graphics.setColor(0.2, 0.8, 0.2, 0.3)
        love.graphics.rectangle("fill", listPanelX + 10, playerListY - 5, listPanelW - 20, lineHeight, 5, 5)

        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.print("ID: " .. myPlayerId, listPanelX + 20, playerListY)
        love.graphics.setFont(UI.font("small"))
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("(Tú)", listPanelX + 20, playerListY + 16)

        playerListY = playerListY + lineHeight
    end

    -- Agregar otros jugadores
    local otherPlayers = Red.obtener_otros_jugadores()
    for pid, pdata in pairs(otherPlayers) do
        love.graphics.setFont(UI.font("small"))
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print("ID: " .. pid, listPanelX + 20, playerListY)

        playerListY = playerListY + lineHeight
    end

    -- Mostrar "Esperando..." si no hay suficientes jugadores
    if playerCount < maxPlayers then
        for i = playerCount + 1, math.min(maxPlayers, playerCount + 3) do
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.setFont(UI.font("small"))
            love.graphics.print("...", listPanelX + 20, playerListY)
            playerListY = playerListY + lineHeight
        end
    end

    -- Mensajes de error
    if estado == "error" then
        love.graphics.setFont(UI.font("small"))
        love.graphics.setColor(1, 0.3, 0.3)
        for i, msg in ipairs(mensajes) do
            love.graphics.printf(msg, leftColX, infoStartY + 40 + (i-1) * 18, leftColW, "center")
        end
    end

    -- Botones inferiores
    love.graphics.setFont(UI.font("button"))
    local buttonW, buttonH = 250, 60
    local buttonSpacing = 30

    -- Anfitrión: Mostrar botón Iniciar Juego
    local minPlayers = (gameMode == "1v1" and 2) or (gameMode == "2v2" and 4) or 2  -- FFA min 2
    if isHost and estado == "waiting" and playerCount >= minPlayers then
        local startButtonX = W/2 - buttonW - buttonSpacing/2
        local startButtonY = H * 0.83

        -- Botón Iniciar
        if startButtonHover then
            love.graphics.setColor(0.2, 0.8, 0.2, 0.9)
        else
            love.graphics.setColor(0.1, 0.6, 0.1, 0.8)
        end
        love.graphics.rectangle("fill", startButtonX, startButtonY, buttonW, buttonH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", startButtonX, startButtonY, buttonW, buttonH, 10, 10)
        local textHeight = UI.font("button"):getHeight()
        local startText = "START GAME"
        if gameMode == "ffa" then
            startText = startText .. string.format(" (%d+)", minPlayers)  -- "START GAME (2+)"
        end
        love.graphics.printf(startText, startButtonX, startButtonY + (buttonH - textHeight)/2, buttonW, "center")

        -- Botón Salir (lado derecho)
        local leaveButtonX = W/2 + buttonSpacing/2
        if leaveButtonHover then
            love.graphics.setColor(0.8, 0.2, 0.2, 0.9)
        else
            love.graphics.setColor(0.6, 0.1, 0.1, 0.8)
        end
        love.graphics.rectangle("fill", leaveButtonX, startButtonY, buttonW, buttonH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", leaveButtonX, startButtonY, buttonW, buttonH, 10, 10)
        love.graphics.printf("LEAVE", leaveButtonX, startButtonY + (buttonH - textHeight)/2, buttonW, "center")
    else
        -- No anfitrión o no hay suficientes jugadores: Solo mostrar botón salir centrado
        local leaveButtonX = W/2 - buttonW/2
        local leaveButtonY = H * 0.83

        if leaveButtonHover then
            love.graphics.setColor(0.8, 0.2, 0.2, 0.9)
        else
            love.graphics.setColor(0.6, 0.1, 0.1, 0.8)
        end
        love.graphics.rectangle("fill", leaveButtonX, leaveButtonY, buttonW, buttonH, 10, 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", leaveButtonX, leaveButtonY, buttonW, buttonH, 10, 10)
        local textHeight = UI.font("button"):getHeight()
        love.graphics.printf("LEAVE ROOM", leaveButtonX, leaveButtonY + (buttonH - textHeight)/2, buttonW, "center")
    end

    -- Indicación ESC
    love.graphics.setFont(UI.font("small"))
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.printf("[ESC] Back to menu", 0, H * 0.93, W, "center")
end

function Lobby.keypressed(key, escena)
    if key == "escape" then
        if false then  -- room_select removed
            escena.volver()
        else
            Red.desconectar()
            escena.volver()
        end
    elseif estado == "room_select" then
        if key == "return" or key == "kpenter" then
            -- Conectar a la sala
            if roomInput ~= "" then
                Lobby.connectToRoom(roomInput)
            end
        elseif key == "backspace" then
            -- Eliminar último carácter
            roomInput = roomInput:sub(1, -2)
        elseif #key == 1 then
            -- Agregar carácter (solo letras y números)
            if key:match("[%w]") and #roomInput < 20 then
                roomInput = roomInput .. key
            end
        end
    end
end

function Lobby.mousemoved(x, y, escena)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Verificar hover de botones de equipo (para 2v2)
    if gameMode == "2v2" and myPlayerId then
        local pw, ph = W * 0.7, H * 0.75
        local panelX = W/2 - pw/2
        local panelY = H/2 - ph/2
        local contentY = panelY + ph * 0.15
        local listPanelW = W * 0.22
        local listPanelX = panelX + pw - listPanelW - 20
        local leftColX = panelX
        local leftColW = listPanelX - panelX - 20
        local centerX = leftColX + leftColW / 2

        local buttonW, buttonH = 160, 60
        local spacing = 20
        local team1X = centerX - buttonW - spacing/2
        local team2X = centerX + spacing/2
        local buttonY = contentY + 215

        teamButtonHover[1] = x >= team1X and x <= team1X + buttonW and
                             y >= buttonY and y <= buttonY + buttonH

        teamButtonHover[2] = x >= team2X and x <= team2X + buttonW and
                             y >= buttonY and y <= buttonY + buttonH
    end

    -- Verificar hover de botones inferiores
    local buttonW, buttonH = 250, 60
    local buttonY = H * 0.83
    local buttonSpacing = 30

    local minPlayers = (gameMode == "1v1" and 2) or (gameMode == "2v2" and 4) or 2
    if isHost and estado == "waiting" and playerCount >= minPlayers then
        -- Botón Iniciar (izquierda)
        local startButtonX = W/2 - buttonW - buttonSpacing/2
        startButtonHover = x >= startButtonX and x <= startButtonX + buttonW and
                          y >= buttonY and y <= buttonY + buttonH

        -- Botón Salir (derecha)
        local leaveButtonX = W/2 + buttonSpacing/2
        leaveButtonHover = x >= leaveButtonX and x <= leaveButtonX + buttonW and
                          y >= buttonY and y <= buttonY + buttonH
    else
        -- Solo botón salir (centrado)
        startButtonHover = false
        local leaveButtonX = W/2 - buttonW/2
        leaveButtonHover = x >= leaveButtonX and x <= leaveButtonX + buttonW and
                          y >= buttonY and y <= buttonY + buttonH
    end
end

function Lobby.mousepressed(x, y, btn, escena)
    if btn ~= 1 then return end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Verificar clics en botones de equipo (para 2v2)
    if gameMode == "2v2" and myPlayerId and estado == "waiting" then
        local pw, ph = W * 0.7, H * 0.75
        local panelX = W/2 - pw/2
        local panelY = H/2 - ph/2
        local contentY = panelY + ph * 0.15
        local listPanelW = W * 0.22
        local listPanelX = panelX + pw - listPanelW - 20
        local leftColX = panelX
        local leftColW = listPanelX - panelX - 20
        local centerX = leftColX + leftColW / 2

        local buttonW, buttonH = 160, 60
        local spacing = 20
        local team1X = centerX - buttonW - spacing/2
        local team2X = centerX + spacing/2
        local buttonY = contentY + 215

        if x >= team1X and x <= team1X + buttonW and y >= buttonY and y <= buttonY + buttonH then
            myTeam = 1
            return
        end

        if x >= team2X and x <= team2X + buttonW and y >= buttonY and y <= buttonY + buttonH then
            myTeam = 2
            return
        end
    end

    -- Verificar botón iniciar juego (solo anfitrión)
    local minPlayers = (gameMode == "1v1" and 2) or (gameMode == "2v2" and 4) or 2  -- FFA min 2
    if isHost and startButtonHover and estado == "waiting" and playerCount >= minPlayers then
        -- Forzar inicio del juego
        estado = "ready"
        countdown = 0
        escena.setAction("play_multiplayer")
        return
    end

    -- Verificar si se hizo clic en botón salir
    if leaveButtonHover then
        Red.desconectar()
        escena.volver()
    end
end

return Lobby