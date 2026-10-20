# Pixel Zombie LAN v0.4.36

## v0.4.36 — Android Join keyboard and modal input fix
- The Join LAN IP field explicitly enables and requests the Android virtual keyboard after the dialog is visible; the URL keyboard layout keeps the dot key accessible, and the field accepts a maximum of 15 characters.
- While the native Join dialog is open, touches are not dispatched through the custom game HUD, so tapping the IP field cannot accidentally activate controls behind the dialog. Enter/Done submits the dialog, while Cancel safely closes it.
- Android version code/name: 48 / 0.4.36. Runtime Godot 4.7.2 and real-phone keyboard behavior still need confirmation in CI/device testing.

## v0.4.35 — Cancel prevents immediate re-trigger for same nearby airdrop
- Root cause fixed: canceling an occupied weapon crate now records a host-local per-player ignore for that exact drop while the player remains close. The crate stays on the ground, is not deleted, and other players can still claim it.
- Ignore clears after the player leaves a 62 px release radius (pickup radius remains 42 px), allowing a later deliberate return to reopen the choice. Player death, disconnect, world reset, and crate removal also clear the ignore.
- Added an end-to-end codec-test regression: initial prompt -> Cancel -> same-position update stays closed -> walk away -> return -> prompt can reopen. LAN snapshot/save schemas unchanged.
- Android version code/name: 47 / 0.4.35. Runtime Godot 4.7.2 pass must still be confirmed in CI.

## v0.4.34 — reliable weapon replacement Cancel
- Cancel immediately dismisses the modal for host/offline/client input paths and clears stale hitboxes.
- Touches are dispatched against live modal hitboxes directly; gameplay taps cannot intercept the Cancel press.
- Stale client snapshots are suppressed until host acknowledgement, with a timeout for retry if the response is missing.
- Host releases the airdrop reservation and immediately broadcasts the updated world state.
- Android version code/name: 46 / 0.4.34. Runtime validation through Godot 4.7.2 GitHub Actions remains required.

# Pixel Zombie LAN v0.4.33

## v0.4.33 — turret-facing test setup fix
- Corrects the regression test to explicitly reselect AIM LEFT in the new placement session before asserting that a right-side preview point does not change facing.
- Strengthens host deployment coverage by placing a left-facing turret to the right of its owner.
- Retains v0.4.32's two-step turret placement, explicit DEPLOY/CANCEL actions, thumb-friendly weapon replacement Cancel button, and debounced AIM toggle.
- Android version code/name: 45 / 0.4.33. Snapshot records and save schema remain unchanged.
- Godot 4.7.2 runtime tests and APK export must be confirmed by GitHub Actions.


## v0.4.32 — input and placement reliability
- AIM toggle is debounced against duplicate Android touch/emulated-mouse presses and saved locally.
- Turret placement uses a persistent preview with explicit DEPLOY and CANCEL controls; releasing a drag only repositions the preview.
- Weapon replacement Cancel target is enlarged for landscape mobile and clients dismiss the modal immediately while cancellation is sent reliably to the host.

## v0.4.31 — turret destruction assertion fix and test cleanup
- Added shared `_turret_facing_button_rects()` geometry for drawing, touch hit-testing, and Android coordinate fallback. First tap on AIM LEFT/RIGHT now registers before the first draw pass, and selection remains independent of the chosen ground point.
- Re-aligned the turret yaw joint to the base bearing and moved the simulated muzzle origin to match the visible barrel bore.
- Added active-control hit testing that tolerates Android viewport/window coordinate differences for AIM settings and first-tap weapon replacement.
- The in-game placement workflow reserves arena touches for choosing a turret position while placement is active; players continue to pass through turret scenery.
- Added regressions for first-tap AIM LEFT hit testing, both facing choices, turret pivot/muzzle alignment, transformed AIM taps, and the first replacement-slot tap.
- Android version code/name: 43 / 0.4.31. Player/turret/drop snapshot record sizes and save schema unchanged.

# Pixel Zombie LAN v0.4.28

## v0.4.28 — two-step turret placement, reliable touch input, and muzzle alignment

- Turret deployment is now a two-step interaction: press TUR to enter placement mode, then tap/drag a point in the world and release to place. Positioning to the left or right of the survivor selects the corresponding 180° firing hemisphere.
- Touch, drag, and mouse positions are transformed from viewport space into the game canvas before hit-testing. User Settings rebuilds the AIM toggle hitbox from its layout, while weapon-replacement hitboxes are generated from a shared layout before the first touch is processed.
- Lock survivor movement while an airdrop weapon-slot choice is open and allow 96 px tolerance for host validation, avoiding a stale first replace click when position drift occurs.
- Survivors pass through turret feet/body. The obstacle resolver remains in use for zombie movement so zombies can still interact with/damage turrets.
- Added a central articulated mast/collar between turret head and support legs. Muzzle flash and the brighter moving tracer share a single barrel-tip calculation for both left- and right-facing heads.
- Added regression coverage for left/right turret placement, first-tap settings/weapon modal input, survivor pass-through, and muzzle positions. Android version code/name: 40 / 0.4.28. Network record sizes and save schema remain unchanged.
- Runtime codec test and APK export must pass GitHub Actions before treating the update as fully verified.

## Previous release: v0.4.26 — front 180° turret sector, solid footprint, dependable AIM toggle

- Turret keeps the deployment-side direction (left/right) and targets only zombies in the front 180° sector. The head rotates inside that sector without crossing through the back arc.
- Expanded the turret body collision to cover the visible base more accurately; survivor prediction, authoritative player movement, and zombie movement use the same solid footprint.
- AIM ASSIST in User Settings is now a large ON/OFF toggle row with a dedicated touch path, a clear visible state, and persistent local preference.
- Bumped save format to version 7 and migrates legacy 360° turret yaw to the new relative half-arc while preserving the saved facing where possible.
- Added regression checks for legacy/current turret save orientation, firing restrictions, and collision approaches from both sides.
- Snapshot records remain unchanged (8-byte turret record); all LAN clients should use v0.4.26 together because turret angle semantics remain directional.
- Android version code/name: 38 / 0.4.26. Validate runtime with Godot 4.7.2 in GitHub Actions.

## Previous release: v0.4.25 — Directional turret arc, body collision, and AIM switch

- Turret firing arc is a front-facing 180° semicircle. The turret keeps the left/right direction it had when placed; the head only rotates within that half-plane.
- Solid rectangular footprint blocks survivor and zombie movement; placement checks keep turret bodies away from barricades.
- AIM direction marker can be changed through a large switch-style ON/OFF row in User Settings.
- Snapshot packet sizes are unchanged; the 8-byte turret angle field now packs facing direction in the high bit. All LAN devices must use v0.4.25 together.
- Android version code/name: 37 / 0.4.25. Runtime Godot build/test must be verified in GitHub Actions.

## v0.4.23 — Destructible auto-turrets, aim toggle and survivor weapon cleanup

- Added a deployable auto-turret kit delivered by airdrop. Hold and drag from the TUR control to position it; the green/red circular range preview shows placement/range before release.
- Turret head tracks nearby zombies smoothly, fires server-authoritative shots, displays health/damage smoke, and can be destroyed by the horde. Maximum four turrets per world.
- Added local AIM marker ON/OFF control, persisted on the device and placed in the upper HUD gap to avoid the VITALS panel.
- Fixed duplicate/overhead survivor weapons: clean survivor atlas removes baked-in gun pixels, then the selected loadout weapon and arm/hand overlay is drawn along the torso/hand line; visible muzzle and ray effects share the firing lane.
- Added turret kit count and turret position/HP/head-angle to the LAN snapshot; all players must use the same protocol version.
- Android version code/name: 34 / 0.4.23. Snapshot cap remains 1180 bytes.

## v0.4.23 — Turret presentation, user aim setting and safe weapon replacement
- Split the automatic turret into separate transparent PNG base/head layers. The upper head rotates toward zombies, includes a muzzle flash, and uses an original compact turret-fire WAV effect.
- Removed stretched forearm overlays responsible for the extra diagonal shape near the character; the held weapon remains drawn as a separate loadout sprite.
- AIM Assist ON/OFF now lives under User Settings in the safehouse and lobby, not on the gameplay HUD. The preference is persisted locally.
- When a weapon drop arrives while both gun slots are occupied, the pickup prompt asks to replace slot 1, replace slot 2, or cancel. Cancel leaves the crate on the ground; the host validates selection and keeps the prompt state in existing player-flag bits without enlarging the LAN player record.
- Turret target acquisition uses squared distance to avoid a square-root operation for each zombie candidate. Added codec tests for explicit slot selection and cancellation.
- Android version code/name: 35 / 0.4.23. Godot headless parsing/runtime test and APK export must still pass in GitHub Actions; this edit environment has no Godot executable.

## v0.4.20 — Weapon grip, aim guide, tighter barricade rows and supplied ambience
- Reworked survivor weapon rendering: firearms are scaled/placed around the gameplay muzzle, mirrored for facing, and connected to the character with outlined arms and hands. Recoil flash now lines up with the actual shot origin.
- Added a visual-only horizontal aim guide. Dashed guide + bracket marker show the current direction and nearest eligible zombie; the marker turns muted green when a zombie is inside the active weapon's effective range/lane. Hit logic and LAN packets are unchanged.
- Kept horizontal barricade join spacing at 4 px, reduced vertical row spacing from 88 px to 60 px, and added vertical-row snapping for tighter upper/lower barricade placement.
- Added the supplied 151-second stereo MP3 as the primary looping gameplay ambience at -20 dB under gunfire/SFX. The existing WAV ambience remains a fallback; music still starts only during gameplay, pauses on Pause, and stops when leaving/game over.
- Android version code/name: 32 / 0.4.20. Snapshot layout and LAN wire protocol remain unchanged.

## v0.4.19 — movement animation, more frequent airdrops, and combat audio
- Walking visuals split the source sprite at the hips and animate the lower-body layer with a stronger gait; player weapon placement sways with movement, adds a grip-hand overlay, recoil and a brief pixel muzzle flash. Zombie and boss movement use stronger stride sway, with the Brute retaining its dedicated attack-frame sheets.
- Added an original 42-second looping combat ambience, a Brute roar/attack sound, and an incoming-airdrop cue. Music plays only during a match, pauses on Pause, and stops when leaving the match. New SFX use the existing LAN synchronization path.
- First airdrop arrives after 10 seconds, later drops spawn every 24–34 seconds, and a full active-drop limit retries after 4 seconds. Landed crates remain for 28 seconds; weapon/ammo loot now occupies 36% of rolls combined.
- The rifle slot is tuned and labeled as the Renbo LMG without changing packed weapon IDs or the multiplayer snapshot layout. Android version code/name: 31 / 0.4.19.

## v0.4.12 — grenade blast, survivor death remains, and supply expiry
- Grenade detonation now has a brief white-hot flash, a flattened expanding shockwave, deterministic radial embers and fragments, then a rising clumped smoke plume. Visual effects stay compatible with the existing effect id and compact snapshot record.
- A survivor fades and collapses over 1.25 seconds, then leaves a small ground-level skeleton/bone silhouette that gradually fades. This is client-local presentation state only; no player or snapshot fields were added.
- Landed airdrops expire after 22 seconds if untouched. A countdown/progress strip warns the player during the final six seconds, and expired drops leave a short dust/smoke puff.
- Host remains authoritative for grenade damage and airdrop removal. No networking cadence, packet field, snapshot byte count, or RPC signature changed.
- Android version code/name: 25 / 0.4.12.


## v0.4.11 updates — barricade faces the zombies
- New barricade art: it now stands across the lane with the A-frame profile toward the viewer and its long hazard panel receding into the screen (the angle of the reference), instead of lying side-on. It was re-rendered from a 3D model using textures cut from the previous painted sprite, with a dark outline.
- Gameplay geometry matches the new shape: zombies stop and attack ~50 px from the barricade, and it blocks a wider strip of the lane (46 px). The WALL button icon, HP bar, placement preview and shadows use the new footprint.
- Visual/gameplay-geometry only, no network change: v0.4.9 and later can still play together (the host decides where zombies stop).

## v0.4.10 updates — barricade sits on the asphalt
- The A-frame barricade looked like it floated: one flat ellipse + a straight line were drawn below the sprite, but its four feet touch the road at different depths (3/4 view). Shadows are now anchored to the real foot-pad positions (contact shadow per foot, soft cast shadow following the footprint toward the camera) and the sprite is tinted slightly into the dusk palette.
- The placement preview uses the same grounding and a flattened ring lying on the road. Visual only: no network/gameplay change, so v0.4.9 and v0.4.10 can still play together.

## v0.4.9 updates — smooth for host AND client
- The host used to draw a client's survivor straight from command packets, so it moved in steps (frozen about every second frame, worse with Wi-Fi jitter). The host now draws remote survivors from a short, jitter-adaptive track built from the commands' own durations, so network jitter no longer shows up as stutter. Gameplay (zombie targeting, hits) still uses the exact authoritative position.
- Movement commands and world snapshots now go out at up to 60 Hz (about 11 KB/s in total). The interpolation buffer shrinks accordingly, so other survivors and zombies are drawn ~35-40 ms closer to real time on the client.
- Send timers tolerate half a frame, so packets are evenly spaced instead of alternating 33/50 ms.
- **Every device must install v0.4.9 to play together** (command/snapshot cadence changed).

## v0.4.8 updates — LAN client responsiveness
- Clients now use real prediction with host reconciliation (sequence-numbered movement commands), so your own survivor responds immediately and is only corrected when it truly disagrees with the host.
- World state is sent as a compact binary snapshot (always one UDP datagram, ~30 Hz) instead of a large Dictionary RPC; remote survivors and zombies are interpolated from a timestamped snapshot buffer.
- Your own shots, tracer and sound are instant; host effects are loss-tolerant and line up with what you see.
- Clients show a small NET line (RTT, loss, snapshots/s, KB/s, buffer, prediction error). Set `SHOW_NET_STATS := false` in `scripts/game.gd` to hide it.

## v0.4.7 updates
- Enlarged the transparent A-frame barricade art to match its native aspect ratio and aligned its feet and contact shadow to the survivor ground line. Preview and placed barricade use the same shape; obstacle spacing and zombie attack distance match its width.
- Removed the long ground-to-projectile tether during grenade throws. The grenade now has a ground shadow and tiny motion sparks; explosion feedback includes a collapsing fireball, expanding shock rings, radial sparks, scorch shadow and rising smoke.
- Added client-side local-player prediction with gentle correction to the host state, plus interpolation for remote players and zombies.
- Clients submit movement at about 30 Hz; the host broadcasts snapshots at about 15 Hz. ENet FastLZ compression is enabled symmetrically. Fire input no longer causes an extra full-world broadcast for every shot.
- Host remains authoritative for movement bounds, combat hits, health, grenade damage, loot and barricade placement.

## Controls
- Left virtual analog: move in the lower defense lane.
- Hold FIRE: repeat shots in the last left/right facing direction. The visual aim guide and bracket marker show the current shot lane; green means a zombie is within the active weapon range/lane. This is visual assistance only. The sidearm has infinite ammo; airdrop weapons use finite magazines and reserve ammo.
- HEAL: consume one medkit to restore up to 35 HP.
- GREN: hold and drag to the landing point, then release to throw. The dotted arc and landing marker show the aim.
- WALL: hold and drag the A-frame barricade preview, then release when it is green. Red indicates invalid placement. Barricades block aligned zombies, have HP and can be destroyed.
- Pause: resume, manually save, or leave the session.

## Supply drops
Supply crates descend under a parachute and can contain grenades, wall kits, medkits, one of five limited-ammo guns (SMG, shotgun, rifle, sniper or rocket launcher), or ammunition compatible with a gun already owned by the squad. Weapon drops equip the gun and fill its magazine with starting reserve ammo. Ammo drops are matched to a gun already owned by a squad member who still has room for rounds; if nobody can use an ammo cache, the roll becomes a weapon drop instead. A compatible cache fills reserve space first, then uses leftover rounds to top up a missing magazine. Fully stocked players leave the cache on the ground for later. If both weapon slots are occupied by different guns, the player must choose whether to replace slot 1 or slot 2; Cancel leaves the airdrop available on the ground. Tap the 0, 1 or 2 weapon tiles to switch; 0 is the infinite sidearm. Holding FIRE while a gun is empty starts a reload when reserve ammo remains, or falls back to the sidearm when no ammo remains. Reload is cancelled when manually switching slots.

## LAN setup
The host selects **Multiplayer LAN → Create World** and shares the hotspot IPv4 address. Other devices must join the same hotspot, select **Join World**, and enter that address. Wi-Fi hotspot isolation and device performance vary, so test the actual phones together. Client prediction/interpolation reduces perceived input delay and snapshot stepping; it cannot compensate for a poor hotspot or a heavily loaded device.

## Build from source
Push the ZIP contents so `project.godot` is in the repository root. GitHub Actions checks resource references, landscape configuration, script markers, SVG/WAV assets, Godot import and headless startup before exporting a debug APK and uploading a source ZIP. Install only after the workflow succeeds.

## Verification
v0.4.10 was parsed and run in Godot 4.7.2 (netcode checked at v0.4.9, barricade visuals rendered via Xvfb) (headless): snapshot codec tests plus a real host+client session over UDP with simulated delay, jitter and packet loss (`tools/net_test/`). Real-phone testing is still recommended for frame pacing, hotspot behavior and four-device sessions.


## v0.4.7 — Godot 4.7 ENet compression API fix
- Fixed the LAN compression compile error: Godot 4.7 defines `COMPRESS_FASTLZ` on `ENetConnection`, not `ENetMultiplayerPeer`.
- Host and client now create their ENet peer first, then call `peer.host.compress(ENetConnection.COMPRESS_FASTLZ)` before assigning it to `multiplayer.multiplayer_peer`.
- The CI validator rejects the invalid legacy enum/property spelling and checks that both sides use the same compression mode.
- Android version code/name: 20 / 0.4.7.


## v0.4.13 — tighter barricade placement and asset-based grenade blast
- Replaced the old 132 px barricade spacing with sprite-footprint overlap checks. Walls can be placed side-by-side with a 4 px visual gap while overlapping placements remain invalid.
- Added automatic neighbour snapping when the wall preview is dragged close to an existing wall end; the preview inherits the neighbour's lane depth for straighter defensive lines.
- Added `assets/grenade_explosion_asset.png` (rendered from the editable transparent SVG source), a layered blast asset animated with growth and fade, blended with the existing shock ring, sparks, fragments, and lingering smoke.
- Preserves the v0.4.11 compact snapshot protocol and ENet networking configuration. Android version code/name: 26 / 0.4.13.

### Generated visual assets (v0.4.14)

The project now includes `assets/grenade_explosion_asset.png`, `assets/airdrop_parachute_generated.png`, `assets/airdrop_crate_generated.png`, and `assets/airdrop_landing_dust_generated.png`. Full generated source sheets are retained in `assets/grenade_explosion_spritesheet_source.png` and `assets/airdrop_spritesheet_source.png`. The in-game grenade blast still uses the existing synchronized effect lifetime and host authority.



## v0.4.18 — Airdrop weapons, matching ammunition and weapon-specific combat
- Added five limited-ammo weapon types with separate damage, effective range, lane tolerance, fire cadence, magazine size, reserve limit and reload duration: SMG, shotgun, rifle, sniper and rocket launcher. The sidearm remains infinite-ammo and is the fallback when the active firearm has no magazine or reserve rounds.
- Added two selectable firearm slots next to the default sidearm. Weapon pickup equips the new gun; when both firearm slots are full, a newly collected weapon replaces slot 2. Tapping a slot switches weapons and cancels an in-progress reload without restoring rounds.
- Airdrops can roll a weapon or matching ammunition. Ammo is selected from gun types owned by a squad member who can still accept it; if no firearm is owned or all magazines/reserves are full, the roll becomes a weapon drop instead. Ammo only replenishes its matching gun. When reserve capacity is full, a compatible cache fills missing magazine rounds; if the magazine and reserve are both full, the crate remains on the ground until someone can use it. Legacy loot categories remain available.
- Added five transparent weapon sprites from the supplied reference sheet, a weapon tile HUD, on-character gun art, weapon-dependent muzzle/tracer/pellet effects, a five-pellet shotgun spread, a long precision sniper streak and a timed rocket projectile with radial falloff damage.
- Expanded player snapshot records from 19 to 29 bytes for the two firearm slots, ammo counts, active slot and reload timer. Weapon and ammo subtype share the existing airdrop quantity byte, so the drop record remains 27 bytes and no new snapshot section/RPC was introduced. All LAN devices must update to v0.4.18 together.
- Added codec tests for weapon loadout/ammo round-trip, weapon/ammo airdrop subtype round-trip, sidearm infinite ammunition and partial reload handling. Runtime Godot parser/import, codec execution and APK export still require the provided CI/Godot 4.7.2 environment.
- Android version code/name: 30 / 0.4.18.

## v0.4.17 — Brute attack animations
- Added three dedicated five-frame transparent pixel-art animation strips based on the supplied Brute reference: heavy claw slash, overhead ground slam, and forward lunge. The frames keep a common ground baseline and preserve their intended action silhouettes.
- Attack anticipation, active hit moment, and recovery use distinct timings. Slashes deal 18 damage in a short arc, lunges deal 22 and move the boss toward its target, and ground slams deal 24 in a 104 px radius with a ground-hugging shock ring, dust, and debris. The boss also uses attack-timed damage against barricades.
- The generic zombie swipe overlay no longer draws on top of the boss's custom animation. Boss attack type is synchronized by reusing spare bits in the existing flags byte; the zombie record remains 13 bytes and snapshot size/cadence are unchanged.
- Android version code/name: 29 / 0.4.17. Use the same version on LAN devices for synchronized boss animation.

## v0.4.16 — boss waves, scaling hordes, and grounded supply drops
- Zombie count is no longer fixed at 25: each wave adds five infected (Wave 1: 25, Wave 2: 30, Wave 10: 70), with the network counter safely capped at 255.
- Every wave divisible by 10 begins with a dedicated Brute boss. It has a large isolated sprite, a boss HP bar, slower movement, stronger attacks, and more HP at later boss tiers. Boss HP is normalized into the existing compact snapshot byte; the packet layout and 60 Hz LAN cadence are unchanged.
- Replaced the clipped multi-canopy airdrop PNG with one complete canopy. Suspension lines now meet the parachute and crate, and the crate/shadow bottom is aligned with the survivor ground line. A dust/smoke puff appears for two seconds when the crate lands and sits behind it so the crate remains readable. Old saved runs also recalculate the horde target from the current wave.
- Source version: 0.4.16. Android version code/name: 28 / 0.4.16. Install the same build on all LAN devices because older builds do not understand the new boss kind.

## v0.4.15 — cohesive generated VFX and airdrop presentation
- Replaced the old explosion raster, whose partially transparent orange/brown background caused a large muddy rectangle over the road, with a cropped, premultiplied-alpha transparent pixel-art blast. It is rendered using its original aspect ratio and anchored at ground level.
- Reduced the oversized circular shock ring to a thinner, flattened pressure ripple and reduced duplicate procedural sparks, debris and smoke so the textured asset reads as one coherent effect rather than stacked effects.
- Replaced the bright blue crate with a worn olive/rust/red supply crate that matches the dusk palette. Rendering now preserves the texture aspect ratio and aligns the crate bottom to the road contact point. Large original source sheets are kept in `art_source/` and excluded from Android export.
- Combined the landed loot label and expiry countdown into one compact panel above the crate; removed the duplicate label below it and the strong rectangular warning outline.
- Kept the compact binary snapshot protocol, ENet settings, RPC signatures and LAN cadence unchanged. Android version code/name: 27 / 0.4.15.


### CI troubleshooting: codec test
The snapshot codec CI step streams output live and stops after 90 seconds if no completion occurs. Look for the last `[codec checkpoint]` line in GitHub Actions to identify which test section stalled.
