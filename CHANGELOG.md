# Changelog

## 0.3.5 — Android startup and landscape fix
- Fixed conflicting portrait/landscape configuration: the project and Android export preset both request landscape before the first frame.
- Removed runtime screen rotation from `_ready()` to avoid forcing rotation while Android/Godot is initializing the viewport.
- Added an opaque canvas safety underlay and warnings for missing background/sprite assets so a missing texture does not leave an empty black canvas.
- Included the latest hold-to-fire control and detailed 64×80 PNG sprite atlas handling.
- Replaced the tiny 400×180 background with a 1200×540 generated apocalyptic street backdrop.
- Android version code/name set to 8 / 0.3.5.

## 0.3.4 — detailed sprites, arena art and hold-to-fire
- Uses the detailed transparent PNG sprite atlas for four survivors, four zombie types and combat effects.
- Adds a ruined-city skyline, sunset haze, wrecked vehicles, road texture, barricades, fence and debris.
- Holding FIRE automatically shoots at about 3.3 shots per second; releasing stops firing.
- Bullets use a moving projectile with a very short trail instead of a continuous laser beam.
