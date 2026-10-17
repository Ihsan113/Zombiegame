# Pixel Zombie LAN — v0.3.6 (Landscape Fix)

Godot 4.7.2 Android landscape wave-defense prototype. **Landscape orientation is configured consistently before startup** in both `project.godot` and the Android export preset. The game opens on a home screen; the upper half of the game world shows the ruined city and the lower horizontal lane is the defense arena.

## Current controls
- Left virtual analog: move within the lower arena.
- Hold FIRE: automatic horizontal shots about every 0.30 seconds; release to stop.
- HEAL: use a medkit.
- Pause: resume, save, or leave.

## Local hotspot multiplayer
The host creates a world and friends connect to the same hotspot using the host's IPv4 address. Networking uses ENet UDP port 24567 and does not require internet. Android hotspot/client-isolation behavior still needs testing on physical phones.

## Build
Push the files in this folder to your GitHub repository, then open **Actions → Build Android APK**. The workflow verifies both landscape settings are explicitly set to the correct Godot enum value (`0`) before importing and exporting the project. It uploads a debug APK and source ZIP.

## What this fix changes
- `project.godot`: `window/handheld/orientation=0` (Landscape).
- `export_presets.cfg`: `screen/orientation=0` (Landscape).
- Runtime script does not try to rotate the display after startup.
- Android version code/name is `9` / `0.3.6`, to distinguish it from the earlier broken `0.3.5` package.
- ZIP is clean and flat: `project.godot`, `Main.tscn`, `scripts/`, `assets/` and `.github/` are directly at the archive root; no duplicate nested project folder or `.godot` editor cache.

## Validation note
The orientation configuration and ZIP structure are statically checked here. A Godot executable and Android device are not available in this environment, so this ZIP has not been exported locally or physically tested on a phone. After you push, the GitHub Actions workflow will run an actual Godot import/export and upload its build artifacts.
