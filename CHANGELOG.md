# Changelog

## 0.3.6 — landscape configuration correction
- Corrected Godot Android orientation in both the project settings and Android export preset. Godot's `SCREEN_LANDSCAPE` enum is `0`; enum `1` requests portrait.
- Kept runtime display rotation disabled to avoid a startup rotation race.
- Added CI preflight checks so the workflow fails immediately if either orientation setting is accidentally changed away from landscape.
- Bumped Android version code/name to 9 / 0.3.6.

## 0.3.5 — Android startup and landscape attempt
- Startup fallback and runtime rotation removal. The previous orientation enum was incorrectly set to portrait; corrected in 0.3.6.
