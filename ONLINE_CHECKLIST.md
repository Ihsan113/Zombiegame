# Online WebSocket v0.6.0 checklist

- [x] HTTP room API and WS upgrade use exactly one TCP port.
- [x] Random one-use tickets, server-side player IDs, 4 seats maximum.
- [x] Node.js owns state changes, input validation, damage, zombies, waves, pickups and buildables.
- [x] 60Hz fixed-step Node simulation; 30Hz bounded binary snapshots; existing client interpolation and local prediction retained.
- [x] Android SERVER API URL accepts `http://` / `https://` and derives WS/WSS on the same port.
- [x] Explicit large TEMPEL buttons for URL, room code and legacy LAN IP.
- [x] Automated Node HTTP/WS end-to-end tests.
- [ ] Run Godot 4.7.2 headless import/parse against final source.
- [ ] Export and install Android APK.
- [ ] Physical test: two Android phones create/join across Wi-Fi then separate Internet networks.
- [ ] Test Android clipboard with a real keyboard, locale and OS permissions.
- [ ] Test overloaded server, RTT variation, loss/stalls, reconnect, pause/resume, battery.
- [ ] Compare all v0.5.0 weapon/AI/boss/drop/turret audio and gameplay rules and close parity gaps.
- [ ] Production TLS WSS reverse proxy, monitoring, persistent sessions and anti-abuse hardening.

### v0.6.1: URL in console

- [ ] Check startup log for `Alamat di HP ini` and `IP lokal`, with `URL publik/hosting` if configured.
- [ ] Check `http://HOST:PORT/` to see copyable `server_url`.
- [ ] On public hosting, check Network allocation/port and supply `PUBLIC_URL` if the panel does not pass `SERVER_IP`.

### Server v0.6.2 (.env)

- [x] `server/.env` disertakan untuk mengatur `API_PORT`, `API_BIND` dan `MAX_ROOMS`.
- [x] Port tidak lagi memiliki angka fallback di `server/index.js`.
- [x] Prioritas `SERVER_PORT` panel, lalu `API_PORT`, kemudian `PORT`.
- [x] Node test dan test boot menggunakan `.env`.
- [ ] Validasi port real dari Network allocation Pterodactyl.

### v0.6.4 gameplay parity and real-phone gate

- [x] Stable LAN/offline authoritative formulas compared to Node gameplay for turret barrel, grenade range, placement, weapon FX, airdrop ammo and boss windups.
- [x] Node regression suite includes effect lifetime/wire clock, shot origin both turret facings, valid maximum grenade range and distinct projectile types.
- [x] Client online turret flash/audio/feedback added without changing LAN/offline physics.
- [ ] Run Godot 4.7.2 import/script parse and export Android debug APK.
- [ ] Test 2-4 Android phones over mobile data/Wi-Fi. Check smoothness and boss/turret/weapon/airdrop visuals while profiling server CPU and websocket traffic.
