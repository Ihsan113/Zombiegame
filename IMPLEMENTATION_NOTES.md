# Implementation notes — v0.4.5

- Project target is landscape Android with Godot 4; gameplay supports offline solo and a host-authoritative LAN session over ENet/UDP port 24567.
- Ammunition is unlimited (`ammo = -1`); supply loot focuses on grenades, wall kits, and medkits.
- `assets/barricade_detail.png` is the primary transparent A-frame road barricade. `assets/barricade_detail.svg` provides a matching low-cost vector fallback. The in-game render uses a wide 86×52 rectangle anchored to the barrier's feet, a tight ground shadow, and a health bar above the hazard beam.
- Grenade interaction is one hold-drag-release gesture: press GREN to start aiming, drag a target within the defense lane, then release to throw. The preview draws a dotted arc, a landing reticle and an estimated range. Target X/Y are sent as normalized viewport coordinates to the host; host validation clamps the landing point to the lane and the minimum/maximum throw distance.
- Wall placement uses the same gesture pattern: press WALL, drag the barricade ghost to a valid nearby point, and release to request placement. Green/red tint communicates validity; the host validates inventory, alive state, distance, lane, overlap and active wall capacity. Barricades block aligned zombies, take damage, and can be destroyed.
- Touch ID is captured when the action button is pressed. Drag events update the same gesture and release queues at most one action. Pause/session cleanup clears active targeting state.
- CI validates resource references, landscape settings, feature markers, transparent PNG existence, SVG well-formedness and WAV format, then runs Godot import, headless startup and Android APK export. Physical touch feel and four-phone LAN still require device testing.
