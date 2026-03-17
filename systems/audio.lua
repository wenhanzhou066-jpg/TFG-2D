-- Modulo de audio: musica de juego, efectos y sonidos de menu

local Settings = require("systems.settings")

local Audio = {}

-- Archivos de musica por mapa
local archivoMusica = {}

-- Archivos de efectos de juego
local archivosSfx = {}

local musica = nil   -- musica activa del mapa
local sfx = {}    -- efectos de juego cargados
local sfxMenu = {}    -- efectos de menu generados por sintesis
local motorOn = false -- si el motor del tanque esta sonando

-- Intenta cargar un audio sin crashear si no existe el fichero
local function cargar(ruta, modo)
    local ok, src = pcall(love.audio.newSource, ruta, modo)
    return ok and src or nil
end

-- Genera un sonido sintetico para el menu (sin necesitar ficheros externos)
-- tipo: "click" | "hover" | "back" | "confirm"
local function generarSonidoMenu(tipo)
    local tasa = 44100
    local duracion = 0.12
    if tipo == "hover" then duracion = 0.07 end
    if tipo == "back"  then duracion = 0.15 end

    local muestras = math.floor(tasa * duracion)
    local datos = love.sound.newSoundData(muestras, tasa, 16, 1)

    for i = 0, muestras - 1 do
        local t   = i / tasa
        -- Envelope: el sonido va bajando de volumen hasta cero
        local env = math.max(0, 1 - t / duracion)
        local val = 0

        if tipo == "click" then
            -- Tick metalico con dos frecuencias mezcladas
            val = (math.sin(2 * math.pi * 880  * t) * 0.6
                 + math.sin(2 * math.pi * 1320 * t) * 0.4) * env * env

        elseif tipo == "hover" then
            -- Pitido suave que sube de tono
            local f = 440 + t * 1200
            val = math.sin(2 * math.pi * f * t) * env * 0.5

        elseif tipo == "back" then
            -- Pitido que baja de tono (sensacion de retroceder)
            local f = 660 - t * 800
            val = (math.sin(2 * math.pi * f       * t) * 0.5
                 + math.sin(2 * math.pi * f * 0.5 * t) * 0.3) * env

        elseif tipo == "confirm" then
            -- Dos notas cortas seguidas (do-mi)
            local f = t < 0.06 and 523 or 659
            val = math.sin(2 * math.pi * f * t) * env * 0.7
        end

        -- Clamp para que no se salga del rango de audio [-1, 1]
        datos:setSample(i, math.max(-1, math.min(1, val)))
    end

    return love.audio.newSource(datos)
end

-- Carga los sonidos del menu (llamar en Menu.load)
function Audio.cargarSonidosMenu()
    sfxMenu.click = generarSonidoMenu("click")
    sfxMenu.hover = generarSonidoMenu("hover")
    sfxMenu.back = generarSonidoMenu("back")
    sfxMenu.confirm = generarSonidoMenu("confirm")

    -- Volumen de cada sonido de menu
    if sfxMenu.click   then sfxMenu.click:setVolume(0.55)   end
    if sfxMenu.hover   then sfxMenu.hover:setVolume(0.25)   end
    if sfxMenu.back    then sfxMenu.back:setVolume(0.40)    end
    if sfxMenu.confirm then sfxMenu.confirm:setVolume(0.65) end
end

-- Reproduce un sonido de menu respetando el volumen de Settings
local function reproducirMenu(clave)
    local src = sfxMenu[clave]
    if not src then return end
    -- Clonamos para que puedan sonar varios a la vez (polofonia)
    local clon = src:clone()
    clon:setVolume(src:getVolume() * (Settings.volumenSfx or 0.7))
    love.audio.play(clon)
end

-- Sonidos de menu publicos
function Audio.clickMenu() reproducirMenu("click") end
function Audio.hoverMenu() reproducirMenu("hover") end
function Audio.volverMenu() reproducirMenu("back") end
function Audio.confirmMenu() reproducirMenu("confirm") end

-- Actualiza el volumen de la musica del menu en tiempo real
function Audio.aplicarVolumenMenu(musicaMenu)
    if musicaMenu then
        musicaMenu:setVolume(Settings.volumen)
    end
end

-- Carga la musica del mapa y los efectos de juego
function Audio.load(indiceMapa)
    -- Paramos la musica anterior si la hay
    if musica then musica:stop() end

    local ruta = archivoMusica[indiceMapa] or archivoMusica[1]
    musica = cargar(ruta, "stream")
    if musica then
        musica:setLooping(true)
        musica:setVolume((Settings.volumen or 0.7) * 0.6)
        love.audio.play(musica)
    end

    -- Cargamos sfx de juego solo la primera vez
    if not sfx.disparo then
        sfx.disparo   = cargar(archivosSfx.disparo, "static")
        sfx.explosion = cargar(archivosSfx.explosion, "static")
        sfx.motor     = cargar(archivosSfx.motor, "static")
        if sfx.motor then
            sfx.motor:setLooping(true)
            sfx.motor:setVolume((Settings.volumen or 0.7) * 0.5)
        end
    end

    motorOn = false
end

-- Para toda la musica al volver al menu
function Audio.pararMusica()
    if musica    then musica:stop(); musica = nil end
    if sfx.motor then sfx.motor:stop() end
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

-- Arranca o para el motor segun si el tanque se mueve
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

return Audio