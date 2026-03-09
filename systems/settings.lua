
-- Guarda y carga las preferencias del jugador en disco

local Settings = {}

-- Valores por defecto 
Settings.volumen          = 0.7
Settings.idioma           = "ES"
Settings.pantallaCompleta = true

local ARCHIVO = "settings.json"

-- Guarda las preferencias en disco en formato JSON
function Settings.guardar()
    local datos = string.format(
        '{"volumen":%.2f,"idioma":"%s","pantallaCompleta":%s}',
        Settings.volumen,
        Settings.idioma,
        tostring(Settings.pantallaCompleta)
    )
    love.filesystem.write(ARCHIVO, datos)
end

-- Carga las preferencias desde disco.
-- Si el archivo no existe, se quedan los valores por defecto.
function Settings.cargar()
    if not love.filesystem.getInfo(ARCHIVO) then return end

    local contenido = love.filesystem.read(ARCHIVO)
    if not contenido then return end
    
    local vol = contenido:match('"volumen":(%-?%d+%.?%d*)')
    local idi = contenido:match('"idioma":"(%a+)"')
    local pan = contenido:match('"pantallaCompleta":(%a+)')

    if vol then Settings.volumen          = tonumber(vol) end
    if idi then Settings.idioma           = idi end
    if pan then Settings.pantallaCompleta = (pan == "true") end
end

return Settings