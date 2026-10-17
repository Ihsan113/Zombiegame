# Pixel Zombie LAN — v0.3.7 (Clean Startup Fix)

Godot 4.7.2 Android landscape wave-defense prototype. The v0.3.6 screen was blank because `scripts/game.gd` had a GDScript parse error in the FIRE button renderer: `draw_circle()` was called without its required radius argument. The correct call is now `draw_circle(pos, radius, color)`, allowing the scene script to load and `_draw()` to render the home screen.

## Current controls
- Left virtual analog: move within the lower defense lane.
- Hold FIRE: automatic horizontal shots about every 0.30 seconds; release to stop.
- HEAL: use a medkit.
- Pause: resume, save, or leave.

## Local hotspot multiplayer
The host creates a world and friends connect to the same hotspot using the host's IPv4 address. Networking uses ENet UDP port 24567 and does not require internet. Android hotspot/client-isolation behavior still needs testing on physical phones.

## Build from GitHub Actions
1. Push the files in this directory to your repository (the ZIP is flat, with `project.godot` at its root).
2. Open **Actions → Build Android APK**.
3. Download the APK artifact only if **Verify project resources**, **Import and validate project scripts**, and the headless smoke test all pass.

The workflow now fails when Godot reports `SCRIPT ERROR`, `Parse Error`, or `Failed to load script`, rather than exporting a broken APK anyway. It also checks the `res://` references and the landscape settings before export.

## v0.3.7 changes
- Fixed the malformed `draw_circle()` invocation that prevented `game.gd` from compiling and left the app at the engine's default clear color.
- Added a project icon to remove the previous no-icon export warning.
- Added PNG/JPG-to-SVG fallbacks. The detailed PNG sprite atlas uses 64×80 character cells; the SVG fallback uses 80×80 cells, and the renderer now handles both layouts correctly.
- Removed two unused helper functions and added CI script-error detection plus a headless scene startup test.
- Both `project.godot` and `export_presets.cfg` specify landscape orientation. Version code/name: `10` / `0.3.7`.

## Validation status
I confirmed the exact parse error from the GitHub Actions logs for the broken build and corrected that line. This environment has no local Godot executable and cannot reach GitHub's release downloads, so the corrected project has not been freshly exported or physically tested on Android here. The included workflow will perform the real Godot import, startup smoke test, and APK export after you push the ZIP contents.
