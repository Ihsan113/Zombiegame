# Pixel Zombie Online v0.6.4 — Node.js + WebSocket

> Based on the supplied `PixelZombieOnline_v0.5.0_CI_Fixed(1).zip` source. This is **source code**, not a finished APK or a live internet service.

## Goal / Visi & Misi

- **One server address** entered once inside the Android app, for example `http://YOUR_PUBLIC_IP:2186`. The app automatically maps it to `ws://YOUR_PUBLIC_IP:2186/ws` for gameplay. HTTPS maps to secure `wss://`.
- **Server-authoritative simulation in Node.js only**. No Godot binary or UDP port is needed on the host. The Android **client remains Godot**.
- Private six-character room codes, single-use 45-second tickets, four players per room, owner-only start/restart, automatic room isolation and cleanup.
- Fast realtime updates: 60 Hz *simulation* and 30 Hz compact binary *snapshots*, client-side prediction/reconciliation/interpolation already present in Godot, WebSocket over the same single TCP port as the HTTP API.
- Preserve Android UI/solo/LAN and main graphics. Add explicit **TEMPEL** paste buttons in online API/room-code dialogs and LAN IP dialog.

**Performance honesty:** WebSocket real-time does not imply identical latency to UDP. Packet stalls/loss on TCP can create latency spikes. Target rates are not a guarantee of smooth FPS on every phone/network.

**Gameplay parity honesty:** v0.6.4 fixes major LAN/online discrepancies in turret barrel origin, grenade throws, barricades, weapon FX, zombie/boss timings and drop/audio behavior. It still ports the core server-owned systems for player movement, waves and zombies (including bosses), HP/damage, fire/weapon ammo, basic turret behavior, barricades, grenades and supply drops. It does **not yet fully reproduce** every nuanced Godot v0.5.0 behavior/animation/audio/AI path (e.g., specialized boss attack choreography, turret collision nuance, airdrop replacement subtleties). Such features require comparative playtesting and follow-up parity patches.

## Run API and realtime server in Termux + Ubuntu

Requires **Node.js 22+**. Godot is **not installed on the server**.

```bash
cd /path/to/PixelZombieOnline/server
node -v                # v22.x or higher
npm test               # Tests use built-in Node APIs; no npm install needed
API_BIND=0.0.0.0 API_PORT=2186 MAX_ROOMS=4 node index.js
```

Single port `2186/TCP` carries both `http://.../health` and the WebSocket endpoint `ws://.../ws`.

Open `http://127.0.0.1:2186/health` on the same phone, then enter `http://127.0.0.1:2186` in the **new v0.6.4 APK** for a same-phone test. For another phone on the same Wi-Fi, use the host phone's actual Wi-Fi LAN IPv4 address instead of `127.0.0.1` and ensure the same TCP port is accessible.

For global hosting: configure public TCP routing/port/firewall for 2186 and preferably a domain with HTTPS / WSS TLS termination. `http://` / `ws://` is **unencrypted**; avoid sharing room tickets over insecure public networks. A plain TCP proxy must allow WebSocket Upgrade and longer-lived connections.

**Important:** The existing v0.5.0 client APK (ENet/UDP) **cannot** connect to this server. Export a new Android APK from this v0.6.4 Godot project. The old server scripts inside `docs/` are archived for historical reference only.

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

## Server URLs in the terminal (v0.6.1)

On startup the Node.js server now prints the listening TCP port, localhost URL, local network IPs, and public URL if one is actually configured or exposed by hosting. Enter the **base HTTP URL** shown in the log in the Android server field; do not include `/health` or `/ws`. When the server is on the same phone use `http://127.0.0.1:2186`. On Wi-Fi use the phone’s local IP shown at startup.

Pterodactyl automatically provides `SERVER_PORT` in many eggs, and some expose `SERVER_IP`. If the allocated public IP is unavailable from the container, `PUBLIC_URL=http://YOUR_PUBLIC_IP:YOUR_PORT` can be provided explicitly, or read your allocation in the hosting control panel. Public IP reachability cannot be guaranteed by an informational banner. GET `/` now also returns a `server_url` derived from the URL used to open the server in the browser.

## Server update v0.6.2 — `.env` untuk port (game APK tetap v0.6.1)

Backend Node.js sekarang memuat `server/.env` secara otomatis. Cukup edit `API_PORT=2186` ke nomor TCP port yang dipakai, lalu restart server; tidak perlu mengubah `server/index.js`. Contoh file cadangan tersedia di `server/.env.example`. Pada Pterodactyl, `SERVER_PORT` yang ditetapkan panel diutamakan daripada `API_PORT`, karena game tidak dapat mendengarkan pada port yang belum dialokasikan hosting. Nama versi game/Android tetap **0.6.1-online** karena client/protokol tidak diubah. Lihat `server/README.md` untuk detail.


### Backend Node.js v0.6.3: deteksi IP publik keluar
Folder `server/` kini melakukan lookup HTTPS non-blocking ke ipify (fallback
icanhazip) pada startup dan menampilkannya di console. IP keluar tidak selalu
sama dengan IP/port yang bisa diakses pemain; alokasi Pterodactyl atau
`PUBLIC_URL` tetap lebih dapat diandalkan. Atur `PUBLIC_IP_LOOKUP=0` dalam
`server/.env` untuk mematikan fitur ini. Tidak ada perubahan ke APK Godot.

## v0.6.4: LAN/offline versus Online Global verification

This release ports the **stable LAN formulas** to Node authoritative simulation where the former online simplifications visibly diverged. Key regressions are in `server/test/gameplay_parity.test.js`. LAN/solo GDScript logic and game art are left intact.

**Important deployment:** update **both** the backend server and Android APK. `game.gd` now handles online visual turret firing and server audio/feedback events; an APK built from older source may fail to render those improvements. `server/geometry.js` is now an **essential runtime file**; upload it alongside `index.js`, `game.js`, `codec.js`, `websocket.js`, `config.js`, and `network_info.js`. Stop server, back up `.env`, upload/extract new server ZIP, restore `.env`, start, verify `/health`, then launch v0.6.4 APK. No UDP is required.

Gameplay equivalence is not yet a certification of every animation, difficulty curve or interaction. Test as a group on real Android phones, including turret aim left/right, grenade aim/throw at both extremes, barricade placement chains, weapon pickup/replacement and a wave-10 boss. This container has no Godot executable, so parser/Android export and physical playtests remain outstanding.
