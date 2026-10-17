# Changelog

## 0.4.1 — lane bounds, wave clock, game over and SFX
- Constrained survivor/zombie centers and full 70–80 px sprite bounds to the background's asphalt corridor (top 56.5%, bottom 86.5%).
- Added an independent countdown per wave (90s, -3s per wave to a 55s floor); overtime speeds zombie walking by 18% and continues until all 25 wave enemies are eliminated.
- Added squad-wide Game Over, host-synced game-over screen, restart request, full restart and return-to-safehouse actions.
- New runs don't restore leftover zombies. Saving is explicit; Continue Saved is separate. Leaving clears runtime arrays/state and no longer auto-saves zombie positions every 30 seconds.
- Added eight locally-generated WAV SFX and synchronized key gameplay cues across LAN.
- Android export version code/name: 14 / 0.4.1.

## 0.4.0 — arena and animation
- Lower-lane bounds, animated walk/attack/hurt visuals, footsteps and horror UI.
