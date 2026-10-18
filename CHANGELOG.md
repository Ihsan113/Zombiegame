# Changelog

## 0.4.3 — infinite ammo, aimable grenades, and deployable barricades
- Switched to infinite ammunition and changed HUD to `AMMO ∞`; removed ammo-consuming fire logic.
- Replaced ammo drops with useful randomized grenade, wall-kit, and medkit drops. Capped loot converts to medkits or HP; old saved ammo drops migrate to a grenade cache.
- Added grenade aim mode, a range slider, estimated distance, dotted ballistic arc, landing crosshair, throw/cancel steps, normalized multiplayer range requests and range-dependent trajectory/fuse.
- Added wall placement preview with drag-to-position, green/red validity feedback, place/cancel controls and host-side checks for distance, lane, inventory, overlap and active barrier count.
- Added detailed transparent SVG assets for fragmentation grenade, braced timber barricade, military supply crate and parachute canopy.
- Updated all relevant reset paths for new targeting states; Android version code/name 16 / 0.4.3.

## 0.4.2 — tighter lane, grenades, loot drops and barricades
- Moved the upper playable boundary closer to the background's sidewalk/road seam while keeping the character ground point on asphalt. The lower edge remains clamped before the foreground curb and fence.
- Added a three-grenade starting inventory and a dedicated touch button. A thrown grenade arcs forward, then explodes with area damage and synced sound/visual effects.
- Added randomized supply crates and buildable, destructible timber barricades.
- Added procedural sound effects for grenade toss, explosion, supply drop, wall placement, wall break, and pickup.

## 0.4.1 — lane bounds, wave clock, game over and SFX
- Added per-wave countdown and overtime, squad-wide Game Over, clean restart, explicit save/continue, and original procedural WAV cues.

## 0.4.0 — arena and animation
- Added a more complete horror backdrop, lower-lane bounds, animated walk/attack/hurt visuals and horror-themed UI.
