# Changelog

## 0.4.3 — infinite ammo, aimable grenades, and deployable barricades
- Switched to infinite ammunition and changed HUD to `AMMO ∞`; removed ammo-consuming fire logic.
- Replaced ammo drops with useful randomized grenade, wall-kit, and medkit drops. Capped loot converts to medkits or HP; old saved ammo drops migrate to a grenade cache.
- Added grenade aim mode, a range slider, estimated distance, dotted ballistic arc, landing crosshair, throw/cancel steps, normalized multiplayer range requests and range-dependent trajectory/fuse.
- Added wall placement preview with drag-to-position, green/red validity feedback, place/cancel controls and host-side checks for distance, lane, inventory, overlap and active barrier count.
- Added detailed transparent SVG assets for fragmentation grenade, braced timber barricade, military supply crate and parachute canopy.
- Updated all relevant reset paths for new targeting states; Android version code/name 16 / 0.4.3.

## 0.4.2 — tighter lane, grenades, loot drops and barricades
- Moved the upper playable boundary closer to the background's sidewalk/road seam while keeping the character ground point on asphalt. The lower edge remains clamped before the foreground curb and fence.
- Added a three-grenade starting inventory and a dedicated touch button. A thrown grenade arcs forward, then explodes with area damage and synced sound/visual effects.
- Added randomized supply crates and buildable, destructible timber barricades.
- Added procedural sound effects for grenade toss, explosion, supply drop, wall placement, wall break, and pickup.

## 0.4.1 — lane bounds, wave clock, game over and SFX
- Added per-wave countdown and overtime, squad-wide Game Over, clean restart, explicit save/continue, and original procedural WAV cues.

## 0.4.0 — arena and animation
- Added a more complete horror backdrop, lower-lane bounds, animated walk/attack/hurt visuals and horror-themed UI.


## 0.4.4 — CI validator correction
- Fixed the airdrop loot label match to declare grenade loot explicitly and satisfy the existing semantic marker checks.
- Legacy saved ammo drops now label as grenade loot because ammunition is unlimited.
- Android version code/name: 17 / 0.4.4.


## 0.4.5 — A-frame barricade and one-gesture controls
- Replaced the square barricade art with a weathered A-frame roadside barrier and retuned its render size/shadow/health bar.
- Grenade control is hold-drag-release, with a 2D landing point, ballistic-style dotted preview, reticle and range readout. The host validates normalized X/Y target coordinates.
- Wall control is hold-drag-release, previewing the A-frame sprite in green/red and deploying on release only when valid. Removed separate range slider and placement-confirm controls.
- Bumped Android version code/name to 18 / 0.4.5.


## 0.4.6 — LAN smoothing and grounded grenade/barricade visuals
- Barricade image enlarged proportionally and anchored to the ground with a stronger contact shadow; placement preview matches placed size. Adjusted obstacle spacing and zombie approach distance.
- Removed long vertical-looking projectile line. Added short directionally placed spark particles and ground shadow. Rebuilt explosion feedback with a fireball, expanding shockwave rings, radial sparks and smoke.
- Added local movement prediction and gentle authoritative correction for joining clients, smoothed zombies across snapshots, 30 Hz input cadence, ~15 Hz world snapshots and FastLZ compression. Kept fire requests reliable on a dedicated ENet channel and removed the extra full-world broadcast after every shot to reduce packet bursts.


## 0.4.7 — ENet compression API fix
- Replaced the invalid `ENetMultiplayerPeer.COMPRESS_FASTLZ` reference with `ENetConnection.COMPRESS_FASTLZ`.
- Set compression via the created peer's `host.compress(...)` for both host and client, before attaching the peer to the MultiplayerAPI.
- Added a CI guard against the invalid API spelling; bumped Android version code/name to 20 / 0.4.7.
