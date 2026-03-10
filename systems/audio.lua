-- systems/audio.lua
-- Modulo central de audio para el juego.
-- Musica por mapa + efectos de sonido (motor, disparo, explosion).

local Settings = require("systems.settings")

local Audio = {}

-- Musica de fondo (una por mapa)
local musicFiles = {
    "assets/audio/game/music_1.ogg",
    "assets/audio/game/music_2.ogg",
    "assets/audio/game/music_3.ogg",
}

-- Efectos de sonido
local sfxFiles = {
    shot      = "assets/audio/game/shot.ogg",
    explosion = "assets/audio/game/explosion.ogg",
    engine    = "assets/audio/game/engine.ogg",
}

local music     = nil   -- Source de musica activa
local sfx       = {}    -- { shot=Source, explosion=Source, engine=Source }
local engineOn  = false -- estado actual del motor

-- Intenta cargar un audio; devuelve nil si el fichero no existe.
local function tryLoad(path, mode)
    local ok, src = pcall(love.audio.newSource, path, mode)
    if ok then return src end
    return nil
end

-- ── API publica ────────────────────────────────────────────────────

-- Llamar en Game.load(mapIdx) para arrancar la musica del mapa.
function Audio.load(mapIdx)
    -- Detener musica anterior si la hay
    if music then music:stop() end

    -- Cargar y reproducir musica del mapa
    local path = musicFiles[mapIdx] or musicFiles[1]
    music = tryLoad(path, "stream")
    if music then
        music:setLooping(true)
        music:setVolume((Settings.volumen or 0.7) * 0.6)
        love.audio.play(music)
    end

    -- Cargar SFX (solo la primera vez o si aun no estan cargados)
    if not sfx.shot then
        sfx.shot      = tryLoad(sfxFiles.shot,      "static")
        sfx.explosion = tryLoad(sfxFiles.explosion, "static")
        sfx.engine    = tryLoad(sfxFiles.engine,    "static")
        if sfx.engine then
            sfx.engine:setLooping(true)
            sfx.engine:setVolume((Settings.volumen or 0.7) * 0.5)
        end
    end

    engineOn = false
end

-- Detener toda la musica de juego (al volver al menu).
function Audio.stopMusic()
    if music then music:stop(); music = nil end
    if sfx.engine then sfx.engine:stop() end
    engineOn = false
end

-- Reproducir sonido de disparo (polifonico: clona el source).
function Audio.playShot()
    if not sfx.shot then return end
    local clone = sfx.shot:clone()
    clone:setVolume((Settings.volumen or 0.7) * 0.8)
    love.audio.play(clone)
end

-- Reproducir sonido de explosion (polifonico: clona el source).
function Audio.playExplosion()
    if not sfx.explosion then return end
    local clone = sfx.explosion:clone()
    clone:setVolume((Settings.volumen or 0.7) * 0.9)
    love.audio.play(clone)
end

-- Llamar cada frame desde Tank.update; arranca/para el bucle del motor.
function Audio.updateEngine(isMoving)
    if not sfx.engine then return end
    if isMoving and not engineOn then
        love.audio.play(sfx.engine)
        engineOn = true
    elseif not isMoving and engineOn then
        sfx.engine:stop()
        engineOn = false
    end
end

return Audio
