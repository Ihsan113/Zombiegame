# Pixel Zombie Online v0.6.0 — Node.js + WebSocket

> Based on the supplied `PixelZombieOnline_v0.5.0_CI_Fixed(1).zip` source. This is **source code**, not a finished APK or a live internet service.

## Goal / Visi & Misi

- **One server address** entered once inside the Android app, for example `http://YOUR_PUBLIC_IP:2186`. The app automatically maps it to `ws://YOUR_PUBLIC_IP:2186/ws` for gameplay. HTTPS maps to secure `wss://`.
- **Server-authoritative simulation in Node.js only**. No Godot binary or UDP port is needed on the host. The Android **client remains Godot**.
- Private six-character room codes, single-use 45-second tickets, four players per room, owner-only start/restart, automatic room isolation and cleanup.
- Fast realtime updates: 60 Hz *simulation* and 30 Hz compact binary *snapshots*, client-side prediction/reconciliation/interpolation already present in Godot, WebSocket over the same single TCP port as the HTTP API.
- Preserve Android UI/solo/LAN and main graphics. Add explicit **TEMPEL** paste buttons in online API/room-code dialogs and LAN IP dialog.

**Performance honesty:** WebSocket real-time does not imply identical latency to UDP. Packet stalls/loss on TCP can create latency spikes. Target rates are not a guarantee of smooth FPS on every phone/network.

**Gameplay parity honesty:** This version ports the core server-owned systems for player movement, waves and zombies (including bosses), HP/damage, fire/weapon ammo, basic turret behavior, barricades, grenades and supply drops. It does **not yet fully reproduce** every nuanced Godot v0.5.0 behavior/animation/audio/AI path (e.g., specialized boss attack choreography, turret collision nuance, airdrop replacement subtleties). Such features require comparative playtesting and follow-up parity patches.

## Run API and realtime server in Termux + Ubuntu

Requires **Node.js 22+**. Godot is **not installed on the server**.

```bash
cd /path/to/PixelZombieOnline/server
node -v                # v22.x or higher
npm test               # Tests use built-in Node APIs; no npm install needed
API_BIND=0.0.0.0 API_PORT=2186 MAX_ROOMS=4 node index.js
```

Single port `2186/TCP` carries both `http://.../health` and the WebSocket endpoint `ws://.../ws`.

Open `http://127.0.0.1:2186/health` on the same phone, then enter `http://127.0.0.1:2186` in the **new v0.6.0 APK** for a same-phone test. For another phone on the same Wi-Fi, use the host phone's actual Wi-Fi LAN IPv4 address instead of `127.0.0.1` and ensure the same TCP port is accessible.

For global hosting: configure public TCP routing/port/firewall for 2186 and preferably a domain with HTTPS / WSS TLS termination. `http://` / `ws://` is **unencrypted**; avoid sharing room tickets over insecure public networks. A plain TCP proxy must allow WebSocket Upgrade and longer-lived connections.

**Important:** The existing v0.5.0 client APK (ENet/UDP) **cannot** connect to this server. Export a new Android APK from this v0.6.0 Godot project. The old server scripts inside `docs/` are archived for historical reference only.

## Build Android

1. Open this folder using **Godot 4.7.2**, import all assets. Enable Android SDK/JDK and Android export templates.
2. Use the `Android` preset in `export_presets.cfg` to export the APK; GitHub Actions also builds after upload of the complete project.
3. If Android blocks cleartext `http://` on a particular OS/manifest configuration, use an HTTPS domain with WSS or configure the Android network security policy in a custom Android export template. This server does not provide TLS itself.
4. In the APK tap `MAIN ONLINE GLOBAL`, `SERVER API URL`, **TEMPEL**, `CHECK API STATUS`, then `CREATE ROOM` or `JOIN ROOM`.
5. Only the room owner can start a match. A single TCP port handles both control and snapshots.

## Files

- `server/index.js` — HTTP room service, WebSocket upgrade, authentication/ticket lifecycle, rate limits and cleanup.
- `server/websocket.js` — small RFC6455 frame server using Node core modules (no `ws` dependency).
- `server/game.js` — Node-owned 60-tick authoritative game simulation.
- `server/codec.js` — compact little-endian snapshot encoder matching Godot `_decode_snapshot` and sequenced movement command parser.
- `server/test/api.test.js` — end-to-end Node HTTP/WS tests; run with `npm test`.
- `scripts/game.gd` — Android front end, WS client, binary input, binary snapshot interpolation, dedicated paste buttons.
- `.github/workflows/android.yml` — Android CI and backend tests.
- `docs/` — previous v0.5.0 deployment reference, not applicable to WebSocket v0.6.0.

## Security / limitations

Tickets are randomly generated and stored only as SHA-256 hashes in memory. Authenticated peers are bound to their connection and own server-side player IDs. Input time is limited; actions are cooldown-, distance- and inventory-validated by Node. Tickets, rooms and gameplay data are in-memory; restarting Node clears all rooms. Reconnection mid-match, persistent player profiles, autoscaling/multi-process clustering, monitoring and anti-DDoS protection are not included. For production, add TLS/WSS, reverse-proxy upgrade support, protection against overload, and device tests under realistic lag/loss.

**Testing:** Node-level HTTP/WS protocol/simulation tests pass. The execution environment used to create this ZIP does **not contain a runnable Godot executable or Android SDK**, so a full Godot editor parse, APK export, or two-physical-phone game test was **not** performed here. Treat this as a testable migration build, not a claimed AAA-quality verified release.
