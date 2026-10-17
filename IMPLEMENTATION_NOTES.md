# Implementation notes — v0.3.7

## Startup failure diagnosis
The blank dark screen was traced to the v0.3.6 GitHub Actions logs. Godot reported a GDScript parse error in `_draw_action_button()`: `draw_circle(pos, color)` omitted the required radius argument. Because `scripts/game.gd` did not compile, `Main.tscn` could not execute the script's `_draw()` callback, and the app stayed on the engine's default clear color. The invocation is now `draw_circle(pos, radius, color)`.

## Entry point and rendering
- Main scene: `Main.tscn`.
- Script: `scripts/game.gd`.
- `_ready()` loads art in this order: `sprite_atlas.png` then `sprite_atlas.svg`; `arena_bg.jpg` then `arena_bg.svg`.
- The PNG atlas is 320×192: four 64×80 survivor cells, four 64×80 zombie cells, and 32×32 effect cells. The SVG fallback is 320×240 with 80×80 character cells; the renderer detects which layout is loaded.
- `assets/game_icon.png` is used by Godot project settings and removes the earlier no-icon export warning.

## Controls and multiplayer
- Landscape orientation is set in both `project.godot` and `export_presets.cfg`; both use orientation enum value `0`.
- FIRE supports tap-to-fire plus hold-to-repeat at 0.30-second intervals, then release-to-stop.
- LAN uses ENet/UDP port 24567 and targets four phones on the same local hotspot. Physical device networking has not been verified in this workspace.

## Build safeguards
The GitHub Actions workflow now validates required files, checks static `res://` resource paths and landscape settings, scans Godot editor-import output for script parse/load errors, and launches `Main.tscn` headlessly before APK export. This prevents a build from being marked successful solely because an APK file was exported despite a failed script load.

The script fix and resource references were checked statically. This workspace does not contain a local Godot executable and cannot download one, so a fresh Godot export and physical Android test must still run after pushing this ZIP.


## v0.3.8 UI implementation notes
- All menus and HUD are drawn by `scripts/game.gd`; no external UI scene dependency was added.
- The home page uses a darkened existing `arena_bg.jpg`/SVG fallback with responsive spacing and a consistent safehouse terminal.
- The HUD is split into squad/session, wave progress, vitality and bottom control groups.
- Player health uses green/amber/red thresholds; zombie bars use a dark backplate and amber/coral/crimson fill by remaining health.
- FIRE remains a press-and-hold control, including release-to-stop cleanup on pause/session reset.
- The in-game lane starts at 56.5% and ends at 92% of viewport height, aligning more closely to the illustrated road.
- Static source/resource checks can be inspected locally; the actual Godot parser, render and Android run must still pass in GitHub Actions/on a physical device.


## v0.3.9 compile fix
- In `_draw_game_world()`, the loop uses a typed `Array[float]`; each cover X value and `sx` are explicitly converted/declared as `float`, avoiding the Godot 4.7.2 Variant inference parse error.
- The provided CI workflow validates scripts and starts the project headlessly before exporting an APK.


## v0.4.0 arena and procedural animation
- The background image’s own curb marks the transition. `ARENA_TOP_RATIO=0.515` keeps spawn/movement inside the asphalt section without a second full-width rendered divider. The renderer no longer draws duplicate lane-centre dashes, since the JPG already contains those markings.
- `animation_clock` advances locally every frame. `_character_visual_position()` adds light idle breathing and walk bob; `_draw_atlas_character()` adds tiny body sway/squash, lunge/recoil, hit shake and a short red impact tint.
- Walking survivors/zombies get small procedural dust puffs. The host publishes `walking`, `shoot_timer`, `hurt_timer`, `attack_timer`, `attack_cooldown`, `hit_timer`, and attack state in world snapshots so LAN peers show matching action states.
- Zombie contact now uses `ZOMBIE_ATTACK_RANGE` and a cooldown-based melee hit with an animated claw swipe, rather than continuously draining player HP each frame. Standard, runner and heavy types use different damage/cadence values.
- This is a lightweight procedural animation over the existing sprite atlas, not a new multi-frame skeletal sprite sheet. Godot parser/startup smoke tests and physical Android/hotspot play still need to pass after push.
