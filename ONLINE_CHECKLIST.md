# Checklist: Online Global integration (0.5.0-online)

## Implemented in source

- [x] Home button: MAIN ONLINE GLOBAL; original LAN and solo buttons remain.
- [x] Android dialog for configuring HTTP/HTTPS room API; saved locally in `user://settings.cfg`.
- [x] API health status, create private room, join using six-character code, copy code, leave/cancel.
- [x] Node.js HTTP room service (no npm dependencies): random invite code, non-reusable random ticket, room reservation/occupancy cap, per-room Godot process, idle cleanup, basic per-IP throttling.
- [x] Headless Godot dedicated authoritative simulation; 4 remote players and no phone host; game logic shares existing `scripts/game.gd`.
- [x] Lobby admission ticket check over localhost API; unauthenticated peers never become players; 8-second pending timeout.
- [x] Creator/owner-only start and restart; owner transfers on disconnect when other players are already in the room.
- [x] Preserve existing compact ENet UDP packets, buffered prediction, reconciliation and interpolation; dedicated 60 physics ticks/s, default 45 snapshots/s.
- [x] Reject new entrants after game has started; clean lobby/session separation.
- [x] Node.js integration tests passed: room creation, ready, joining, owner/friend ticket validation, replay blocking, missing/invalid/full room, capacity, expired tickets and departure.
- [x] Static code checks: no duplicate function declarations, balanced delimiters; modified files zipped.

## Required before production use

- [ ] Compile/run Godot **4.7.2** project and review editor/headless errors (Godot binary unavailable in this build environment).
- [ ] Build Android APK using Godot Android export templates; source ZIP contains no APK.
- [ ] Deploy on public VPS with Node >=20 and Godot 4.7.2 binary; set `GAME_PUBLIC_HOST`, UDP range and HTTPS reverse proxy.
- [ ] Verify fresh room connects, owner and guest enter lobby, gameplay starts, snapshot movement/zombies/damage sync, owner restart, drops/disconnects, many concurrent rooms.
- [ ] Exercise 2-4 real phones over Wi-Fi + mobile data; measure RTT, loss, rubber-banding and bandwidth; tune 20-60 Hz snapshots and select a region close to players.
- [ ] Harden backend for production: persistent room coordination, metrics, anti-DDoS, monitoring and encrypted/authenticated gameplay transport if needed.

**Why not claim zero lag?** Physical RTT, congestion, frame timing, radio packet loss and VPS resources cannot be eliminated by code; the implemented prediction/interpolation reduces visual hitches but requires real-world testing to quantify.
