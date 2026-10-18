# Pixel Zombie LAN — v0.4.5

A landscape Android zombie wave-defense prototype built with Godot 4. It supports offline solo play and a host-authoritative local Wi-Fi session for up to four players (ENet UDP port 24567); an internet connection is not needed after installation.

## What's new in v0.4.5
- Infinite ammunition: FIRE no longer consumes bullets; the HUD shows `AMMO ∞`. Airdrops now contain useful loot instead of redundant ammo: grenades, wall kits or medkits.
- Single-gesture grenade aiming: press and hold GREN, drag the target marker anywhere in the defense lane to adjust both direction and distance, then release to throw. A dotted arc and landing marker update while dragging. The host validates the 2D target and simulates the throw.
- Single-gesture barricade placement: press and hold WALL, drag the A-frame ghost to a valid point, then release to deploy. Invalid spots turn red; no separate PLACE button or slider is needed.
- Replaced the crate-like wall sprite with a detailed A-frame roadside barricade featuring a hazard beam, splayed legs, cross-bracing, weathered metal and feet. The PNG is transparent and uses an SVG fallback.
- Airdrop loot has randomized useful items and labeled pickup rewards. If a category is full, overflow converts to a medkit or emergency HP rather than wasted ammo.
- Android version code 18 / version name 0.4.5.

## Controls
- Left virtual analog: move around the defense lane.
- Hold FIRE: fire horizontal shots in the direction the survivor last faced. Ammunition is unlimited.
- HEAL: spend one medkit to restore up to 35 HP.
- GREN: hold and drag from the GREN button toward the desired landing point, then release to throw. The arc, crosshair and estimated range follow the pointer. Starts with 3 grenades; supply drops can replenish them.
- WALL: hold and drag the WALL button into the arena to position the A-frame barricade; release to deploy when the preview is green. Red means invalid placement. No separate confirmation slider/button. Barricades block aligned zombies, have HP and can be destroyed.
- Pause: resume, manually save, or leave the session.

## Supply drops and barricades
Supply crates descend under a parachute and land in the defense lane. Each random crate yields grenades, wall kits or a medkit. The crate label shows the content. Survivors start with two wall kits; placement is host-validated and restricted to a reasonable distance and lane. A maximum of eight barricades can exist; zombies attack barriers before reaching players, and damaged barriers display HP/degradation marks.

## LAN multiplayer
The host opens Multiplayer LAN → Create World, then shares its hotspot IPv4 address. Friends connected to the same hotspot select Join World and enter that address. Android hotspot isolation varies by device, so physical-device testing is still required.

## Saved runs
Saving is manual from the host pause menu/lobby. Continue Saved is explicit; new solo/host runs clear previous zombie and effect state. Leaving does not auto-save.

## Build
Push the source ZIP contents so `project.godot` is in the repository root. GitHub Actions imports assets, validates resource references and sound files, checks script markers, runs a headless scene startup, exports a debug APK and uploads a source ZIP.

## Prototype/testing note
Grenade and airdrop assets are SVG; the barricade uses a transparent detailed PNG with a matching SVG fallback. SFX are synthesized locally. Static checks verify resource paths and formats, but Godot runtime compilation, touchscreen feel and actual four-device LAN behavior must be confirmed by GitHub Actions and device testing.


## v0.4.4 — CI validator correction
- Fixed the airdrop loot-label match so grenade loot has an explicit branch and the code matches the workflow's required implementation markers.
- Legacy saved `ammo` drops are labelled and migrated as grenade loot, since ammunition is unlimited.
- Bumped Android version code/name to 17 / 0.4.4.
- No gameplay controls, grenade aim, wall placement, or arena geometry changes in this maintenance update.


## v0.4.5 — A-frame barricade and direct touch gestures
- Replaced the boxy barricade sprite with a detailed transparent A-frame road barrier; render dimensions, shadow and HP bar are tuned to the new silhouette.
- Grenade targeting is now one continuous hold-drag-release gesture. It uses a 2D target, dotted arc, landing reticle and distance label; touch release throws immediately. Host RPC sends normalized target coordinates.
- Wall placement uses the same hold-drag-release pattern. The ghost barricade follows the pointer and deploys only on release if valid; removed the grenade range slider and cancel/place controls.
- Bumped Android version code/name to 18 / 0.4.5.
