# Implementation notes — v0.2.0

## Networking model
- The host listens on UDP port `24567` with capacity for three remote peers (four players total including host).
- Clients send normalized input vectors; the host owns position, zombie AI, HP, shots, healing and medkit consumption.
- Host world snapshots are sent around 10 times per second. Client joystick input is sent around 20 times per second.
- This is a LAN prototype, not a hardened public multiplayer service. Validate all requests and add rate limits/timeout handling before wider release.

## Save model
- The host writes `version`, `seed`, `time` and `zombies` to `user://world_save.json`.
- Loading clamps saved zombie positions and HP to expected bounds and creates a fresh player session.
- Save schema migration and corruption recovery beyond basic JSON checks are future work.

## Build
- Workflow uses the latest stable Godot 4.7.2 release as listed in the official Godot archive as of 2026-10-17.
- Workflow stores export templates in `~/.local/share/godot/export_templates/4.7.2.stable`, configures Java/Android SDK paths, imports the project, exports an Android debug APK, and uploads it.
- The workflow has not been executed in this environment. Its result is the required validation step before installing the APK.
