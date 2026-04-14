-- Control del tanque del jugador

local Tracks = require("systems.tracks")

local tanque = {}
local sprites = {}
local datos = {}
local escala = 0.3
local TRACK_INTERVALO = 0.08 -- tiempo entre huellas
local VIDA_MAX = 5
local vida = VIDA_MAX
local timerInvulnerable = 0
local TIEMPO_INVULNERABLE = 0.8  -- segundos de invulnerabilidad tras recibir daño

-- colision del tanque con el mapa
local function isBlocked(nx, ny, r)
    local ms = Map and Map.getSize and Map.getSize()
    local MW = ms and ms.w or 1920
    local MH = ms and ms.h or 1080
    if nx - r < 0 or nx + r > MW or
       ny - r < 0 or ny + r > MH then
        return true
    end
    for _, w in ipairs(Map.getWalls()) do
        if not (w.dest and w.hp <= 0) then
            local cx = math.max(w.x, math.min(nx, w.x + w.w))
            local cy = math.max(w.y, math.min(ny, w.y + w.h))
            if (nx - cx)^2 + (ny - cy)^2 < r*r then
                return true
            end
        end
    end
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
                if not onBridge then return true end
            end
        end
    end
    return false
end

function tanque.load(sx, sy)
    sprites.tracks = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
    sprites.hull   = love.graphics.newImage("assets/images/PNG/Hulls_Color_A/Hull_01.png")
    sprites.weapon = love.graphics.newImage("assets/images/PNG/Weapon_Color_A/Gun_01.png")

    sprites.tracksPivot = { x = sprites.tracks:getWidth()/2, y = sprites.tracks:getHeight()/2 }
    sprites.hullPivot   = { x = sprites.hull:getWidth()/2,   y = sprites.hull:getHeight()/2   }
    sprites.weaponPivot = { x = sprites.weapon:getWidth()/2,  y = sprites.weapon:getHeight()/2 }
    sprites.weaponOffset = 15

    local r = math.floor(sprites.hull:getWidth()*escala/2*0.75)

    datos = {
        x = sx or 170,
        y = sy or 185,
        angulo = 0,
        anguloTorreta = 0,
        velocidad = 0,
        aceleracion = 300,
        velMax = 150,
        friccion = 200,
        radio = r,
        trackTimer = 0,
        isMoving = false,
        torretaDir = 0,
    }

    vida = VIDA_MAX
    timerInvulnerable = 0
end

function tanque.update(dt)
    datos.isMoving = false
    local r = datos.radio
    local nx, ny = datos.x, datos.y

    -- timer de invulnerabilidad tras recibir daño
    if timerInvulnerable > 0 then
        timerInvulnerable = timerInvulnerable - dt
    end

    -- movimiento con aceleracion
    if love.keyboard.isDown("w") then
        datos.velocidad = math.min(datos.velocidad + datos.aceleracion * dt, datos.velMax)
    elseif love.keyboard.isDown("s") then
        datos.velocidad = math.max(datos.velocidad - datos.aceleracion * dt, -datos.velMax/2)
    else
        if datos.velocidad > 0 then
            datos.velocidad = math.max(datos.velocidad - datos.friccion * dt, 0)
        elseif datos.velocidad < 0 then
            datos.velocidad = math.min(datos.velocidad + datos.friccion * dt, 0)
        end
    end

    nx = nx + math.cos(datos.angulo) * datos.velocidad * dt
    ny = ny + math.sin(datos.angulo) * datos.velocidad * dt

    local oldx, oldy = datos.x, datos.y
    if not isBlocked(nx, ny, r) then
        datos.x, datos.y = nx, ny
    else
        if not isBlocked(nx, datos.y, r) then datos.x = nx
        elseif not isBlocked(datos.x, ny, r) then datos.y = ny
        end
    end
    datos.isMoving = (datos.x ~= oldx or datos.y ~= oldy)

    -- rotacion (solo con velocidad suficiente)
    local turnSpeed = 2
    if math.abs(datos.velocidad) > 5 then
        if love.keyboard.isDown("a") then datos.angulo = datos.angulo - turnSpeed * dt end
        if love.keyboard.isDown("d") then datos.angulo = datos.angulo + turnSpeed * dt end
    end

    -- torreta hacia el raton con inercia
    local mx, my = love.mouse.getPosition()
    if GameView then
        mx = (mx - GameView.ox) / GameView.scale + (Camera and Camera.x or 0)
        my = (my - GameView.oy) / GameView.scale + (Camera and Camera.y or 0)
    end
    local targetTorreta = math.atan2(my - datos.y, mx - datos.x)
    local diffTorreta   = targetTorreta - datos.anguloTorreta
    while diffTorreta >  math.pi do diffTorreta = diffTorreta - 2*math.pi end
    while diffTorreta < -math.pi do diffTorreta = diffTorreta + 2*math.pi end

    local TURRET_SPEED = 3.5
    local prevDir = datos.torretaDir
    local newDir  = 0
    if math.abs(diffTorreta) > 0.005 then
        newDir = diffTorreta > 0 and 1 or -1
        local paso = math.min(math.abs(diffTorreta), TURRET_SPEED * dt)
        datos.anguloTorreta = datos.anguloTorreta + newDir * paso
    else
        datos.anguloTorreta = targetTorreta
    end
    datos.torretaDir = newDir

    if Audio then
        if newDir ~= 0 then Audio.torretaGirando(newDir ~= prevDir)
        else Audio.torretaParada() end
        Audio.actualizarMotor(datos.isMoving)
    end

    if datos.isMoving then
        datos.trackTimer = datos.trackTimer + dt
        if datos.trackTimer >= TRACK_INTERVALO then
            datos.trackTimer = 0
            Tracks.spawn(datos.x, datos.y, datos.angulo, datos.velocidad < 0)
        end
    end
end

function tanque.draw()
    local function drawSprite(img, pivot, angulo, x, y)
        love.graphics.draw(img, x, y, angulo, escala, escala, pivot.x, pivot.y)
    end

    -- parpadeo si es invulnerable (daño reciente)
    local visible = timerInvulnerable <= 0 or (math.floor(timerInvulnerable * 10) % 2 == 0)
    if not visible then return end

    love.graphics.setColor(1, 1, 1)
    drawSprite(sprites.tracks, sprites.tracksPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    local Perfil = require("systems.perfil")
    local cr, cg, cb = 1, 1, 1
    if Perfil.activo then
        cr = Perfil.activo.colorR
        cg = Perfil.activo.colorG
        cb = Perfil.activo.colorB
    end
    love.graphics.setColor(cr, cg, cb)
    drawSprite(sprites.hull, sprites.hullPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    local tx = datos.x + math.cos(datos.anguloTorreta) * sprites.weaponOffset
    local ty = datos.y + math.sin(datos.anguloTorreta) * sprites.weaponOffset
    drawSprite(sprites.weapon, sprites.weaponPivot, datos.anguloTorreta + math.pi/2, tx, ty)
    love.graphics.setColor(1, 1, 1)

    -- barra de vida
    local bw = 40
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", datos.x - bw/2, datos.y - 35, bw, 5)
    local ratio = vida / VIDA_MAX
    love.graphics.setColor(1-ratio, ratio, 0)
    love.graphics.rectangle("fill", datos.x - bw/2, datos.y - 35, bw * ratio, 5)
    love.graphics.setColor(1, 1, 1)
end

function tanque.getMuzzlePos()
    local dist = 40
    local bx = datos.x + math.cos(datos.anguloTorreta) * dist
    local by = datos.y + math.sin(datos.anguloTorreta) * dist
    return bx, by, datos.anguloTorreta
end

function tanque.getPosition()
    return datos.x, datos.y, datos.angulo
end

function tanque.getAngles()
    return datos.angulo, datos.anguloTorreta
end

-- comprueba si una bala de bot impacta con el jugador
function tanque.checkHit(bx, by, danio)
    danio = danio or 1
    if timerInvulnerable > 0 then return false end
    local dx = bx - datos.x
    local dy = by - datos.y
    if math.sqrt(dx*dx + dy*dy) < datos.radio + 5 then
        vida = vida - danio
        timerInvulnerable = TIEMPO_INVULNERABLE
        if vida <= 0 then
            vida = 0
            if Effects and Effects.spawnExplosion then
                Effects.spawnExplosion(datos.x, datos.y)
            end
            if Audio then Audio.explosion() end
        end
        return true
    end
    return false
end

function tanque.getVida()
    return vida, VIDA_MAX
end

function tanque.estaMuerto()
    return vida <= 0
end

function tanque.empujar(ex, ey)
    datos.x = datos.x + ex
    datos.y = datos.y + ey
end

return tanque