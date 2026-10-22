# Pixel Zombie Online — Deployment

## Architecture

- Android APK -> HTTP/HTTPS lobby API (Node.js): check status, create a room, enter a 6-character invite code, receive a short-lived, single-use ticket.
- Node.js -> one **independent Godot 4.7 headless process per room**, dynamically allocated UDP ports, up to four Android peers per room. Node never processes gameplay packets.
- Android APK -> Godot ENet/UDP on the public host+port: send input commands, receive authoritative binary world snapshots. Retains client-side prediction, reconciliation, smoothing/interpolation and unreliable ordered snapshots from original code.
- Game server -> local room API: readiness, ticket authentication, game started, peer left. HTTP is only control-plane traffic. No REST/WebSocket polling for zombie positions.

**This ZIP contains the source code, not a deployed VPS or prebuilt Android APK.** A live VPS with a public IP/domain, UDP firewall rules, Godot engine, and Node.js are required. Latency depends on physical location and route, network conditions, device performance and server resources; zero lag cannot be guaranteed.

## VPS setup (Ubuntu example)

1. Use a Linux VPS with publicly reachable IPv4 and a current Godot 4.7 Linux binary (the `godot` CLI; can be a compatible headless/server build) and Node.js >= 20. No npm install is required.
2. Unzip the complete project on the VPS (must contain `project.godot`, `Main.tscn`, `scripts/game.gd` and the `server/` folder). E.g. `/opt/pixel-zombie/`.
3. On the VPS, configure values using environment variables, then start room API:

   ```bash
   cd /opt/pixel-zombie/server
   export API_PORT=8080
   export API_BIND=127.0.0.1
   export GAME_PUBLIC_HOST=game.example.com
   export GAME_PORT_START=25000
   export GAME_PORT_END=25099
   export MAX_ROOMS=12
   export GAME_SNAPSHOT_HZ=45
   export GODOT_BIN=/usr/local/bin/godot
   node index.js
   ```

4. DNS: make `game.example.com` point to the VPS **public IPv4**. If using a reverse-proxy/CDN, ENet/UDP still needs direct UDP access to the VPS; HTTPS proxying alone does **not** forward UDP. Do not advertise a private address like `127.0.0.1` or `192.168.x.x` as `GAME_PUBLIC_HOST`.
5. Open only the gameplay UDP range externally, e.g. `sudo ufw allow 25000:25099/udp`. For production, place the API behind HTTPS on port 443, e.g. Caddy:

   ```caddy
   api.example.com {
       reverse_proxy 127.0.0.1:8080
   }
   ```

   Point `api.example.com` to the VPS and allow TCP 80/443 for certificate issuance. Keep `API_BIND=127.0.0.1` so game-server internal endpoints are not directly exposed. In the APK, choose **MAIN ONLINE GLOBAL > SERVER API URL** and enter `https://api.example.com`.
6. Test API health: `curl https://api.example.com/health`, which returns `{"ok":true,"rooms":0}` if empty. Creating a room launches another Godot process, which reports readiness through localhost; only then the APK connects to its assigned UDP port.
7. Verify with **two actual devices** on *different* networks (e.g. Wi-Fi and mobile data): create, join using the six-character code, start, shoot zombies, disconnect and rejoin while lobby still open. Use phone network stats (RTT, loss, snapshots) for performance tuning.

For a quick **development-only** test on a trusted network, you can run `API_BIND=0.0.0.0` and use `http://VPS_IPV4:8080`. Keep port 8080 restricted to test clients; use HTTPS in production. Android versions / export settings may block plaintext HTTP via network security policy. HTTPS is recommended and tested at the transport API level.

## API contract

All JSON POST calls use `Content-Type: application/json`:

- `GET /health` -> `ok`, `rooms`.
- `POST /api/rooms/create` `{}` -> `code`, `ticket`, `owner:true`, `ready:false|true`.
- `POST /api/rooms/join` `{"code":"ABC234"}` -> `code`, `ticket`, `owner:false` (errors for not found/full/started).
- `POST /api/rooms/connect` `{"code":"ABC234","ticket":"..."}` -> `ready`, and once ready `host`, `port`.
- `/internal/ready`, `/internal/validate`, `/internal/disconnected`, `/internal/started` -> localhost only, require `X-Server-Secret` injected into the room process and matching `code`.

The owner ticket is single-use; all tickets expire if unused after 45 seconds (configurable in Node). Authenticated players are tracked by their Godot peer ID; no anonymous peer is put into the world. Game state/restart is controlled by Godot server and only room owner can start/restart. In the lobby, the owner role transfers when the current owner disconnects. The code is **an invite code**, not a password against anyone who knows it.

## Behavior / limitations

- Max four players **per room**. Max rooms configurable; each takes RAM/CPU as a separate Godot process.
- New join requests are rejected after match starts. No reconnect-to-running-game or persistent account system in this iteration.
- Server process is stopped when room goes idle (default about two minutes after no active players); active rooms are not killed by the idle sweeper.
- Room directory and tickets live in process memory. Restarting the Node coordinator drops room state. Use a process manager (`systemd`) to keep it up; for horizontal scale add Redis/database + durable room orchestrator.
- Online mode does not use local save; solo still does. The original LAN mode remains available as a separate legacy option until online is verified.
- Godot simulates at a fixed 60 physics ticks/sec, and sends ~45 snapshots/sec by default (`GAME_SNAPSHOT_HZ` 20-60 can be tuned, affecting bandwidth, CPU usage and smoothness). One `GAME_PUBLIC_HOST` is returned for every room. For global matchmaking, multiple geographic regions are a later enhancement; this release is a single-region dedicated server.
- No entitlement/accounts, DDoS protection, moderation, matchmaking or persistent inventory. HTTP API has basic per-IP request throttling; use firewall/reverse-proxy protections for production.

## Quick checks

```bash
cd /opt/pixel-zombie/server
npm test
node --check index.js
# With Godot 4.7 installed:
godot --headless --path /opt/pixel-zombie --editor --quit
GODOT=godot bash /opt/pixel-zombie/tools/net_test/run_loopback.sh wifi 15 10 2
```

The `--editor --quit` check imports assets; don't use `--editor` to run an actual live headless room. The lobby coordinator launches `godot --headless --path ...` with its room environment variables, never a client screen. The second network test exercises the original LAN snapshot protocol only. To validate online integration, test API + Godot with actual devices, including dropping cellular connectivity and reconnecting.

## Security notes

- HTTPS protects tickets in transit. Don't put tickets in URLs or logs.
- Keep internal API on loopback and do not leak `PZ_INTERNAL_SECRET`.
- Run Node and Godot under a **non-root** user with limited permissions.
- UDP game traffic isn't encrypted by ENet by default. For sensitive data or public-scale deployment, use an authenticated/encrypted transport design.
- Rate limit and harden public network access at the VPS/reverse proxy; code does not guarantee resistance to deliberate flooding.
