"""
Simple UDP Game Server for Tank Game
Receives player positions and broadcasts to all connected clients
"""
import socket
import json
import time
from datetime import datetime

HOST = '0.0.0.0'  # Listen on all interfaces
PORT = 12345      # Game server port

class GameServer:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind((HOST, PORT))
        self.clients = {}  # {address: {'id': player_id, 'last_seen': timestamp}}
        self.game_state = {}  # {player_id: {'x': x, 'y': y, 'angle': angle}}
        self.next_player_id = 1

    def run(self):
        print(f"[SERVER] Started on {HOST}:{PORT}")
        print("[SERVER] Waiting for players...")

        while True:
            try:
                data, addr = self.sock.recvfrom(1024)
                self.handle_message(data, addr)
            except ConnectionResetError:
                # Windows UDP quirk: ignore "connection reset" errors
                # These occur when a client disconnects abruptly
                pass
            except Exception as e:
                # Only print unexpected errors
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
            print(f"[WARN] Invalid JSON from {addr}")

    def handle_connect(self, addr):
        if addr not in self.clients:
            player_id = self.next_player_id
            self.next_player_id += 1
            self.clients[addr] = {
                'id': player_id,
                'last_seen': time.time()
            }
            self.game_state[player_id] = {'x': 960, 'y': 540, 'angle': 0}

            print(f"[CONNECT] Player {player_id} joined from {addr}")

            # Send welcome message with assigned ID
            response = json.dumps({
                'type': 'welcome',
                'player_id': player_id
            })
            self.sock.sendto(response.encode('utf-8'), addr)

    def handle_update(self, msg, addr):
        if addr in self.clients:
            player_id = self.clients[addr]['id']
            self.clients[addr]['last_seen'] = time.time()

            # Update game state
            self.game_state[player_id] = {
                'x': msg.get('x', 0),
                'y': msg.get('y', 0),
                'angle': msg.get('angle', 0)
            }

            # Broadcast game state to all clients
            self.broadcast_state()

    def handle_disconnect(self, addr):
        if addr in self.clients:
            player_id = self.clients[addr]['id']
            print(f"[DISCONNECT] Player {player_id} left")
            del self.clients[addr]
            if player_id in self.game_state:
                del self.game_state[player_id]

    def broadcast_state(self):
        """Send current game state to all connected clients"""
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
        """Remove clients that haven't sent data in 10 seconds"""
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
        print("\n[SERVER] Shutting down...")
