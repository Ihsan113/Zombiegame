# Implementation notes — v0.4.8

- Target: Godot 4, landscape Android; 4-player host-authoritative ENet/UDP LAN on port 24567.
- `assets/barricade_detail.png` is the transparent A-frame road barrier; SVG is its fallback. Both render at 120×72, preserving the asset's 720×433 aspect ratio. With the game entity position at the same center convention as a survivor, the barrier's feet and a wider contact shadow reach the ground line. Wall placement preview shares the same dimensions. Minimum spacing is 132 px and zombie attack distance is tuned to engage at the outside edge.
- Grenade visuals do not draw a line between ground position and airborne sprite. Ground shadow remains on the asphalt while two small sparks trail along the launch-to-target direction. Joining clients render grenade elapsed time using time since the last snapshot, improving projectile smoothness. Explosion includes a fireball, shock rings, radial sparks, ground scorch/shadow and smoke puffs.
- Clients predict their own survivor movement each frame and gently reconcile it against host authority. Other survivors interpolate at snapshot cadence; zombie snapshots merge by stable ID and interpolate X/Y rather than replacing all displayed positions.
- Input cadence is ~30 Hz; host snapshot cadence is ~15 Hz. ENet FastLZ compression is configured on both host and client before the peer is created. `request_fire` is reliable on its own ENet channel (this note previously said unreliable-ordered, which did not match the code); firing does not trigger an extra world snapshot. Grenade/wall/heal requests remain reliable actions.
- Static CI checks resource paths, settings, gameplay markers, SVG XML and WAV formats, then imports and launches the scene headless before APK export. No Godot binary is installed in the current editing environment, so CI and hardware testing remain the authoritative compile/runtime checks.


## v0.4.7 compression correction
- In Godot 4.7.2, `ENetMultiplayerPeer` exposes the underlying `ENetConnection` via `host`; compression is configured by `host.compress(ENetConnection.COMPRESS_FASTLZ)`.
- Configure this after `create_server()`/`create_client()` returns `OK` and before assigning the peer to `multiplayer.multiplayer_peer`. Host and all clients must use the same compression mode.
- CI now fails if the old invalid constant/property spelling appears or if host/client compression setup differs.


## v0.4.8 networking model
- **Wire format.** `receive_world(buf)` (unreliable-ordered, ~30 Hz) carries `_encode_snapshot()`: 31-byte header (magic, flags, seq, host ms, host world size, wave state), then counted sections for survivors, zombies, barricades, supply drops, grenades and recent effects. Capped at `MAX_SNAPSHOT_BYTES` (1180) so ENet never fragments it. The same bytes are sent reliably as `receive_initial_world` (join) and `receive_game_over_snapshot`.
- **Client -> host.** `submit_input(buf)` (unreliable-ordered, ~30 Hz) carries up to 8 un-acked commands `(seq u32, qx i8, qy i8, dt u16 in 0.1 ms)`. The host applies commands with `seq > last_applied`, limits total movement time to real time x 1.12 (budget), and writes `last_applied` back as `ack` in the survivor record.
- **Client view.** `_ingest_snapshot` stores snapshots and aligns clocks (minimum receive-host offset; excess = jitter). `_client_update_render` renders at `now - offset - interp_delay`, interpolating between the bracketing snapshots (extrapolating <= 120 ms when starved) and rebuilding `players/zombies/barricades/airdrops/active_grenades/combat_effects` for the unchanged drawing code. Positions are scaled by `screen / host_world` so different aspect ratios stay consistent.
- **Prediction.** Own survivor = `pred_pos`: advanced every frame by the same quantized command vector the host will apply; `_reconcile_local` replays un-acked commands on the acked authoritative position and bleeds any difference in (snaps above 90 px).
- **Verification performed (Godot 4.7.2 headless, real UDP loopback, impairment proxy).** Codec round-trip + size tests, host+client A/B against v0.4.7 on clean, 15±10 ms/2 % and 30±20 ms/6 % bursty-loss links, speed-hack attempt (host-applied 151 px/s vs 454 px/s claimed), duplicate-effect check, and mixed screen sizes. Device testing on real phones/hotspots is still recommended.
