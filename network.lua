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
Red.id_sala = nil  -- ID de la sala/lobby actual
Red.otros_jugadores = {}  -- {id_jugador: {x, y, angulo}}
Red.balas_recibidas = {}  -- Cola de balas recibidas de otros jugadores
Red.salas_disponibles = {}  -- Lista de salas del servidor
Red.tasa_envio = 0.03  -- Enviar actualizaciones cada 30ms (~33 Hz) - Antes: 0.05 (20 Hz)
Red.temporizador_envio = 0
Red.update_llamado = false  -- Bandera de depuración

-- Fase 2: Modo autoritativo
Red.use_auth = false  -- Poner a true para activar protocolo v2
Red.input_seq = 0  -- Número de secuencia de entrada para v2
Red.last_snapshot = nil  -- Último snapshot del servidor

-- Fase 3: Buffer de interpolación
Red.snapshot_buffer = {}  -- FIFO de {tick_servidor, tiempo_recepcion, tanques}, profundidad ~6
Red.buffer_max_size = 6

-- Fase 4: Eventos de balas
Red.bullet_spawn_queue = {}  -- Balas generadas por el servidor
Red.bullet_despawn_queue = {}  -- Balas eliminadas por el servidor
Red.hit_events = {}  -- Eventos de impacto del servidor
Red.death_events = {}  -- Eventos de muerte del servidor
Red.respawn_events = {}  -- Eventos de reaparición del servidor
Red.fire_seq = 0  -- Número de secuencia de disparo

Red.powerup_events = {}  -- Eventos de powerup del servidor (AUTH)
Red.map_idx = 1  -- Índice de mapa sincronizado con el servidor
Red.in_game = false  -- Activa envío de posición solo durante partida
Red.debug = false  -- Activar para logs verbosos
Red.other_profiles = {}  -- {pid = {gamertag, colors..., weapon_idx}}
Red.profile_pendiente = nil  -- Perfil propio aún por enviar tras WELCOME

function Red.init(ip_servidor, puerto_servidor)
    print("[CLIENT] Inicializando red...")

    local exito, err = pcall(function()
        Red.udp = socket.udp()
        Red.udp:settimeout(0)  -- Sin bloqueo
        Red.ip_servidor = ip_servidor or Red.ip_servidor
        Red.puerto_servidor = puerto_servidor or Red.puerto_servidor

        -- Arreglo UDP en Windows: conectar al destino para evitar errores ICMP
        Red.udp:setpeername(Red.ip_servidor, Red.puerto_servidor)
    end)

    if not exito then
        print("[ERROR] Fallo al inicializar red: " .. tostring(err))
        return false
    end

    print("[CLIENT] Red inicializada - " .. Red.ip_servidor .. ":" .. Red.puerto_servidor)
    return true
end

function Red.conectar(id_sala, metadata)
    if not Red.udp then
        print("[ERROR] Red no inicializada!")
        return false
    end

    Red.id_sala = id_sala or "default"
    local msg_data = {
        type = "connect",
        room_id = Red.id_sala
    }

    -- Añadir metadatos si se proporcionan (al crear sala)
    if metadata then
        msg_data.metadata = metadata
    end

    local msg = binary_protocol.encode(msg_data)
    print("[DEBUG] Enviando mensaje binario de conexión a sala '" .. Red.id_sala .. "'")

    -- Usar send() en vez de sendto() ya que usamos setpeername()
    local enviado, err = Red.udp:send(msg)
    print("[DEBUG] send() devolvió: enviado=" .. tostring(enviado) .. ", err=" .. tostring(err))

    if not enviado then
        print("[ERROR] Fallo al enviar conexión: " .. (err or "desconocido"))
        return false
    end

    print("[CLIENT] Mensaje de conexión enviado correctamente!")
    return true
end

function Red.desconectar()
    if Red.udp and Red.conectado then
        local msg = binary_protocol.encode({type = "disconnect"})
        Red.udp:send(msg)
    end
    Red.conectado = false
    Red.id_jugador = nil
    Red.otros_jugadores = {}
    Red.balas_recibidas = {}
    Red.snapshot_buffer = {}
    Red.last_snapshot = nil
    Red.use_auth = false
    Red.update_llamado = false
    Red.in_game = false
    Red.powerup_events = {}
    Red.other_profiles = {}
    Red.profile_pendiente = nil
    if Red.udp then
        Red.udp:close()
        Red.udp = nil
    end
    print("[CLIENT] Desconectado")
end

function Red.enviar_actualizacion(x, y, angulo, hp)
    if not Red.conectado then return end

    local msg = binary_protocol.encode({
        type = "update",
        x = x,
        y = y,
        angle = angulo,
        hp = hp or 100
    })

    -- Usar send() ya que usamos setpeername()
    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[WARNING] Error de envío: " .. err)
    end
end

-- Enviar perfil propio al servidor (se reenvía a los demás de la sala).
-- profile = {gamertag, color_body_r/g/b, color_turret_r/g/b, color_ammo_r/g/b, weapon_idx}
function Red.enviar_profile(profile)
    if not Red.udp then
        Red.profile_pendiente = profile
        return
    end
    if not Red.conectado or not Red.id_jugador then
        Red.profile_pendiente = profile
        return
    end
    local msg = binary_protocol.encode({
        type = "profile",
        player_id = Red.id_jugador,
        gamertag = profile.gamertag or "",
        color_body_r = profile.color_body_r or 1,
        color_body_g = profile.color_body_g or 1,
        color_body_b = profile.color_body_b or 1,
        color_turret_r = profile.color_turret_r or 1,
        color_turret_g = profile.color_turret_g or 1,
        color_turret_b = profile.color_turret_b or 1,
        color_ammo_r = profile.color_ammo_r or 1,
        color_ammo_g = profile.color_ammo_g or 1,
        color_ammo_b = profile.color_ammo_b or 1,
        weapon_idx = profile.weapon_idx or 1,
    })
    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[WARNING] Error de envío de perfil: " .. err)
    else
        Red.profile_pendiente = nil
    end
end

function Red.get_other_profiles()
    return Red.other_profiles
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
        print("[WARNING] Error de envío de bala: " .. err)
    end
end

-- Fase 2: Enviar entrada al servidor (protocolo v2)
function Red.enviar_input(input_bits, turret_angle, dt_ms)
    if not Red.conectado or not Red.use_auth then return end

    Red.input_seq = Red.input_seq + 1

    local msg = binary_protocol.encode({
        type = "input",
        seq = Red.input_seq,
        input_bits = input_bits,
        turret_angle = turret_angle,
        dt_ms = dt_ms
    })

    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[WARNING] Error de envío de entrada: " .. err)
    end
end

-- Fase 4: Enviar intención de disparo al servidor (protocolo v2)
function Red.enviar_fire_intent(turret_angle, weapon_idx)
    if not Red.conectado or not Red.use_auth then return end

    Red.fire_seq = Red.fire_seq + 1

    local msg = binary_protocol.encode({
        type = "fire_intent",
        seq = Red.fire_seq,
        turret_angle = turret_angle,
        weapon_idx = weapon_idx
    })

    local enviado, err = Red.udp:send(msg)
    if not enviado and err then
        print("[WARNING] Error de envío de intención de disparo: " .. err)
    end
end

function Red.update(dt, tanque_x, tanque_y, tanque_angulo, tanque_hp)
    if not Red.udp then return end

    -- Depuración: mostrar que se está llamando al update
    if not Red.update_llamado then
        print("[DEBUG] Red.update() está siendo llamado")
        Red.update_llamado = true
    end

    -- Enviar actualizaciones de posición a frecuencia fija (solo en partida)
    if Red.in_game then
        Red.temporizador_envio = Red.temporizador_envio + dt
        if Red.temporizador_envio >= Red.tasa_envio then
            Red.enviar_actualizacion(tanque_x, tanque_y, tanque_angulo, tanque_hp)
            Red.temporizador_envio = 0
        end
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
        if Red.debug then print("[DEBUG] Mensaje binario recibido (" .. #datos .. " bytes)") end

        local msg, err = binary_protocol.decode(datos)
        if msg then
            Red.manejar_mensaje(msg)
        else
            print("[ERROR] Fallo al decodificar mensaje binario: " .. tostring(err))
        end
    end

    if Red.debug and contador_mensajes > 0 then
        print("[DEBUG] Procesados " .. contador_mensajes .. " mensajes")
    end
end

function Red.manejar_mensaje(msg)
    local tipo_msg = msg.type
    if Red.debug then print("[CLIENT] Tipo de mensaje recibido: " .. tostring(tipo_msg)) end

    if tipo_msg == "welcome" then
        Red.id_jugador = msg.player_id
        Red.id_sala = msg.room_id or "default"
        Red.map_idx = msg.map_idx or 1
        Red.conectado = true

        if msg.room_id then
            print("[CLIENT] *** CONECTADO! ID Jugador: " .. Red.id_jugador .. " | Sala: " .. Red.id_sala .. " | Mapa: " .. Red.map_idx .. " ***")
        else
            print("[CLIENT] *** CONECTADO! ID Jugador: " .. Red.id_jugador .. " ***")
        end

        -- Enviar perfil pendiente ahora que tenemos id_jugador
        if Red.profile_pendiente then
            Red.enviar_profile(Red.profile_pendiente)
        end

    elseif tipo_msg == "profile" then
        if msg.player_id and msg.player_id ~= Red.id_jugador then
            Red.other_profiles[msg.player_id] = {
                gamertag = msg.gamertag,
                color_body_r = msg.color_body_r, color_body_g = msg.color_body_g, color_body_b = msg.color_body_b,
                color_turret_r = msg.color_turret_r, color_turret_g = msg.color_turret_g, color_turret_b = msg.color_turret_b,
                color_ammo_r = msg.color_ammo_r, color_ammo_g = msg.color_ammo_g, color_ammo_b = msg.color_ammo_b,
                weapon_idx = msg.weapon_idx,
            }
            if Red.debug then
                print("[CLIENT] Perfil recibido pid=" .. msg.player_id .. " gamertag='" .. (msg.gamertag or "") .. "'")
            end
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
                    angulo = datos_j.angle,
                    hp = datos_j.hp or 100
                }
            end
        end

    elseif tipo_msg == "snapshot" then
        -- B8: Activar modo auth automáticamente al recibir snapshot (servidor en AUTH)
        if not Red.use_auth then
            Red.use_auth = true
            print("[CLIENTE] Activando modo AUTH automáticamente (servidor envió snapshot)")
        end

        -- Fase 2: Snapshot del servidor (protocolo v2)
        Red.last_snapshot = msg

        -- Fase 3: Añadir al buffer de interpolación
        local snapshot_entry = {
            server_tick = msg.server_tick,
            recv_time = socket.gettime(),
            tanks = msg.tanks
        }

        table.insert(Red.snapshot_buffer, snapshot_entry)

        -- Mantener tamaño de buffer limitado (FIFO)
        while #Red.snapshot_buffer > Red.buffer_max_size do
            table.remove(Red.snapshot_buffer, 1)
        end

        -- Fix 1.1: Mirror snapshot tanks into otros_jugadores so lobby + game_multiplayer work in AUTH mode
        Red.otros_jugadores = {}
        for _, tank in ipairs(msg.tanks) do
            if tank.pid ~= Red.id_jugador then
                Red.otros_jugadores[tank.pid] = {
                    x = tank.x,
                    y = tank.y,
                    angulo = tank.angle,
                    hp = tank.hp
                }
            end
        end

        if Red.debug then print("[CLIENTE] Snapshot tick=" .. msg.server_tick .. " con " .. #msg.tanks .. " tanques (buffer=" .. #Red.snapshot_buffer .. ")") end

    elseif tipo_msg == "powerup_collected" then
        table.insert(Red.powerup_events, {
            kind = "collected",
            index = msg.powerup_index,
            player_id = msg.player_id,
            powerup_type = msg.powerup_type
        })

    elseif tipo_msg == "powerup_spawn" then
        table.insert(Red.powerup_events, {
            kind = "spawn",
            index = msg.powerup_index
        })

    elseif tipo_msg == "bullet_spawn" then
        -- Fase 4: El servidor generó una bala
        table.insert(Red.bullet_spawn_queue, {
            bullet_id = msg.bullet_id,
            owner_pid = msg.owner_pid,
            x = msg.x,
            y = msg.y,
            angle = msg.angle,
            weapon_idx = msg.weapon_idx
        })
        if Red.debug then print("[CLIENTE] Bala generada: id=" .. msg.bullet_id) end

    elseif tipo_msg == "bullet_despawn" then
        -- Fase 4: El servidor eliminó una bala
        table.insert(Red.bullet_despawn_queue, {
            bullet_id = msg.bullet_id,
            reason = msg.reason
        })

    elseif tipo_msg == "hit" then
        -- Fase 4: Bala impactó a un tanque
        table.insert(Red.hit_events, {
            bullet_id = msg.bullet_id,
            victim_pid = msg.victim_pid,
            damage = msg.damage,
            new_hp = msg.new_hp
        })
        if Red.debug then print("[CLIENTE] Impacto: víctima=" .. msg.victim_pid .. " daño=" .. msg.damage .. " hp=" .. msg.new_hp) end

    elseif tipo_msg == "death" then
        -- Fase 4: Tanque murió
        table.insert(Red.death_events, {
            victim_pid = msg.victim_pid
        })
        if Red.debug then print("[CLIENTE] Muerte: pid=" .. msg.victim_pid) end

    elseif tipo_msg == "respawn" then
        -- Fase 4: Tanque reapareció
        table.insert(Red.respawn_events, {
            pid = msg.pid,
            x = msg.x,
            y = msg.y
        })
        if Red.debug then print("[CLIENTE] Reaparición: pid=" .. msg.pid) end

    elseif tipo_msg == "bullet" then
        -- Bala disparada por otro jugador
        if msg.player_id ~= Red.id_jugador then
            table.insert(Red.balas_recibidas, {
                x = msg.x,
                y = msg.y,
                angulo = msg.angle,
                tipo = msg.bullet_type or "plasma"
            })
            if Red.debug then print("[CLIENT] Bala recibida del jugador " .. msg.player_id) end
        end

    elseif tipo_msg == "rooms_list" then
        -- Lista de salas disponibles
        Red.salas_disponibles = msg.rooms or {}
        print("[CLIENTE] Recibida lista de " .. #Red.salas_disponibles .. " salas")

    else
        print("[CLIENT] Tipo de mensaje desconocido: " .. tostring(tipo_msg))
    end
end

-- Solicitar lista de salas disponibles
function Red.solicitar_lista_salas()
    if not Red.udp then
        print("[ERROR] Red no inicializada!")
        return false
    end

    local msg = binary_protocol.encode({ type = "list_rooms" })
    local enviado, err = Red.udp:send(msg)

    if not enviado and err then
        print("[WARNING] Error al solicitar lista: " .. err)
        return false
    end

    print("[CLIENT] Solicitando lista de salas...")
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

-- Fase 2: Obtener tanque del snapshot por ID de jugador
function Red.get_tank_from_snapshot(pid)
    if not Red.last_snapshot or not Red.last_snapshot.tanks then
        return nil
    end

    for _, tank in ipairs(Red.last_snapshot.tanks) do
        if tank.pid == pid then
            return tank
        end
    end

    return nil
end

-- Fase 4: Obtener y limpiar colas de eventos de balas
function Red.get_bullet_spawns()
    local events = Red.bullet_spawn_queue
    Red.bullet_spawn_queue = {}
    return events
end

function Red.get_bullet_despawns()
    local events = Red.bullet_despawn_queue
    Red.bullet_despawn_queue = {}
    return events
end

function Red.get_hit_events()
    local events = Red.hit_events
    Red.hit_events = {}
    return events
end

function Red.get_death_events()
    local events = Red.death_events
    Red.death_events = {}
    return events
end

function Red.get_respawn_events()
    local events = Red.respawn_events
    Red.respawn_events = {}
    return events
end

-- Fase 3: Muestrear posiciones interpoladas del buffer
-- Devuelve {[pid] = {x, y, angulo, torreta, hp, isDead, invuln}} o nil
function Red.sample(now, render_delay)
    render_delay = render_delay or 0.1

    if #Red.snapshot_buffer < 2 then
        -- No hay suficientes snapshots, usar el más reciente si existe
        if #Red.snapshot_buffer == 1 then
            local snap = Red.snapshot_buffer[1]
            local result = {}
            for _, tank in ipairs(snap.tanks) do
                result[tank.pid] = {
                    x = tank.x,
                    y = tank.y,
                    angle = tank.angle,
                    turret = tank.turret,
                    hp = tank.hp,
                    isDead = tank.isDead,
                    invuln = tank.invuln
                }
            end
            return result
        end
        return nil
    end

    -- Tiempo objetivo = ahora - retardo de renderizado
    local target_time = now - render_delay

    -- Encontrar dos snapshots que encuadren el tiempo objetivo
    local snap_before = nil
    local snap_after = nil

    for i = 1, #Red.snapshot_buffer do
        local snap = Red.snapshot_buffer[i]
        if snap.recv_time <= target_time then
            snap_before = snap
        elseif snap.recv_time > target_time and not snap_after then
            snap_after = snap
            break
        end
    end

    -- Si no tenemos ambos, usar el más cercano disponible
    if not snap_before and snap_after then
        snap_before = snap_after
    elseif not snap_after and snap_before then
        snap_after = snap_before
    elseif not snap_before and not snap_after then
        -- Usar el más reciente
        local latest = Red.snapshot_buffer[#Red.snapshot_buffer]
        snap_before = latest
        snap_after = latest
    end

    -- Calcular factor de interpolación
    local alpha = 0
    if snap_before ~= snap_after then
        local time_diff = snap_after.recv_time - snap_before.recv_time
        if time_diff > 0 then
            alpha = (target_time - snap_before.recv_time) / time_diff
            alpha = math.max(0, math.min(1, alpha))
        end
    end

    -- Interpolar posiciones de tanques
    local result = {}

    -- Construir tabla de búsqueda para tanques del snapshot posterior
    local after_tanks = {}
    for _, tank in ipairs(snap_after.tanks) do
        after_tanks[tank.pid] = tank
    end

    -- Interpolar cada tanque
    for _, tank_before in ipairs(snap_before.tanks) do
        local tank_after = after_tanks[tank_before.pid]

        if tank_after then
            -- Interpolar posición
            local x = tank_before.x + (tank_after.x - tank_before.x) * alpha
            local y = tank_before.y + (tank_after.y - tank_before.y) * alpha

            -- Interpolar ángulos (camino más corto)
            local function lerp_angle(a1, a2, t)
                local diff = a2 - a1
                while diff > math.pi do diff = diff - 2 * math.pi end
                while diff < -math.pi do diff = diff + 2 * math.pi end
                return a1 + diff * t
            end

            local angle = lerp_angle(tank_before.angle, tank_after.angle, alpha)
            local turret = lerp_angle(tank_before.turret, tank_after.turret, alpha)

            -- Usar estado más reciente para valores discretos
            result[tank_before.pid] = {
                x = x,
                y = y,
                angle = angle,
                turret = turret,
                hp = tank_after.hp,
                isDead = tank_after.isDead,
                invuln = tank_after.invuln
            }
        else
            -- Tanque no en snapshot posterior, usar datos anteriores
            result[tank_before.pid] = {
                x = tank_before.x,
                y = tank_before.y,
                angle = tank_before.angle,
                turret = tank_before.turret,
                hp = tank_before.hp,
                isDead = tank_before.isDead,
                invuln = tank_before.invuln
            }
        end
    end

    return result
end

function Red.get_powerup_events()
    local e = Red.powerup_events
    Red.powerup_events = {}
    return e
end

return Red
