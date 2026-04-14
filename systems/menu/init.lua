-- Router del menu: gestiona que pantalla esta activa y enruta los eventos

local Settings = require("systems.settings")
local UI       = require("systems.ui")
local Audio    = require("systems.audio")

local pantallas = {
    principal    = require("systems.menu.principal"),
    jugar        = require("systems.menu.jugar"),
    mapas        = require("systems.menu.mapas"),
    multijugador = require("systems.menu.multijugador"),
    lobby        = require("systems.menu.lobby"),
    personalizar = require("systems.menu.personalizar"),
    ranking      = require("systems.menu.ranking"),
    configuracion= require("systems.menu.configuracion"),
    menu_oleadas = require("systems.menu.menu_oleadas"),
    practicar    = require("systems.menu.practicar"),
}

local Menu = {}

local estado   = "principal"
local historial = {}
local accion   = nil
local tiempo   = 0
local musica, botonImg, botonExitImg, tituloImg, fondos

local function navegarA(nuevoEstado)
    table.insert(historial, estado)
    estado = nuevoEstado
end

local function volver()
    estado = table.remove(historial) or "principal"
end

local function setAccion(a)
    accion = a
end

local escena = {
    navegarA     = navegarA,
    volver       = volver,
    setAction    = setAccion,
    getMusica    = function() return musica end,
    getTiempo    = function() return tiempo end,
    botonImg     = function() return botonImg end,
    botonExitImg = function() return botonExitImg end,
    tituloImg    = function() return tituloImg end,
    fondos       = function() return fondos end,
}

function Menu.load()
    accion   = nil
    estado   = "principal"
    historial = {}
    tiempo   = 0

    UI.loadFonts()
    Settings.cargar()

    if not Settings.volumenSfx then
        Settings.volumenSfx = 0.7
    end

    Audio.cargarSonidosMenu()

    musica = love.audio.newSource("assets/menu/musicamilitar.mp3", "stream")
    musica:setLooping(true)
    musica:setVolume(Settings.volumen)
    love.audio.play(musica)

    botonImg     = love.graphics.newImage("assets/menu/boton_normal.png")
    botonExitImg = love.graphics.newImage("assets/menu/boton_salir.png")
    tituloImg    = love.graphics.newImage("assets/menu/titulo_panel.png")

    botonImg:setFilter("nearest", "nearest")
    botonExitImg:setFilter("nearest", "nearest")
    tituloImg:setFilter("nearest", "nearest")

    fondos = {
        love.graphics.newImage("assets/menu/parallax-mountain-bg.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-foreground-trees.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-montain-far.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-mountains.png"),
        love.graphics.newImage("assets/menu/parallax-mountain-trees.png"),
    }

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

function Menu.mousereleased(mx, my, btn)
    local p = pantallas[estado]
    if p and p.mousereleased then p.mousereleased(mx, my, btn) end
end

function Menu.textinput(t)
    local p = pantallas[estado]
    if p and p.textinput then p.textinput(t, escena) end
end

function Menu.resize()
    UI.loadFonts()
end

function Menu.getAction()   return accion end
function Menu.clearAction() accion = nil  end

function Menu.stopMusic()
    if musica then musica:stop() end
end

return Menu