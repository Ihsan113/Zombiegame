"""Tiny UDP network emulator (delay + jitter + loss) between an ENet client and host.

usage: netem_proxy.py LISTEN_PORT HOST_PORT DELAY_MS JITTER_MS LOSS_PCT SECONDS [BURST] [STALL_EVERY_S] [STALL_MAX_MS]
Both directions get the same impairment. Packets are delayed individually, so jitter can reorder.
BURST (default 0): probability that a loss event drops the following 2 packets as well.
STALL_EVERY_S / STALL_MAX_MS (default 0 = off): models Wi-Fi power-save / hotspot hiccups. On average
every STALL_EVERY_S seconds the link freezes for 40 ms .. STALL_MAX_MS; everything sent meanwhile is held
and released together in order when the stall ends (a delivery burst), exactly what phone hotspots do.
"""
import heapq
import random
import socket
import sys
import threading
import time

listen_port, host_port = int(sys.argv[1]), int(sys.argv[2])
delay, jitter, loss = float(sys.argv[3]) / 1000.0, float(sys.argv[4]) / 1000.0, float(sys.argv[5]) / 100.0
run_for = float(sys.argv[6])
burst = float(sys.argv[7]) if len(sys.argv) > 7 else 0.0
stall_every = float(sys.argv[8]) if len(sys.argv) > 8 else 0.0
stall_max = float(sys.argv[9]) / 1000.0 if len(sys.argv) > 9 else 0.0
stall_until = 0.0
next_stall = time.time() + 2.0

rng = random.Random(1234)
front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
front.bind(("127.0.0.1", listen_port))
front.settimeout(0.05)
back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
back.bind(("127.0.0.1", 0))
back.settimeout(0.05)

client_addr = None
queue = []  # (deliver_at, seq, direction, data)
lock = threading.Lock()
seq = 0
stop = time.time() + run_for
drop_next = {"up": 0, "down": 0}
stats = {"up_in": 0, "up_drop": 0, "down_in": 0, "down_drop": 0, "down_bytes": 0, "down_max": 0}


def enqueue(direction, data):
    global seq, stall_until, next_stall
    stats[direction + "_in"] += 1
    if direction == "down":
        stats["down_bytes"] += len(data)
        stats["down_max"] = max(stats["down_max"], len(data))
    if drop_next[direction] > 0:
        drop_next[direction] -= 1
        stats[direction + "_drop"] += 1
        return
    if loss > 0 and rng.random() < loss:
        stats[direction + "_drop"] += 1
        if burst > 0 and rng.random() < burst:
            drop_next[direction] = 2
        return
    now = time.time()
    if stall_every > 0.0 and stall_max > 0.0 and now >= next_stall:
        stall_until = now + rng.uniform(0.04, stall_max)
        next_stall = stall_until + rng.expovariate(1.0 / stall_every)
    when = now + max(0.0, delay + rng.uniform(-jitter, jitter))
    if now < stall_until:
        when = max(when, stall_until + rng.uniform(0.0, 0.002))  # released as a burst, order roughly kept
    with lock:
        seq += 1
        heapq.heappush(queue, (when, seq, direction, data))


def reader_front():
    global client_addr
    while time.time() < stop:
        try:
            data, addr = front.recvfrom(65535)
        except socket.timeout:
            continue
        client_addr = addr
        enqueue("up", data)


def reader_back():
    while time.time() < stop:
        try:
            data, _ = back.recvfrom(65535)
        except socket.timeout:
            continue
        enqueue("down", data)


def sender():
    while time.time() < stop + 0.2:
        item = None
        with lock:
            if queue and queue[0][0] <= time.time():
                item = heapq.heappop(queue)
        if item is None:
            time.sleep(0.0005)
            continue
        _, _, direction, data = item
        if direction == "up":
            back.sendto(data, ("127.0.0.1", host_port))
        elif client_addr is not None:
            front.sendto(data, client_addr)


threads = [threading.Thread(target=f, daemon=True) for f in (reader_front, reader_back, sender)]
for t in threads:
    t.start()
for t in threads:
    t.join()
print("PROXY", stats, flush=True)
