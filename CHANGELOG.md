# Pixel Zombie LAN v0.4.26

## v0.4.26 — half-plane turret aiming and reliable settings toggle

- Turret targeting and visual tracking are strictly limited to a front-facing 180° sector, selected by the placing survivor's left/right facing. Head yaw is clamped relative to the base angle so it does not sweep through the rear hemisphere.
- Increased the static turret collision footprint to match the displayed base more closely and prevent survivors/zombies from walking through the machine.
- Enlarged the AIM ASSIST switch row and gave it a dedicated high-priority touch route in Settings to reduce missed taps; explicit ON/OFF state remains stored locally.
- Bumped saved-world format to version 7 and added migration for older turret yaw values.
- Added codec regressions for old-save yaw migration and body collision from both approaches.
- Android version code/name: 38 / 0.4.26. Godot runtime and APK export still need to pass GitHub Actions.

## Previous release history


- Replaced procedural turret geometry with transparent generated PNG base/head sprites; only the head rotates around its pivot.
- Added compact generated turret-fire SFX and connected it to synchronized turret firing.
- Removed long overlaid weapon-arm strokes that created a stray diagonal shape near the survivor.
- Moved the aim-assist toggle out of combat HUD into User Settings, accessible from home and lobby; preference remains local and persistent.
- Added explicit weapon airdrop replacement choice when both slots are occupied: choose slot 1, slot 2, or cancel; the crate remains available until resolved. The player flags use spare bits, keeping the 30-byte player record unchanged.
- Reduced turret target acquisition overhead by using squared-distance comparisons; kept host-authoritative simulation and four-player LAN limits.
- Reserved weapon drops are released if their chooser dies or disconnects; the prompt intercepts taps before underlying combat controls.

## v0.4.24 — turret asset check lifecycle fix

- Wait for one SceneTree frame after adding `Main.tscn` in the SceneTree codec test so `_ready()` completes before runtime resource assertions.
- Added separate direct `ResourceLoader` checks for both turret PNGs alongside checks for the loaded fields.
- Android version code/name: 36 / 0.4.24.


## v0.4.23 — codec test runtime fixes

- Made offline codec tests explicitly offline before exercising loot/fire functions, preventing sound events from dereferencing a null MultiplayerAPI.
- Guarded `_emit_sfx` and `_is_connected_client` when the MultiplayerAPI or peer is unavailable.
- Fixed typed `Array[Dictionary]` test fixtures by using `clear()` + `append()` rather than assigning an untyped array.
- Reset test projectiles/grenades/airdrops and hold the airdrop spawn timer during the turret-destruction simulation for deterministic results.
- Android version code/name: 35 / 0.4.23.

## v0.4.21 — Deployable auto-turret and survivor weapon correction

- Added destructible server-authoritative auto-turrets with a 270 px range, smooth head rotation, muzzle flash/tracer effects, health bar and damage smoke.
- Added an airdrop turret kit. Each fourth supply drop guarantees one when the squad has neither a kit nor an active turret; rare random drops can also appear. Kit cap is two, and a world supports four deployed turrets.
- Turret build preview follows the barricade's hold/drag/release placement style and shows the turret's attack radius and invalid placement colour.
- Zombies will target a turret when it is closer than a survivor and attack it; regular and boss attacks can destroy the turret.
- Fixed duplicated survivor weapons by adding a cleaned body-only survivor atlas and lowering the selected weapon/hand overlay to the torso. Fire lane and muzzle FX are aligned to the rendered muzzle.
- Added persistent local AIM marker toggle in a non-overlapping upper HUD position.
- Extended the player snapshot by one turret-kit byte and added compact turret records (8 bytes each); packet size is still bounded by the existing 1180-byte cap. LAN peers must all update to 0.4.21.
- Android version code/name: 33 / 0.4.21.

# Changelog — Pixel Zombie LAN

## v0.4.20 — Weapon grip, aim marker, barricade depth and supplied music
- Tightened per-weapon on-character placement and added outlined arms/hands connecting the firearm to the survivor. The rendered muzzle flash is aligned to the combat ray origin.
- Added a visual-only horizontal firing guide with a bracket reticle; its color indicates whether a zombie is in the selected weapon’s valid lane/range. No gameplay hit logic or snapshot fields changed.
- Preserved the 4 px horizontal barricade gap, reduced vertical row spacing to 60 px, and added vertical snapping for tighter upper/lower rows.
- Integrated the user-provided 151-second stereo MP3 as looping gameplay ambience at -20 dB, with the existing WAV as fallback. Pause/exit audio behavior remains unchanged.
- Android version code/name: 32 / 0.4.20.

## 0.4.19 — Animation, Airdrop & Audio Pass

- Added an original looping survival-combat ambience track; it starts during gameplay, pauses with the pause screen, and stops when leaving the match.
- Added original boss roar/attack sounds and an airdrop incoming cue, using the existing synchronized SFX event path for LAN sessions.
- Made player/zombie walking more visible with an animated lower-body layer, stronger gait, dust footsteps, improved weapon grip placement, recoil, and muzzle flashes.
- Made the boss movement more substantial with stride sway, a pulsing red aura, and stronger slam/lunge deformation.
- Reduced initial airdrop wait to 10 seconds, then set future drops to 24–34 seconds; full slots retry after 4 seconds and landed drops remain available for 28 seconds.
- Increased weapon loot frequency and renamed the existing rifle role to Renbo LMG without changing the packed weapon IDs or LAN snapshot layout.
- Updated Android version metadata to 0.4.19 / version code 31.

## 0.4.18 — airdrop weapon system and finite ammunition
- Added five limited-ammo guns (SMG, shotgun, rifle, sniper and rocket launcher), with individual stats, muzzle/tracer effects, shotgun pellet spread, sniper precision streak, and delayed rocket splash damage.
- Added a two-firearm-slot loadout plus an infinite-ammo default sidearm. Weapon drops auto-equip; ammo drops only target squad-owned guns that can accept rounds, fill reserve space first, and use leftover pack rounds to top up a missing magazine. Fully stocked caches remain in the world. Empty firearms auto-reload when reserve ammo exists or fall back to the sidearm when empty.
- Added matching transparent weapon sprites from the supplied reference, tap-to-switch HUD tiles, reload status, and ammo/magazine counts. Bumped player snapshot records to 29 bytes and Android version code/name to 30 / 0.4.18. All LAN devices must use the same version.
- Added codec coverage for loadout, ammo, reload timer and weapon/ammo airdrop subtype round-trip. Runtime compile/startup and APK export remain to be confirmed by Godot 4.7.2 CI.
- Fixed Godot 4.7.2 codec-test parse errors by explicitly typing the boss maximum-HP and boss attack-frame local variables (`float` and `int`); these values came through dynamically typed `Node` calls in the test.

## 0.4.17 — Brute attack animations
- Added five-frame transparent pixel-art strips for the Brute's claw slash, overhead ground slam, and forward lunge, with consistent ground anchoring and detached edge-fragment cleanup.
- Added attack-specific wind-up, hit timing, recovery, damage reach/radius, timed barricade damage, lunge movement, and a synchronized ground shockwave/dust/debris effect.
- Removed the ordinary-zombie swipe overlay from boss renders so it no longer conflicts with the custom frames.
- Reused two spare bits of the zombie flags byte to transmit boss attack type. The 13-byte zombie record, snapshot size cap, RPC signatures, and network cadence remain unchanged.
- Android version code/name: 29 / 0.4.17.

## 0.4.16 — escalating waves, Brute boss, and grounded airdrop
- Wave target counts rise by five each wave instead of remaining fixed at 25; the displayed counter remains within its one-byte network range.
- Waves 10, 20, 30, etc. introduce the Brute boss, with dedicated art, health bar, higher durability per boss tier, slower chase speed and harder melee damage. Boss health uses a normalized field, preserving existing record lengths.
- Corrected the parachute texture from a spritesheet to a single canopy. Reworked suspension-line attachment and crate grounding; landing smoke lasts two seconds and is drawn behind entities; a shorter dust puff still marks expiry.
- Android version code/name: 28 / 0.4.16. Update all LAN peers together for the boss type.

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


## v0.4.21 CI hotfix — codec-test live logs and hang diagnostics

- Changed the GitHub Actions snapshot codec test to stream Godot output directly into the job log instead of hiding it in a temporary file until completion.
- Added a 90-second safety timeout with explicit failure reporting if the codec test stalls.
- Added named checkpoints around snapshot round-trips, weapon/ammo handling, boss frames, turret deployment/destruction, and the encode/decode stress loops, so the last printed checkpoint identifies the area to inspect.
- This is a CI/test-diagnostics hotfix only; gameplay code, assets, LAN packet structure, and Android version code remain unchanged.
