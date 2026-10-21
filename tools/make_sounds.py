#!/usr/bin/env python3
"""Synthesize the Plasticc sound kit from scratch (no samples, no downloads).

Makes every UI sound for the disposable-camera app (shutter, wind/crank
ratchets, flash whine, shrink-wrap crinkles, prints, lab bell...) as mono
44.1 kHz 16-bit WAV in a temp dir, prints a sanity check for each (peak dBFS,
duration, boundary samples, DC), then converts each to CAF in App/Sounds/.

Run from anywhere:  python3 tools/make_sounds.py
Needs numpy and /usr/bin/afconvert. Every sound uses its own fixed seed, so
re-running reproduces the same files.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "App", "Sounds")
# Long files use IMA4 to stay small; everything else is plain 16-bit PCM.
IMA4 = {"flash_charge", "lab_bell"}


# ---------------------------------------------------------------- helpers

def n_of(sec):
    return int(round(sec * SR))


def time_axis(sec):
    return np.arange(n_of(sec)) / SR


def bandpass(x, lo=None, hi=None, order=2):
    """Zero-phase Butterworth-shaped band filter in the FFT domain (zero padded)."""
    n = len(x)
    size = 1 << int(np.ceil(np.log2(2 * n + 1)))
    spec = np.fft.rfft(x, size)
    f = np.fft.rfftfreq(size, 1 / SR)
    f[0] = 1e-6
    gain = np.ones_like(f)
    if lo:
        gain /= np.sqrt(1 + (lo / f) ** (2 * order))
    if hi:
        gain /= np.sqrt(1 + (f / hi) ** (2 * order))
    return np.fft.irfft(spec * gain, size)[:n]


def sweep_lowpass(x, fc_start, fc_end):
    """One-pole low-pass whose cutoff glides exponentially from fc_start to fc_end."""
    fc = fc_start * (fc_end / fc_start) ** np.linspace(0, 1, len(x))
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def exp_decay(sec, tau):
    return np.exp(-time_axis(sec) / tau)


def hump(sec, attack_frac=0.3, power=2.0):
    """Asymmetric smooth swell: rises over attack_frac of the length, then falls."""
    t = np.linspace(0, 1, n_of(sec))
    up = np.clip(t / attack_frac, 0, 1)
    down = np.clip((1 - t) / (1 - attack_frac), 0, 1)
    return (np.sin(np.pi / 2 * np.minimum(up, down)) ** power)


def noise_burst(rng, sec, lo, hi, tau):
    """Band-limited noise with an exponential decay (filtered first so the attack stays sharp)."""
    pad = n_of(0.01)
    noise = bandpass(rng.standard_normal(n_of(sec) + pad), lo, hi)[pad:]
    noise /= np.max(np.abs(noise)) + 1e-12
    return noise * exp_decay(sec, tau)


def click(rng, sec, lo, hi, tau, body_hz=None, body_amt=0.0, body_tau=0.004):
    """A transient: noise snap plus an optional little resonant body."""
    out = noise_burst(rng, sec, lo, hi, tau)
    if body_hz:
        out = out + body_amt * resonant_body(sec, [(body_hz, 1.0, body_tau)])
    return out


def resonant_body(sec, partials):
    """Sum of damped sines: partials = [(freq_hz, amp, tau_s), ...]."""
    t = time_axis(sec)
    out = np.zeros_like(t)
    for freq, amp, tau in partials:
        out += amp * np.sin(2 * np.pi * freq * t) * np.exp(-t / tau)
    return out


def sweep(sec, f_of_t, amp=1.0):
    """Sine whose instantaneous frequency is the array f_of_t (Hz)."""
    phase = 2 * np.pi * np.cumsum(f_of_t) / SR
    return amp * np.sin(phase)


def place(buf, x, at_sec, gain=1.0):
    """Mix x into buf starting at at_sec (truncated at the end of buf)."""
    i = n_of(at_sec)
    m = min(len(x), len(buf) - i)
    if m > 0:
        buf[i:i + m] += gain * x[:m]
    return buf


def fade(x, fade_in=0.003, fade_out=0.010):
    x = x.copy()
    a, b = n_of(fade_in), n_of(fade_out)
    if a:
        x[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    if b:
        x[-b:] *= np.cos(np.linspace(0, np.pi / 2, b)) ** 2
    x[0] = 0.0
    x[-1] = 0.0
    return x


def finish(x, peak_db, fade_in=0.003, fade_out=0.010):
    """Remove DC/rumble, apply fades, normalize to peak_db dBFS."""
    x = bandpass(x - np.mean(x), lo=25, order=2)
    x = fade(x, fade_in, fade_out)
    window = np.hanning(len(x))  # zero at both ends, so removing DC keeps the edges at 0
    x -= window * (np.sum(x) / np.sum(window))
    return x * (10 ** (peak_db / 20) / np.max(np.abs(x)))


def crackle_events(rng, buf, start, end, rate_fn, lo=2000, hi=9000, cluster=0.35, gain=1.0):
    """Sprinkle tiny plastic clicks between start/end seconds.

    rate_fn(u) gives events per second at normalized position u in [0, 1].
    Some events spawn a quick cluster of follow-ups (the 'crk-k-k' of wrap).
    """
    t = start
    while t < end:
        u = (t - start) / (end - start)
        rate = max(rate_fn(u), 1.0)
        t += rng.exponential(1.0 / rate)
        if t >= end:
            break
        amp = gain * rng.pareto(2.5) * 0.4 + 0.08
        amp = min(amp, 1.0)
        n_follow = rng.poisson(2.0) if rng.random() < cluster else 0
        tt = t
        for k in range(n_follow + 1):
            dur = rng.uniform(0.0015, 0.006)
            band_lo = lo * rng.uniform(0.8, 1.3)
            band_hi = hi * rng.uniform(0.7, 1.0)
            c = noise_burst(rng, dur, band_lo, band_hi, rng.uniform(0.0003, 0.0012))
            place(buf, c, tt, amp * (0.6 ** k) * rng.choice([-1, 1]))
            tt += rng.uniform(0.0008, 0.004)
    return buf


# ---------------------------------------------------------------- sounds

def shutter():
    rng = np.random.default_rng(101)
    buf = np.zeros(n_of(0.150))
    t0, t1 = 0.004, 0.004 + 0.037
    # Opening snap: bright spring + plastic leaf.
    snap = noise_burst(rng, 0.020, 2500, 7000, 0.0016)
    spring = resonant_body(0.030, [(3150, 0.35, 0.004), (4720, 0.30, 0.003), (6180, 0.20, 0.002)])
    knock = resonant_body(0.090, [(330, 0.40, 0.011), (395, 0.18, 0.008), (760, 0.15, 0.005)])
    place(buf, snap, t0)
    place(buf, spring, t0)
    place(buf, knock, t0 + 0.0008)
    # Return snap: a touch softer and slightly lower.
    snap2 = noise_burst(rng, 0.018, 2300, 6500, 0.0013)
    spring2 = resonant_body(0.025, [(2980, 0.30, 0.0035), (4510, 0.22, 0.0025)])
    knock2 = resonant_body(0.060, [(300, 0.40, 0.009), (720, 0.12, 0.004)])
    place(buf, snap2, t1, 0.85)
    place(buf, spring2, t1, 0.85)
    place(buf, knock2, t1 + 0.0006, 0.6)
    # Tiny trailing rattle of the cheap housing.
    place(buf, noise_burst(rng, 0.008, 3000, 8000, 0.0006), t1 + 0.011, 0.12)
    return finish(buf, -3, 0.002, 0.030)


def wind_tick(seed, pitch, bright, length):
    """One notch of the thumbwheel: the pawl scrapes up the ratchet tooth, then drops with a hollow 'tk'."""
    rng = np.random.default_rng(seed)
    buf = np.zeros(n_of(length))
    # Pawl dragging up the tooth: a soft, short plastic scrape.
    scrape = noise_burst(rng, 0.007, 1500 * pitch, 6000 * pitch, 0.004) * np.linspace(0.3, 1.0, n_of(0.007))
    place(buf, scrape, 0.001, 0.22)
    # The drop: a sharp tick into the hollow body of the camera.
    drop = 0.008
    place(buf, noise_burst(rng, 0.006, 2600 * pitch, 7000 * pitch * bright, 0.0007), drop, 0.9)
    place(buf, resonant_body(length - drop, [(1350 * pitch, 0.55, 0.0035), (2900 * pitch, 0.25, 0.0018),
                                             (460 * pitch, 0.35, 0.006)]), drop)
    return finish(buf, -8, 0.001, 0.008)


def wind_stop():
    """The wheel locks on the next frame: a firm clack, and the shutter spring cocking a beat after."""
    rng = np.random.default_rng(201)
    buf = np.zeros(n_of(0.110))
    # Pawl slams into the stop.
    place(buf, noise_burst(rng, 0.010, 1500, 6000, 0.0011), 0.002, 0.8)
    place(buf, resonant_body(0.080, [(560, 0.9, 0.013), (880, 0.5, 0.008), (190, 0.35, 0.012), (1500, 0.25, 0.004)]), 0.002)
    # Shutter cocks: small bright metal 'tink' with a short ring.
    place(buf, noise_burst(rng, 0.004, 4000, 9500, 0.0005), 0.026, 0.45)
    place(buf, resonant_body(0.060, [(4300, 0.30, 0.009), (6100, 0.18, 0.006)]), 0.026)
    # A last settle of the cheap housing.
    place(buf, resonant_body(0.030, [(640, 0.2, 0.006)]), 0.048)
    return finish(buf, -4, 0.001, 0.025)


def crank_tick(seed, pitch, length):
    rng = np.random.default_rng(seed)
    buf = np.zeros(n_of(length))
    place(buf, noise_burst(rng, length, 3000 * pitch, 7000 * pitch, 0.0009), 0.0025)
    place(buf, resonant_body(length, [(1650 * pitch, 0.25, 0.002)]), 0.0025)
    return finish(buf, -10, 0.002, 0.004)


def crank_release():
    rng = np.random.default_rng(301)
    length = 0.200
    buf = np.zeros(n_of(length))
    zz = 0.150
    # Friction bed: noise whose brightness falls as the leader slips.
    bed = bandpass(rng.standard_normal(n_of(zz)), 400, 9000)
    bed = sweep_lowpass(bed, 7000, 900) * hump(zz, 0.12, 1.0)
    place(buf, bed, 0.003, 0.5)
    # The "rrr": stick-slip pulses slowing from ~170 to ~60 per second.
    t = 0.005
    while t < zz:
        u = t / zz
        rate = 170 * (60 / 170) ** u
        hi = 8000 * (1800 / 8000) ** u
        c = noise_burst(rng, 0.004, 600, hi, 0.0007)
        place(buf, c, t, (1 - 0.6 * u) * rng.uniform(0.6, 1.0))
        t += (1 / rate) * rng.uniform(0.85, 1.15)
    # Soft hollow tap as the leader flaps against the spool.
    tap = resonant_body(0.045, [(610, 0.5, 0.009), (1340, 0.2, 0.005)])
    tap += 0.15 * noise_burst(rng, 0.045, 500, 3000, 0.002)
    place(buf, tap, zz + 0.006, 0.55)
    return finish(buf, -6, 0.004, 0.012)


def flash_charge():
    rng = np.random.default_rng(401)
    total, rise = 2.4, 2.2
    t = time_axis(total)
    # Capacitor-charge curve: climbs fast, then eases toward the top.
    k = 1.6
    u = np.clip(t / rise, 0, 1)
    curve = (1 - np.exp(-k * u)) / (1 - np.exp(-k))
    f = 1500 + (8700 - 1500) * curve
    # Faint flutter in pitch and level.
    drift = np.cumsum(rng.standard_normal(len(t)))
    drift = bandpass(drift - drift.mean(), hi=8)
    drift /= np.max(np.abs(drift)) + 1e-12
    f = f * (1 + 0.004 * drift)
    flutter = 1 + 0.06 * np.sin(2 * np.pi * 13 * t) + 0.04 * drift
    tone = sweep(total, f)
    tone += 0.03 * sweep(total, 2 * f) * (2 * f < 20000)
    tone += 0.012 * sweep(total, 3 * f) * (3 * f < 20000)
    # Slight swell in level as it climbs, gentle fade in.
    level = 0.75 + 0.25 * curve
    return finish(tone * flutter * level, -14, 0.120, 0.060)


def flash_ready():
    rng = np.random.default_rng(451)
    buf = np.zeros(n_of(0.030))
    place(buf, noise_burst(rng, 0.010, 6000, 11000, 0.0005), 0.003, 0.6)
    place(buf, resonant_body(0.025, [(4200, 1.0, 0.0035), (6900, 0.25, 0.002)]), 0.003)
    return finish(buf, -16, 0.002, 0.008)


def crinkle(seed, length):
    rng = np.random.default_rng(seed)
    buf = np.zeros(n_of(length))
    # Rate wobbles over the gesture so each file has its own shape.
    peak_at = rng.uniform(0.2, 0.8)
    base = rng.uniform(90, 180)
    rate = lambda u: base * (0.35 + np.exp(-((u - peak_at) / 0.3) ** 2))
    crackle_events(rng, buf, 0.004, length - 0.012, rate, cluster=rng.uniform(0.25, 0.5))
    return finish(buf, -8, 0.003, 0.010)


def tear():
    rng = np.random.default_rng(601)
    length = 0.450
    buf = np.zeros(n_of(length))
    rate = lambda u: 900 * np.sin(np.pi * min(u / 0.35, 1) / 2) ** 2 * (1 - u) ** 1.6 + 40
    crackle_events(rng, buf, 0.004, length - 0.02, rate, cluster=0.45)
    whoosh = bandpass(rng.standard_normal(n_of(0.40)), 700, 4500)
    whoosh = whoosh / np.max(np.abs(whoosh)) * hump(0.40, 0.3, 2.0)
    place(buf, whoosh, 0.010, 0.18)
    return finish(buf, -5, 0.003, 0.040)


def canister_clunk():
    rng = np.random.default_rng(701)
    length = 0.150
    buf = np.zeros(n_of(length))
    t = time_axis(0.120)
    thud_f = 175 * (125 / 175) ** np.clip(t / 0.05, 0, 1)
    thud = sweep(0.120, thud_f) * np.exp(-t / 0.018)
    thud += 0.4 * bandpass(rng.standard_normal(len(t)), 60, 500) / 3 * np.exp(-t / 0.006)
    place(buf, thud, 0.003)
    knock = resonant_body(0.080, [(480, 0.45, 0.012), (1120, 0.25, 0.007), (1730, 0.1, 0.004)])
    knock += 0.2 * noise_burst(rng, 0.080, 800, 3500, 0.0015)
    place(buf, knock, 0.0035)
    tick = resonant_body(0.030, [(5300, 0.5, 0.005), (7900, 0.35, 0.004), (9650, 0.2, 0.003)])
    place(buf, tick, 0.006, 0.12)
    return finish(buf, -3, 0.002, 0.030)


def door_snap():
    rng = np.random.default_rng(801)
    length = 0.085
    buf = np.zeros(n_of(length))
    place(buf, noise_burst(rng, 0.015, 2000, 8000, 0.0010), 0.003)
    place(buf, resonant_body(0.050, [(910, 0.6, 0.006), (1420, 0.35, 0.004), (420, 0.3, 0.008)]), 0.003)
    for at, g in ((0.014, 0.35), (0.021, 0.22), (0.029, 0.15), (0.038, 0.08)):
        place(buf, click(rng, 0.008, 1800, 6000, 0.0007, 1250 * rng.uniform(0.9, 1.1), 0.5, 0.002), at, g)
    return finish(buf, -4, 0.002, 0.020)


def paper_swoosh(rng, sec, lo, hi, attack, fc_start, fc_end, grain=0.4):
    """Filtered-noise paper movement with a grainy, uneven envelope."""
    x = bandpass(rng.standard_normal(n_of(sec)), lo, hi)
    x = sweep_lowpass(x, fc_start, fc_end)
    x /= np.max(np.abs(x)) + 1e-12
    wobble = bandpass(rng.standard_normal(len(x)), hi=120)
    wobble /= np.max(np.abs(wobble)) + 1e-12
    return x * hump(sec, attack, 1.5) * (1 + grain * wobble)


def print_slide():
    rng = np.random.default_rng(901)
    length = 0.230
    buf = np.zeros(n_of(length))
    place(buf, paper_swoosh(rng, 0.215, 1000, 6000, 0.25, 9000, 2500), 0.004)
    return finish(buf, -10, 0.004, 0.020)


def keep():
    rng = np.random.default_rng(1001)
    length = 0.120
    buf = np.zeros(n_of(length))
    tap = noise_burst(rng, 0.030, 250, 2200, 0.0035) + resonant_body(0.030, [(210, 0.6, 0.006)])
    place(buf, tap, 0.003)
    place(buf, paper_swoosh(rng, 0.075, 1500, 5000, 0.2, 6000, 2000), 0.020, 0.35)
    return finish(buf, -10, 0.002, 0.020)


def toss():
    rng = np.random.default_rng(1101)
    length = 0.150
    buf = np.zeros(n_of(length))
    place(buf, paper_swoosh(rng, 0.090, 2000, 9000, 0.15, 12000, 4000, 0.3), 0.003)
    crackle_events(rng, buf, 0.075, 0.125, lambda u: 260 * (1 - u) + 20, lo=1500, hi=7000, gain=0.45)
    return finish(buf, -10, 0.003, 0.020)


def envelope():
    rng = np.random.default_rng(1201)
    length = 0.400
    buf = np.zeros(n_of(length))
    # Overlapping rustle grains: the flap lifting and the paper flexing.
    t = 0.004
    while t < length - 0.07:
        dur = rng.uniform(0.02, 0.07)
        g = paper_swoosh(rng, dur, 500, 6000, rng.uniform(0.2, 0.6), rng.uniform(4000, 8000), rng.uniform(1500, 3000))
        place(buf, g, t, rng.uniform(0.3, 1.0) * np.sin(np.pi * (t / length)) ** 0.5)
        t += rng.uniform(0.012, 0.035)
    crackle_events(rng, buf, 0.03, length - 0.06, lambda u: 50, lo=1500, hi=6000, cluster=0.2, gain=0.5)
    return finish(buf, -9, 0.004, 0.040)


def lab_bell():
    rng = np.random.default_rng(1301)
    length = 1.300
    f0 = 1800
    partials = [
        (f0, 1.00, 0.36), (f0 * 1.0011, 0.45, 0.33),  # slow beat for warmth
        (f0 * 2.76, 0.40, 0.18), (f0 * 2.763, 0.15, 0.16),
        (f0 * 5.40, 0.16, 0.07), (f0 * 8.93, 0.06, 0.03),
        (f0 * 0.5, 0.10, 0.25),  # soft hum tone underneath
    ]
    buf = np.zeros(n_of(length))
    place(buf, resonant_body(length - 0.003, partials), 0.003)
    place(buf, noise_burst(rng, 0.006, 3000, 10000, 0.0005), 0.003, 0.15)
    return finish(buf, -8, 0.002, 0.120)


def build():
    sounds = {"shutter": shutter()}
    for i, (seed, pitch, bright, length) in enumerate(
            [(111, 1.00, 1.00, 0.030), (112, 1.04, 1.10, 0.026), (113, 0.96, 0.92, 0.034)], 1):
        sounds[f"wind_tick_{i}"] = wind_tick(seed, pitch, bright, length)
    sounds["wind_stop"] = wind_stop()
    for i, (seed, pitch, length) in enumerate([(211, 1.00, 0.014), (212, 1.04, 0.011), (213, 0.96, 0.017)], 1):
        sounds[f"crank_tick_{i}"] = crank_tick(seed, pitch, length)
    sounds["crank_release"] = crank_release()
    sounds["flash_charge"] = flash_charge()
    sounds["flash_ready"] = flash_ready()
    for i, length in enumerate([0.09, 0.14, 0.21, 0.12, 0.18, 0.10], 1):
        sounds[f"crinkle_{i}"] = crinkle(500 + i, length)
    sounds["tear"] = tear()
    sounds["canister_clunk"] = canister_clunk()
    sounds["door_snap"] = door_snap()
    sounds["print_slide"] = print_slide()
    sounds["keep"] = keep()
    sounds["toss"] = toss()
    sounds["envelope"] = envelope()
    sounds["lab_bell"] = lab_bell()
    return sounds


def write_wav(path, x):
    pcm = np.clip(np.round(x * 32767), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    return pcm


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        print(f"{'name':16} {'dur ms':>7} {'peak dBFS':>9} {'first':>6} {'last':>6} {'DC':>9}")
        for name, x in build().items():
            wav = os.path.join(tmp, name + ".wav")
            pcm = write_wav(wav, x)
            peak = 20 * np.log10(np.max(np.abs(pcm)) / 32768)
            assert np.max(np.abs(pcm)) < 32767, f"{name} clips"
            assert abs(int(pcm[0])) <= 2 and abs(int(pcm[-1])) <= 2, f"{name} has a boundary click"
            print(f"{name:16} {len(pcm) / SR * 1000:7.1f} {peak:9.2f} {pcm[0]:6d} {pcm[-1]:6d} {pcm.mean():9.3f}")
            fmt = "ima4" if name in IMA4 else "LEI16@44100"
            subprocess.run(["/usr/bin/afconvert", "-f", "caff", "-d", fmt, wav,
                            os.path.join(OUT_DIR, name + ".caf")], check=True)


if __name__ == "__main__":
    main()
