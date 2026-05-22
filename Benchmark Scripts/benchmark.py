"""
Benchmark sender — postupný ramp-up pro testování škálování pipeline.

Stejný wire formát i fyzikální model jako `main.py`, jediný rozdíl je
v tom, že každých `RAMP_INTERVAL` sekund přidá `RAMP_STEP` dalších
hráčů. Cílem je naměřit, kdy začne latence prosakovat přes 100 ms
hranici stanovenou v nefunkčních požadavcích.

CSV s naměřenými časy zapisuje aplikace přes `BenchmarkLogger`
(spuštění s `--benchmark` argumentem v Edit Scheme). Plot vizualizace
viz `benchmark_plot.py`.
"""

import socket
import time
import struct
import math
import random

UDP_IP = "127.0.0.1"
UDP_PORT = 12345
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

FIELD_W = 60.0  # šířka hřiště (osa X): -30..30
FIELD_H = 30.0  # výška hřiště (osa Y): -15..15

PLAYER_SPEED = 8.0   # m/s
FRAME_HZ = 15        # Frekvence aktualizace fyziky a vzorkování pozic (Hz)
STATS_INTERVAL = 1.0 # Jak často vypisovat souhrn (s)

# Ramp-up parametry pro benchmark.
INITIAL_PLAYERS = 5
RAMP_STEP = 5         # hráčů přidáno na každém kroku
RAMP_INTERVAL = 10.0  # s mezi kroky
MAX_PLAYERS = 250     # hard cap; ramp-up se po dosažení zastaví, sender běží dál

# Hardware ID rozsah. Wire formát přenáší ID jako little-endian UInt64
# (8 B), takže lze používat realistické UWB tag IDs bez ztráty přesnosti.
# Benchmark záměrně neposílá puk — měříme čisté škálování s počtem hráčů,
# takže `active_count_at_render` v CSV začíná přesně na `INITIAL_PLAYERS`.
PLAYER_ID_BASE = 80_000_000


def random_unit_vector():
    angle = random.uniform(0, 2 * math.pi)
    return math.cos(angle), math.sin(angle)


def bounce(entity):
    """Odrazí entitu od hranic hřiště. Vrátí True pokud došlo k odrazu."""
    bounced = False
    if entity["x"] < -FIELD_W / 2:
        entity["x"] = -FIELD_W / 2
        entity["dx"] = abs(entity["dx"])
        bounced = True
    elif entity["x"] > FIELD_W / 2:
        entity["x"] = FIELD_W / 2
        entity["dx"] = -abs(entity["dx"])
        bounced = True
    if entity["y"] < -FIELD_H / 2:
        entity["y"] = -FIELD_H / 2
        entity["dy"] = abs(entity["dy"])
        bounced = True
    elif entity["y"] > FIELD_H / 2:
        entity["y"] = FIELD_H / 2
        entity["dy"] = -abs(entity["dy"])
        bounced = True
    return bounced


def make_player(index):
    p_dx, p_dy = random_unit_vector()
    return {
        "id": PLAYER_ID_BASE + index,
        "x": random.uniform(-FIELD_W / 2, FIELD_W / 2),
        "y": random.uniform(-FIELD_H / 2, FIELD_H / 2),
        "dx": p_dx,
        "dy": p_dy,
    }


# ── INICIALIZACE HRÁČŮ ────────────────────────────────────────────────────
players = [make_player(i) for i in range(INITIAL_PLAYERS)]
next_player_index = INITIAL_PLAYERS

start_time = time.time()
last_time = start_time
last_stats_time = start_time
last_ramp_time = start_time
cap_reached_at: float | None = None
packets_since_stats = 0

print(f"start: {INITIAL_PLAYERS} hráčů, +{RAMP_STEP} každých {RAMP_INTERVAL:.0f} s, cap {MAX_PLAYERS}")

while True:
    current_time = time.time()
    dt = current_time - last_time
    last_time = current_time

    # ── RAMP-UP ─────────────────────────────────────────────────────────────
    if len(players) < MAX_PLAYERS and current_time - last_ramp_time >= RAMP_INTERVAL:
        room = MAX_PLAYERS - len(players)
        for _ in range(min(RAMP_STEP, room)):
            players.append(make_player(next_player_index))
            next_player_index += 1
        last_ramp_time = current_time
        elapsed = current_time - start_time
        if len(players) >= MAX_PLAYERS:
            cap_reached_at = current_time
            print(f"[ramp] t={elapsed:.1f}s → {len(players)} hráčů (cap, končím za {RAMP_INTERVAL:.0f} s)")
        else:
            print(f"[ramp] t={elapsed:.1f}s → {len(players)} hráčů")

    # ── KONEC: 10 s po dosažení capu ────────────────────────────────────────
    if cap_reached_at is not None and current_time - cap_reached_at >= RAMP_INTERVAL:
        elapsed = current_time - start_time
        print(f"[done] t={elapsed:.1f}s → konec měření")
        break

    # ── HRÁČI ────────────────────────────────────────────────────────────────
    for player in players:
        player["x"] += player["dx"] * PLAYER_SPEED * dt
        player["y"] += player["dy"] * PLAYER_SPEED * dt

        if bounce(player):
            angle = math.atan2(player["dy"], player["dx"]) + random.uniform(-math.pi / 6, math.pi / 6)
            player["dx"] = math.cos(angle)
            player["dy"] = math.sin(angle)

    # ── ODESLÁNÍ UDP ─────────────────────────────────────────────────────────
    entities_to_send = players
    per_packet_delay = (1.0 / FRAME_HZ) / len(entities_to_send)

    for e in entities_to_send:
        send_ts = time.time()

        # '<'    = Little-Endian
        # 'd'    = x         (8 bytes, offset 0)
        # 'd'    = y         (8 bytes, offset 8)
        # 'Q'    = id        (8 bytes, offset 16)  -- UInt64
        # 'd'    = timestamp (8 bytes, offset 24)
        data = struct.pack("<ddQd", e["x"], e["y"], int(e["id"]), send_ts)

        sock.sendto(data, (UDP_IP, UDP_PORT))
        packets_since_stats += 1

        time.sleep(per_packet_delay)

    if current_time - last_stats_time >= STATS_INTERVAL:
        elapsed_stats = current_time - last_stats_time
        elapsed_total = current_time - start_time
        print(f"t={elapsed_total:6.1f}s | {packets_since_stats} pkts in {elapsed_stats:.2f}s "
              f"({packets_since_stats / elapsed_stats:6.1f} pkt/s, "
              f"{len(players)} hráčů @ {FRAME_HZ} Hz)")
        last_stats_time = current_time
        packets_since_stats = 0
