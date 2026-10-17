# Pixel Zombie LAN — v0.4.2

A landscape Android zombie wave-defense prototype built with Godot 4. It supports offline solo play and a host-authoritative local Wi-Fi session for up to four players (ENet UDP port 24567); an internet connection is not needed after installation.

## What's new in v0.4.2
- Moved the upper playable boundary closer to the background's sidewalk/road seam while keeping the character ground point on asphalt. The lower edge remains clamped before the foreground curb and fence.
- Added a three-grenade starting inventory and a dedicated touch button. A thrown grenade arcs forward, then explodes with area damage and synced sound/visual effects.
- Added a random supply-drop loop. Each crate can contain ammunition, grenades, barricade kits, or a medkit; the landed crate is labeled to show its loot. Full inventory converts the excess into ammunition.
- Added buildable timber barricades. Place one in the direction the survivor faces; the wall blocks zombies in the same lane, has an HP bar, and can be attacked/destroyed by zombies. Wall kits can come from drops.
- Added six original procedural SFX for grenade toss, explosion, supply drop, wall placement, wall break, and pickup.
- Android version code 15 / version name 0.4.2.

## Controls
- Left virtual analog: move around the middle defense lane.
- Hold FIRE: fire repeated horizontal shots in the direction the survivor last faced. Ammo is consumed per shot.
- HEAL: spend a medkit to restore up to 35 HP.
- GREN: throw one grenade (starts with 3; supply drops can replenish them).
- WALL: spend one wall kit to place a destructible barricade in front of the survivor.
- Pause: resume, manually save, or leave the session.

## Supply drops and barricades
The first supply drop arrives after a short delay, descends under a parachute, and lands in the asphalt lane. Landed crates show their randomized loot label: ammo, grenades, wall kits, or medkit. Touch a crate to collect it. Survivors start with two wall kits; use WALL while facing the desired direction. Walls occupy the shared world, block aligned zombies, and lose durability when attacked.

## LAN multiplayer
The host opens Multiplayer LAN → Create World, then shares its hotspot IPv4 address. Friends connected to the same hotspot select Join World and enter that address. Android hotspot isolation varies by device, so physical-device testing is still required.

## Saved runs
Saving is manual from the host pause menu/lobby. Continue Saved is explicit; new solo/host runs clear previous zombie and effect state. Leaving does not auto-save.

## Build
Push the source ZIP contents so `project.godot` is in the repository root. GitHub Actions imports assets, validates resource references and sound files, checks script markers, runs a headless scene startup, exports a debug APK and uploads a source ZIP.

## Prototype/testing note
SFX are synthesized locally for this project instead of copied from third-party audio packs. Static checks can verify resource paths and formats, but Godot's runtime compilation and actual four-device LAN behavior must be confirmed by GitHub Actions and device testing.
