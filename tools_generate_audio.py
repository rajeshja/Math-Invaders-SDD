"""
Generates every audio asset for Phase 10 (FR9.5/FR9.6/FR9.8) as 16-bit
mono 22050 Hz WAV files, using only the Python standard library:

  assets/audio/sfx/*.wav        - fire, hit, miss, enemy_fire, player_hit,
                                  wave_complete, level_complete, game_over,
                                  tick, chime, click, hover, unlock, paper,
                                  scroll_tick
  assets/audio/music/*.wav      - gameplay_music (seamless loop)

Run:  python tools_generate_audio.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
SFX_DIR = os.path.join("assets", "audio", "sfx")
MUSIC_DIR = os.path.join("assets", "audio", "music")


def write_wav(path, samples):
    data = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print(f"wrote {path} ({len(samples) / SR:.2f}s)")


def silence(dur):
    return [0.0] * int(dur * SR)


def mix_into(base, add, at_seconds):
    start = int(at_seconds * SR)
    for i, v in enumerate(add):
        j = start + i
        if 0 <= j < len(base):
            base[j] += v


def env_exp(i, n, k):
    """Exponential decay envelope, sample-indexed."""
    return math.exp(-k * i / n)


def sine(t, f):
    return math.sin(2.0 * math.pi * f * t)


def saw(t, f):
    return 2.0 * ((t * f) % 1.0) - 1.0


def square(t, f):
    return 1.0 if (t * f) % 1.0 < 0.5 else -1.0


def tri(t, f):
    p = (t * f) % 1.0
    return 4.0 * p - 1.0 if p < 0.5 else 3.0 - 4.0 * p


def sweep_tone(dur, f0, f1, wave_fn=sine, decay=18.0, curve=1.0):
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        frac = (i / n) ** curve
        f = f0 * (f1 / f0) ** frac if f0 > 0 and f1 > 0 else f0 + (f1 - f0) * frac
        phase += 2.0 * math.pi * f / SR
        out.append(math.sin(phase) * env_exp(i, n, decay))
    return out


def tone(dur, f, wave_fn=sine, decay=8.0, attack=0.004, vib_hz=0.0, vib_amt=0.0):
    n = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f_inst = f * (1.0 + vib_amt * math.sin(2 * math.pi * vib_hz * t)) if vib_hz else f
        phase += 2.0 * math.pi * f_inst / SR
        a = min(1.0, i / max(1, int(attack * SR)))
        out.append(wave_fn(0, f) * 0 + math.sin(phase) * a * env_exp(i, n, decay))
        # wave_fn kept for interface symmetry; phase-accumulated sine is cleaner
    return out


def tone_wave(dur, f, wave_fn, decay=8.0, attack=0.004):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        a = min(1.0, i / max(1, int(attack * SR)))
        out.append(wave_fn(t, f) * a * env_exp(i, n, decay))
    return out


def noise_burst(dur, decay=14.0, lowpass=0.25, seed=5):
    rnd = random.Random(seed)
    n = int(dur * SR)
    out = []
    prev = 0.0
    for i in range(n):
        white = rnd.uniform(-1, 1)
        prev = prev + lowpass * (white - prev)  # one-pole low-pass
        out.append(prev * env_exp(i, n, decay))
    return out


def normalize(samples, peak):
    m = max(1e-9, max(abs(s) for s in samples))
    g = peak / m
    return [s * g for s in samples]


def bell_note(dur, f, decay=6.0, shimmer=1.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        e = env_exp(i, n, decay)
        v = (math.sin(2 * math.pi * f * t)
             + 0.5 * math.sin(2 * math.pi * f * 2.0 * t)
             + shimmer * 0.25 * math.sin(2 * math.pi * f * 2.98 * t))
        out.append(v * e)
    return out


# ------------------------------------------------------------------- effects

def sfx_fire():
    body = sweep_tone(0.16, 950, 240, decay=26, curve=1.4)
    sparkle = [0.22 * s for s in sweep_tone(0.10, 2400, 900, decay=40)]
    out = silence(0.18)
    mix_into(out, body, 0.0)
    mix_into(out, sparkle, 0.0)
    return normalize(out, 0.72)


def sfx_hit():
    out = silence(0.38)
    mix_into(out, noise_burst(0.30, decay=16, lowpass=0.32), 0.0)
    mix_into(out, sweep_tone(0.26, 170, 52, decay=13, curve=0.8), 0.0)
    return normalize(out, 0.8)


def sfx_miss():
    n = int(0.30 * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = 300.0 * (120.0 / 300.0) ** (i / n)
        v = square(t, f) * 0.6 + sine(t, f) * 0.4
        out.append(v * env_exp(i, n, 11))
    return normalize(out, 0.6)


def sfx_enemy_fire():
    out = sweep_tone(0.18, 520, 160, decay=20, curve=1.2)
    return normalize(out, 0.6)


def sfx_player_hit():
    out = silence(0.42)
    mix_into(out, noise_burst(0.34, decay=13, lowpass=0.22, seed=9), 0.0)
    mix_into(out, sweep_tone(0.30, 130, 44, decay=10, curve=0.8), 0.0)
    mix_into(out, [0.5 * s for s in sweep_tone(0.2, 90, 40, decay=12)], 0.03)
    return normalize(out, 0.85)


def sfx_wave_complete():
    notes = [523.25, 659.25, 783.99, 1046.5]
    out = silence(0.9)
    for k, f in enumerate(notes):
        mix_into(out, bell_note(0.45, f, decay=9), k * 0.11)
    return normalize(out, 0.62)


def sfx_level_complete():
    seq = [392.0, 523.25, 659.25, 783.99]
    out = silence(1.5)
    for k, f in enumerate(seq):
        mix_into(out, bell_note(0.4, f, decay=10), k * 0.13)
    chord_at = len(seq) * 0.13
    for f in (523.25, 659.25, 783.99, 1046.5):
        mix_into(out, bell_note(0.9, f, decay=5), chord_at)
    return normalize(out, 0.66)


def sfx_game_over():
    seq = [440.0, 349.23, 293.66, 220.0]
    out = silence(1.9)
    for k, f in enumerate(seq):
        mix_into(out, tone(0.5, f, decay=5, attack=0.01, vib_hz=5.5, vib_amt=0.012), k * 0.3)
    mix_into(out, tone(1.0, 110.0, decay=3.2, attack=0.02), 3 * 0.3)
    return normalize(out, 0.6)


def sfx_tick():
    return normalize(sweep_tone(0.05, 1350, 1250, decay=60), 0.42)


def sfx_chime():
    out = silence(1.1)
    mix_into(out, bell_note(0.9, 1318.51, decay=5), 0.0)
    mix_into(out, bell_note(0.9, 1760.0, decay=5), 0.09)
    return normalize(out, 0.5)


def sfx_click():
    out = silence(0.06)
    mix_into(out, noise_burst(0.02, decay=90, lowpass=0.9, seed=3), 0.0)
    mix_into(out, tone_wave(0.035, 1800, sine, decay=70), 0.004)
    return normalize(out, 0.5)


def sfx_hover():
    return normalize(tone_wave(0.035, 1500, sine, decay=60, attack=0.004), 0.28)


def sfx_unlock():
    notes = [880.0, 1174.66, 1567.98, 2093.0]
    out = silence(1.0)
    for k, f in enumerate(notes):
        mix_into(out, bell_note(0.4, f, decay=11), k * 0.07)
    mix_into(out, tone(0.7, 2637.0, decay=6, vib_hz=7, vib_amt=0.01), 0.28)
    return normalize(out, 0.55)


def sfx_paper():
    rnd = random.Random(13)
    n = int(0.28 * SR)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / n
        white = rnd.uniform(-1, 1)
        prev += 0.55 * (white - prev)
        swell = math.sin(math.pi * min(1.0, t * 1.15)) ** 1.5
        flutter = 0.75 + 0.25 * math.sin(2 * math.pi * (30 + 60 * t) * i / SR)
        out.append(prev * swell * flutter * 0.8)
    return normalize(out, 0.4)


def sfx_scroll_tick():
    return normalize(tone_wave(0.022, 850, sine, decay=90), 0.2)


# -------------------------------------------------------------------- music

def sfx_music_loop():
    """8 bars @ 112 BPM in A minor (Am F C G x2). Seamless by construction:
    every note's release finishes inside the loop and the total sample
    count is an exact multiple of the beat length."""
    bpm = 112.0
    beat = 60.0 / bpm
    total = int(round(8 * 4 * beat * SR))  # exactly 378000 samples
    out = [0.0] * total

    def add(start_beat, dur, f, amp, wave_fn=sine, decay=4.0, attack=0.01):
        n = int(dur * SR)
        start = int(start_beat * beat * SR)
        for i in range(n):
            j = start + i
            if j >= total:
                break
            t = i / SR
            a = min(1.0, i / max(1, int(attack * SR)))
            out[j] += wave_fn(t, f) * a * env_exp(i, n, decay) * amp

    roots = [110.0, 87.31, 130.81, 98.0]          # A2 F2 C3 G2
    chords = [
        [220.0, 261.63, 329.63],                  # Am
        [174.61, 220.0, 261.63],                  # F
        [196.0, 261.63, 329.63],                  # C (voiced G-C-E)
        [196.0, 246.94, 293.66],                  # G
    ]
    # pentatonic melody (A C D E G) as absolute frequencies, per bar, 8 eighths
    A4, C5, D5, E5, G5, A5, C6 = 440.0, 523.25, 587.33, 659.25, 783.99, 880.0, 1046.5
    melody = [
        [A4, 0, C5, E5, 0, D5, C5, A4],
        [C5, 0, A4, C5, D5, 0, C5, 0],
        [E5, 0, D5, C5, 0, G5, E5, D5],
        [D5, 0, E5, D5, C5, 0, A4, 0],
        [A4, 0, C5, E5, 0, A5, G5, E5],
        [G5, 0, E5, D5, C5, 0, D5, 0],
        [E5, G5, A5, 0, G5, E5, D5, C5],
        [D5, 0, C5, A4, 0, A4, 0, 0],
    ]

    rnd = random.Random(42)
    for bar in range(8):
        b0 = bar * 4
        chord = chords[bar % 4]
        root = roots[bar % 4]
        # bass: root-fifth on eighths 0..3 and 4..7 (root only)
        add(b0 + 0.0, beat * 0.9, root, 0.30, square, decay=3.0)
        add(b0 + 1.0, beat * 0.9, root * 1.5, 0.20, square, decay=4.0)
        add(b0 + 2.0, beat * 0.9, root, 0.26, square, decay=3.0)
        add(b0 + 3.0, beat * 0.45, root * 1.5, 0.16, square, decay=5.0)
        add(b0 + 3.5, beat * 0.45, root * 2.0, 0.12, square, decay=6.0)
        # pad: soft chord tones, one per bar
        for f in chord:
            add(b0 + 0.0, beat * 3.6, f, 0.055, sine, decay=0.55, attack=0.25)
        # melody
        for e, deg in enumerate(melody[bar]):
            if deg:
                add(b0 + e * 0.5, beat * 0.52, deg, 0.16, tri, decay=3.2, attack=0.008)
        # drums: kick on 1 & 3, hats on off-eighths
        for kb in (b0, b0 + 2.0):
            add(kb, 0.16, 58.0, 0.5, sine, decay=16.0, attack=0.001)
        for hb in (b0 + 0.5, b0 + 1.5, b0 + 2.5, b0 + 3.5):
            n = int(0.035 * SR)
            start = int(hb * beat * SR)
            for i in range(n):
                j = start + i
                if j < total:
                    out[j] += rnd.uniform(-1, 1) * env_exp(i, n, 55.0) * 0.045

    return normalize(out, 0.58)


if __name__ == "__main__":
    write_wav(os.path.join(SFX_DIR, "fire.wav"), sfx_fire())
    write_wav(os.path.join(SFX_DIR, "hit.wav"), sfx_hit())
    write_wav(os.path.join(SFX_DIR, "miss.wav"), sfx_miss())
    write_wav(os.path.join(SFX_DIR, "enemy_fire.wav"), sfx_enemy_fire())
    write_wav(os.path.join(SFX_DIR, "player_hit.wav"), sfx_player_hit())
    write_wav(os.path.join(SFX_DIR, "wave_complete.wav"), sfx_wave_complete())
    write_wav(os.path.join(SFX_DIR, "level_complete.wav"), sfx_level_complete())
    write_wav(os.path.join(SFX_DIR, "game_over.wav"), sfx_game_over())
    write_wav(os.path.join(SFX_DIR, "tick.wav"), sfx_tick())
    write_wav(os.path.join(SFX_DIR, "chime.wav"), sfx_chime())
    write_wav(os.path.join(SFX_DIR, "click.wav"), sfx_click())
    write_wav(os.path.join(SFX_DIR, "hover.wav"), sfx_hover())
    write_wav(os.path.join(SFX_DIR, "unlock.wav"), sfx_unlock())
    write_wav(os.path.join(SFX_DIR, "paper.wav"), sfx_paper())
    write_wav(os.path.join(SFX_DIR, "scroll_tick.wav"), sfx_scroll_tick())
    write_wav(os.path.join(MUSIC_DIR, "gameplay_music.wav"), sfx_music_loop())
