# Pixel Zombie LAN — v0.4.1

A landscape Android zombie wave-defense prototype built with Godot 4. Supports an offline solo run and a host-authoritative local Wi-Fi session for up to four players (ENet UDP port 24567). Internet is not needed after installation.

## What's new in v0.4.1
- Corrected the playable lane to fit inside the actual asphalt corridor: the character body is constrained so heads and feet stay within the curb/road area near both ends.
- Added a per-wave 90-second countdown, shortening by 3 seconds per wave until a 55-second minimum. When the timer expires, the game enters overtime and zombies become 18% faster; all wave zombies must still be eliminated before the next wave.
- Added a proper squad Game Over overlay when every connected player is down. It stops combat, shows the wave/status, and offers Restart Run or Return to Safehouse. A LAN client may request a restart from the host.
- Restart clears zombies, effects, cooldowns and wave counters, then restores players and medkits.
- Leaving a session clears runtime actors without silently writing zombie positions to the save. New Solo/Host runs start with a clean arena. Manual Save is explicit; Continue Saved is a separate home-screen option.
- Added eight original, compact procedural WAV sound effects: gun pop, hit thud, zombie attack groan, death groan, heal cue, wave-start cue, wave-clear stinger, and Game Over sting. LAN hosts relay gameplay SFX events to clients.
- Version code 14 / version name 0.4.1.

## Controls
- Left virtual analog: move only inside the road lane.
- Hold FIRE: shoot repeatedly every 0.30 seconds in the direction the survivor last faced.
- HEAL: consume one medkit to restore up to 35 HP.
- Pause: resume, manually save, or abandon the session.
- On Game Over, Restart Run starts a clean attempt (clients ask the host); Return to Safehouse leaves the session.

## LAN multiplayer
The host opens Multiplayer LAN → Create World, then shares its hotspot IPv4 address. Friends on the same hotspot select Join World and enter that address. Android hotspot isolation/firewall behavior varies; physical-device testing is required.

## Saved runs
Saving is manual from the host pause menu/lobby. The home screen offers Continue Saved only as an explicit action. New Solo Run and Create World deliberately start clean and do not load old zombie positions. Exiting does not auto-save.

## Build
Push the source ZIP contents so `project.godot` is in the repository root. GitHub Actions imports assets, validates scripts with a headless scene start, checks landscape/res references/audio files, exports a debug APK and uploads a source artifact.

## Limits
This remains a prototype. The WAV sound effects are generated procedurally for this project to avoid uncertain third-party sound licensing. LAN behavior and the final on-device visuals/audio should be tested on the target phones before distribution.
