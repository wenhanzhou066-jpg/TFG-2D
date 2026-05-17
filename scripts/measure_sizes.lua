-- measure_sizes.lua
-- Ejecutar con: luajit measure_sizes.lua
-- Mide tamaño real de mensajes binarios vs JSON equivalente

package.path = package.path .. ";./?.lua"
local bp = require("src.binary_protocol")
local json = require("systems.json")

local function measure(name, bin_msg, json_table)
    local bin_size = #bin_msg
    local json_size = #json.encode(json_table)
    local pct = math.floor((1 - bin_size / json_size) * 100 + 0.5)
    print(string.format("%-35s  JSON=%3d  Bin=%3d  -%d%%", name, json_size, bin_size, pct))
end

print(string.format("%-35s  %s  %s  %s", "Mensaje", "JSON(B)", "Bin(B)", "Reduc"))
print(string.rep("-", 65))

-- CONNECT (cliente -> servidor: room_id + player_name)
measure("CONNECT",
    bp.encode({ type="connect", room_id="sala1", player_name="Player1" }),
    { type="connect", room_id="sala1", player_name="Player1" }
)

-- INPUT v2 (cliente -> servidor)
measure("INPUT v2 (cliente->servidor)",
    bp.encode({ type="input", up=true, down=false, left=false, right=false,
                shoot=false, turret_angle=1.57, seq=42 }),
    { type="input", up=true, down=false, left=false, right=false,
      shoot=false, turret_angle=1.57, seq=42 }
)

-- SNAPSHOT con 2 jugadores
local snap2 = {
    type="snapshot", seq=100,
    players={
        { id=1, x=300, y=400, angle=1.2, turret_angle=0.5, hp=100, alive=true },
        { id=2, x=600, y=700, angle=2.1, turret_angle=1.8, hp=75,  alive=true },
    }
}
measure("SNAPSHOT 2 jugadores",
    bp.encode(snap2), snap2
)

-- SNAPSHOT con 4 jugadores
local snap4 = {
    type="snapshot", seq=100,
    players={
        { id=1, x=300, y=400, angle=1.2, turret_angle=0.5, hp=100, alive=true },
        { id=2, x=600, y=700, angle=2.1, turret_angle=1.8, hp=75,  alive=true },
        { id=3, x=150, y=200, angle=0.3, turret_angle=3.1, hp=50,  alive=true },
        { id=4, x=900, y=500, angle=4.7, turret_angle=2.2, hp=100, alive=true },
    }
}
measure("SNAPSHOT 4 jugadores",
    bp.encode(snap4), snap4
)

-- BULLET_SPAWN (servidor -> clientes)
measure("BULLET_SPAWN",
    bp.encode({ type="bullet_spawn", bullet_id=7, owner_id=1,
                x=320, y=410, angle=1.2, bullet_type=1 }),
    { type="bullet_spawn", bullet_id=7, owner_id=1,
      x=320, y=410, angle=1.2, bullet_type=1 }
)

-- HIT (servidor -> clientes)
measure("HIT",
    bp.encode({ type="hit", bullet_id=7, target_id=2, damage=25, new_hp=75 }),
    { type="hit", bullet_id=7, target_id=2, damage=25, new_hp=75 }
)

-- LIST_ROOMS (cliente -> servidor, mensaje vacío)
measure("LIST_ROOMS (peticion)",
    bp.encode({ type="list_rooms" }),
    { type="list_rooms" }
)

-- ROOMS_LIST con 3 salas (servidor -> cliente)
local rooms = {
    type="rooms_list",
    rooms={
        { room_id="sala1", game_mode="ffa", player_count=2, max_players=8, status="playing" },
        { room_id="sala2", game_mode="tdm", player_count=4, max_players=8, status="waiting" },
        { room_id="sala3", game_mode="ffa", player_count=1, max_players=4, status="waiting" },
    }
}
measure("ROOMS_LIST (3 salas)",
    bp.encode(rooms), rooms
)