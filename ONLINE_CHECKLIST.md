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
