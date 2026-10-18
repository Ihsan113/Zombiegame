# Pixel Zombie LAN — v0.4.10

A landscape Android zombie wave-defense game made with Godot 4. It supports solo offline play and a host-authoritative LAN session for up to four devices through the same Wi-Fi hotspot. No internet is needed after installation.

## v0.4.10 updates — barricade sits on the asphalt
- The A-frame barricade looked like it floated: one flat ellipse + a straight line were drawn below the sprite, but its four feet touch the road at different depths (3/4 view). Shadows are now anchored to the real foot-pad positions (contact shadow per foot, soft cast shadow following the footprint toward the camera) and the sprite is tinted slightly into the dusk palette.
- The placement preview uses the same grounding and a flattened ring lying on the road. Visual only: no network/gameplay change, so v0.4.9 and v0.4.10 can still play together.

## v0.4.9 updates — smooth for host AND client
- The host used to draw a client's survivor straight from command packets, so it moved in steps (frozen about every second frame, worse with Wi-Fi jitter). The host now draws remote survivors from a short, jitter-adaptive track built from the commands' own durations, so network jitter no longer shows up as stutter. Gameplay (zombie targeting, hits) still uses the exact authoritative position.
- Movement commands and world snapshots now go out at up to 60 Hz (about 11 KB/s in total). The interpolation buffer shrinks accordingly, so other survivors and zombies are drawn ~35-40 ms closer to real time on the client.
- Send timers tolerate half a frame, so packets are evenly spaced instead of alternating 33/50 ms.
- **Every device must install v0.4.9 to play together** (command/snapshot cadence changed).

## v0.4.8 updates — LAN client responsiveness
- Clients now use real prediction with host reconciliation (sequence-numbered movement commands), so your own survivor responds immediately and is only corrected when it truly disagrees with the host.
- World state is sent as a compact binary snapshot (always one UDP datagram, ~30 Hz) instead of a large Dictionary RPC; remote survivors and zombies are interpolated from a timestamped snapshot buffer.
- Your own shots, tracer and sound are instant; host effects are loss-tolerant and line up with what you see.
- Clients show a small NET line (RTT, loss, snapshots/s, KB/s, buffer, prediction error). Set `SHOW_NET_STATS := false` in `scripts/game.gd` to hide it.

## v0.4.7 updates
- Enlarged the transparent A-frame barricade art to match its native aspect ratio and aligned its feet and contact shadow to the survivor ground line. Preview and placed barricade use the same shape; obstacle spacing and zombie attack distance match its width.
- Removed the long ground-to-projectile tether during grenade throws. The grenade now has a ground shadow and tiny motion sparks; explosion feedback includes a collapsing fireball, expanding shock rings, radial sparks, scorch shadow and rising smoke.
- Added client-side local-player prediction with gentle correction to the host state, plus interpolation for remote players and zombies.
- Clients submit movement at about 30 Hz; the host broadcasts snapshots at about 15 Hz. ENet FastLZ compression is enabled symmetrically. Fire input no longer causes an extra full-world broadcast for every shot.
- Host remains authoritative for movement bounds, combat hits, health, grenade damage, loot and barricade placement.

## Controls
- Left virtual analog: move in the lower defense lane.
- Hold FIRE: repeat horizontal shots in the last left/right facing direction. Ammo is unlimited.
- HEAL: consume one medkit to restore up to 35 HP.
- GREN: hold and drag to the landing point, then release to throw. The dotted arc and landing marker show the aim.
- WALL: hold and drag the A-frame barricade preview, then release when it is green. Red indicates invalid placement. Barricades block aligned zombies, have HP and can be destroyed.
- Pause: resume, manually save, or leave the session.

## Supply drops
Supply crates descend under a parachute. Loot is randomized between grenades, wall kits and medkits. If a category is full, excess loot converts to a useful alternative rather than ammunition, because ammunition is unlimited.

## LAN setup
The host selects **Multiplayer LAN → Create World** and shares the hotspot IPv4 address. Other devices must join the same hotspot, select **Join World**, and enter that address. Wi-Fi hotspot isolation and device performance vary, so test the actual phones together. Client prediction/interpolation reduces perceived input delay and snapshot stepping; it cannot compensate for a poor hotspot or a heavily loaded device.

## Build from source
Push the ZIP contents so `project.godot` is in the repository root. GitHub Actions checks resource references, landscape configuration, script markers, SVG/WAV assets, Godot import and headless startup before exporting a debug APK and uploading a source ZIP. Install only after the workflow succeeds.

## Verification
v0.4.10 was parsed and run in Godot 4.7.2 (netcode checked at v0.4.9, barricade visuals rendered via Xvfb) (headless): snapshot codec tests plus a real host+client session over UDP with simulated delay, jitter and packet loss (`tools/net_test/`). Real-phone testing is still recommended for frame pacing, hotspot behavior and four-device sessions.


## v0.4.7 — Godot 4.7 ENet compression API fix
- Fixed the LAN compression compile error: Godot 4.7 defines `COMPRESS_FASTLZ` on `ENetConnection`, not `ENetMultiplayerPeer`.
- Host and client now create their ENet peer first, then call `peer.host.compress(ENetConnection.COMPRESS_FASTLZ)` before assigning it to `multiplayer.multiplayer_peer`.
- The CI validator rejects the invalid legacy enum/property spelling and checks that both sides use the same compression mode.
- Android version code/name: 20 / 0.4.7.
