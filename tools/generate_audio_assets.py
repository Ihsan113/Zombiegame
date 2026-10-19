from pathlib import Path
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUT.mkdir(parents=True, exist_ok=True)
SR = 22050
rng = np.random.default_rng(1947)

def write_wav(name: str, signal: np.ndarray) -> None:
    signal = np.asarray(signal, dtype=np.float64)
    if signal.ndim == 2:
        signal = signal.mean(axis=1)
    peak = float(np.max(np.abs(signal))) if signal.size else 0.0
    if peak > 0.98:
        signal = signal * (0.98 / peak)
    pcm = np.round(np.clip(signal, -1.0, 1.0) * 32767).astype('<i2')
    with wave.open(str(OUT / name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())

def env_attack_release(t, attack=0.025, release=0.20, duration=None):
    e = np.minimum(1.0, t / max(0.001, attack))
    if duration is not None:
        e *= np.clip((duration - t) / max(0.001, release), 0.0, 1.0)
    return e

# 42-second original dark survival loop. Synthesized from tones and filtered noise;
# no samples, recordings, or copyrighted melodies are used.
dur = 42.0
n = int(SR * dur)
t = np.arange(n, dtype=np.float64) / SR
music = np.zeros(n, dtype=np.float64)
# Dark, stable drone bed in a minor tonal palette.
for freq, amp, phase in [(41.203, 0.075, .3), (55.0, 0.055, 1.1), (82.407, 0.028, 2.2), (110.0, 0.015, 0.5), (164.814, 0.009, 1.7)]:
    music += amp * np.sin(2*np.pi*freq*t + phase)
# Slowly moving tension pad / filtered, deterministic rumble.
mod = 0.62 + 0.38 * np.sin(2*np.pi*t/10.5 + .6)
for freq, amp in [(73.416, 0.018), (146.832, 0.011), (220.0, 0.006)]:
    music += amp * mod * np.sin(2*np.pi*freq*t + 1.3)
# A restrained heartbeat-like low percussion on a 1.4 sec pulse.
for onset in np.arange(0.35, dur - 0.25, 1.4):
    i0 = int(onset * SR)
    length = min(int(0.36*SR), n-i0)
    tt = np.arange(length)/SR
    pitch = 58.0 - 20.0 * (tt/0.36)
    ph = 2*np.pi*np.cumsum(pitch)/SR
    hit = np.sin(ph) * np.exp(-tt*13.0) * 0.12
    # click + soft noise edge
    click = rng.normal(0.0, 1.0, length) * np.exp(-tt*55.0) * 0.009
    music[i0:i0+length] += hit + click
# Sparse, high, eerie three-note motif every 10.5 sec, damped to stay behind combat.
scale = [146.832, 174.614, 220.0, 196.0, 164.814]
for cycle in range(4):
    base = cycle * 10.5
    for j, (offset, note) in enumerate([(0.9,0),(2.75,2),(5.1,1),(7.7,3),(9.1,4)]):
        onset = base + offset
        if onset >= dur - 1.0:
            continue
        i0 = int(onset*SR)
        length = min(int(1.55*SR), n-i0)
        tt = np.arange(length)/SR
        e = np.clip(tt/0.035, 0, 1) * np.clip((1.55-tt)/0.48, 0, 1)
        note_hz = scale[note]
        music[i0:i0+length] += (0.025*np.sin(2*np.pi*note_hz*tt) + 0.008*np.sin(2*np.pi*note_hz*2.01*tt+0.3)) * e
# Very low breathing wind layer created from slowly moving oscillators (not random static).
wind = (np.sin(2*np.pi*0.17*t + .4) * np.sin(2*np.pi*29.1*t) + 0.4*np.sin(2*np.pi*0.09*t+1.0)*np.sin(2*np.pi*43.7*t)) * 0.013
music += wind
# Soften the seam; both ends are deliberately quiet to avoid a click on looping.
f = int(0.45*SR)
ramp = np.linspace(0.0, 1.0, f, endpoint=True)
music[:f] *= ramp
music[-f:] *= ramp[::-1]
# Maintain safe background levels.
write_wav('combat_ambience_loop.wav', music * 0.72)

# Boss roar: descending, rough, layered growl with vocal-like formant bands.
dur = 2.35
n = int(SR*dur)
t = np.arange(n)/SR
rng = np.random.default_rng(90210)
f0 = 112.0 - 54.0*(t/dur) + 6.5*np.sin(2*np.pi*3.2*t)
phase = 2*np.pi*np.cumsum(f0)/SR
rough = np.sin(phase) + 0.43*np.sin(2*phase+0.25) + 0.23*np.sin(3.03*phase+0.6) + 0.1*np.sin(4.1*phase)
noise = rng.normal(0,1,n)
# A simple noise resonator creates a breathy rasp without recorded samples.
filtered = np.zeros(n)
for i in range(2, n):
    filtered[i] = 0.72*filtered[i-1] - 0.12*filtered[i-2] + 0.18*noise[i]
e = np.clip(t/0.09,0,1) * np.clip((dur-t)/0.34,0,1)
pulse = 0.75 + 0.25*np.sin(2*np.pi*4.1*t)
roar = (rough*0.48 + filtered*0.22) * e * pulse
# Tail rumble and a short, crunchy onset.
roar += 0.10*np.sin(2*np.pi*(44-12*t)*t) * np.exp(-t*2.6)
write_wav('boss_roar.wav', roar*0.74)

# Boss attack impact: short whoosh into a heavy, gritty slam.
dur = 0.92
n = int(SR*dur)
t = np.arange(n)/SR
rng = np.random.default_rng(427)
noise = rng.normal(0,1,n)
impact = np.zeros(n)
# Pre-impact rising rush.
rush = np.clip(t/0.24,0,1) * np.clip((0.31-t)/0.12,0,1)
impact += 0.11*noise*rush
# Deep body impact, downward pitch bend and gritty tail.
body = np.sin(2*np.pi*np.cumsum(78-44*t)/SR)
impact += body * np.exp(-np.maximum(0,t-0.23)*6.8) * (t>=0.23) * 0.55
impact += noise * np.exp(-np.maximum(0,t-0.23)*10.5) * (t>=0.23) * 0.19
impact += 0.13*np.sin(2*np.pi*39*t)*np.exp(-t*4.1)
write_wav('boss_attack.wav', impact*0.78)

# Incoming airdrop: descending air whistle, canopy-like whoosh, then radio-like two pips.
dur = 1.75
n = int(SR*dur)
t = np.arange(n)/SR
rng = np.random.default_rng(132)
noise = rng.normal(0,1,n)
# Broad noise shaped into a rushing layer by smoothing with a short moving average.
kernel = np.ones(180)/180
wind_noise = np.convolve(noise, kernel, mode='same')
wind_noise /= max(1e-5, np.max(np.abs(wind_noise)))
e = np.clip(t/0.11,0,1) * np.clip((dur-t)/0.28,0,1)
whistle_freq = 840.0 - 460.0*(t/dur)
whistle_phase = 2*np.pi*np.cumsum(whistle_freq)/SR
incoming = 0.27*wind_noise*e + 0.06*np.sin(whistle_phase)*e
for onset, hz in [(0.76, 880.0), (1.02, 660.0)]:
    i0 = int(onset*SR)
    length = min(int(0.12*SR), n-i0)
    tt = np.arange(length)/SR
    incoming[i0:i0+length] += 0.12*np.sin(2*np.pi*hz*tt)*np.exp(-tt*20.0)
write_wav('airdrop_incoming.wav', incoming*0.68)

print('Generated:', ', '.join(p.name for p in sorted(OUT.glob('*.wav')) if p.name in {'combat_ambience_loop.wav','boss_roar.wav','boss_attack.wav','airdrop_incoming.wav'}))
