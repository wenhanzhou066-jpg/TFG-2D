-- entities/bot.lua
-- Estados: patrulla/persigue/ataca/retrocede/investiga
-- Dificultades: 1=Fácil, 2=Normal, 3=Difícil.

local Colision = require("systems.collision")

local Bot = {}

local sprites = {}
local spritesLoaded = false
local bots = {}
local ESCALA = 0.3

local DIFICULTADES = {
    {
        nombre = "Facil",
        cantidadBots = 5,
        vida = 20,
        velPatrulla = 65,
        velPersecucion = 85,
        cooldownDisparo = 2.5,
        rangoDeteccion = 300,
        rangoAtaque = 250,
        rangoPerdida = 450,
        velGiro = 2.0,
        errorPunteria = 0.25,
        disparoPredictivo = false,
        puedeStrafearse = false,
        puedeEsquivar = false,
        puedeRetroceder = false,
        velStrafe = 0,
        velEsquiva = 0,
    },
    {
        nombre = "Normal",
        cantidadBots = 7,
        vida = 30,
        velPatrulla = 100,
        velPersecucion = 135,
        cooldownDisparo = 1.4,
        rangoDeteccion = 420,
        rangoAtaque = 300,
        rangoPerdida = 520,
        velGiro = 2.8,
        errorPunteria = 0.10,
        disparoPredictivo = false,
        puedeStrafearse = true,
        puedeEsquivar = false,
        puedeRetroceder = false,
        velStrafe = 70,
        velEsquiva = 0,
    },
    {
        nombre = "Dificil",
        cantidadBots = 10,
        vida = 50,
        velPatrulla = 125,
        velPersecucion = 175,
        cooldownDisparo = 0.75,
        rangoDeteccion = 550,
        rangoAtaque = 350,
        rangoPerdida = 650,
        velGiro = 3.5,
        errorPunteria = 0.03,
        disparoPredictivo = true,
        puedeStrafearse = true,
        puedeEsquivar = true,
        puedeRetroceder = true,
        velStrafe = 110,
        velEsquiva = 200,
    },
}

local dif = DIFICULTADES[2]
local objetivos = {}

local function distancia(x1, y1, x2, y2)
    return math.sqrt((x2-x1)^2 + (y2-y1)^2)
end

local function difAngulos(a, b)
    local d = (b - a) % (2 * math.pi)
    if d > math.pi then d = d - 2 * math.pi end
    return d
end

local function girarHacia(actual, objetivo, velocidad, dt)
    local d = difAngulos(actual, objetivo)
    local maxGiro = velocidad * dt
    if math.abs(d) < maxGiro then return objetivo
    elseif d > 0 then return actual + maxGiro
    else return actual - maxGiro end
end

-- elige punto aleatorio libre evitando muros y rios
local function puntoAleatorio()
    local mw, mh = 1920, 1080
    if Map and Map.getSize then
        local sz = Map.getSize(); mw = sz.w; mh = sz.h
    end
    for _ = 1, 50 do
        local x = math.random(100, mw-100)
        local y = math.random(100, mh-100)
        if not Colision.isBlocked(x, y, 20) then return x, y end
    end
    return mw/2, mh/2
end

local VEL_BALA = 600

local function predecirPunteria(bx, by, tx, ty, tvx, tvy)
    local dx = tx - bx
    local dy = ty - by
    local t = math.sqrt(dx*dx + dy*dy) / VEL_BALA
    return math.atan2((ty + tvy*t) - by, (tx + tvx*t) - bx)
end

local function cargarSprites()
    if spritesLoaded then return end
    sprites.casco   = love.graphics.newImage("assets/images/PNG/Hulls_Color_A/Hull_02.png")
    sprites.torreta = love.graphics.newImage("assets/images/PNG/Weapon_Color_A/Gun_02.png")
    sprites.orugas  = love.graphics.newImage("assets/images/PNG/Tracks/Track_1_A.png")
    sprites.cascoPivX   = sprites.casco:getWidth()   / 2
    sprites.cascoPivY   = sprites.casco:getHeight()  / 2
    sprites.torretaPivX = sprites.torreta:getWidth()  / 2
    sprites.torretaPivY = sprites.torreta:getHeight() / 2
    sprites.orugasPivX  = sprites.orugas:getWidth()   / 2
    sprites.orugasPivY  = sprites.orugas:getHeight()  / 2
    spritesLoaded = true
end

local function calcularPosicionesSpawn(cantidad, radio)
    local lista = {}
    local mw, mh = 1920, 1080
    if Map and Map.getSize then local sz = Map.getSize(); mw = sz.w; mh = sz.h end
    local spawns = (Map and Map.getSpawns) and Map.getSpawns() or {}
    radio = radio or 20

    for i = 1, cantidad do
        local sx, sy
        local sp = (#spawns > 1) and spawns[((i-1) % (#spawns-1)) + 2] or {x = mw/2, y = mh/2}
        
        -- Intentar encontrar un punto libre cerca del spawn
        local encontrado = false
        local intentos = 0
        local radioBusqueda = 150
        
        while not encontrado and intentos < 30 do
            intentos = intentos + 1
            local ox = (math.random() - 0.5) * radioBusqueda
            local oy = (math.random() - 0.5) * radioBusqueda
            local tx = math.max(radio + 10, math.min(mw - radio - 10, sp.x + ox))
            local ty = math.max(radio + 10, math.min(mh - radio - 10, sp.y + oy))
            
            if not Colision.isBlocked(tx, ty, radio) then
                sx, sy = tx, ty
                encontrado = true
            else
                -- Si no encontramos, ampliamos el rango de búsqueda ligeramente
                radioBusqueda = radioBusqueda + 20
            end
        end
        
        -- Si después de muchos intentos no encontramos sitio libre, usamos el punto del spawn puro
        -- (o el último punto calculado) para no bloquear el juego
        if not encontrado then
            sx = sp.x
            sy = sp.y
        end
        
        lista[i] = {x = sx, y = sy}
    end
    return lista
end

local function crearBot(sx, sy, radio)
    local tx, ty = puntoAleatorio()
    return {
        x = sx, y = sy,
        angulo = math.random() * 2 * math.pi,
        anguloTorreta = 0,
        radio = radio,
        vida = dif.vida,
        vidaMax = dif.vida,
        velocidad = dif.velPatrulla,
        estado = "patrulla",
        objetivoX = tx, objetivoY = ty,
        ultimaPosX = tx, ultimaPosY = ty,
        timerDisparo = dif.cooldownDisparo * (0.5 + math.random()),
        timerEstado = 0,
        vivo = true,
        dirStrafe = (math.random() > 0.5) and 1 or -1,
        timerStrafe = 0,
        timerEsquiva = 0,
        anguloEsquiva = 0,
        esquivando = false,
        trackTimer = 0,
    }
end

function Bot.setDificultad(nivel)
    dif = DIFICULTADES[nivel] or DIFICULTADES[2]
end

function Bot.getDificultades()
    local nombres = {}
    for i, d in ipairs(DIFICULTADES) do nombres[i] = d.nombre end
    return nombres
end

function Bot.load()
    cargarSprites()
    local r = math.floor(sprites.casco:getWidth() * ESCALA / 2 * 0.75)
    bots = {}
    local posiciones = calcularPosicionesSpawn(dif.cantidadBots, r)
    for i = 1, dif.cantidadBots do
        bots[i] = crearBot(posiciones[i].x, posiciones[i].y, r)
    end
end

function Bot.spawnOleada(config)
    cargarSprites()
    dif = {
        vida = config.hp,
        velPatrulla = math.floor(100 * config.speedMult),
        velPersecucion = math.floor(135 * config.speedMult),
        cooldownDisparo = 1.4 * config.shootMult,
        rangoDeteccion = 420,
        rangoAtaque = 300,
        rangoPerdida = 520,
        velGiro = 2.8 + (1 - config.shootMult) * 1.5,
        errorPunteria = config.aimError,
        disparoPredictivo = config.leadShots,
        puedeStrafearse = config.canStrafe,
        puedeEsquivar = config.canDodge,
        puedeRetroceder = config.canRetreat,
        velStrafe = config.canStrafe and math.floor(70 * config.speedMult) or 0,
        velEsquiva = config.canDodge  and math.floor(200 * config.speedMult) or 0,
    }
    local r = math.floor(sprites.casco:getWidth() * ESCALA / 2 * 0.75)
    bots = {}
    local posiciones = calcularPosicionesSpawn(config.botCount, r)
    for i = 1, config.botCount do
        bots[i] = crearBot(posiciones[i].x, posiciones[i].y, r)
    end
end

function Bot.setObjetivos(lista)
    objetivos = lista or {}
end

local prevJx, prevJy, velJx, velJy = 0, 0, 0, 0

function Bot.update(dt)
    local tgts = {}
    if #objetivos > 0 then
        tgts = objetivos
    else
        local allTanks = Tank.getTanks()
        for _, tn in pairs(allTanks) do
            if not tn.isDead then
                table.insert(tgts, {x=tn.x, y=tn.y})
            end
        end
        if #tgts == 0 then
            local jx, jy = Tank.getPosition()
            table.insert(tgts, {x=jx, y=jy})
        end
    end

    local jx, jy = tgts[1].x, tgts[1].y
    if prevJx ~= 0 and dt > 0 then
        velJx = (jx - prevJx) / dt
        velJy = (jy - prevJy) / dt
    end
    prevJx, prevJy = jx, jy

    for _, b in ipairs(bots) do
        if not b.vivo then goto continuar end

        local px, py = tgts[1].x, tgts[1].y
        local d = distancia(b.x, b.y, px, py)
        for ti = 2, #tgts do
            local d2 = distancia(b.x, b.y, tgts[ti].x, tgts[ti].y)
            if d2 < d then d = d2; px, py = tgts[ti].x, tgts[ti].y end
        end

        b.timerEstado = b.timerEstado + dt
        b.timerDisparo = b.timerDisparo - dt

        -- transiciones de estado
        if b.estado == "patrulla" then
            if d < dif.rangoDeteccion and Colision.lineOfSight(b.x, b.y, px, py) then
                b.estado = "persigue"; b.timerEstado = 0
            end

        elseif b.estado == "persigue" then
            if d < dif.rangoAtaque and Colision.lineOfSight(b.x, b.y, px, py) then
                b.estado = "ataca"; b.timerEstado = 0
                b.dirStrafe = (math.random() > 0.5) and 1 or -1
            elseif d > dif.rangoPerdida or not Colision.lineOfSight(b.x, b.y, px, py) then
                if d < dif.rangoPerdida * 1.5 then -- si no se ha ido muy lejos, investiga
                    b.estado = "investiga"
                    b.ultimaPosX, b.ultimaPosY = px, py
                    b.timerEstado = 0
                else
                    b.estado = "patrulla"
                    b.objetivoX, b.objetivoY = puntoAleatorio()
                    b.timerEstado = 0
                end
            end

        elseif b.estado == "ataca" then
            if dif.puedeRetroceder and b.vida <= math.ceil(dif.vida * 0.3) then
                b.estado = "retrocede"; b.timerEstado = 0
            elseif d > dif.rangoAtaque * 1.3 or not Colision.lineOfSight(b.x, b.y, px, py) then
                b.estado = "persigue"; b.timerEstado = 0
            else
                b.ultimaPosX, b.ultimaPosY = px, py
            end

        elseif b.estado == "retrocede" then
            if d > dif.rangoPerdida * 0.8 or b.timerEstado > 4 then
                b.estado = "investiga"
                b.ultimaPosX, b.ultimaPosY = px, py
                b.timerEstado = 0
            end
            
        elseif b.estado == "investiga" then
            if d < dif.rangoDeteccion and Colision.lineOfSight(b.x, b.y, px, py) then
                b.estado = "persigue"; b.timerEstado = 0
            elseif distancia(b.x, b.y, b.ultimaPosX, b.ultimaPosY) < 40 or b.timerEstado > 6 then
                b.estado = "patrulla"
                b.objetivoX, b.objetivoY = puntoAleatorio()
                b.timerEstado = 0
            end
        end

        -- comportamiento por estado
        if b.estado == "patrulla" then
            b.velocidad = dif.velPatrulla
            if distancia(b.x, b.y, b.objetivoX, b.objetivoY) < 30 then
                b.objetivoX, b.objetivoY = puntoAleatorio()
            end
            local angDestino = math.atan2(b.objetivoY-b.y, b.objetivoX-b.x)
            b.angulo = girarHacia(b.angulo, angDestino, dif.velGiro, dt)
            b.anguloTorreta = b.angulo

        elseif b.estado == "persigue" then
            b.velocidad = dif.velPersecucion
            local angDestino = math.atan2(py-b.y, px-b.x)
            b.angulo = girarHacia(b.angulo, angDestino, dif.velGiro, dt)
            b.anguloTorreta = angDestino
            if d < dif.rangoAtaque * 1.3 and b.timerDisparo <= 0 then
                b.timerDisparo = dif.cooldownDisparo * 1.2
                local punteria = b.anguloTorreta + (math.random()-0.5) * dif.errorPunteria * 2
                local md = 40
                Bullet.spawn(b.x + math.cos(punteria)*md, b.y + math.sin(punteria)*md, punteria, "light", "bot")
            end

        elseif b.estado == "ataca" then
            local punteria
            if dif.disparoPredictivo then
                punteria = predecirPunteria(b.x, b.y, px, py, velJx, velJy)
            else
                punteria = math.atan2(py-b.y, px-b.x)
            end
            punteria = punteria + (math.random()-0.5) * dif.errorPunteria * 2
            b.anguloTorreta = punteria

            if dif.puedeStrafearse then
                b.timerStrafe = b.timerStrafe + dt
                if b.timerStrafe > 1.5 + math.random() then
                    b.timerStrafe = 0
                    b.dirStrafe = -b.dirStrafe
                end
                local angPerp = math.atan2(py-b.y, px-b.x) + math.pi/2 * b.dirStrafe
                b.velocidad = dif.velStrafe
                b.angulo = angPerp
            else
                b.velocidad = 0
            end

            if b.timerDisparo <= 0 then
                b.timerDisparo = dif.cooldownDisparo
                local md = 40
                Bullet.spawn(
                    b.x + math.cos(b.anguloTorreta)*md,
                    b.y + math.sin(b.anguloTorreta)*md,
                    b.anguloTorreta, "light", "bot"
                )
            end

        elseif b.estado == "retrocede" then
            local angHuida = math.atan2(b.y-py, b.x-px)
            angHuida = angHuida + math.sin(b.timerEstado * 3) * 0.4
            b.angulo = girarHacia(b.angulo, angHuida, dif.velGiro * 1.2, dt)
            b.velocidad = dif.velPersecucion * 1.1
            b.anguloTorreta = math.atan2(py-b.y, px-b.x)
            if b.timerDisparo <= 0 then
                b.timerDisparo = dif.cooldownDisparo * 1.5
                local md = 40
                Bullet.spawn(
                    b.x + math.cos(b.anguloTorreta)*md,
                    b.y + math.sin(b.anguloTorreta)*md,
                    b.anguloTorreta, "light", "bot"
                )
            end
            
        elseif b.estado == "investiga" then
            b.velocidad = dif.velPersecucion
            local angDestino = math.atan2(b.ultimaPosY-b.y, b.ultimaPosX-b.x)
            b.angulo = girarHacia(b.angulo, angDestino, dif.velGiro, dt)
            b.anguloTorreta = b.angulo
        end

        -- esquiva de balas (solo dificil)
        if dif.puedeEsquivar and not b.esquivando then
            local _, _, punteriaMuzzle = Tank.getMuzzlePos()
            local angAlBot = math.atan2(b.y-jy, b.x-jx)
            if math.abs(difAngulos(punteriaMuzzle, angAlBot)) < 0.15 and d < dif.rangoAtaque * 1.5 then
                if math.random() < 0.04 then
                    b.esquivando = true
                    b.timerEsquiva = 0.3
                    b.anguloEsquiva = angAlBot + math.pi/2 * ((math.random()>0.5) and 1 or -1)
                end
            end
        end

        if b.esquivando then
            b.timerEsquiva = b.timerEsquiva - dt
            if b.timerEsquiva <= 0 then
                b.esquivando = false
            else
                b.velocidad = dif.velEsquiva
                b.angulo = b.anguloEsquiva
            end
        end

        if b.velocidad > 0 then
            local nx = b.x + math.cos(b.angulo) * b.velocidad * dt
            local ny = b.y + math.sin(b.angulo) * b.velocidad * dt
            local r  = b.radio
            if not Colision.isBlocked(nx, ny, r) then
                b.x, b.y = nx, ny
                b.trackTimer = (b.trackTimer or 0) + dt
                if b.trackTimer >= 0.08 then
                    b.trackTimer = 0
                    Tracks.spawn(b.x, b.y, b.angulo, false)
                end
            else
                if not Colision.isBlocked(nx, b.y, r) then
                    b.x = nx
                elseif not Colision.isBlocked(b.x, ny, r) then
                    b.y = ny
                else
                    -- bloqueado: busca salida
                    b.objetivoX, b.objetivoY = puntoAleatorio()
                    b.esquivando = false
                end
            end
        end

        ::continuar::
    end
end

function Bot.draw()
    local medioPi = math.pi / 2
    for _, b in ipairs(bots) do
        if not b.vivo then goto continuar end

        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.draw(sprites.orugas,  b.x, b.y, b.angulo+medioPi,        ESCALA, ESCALA, sprites.orugasPivX,  sprites.orugasPivY)
        love.graphics.draw(sprites.casco,   b.x, b.y, b.angulo+medioPi,        ESCALA, ESCALA, sprites.cascoPivX,   sprites.cascoPivY)

        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.draw(sprites.torreta, b.x, b.y, b.anguloTorreta+medioPi, ESCALA, ESCALA, sprites.torretaPivX, sprites.torretaPivY)

        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", b.x-20, b.y-30, 40, 6)
        local ratio = b.vida / b.vidaMax
        love.graphics.setColor(1-ratio, ratio, 0)
        love.graphics.rectangle("fill", b.x-20, b.y-30, 40*ratio, 6)

        love.graphics.setColor(1, 1, 1)
        ::continuar::
    end
end

function Bot.checkHit(bx, by, danio)
    danio = danio or 1
    for _, b in ipairs(bots) do
        if b.vivo and distancia(bx, by, b.x, b.y) < b.radio + 5 then
            b.vida = b.vida - danio
            if b.vida <= 0 then
                b.vivo = false
                if Effects and Effects.spawnExplosion then
                    Effects.spawnExplosion(b.x, b.y)
                end
                if Audio then Audio.explosion() end
            end
            return true
        end
    end
    return false
end

function Bot.checkHitArea(bx, by, radio, danio)
    danio = danio or 1
    local golpeo = false
    for _, b in ipairs(bots) do
        if b.vivo and distancia(bx, by, b.x, b.y) < radio then
            b.vida = b.vida - danio
            if b.vida <= 0 then
                b.vivo = false
                if Effects and Effects.spawnExplosion then
                    Effects.spawnExplosion(b.x, b.y)
                end
                if Audio then Audio.explosion() end
            end
            golpeo = true
        end
    end
    return golpeo
end

function Bot.contarVivos()
    local c = 0
    for _, b in ipairs(bots) do if b.vivo then c = c+1 end end
    return c
end

function Bot.getVivos()
    local vivos = {}
    for _, b in ipairs(bots) do if b.vivo then vivos[#vivos+1] = b end end
    return vivos
end

return Bot