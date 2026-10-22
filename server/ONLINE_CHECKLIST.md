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

### v0.6.2: Konfigurasi port lewat .env

- [x] Backend membaca `.env` di samping `index.js` tanpa npm dependency tambahan.
- [x] `API_PORT` ditentukan dari file, bukan angka hardcoded di startup script.
- [x] `SERVER_PORT` dari panel mengutamakan alokasi jaringan hosting.
- [x] Pengujian port, pembacaan file, serta boot dari working directory berbeda.
- [ ] Tes pergantian port melalui Termux dan Pterodactyl sesuai alokasi yang diizinkan.

- [ ] Pastikan IP publik terdeteksi adalah **egress**, bukan jaminan port masuk terbuka.
- [ ] Bandingkan URL dari panel Pterodactyl dengan IP terdeteksi; tes `/health` dari jaringan lain.

### v0.6.4 game parity
- [x] Turret authoritative yaw/muzzle and client flash match stable LAN geometry.
- [x] Grenade throws, walls/turret placement, ammo, weapon types, crate ownership and boss windups regression-tested.
- [x] Snapshot effect age corrected; stale VFX filtered.
- [ ] Parse/export Godot Android app and test actual 2–4-player gameplay on two networks.
