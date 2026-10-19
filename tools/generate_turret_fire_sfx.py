#!/usr/bin/env python3
"""Regenerate the compact deterministic turret-fire WAV used by Pixel Zombie LAN."""
from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "turret_fire.wav"
RATE = 22050
DURATION = 0.165
N = int(RATE * DURATION)
t = np.arange(N, dtype=np.float64) / RATE
rng = np.random.default_rng(9072)
raw = rng.normal(0.0, 1.0, N)
low_pass = np.zeros(N, dtype=np.float64)
coefficient = 0.23
for i in range(1, N):
    low_pass[i] = low_pass[i - 1] + coefficient * (raw[i] - low_pass[i - 1])
low = np.sin(2 * np.pi * (105 - 42 * (t / DURATION)) * t) * np.exp(-t * 26.0)
mid = np.sin(2 * np.pi * (440 - 155 * (t / DURATION)) * t) * np.exp(-t * 47.0)
signal = 0.46 * low_pass * np.exp(-t * 31.0) + 0.28 * raw * np.exp(-t * 85.0) + 0.34 * low + 0.13 * mid
signal += 0.32 * np.sin(2 * np.pi * 1800 * t) * np.exp(-((t - 0.004) / 0.0028) ** 2)
bolt_t = np.maximum(t - 0.075, 0)
signal += 0.09 * np.sin(2 * np.pi * 680 * bolt_t) * np.exp(-bolt_t * 42.0) * (t >= 0.075)
signal *= np.minimum(1.0, np.arange(N) / (RATE * 0.002))
signal /= max(1e-9, float(np.max(np.abs(signal))))
pcm = (signal * 0.82 * 32767).astype("<i2")
OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(RATE)
    wav.writeframes(pcm.tobytes())
print(f"Wrote {OUT}")
