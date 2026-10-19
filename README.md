# Pixel Zombie LAN — v0.4.19

A landscape Android zombie wave-defense game made with Godot 4. It supports solo offline play and a host-authoritative LAN session for up to four devices through the same Wi-Fi hotspot. No internet is needed after installation.

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
- Hold FIRE: repeat shots in the last left/right facing direction. The sidearm has infinite ammo; airdrop weapons use finite magazines and reserve ammo.
- HEAL: consume one medkit to restore up to 35 HP.
- GREN: hold and drag to the landing point, then release to throw. The dotted arc and landing marker show the aim.
- WALL: hold and drag the A-frame barricade preview, then release when it is green. Red indicates invalid placement. Barricades block aligned zombies, have HP and can be destroyed.
- Pause: resume, manually save, or leave the session.

## Supply drops
Supply crates descend under a parachute and can contain grenades, wall kits, medkits, one of five limited-ammo guns (SMG, shotgun, rifle, sniper or rocket launcher), or ammunition compatible with a gun already owned by the squad. Weapon drops equip the gun and fill its magazine with starting reserve ammo. Ammo drops are matched to a gun already owned by a squad member who still has room for rounds; if nobody can use an ammo cache, the roll becomes a weapon drop instead. A compatible cache fills reserve space first, then uses leftover rounds to top up a missing magazine. Fully stocked players leave the cache on the ground for later. If all weapon slots are occupied, a new gun replaces slot 2. Tap the 0, 1 or 2 weapon tiles to switch; 0 is the infinite sidearm. Holding FIRE while a gun is empty starts a reload when reserve ammo remains, or falls back to the sidearm when no ammo remains. Reload is cancelled when manually switching slots.

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
