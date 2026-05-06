-- Control del tanque del jugador

local Tracks   = require("systems.tracks")
local Controls = require("systems.controls")

local tanque = {}
tanque.onDieCallback = nil   -- se asigna desde cada modo de juego
local sprites = {}
local tanks = {} -- Cambiado: guardaremos { [1] = datosP1, [2] = datosP2 }
local escala = 0.3
local TRACK_INTERVALO = 0.08 -- tiempo entre huellas
local VIDA_MAX = 5
local timerInvulnerable = 0
local TIEMPO_INVULNERABLE = 0.8

-- colision del tanque con el mapa
local function isBlocked(nx, ny, r, selfId)
    -- Colisión con otros tanques locales
    for id, datos in pairs(tanks) do
        if id ~= selfId and not datos.isDead then
            local dx = nx - datos.x
            local dy = ny - datos.y
            local distSq = dx*dx + dy*dy
            local sumRadius = (r + datos.radio) * 0.9 -- tolerancia
            if distSq < sumRadius*sumRadius then
                return true
            end
        end
    end

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

local function createTankData(sx, sy)
    local r = math.floor(sprites.hull:getWidth()*escala/2*0.75)
    return {
        x = sx or 170,
        y = sy or 185,
        angulo = 0,
        anguloTorreta = 0,
        velocidad = 0,
        aceleracion = 300,
        velMax = 150,
        velMaxBase = 150,  -- Velocidad base (para speed boost)
        friccion = 200,
        radio = r,
        trackTimer = 0,
        isMoving = false,
        torretaDir = 0,
        hp = 100,
        maxHp = 100,
        isDead = false,
        respawnTimer = 0,
        respawnDelay = 3.0,
        invulnerable = false,
        invulnTimer = 0,
        spawnX = sx or 170,
        spawnY = sy or 185,
        shootCooldown = 0,
        shootDelay = 0.3,
        shootDelayBase = 0.3,  -- Cooldown base (para ammo boost)
        -- Powerups activos
        speedBoostTimer = 0,
        ammoBoostTimer = 0,
    }
end

function tanque.load(sx, sy)
    sprites.tracks = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
    sprites.hull   = love.graphics.newImage("assets/images/PNG/Hulls_Color_A/Hull_01.png")
    sprites.weapon = love.graphics.newImage("assets/images/PNG/Weapon_Color_A/Gun_01.png")

    -- Sprites alternativos para J2 (pueden ser B)
    sprites.hull2   = love.graphics.newImage("assets/images/PNG/Hulls_Color_B/Hull_01.png")
    sprites.weapon2 = love.graphics.newImage("assets/images/PNG/Weapon_Color_B/Gun_01.png")

    sprites.tracksPivot = { x = sprites.tracks:getWidth()/2, y = sprites.tracks:getHeight()/2 }
    sprites.hullPivot   = { x = sprites.hull:getWidth()/2,   y = sprites.hull:getHeight()/2   }
    sprites.weaponPivot = { x = sprites.weapon:getWidth()/2,  y = sprites.weapon:getHeight()/2 }
    sprites.weaponOffset = 15

    tanks = {}
    tanks[1] = createTankData(sx, sy)

    timerInvulnerable = 0
end

function tanque.loadCoop(sx, sy)
    tanks[2] = createTankData(sx, sy)
end

function tanque.update(dt)
    if timerInvulnerable > 0 then
        timerInvulnerable = timerInvulnerable - dt
    end

    local anyMoving = false
    local anyRotating = false
    local turretDirChanged = false

    for id, datos in pairs(tanks) do
        if datos.isDead then
            datos.respawnTimer = datos.respawnTimer - dt
            if datos.respawnTimer <= 0 then
                tanque.respawn(id)
            end
        else
            if datos.invulnerable then
                datos.invulnTimer = datos.invulnTimer - dt
                if datos.invulnTimer <= 0 then
                    datos.invulnerable = false
                end
            end

            -- Actualizar timers de powerups
            if datos.speedBoostTimer > 0 then
                datos.speedBoostTimer = datos.speedBoostTimer - dt
                if datos.speedBoostTimer <= 0 then
                    -- Restaurar velocidad normal
                    datos.velMax = datos.velMaxBase
                end
            end

            if datos.ammoBoostTimer > 0 then
                datos.ammoBoostTimer = datos.ammoBoostTimer - dt
                if datos.ammoBoostTimer <= 0 then
                    -- Restaurar cooldown normal
                    datos.shootDelay = datos.shootDelayBase
                end
            end

            if datos.shootCooldown > 0 then
                datos.shootCooldown = datos.shootCooldown - dt
            end

            datos.isMoving = false
            local r = datos.radio
            local nx, ny = datos.x, datos.y

            local up, down, left, right
            local kUp    = Controls.get(id, "up")    or (id == 1 and "w"    or "up")
            local kDown  = Controls.get(id, "down")  or (id == 1 and "s"    or "down")
            local kLeft  = Controls.get(id, "left")  or (id == 1 and "a"    or "left")
            local kRight = Controls.get(id, "right") or (id == 1 and "d"    or "right")
            up    = love.keyboard.isDown(kUp)
            down  = love.keyboard.isDown(kDown)
            left  = love.keyboard.isDown(kLeft)
            right = love.keyboard.isDown(kRight)

            if up then
                datos.velocidad = math.min(datos.velocidad + datos.aceleracion * dt, datos.velMax)
            elseif down then
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
            if not isBlocked(nx, ny, r, id) then
                datos.x, datos.y = nx, ny
            else
                if not isBlocked(nx, datos.y, r, id) then datos.x = nx
                elseif not isBlocked(datos.x, ny, r, id) then datos.y = ny
                end
            end
            datos.isMoving = (datos.x ~= oldx or datos.y ~= oldy)

            local turnSpeed = 2
            if math.abs(datos.velocidad) > 5 then
                if left then datos.angulo = datos.angulo - turnSpeed * dt end
                if right then datos.angulo = datos.angulo + turnSpeed * dt end
            end

            local TURRET_SPEED = 3.5
            local prevDir = datos.torretaDir
            local newDir  = 0

            if id == 1 then
                local mx, my = love.mouse.getPosition()
                if GameView then
                    mx = (mx - GameView.ox) / GameView.scale + (Camera and Camera.x or 0)
                    my = (my - GameView.oy) / GameView.scale + (Camera and Camera.y or 0)
                end
                local targetTorreta = math.atan2(my - datos.y, mx - datos.x)
                local diffTorreta   = targetTorreta - datos.anguloTorreta
                while diffTorreta >  math.pi do diffTorreta = diffTorreta - 2*math.pi end
                while diffTorreta < -math.pi do diffTorreta = diffTorreta + 2*math.pi end

                if math.abs(diffTorreta) > 0.005 then
                    newDir = diffTorreta > 0 and 1 or -1
                    local paso = math.min(math.abs(diffTorreta), TURRET_SPEED * dt)
                    datos.anguloTorreta = datos.anguloTorreta + newDir * paso
                else
                    datos.anguloTorreta = targetTorreta
                end
            else
                local kTL = Controls.get(id, "turretLeft")  or "j"
                local kTR = Controls.get(id, "turretRight") or "k"
                if love.keyboard.isDown(kTL) then newDir = -1 end
                if love.keyboard.isDown(kTR) then newDir =  1 end
                datos.anguloTorreta = datos.anguloTorreta + newDir * TURRET_SPEED * dt
            end

            datos.torretaDir = newDir

            if datos.isMoving then
                anyMoving = true
                datos.trackTimer = datos.trackTimer + dt
                if datos.trackTimer >= TRACK_INTERVALO then
                    datos.trackTimer = 0
                    Tracks.spawn(datos.x, datos.y, datos.angulo, datos.velocidad < 0)
                end
            end
            
            if newDir ~= 0 then
                anyRotating = true
                if newDir ~= prevDir then
                    turretDirChanged = true
                end
            end
        end
    end

    if Audio then
        if anyRotating then
            Audio.torretaGirando(turretDirChanged)
        else
            Audio.torretaParada()
        end
        Audio.actualizarMotor(anyMoving)
    end
end

function tanque.draw()
    for id, datos in pairs(tanks) do
        if not datos.isDead then
            local function drawSprite(img, pivot, angulo, x, y)
                love.graphics.draw(img, x, y, angulo, escala, escala, pivot.x, pivot.y)
            end

            local invuln = datos.invulnerable or (timerInvulnerable > 0)
            local blinkTimer = datos.invulnTimer or timerInvulnerable
            local skipDraw = false
            if invuln and math.floor(blinkTimer * 10) % 2 == 0 then
                skipDraw = true
            end

            if not skipDraw then
                love.graphics.setColor(1, 1, 1)
                drawSprite(sprites.tracks, sprites.tracksPivot, datos.angulo + math.pi/2, datos.x, datos.y)

                local cr, cg, cb = 1, 1, 1
                local tr, tg, tb = 1, 1, 1
                if id == 1 then
                    local Perfil = require("systems.perfil")
                    if Perfil.activo then
                        cr = Perfil.activo.colorBodyR   or 1
                        cg = Perfil.activo.colorBodyG   or 1
                        cb = Perfil.activo.colorBodyB   or 1
                        tr = Perfil.activo.colorTurretR or 1
                        tg = Perfil.activo.colorTurretG or 1
                        tb = Perfil.activo.colorTurretB or 1
                    end
                end

                local hullSprite = id == 2 and sprites.hull2 or sprites.hull
                local weaponSprite = id == 2 and sprites.weapon2 or sprites.weapon

                love.graphics.setColor(cr, cg, cb)
                drawSprite(hullSprite, sprites.hullPivot, datos.angulo + math.pi/2, datos.x, datos.y)

                local tx = datos.x + math.cos(datos.anguloTorreta) * sprites.weaponOffset
                local ty = datos.y + math.sin(datos.anguloTorreta) * sprites.weaponOffset
                love.graphics.setColor(tr, tg, tb)
                drawSprite(weaponSprite, sprites.weaponPivot, datos.anguloTorreta + math.pi/2, tx, ty)

                -- Indicadores visuales de powerups activos
                if datos.speedBoostTimer > 0 then
                    -- Aura magenta para speed boost
                    local pulse = math.sin(love.timer.getTime() * 10) * 0.3 + 0.7
                    love.graphics.setColor(1, 0.3, 1, 0.3 * pulse)
                    love.graphics.circle("line", datos.x, datos.y, datos.radio + 10, 32)
                    love.graphics.circle("line", datos.x, datos.y, datos.radio + 15, 32)
                end

                if datos.ammoBoostTimer > 0 then
                    -- Aura amarilla para ammo boost
                    local pulse = math.sin(love.timer.getTime() * 8) * 0.3 + 0.7
                    love.graphics.setColor(1, 0.8, 0.2, 0.3 * pulse)
                    love.graphics.circle("line", datos.x, datos.y, datos.radio + 8, 32)
                end

                love.graphics.setColor(1, 1, 1)

                tanque.drawHealthBar(id)
            end
        end
    end
end

function tanque.drawHealthBar(id)
    local datos = tanks[id or 1]
    if not datos or datos.isDead then return end

    local barW = 60
    local barH = 6
    local barX = datos.x - barW/2
    local barY = datos.y - 50

    local hpPercent = datos.hp / datos.maxHp

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", barX-1, barY-1, barW+2, barH+2)

    local r, g, b
    if hpPercent > 0.6 then
        r, g, b = 0.2, 0.8, 0.2
    elseif hpPercent > 0.3 then
        r, g, b = 1.0, 0.8, 0.0
    else
        r, g, b = 1.0, 0.2, 0.2
    end

    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", barX, barY, barW * hpPercent, barH)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", barX-1, barY-1, barW+2, barH+2)

    -- Si hay más de 1 jugador, mostrar P1 o P2 encima
    if tanks[2] then
        love.graphics.print("P"..id, barX + 20, barY - 15)
    end
    
    love.graphics.setColor(1, 1, 1)
end

function tanque.getMuzzlePos(id)
    local datos = tanks[id or 1]
    if not datos then return 0,0,0 end
    local dist = 40
    local bx = datos.x + math.cos(datos.anguloTorreta) * dist
    local by = datos.y + math.sin(datos.anguloTorreta) * dist
    return bx, by, datos.anguloTorreta
end

function tanque.getPosition(id)
    local datos = tanks[id or 1]
    if not datos then return 0,0,0 end
    return datos.x, datos.y, datos.angulo
end

function tanque.getAngles(id)
    local datos = tanks[id or 1]
    if not datos then return 0,0 end
    return datos.angulo, datos.anguloTorreta
end

function tanque.checkHit(bx, by, danio, id)
    local datos = tanks[id or 1]
    if not datos then return false end

    danio = danio or 1
    if datos.isDead or datos.invulnerable or (timerInvulnerable > 0) then return false end
    
    local dx = bx - datos.x
    local dy = by - datos.y
    if math.sqrt(dx*dx + dy*dy) < datos.radio + 5 then
        tanque.takeDamage(danio, id)
        return true
    end
    return false
end

function tanque.getVida(id)
    local datos = tanks[id or 1]
    if not datos then return 0,1 end
    return datos.hp, datos.maxHp
end

function tanque.estaMuerto(id)
    local datos = tanks[id or 1]
    if not datos then return true end
    return datos.isDead
end

function tanque.empujar(ex, ey, id)
    local datos = tanks[id or 1]
    if not datos then return end
    datos.x = datos.x + ex
    datos.y = datos.y + ey
end

function tanque.takeDamage(damage, id)
    local datos = tanks[id or 1]
    if not datos then return false end

    if datos.isDead or datos.invulnerable then
        return false
    end

    datos.hp = math.max(0, datos.hp - damage)

    if Effects then
        Effects.shake(5)
        Effects.spawnDamageNumber(datos.x, datos.y - 30, damage)
        Effects.spawnFlash(datos.x, datos.y)
    end

    if datos.hp <= 0 then
        tanque.die(id)
    end

    return true
end

function tanque.die(id)
    local datos = tanks[id or 1]
    if not datos then return end

    datos.isDead = true
    datos.respawnTimer = datos.respawnDelay
    datos.velocidad = 0

    if Effects then
        Effects.spawnExplosion(datos.x, datos.y, "heavy", 64)
    end
    if Audio then
        Audio.explosion()
    end
    if tanque.onDieCallback then tanque.onDieCallback() end

    if _G.GameMultiplayer and _G.GameMultiplayer.addMuerte then
        _G.GameMultiplayer.addMuerte()
    end
end

function tanque.respawn(id)
    local datos = tanks[id or 1]
    if not datos then return end

    datos.isDead = false
    datos.hp = datos.maxHp

    local spawnPartner = false
    for oid, odatos in pairs(tanks) do
        if oid ~= (id or 1) and not odatos.isDead then
            -- Intentar aparecer a un lado (derecha, izquierda, abajo, arriba)
            local offsets = {{60,0}, {-60,0}, {0,60}, {0,-60}}
            local foundSpot = false
            for _, off in ipairs(offsets) do
                local nx, ny = odatos.x + off[1], odatos.y + off[2]
                if not isBlocked(nx, ny, datos.radio, id) then
                    datos.x, datos.y = nx, ny
                    foundSpot = true
                    break
                end
            end
            
            -- Si no hay hueco libre alrededor, aparecer encima como último recurso
            if not foundSpot then
                datos.x, datos.y = odatos.x, odatos.y
            end
            
            spawnPartner = true
            break
        end
    end

    if not spawnPartner then
        datos.x = datos.spawnX
        datos.y = datos.spawnY
    end

    datos.angulo = 0
    datos.anguloTorreta = 0
    datos.velocidad = 0
    datos.invulnerable = true
    datos.invulnTimer = 2.0

    if Effects then
        Effects.spawnExplosion(datos.x, datos.y, "plasma", 32)
    end
end

function tanque.getHP(id)
    local datos = tanks[id or 1]
    if not datos then return 0,1 end
    return datos.hp, datos.maxHp
end

function tanque.heal(amount, id)
    local datos = tanks[id or 1]
    if not datos then return false end
    if datos.isDead then return false end
    datos.hp = math.min(datos.maxHp, datos.hp + amount)
    return true
end

function tanque.isDead(id)
    local datos = tanks[id or 1]
    if not datos then return true end
    return datos.isDead
end

function tanque.isInvulnerable(id)
    local datos = tanks[id or 1]
    if not datos then return false end
    return datos.invulnerable
end

function tanque.getBounds(id)
    local datos = tanks[id or 1]
    if not datos then return 0,0,0 end
    return datos.x, datos.y, datos.radio
end

function tanque.canShoot(id)
    local datos = tanks[id or 1]
    if not datos then return false end
    return not datos.isDead and datos.shootCooldown <= 0
end

function tanque.shoot(id)
    local datos = tanks[id or 1]
    if not datos then return false end
    if not tanque.canShoot(id) then
        return false
    end
    datos.shootCooldown = datos.shootDelay
    return true
end

-- Funciones para obtener info de ambos tanques en coop
function tanque.hasPlayer2()
    return tanks[2] ~= nil
end

function tanque.getTanks()
    return tanks
end

-- Aplicar powerup de escudo (invulnerabilidad temporal)
function tanque.applyShield(duration, id)
    local datos = tanks[id or 1]
    if not datos or datos.isDead then return false end
    datos.invulnerable = true
    datos.invulnTimer = duration
    return true
end

-- Aplicar powerup de velocidad
function tanque.applySpeedBoost(duration, id)
    local datos = tanks[id or 1]
    if not datos or datos.isDead then return false end
    datos.velMax = datos.velMaxBase * 1.5  -- 50% más rápido
    datos.speedBoostTimer = duration
    return true
end

-- Aplicar powerup de munición (disparo más rápido)
function tanque.applyAmmoBoost(duration, id)
    local datos = tanks[id or 1]
    if not datos or datos.isDead then return false end
    datos.shootDelay = datos.shootDelayBase * 0.5  -- Mitad de cooldown
    datos.ammoBoostTimer = duration
    return true
end

return tanque