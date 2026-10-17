# Changelog

## 0.3.6 — landscape configuration correction
- Corrected Godot Android orientation in both the project settings and Android export preset. Godot's `SCREEN_LANDSCAPE` enum is `0`; enum `1` requests portrait.
- Kept runtime display rotation disabled to avoid a startup rotation race.
- Added CI preflight checks so the workflow fails immediately if either orientation setting is accidentally changed away from landscape.
- Bumped Android version code/name to 9 / 0.3.6.

## 0.3.5 — Android startup and landscape attempt
- Startup fallback and runtime rotation removal. The previous orientation enum was incorrectly set to portrait; corrected in 0.3.6.



## 0.3.7 — fix blank screen and asset fallbacks
- Fixed the `draw_circle()` call missing the radius argument in the FIRE button, which caused a GDScript parse error and prevented the scene from drawing.
- Added workflow checks that fail on script parse/load errors, validate all `res://` file references, and run the main scene headlessly before APK export.
- Added a project icon and functional PNG/JPG-to-SVG fallbacks. The sprite renderer supports both 64×80 PNG cells and 80×80 SVG cells.
- Removed unused helper functions. Android version code/name: 10 / 0.3.7.


## 0.3.8 — proportional survival-horror UI
- Rebuilt the home screen with a safehouse terminal, case-file headers, blood-red typography and team lineup.
- Unified panels/buttons to a charcoal, steel and muted-crimson style.
- Improved HUD hierarchy for wave progression, squad/session status, vitality and medkits.
- Added HP color thresholds, more legible zombie HP bars and tactile combat buttons.
- Refined the lane shading/cover visuals, moved its bounds to match the background road, and preserved hold-to-fire.
- Android version code/name: 11 / 0.3.8.


## 0.3.9 — parser fix
- Fixed Godot 4.7.2 `Cannot infer the type of "sx"` by explicitly typing the hazard cover positions and stripe coordinates.
- Android version code/name: 12 / 0.3.9.


## 0.4.0 — seamless arena and living characters
- Moved the playable area start from 56.5% to 51.5%, aligned to the original background’s curb/asphalt edge.
- Removed artificial full-width arena separators and duplicate yellow lane dashes so the background artwork supplies the transition/road markings naturally.
- Added procedural survivor/zombie idle breathing and walk bob/sway, small footstep dust, muzzle-fire recoil, hit flashes/shake, and zombie lunge/recoil.
- Reworked zombie melee from continuous touch damage into readable timed strikes with a short claw swipe; tuned standard/runner/heavy hit cadence while keeping comparable damage rates.
- Preserved host-authoritative combat and replicated animation timers; added safe defaults for saved zombie state.
- Added CI checks for animation implementation markers; Android version code/name 13 / 0.4.0.
