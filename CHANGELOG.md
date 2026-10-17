# Changelog

## 0.2.0 — LAN foundation pass
- Switched the project to landscape orientation.
- Updated the CI build target to the official Godot 4.7.2 stable release.
- Reworked multiplayer movement so clients send input vectors and the host computes authoritative positions.
- Changed state sync to ordered-unreliable snapshots at approximately 10 Hz and client input at approximately 20 Hz.
- Moved firing, player damage, healing and medkit consumption to the host.
- Added cooldowns to firing and healing.
- Made host LAN-IP information remain visible in the HUD while player join/disconnect messages change.
- Added IPv4 input validation and improved the join prompt.
- Added client position interpolation, landscape UI refinements, simple building placeholders and basic save-data validation.
- Added `README.md`, implementation notes, versioning and CI artifact instructions.

## Known limitations
- Not compiled or tested in Godot in the current environment.
- Artwork and collision are placeholders; no tilemap, loot system, crafting, weapon inventory, animations, sound or host migration yet.
- Hotspot peer-to-peer connectivity varies by Android device and must be tested on real phones.
