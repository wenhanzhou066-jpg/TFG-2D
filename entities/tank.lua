-- Control del tanque del jugador

local Tracks = require("systems.tracks")

local tanque = {}
tanque.onDieCallback = nil   -- se asigna desde cada modo de juego
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
        torretaDir = 0,   -- dirección de giro actual: -1, 0 o 1
        -- Sistema de combate del compañero
        hp = 100,
        maxHp = 100,
        isDead = false,
        respawnTimer = 0,
        respawnDelay = 3.0,
        invulnerable = false,
        invulnTimer = 0,
        spawnX = sx or 170,
        spawnY = sy or 185,
        -- Cooldown de disparo
        shootCooldown = 0,
        shootDelay = 0.3,  -- 0.3s entre disparos
    }

    vida = VIDA_MAX
    timerInvulnerable = 0
end

function tanque.update(dt)
    -- Manejar respawn si está muerto
    if datos.isDead then
        datos.respawnTimer = datos.respawnTimer - dt
        if datos.respawnTimer <= 0 then
            tanque.respawn()
        end
        return
    end

    -- Invulnerabilidad temporal después de respawn
    if datos.invulnerable then
        datos.invulnTimer = datos.invulnTimer - dt
        if datos.invulnTimer <= 0 then
            datos.invulnerable = false
        end
    end

    -- Cooldown de disparo
    if datos.shootCooldown > 0 then
        datos.shootCooldown = datos.shootCooldown - dt
    end

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
    -- No dibujar si está muerto
    if datos.isDead then
        return
    end

    local function drawSprite(img, pivot, angulo, x, y)
        love.graphics.draw(img, x, y, angulo, escala, escala, pivot.x, pivot.y)
    end

    -- Efecto de parpadeo si invulnerable
    local invuln = datos.invulnerable or (timerInvulnerable > 0)
    local blinkTimer = datos.invulnTimer or timerInvulnerable
    if invuln and math.floor(blinkTimer * 10) % 2 == 0 then
        return
    end

    -- orugas (siempre blanco)
    love.graphics.setColor(1, 1, 1)
    drawSprite(sprites.tracks, sprites.tracksPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    local Perfil = require("systems.perfil")
    local bodyR, bodyG, bodyB = 1, 1, 1
    local turretR, turretG, turretB = 1, 1, 1
    if Perfil.activo then
        bodyR   = Perfil.activo.colorBodyR   or 1
        bodyG   = Perfil.activo.colorBodyG   or 1
        bodyB   = Perfil.activo.colorBodyB   or 1
        turretR = Perfil.activo.colorTurretR or 1
        turretG = Perfil.activo.colorTurretG or 1
        turretB = Perfil.activo.colorTurretB or 1
    end
    love.graphics.setColor(bodyR, bodyG, bodyB)
    drawSprite(sprites.hull, sprites.hullPivot, datos.angulo + math.pi/2, datos.x, datos.y)

    local tx = datos.x + math.cos(datos.anguloTorreta) * sprites.weaponOffset
    local ty = datos.y + math.sin(datos.anguloTorreta) * sprites.weaponOffset
    love.graphics.setColor(turretR, turretG, turretB)
    drawSprite(sprites.weapon, sprites.weaponPivot, datos.anguloTorreta + math.pi/2, tx, ty)
    love.graphics.setColor(1, 1, 1)
    -- Barra de vida encima del tanque
    tanque.drawHealthBar()
end

-- Dibujar barra de vida
function tanque.drawHealthBar()
    if datos.isDead then return end

    local barW = 60
    local barH = 6
    local barX = datos.x - barW/2
    local barY = datos.y - 50

    local hpPercent = datos.hp / datos.maxHp

    -- Fondo negro
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX-1, barY-1, barW+2, barH+2)

    -- Barra de HP con gradiente de color
    local r, g, b
    if hpPercent > 0.6 then
        r, g, b = 0.2, 0.8, 0.2  -- verde
    elseif hpPercent > 0.3 then
        r, g, b = 1.0, 0.8, 0.0  -- amarillo
    else
        r, g, b = 1.0, 0.2, 0.2  -- rojo
    end

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", barX, barY, barW * hpPercent, barH)

    -- Borde blanco
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", barX-1, barY-1, barW+2, barH+2)

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
    if datos.isDead or datos.invulnerable or (timerInvulnerable > 0) then return false end
    
    local dx = bx - datos.x
    local dy = by - datos.y
    if math.sqrt(dx*dx + dy*dy) < datos.radio + 5 then
        tanque.takeDamage(danio)
        return true
    end
    return false
end

function tanque.getVida()
    return datos.hp, datos.maxHp
end

function tanque.estaMuerto()
    return datos.isDead
end

function tanque.empujar(ex, ey)
    datos.x = datos.x + ex
    datos.y = datos.y + ey
end

-- SISTEMA DE COMBATE
function tanque.takeDamage(damage)
    if datos.isDead or datos.invulnerable then
        return false
    end

    datos.hp = math.max(0, datos.hp - damage)

    -- Efectos visuales
    if Effects then
        Effects.shake(5)
        Effects.spawnDamageNumber(datos.x, datos.y - 30, damage)
        Effects.spawnFlash(datos.x, datos.y)
    end

    if datos.hp <= 0 then
        tanque.die()
    end

    return true
end

function tanque.die()
    datos.isDead = true
    datos.respawnTimer = datos.respawnDelay
    datos.velocidad = 0

    -- Explosion grande en posición de muerte
    if Effects then
        Effects.spawnExplosion(datos.x, datos.y, "heavy", 64)
    end
    if Audio then
        Audio.explosion()
    end
    if tanque.onDieCallback then tanque.onDieCallback() end
end

function tanque.respawn()
    datos.isDead = false
    datos.hp = datos.maxHp
    datos.x = datos.spawnX
    datos.y = datos.spawnY
    datos.angulo = 0
    datos.anguloTorreta = 0
    datos.velocidad = 0
    datos.invulnerable = true
    datos.invulnTimer = 2.0  -- 2 segundos de invulnerabilidad

    if Effects then
        Effects.spawnExplosion(datos.x, datos.y, "plasma", 32)
    end
end

function tanque.getHP()
    return datos.hp, datos.maxHp
end

function tanque.heal(amount)
    if datos.isDead then return false end
    datos.hp = math.min(datos.maxHp, datos.hp + amount)
    return true
end

function tanque.isDead()
    return datos.isDead
end

function tanque.isInvulnerable()
    return datos.invulnerable
end

function tanque.getBounds()
    return datos.x, datos.y, datos.radio
end

function tanque.canShoot()
    return not datos.isDead and datos.shootCooldown <= 0
end

function tanque.shoot()
    if not tanque.canShoot() then
        return false
    end

    datos.shootCooldown = datos.shootDelay
    return true
end

return tanque