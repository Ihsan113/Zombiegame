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


## 0.4.8 — LAN client responsiveness (compact snapshots, interpolation, reconciliation)
Root causes fixed (client felt delayed while the host felt instant):
- **Own survivor was pulled back to stale host positions.** Prediction is now real client-side prediction with server reconciliation: the client sends sequence-numbered movement commands (redundantly resent), the host acknowledges the last applied command in each snapshot, and the client replays unacknowledged commands on top of the authoritative position. Only genuine disagreement is corrected, smoothly.
- **World snapshot was a large Dictionary RPC (several KB, split into many fragments).** One lost fragment dropped the whole snapshot. Snapshots are now a packed binary format (positions as 1/8 px uint16, no repeated key strings) of at most 1180 bytes (typically 150–600 B), always a single datagram, sent at ~30 Hz.
- **Remote survivors and zombies were chased with `lerp` toward the newest snapshot.** The client now keeps a timestamped snapshot buffer and renders slightly in the past (adaptive 75–300 ms from measured jitter), interpolating between two snapshots, with up to 120 ms extrapolation if snapshots starve.
- **Shots had no local feedback.** Muzzle flash, tracer, shot sound and gun animation are predicted instantly on the shooter's device. Effects and sounds from the host are carried redundantly (loss-tolerant, de-duplicated by id) and scheduled on the render timeline so they line up with interpolated entities.
Other changes:
- Host rejects inflated movement time (per-player time budget), so a modified client cannot speed-hack.
- ENet unreliable-packet throttling is disabled so Wi-Fi RTT spikes do not make ENet drop snapshots.
- Clients with a different screen aspect ratio than the host now see the host world scaled consistently (host world size is sent in every snapshot).
- Pausing no longer leaves a remote survivor walking on the host (movement is time-bounded commands, not a sticky vector).
- Remote fire cooldown tolerance (220 ms vs 280 ms) absorbs Wi-Fi jitter so valid shots are not rejected.
- On-screen network readout for clients (RTT, snapshot loss, snapshots/s, KB/s, interpolation buffer, prediction error); set `SHOW_NET_STATS := false` to hide it.
- Added `tests/codec_test.gd` (CI) and `tools/net_test/` (loopback host+client test with delay/jitter/loss proxy).
- RPC signatures changed: **all devices must install v0.4.8 together** (older builds cannot join).
- Android version code/name: 21 / 0.4.8.


## 0.4.9 — smooth movement on both sides (host view of clients)
- **Host saw client survivors stutter.** Remote survivors only moved when a command packet arrived, and the host drew that position directly (a staircase, uneven with Wi-Fi jitter). The host now draws them from a jitter-adaptive track built from the commands' own durations (virtual time), interpolated slightly in the past. Measured: frozen frames 50-57 % -> 2-3 %, speed variation 1.0-1.3 -> ~0.2 (clean, 15+-10 ms/2 % loss and 30+-20 ms/6 % bursty loss links).
- Movement commands and world snapshots now run at up to 60 Hz (~11 KB/s total); client interpolation floor lowered to 50 ms, so remote survivors/zombies are drawn ~35-40 ms closer to real time.
- Send timers tolerate half a frame and no longer alternate 33/50 ms.
- Gameplay stays host-authoritative: zombie targeting, hits, speed-hack budget and snapshots use the exact position; only drawing is smoothed.
- CI markers updated (60 Hz constants, host-view functions).
- **All devices must install v0.4.9 together.** Android version code/name: 22 / 0.4.9.


## 0.4.10 — barricade grounding
- Barricade no longer looks like it floats over the asphalt: per-foot contact shadows and a footprint-shaped cast shadow replace the flat ellipse and ground line; slight dusk tint on the sprite.
- Placement preview uses the same grounding plus a flattened ring on the road.
- Visual only (no RPC/gameplay change). Android version code/name: 23 / 0.4.10.


## 0.4.11 — barricade faces the zombies
- Re-rendered barricade art: stands across the lane, A-frame profile toward the viewer, hazard panel receding into the screen (reference angle).
- Wall geometry updated: `WALL_ATTACK_RANGE` 71 -> 50, `WALL_LANE_TOLERANCE` 34 -> 46, draw rect 60x88 with foot-anchored shadows, new HUD icon aspect, depth sort fixed (`wall.y + 2`), damage tint instead of fixed crack lines.
- No RPC/network change. Android version code/name: 24 / 0.4.11.


## 0.4.12 — cinematic grenade blast, fading death remains, and timed supply drops
- Reworked grenade impact into a multi-stage flash/fireball, road-level shockwave, deterministic hot fragments, flying dark debris and rising smoke. Effect kind `6` and the compact snapshot format are unchanged.
- Added client-local survivor death animation: fade/collapse, then skull/rib/spine/limb remains that slowly fade. This adds no network state and does not touch host-authoritative HP.
- Landed airdrops now last 22 seconds, display remaining time and a final-six-second flashing warning, then dissolve with a synchronized dust puff if not collected.
- Preserved v0.4.11 ENet settings, input/snapshot rates, binary record sizes and RPC signatures. Android version code/name: 25 / 0.4.12.


## 0.4.13 — aligned barricades and textured grenade blast
- Replaced the 132 px barricade-distance rule with rendered-footprint overlap checks. Barricades can form tight rows while their sprite bounds still cannot overlap.
- Added snap-to-neighbour for wall previews dragged near an existing barricade end. Candidate placements keep the same lane depth and still pass distance/range/overlap validation.
- Added `assets/grenade_explosion_asset.png` (with editable SVG source alongside it), a transparent explosion sprite used by the grenade renderer with animated scale and opacity. Existing deterministic shockwave, ember, debris, and smoke layers remain.
- Preserved multiplayer snapshot field sizes and ENet settings. Android version code/name: 26 / 0.4.13.

## v0.4.14 — Generated explosion and airdrop assets

- Integrated generated grenade explosion art into the existing host-synchronized explosion effect.
- Added generated parachute and supply-crate textures with SVG fallbacks.
- Added a generated ground-level dust sprite to the synchronized airdrop expiry puff.
- Preserved original generated sprite sheets under `assets/*_spritesheet_source.png` for future frame slicing.
- Kept host-authoritative gameplay and the compact LAN snapshot protocol unchanged.


## 0.4.15 — VFX asset integration polish
- Replaced the grenade explosion image with a truly transparent, ground-hugging generated pixel-art blast, cropped/resized with alpha-aware processing and no opaque warm background.
- Reduced shock-ring diameter and outline weight; toned down overlapping procedural fragments and smoke to avoid an oversized circular overlay.
- Replaced the airdrop crate texture with a worn muted olive/rust supply crate and preserved texture proportions while aligning its base to the road.
- Merged loot type and remaining time into a single small landed-drop tag instead of two stacked labels.
- No multiplayer protocol or network-configuration changes. Android version code/name: 27 / 0.4.15.
