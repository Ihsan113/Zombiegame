# Pixel Zombie LAN — v0.3.5

Godot 4.7.2 Android landscape wave-defense prototype. The game starts directly in landscape. The upper half of the screen displays a ruined city at sunset; the lower horizontal lane is the defense arena.

## Current controls
- Left virtual analog: move in the lower arena.
- Hold FIRE: automatic horizontal shots at ~0.30-second intervals; release to stop.
- HEAL: use a medkit.
- Pause: resume, save, or leave.

## Local hotspot multiplayer
The host creates a world and friends connect to the same hotspot using the host's IPv4 address. Networking uses ENet UDP port 24567 and does not require internet. Android hotspot/client-isolation behavior still needs testing on physical phones.

## Build
Push this project to a GitHub repository, then open **Actions → Build Android APK**. The workflow validates/imports Godot resources, exports a debug APK and uploads a source ZIP. The Android export preset and project are both configured for landscape before startup; the runtime script no longer forces rotation during initialization.

## Startup recovery notes
The renderer paints a solid underlay before UI/world drawing, and the app logs warnings if the background or sprite atlas fails to load. Missing images should therefore produce a fallback scene rather than a fully black canvas. Build success does not replace testing on the target Android device.
