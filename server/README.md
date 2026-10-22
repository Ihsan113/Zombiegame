# Node.js-only Pixel Zombie Online room + WebSocket server

No Godot binary, no UDP, no extra npm packages. Requires Node.js 22+.

```bash
cd server
npm test
API_BIND=0.0.0.0 API_PORT=2186 MAX_ROOMS=4 node index.js
```

Test `curl http://127.0.0.1:2186/health`. Expect `{ "ok": true, "mode": "node-websocket", ... }`.

API: POST `/api/rooms/create` (`{}`) -> `code` + single-use `ticket`; POST `/api/rooms/join` (`{"code":"ABC234"}`) -> ticket; POST `/api/rooms/connect` (`{"code":"...","ticket":"..."}`) -> `transport:websocket`, `path:/ws`.

The client connects to `ws://<same-host>:<same-port>/ws` (or `wss://` for HTTPS), sends `{"type":"auth","code":"...","ticket":"..."}`. Server returns `welcome`, `members`, then sends compact 30Hz binary state. Movement is a binary packet containing 1-byte count followed by repeated 8-byte little-endian sequenced commands. Actions are JSON text. Node simulates authoritative movement, combat, zombies, waves, pickups, and buildables at 60 fixed ticks/s.

Each active room has its own `GameRoom` instance in one Node.js process. Defaults: 12 rooms maximum, four players per room, 45-second ticket reservation, 2-minute empty-room cleanup. Tuning: `MAX_ROOMS`, `API_PORT`, `API_BIND`, `GAME_IDLE_MS` (idle override to add if needed). Only TCP port `API_PORT` is required.

Set external firewall to allow TCP 2186 (or chosen port). `API_BIND=0.0.0.0` exposes the service to the network; use TLS/wss, firewall and authentication precautions on public servers. No UDP port, port-forwarding per-room, or GODOT_BIN is needed. Note 60Hz and 30Hz are update targets, not guaranteed latencies. Explicitly untested: real Android APK export and multi-device wide-area performance.
