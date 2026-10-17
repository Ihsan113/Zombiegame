# Pixel Zombie LAN — v0.3.8 Horror UI Pass

Godot 4.7.2 Android landscape wave-defense prototype. This is a clean source package based on v0.3.7, focused on a more proportional survival-horror interface and better visual hierarchy.

## v0.3.8 visual updates
- Unified UI style: charcoal/steel panels, restrained blood-red accents, warm aged paper text, darker backgrounds and clearer outlines.
- Rebuilt the home screen as a survivor safehouse terminal with a layered title treatment, case-file label, team-colored survivor lineup and consistent menu button sizing.
- Redesigned in-game HUD groups for squad/session, wave progress, vitality and medkit counts.
- Health colors now shift toward amber/red as player HP drops; zombie health bars are clearer and more legible.
- Updated analog joystick and action buttons with heavier outlines, directional indicator and cartridge/medical cross motifs.
- Kept all game controls interactive and preserved press-and-hold FIRE behavior.
- Tightened the playable arena to match the street section of the background and added a subtle night grade plus grounded hazard cover.
- Version code/name: 11 / 0.3.8.

## Controls
- Left virtual analog: move within the lower defense lane.
- Hold FIRE: automatic horizontal shots about every 0.30 seconds; release to stop.
- HEAL: use a medkit.
- Pause: resume, save, or leave.

## Local hotspot multiplayer
The host creates a world and friends connect to the same hotspot using the host's IPv4 address. Networking uses ENet UDP port 24567 and does not require internet. Android hotspot/client-isolation behavior still needs testing on physical phones.

## Build from GitHub Actions
1. Push the files from the root of this ZIP to your repository (the ZIP has `project.godot` directly at its root).
2. Open **Actions → Build Android APK**.
3. Install the APK artifact only if landscape, resource-reference, Godot import, script parse/load, and headless startup checks all pass.

This package has not been freshly exported or physically tested on Android in this environment. The workflow is configured to run the real Godot import, startup smoke test, and APK export after you push it.
