# Implementation notes — v0.4.13

- Target: Godot 4, landscape Android; 4-player host-authoritative ENet/UDP LAN on port 24567.
- `assets/barricade_detail.png` is the transparent A-frame road barrier; SVG is its fallback. Both render at 120×72, preserving the asset's 720×433 aspect ratio. With the game entity position at the same center convention as a survivor, the barrier's feet and a wider contact shadow reach the ground line. Wall placement preview shares the same dimensions. Minimum spacing is 132 px and zombie attack distance is tuned to engage at the outside edge.
- Grenade visuals do not draw a line between ground position and airborne sprite. Ground shadow remains on the asphalt while two small sparks trail along the launch-to-target direction. Joining clients render grenade elapsed time using time since the last snapshot, improving projectile smoothness. Explosion includes a fireball, shock rings, radial sparks, ground scorch/shadow and smoke puffs.
- Clients predict their own survivor movement each frame and gently reconcile it against host authority. Other survivors interpolate at snapshot cadence; zombie snapshots merge by stable ID and interpolate X/Y rather than replacing all displayed positions.
- Input cadence is up to 60 Hz; host snapshot cadence is ~15 Hz. ENet FastLZ compression is configured on both host and client before the peer is created. `request_fire` is reliable on its own ENet channel (this note previously said unreliable-ordered, which did not match the code); firing does not trigger an extra world snapshot. Grenade/wall/heal requests remain reliable actions.
- Static CI checks resource paths, settings, gameplay markers, SVG XML and WAV formats, then imports and launches the scene headless before APK export. No Godot binary is installed in the current editing environment, so CI and hardware testing remain the authoritative compile/runtime checks.


## v0.4.7 compression correction
- In Godot 4.7.2, `ENetMultiplayerPeer` exposes the underlying `ENetConnection` via `host`; compression is configured by `host.compress(ENetConnection.COMPRESS_FASTLZ)`.
- Configure this after `create_server()`/`create_client()` returns `OK` and before assigning the peer to `multiplayer.multiplayer_peer`. Host and all clients must use the same compression mode.
- CI now fails if the old invalid constant/property spelling appears or if host/client compression setup differs.


## v0.4.8 networking model
- **Wire format.** `receive_world(buf)` (unreliable-ordered, up to 60 Hz) carries `_encode_snapshot()`: 31-byte header (magic, flags, seq, host ms, host world size, wave state), then counted sections for survivors, zombies, barricades, supply drops, grenades and recent effects. Capped at `MAX_SNAPSHOT_BYTES` (1180) so ENet never fragments it. The same bytes are sent reliably as `receive_initial_world` (join) and `receive_game_over_snapshot`.
- **Client -> host.** `submit_input(buf)` (unreliable-ordered, up to 60 Hz) carries up to 8 un-acked commands `(seq u32, qx i8, qy i8, dt u16 in 0.1 ms)`. The host applies commands with `seq > last_applied`, limits total movement time to real time x 1.12 (budget), and writes `last_applied` back as `ack` in the survivor record.
- **Client view.** `_ingest_snapshot` stores snapshots and aligns clocks (minimum receive-host offset; excess = jitter). `_client_update_render` renders at `now - offset - interp_delay`, interpolating between the bracketing snapshots (extrapolating <= 120 ms when starved) and rebuilding `players/zombies/barricades/airdrops/active_grenades/combat_effects` for the unchanged drawing code. Positions are scaled by `screen / host_world` so different aspect ratios stay consistent.
- **Prediction.** Own survivor = `pred_pos`: advanced every frame by the same quantized command vector the host will apply; `_reconcile_local` replays un-acked commands on the acked authoritative position and bleeds any difference in (snaps above 90 px).
- **Verification performed (Godot 4.7.2 headless, real UDP loopback, impairment proxy).** Codec round-trip + size tests, host+client A/B against v0.4.7 on clean, 15±10 ms/2 % and 30±20 ms/6 % bursty-loss links, speed-hack attempt (host-applied 151 px/s vs 454 px/s claimed), duplicate-effect check, and mixed screen sizes. Device testing on real phones/hotspots is still recommended.


## v0.4.9 host-side smooth view
- **Problem.** Remote survivors are advanced inside `submit_input` whenever a command packet lands, so `players[id].x/y` is a staircase in time. The host drew that directly (measured: survivor frozen in ~50 % of frames while moving, speed CV ~1.0).
- **Fix.** `host_track[id]` stores samples `(virtual_time, x, y)`, one per applied command. Virtual time is the running sum of budgeted command durations (the client's clock), so arrival jitter cancels. `_host_track_arrival` keeps a min-filtered clock offset (`off`), a peak-hold jitter (`jit`) and the mean packet span; `_update_host_view` renders at `now - off - delay` with `delay = clamp(span + jit + 12 ms, 30..200 ms)`, via a small PLL (max +-10 % time warp) so changing the delay never rewinds. If the track runs dry it coasts on the last velocity for <= 100 ms, then holds. A >70 px mismatch with the authoritative position snaps and resets the track.
- **Scope.** Drawing only (`_player_draw_pos`). Zombie AI, hits, snapshots and the anti-speed-hack budget still use `players[id]`. `host_track` / `host_view` are cleared wherever `cmd_*` state is cleared.
- **Timers.** Snapshot and input timers fire when `timer >= interval - delta/2` and subtract (not fmod) the interval, giving even spacing at 60 fps.
- **Cadence.** 60 Hz input and snapshots; `INTERP_DELAY_MIN` 50 ms.
- **Measured (Godot 4.7.2 headless, UDP loopback + impairment proxy, v0.4.8 -> v0.4.9).** Host's view of the client survivor: stalled frames 50-57 % -> 2-3 %, speed CV 1.0-1.3 -> ~0.2, jerk p95 300-600 -> 20-40 px/s (60 Hz frame quantisation). Client's view of other survivors lags 95-135 ms -> 65-100 ms. Own-survivor lag/error unchanged (15 ms floor, ~0.6 px). Traffic ~6 -> ~11 KB/s.


## v0.4.10 barricade grounding
- `assets/barricade_detail.png` is a 3/4 view, so its four foot pads sit at different depths. `BARRICADE_FEET` / `BARRICADE_FOOT_RX` hold the pad bottoms in the 120x72 draw rect (measured from the PNG's alpha bottom profile); `_draw_barricade_grounding(pos, strength)` draws a 3-layer cast shadow (convex hull of the pads and the pads shifted by `BARRICADE_SHADOW_OFFSET`) plus a tight and a soft contact ellipse under every pad, before the sprite. Used by both placed walls (strength 1.0) and the placement preview (0.7).
- If the barricade art is replaced, re-measure the four pad positions and update those constants.
- Sprite tint `BARRICADE_TINT`; the old flat ellipse and straight ground line were removed.


## v0.4.11 barricade orientation
- `assets/barricade_detail.png` (232x340) was re-rendered from a procedural 3D sawhorse (boxes: two A-frames, lower brace, hazard-painted beam, metal end plates, foot pads) with Godot's orthographic camera (yaw: long axis 28 degrees off the depth axis, pitch 38 degrees), textures cut from the previous sprite, a dark outline and a LANCZOS downscale. The long axis recedes into the screen so the A-frame faces the zombies, who walk in from the sides.
- Drawn into `BARRICADE_RECT_SIZE` (60x88) at `BARRICADE_RECT_OFFSET`; the centre of the four foot pads is 26 px below the wall position. `BARRICADE_FEET` are the pad bottoms relative to the wall position. If the art changes, re-measure them (projected from the model, or from the alpha bottom profile).
- `WALL_ATTACK_RANGE` 71 -> 50 (zombies stop ~41 px away and attack within 50 px), `WALL_LANE_TOLERANCE` 34 -> 46 (the wall spans depth now). Depth-sort key is `wall.y + 2`.
- HP bar sits above the sprite; damage tints the sprite instead of drawing cracks at fixed spots.


## v0.4.12 visual and supply lifecycle notes
- Grenade effect type 6 is still carried through the existing 16-byte effect record. The richer renderer is deterministic from the effect id, so clients render the same particle directions without adding packet fields. The existing sound and host-side grenade damage remain unchanged.
- Player death fade/bone remains are presentation-only and maintained in `player_death_visuals` locally. They do not enter `_encode_snapshot()`, save state, or any RPC. A respawn/restart clears the cosmetic state.
- A landed airdrop's existing `despawn_timer` now starts at 22 seconds. The host remains the only device that removes the loot; clients show the countdown and render effect type 8 after receiving the authoritative snapshot.
- No ENet tuning, input cadence, snapshot cadence, player/zombie/wall/drop/grenade/effect record sizes or RPC signatures were changed in this release.


## v0.4.13 placement/render notes
- Barricade spacing checks the rendered 60×88 px sprite footprint, uses 4 px horizontal join gap and 88 px vertical clearance. At the same lane depth, neighbours can sit 64 px apart rather than requiring 132 px.
- `_snap_wall_preview_to_neighbour()` snaps near-end drag gestures to the nearest slot beside a placed barricade when the target remains within player range and valid arena bounds.
- `assets/grenade_explosion_asset.svg` is a transparent 512×420 vector sprite with fire core, irregular flames, smoke lobes, ground dust and debris. The runtime scales/fades the asset while preserving the shock ring, sparks, falling fragments and smoke simulation.
- No snapshot fields, RPC signatures, network intervals, or ENet compression settings were changed in this update.
