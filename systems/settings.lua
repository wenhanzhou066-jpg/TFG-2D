-- Guarda y carga las preferencias del jugador en disco

local Settings = {}

-- Valores por defecto
Settings.volumen = 0.7
Settings.volumenSfx = 0.7
Settings.idioma = "ES"

local ARCHIVO = "settings.json"

-- Guarda las preferencias en disco en formato JSON
function Settings.guardar()
    local datos = string.format(
        '{"volumen":%.2f,"volumenSfx":%.2f,"idioma":"%s"}',
        Settings.volumen,
        Settings.volumenSfx,
        Settings.idioma
    )
    love.filesystem.write(ARCHIVO, datos)
end

-- Carga las preferencias desde disco.
-- Si el archivo no existe se quedan los valores por defecto.
function Settings.cargar()
    if not love.filesystem.getInfo(ARCHIVO) then return end
    local contenido = love.filesystem.read(ARCHIVO)
    if not contenido then return end

    local vol = contenido:match('"volumen":(%-?%d+%.?%d*)')
    local sfx = contenido:match('"volumenSfx":(%-?%d+%.?%d*)')
    local idi = contenido:match('"idioma":"(%a+)"')

    if vol then Settings.volumen = tonumber(vol) end
    if sfx then Settings.volumenSfx = tonumber(sfx) end
    if idi then Settings.idioma = idi end
end

return Settings