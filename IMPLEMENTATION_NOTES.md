# Implementation notes — v0.3.5

- Main entry point: `Main.tscn` → `scripts/game.gd`.
- Landscape is set before launch in `project.godot` (`window/handheld/orientation=1`) and Android export preset (`screen/orientation=1`). Runtime `DisplayServer.screen_set_orientation` was removed to avoid a startup rotation race/stale viewport.
- `_draw()` paints an opaque background safety layer first. `_draw_apocalypse_backdrop()` uses `assets/arena_bg.jpg` and falls back to a procedural colored backdrop if loading fails.
- `assets/arena_bg.jpg` is 1200×540. `assets/sprite_atlas.png` is a transparent 320×192 atlas: four 64×80 survivor cells, four 64×80 zombie cells, and 32×32 combat effects.
- FIRE supports touch-and-hold repeat firing at 0.30-second intervals and release-to-stop behavior.
- Local multiplayer uses ENet/UDP port 24567. Host-authoritative game state is intended for up to four local Wi-Fi phones; physical hotspot multiplayer is not covered by CI.
- Workflow exports a debug APK. CI success validates import/export but cannot establish that the app renders correctly on every phone; test the output package on the target device.
