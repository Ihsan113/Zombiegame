# Pixel Zombie LAN — v0.4.0 Horror Animation Pass

Godot 4.7.2 Android landscape wave-defense prototype. This is a clean source package based on v0.3.9, focused on removing the false arena seam and adding lightweight survival-horror character motion.

## v0.4.0 visual and animation updates
- Unified UI style: charcoal/steel panels, restrained blood-red accents, warm aged paper text, darker backgrounds and clearer outlines.
- Rebuilt the home screen as a survivor safehouse terminal with a layered title treatment, case-file label, team-colored survivor lineup and consistent menu button sizing.
- Redesigned in-game HUD groups for squad/session, wave progress, vitality and medkit counts.
- Health colors now shift toward amber/red as player HP drops; zombie health bars are clearer and more legible.
- Updated analog joystick and action buttons with heavier outlines, directional indicator and cartridge/medical cross motifs.
- Kept all game controls interactive and preserved press-and-hold FIRE behavior.
- Removed the hard full-width arena top separator and duplicate center-line paint overlay; the background JPG’s actual curb/asphalt transition now defines the play area. The movement bounds start at 51.5% and still end at 92%.
- Added procedural idle breathing, walk bob/sway, soft footstep dust, survivor recoil when firing, red hit flashes, zombie impact flinch, timed melee attacks, lunge/recoil animation and short claw-slash effects.
- Kept server-authoritative movement/combat and replicated animation timers; older saved zombies load with safe animation defaults.
- Version code/name: 13 / 0.4.0.

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


## v0.3.9 — Godot 4.7.2 type-inference fix
- Fixed the parse error in the arena hazard-stripe drawing loop by explicitly typing cover positions and the stripe x-coordinate as floats.
- Android version code/name updated to 12 / 0.3.9.
- CI continues to fail on script parse/load errors and runs a headless startup smoke test before APK export.


## Build status
The clean ZIP includes CI checks for resource references, landscape settings, required animation markers, Godot script import, headless startup, and Android export. This workspace does not include Godot itself, so the full Godot 4.7.2 parser and on-device animation still need confirmation in GitHub Actions and on a phone.
