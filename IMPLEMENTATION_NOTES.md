# Implementation notes — v0.3.6

- Main entry point: `Main.tscn` → `scripts/game.gd`.
- **Landscape must use enum value 0**: `project.godot` contains `window/handheld/orientation=0` and `export_presets.cfg` contains `screen/orientation=0`. Value 1 is portrait and was the root cause of the previous build reverting to vertical orientation.
- Runtime `DisplayServer.screen_set_orientation` is intentionally not used.
- `_draw()` paints an opaque background underlay before the home/world UI. The background loads from `assets/arena_bg.jpg`; if missing, the draw routines render a solid procedural fallback.
- `assets/arena_bg.jpg` is 1200×540. `assets/sprite_atlas.png` is a 320×192 transparent atlas with four 64×80 survivor cells, four 64×80 zombie cells, and 32×32 combat-effect cells.
- FIRE supports touch-and-hold repeat firing at 0.30-second intervals and release-to-stop behavior.
- LAN uses ENet/UDP port 24567. Four-device hotspot connectivity still requires physical testing.
- GitHub Actions validates orientation, imports project resources, exports a debug APK and uploads a source ZIP. CI success does not replace testing on the target phone.
