# Pixel Zombie LAN — v0.4.3

A landscape Android zombie wave-defense prototype built with Godot 4. It supports offline solo play and a host-authoritative local Wi-Fi session for up to four players (ENet UDP port 24567); an internet connection is not needed after installation.

## What's new in v0.4.3
- Infinite ammunition: FIRE no longer consumes bullets; the HUD shows `AMMO ∞`. Airdrops now contain useful loot instead of redundant ammo: grenades, wall kits or medkits.
- PUBG-style grenade aiming: tap GREN to enter aim mode, adjust the range slider, review the dotted arc and impact marker/distance, then tap THROW. CANCEL exits without consuming a grenade. The host validates and simulates the actual range.
- Barricade placement preview: tap WALL, drag the ghost to a valid point near your survivor, then tap PLACE. Invalid spots turn red; CANCEL exits. The host validates range, lane, overlaps, wall capacity and wall-kit inventory.
- Replaced simple grenade, barricade and airdrop drawings with detailed, transparent vector assets: olive fragmentation grenade, braced timber-and-steel barricade, rugged military supply crate and segmented parachute.
- Airdrop loot has randomized useful items and labeled pickup rewards. If a category is full, overflow converts to a medkit or emergency HP rather than wasted ammo.
- Android version code 16 / version name 0.4.3.

## Controls
- Left virtual analog: move around the defense lane.
- Hold FIRE: fire horizontal shots in the direction the survivor last faced. Ammunition is unlimited.
- HEAL: spend one medkit to restore up to 35 HP.
- GREN: tap to aim, drag the range slider, then tap THROW. The preview shows the estimated landing point and range; CANCEL exits aim mode. Starts with 3 grenades, supply drops can replenish them.
- WALL: enter placement mode, drag the translucent barricade preview around the lane, then tap PLACE when green. CANCEL exits without using a kit. Barricades block aligned zombies, have HP and can be destroyed.
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
New grenade/barricade/airdrop art is original SVG artwork; SFX are synthesized locally. Static checks verify resource paths and formats, but Godot runtime compilation, touchscreen feel and actual four-device LAN behavior must be confirmed by GitHub Actions and device testing.
