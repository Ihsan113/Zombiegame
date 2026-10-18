# Implementation notes — v0.4.4

- Player ammo uses `-1` as the infinite-ammo sentinel. Fire cadence and host-side hit resolution are unchanged; `_host_fire` neither blocks nor decrements on ammo.
- Random supply pools are: grenades (48%), wall kits (34%), medkit (18%). There is no new ammo loot; v0.4.2 saved ammo caches migrate to one grenade cache.
- Grenade aim state is local UI state only. The range control normalizes to a ratio of logical viewport width; `request_grenade(range_ratio)` sends that ratio to the host, which clamps it, computes the landing point and flight time, consumes a grenade, simulates the fuse/blast and broadcasts the world.
- Grenade range is 6.5–30% of logical viewport width. The preview draws a dotted ballistic arc, a ground ellipse, crosshair, distance label and a touch-controlled range slider. Tap GREN → adjust slider → THROW; CANCEL does not consume an item.
- Wall placement uses `wall_place_active` and a translucent preview. Touch/cursor movement inside the lane moves the preview, then PLACE sends normalized x/y to the host. Host validation checks alive state, available kit, max active walls, min/max distance, lane edges and overlap; wall collision/HP/destruction remain host-authoritative.
- `assets/grenade_detail.svg`, `barricade_detail.svg`, `airdrop_crate_detail.svg`, and `parachute_detail.svg` are original layered SVG art; `game.gd` has primitive fallbacks if a texture cannot load. Parachute suspension lines are drawn separately to match animated crate position.
- CI validates all `res://` references, XML well-formedness for SVGs, all 14 WAVs, landscape settings, feature markers, Godot import/compiler output, headless scene startup and APK export. Device-level aim handling and four-phone LAN still need physical testing.


## v0.4.4 maintenance fix
- The validator looked for explicit `loot_tag = "GREN +%d"` and `loot_kind = "grenade"` statements, while v0.4.3 only initialized those values. The landed-loot `match` now explicitly handles the grenade case and the code/validator agree.
- Existing legacy drops stored as `ammo` are treated as one grenade because ammo is now unlimited.
- Version metadata: Android code 17 / version 0.4.4.
