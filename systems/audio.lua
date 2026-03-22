-- Modulo de audio: musica de juego, efectos y sonidos de menu

local Settings = require("systems.settings")

local Audio = {}

-- Musica de fondo (misma para todos los mapas por ahora)
local MUSICA_MAPA = "assets/sounds/maps/Gumbel - Tapes.mp3"

-- Rutas de efectos del tanque
local RUTAS_SFX = {
    disparo   = "assets/sounds/tank/423116__ogsoundfx__guns-explosions-album-heavy-object-impact-4.wav",
    explosion = "assets/sounds/tank/478277__joao_janz__8-bit-explosion-1_6.wav",
    motor     = "assets/sounds/tank/200303__qubodup__tank-engine-loop.flac",
    torreta   = "assets/sounds/tank/418881__kierankeegan__tank-turret-rotate.wav",
}

local musica  = nil
local sfx     = {}
local sfxMenu = {}
local motorOn = false

-- Intenta cargar un audio sin crashear si no existe el fichero
local function cargar(ruta, modo)
    local ok, src = pcall(love.audio.newSource, ruta, modo)
    return ok and src or nil
end

-- Genera un sonido sintetico para el menu (sin necesitar ficheros externos)
local function generarSonidoMenu(tipo)
    local tasa    = 44100
    local duracion = 0.12
    if tipo == "hover" then duracion = 0.07 end
    if tipo == "back"  then duracion = 0.15 end

    local muestras = math.floor(tasa * duracion)
    local datos    = love.sound.newSoundData(muestras, tasa, 16, 1)

    for i = 0, muestras - 1 do
        local t   = i / tasa
        local env = math.max(0, 1 - t / duracion)
        local val = 0

        if tipo == "click" then
            val = (math.sin(2*math.pi*880*t)*0.6 + math.sin(2*math.pi*1320*t)*0.4) * env * env
        elseif tipo == "hover" then
            local f = 440 + t * 1200
            val = math.sin(2*math.pi*f*t) * env * 0.5
        elseif tipo == "back" then
            local f = 660 - t * 800
            val = (math.sin(2*math.pi*f*t)*0.5 + math.sin(2*math.pi*f*0.5*t)*0.3) * env
        elseif tipo == "confirm" then
            local f = t < 0.06 and 523 or 659
            val = math.sin(2*math.pi*f*t) * env * 0.7
        end

        datos:setSample(i, math.max(-1, math.min(1, val)))
    end
    return love.audio.newSource(datos)
end

function Audio.cargarSonidosMenu()
    sfxMenu.click   = generarSonidoMenu("click")
    sfxMenu.hover   = generarSonidoMenu("hover")
    sfxMenu.back    = generarSonidoMenu("back")
    sfxMenu.confirm = generarSonidoMenu("confirm")

    if sfxMenu.click   then sfxMenu.click:setVolume(0.55)   end
    if sfxMenu.hover   then sfxMenu.hover:setVolume(0.25)   end
    if sfxMenu.back    then sfxMenu.back:setVolume(0.40)    end
    if sfxMenu.confirm then sfxMenu.confirm:setVolume(0.65) end
end

local function reproducirMenu(clave)
    local src = sfxMenu[clave]
    if not src then return end
    local clon = src:clone()
    clon:setVolume(src:getVolume() * (Settings.volumenSfx or 0.7))
    love.audio.play(clon)
end

function Audio.clickMenu()   reproducirMenu("click")   end
function Audio.hoverMenu()   reproducirMenu("hover")   end
function Audio.volverMenu()  reproducirMenu("back")    end
function Audio.confirmMenu() reproducirMenu("confirm") end

function Audio.aplicarVolumenMenu(musicaMenu)
    if musicaMenu then musicaMenu:setVolume(Settings.volumen) end
end

-- Carga la musica del mapa y los efectos de juego
function Audio.load(indiceMapa)
    if musica then musica:stop() end

    musica = cargar(MUSICA_MAPA, "stream")
    if musica then
        musica:setLooping(true)
        musica:setVolume((Settings.volumen or 0.7) * 0.6)
        love.audio.play(musica)
    end

    -- SFX: cargar solo la primera vez
    if not sfx.disparo then
        sfx.disparo   = cargar(RUTAS_SFX.disparo,   "static")
        sfx.explosion = cargar(RUTAS_SFX.explosion,  "static")
        sfx.motor     = cargar(RUTAS_SFX.motor,      "static")
        sfx.torreta   = cargar(RUTAS_SFX.torreta,    "static")

        if sfx.motor then
            sfx.motor:setLooping(true)
            sfx.motor:setVolume((Settings.volumen or 0.7) * 0.5)
        end
        if sfx.torreta then
            sfx.torreta:setLooping(false)
        end
    end

    motorOn = false
end

function Audio.pararMusica()
    if musica       then musica:stop(); musica = nil end
    if sfx.motor    then sfx.motor:stop() end
    if sfx.torreta  then sfx.torreta:stop() end
    motorOn = false
end

-- Disparo
function Audio.disparo()
    if not sfx.disparo then return end
    local clon = sfx.disparo:clone()
    clon:setVolume((Settings.volumenSfx or 0.7) * 0.8)
    love.audio.play(clon)
end

-- Explosion
function Audio.explosion()
    if not sfx.explosion then return end
    local clon = sfx.explosion:clone()
    clon:setVolume((Settings.volumenSfx or 0.7) * 0.9)
    love.audio.play(clon)
end

-- Motor del tanque
function Audio.actualizarMotor(seEstaMoviendo)
    if not sfx.motor then return end
    if seEstaMoviendo and not motorOn then
        love.audio.play(sfx.motor)
        motorOn = true
    elseif not seEstaMoviendo and motorOn then
        sfx.motor:stop()
        motorOn = false
    end
end

-- Torreta girando: reiniciar=true fuerza reinicio del sonido (cambio de dir)
function Audio.torretaGirando(reiniciar)
    if not sfx.torreta then return end
    if reiniciar or not sfx.torreta:isPlaying() then
        sfx.torreta:stop()
        sfx.torreta:seek(0)
        sfx.torreta:setVolume((Settings.volumenSfx or 0.7) * 0.4)
        love.audio.play(sfx.torreta)
    end
end

function Audio.torretaParada()
    if sfx.torreta and sfx.torreta:isPlaying() then
        sfx.torreta:stop()
    end
end

return Audio
