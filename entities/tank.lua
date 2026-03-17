-- Control del tanque del jugador

local Tracks = require("systems.tracks")

local tanque = {}
local sprites = {}
local datos = {}
local TRACK_INTERVALO = 0.08
local escala = 0.3
local MAP_W = 1920
local MAP_H = 1080


-- FUNCION DE COLISION
local function isBlocked(nx, ny, r)

    -- límites del mapa
    if nx - r < 0 or nx + r > MAP_W or
       ny - r < 0 or ny + r > MAP_H then
        return true
    end

    -- colisión con muros
    for _, w in ipairs(Map.getWalls()) do
        if not (w.dest and w.hp <= 0) then

            local cx = math.max(w.x, math.min(nx, w.x + w.w))
            local cy = math.max(w.y, math.min(ny, w.y + w.h))

            if (nx - cx)^2 + (ny - cy)^2 < r*r then
                return true
            end
        end
    end

    -- colisión con ríos
    local pts = {{nx+r,ny},{nx-r,ny},{nx,ny+r},{nx,ny-r}}

    for _, p in ipairs(pts) do
        for _, rv in ipairs(Map.getRivers()) do

            if p[1] >= rv.x and p[1] <= rv.x+rv.w and
               p[2] >= rv.y and p[2] <= rv.y+rv.h then

                local onBridge = false

                for _, br in ipairs(Map.getBridges()) do
                    if p[1] >= br.x and p[1] <= br.x+br.w and
                       p[2] >= br.y and p[2] <= br.y+br.h then
                        onBridge = true
                        break
                    end
                end

                if not onBridge then
                    return true
                end
            end
        end
    end

    return false
end


-- CARGA DEL TANQUE
function tanque.load()

    -- cargar sprites
    sprites.tracks = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
    sprites.hull = love.graphics.newImage("assets/images/PNG/Hulls_Color_A/Hull_01.png")
    sprites.weapon = love.graphics.newImage("assets/images/PNG/Weapon_Color_A/Gun_01.png")

    -- pivotes
    sprites.tracksPivot = {
        x = sprites.tracks:getWidth()/2,
        y = sprites.tracks:getHeight()/2
    }

    sprites.hullPivot = {
        x = sprites.hull:getWidth()/2,
        y = sprites.hull:getHeight()/2
    }

    sprites.weaponPivot = {
        x = sprites.weapon:getWidth()/2,
        y = sprites.weapon:getHeight()/2
    }

    -- centrar torreta
    sprites.weaponOffset = 15

    local r = math.floor(sprites.hull:getWidth()*escala/2*0.75)

    datos = {
        x = 400,
        y = 300,
        angulo = 0,
        anguloTorreta = 0,
        velocidad = 0,
        aceleracion = 300,
        velMax = 150,
        friccion = 200,
        radio = r,
        trackTimer = 0,
        isMoving = false
    }
end

function tanque.update(dt)

    datos.isMoving = false
    local r = datos.radio
    local nx, ny = datos.x, datos.y

    -- MOVIMIENTO CON ACELERACION
    if love.keyboard.isDown("w") then
        datos.velocidad = math.min(
            datos.velocidad + datos.aceleracion * dt,
            datos.velMax
        )
    elseif love.keyboard.isDown("s") then
        datos.velocidad = math.max(
            datos.velocidad - datos.aceleracion * dt,
            -datos.velMax/2
        )
    else
        if datos.velocidad > 0 then
            datos.velocidad = math.max(datos.velocidad - datos.friccion * dt, 0)
        elseif datos.velocidad < 0 then
            datos.velocidad = math.min(datos.velocidad + datos.friccion * dt, 0)
        end
    end

    nx = nx + math.cos(datos.angulo) * datos.velocidad * dt
    ny = ny + math.sin(datos.angulo) * datos.velocidad * dt

    -- COLISIONES
    local oldx, oldy = datos.x, datos.y

    if not isBlocked(nx, ny, r) then
        datos.x, datos.y = nx, ny
    else
        if not isBlocked(nx, datos.y, r) then
            datos.x = nx
        elseif not isBlocked(datos.x, ny, r) then
            datos.y = ny
        end
    end

    datos.isMoving = (datos.x ~= oldx or datos.y ~= oldy)

    -- ROTACION
    local turnSpeed = 2

    if math.abs(datos.velocidad) > 5 then
        if love.keyboard.isDown("a") then
            datos.angulo = datos.angulo - turnSpeed * dt
        end
        if love.keyboard.isDown("d") then
            datos.angulo = datos.angulo + turnSpeed * dt
        end
    end

    -- TORRETA APUNTA AL RATON
    local mx, my = love.mouse.getPosition()
    datos.anguloTorreta = math.atan2(my - datos.y, mx - datos.x)

    -- SONIDO MOTOR
    if Audio then
        Audio.actualizarMotor(datos.isMoving)
    end

    -- HUELLAS
    if datos.isMoving then
        datos.trackTimer = datos.trackTimer + dt
        if datos.trackTimer >= TRACK_INTERVALO then
            datos.trackTimer = 0
            Tracks.spawn(datos.x, datos.y, datos.angulo)
        end
    end
end


-- DIBUJAR TANQUE
function tanque.draw()

    -- función para dibujar sprite
    local function drawSprite(img, pivot, angulo, x, y)
        love.graphics.draw(
            img, x, y, angulo,
            escala, escala,
            pivot.x, pivot.y
        )
    end

    love.graphics.setColor(1, 1, 1)

    -- orugas
    drawSprite(sprites.tracks, sprites.tracksPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    -- casco
    drawSprite(sprites.hull, sprites.hullPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    -- torreta desplazada hacia delante
    local tx = datos.x + math.cos(datos.anguloTorreta) * sprites.weaponOffset
    local ty = datos.y + math.sin(datos.anguloTorreta) * sprites.weaponOffset
    drawSprite(sprites.weapon, sprites.weaponPivot, datos.anguloTorreta + math.pi/2, tx, ty)
end


-- POSICION DEL CAÑON PARA DISPARAR
function tanque.getMuzzlePos()
    local dist = 40
    local bx = datos.x + math.cos(datos.anguloTorreta) * dist
    local by = datos.y + math.sin(datos.anguloTorreta) * dist
    return bx, by, datos.anguloTorreta
end

-- OBTENER POSICION DEL TANQUE (para multiplayer)
function tanque.getPosition()
    return datos.x, datos.y, datos.angulo
end

-- OBTENER ANGULOS (para multiplayer)
function tanque.getAngles()
    return datos.angulo, datos.anguloTorreta
end

return tanque