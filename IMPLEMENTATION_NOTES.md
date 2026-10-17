# Implementation notes — v0.4.2

- Play-lane top is 52% of viewport height, with a 22 px center-point clearance: the character ground shadow/feet remain just below the sidewalk-to-asphalt join. The lower bound remains 86.5% with a 40 px clearance to keep sprites above the foreground fence.
- New survivors start with 120 bullets, 3 grenades, 2 wall kits, and 2 medkits. Grenades use host-authoritative projectiles, a timed blast and synchronized combat effects. Ammo remains host-authoritative and is consumed per shot.
- Airdrops are host-spawned and randomized across four loot classes: ammunition (45–75 rounds), grenades (1–2), wall kits (1–2), or a medkit (1). The landed crate label reflects the loot class; pickup and rewards replicate with the world snapshot. Excess pickups convert to bullets at inventory capacity.
- Barricades are shared dictionaries with position, HP, max HP, and owner ID. The host places them in front of an alive player, rejects close overlaps, caps total active walls, and decrements durability as aligned zombies attack. Walls are included in world snapshots and saves.
- All six new sound clips are locally generated 22050 Hz mono 16-bit PCM WAV; runtime only references `res://assets/audio/*.wav`. No third-party sound source is needed.
- CI validates required gameplay markers, all `res://` references, landscape settings, WAV format/presence, Godot import/compiler output, a headless scene start, and APK export. This source package has not been compiled in the local environment; the CI run remains the engine-level verification step.
