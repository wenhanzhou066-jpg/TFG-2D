"""
Servidor de juego UDP simple para Tank Game
Recibe posiciones de jugadores y retransmite a todos los clientes conectados
"""
import socket
import json
import time
from datetime import datetime

HOST = '0.0.0.0'  # Escucha en todas las interfaces
PORT = 12345      # Puerto del servidor de juego

class GameServer:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((HOST, PORT))
        self.clients = {}  # {direccion: {'id': id_jugador, 'last_seen': timestamp}}
        self.game_state = {}  # {id_jugador: {'x': x, 'y': y, 'angle': angulo}}
        self.next_player_id = 1

    def run(self):
        print(f"[SERVIDOR] Iniciado en {HOST}:{PORT}")
        print("[SERVIDOR] Esperando jugadores...")

        while True:
            try:
                data, addr = self.sock.recvfrom(1024)
                self.handle_message(data, addr)
            except ConnectionResetError:
                # Peculiaridad UDP en Windows: ignorar errores de "conexión reiniciada"
                # Ocurren cuando un cliente se desconecta de forma abrupta
                pass
            except Exception as e:
                # Solo mostrar errores inesperados
                if "10054" not in str(e):
                    print(f"[ERROR] {e}")

    def handle_message(self, data, addr):
        try:
            msg = json.loads(data.decode('utf-8'))
            msg_type = msg.get('type')

            if msg_type == 'connect':
                self.handle_connect(addr)

            elif msg_type == 'update':
                self.handle_update(msg, addr)

            elif msg_type == 'disconnect':
                self.handle_disconnect(addr)

        except json.JSONDecodeError:
            print(f"[ADVERTENCIA] JSON inválido de {addr}")

    def handle_connect(self, addr):
        if addr not in self.clients:
            player_id = self.next_player_id
            self.next_player_id += 1
            self.clients[addr] = {
                'id': player_id,
                'last_seen': time.time()
            }
            self.game_state[player_id] = {'x': 960, 'y': 540, 'angle': 0}

            print(f"[CONECTADO] Jugador {player_id} se unió desde {addr}")

            # Enviar mensaje de bienvenida con el ID asignado
            response = json.dumps({
                'type': 'welcome',
                'player_id': player_id
            })
            self.sock.sendto(response.encode('utf-8'), addr)

    def handle_update(self, msg, addr):
        if addr in self.clients:
            player_id = self.clients[addr]['id']
            self.clients[addr]['last_seen'] = time.time()

            # Actualizar estado del juego
            self.game_state[player_id] = {
                'x': msg.get('x', 0),
                'y': msg.get('y', 0),
                'angle': msg.get('angle', 0)
            }

            # Difundir estado del juego a todos los clientes
            self.broadcast_state()

    def handle_disconnect(self, addr):
        if addr in self.clients:
            player_id = self.clients[addr]['id']
            print(f"[DESCONECTADO] Jugador {player_id} salió")
            del self.clients[addr]
            if player_id in self.game_state:
                del self.game_state[player_id]

    def broadcast_state(self):
        """Enviar estado actual del juego a todos los clientes conectados"""
        state_msg = json.dumps({
            'type': 'state',
            'players': self.game_state
        })

        for addr in list(self.clients.keys()):
            try:
                self.sock.sendto(state_msg.encode('utf-8'), addr)
            except:
                pass

    def cleanup_stale_clients(self):
        """Eliminar clientes que no han enviado datos en 10 segundos"""
        current_time = time.time()
        stale_addrs = []

        for addr, client in self.clients.items():
            if current_time - client['last_seen'] > 10:
                stale_addrs.append(addr)

        for addr in stale_addrs:
            self.handle_disconnect(addr)

if __name__ == '__main__':
    server = GameServer()
    try:
        server.run()
    except KeyboardInterrupt:
        print("\n[SERVIDOR] Cerrando...")
