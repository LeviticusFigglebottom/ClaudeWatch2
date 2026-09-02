"""RINGFALL audio synthesis primitives.

Small, dependency-light DSP toolkit used by recipes.py / gen_audio.py:
oscillators, envelopes, biquad filters, effects, layering, loop tools, WAV/OGG IO and
numeric validation helpers. Everything is deterministic given a seed.

Signals are float64 numpy arrays in [-1, 1]; mono is shape (n,), stereo is (n, 2).
"""
from __future__ import annotations

import math
import os
import struct
import wave
from typing import Callable, Sequence

import numpy as np
from scipy import signal as sps

SR = 44100
TAU = 2.0 * math.pi


# --------------------------------------------------------------------------------------
# basics
# --------------------------------------------------------------------------------------
def rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(int(seed) & 0xFFFFFFFF)


def n_samples(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def t_axis(dur: float) -> np.ndarray:
    return np.arange(n_samples(dur)) / SR


def db(x_db: float) -> float:
    """dB -> linear gain."""
    return 10.0 ** (x_db / 20.0)


def to_db(x: float) -> float:
    return 20.0 * math.log10(max(float(x), 1e-12))


def midi_to_hz(n: float) -> float:
    return 440.0 * 2.0 ** ((n - 69.0) / 12.0)


def silence(dur: float) -> np.ndarray:
    return np.zeros(n_samples(dur))


def is_stereo(sig: np.ndarray) -> bool:
    return sig.ndim == 2


def mono(sig: np.ndarray) -> np.ndarray:
    return sig.mean(axis=1) if sig.ndim == 2 else sig


# --------------------------------------------------------------------------------------
# oscillators. `freq` may be a scalar or a per-sample array (pitch sweeps).
# --------------------------------------------------------------------------------------
def _phase(freq, n: int, phase: float = 0.0) -> np.ndarray:
    if np.isscalar(freq):
        return TAU * float(freq) * np.arange(n) / SR + phase
    f = np.asarray(freq, dtype=float)
    if len(f) != n:
        f = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(f)), f)
    return TAU * np.cumsum(f) / SR + phase


def sine(freq, dur: float, phase: float = 0.0) -> np.ndarray:
    return np.sin(_phase(freq, n_samples(dur), phase))


def saw(freq, dur: float, phase: float = 0.0) -> np.ndarray:
    ph = _phase(freq, n_samples(dur), phase) / TAU
    return 2.0 * (ph - np.floor(ph + 0.5))


def square(freq, dur: float, duty: float = 0.5, phase: float = 0.0) -> np.ndarray:
    ph = _phase(freq, n_samples(dur), phase) / TAU
    return np.where((ph - np.floor(ph)) < duty, 1.0, -1.0)


def tri(freq, dur: float, phase: float = 0.0) -> np.ndarray:
    return 2.0 * np.abs(saw(freq, dur, phase)) - 1.0


def pulse_train(freq, dur: float, width: int = 8) -> np.ndarray:
    """Impulse train (glottal-ish source for vocoder textures)."""
    ph = _phase(freq, n_samples(dur)) / TAU
    frac = ph - np.floor(ph)
    out = np.zeros_like(frac)
    edges = np.where(np.diff(np.floor(ph)) > 0)[0] + 1
    for e in edges:
        out[e:e + width] = np.linspace(1.0, 0.0, width)[: max(0, min(width, len(out) - e))]
    return out


def noise(dur: float, seed: int = 0, color: str = "white") -> np.ndarray:
    r = rng(seed)
    w = r.uniform(-1.0, 1.0, n_samples(dur))
    if color == "white":
        return w
    if color == "pink":
        # Paul Kellet's economy pink filter
        b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]
        a = [1, -2.494956002, 2.017265875, -0.522189400]
        p = sps.lfilter(b, a, w)
        return p / (np.abs(p).max() + 1e-9)
    if color == "brown":
        br = np.cumsum(w) * 0.02
        br = highpass(br, 20.0)
        return br / (np.abs(br).max() + 1e-9)
    raise ValueError(color)


def fm(carrier, ratio: float, index, dur: float, phase: float = 0.0) -> np.ndarray:
    """Simple 2-op FM. `index` may be scalar or per-sample envelope."""
    n = n_samples(dur)
    car = _phase(carrier, n, phase)
    if np.isscalar(carrier):
        modf = float(carrier) * ratio
    else:
        modf = np.asarray(carrier, dtype=float) * ratio
    mod = np.sin(_phase(modf, n))
    idx = index if np.isscalar(index) else np.asarray(index)
    return np.sin(car + idx * mod)


def sweep(f0: float, f1: float, dur: float, curve: str = "exp") -> np.ndarray:
    n = n_samples(dur)
    x = np.linspace(0.0, 1.0, n)
    if curve == "exp":
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


def harmonics(freq: float, dur: float, amps: Sequence[float], detune_cents: float = 0.0) -> np.ndarray:
    out = np.zeros(n_samples(dur))
    for i, a in enumerate(amps):
        if a == 0:
            continue
        f = freq * (i + 1) * 2.0 ** (detune_cents * (i % 2 * 2 - 1) / 1200.0)
        out += a * sine(f, dur)
    return out


# --------------------------------------------------------------------------------------
# envelopes
# --------------------------------------------------------------------------------------
def adsr(dur: float, a: float, d: float, s: float, r: float, curve: float = 1.0) -> np.ndarray:
    n = n_samples(dur)
    na, nd, nr = n_samples(a), n_samples(d), n_samples(r)
    ns = max(0, n - na - nd - nr)
    parts = [
        np.linspace(0.0, 1.0, na, endpoint=False),
        np.linspace(1.0, s, nd, endpoint=False),
        np.full(ns, s),
        np.linspace(s, 0.0, nr),
    ]
    env = np.concatenate(parts)[:n]
    if len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    if curve != 1.0:
        env = env ** curve
    return env


def exp_env(dur: float, tau: float, start: float = 1.0, floor: float = 0.0) -> np.ndarray:
    t = t_axis(dur)
    return floor + (start - floor) * np.exp(-t / max(tau, 1e-5))


def env_points(dur: float, points: Sequence[tuple[float, float]]) -> np.ndarray:
    """Piecewise-linear envelope from (time_seconds, value) points."""
    t = t_axis(dur)
    ts = [p[0] for p in points]
    vs = [p[1] for p in points]
    return np.interp(t, ts, vs)


def apply(sig: np.ndarray, env: np.ndarray) -> np.ndarray:
    n = min(len(sig), len(env))
    out = sig[:n].copy()
    if out.ndim == 2:
        out *= env[:n, None]
    else:
        out *= env[:n]
    return out


# --------------------------------------------------------------------------------------
# filters (RBJ cookbook biquads via scipy.signal.lfilter)
# --------------------------------------------------------------------------------------
def biquad_coeffs(kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0):
    fc = float(np.clip(fc, 10.0, SR * 0.49))
    w0 = TAU * fc / SR
    cw, sw = math.cos(w0), math.sin(w0)
    alpha = sw / (2.0 * max(q, 0.05))
    A = 10.0 ** (gain_db / 40.0)
    if kind == "lowpass":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "highpass":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "bandpass":
        b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "notch":
        b = [1.0, -2 * cw, 1.0]
        a = [1 + alpha, -2 * cw, 1 - alpha]
    elif kind == "peak":
        b = [1 + alpha * A, -2 * cw, 1 - alpha * A]
        a = [1 + alpha / A, -2 * cw, 1 - alpha / A]
    elif kind == "lowshelf":
        sa = 2 * math.sqrt(A) * alpha
        b = [A * ((A + 1) - (A - 1) * cw + sa), 2 * A * ((A - 1) - (A + 1) * cw), A * ((A + 1) - (A - 1) * cw - sa)]
        a = [(A + 1) + (A - 1) * cw + sa, -2 * ((A - 1) + (A + 1) * cw), (A + 1) + (A - 1) * cw - sa]
    elif kind == "highshelf":
        sa = 2 * math.sqrt(A) * alpha
        b = [A * ((A + 1) + (A - 1) * cw + sa), -2 * A * ((A - 1) + (A + 1) * cw), A * ((A + 1) + (A - 1) * cw - sa)]
        a = [(A + 1) - (A - 1) * cw + sa, 2 * ((A - 1) - (A + 1) * cw), (A + 1) - (A - 1) * cw - sa]
    else:
        raise ValueError(kind)
    b = np.array(b) / a[0]
    a = np.array(a) / a[0]
    return b, a


def biquad(sig: np.ndarray, kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0) -> np.ndarray:
    b, a = biquad_coeffs(kind, fc, q, gain_db)
    if sig.ndim == 2:
        return np.stack([sps.lfilter(b, a, sig[:, c]) for c in range(sig.shape[1])], axis=1)
    return sps.lfilter(b, a, sig)


def lowpass(sig, fc, q=0.707):
    return biquad(sig, "lowpass", fc, q)


def highpass(sig, fc, q=0.707):
    return biquad(sig, "highpass", fc, q)


def bandpass(sig, fc, q=1.0):
    return biquad(sig, "bandpass", fc, q)


def notch(sig, fc, q=4.0):
    return biquad(sig, "notch", fc, q)


def peak_eq(sig, fc, q, gain_db):
    return biquad(sig, "peak", fc, q, gain_db)


def shelf(sig, fc, gain_db, high: bool = False):
    return biquad(sig, "highshelf" if high else "lowshelf", fc, 0.707, gain_db)


def sweep_filter(sig: np.ndarray, kind: str, fc, q: float = 0.707, block: int = 64) -> np.ndarray:
    """Time-varying biquad: `fc` is a per-sample array; coefficients update every `block` samples."""
    n = len(sig)
    fc = np.asarray(fc, dtype=float)
    if len(fc) != n:
        fc = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(fc)), fc)
    out = np.zeros_like(sig)
    zi = np.zeros(2)
    for s in range(0, n, block):
        e = min(n, s + block)
        b, a = biquad_coeffs(kind, float(fc[(s + e) // 2]), q)
        out[s:e], zi = sps.lfilter(b, a, sig[s:e], zi=zi)
    return out


def butter(sig, fc, kind="low", order=4):
    sos = sps.butter(order, float(np.clip(fc, 10, SR * 0.49)), kind, fs=SR, output="sos")
    if sig.ndim == 2:
        return np.stack([sps.sosfilt(sos, sig[:, c]) for c in range(sig.shape[1])], axis=1)
    return sps.sosfilt(sos, sig)


# --------------------------------------------------------------------------------------
# effects
# --------------------------------------------------------------------------------------
def soft_clip(sig: np.ndarray, drive: float = 2.0) -> np.ndarray:
    return np.tanh(sig * drive) / math.tanh(min(drive, 20.0))


def hard_clip(sig: np.ndarray, ceiling: float = 0.9) -> np.ndarray:
    return np.clip(sig, -ceiling, ceiling)


def bitcrush(sig: np.ndarray, bits: int = 8, hold: int = 1) -> np.ndarray:
    steps = 2 ** (bits - 1)
    out = np.round(sig * steps) / steps
    if hold > 1:
        idx = (np.arange(len(out)) // hold) * hold
        out = out[idx]
    return out


def make_ir(dur: float = 1.2, seed: int = 1, tone: float = 4000.0, early_ms: float = 12.0) -> np.ndarray:
    """Synthesized decaying-noise impulse response (bright start, darker tail)."""
    n = n_samples(dur)
    r = rng(seed)
    ir = r.normal(0, 1, n)
    t = np.arange(n) / SR
    ir *= np.exp(-t * (6.9 / dur))  # -60 dB at `dur`
    ir = sweep_filter(ir, "lowpass", np.linspace(min(tone * 2, 16000), tone * 0.35, n), 0.6, block=256)
    # a few early reflections
    ne = n_samples(early_ms / 1000.0)
    for k in range(4):
        pos = int(ne * (0.3 + 0.7 * r.random()))
        if pos < n:
            ir[pos] += 0.5 * (1 - k * 0.15)
    ir[0] = 0.0
    return ir / (np.sqrt(np.sum(ir ** 2)) + 1e-9)


def reverb(sig: np.ndarray, decay: float = 1.0, mix: float = 0.3, seed: int = 1, tone: float = 4000.0,
           predelay_ms: float = 8.0) -> np.ndarray:
    ir = make_ir(decay, seed, tone)
    pre = np.zeros(n_samples(predelay_ms / 1000.0))
    ir = np.concatenate([pre, ir])
    if sig.ndim == 2:
        wet = np.stack([sps.fftconvolve(sig[:, c], make_ir(decay, seed + c, tone)) for c in range(2)], axis=1)
        wet = np.concatenate([np.zeros((len(pre), 2)), wet])
    else:
        wet = sps.fftconvolve(sig, ir)
    dry = np.zeros_like(wet)
    dry[: len(sig)] = sig
    return dry * (1.0 - mix) + wet * mix


def schroeder_reverb(sig: np.ndarray, mix: float = 0.3, room: float = 1.0) -> np.ndarray:
    """Classic comb + allpass reverb (mono)."""
    combs = [(1116, 0.84), (1188, 0.83), (1277, 0.82), (1356, 0.81)]
    tail = n_samples(0.9 * room)
    x = np.concatenate([sig, np.zeros(tail)])
    acc = np.zeros_like(x)
    for d, g in combs:
        d = int(d * room)
        b = np.zeros(d + 1)
        b[0] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        acc += sps.lfilter(b, a, x)
    acc /= len(combs)
    for d in (225, 556):
        g = 0.5
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        acc = sps.lfilter(b, a, acc)
    return x * (1 - mix) + acc * mix


def delay(sig: np.ndarray, time_ms: float = 120.0, feedback: float = 0.35, mix: float = 0.3, taps: int = 6) -> np.ndarray:
    d = n_samples(time_ms / 1000.0)
    out = np.zeros(len(sig) + d * taps)
    out[: len(sig)] += sig * (1 - mix)
    g = mix
    for k in range(1, taps + 1):
        out[k * d: k * d + len(sig)] += sig * g
        g *= feedback
    return out


def layer(*parts: np.ndarray, gains: Sequence[float] | None = None, offsets: Sequence[float] | None = None) -> np.ndarray:
    """Sum signals (with optional gains and start offsets in seconds), zero-padded to the longest."""
    gains = list(gains) if gains is not None else [1.0] * len(parts)
    offsets = list(offsets) if offsets is not None else [0.0] * len(parts)
    stereo = any(p.ndim == 2 for p in parts)
    total = max(n_samples(o) + len(p) for p, o in zip(parts, offsets))
    out = np.zeros((total, 2) if stereo else total)
    for p, g, o in zip(parts, gains, offsets):
        s = n_samples(o)
        if stereo and p.ndim == 1:
            p = np.stack([p, p], axis=1)
        out[s: s + len(p)] += p * g
    return out


def mix_at(base: np.ndarray, sig: np.ndarray, at: float, gain: float = 1.0) -> np.ndarray:
    return layer(base, sig, gains=[1.0, gain], offsets=[0.0, at])


def normalize(sig: np.ndarray, peak_db: float = -1.0) -> np.ndarray:
    p = np.abs(sig).max()
    if p < 1e-9:
        return sig
    return sig * (db(peak_db) / p)


def fade(sig: np.ndarray, in_ms: float = 2.0, out_ms: float = 10.0) -> np.ndarray:
    out = sig.copy()
    ni, no = min(n_samples(in_ms / 1000.0), len(out)), min(n_samples(out_ms / 1000.0), len(out))
    if ni > 0:
        w = np.linspace(0.0, 1.0, ni)
        out[:ni] = (out[:ni].T * w).T
    if no > 0:
        w = np.linspace(1.0, 0.0, no)
        out[-no:] = (out[-no:].T * w).T
    return out


def remove_dc(sig: np.ndarray) -> np.ndarray:
    return sig - sig.mean(axis=0)


def pad(sig: np.ndarray, before: float = 0.0, after: float = 0.0) -> np.ndarray:
    nb, na = n_samples(before) if before > 0 else 0, n_samples(after) if after > 0 else 0
    if sig.ndim == 2:
        return np.concatenate([np.zeros((nb, 2)), sig, np.zeros((na, 2))])
    return np.concatenate([np.zeros(nb), sig, np.zeros(na)])


def trim_tail(sig: np.ndarray, thresh_db: float = -54.0, keep_ms: float = 25.0) -> np.ndarray:
    m = np.abs(mono(sig))
    above = np.where(m > db(thresh_db) * (m.max() + 1e-9))[0]
    if len(above) == 0:
        return sig
    end = min(len(sig), above[-1] + n_samples(keep_ms / 1000.0))
    return sig[:end]


def trim_head(sig: np.ndarray, thresh_db: float = -50.0) -> np.ndarray:
    m = np.abs(mono(sig))
    above = np.where(m > db(thresh_db) * (m.max() + 1e-9))[0]
    if len(above) == 0:
        return sig
    return sig[max(0, above[0] - 8):]


def limit_len(sig: np.ndarray, dur: float, fade_ms: float = 15.0) -> np.ndarray:
    n = n_samples(dur)
    if len(sig) <= n:
        return sig
    return fade(sig[:n], 0.0, fade_ms)


def resample_ratio(sig: np.ndarray, ratio: float) -> np.ndarray:
    """Pitch/time shift by resampling: ratio 2.0 = one octave up (and half the length)."""
    n = max(8, int(round(len(sig) / ratio)))
    if sig.ndim == 2:
        return np.stack([sps.resample(sig[:, c], n) for c in range(2)], axis=1)
    return sps.resample(sig, n)


def pitch_shift(sig: np.ndarray, semitones: float) -> np.ndarray:
    return resample_ratio(sig, 2.0 ** (semitones / 12.0))


def to_stereo(sig: np.ndarray, width: float = 0.3, haas_ms: float = 0.0, seed: int = 0) -> np.ndarray:
    """Mono -> stereo with a little decorrelation (allpass-ish noise diffusion) and optional Haas delay."""
    if sig.ndim == 2:
        return sig
    left = sig.copy()
    right = sig.copy()
    if width > 0:
        ir_l = make_ir(0.03, seed + 11, 6000)
        ir_r = make_ir(0.03, seed + 23, 6000)
        dl = sps.fftconvolve(sig, ir_l)[: len(sig)]
        dr = sps.fftconvolve(sig, ir_r)[: len(sig)]
        left = sig * (1 - width) + dl * width
        right = sig * (1 - width) + dr * width
    if haas_ms > 0:
        d = n_samples(haas_ms / 1000.0)
        right = np.concatenate([np.zeros(d), right])[: len(left)]
    return np.stack([left, right], axis=1)


def pan(sig: np.ndarray, p: float) -> np.ndarray:
    """Constant-power pan of mono into stereo, p in [-1, 1]."""
    a = (p + 1.0) * 0.25 * math.pi
    return np.stack([sig * math.cos(a), sig * math.sin(a)], axis=1)


def seamless_loop(sig: np.ndarray, xfade_ms: float = 50.0) -> np.ndarray:
    """Crossfade the last `xfade_ms` into the start so the end sample flows into sample 0."""
    x = n_samples(xfade_ms / 1000.0)
    if len(sig) <= 2 * x:
        return sig
    out = sig[:-x].copy()
    w = np.linspace(0.0, 1.0, x)
    win_in = np.sin(w * math.pi / 2) ** 2
    win_out = np.cos(w * math.pi / 2) ** 2
    head = sig[:x]
    tail = sig[-x:]
    if sig.ndim == 2:
        out[:x] = head * win_in[:, None] + tail * win_out[:, None]
    else:
        out[:x] = head * win_in + tail * win_out
    return out


def repeat_to(sig: np.ndarray, dur: float) -> np.ndarray:
    n = n_samples(dur)
    reps = int(math.ceil(n / len(sig)))
    return np.concatenate([sig] * reps)[:n]


def lfo(dur: float, rate: float, depth: float = 1.0, shape: str = "sine", phase: float = 0.0, seed: int = 0) -> np.ndarray:
    if shape == "sine":
        return depth * 0.5 * (1 + np.sin(_phase(rate, n_samples(dur), phase)))
    if shape == "random":
        # smoothed random walk
        n = n_samples(dur)
        k = max(2, int(dur * rate) + 1)
        pts = rng(seed).uniform(0, 1, k)
        return depth * np.interp(np.linspace(0, 1, n), np.linspace(0, 1, k), pts)
    raise ValueError(shape)


def finalize(sig: np.ndarray, peak_db: float = -1.0, in_ms: float = 1.5, out_ms: float = 12.0, dc: bool = True) -> np.ndarray:
    """Standard mastering tail: DC removal, normalize, fade edges, clip guard."""
    out = np.asarray(sig, dtype=float)
    if dc:
        out = remove_dc(out)
    out = normalize(out, peak_db)
    out = fade(out, in_ms, out_ms)
    return np.clip(out, -0.999, 0.999)


# --------------------------------------------------------------------------------------
# IO
# --------------------------------------------------------------------------------------
def _smpl_chunk(loop_start: int, loop_end: int) -> bytes:
    body = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
    body += struct.pack("<6I", 0, 0, loop_start, loop_end, 0, 0)
    return b"smpl" + struct.pack("<I", len(body)) + body


def write_wav(path: str, sig: np.ndarray, sr: int = SR, loop: bool = False) -> None:
    """16-bit PCM WAV. With loop=True a `smpl` chunk marks a forward loop over the whole file
    (Godot's WAV importer picks it up in its default "Detect From WAV" loop mode)."""
    sig = np.clip(np.asarray(sig, dtype=float), -1.0, 1.0)
    channels = 2 if sig.ndim == 2 else 1
    pcm = (sig * 32767.0).astype("<i2").tobytes()
    fmt = b"fmt " + struct.pack("<IHHIIHH", 16, 1, channels, sr, sr * channels * 2, channels * 2, 16)
    data = b"data" + struct.pack("<I", len(pcm)) + pcm
    chunks = fmt
    if loop:
        chunks += _smpl_chunk(0, len(sig) - 1)
    chunks += data
    riff = b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "wb") as f:
        f.write(riff)


def write_ogg(path: str, sig: np.ndarray, sr: int = SR, quality: float = 0.5) -> bool:
    try:
        import soundfile as sf  # type: ignore
    except Exception:
        return False
    sig = np.clip(np.asarray(sig, dtype=float), -1.0, 1.0)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    try:
        sf.write(path, sig, sr, format="OGG", subtype="VORBIS")
    except Exception:
        return False
    return True


def read_audio(path: str) -> tuple[np.ndarray, int]:
    """Read WAV (stdlib) or anything soundfile can decode. Returns (float signal, sr)."""
    if path.lower().endswith(".wav"):
        with wave.open(path, "rb") as w:
            sr = w.getframerate()
            ch = w.getnchannels()
            sw = w.getsampwidth()
            raw = w.readframes(w.getnframes())
        if sw == 2:
            arr = np.frombuffer(raw, dtype="<i2").astype(float) / 32768.0
        elif sw == 1:
            arr = (np.frombuffer(raw, dtype=np.uint8).astype(float) - 128.0) / 128.0
        else:
            raise ValueError("unsupported sample width")
        if ch > 1:
            arr = arr.reshape(-1, ch)
        return arr, sr
    import soundfile as sf  # type: ignore

    data, sr = sf.read(path, dtype="float64")
    return data, sr


def wav_has_loop(path: str) -> bool:
    with open(path, "rb") as f:
        head = f.read(200)
    return b"smpl" in head


def load_mono(path: str, target_sr: int = SR) -> np.ndarray:
    data, sr = read_audio(path)
    data = mono(data)
    if sr != target_sr:
        data = sps.resample(data, int(round(len(data) * target_sr / sr)))
    return data


# --------------------------------------------------------------------------------------
# analysis / validation
# --------------------------------------------------------------------------------------
def stats(sig: np.ndarray, sr: int = SR) -> dict:
    m = mono(np.asarray(sig, dtype=float))
    n = len(m)
    peak = float(np.abs(sig).max()) if n else 0.0
    rms = float(np.sqrt(np.mean(m ** 2))) if n else 0.0
    dc = float(np.mean(m)) if n else 0.0
    edge = max(4, int(sr * 0.001))
    head = float(np.abs(sig[:edge]).max()) if n else 0.0
    tail = float(np.abs(sig[-edge:]).max()) if n else 0.0
    clipped = int(np.sum(np.abs(sig) >= 0.999))
    # transient sharpness: time to reach 50% of peak
    env = np.abs(m)
    idx50 = int(np.argmax(env >= 0.5 * peak)) if peak > 0 else 0
    # low-body ratio: energy below 250 Hz over total (first 120 ms)
    seg = m[: int(sr * 0.12)]
    if len(seg) > 64:
        spec = np.abs(np.fft.rfft(seg * np.hanning(len(seg))))
        freqs = np.fft.rfftfreq(len(seg), 1 / sr)
        tot = float(np.sum(spec ** 2)) + 1e-12
        low = float(np.sum(spec[freqs < 250] ** 2))
        cen = float(np.sum(spec ** 2 * freqs) / tot)
    else:
        low, tot, cen = 0.0, 1.0, 0.0
    return {
        "samples": n,
        "duration": n / sr,
        "peak_db": to_db(peak),
        "rms_db": to_db(rms),
        "dc": dc,
        "clipped": clipped,
        "head_peak": head,
        "tail_peak": tail,
        "attack_ms": idx50 * 1000.0 / sr,
        "low_ratio": low / tot,
        "centroid": cen,
        "channels": 2 if sig.ndim == 2 else 1,
    }


def loop_seam_error(sig: np.ndarray, sr: int = SR, win_ms: float = 5.0) -> float:
    """RMS level difference (dB) between the last and first few ms, plus the raw sample jump."""
    m = mono(sig)
    w = max(8, int(sr * win_ms / 1000.0))
    a = float(np.sqrt(np.mean(m[:w] ** 2)) + 1e-9)
    b = float(np.sqrt(np.mean(m[-w:] ** 2)) + 1e-9)
    jump = abs(float(m[-1]) - float(m[0]))
    return max(abs(20 * math.log10(a / b)), jump * 40.0)


def spectrogram_png(sig: np.ndarray, path: str, sr: int = SR, n_fft: int = 1024, hop: int = 256,
                    height: int = 256, max_width: int = 1200, title: str = "") -> None:
    """STFT magnitude image (log-frequency-ish rows, dB colors) drawn with PIL."""
    from PIL import Image, ImageDraw  # type: ignore

    m = mono(np.asarray(sig, dtype=float))
    if len(m) < n_fft:
        m = np.pad(m, (0, n_fft - len(m)))
    frames = 1 + (len(m) - n_fft) // hop
    if frames > max_width:
        hop = int(math.ceil((len(m) - n_fft) / max_width))
        frames = 1 + (len(m) - n_fft) // hop
    win = np.hanning(n_fft)
    idx = np.arange(n_fft)[None, :] + hop * np.arange(frames)[:, None]
    spec = np.abs(np.fft.rfft(m[idx] * win, axis=1))  # (frames, bins)
    spec_db = 20 * np.log10(spec + 1e-6)
    top = spec_db.max()
    spec_db = np.clip(spec_db, top - 80, top)
    # log-frequency row mapping
    bins = spec.shape[1]
    fmax = sr / 2
    rows = np.geomspace(40.0, fmax, height)
    row_bins = np.clip((rows / fmax * (bins - 1)).astype(int), 0, bins - 1)
    img = np.zeros((height, frames, 3), dtype=np.uint8)
    norm = (spec_db[:, row_bins].T - (top - 80)) / 80.0  # (height, frames) 0..1
    # inferno-ish ramp
    r = np.clip(norm * 2.2, 0, 1)
    g = np.clip(norm * 2.0 - 0.6, 0, 1)
    b = np.clip(1.2 - np.abs(norm - 0.25) * 3.0, 0, 1) * (norm < 0.55) + np.clip(norm * 2 - 1.3, 0, 1)
    img[..., 0] = (r * 255).astype(np.uint8)[::-1]
    img[..., 1] = (g * 255).astype(np.uint8)[::-1]
    img[..., 2] = (b * 255).astype(np.uint8)[::-1]
    im = Image.fromarray(img, "RGB")
    if frames < 400:
        im = im.resize((400, height), Image.NEAREST)
    canvas = Image.new("RGB", (im.width + 48, im.height + 40), (18, 18, 22))
    canvas.paste(im, (44, 8))
    d = ImageDraw.Draw(canvas)
    dur = len(m) / sr
    for f, label in ((100, "100"), (1000, "1k"), (5000, "5k"), (15000, "15k")):
        if f < fmax:
            y = 8 + height - int(round((math.log(f / 40.0) / math.log(fmax / 40.0)) * (height - 1))) - 1
            d.text((2, max(0, y - 5)), label, fill=(200, 200, 200))
    for k in range(5):
        x = 44 + int(im.width * k / 4)
        d.text((x, height + 12), f"{dur * k / 4:.2f}s", fill=(200, 200, 200))
    if title:
        d.text((44, height + 26), title, fill=(255, 220, 160))
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    canvas.save(path)


__all__ = [n for n in dir() if not n.startswith("_")]
