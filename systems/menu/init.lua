
-- Router del menu - dependiendo de la pantalla activa o escenario hace que funcione 


local Settings = require("systems.settings")
local UI = require("systems.ui")

-- Cargamos cada pantalla como un modulo independiente
local pantallas = {
    principal = require("systems.menu.principal"),
    jugar = require("systems.menu.jugar"),
    multijugador = require("systems.menu.multijugador"),
    dificultad = require("systems.menu.dificultad"),
    personalizar = require("systems.menu.personalizar"),
    ranking = require("systems.menu.ranking"),
    configuracion= require("systems.menu.configuracion"),
}

local Menu = {}

-- Estado compartido entre todas las pantallas.
-- Lo pasamos a cada pantalla para que puedan navegar y comunicarse.
local estado = "principal"
local historial = {}
local action = nil
local tiempo = 0
local musica, botonImg, tituloImg, fondos

local function navegarA(nuevoEstado)
    table.insert(historial, estado)
    estado = nuevoEstado
end

local function volver()
    estado = table.remove(historial) or "principal"
end

local function setAction(a)
    action = a
end

-- Escena que pasamos a cada pantalla en su load/update/draw.
local escena = {
    navegarA = navegarA,
    volver = volver,
    setAction = setAction,
    getMusica = function() return musica end,
    getTiempo = function() return tiempo end,
    botonImg = function() return botonImg end,
    tituloImg = function() return tituloImg end,
    fondos = function() return fondos end,
}


function Menu.load()
    action = nil
    estado = "principal"
    historial= {}
    tiempo = 0

    UI.loadFonts()
    Settings.cargar()

    musica = love.audio.newSource("assets/menu/musicamilitar.mp3", "stream")
    musica:setLooping(true)
    musica:setVolume(Settings.volumen)
    love.audio.play(musica)

    botonImg = love.graphics.newImage("assets/menu/ui_concrete.png")
    tituloImg = love.graphics.newImage("assets/menu/titulopanel.png")
    fondos = {
        love.graphics.newImage("assets/menu/parallax-mountain-bg.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-foreground-trees.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-montain-far.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-mountains.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-trees.png"),
    }

    -- iniciamos todas las pantallas pasandoles la escena
    for _, pantalla in pairs(pantallas) do
        if pantalla.load then pantalla.load(escena) end
    end
end

function Menu.update(dt)
    tiempo = tiempo + dt
    local p = pantallas[estado]
    if p and p.update then p.update(dt, escena) end
end

function Menu.draw()
    local p = pantallas[estado]
    if p and p.draw then p.draw(escena) end
end

function Menu.keypressed(key)
    local p = pantallas[estado]
    if p and p.keypressed then p.keypressed(key, escena) end
end

function Menu.mousemoved(mx, my)
    local p = pantallas[estado]
    if p and p.mousemoved then p.mousemoved(mx, my, escena) end
end

function Menu.mousepressed(mx, my, btn)
    local p = pantallas[estado]
    if p and p.mousepressed then p.mousepressed(mx, my, btn, escena) end
end

function Menu.resize()    UI.loadFonts() end
function Menu.getAction() return action end
function Menu.stopMusic() if musica then musica:stop() end end

return Menu