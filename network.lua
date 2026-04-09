-- red.lua
-- Cliente UDP simple para juego de tanques multijugador

local socket = require("socket")
local binary_protocol = require("binary_protocol")

local Red = {}
Red.udp = nil
Red.ip_servidor = "217.78.237.7"  -- IP del servidor Webdock
Red.puerto_servidor = 12345
Red.conectado = false
Red.id_jugador = nil
Red.id_sala = nil  -- ID de sala/lobby actual
Red.otros_jugadores = {}  -- {id_jugador: {x, y, angulo}}
Red.balas_recibidas = {}  -- Cola de balas recibidas de otros jugadores
Red.salas_disponibles = {}  -- Lista de salas del servidor
Red.tasa_envio = 0.03  -- Enviar actualizaciones cada 30ms (~33 Hz) - Antes: 0.05 (20 Hz)
Red.temporizador_envio = 0
Red.update_llamado = false  -- Bandera de debug

function Red.init(ip_servidor, puerto_servidor)
    print("[CLIENTE] Inicializando red...")

    local exito, err = pcall(function()
        Red.udp = socket.udp()
        Red.udp:settimeout(0)  -- No bloqueante
        Red.ip_servidor = ip_servidor or Red.ip_servidor
        Red.puerto_servidor = puerto_servidor or Red.puerto_servidor

        -- Fix UDP en Windows: conectar al destino para evitar errores ICMP
        Red.udp:setpeername(Red.ip_servidor, Red.puerto_servidor)
    end)

    if not exito then
        print("[ERROR] Fallo al inicializar red: " .. tostring(err))
        return false
    end

    print("[CLIENTE] Red inicializada - " .. Red.ip_servidor .. ":" .. Red.puerto_servidor)
    return true
end

function Red.conectar(id_sala, metadata)
    if not Red.udp then
        print("[ERROR] ¡Red no inicializada!")
        return false
    end

    Red.id_sala = id_sala or "default"
    local msg_data = {
        type = "connect",
        room_id = Red.id_sala
    }

    -- Agregar metadatos si se proporcionan (al crear sala)
    if metadata then
        msg_data.metadata = metadata
    end

    local msg = binary_protocol.encode(msg_data)
    print("[DEBUG] Enviando mensaje de conexión binario a sala '" .. Red.id_sala .. "'")

    -- Usar send() en vez de sendto() ya que usamos setpeername()
    local enviado, err = Red.udp:send(msg)
    print("[DEBUG] send() retornó: enviado=" .. tostring(enviado) .. ", err=" .. tostring(err))

    if not enviado then
        print("[ERROR] Fallo al enviar conexión: " .. (err or "desconocido"))
        return false
    end

    print("[CLIENTE] ¡Mensaje de conexión enviado exitosamente!")
    return true
end

function Red.desconectar()
    if Red.udp and Red.conectado then
        local msg = binary_protocol.encode({type = "disconnect"})
        Red.udp:send(msg)
        Red.conectado = false
        print("[CLIENTE] Desconectado")
    end
end

function Red.enviar_actualizacion(x, y, angulo)
    if not Red.conectado then return end

    local msg = binary_protocol.encode({
        type = "update",
        x = x,
        y = y,
        angle = angulo
    })

    -- Usar send() ya que usamos setpeername()
    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[AVISO] Error de envío: " .. err)
    end
end

function Red.enviar_bala(x, y, angulo, tipo_bala)
    if not Red.conectado then return end

    local msg = binary_protocol.encode({
        type = "bullet",
        x = x,
        y = y,
        angle = angulo,
        bullet_type = tipo_bala or "plasma"
    })

    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[AVISO] Error de envío de bala: " .. err)
    end
end

function Red.update(dt, tanque_x, tanque_y, tanque_angulo)
    if not Red.udp then return end

    -- Debug: mostrar que update está siendo llamado
    if not Red.update_llamado then
        print("[DEBUG] Red.update() está siendo llamado")
        Red.update_llamado = true
    end

    -- Enviar actualizaciones de posición a tasa fija
    Red.temporizador_envio = Red.temporizador_envio + dt
    if Red.temporizador_envio >= Red.tasa_envio then
        Red.enviar_actualizacion(tanque_x, tanque_y, tanque_angulo)
        Red.temporizador_envio = 0
    end

    -- Recibir mensajes del servidor
    Red.recibir()
end

function Red.recibir()
    if not Red.udp then
        print("[DEBUG] UDP no inicializado en recibir()")
        return
    end

    local contador_mensajes = 0
    while true do
        -- Usar receive() ya que usamos setpeername()
        local datos, err = Red.udp:receive()

        if not datos then
            if err ~= "timeout" and err then
                print("[DEBUG] Error de recepción: " .. err)
            end
            break  -- No hay más mensajes
        end

        contador_mensajes = contador_mensajes + 1
        print("[DEBUG] Mensaje binario recibido (" .. #datos .. " bytes)")

        local msg, err = binary_protocol.decode(datos)
        if msg then
            Red.manejar_mensaje(msg)
        else
            print("[ERROR] Fallo al decodificar mensaje binario: " .. tostring(err))
        end
    end

    if contador_mensajes > 0 then
        print("[DEBUG] Procesados " .. contador_mensajes .. " mensajes")
    end
end

function Red.manejar_mensaje(msg)
    local tipo_msg = msg.type
    print("[CLIENTE] Tipo de mensaje recibido: " .. tostring(tipo_msg))

    if tipo_msg == "welcome" then
        Red.id_jugador = msg.player_id
        Red.id_sala = msg.room_id or "default"
        Red.conectado = true

        if msg.room_id then
            print("[CLIENTE] *** ¡CONECTADO! ID Jugador: " .. Red.id_jugador .. " | Sala: " .. Red.id_sala .. " ***")
        else
            print("[CLIENTE] *** ¡CONECTADO! ID Jugador: " .. Red.id_jugador .. " ***")
        end

    elseif tipo_msg == "state" then
        -- Actualizar posiciones de otros jugadores
        Red.otros_jugadores = {}
        for pid, datos_j in pairs(msg.players) do
            local id_jugador = tonumber(pid)
            if id_jugador ~= Red.id_jugador then
                Red.otros_jugadores[id_jugador] = {
                    x = datos_j.x,
                    y = datos_j.y,
                    angulo = datos_j.angle
                }
            end
        end

    elseif tipo_msg == "bullet" then
        -- Bala disparada por otro jugador
        if msg.player_id ~= Red.id_jugador then
            table.insert(Red.balas_recibidas, {
                x = msg.x,
                y = msg.y,
                angulo = msg.angle,
                tipo = msg.bullet_type or "plasma"
            })
            print("[CLIENTE] Bala recibida de jugador " .. msg.player_id)
        end

    elseif tipo_msg == "rooms_list" then
        -- Lista de salas disponibles
        Red.salas_disponibles = msg.rooms or {}
        print("[CLIENTE] Recibida lista de " .. #Red.salas_disponibles .. " salas")

    else
        print("[CLIENTE] Tipo de mensaje desconocido: " .. tostring(tipo_msg))
    end
end

-- Solicitar lista de salas disponibles
function Red.solicitar_lista_salas()
    if not Red.udp then
        print("[ERROR] ¡Red no inicializada!")
        return false
    end

    local msg = binary_protocol.encode({ type = "list_rooms" })
    local enviado, err = Red.udp:send(msg)

    if not enviado and err then
        print("[AVISO] Error al solicitar lista: " .. err)
        return false
    end

    print("[CLIENTE] Solicitando lista de salas...")
    return true
end

-- Obtener lista de salas
function Red.obtener_salas()
    return Red.salas_disponibles
end

function Red.obtener_otros_jugadores()
    return Red.otros_jugadores
end

function Red.obtener_balas_recibidas()
    local balas = Red.balas_recibidas
    Red.balas_recibidas = {}  -- Limpiar cola
    return balas
end

function Red.esta_conectado()
    return Red.conectado
end

return Red
