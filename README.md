# Pixel Zombie LAN — v0.2.0 prototype

A Godot 4 top-down zombie survival starter for Android. The target is four human players on the same local Wi-Fi/hotspot, with no internet connection required during a session.

## What is implemented in this iteration

- Landscape touch-first screen layout.
- Virtual movement joystick plus FIRE and HEAL buttons.
- ENet/UDP host and join flow (port `24567`) for up to four players total.
- Host-authoritative player movement: clients submit a direction vector, and the host calculates world positions.
- Host-authoritative zombie spawning, chasing, player damage, firing and healing.
- Two medkits per fresh character; a heal restores up to 35 HP and uses one medkit.
- Client smoothing for player snapshots at about 10 snapshots per second; movement inputs are sent at about 20 updates per second.
- Host save/load of world time, seed and zombie state to `user://world_save.json`.
- GitHub Actions workflow that imports and exports a debug APK, then uploads it as an artifact.

## Important prototype limitations

This is **not a finished or verified APK**. This environment does not include Godot and cannot reach GitHub release assets, so the project could not be compiled here. The GitHub Actions run is the first real compilation check and may reveal export-setting or GDScript errors that need another iteration.

- The map is currently drawn with placeholder shapes rather than a finished sprite sheet or tilemap.
- Host migration, player reconnect tokens, loot/inventory, crafting, collision, animation, sound and full save-slot management are not implemented yet.
- Host world saves retain seed, world time and zombies. Character inventory/player positions are deliberately reset when a saved world is opened.
- Join uses a manually entered IPv4 address. The host status shows a candidate LAN IP, but phones can expose multiple interface addresses; use the address reachable from the other devices.
- Android hotspot implementations may isolate connected clients. If joining fails despite the correct IP, try another phone as hotspot host or a Wi-Fi router that permits peer-to-peer traffic.
- The debug APK is intended for testing/sideloading, not Play Store publication. A production release needs a private signing key and release configuration.

## Build with GitHub Actions

1. Extract the ZIP on your phone. Open the inner `PixelZombieLAN` project folder.
2. Create a new GitHub repository (for example `PixelZombieLAN`) and upload the **contents inside that project folder** to the repository root. Do not upload the ZIP as a single file or leave `project.godot` nested one extra folder deep.
3. Open the repository's **Actions** tab and allow workflows if GitHub prompts you.
4. Push to `main`/`master`, or run **Build Android APK** with **Run workflow**.
4. When the run succeeds, download `PixelZombieLAN-APK` from its Artifacts section.
5. Install the APK on the four Android devices. For the next update, uninstall old test APKs if signature conflicts occur.

## Local hotspot play

1. On the host phone, enable its Wi-Fi hotspot. Internet/mobile data is not needed for local packets.
2. Connect up to three other phones to that hotspot.
3. Open the game on the host and tap **HOST**. Note the IP shown in the status line (confirm it is the hotspot-side address if multiple IPs are present).
4. On other phones, tap **JOIN**, enter the host's reachable IPv4 address, and confirm.
5. Use the left joystick to move, FIRE to hit the nearest zombie within range, and HEAL to consume a medkit.
6. Tap SAVE on the host to save the current world. The host also autosaves approximately every 30 seconds.

## Technology

- Godot 4.7.2 stable
- GDScript
- ENet multiplayer over UDP
- GitHub Actions
