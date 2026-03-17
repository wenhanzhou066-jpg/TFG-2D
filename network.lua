-- red.lua
-- Cliente UDP simple para juego de tanques multijugador

local socket = require("socket")
local json = require("systems.json")

local Red = {}
Red.udp = nil
Red.ip_servidor = "217.78.237.7"  -- IP del servidor Webdock
Red.puerto_servidor = 12345
Red.conectado = false
Red.id_jugador = nil
Red.id_sala = nil  -- ID de sala/lobby actual
Red.otros_jugadores = {}  -- {id_jugador: {x, y, angulo}}
Red.tasa_envio = 0.05  -- Enviar actualizaciones cada 50ms
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

function Red.conectar(id_sala)
    if not Red.udp then
        print("[ERROR] ¡Red no inicializada!")
        return false
    end

    Red.id_sala = id_sala or "default"
    local msg = json.encode({
        type = "connect",
        room_id = Red.id_sala
    })
    print("[DEBUG] Enviando mensaje de conexión a sala '" .. Red.id_sala .. "': " .. msg)

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
        local msg = json.encode({type = "disconnect"})
        Red.udp:send(msg)
        Red.conectado = false
        print("[CLIENTE] Desconectado")
    end
end

function Red.enviar_actualizacion(x, y, angulo)
    if not Red.conectado then return end

    local msg = json.encode({
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
        print("[DEBUG] Datos recibidos: " .. datos)

        local exito, msg = pcall(json.decode, datos)
        if exito then
            Red.manejar_mensaje(msg)
        else
            print("[ERROR] Fallo al decodificar JSON: " .. datos)
            print("[ERROR] Error de decodificación: " .. tostring(msg))
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
    else
        print("[CLIENTE] Tipo de mensaje desconocido: " .. tostring(tipo_msg))
    end
end

function Red.obtener_otros_jugadores()
    return Red.otros_jugadores
end

function Red.esta_conectado()
    return Red.conectado
end

return Red
