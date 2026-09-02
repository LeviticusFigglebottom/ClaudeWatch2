"""RINGFALL sound recipes.

Every recipe is `fn(seed:int, variant:int=0, **params) -> np.ndarray` registered with @recipe.
`kind` drives the numeric validation in gen_audio.py (duration windows, transient checks...).
Recipes that use Kenney CC0 samples go through `ken()` which records the source for ATTRIBUTION.md
and silently falls back to pure synthesis when the OGG decoder (soundfile) is unavailable.

Tone reference (docs/DESIGN.md): hopeful, weathered, sunlit. Weapons are mechanical-with-character
rather than sci-fi lasers; casts are airy; UI is warm and short; announcer stings are musical, not vocal.
"""
from __future__ import annotations

import glob
import hashlib
import math
import os
from dataclasses import dataclass, field
from typing import Callable

import numpy as np
from scipy import signal as sps

import synth as S
from synth import (SR, adsr, apply, bandpass, db, env_points, exp_env, fade, fm, highpass, layer, lowpass,
                   midi_to_hz, mix_at, n_samples, noise, normalize, pad, peak_eq, reverb, rng, saw, seamless_loop,
                   sine, soft_clip, square, sweep, sweep_filter, t_axis, to_stereo, tri)

KENNEY_ROOT = os.environ.get("KENNEY_ROOT", "/opt/assets/kenney")


# --------------------------------------------------------------------------------------
# registry
# --------------------------------------------------------------------------------------
@dataclass
class Recipe:
    name: str
    fn: Callable
    kind: str
    variants: int = 1
    stereo: bool = False
    loop: bool = False
    doc: str = ""


RECIPES: dict[str, Recipe] = {}
CURRENT_SOURCES: list[str] = []  # Kenney files consumed by the recipe being rendered


def recipe(name: str, kind: str, variants: int = 1, stereo: bool = False, loop: bool = False, doc: str = ""):
    def deco(fn):
        RECIPES[name] = Recipe(name, fn, kind, variants, stereo, loop, doc or (fn.__doc__ or "").strip())
        return fn
    return deco


def render(name: str, seed: int, variant: int = 0, **params) -> tuple[np.ndarray, list[str]]:
    """Render a recipe; returns (signal, kenney_sources_used)."""
    CURRENT_SOURCES.clear()
    r = RECIPES[name]
    sig = r.fn(seed, variant, **params)
    return sig, list(CURRENT_SOURCES)


# --------------------------------------------------------------------------------------
# Kenney sample access (optional)
# --------------------------------------------------------------------------------------
_KEN_CACHE: dict[str, np.ndarray | None] = {}


def ken(pack: str, name: str, gain_db: float = 0.0, semitones: float = 0.0, hp: float | None = None,
        lp: float | None = None, max_dur: float | None = None, trim_head: bool = True) -> np.ndarray | None:
    """Load `<KENNEY_ROOT>/<pack>/Audio/<name>.ogg` as mono @44.1k with light processing, or None."""
    path = os.path.join(KENNEY_ROOT, pack, "Audio", name + ".ogg")
    if path not in _KEN_CACHE:
        try:
            _KEN_CACHE[path] = S.load_mono(path)
        except Exception:
            _KEN_CACHE[path] = None
    sig = _KEN_CACHE[path]
    if sig is None:
        return None
    CURRENT_SOURCES.append(f"{pack}/Audio/{name}.ogg")
    out = sig.copy()
    if trim_head:
        out = S.trim_head(out, -45.0)
    if semitones:
        out = S.pitch_shift(out, semitones)
    if hp:
        out = highpass(out, hp)
    if lp:
        out = lowpass(out, lp)
    if max_dur:
        out = S.limit_len(out, max_dur, 12.0)
    return out * db(gain_db)


def ken_pick(pack: str, prefix: str, variant: int, count: int, **kw) -> np.ndarray | None:
    """Pick the variant-th of a numbered Kenney family: e.g. footstep_concrete_000..004."""
    files = sorted(glob.glob(os.path.join(KENNEY_ROOT, pack, "Audio", prefix + "*.ogg")))
    if not files:
        return None
    name = os.path.basename(files[variant % min(count, len(files))])[:-4]
    return ken(pack, name, **kw)


# --------------------------------------------------------------------------------------
# hero identity -> deterministic musical / timbral parameters
# --------------------------------------------------------------------------------------
SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "pent_major": [0, 2, 4, 7, 9, 12, 14],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
}
MINOR = [0, 2, 3, 5, 7, 8, 10]
TIMBRES = ["pluck", "bell", "brass", "glass", "choir", "pad"]
CONTOURS = [  # scale-degree offsets (0 = root)
    [0, 2, 4, 7, 9], [0, 4, 7, 4, 0], [0, -1, 0, 4, 7], [7, 4, 0, 4, 9], [0, 2, 0, 7, 9],
    [0, 7, 9, 7, 12], [4, 2, 0, -3, 0], [0, 3, 7, 10, 12], [0, 5, 4, 7, 11], [2, 0, 4, 7, 14],
    [0, 4, 2, 9, 7], [7, 7, 9, 11, 14],
]
RHYTHMS = [[1, 1, 1, 1, 2.5], [0.5, 0.5, 1, 1, 3], [1, 0.5, 0.5, 1, 3], [1.5, 0.5, 1, 1, 2.5], [0.75, 0.75, 0.5, 1, 3]]


def hero_hash(hero: str) -> int:
    return int.from_bytes(hashlib.md5(hero.encode()).digest()[:8], "little")


def hero_voice(hero: str | None) -> dict:
    if not hero:
        hero = "generic"
    h = hero_hash(hero)
    names = list(SCALES.keys())
    return {
        "hero": hero,
        "semi": (h & 7) - 3,                       # sfx pitch offset in semitones (-3..+4)
        "bright": ((h >> 8) % 100) / 100.0,        # 0 dark .. 1 bright
        "root": 50 + ((h >> 16) % 15),             # D3..E4
        "scale": names[(h >> 24) % len(names)],
        "timbre": TIMBRES[(h >> 32) % len(TIMBRES)],
        "contour": CONTOURS[(h >> 40) % len(CONTOURS)],
        "rhythm": RHYTHMS[(h >> 48) % len(RHYTHMS)],
        "bpm": 96 + ((h >> 56) % 44),
    }


def degree_to_midi(root: int, scale: list[int], degree: int) -> int:
    octave, d = divmod(degree, 7)
    return root + 12 * octave + scale[d]


def motif_notes(voice: dict, minor: bool = False) -> list[tuple[float, float]]:
    """-> [(midi, beats)] for the hero's 5-note motif."""
    scale = MINOR if minor else SCALES[voice["scale"]]
    return [(degree_to_midi(voice["root"], scale, d), b) for d, b in zip(voice["contour"], voice["rhythm"])]


# --------------------------------------------------------------------------------------
# small building blocks
# --------------------------------------------------------------------------------------
def click(seed: int = 0, dur: float = 0.005, hp: float = 1500.0) -> np.ndarray:
    return highpass(apply(noise(dur, seed), exp_env(dur, dur / 3)), hp)


def crack(seed: int, dur: float = 0.035, fc: float = 3000.0, q: float = 1.0, color: str = "white") -> np.ndarray:
    return apply(bandpass(noise(dur, seed, color), fc, q), exp_env(dur, dur / 3.5))


def body(f0: float, f1: float, dur: float, tau: float | None = None, drive: float = 1.5) -> np.ndarray:
    tau = tau or dur / 3.0
    return soft_clip(apply(sine(sweep(f0, f1, dur), dur), exp_env(dur, tau)), drive)


def whoosh(f0: float, f1: float, dur: float, seed: int, q: float = 2.0, color: str = "white",
           shape: tuple[float, float, float] = (0.3, 1.0, 0.0)) -> np.ndarray:
    """Band-swept noise with a rise/peak/fall envelope (shape = peak position, peak level, end level)."""
    n = noise(dur, seed, color)
    out = sweep_filter(n, "bandpass", sweep(f0, f1, dur), q)
    env = env_points(dur, [(0, 0.0), (dur * shape[0], shape[1]), (dur, shape[2])])
    return apply(out, env)


def ring(freq: float, dur: float, seed: int, q: float = 20.0, tau: float | None = None) -> np.ndarray:
    """Resonant noise ping (metallic / glassy)."""
    return apply(bandpass(noise(dur, seed), freq, q), exp_env(dur, tau or dur / 4))


def tone(freq, dur: float, a: float = 0.005, r: float | None = None, wave: str = "sine", tau: float | None = None) -> np.ndarray:
    osc = {"sine": sine, "saw": saw, "tri": tri, "square": square}[wave]
    sig = osc(freq, dur)
    if tau:
        env = exp_env(dur, tau)
        na = n_samples(a)
        env[:na] *= np.linspace(0, 1, na)
        return apply(sig, env)
    return apply(sig, adsr(dur, a, 0.0, 1.0, r if r is not None else dur * 0.5))


def sub_kick(f0: float = 150.0, f1: float = 40.0, dur: float = 0.25, drive: float = 2.5) -> np.ndarray:
    return body(f0, f1, dur, dur / 4, drive)


def room(sig: np.ndarray, decay: float = 0.35, mix: float = 0.18, seed: int = 3, tone_hz: float = 3500.0) -> np.ndarray:
    return reverb(sig, decay, mix, seed, tone_hz)


def semi(v: dict, base: float) -> float:
    """Apply the hero's semitone offset to a base frequency."""
    return base * 2.0 ** (v["semi"] / 12.0)


def var_jitter(seed: int, variant: int, amount: float = 0.06) -> float:
    return 1.0 + rng(seed * 7 + variant * 131).uniform(-amount, amount)


# --------------------------------------------------------------------------------------
# instruments (musical)
# --------------------------------------------------------------------------------------
def pluck(freq: float, dur: float, seed: int = 0, bright: float = 0.6) -> np.ndarray:
    N = max(2, int(round(SR / freq)))
    n = n_samples(dur)
    x = np.zeros(n)
    x[:N] = rng(seed).uniform(-1, 1, N)
    x[:N] = lowpass(x[:N], 1500 + bright * 6000)
    g = 0.001 ** (N / n)
    a = np.zeros(N + 2)
    a[0] = 1.0
    a[N] = -g * 0.5
    a[N + 1] = -g * 0.5
    y = sps.lfilter([1.0], a, x)
    return fade(y / (np.abs(y).max() + 1e-9), 1, 20)


def bell(freq: float, dur: float, seed: int = 0, bright: float = 0.5) -> np.ndarray:
    partials = [(1.0, 1.0), (2.0, 0.55), (2.76, 0.35 * bright + 0.1), (4.07, 0.22 * bright), (5.4, 0.12 * bright)]
    out = np.zeros(n_samples(dur))
    for k, (ratio, amp) in enumerate(partials):
        out += amp * apply(sine(freq * ratio, dur), exp_env(dur, dur / (2.2 + k * 1.2)))
    out = apply(out, adsr(dur, 0.003, 0, 1, dur * 0.4))
    return out / (np.abs(out).max() + 1e-9)


def glass(freq: float, dur: float, seed: int = 0, bright: float = 0.5) -> np.ndarray:
    out = apply(sine(freq, dur), exp_env(dur, dur / 2.5)) + 0.35 * apply(sine(freq * 3.0, dur), exp_env(dur, dur / 6))
    out += 0.2 * apply(fm(freq * 2, 3.5, 0.6, dur), exp_env(dur, dur / 8))
    return fade(out / (np.abs(out).max() + 1e-9), 2, 20)


def brass(freq: float, dur: float, seed: int = 0, bright: float = 0.6) -> np.ndarray:
    vib = 1.0 + 0.004 * np.sin(S._phase(5.5, n_samples(dur)))
    sig = saw(freq * vib, dur) + 0.5 * saw(freq * vib * 1.003, dur)
    cutoff = env_points(dur, [(0, 400), (0.08, 1500 + 3000 * bright), (dur, 700)])
    sig = sweep_filter(sig, "lowpass", cutoff, 1.2)
    sig = apply(sig, adsr(dur, 0.04, 0.1, 0.8, min(0.3, dur * 0.4)))
    return sig / (np.abs(sig).max() + 1e-9)


def pad_note(freq: float, dur: float, seed: int = 0, bright: float = 0.4, attack: float = 0.4) -> np.ndarray:
    r = rng(seed)
    sig = np.zeros(n_samples(dur))
    for c in (-8, -3, 4, 9):
        sig += saw(freq * 2 ** (c / 1200.0), dur, phase=r.uniform(0, S.TAU))
    sig += 1.2 * sine(freq * 0.5, dur)
    cut = 600 + 1800 * bright
    sig = lowpass(sig, cut, 0.8)
    sig = apply(sig, adsr(dur, attack, 0.0, 1.0, min(0.6, dur * 0.4)))
    return sig / (np.abs(sig).max() + 1e-9)


def choir(freq: float, dur: float, seed: int = 0, bright: float = 0.5) -> np.ndarray:
    src = S.pulse_train(freq, dur, 10) + 0.4 * S.pulse_train(freq * 2 ** (7 / 1200), dur, 10)
    out = np.zeros_like(src)
    for fc, q, g in ((650, 6, 1.0), (1080, 8, 0.6), (2650, 10, 0.25 + 0.3 * bright)):
        out += g * bandpass(src, fc, q)
    out = apply(out, adsr(dur, 0.12, 0.0, 1.0, min(0.5, dur * 0.4)))
    return out / (np.abs(out).max() + 1e-9)


INSTRUMENTS = {"pluck": pluck, "bell": bell, "brass": brass, "glass": glass, "choir": choir, "pad": pad_note}


def play_notes(notes: list[tuple[float, float]], bpm: float, instrument: str, seed: int = 0, bright: float = 0.5,
               gain: float = 0.7, sustain_mult: float = 1.6, detune_cents: float = 0.0) -> np.ndarray:
    """Render [(midi, beats)] sequentially with the named instrument."""
    inst = INSTRUMENTS[instrument]
    spb = 60.0 / bpm
    parts, offsets = [], []
    t = 0.0
    for i, (m, beats) in enumerate(notes):
        d = beats * spb * sustain_mult
        f = midi_to_hz(m) * 2 ** (detune_cents / 1200.0)
        parts.append(inst(f, d, seed + i, bright) * gain)
        offsets.append(t)
        t += beats * spb
    return layer(*parts, offsets=offsets)


def chord(midis: list[int], dur: float, instrument: str = "pad", seed: int = 0, bright: float = 0.4, gain: float = 0.5,
          attack: float = 0.3) -> np.ndarray:
    inst = INSTRUMENTS[instrument]
    parts = []
    for i, m in enumerate(midis):
        if instrument == "pad":
            parts.append(inst(midi_to_hz(m), dur, seed + i, bright, attack))
        else:
            parts.append(inst(midi_to_hz(m), dur, seed + i, bright))
    return layer(*parts) * gain / max(1, len(midis)) ** 0.5


# ======================================================================================
# WEAPON FIRES  (kind gunshot: 80-250 ms, sharp transient, low body)
# ======================================================================================
def _shot(seed, variant, hero, tr_hp, body_f, body_dur, crack_fc, crack_dur, drive, click_g=1.0, crack_g=0.8, body_g=1.0,
          extra=None, dur_total=None):
    v = hero_voice(hero)
    j = var_jitter(seed, variant)
    bf0, bf1 = body_f
    parts = [
        click(seed + variant, 0.004, tr_hp) * click_g,
        crack(seed + 3 + variant, crack_dur, semi(v, crack_fc) * j, 1.1) * crack_g,
        body(semi(v, bf0) * j, semi(v, bf1), body_dur, body_dur / 3.2, drive) * body_g,
    ]
    if extra is not None:
        parts.append(extra)
    sig = layer(*parts)
    sig = peak_eq(sig, 2400 + 2500 * v["bright"], 1.0, 2.0 + 3.0 * v["bright"])
    sig = soft_clip(sig, 1.4)
    if dur_total:
        sig = S.limit_len(sig, dur_total, 20)
    return sig


@recipe("rifle_semi", "gunshot", 3, doc="Dry, tight crack with a wooden body; long-range marksman rifle.")
def rifle_semi(seed, variant=0, hero=None, **_):
    return _shot(seed, variant, hero, 2000, (190, 55), 0.15, 3200, 0.03, 1.8,
                 extra=ring(1900, 0.06, seed + 9, 14) * 0.25, dur_total=0.18)


@recipe("smg", "gunshot", 3, doc="Light, snappy, bright: twin machine pistols.")
def smg(seed, variant=0, hero=None, **_):
    return _shot(seed, variant, hero, 2600, (260, 95), 0.08, 4200, 0.02, 1.6, crack_g=1.0, body_g=0.8, dur_total=0.1)


@recipe("cannon", "gunshot", 3, doc="Heavy boom: long low body, saturated, muffled top.")
def cannon(seed, variant=0, hero=None, **_):
    sig = _shot(seed, variant, hero, 900, (110, 34), 0.24, 1400, 0.05, 2.6, click_g=0.6, crack_g=0.7, body_g=1.3)
    return lowpass(sig, 5000)


@recipe("slug_cannon", "gunshot", 3, doc="Cannon with a molten sizzle: Kiln's furnace slugs.")
def slug_cannon(seed, variant=0, hero=None, **_):
    sizzle = apply(bandpass(noise(0.2, seed + 21, "pink"), 5200, 0.7), env_points(0.2, [(0, 0), (0.03, 0.8), (0.2, 0)])) * 0.35
    return _shot(seed, variant, hero, 900, (125, 38), 0.22, 1600, 0.05, 2.4, click_g=0.6, body_g=1.2, extra=sizzle)


@recipe("shotgun_wave", "gunshot", 3, doc="Wide, watery blast: broadband burst swept down + pressure whoosh.")
def shotgun_wave(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    burst = apply(sweep_filter(noise(0.16, seed + variant), "lowpass", sweep(7000, 350, 0.16), 0.9), exp_env(0.16, 0.05))
    wave_ = whoosh(300, 1300, 0.14, seed + 5, 1.5, "pink", (0.15, 0.7, 0.0))
    b = body(semi(v, 95), semi(v, 38), 0.2, 0.06, 2.2)
    sig = layer(click(seed, 0.004, 1200), burst, wave_ * 0.6, b * 1.1)
    return soft_clip(sig, 1.5)


@recipe("mortar_thump", "gunshot", 3, doc="Hollow tube thump: pitch-dropping sine through a resonant lowpass + breathy puff.")
def mortar_thump(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    puff = apply(lowpass(noise(0.18, seed + variant, "pink"), 900, 2.0), exp_env(0.18, 0.05))
    b = body(semi(v, 130), semi(v, 42), 0.22, 0.07, 1.8)
    sig = layer(click(seed, 0.003, 800) * 0.5, puff * 0.9, lowpass(b, 400, 3.0) * 1.4)
    return soft_clip(sig, 1.3)


@recipe("gravity_mortar", "gunshot", 3, doc="Mortar thump with a downward FM 'womp' (gravity engineer).")
def gravity_mortar(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    womp = apply(fm(sweep(semi(v, 220), semi(v, 45), 0.22), 0.5, 3.0, 0.22), exp_env(0.22, 0.07)) * 0.7
    base = mortar_thump(seed, variant, hero)
    return soft_clip(layer(base, womp), 1.3)


@recipe("rock_lob", "gunshot", 3, doc="Earthy launch: low thud + gravel crackle.")
def rock_lob(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    r = rng(seed + variant)
    grav = np.zeros(n_samples(0.16))
    for _ in range(14):
        p = int(r.uniform(0, len(grav) - 400))
        grav[p:p + 300] += crack(seed + p, 300 / SR, r.uniform(900, 3200), 2.0)[:300] * r.uniform(0.3, 1.0)
    grav = apply(grav, exp_env(0.16, 0.05))
    b = body(semi(v, 100), semi(v, 40), 0.2, 0.06, 2.0)
    return soft_clip(layer(click(seed, 0.004, 900) * 0.6, grav, b * 1.2), 1.3)


@recipe("needle_burst", "gunshot", 3, doc="Three quick high FM ticks (25 ms apart): needle burst rifle.")
def needle_burst(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    ticks = []
    offs = []
    for i in range(3):
        f = semi(v, 2600 + 300 * i) * var_jitter(seed, variant + i, 0.05)
        t = apply(fm(f, 2.01, 1.5, 0.04), exp_env(0.04, 0.01)) + click(seed + i, 0.003, 3000) * 0.5
        ticks.append(t)
        offs.append(i * 0.026)
    b = body(semi(v, 160), semi(v, 70), 0.09, 0.03, 1.4) * 0.5
    return soft_clip(layer(*ticks, b, offsets=offs + [0.0]), 1.2)


@recipe("thorn", "gunshot", 3, doc="Organic 'thwip': swept noise + a wooden knock.")
def thorn(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    w = whoosh(2400, 500, 0.06, seed + variant, 2.5, "white", (0.1, 1.0, 0.0))
    knock = apply(lowpass(noise(0.05, seed + 7), 500, 4.0), exp_env(0.05, 0.012))
    b = body(semi(v, 280), semi(v, 110), 0.09, 0.025, 1.2)
    return soft_clip(layer(w, knock * 0.8, b * 0.8), 1.2)


@recipe("disc_launch", "gunshot", 3, doc="Metallic 'shing': inharmonic FM ring + fast whoosh (disc launcher).")
def disc_launch(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    f = semi(v, 880) * var_jitter(seed, variant, 0.04)
    sh = apply(fm(f, 1.41, env_points(0.18, [(0, 3.0), (0.18, 0.4)]), 0.18), exp_env(0.18, 0.05))
    w = whoosh(600, 3200, 0.12, seed + variant, 1.5, "white", (0.25, 0.8, 0.0))
    b = body(semi(v, 170), semi(v, 70), 0.1, 0.03, 1.5) * 0.6
    return soft_clip(layer(click(seed, 0.003, 2500) * 0.6, sh * 0.8, w * 0.6, b), 1.2)


@recipe("lightning_arc", "gunshot", 3, doc="Electric crackle: sparse impulses + buzzy 110 Hz body with rapid decay.")
def lightning_arc(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    r = rng(seed + variant)
    n = n_samples(0.13)
    imp = np.zeros(n)
    for _ in range(40):
        p = int(r.uniform(0, n - 60))
        imp[p:p + 30] += r.uniform(-1, 1) * np.linspace(1, 0, 30)
    crackle = apply(bandpass(imp, 4200, 0.8), exp_env(0.13, 0.05))
    buzz = apply(square(semi(v, 110) * var_jitter(seed, variant, 0.03), 0.09, 0.3), exp_env(0.09, 0.022))
    buzz = lowpass(buzz, 2500)
    return soft_clip(layer(click(seed, 0.002, 4000), crackle, buzz * 0.7), 1.6)


@recipe("beam_fire", "gunshot", 2, doc="Beam ignition: soft zap start with a low hum bloom (not a gunshot, but sharp).")
def beam_fire(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    zap = apply(sine(sweep(semi(v, 1800), semi(v, 600), 0.08)), exp_env(0.08, 0.02)) if False else apply(sine(sweep(semi(v, 1800), semi(v, 600), 0.08), 0.08), exp_env(0.08, 0.02))
    hum = apply(lowpass(saw(semi(v, 110), 0.16), 900), env_points(0.16, [(0, 0), (0.02, 1), (0.16, 0.3)]))
    return soft_clip(layer(click(seed + variant, 0.003, 3000) * 0.7, zap * 0.7, hum * 0.5), 1.2)


@recipe("staff_bolt", "gunshot", 3, doc="Soft lantern bolt: FM shimmer sweep, breathy, no bang.")
def staff_bolt(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    f = semi(v, 700) * var_jitter(seed, variant, 0.05)
    bolt = apply(fm(sweep(f, f * 0.5, 0.15), 2.0, 1.2, 0.15), exp_env(0.15, 0.045))
    breath = whoosh(900, 2500, 0.12, seed + variant, 1.2, "pink", (0.2, 0.6, 0.0))
    b = body(semi(v, 150), semi(v, 70), 0.1, 0.03, 1.2) * 0.5
    return soft_clip(layer(click(seed, 0.003, 2000) * 0.4, bolt, breath * 0.5, b), 1.1)


@recipe("stapler", "gunshot", 3, doc="Mechanical 'ka-chk': two clicks 40 ms apart + spring ping (field-medic stapler).")
def stapler(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    c1 = click(seed + variant, 0.006, 1200) + apply(lowpass(noise(0.02, seed + 1), 1500, 3), exp_env(0.02, 0.005))
    c2 = click(seed + 40 + variant, 0.008, 900) * 1.2 + apply(lowpass(noise(0.03, seed + 2), 700, 2), exp_env(0.03, 0.008))
    spring = ring(semi(v, 1800), 0.07, seed + 5, 25) * 0.5
    b = body(semi(v, 200), semi(v, 90), 0.08, 0.025, 1.2) * 0.6
    return soft_clip(layer(c1, c2, spring, b, offsets=[0.0, 0.04, 0.04, 0.04]), 1.2)


@recipe("flame_bolt", "gunshot", 3, doc="'Fwoosh': brown-noise burst swept 3k->500 + a low puff (candle-maker's flame bolt).")
def flame_bolt(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    fw = apply(sweep_filter(noise(0.2, seed + variant, "pink"), "lowpass", sweep(3500, 450, 0.2), 1.2),
               env_points(0.2, [(0, 0), (0.02, 1), (0.2, 0)]))
    fl = apply(bandpass(noise(0.18, seed + 9, "white"), 1800, 0.6), exp_env(0.18, 0.06)) * 0.3
    b = body(semi(v, 120), semi(v, 55), 0.14, 0.04, 1.4) * 0.8
    return soft_clip(layer(fw, fl, b), 1.2)


@recipe("bass_cannon", "gunshot", 3, doc="808-style sub kick: 150->40 Hz pitch drop, saturated, with a click.")
def bass_cannon(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    k = sub_kick(semi(v, 160) * var_jitter(seed, variant, 0.03), semi(v, 42), 0.22, 3.0)
    c = click(seed + variant, 0.004, 2500) * 0.8 + crack(seed + 3, 0.02, 2200, 1.0) * 0.5
    return soft_clip(layer(c, k * 1.2), 1.2)


@recipe("blade_swing", "swing", 3, doc="Three-hit blade combo: each variant is a different swing arc (band sweep).")
def blade_swing(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    arcs = [(600, 2600, 0.15, 2.2), (2400, 700, 0.17, 2.0), (500, 3400, 0.21, 1.6)]
    f0, f1, dur, q = arcs[variant % 3]
    w = whoosh(semi(v, f0), semi(v, f1), dur, seed + variant, q, "white", (0.4, 1.0, 0.0))
    edge = ring(semi(v, 5200), 0.05, seed + 7, 18) * 0.25
    return soft_clip(layer(w, edge, offsets=[0.0, dur * 0.35]), 1.1)


@recipe("mace_swing", "swing", 3, doc="Heavy mace arc: low, slow whoosh with chain rattle.")
def mace_swing(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    w = whoosh(semi(v, 250), semi(v, 900), 0.24, seed + variant, 1.6, "pink", (0.55, 1.0, 0.0))
    r = rng(seed + variant)
    rattle = np.zeros(n_samples(0.2))
    for _ in range(6):
        p = int(r.uniform(0, len(rattle) - 500))
        rattle[p:p + 400] += ring(r.uniform(2500, 4500), 400 / SR, seed + p, 12)[:400] * 0.3
    return soft_clip(layer(w, rattle), 1.1)


@recipe("heal_bolt", "gunshot", 3, doc="Soft bell-ish bolt: 880 Hz + 2nd harmonic, gentle attack, airy noise.")
def heal_bolt(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    f = semi(v, 880) * var_jitter(seed, variant, 0.04)
    b = apply(sine(f, 0.16) + 0.4 * sine(f * 2, 0.16), exp_env(0.16, 0.05))
    air = whoosh(1500, 3000, 0.1, seed + variant, 1.0, "pink", (0.2, 0.5, 0.0))
    sig = layer(click(seed, 0.002, 2500) * 0.3, b, air * 0.4)
    env = adsr(len(sig) / SR, 0.004, 0, 1, 0.05)
    return apply(sig, env)


# ======================================================================================
# TAILS (kind tail: 0.4-1.2 s)
# ======================================================================================
def _tail(seed, dur, fc_hi, fc_lo, q, color, decay, gain_low=0.0):
    n = noise(dur, seed, color)
    sig = sweep_filter(n, "bandpass", sweep(fc_hi, fc_lo, dur), q)
    sig = apply(sig, exp_env(dur, dur / decay))
    if gain_low:
        sig = layer(sig, apply(lowpass(noise(dur, seed + 1, "brown"), 120), exp_env(dur, dur / 2.5)) * gain_low)
    return reverb(sig, dur * 0.8, 0.5, seed, 3000)[: n_samples(dur)]


@recipe("rifle_tail", "tail", 2, doc="Rifle report echo: bandpass noise 2k->300 over 0.9 s.")
def rifle_tail(seed, variant=0, hero=None, **_):
    return _tail(seed + variant, 0.9, 2200, 300, 1.2, "white", 3.5)


@recipe("cannon_tail", "tail", 2, doc="Low rumble tail 1.2 s.")
def cannon_tail(seed, variant=0, hero=None, **_):
    return _tail(seed + variant, 1.2, 900, 90, 1.0, "pink", 3.0, 0.8)


@recipe("short_tail", "tail", 2, doc="Short room tail 0.45 s.")
def short_tail(seed, variant=0, hero=None, **_):
    return _tail(seed + variant, 0.45, 3000, 500, 1.0, "white", 4.0)


# ======================================================================================
# CASTS / ABILITY ONE-SHOTS (kind cast)
# ======================================================================================
@recipe("whoosh", "cast", doc="Generic airy cast whoosh, 0.35 s.")
def whoosh_cast(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    return layer(whoosh(semi(v, 400), semi(v, 2200), 0.35, seed, 1.8, "pink", (0.35, 1.0, 0.0)),
                 apply(sine(semi(v, 330), 0.3), exp_env(0.3, 0.08)) * 0.3)


@recipe("throw_whoosh", "cast", doc="Arm throw: short cloth whoosh + a glassy tinkle of the thrown object.")
def throw_whoosh(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    w = whoosh(300, 1800, 0.22, seed, 2.0, "pink", (0.5, 1.0, 0.0))
    tink = ring(semi(v, 3800), 0.12, seed + 3, 30) * 0.35 + glass(semi(v, 1760), 0.2, seed) * 0.25
    return layer(w, tink, offsets=[0.0, 0.05])


@recipe("dash", "cast", doc="Dash: fast rising whoosh with a doppler-ish pitch bend.")
def dash(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    w = whoosh(500, 3500, 0.3, seed, 1.5, "white", (0.25, 1.0, 0.0))
    t = apply(sine(sweep(semi(v, 220), semi(v, 440), 0.25), 0.25), env_points(0.25, [(0, 0), (0.05, 0.6), (0.25, 0)]))
    return layer(w, lowpass(t, 1500) * 0.5)


@recipe("teleport_out", "cast", doc="Fold-out: rising FM shimmer with a vacuum pull.")
def teleport_out(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    sh = apply(fm(sweep(semi(v, 300), semi(v, 1800), 0.35), 1.5, 2.0, 0.35), env_points(0.35, [(0, 0.3), (0.3, 1), (0.35, 0)]))
    suck = whoosh(2500, 300, 0.3, seed, 2.0, "white", (0.7, 1.0, 0.0))
    return layer(sh * 0.7, suck * 0.6, click(seed, 0.004, 3000), offsets=[0, 0, 0.33])


@recipe("teleport_in", "cast", doc="Fold-in: descending shimmer that snaps into a soft thump.")
def teleport_in(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    sh = apply(fm(sweep(semi(v, 1800), semi(v, 350), 0.28), 1.5, 2.0, 0.28), exp_env(0.28, 0.1))
    th = body(120, 50, 0.15, 0.04, 1.5)
    air = whoosh(400, 2500, 0.2, seed, 1.5, "pink", (0.3, 0.8, 0.0))
    return layer(sh * 0.6, air * 0.5, th * 0.8, offsets=[0, 0, 0.02])


@recipe("deploy_place", "cast", doc="Deployable set down: mechanical clack + servo whir + confirmation tone.")
def deploy_place(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    clack = click(seed, 0.008, 800) + apply(lowpass(noise(0.04, seed + 1), 900, 2.5), exp_env(0.04, 0.01))
    servo = apply(lowpass(saw(sweep(180, 420, 0.22), 0.22), 1400, 2.0), env_points(0.22, [(0, 0.6), (0.18, 0.6), (0.22, 0)])) * 0.35
    tone_ = apply(sine(semi(v, 1320), 0.18) + 0.3 * sine(semi(v, 1980), 0.18), exp_env(0.18, 0.06)) * 0.4
    k = ken("impact-sounds", "impactMetal_medium_001", -8, 0, 300, None, 0.2)
    parts = [clack, servo, tone_]
    offs = [0.0, 0.02, 0.24]
    if k is not None:
        parts.append(k * 0.6)
        offs.append(0.0)
    return layer(*parts, offsets=offs)


@recipe("barrier_up", "cast", doc="Barrier rising: shimmering sweep up + crystalline lock-in ping.")
def barrier_up(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    sw = apply(sweep_filter(saw(semi(v, 110), 0.5) + saw(semi(v, 165), 0.5), "lowpass", sweep(300, 6000, 0.5), 2.5),
               env_points(0.5, [(0, 0), (0.1, 0.8), (0.42, 0.8), (0.5, 0)])) * 0.4
    ping_ = glass(semi(v, 2093), 0.35, seed) * 0.5
    k = ken("sci-fi-sounds", "forceField_000", -14, 0, 200, 6000, 0.5)
    parts = [sw, ping_]
    offs = [0.0, 0.38]
    if k is not None:
        parts.append(apply(k, env_points(len(k) / SR, [(0, 0), (0.1, 1), (0.45, 1), (0.5, 0)])))
        offs.append(0.0)
    return layer(*parts, offsets=offs)


@recipe("barrier_down", "cast", doc="Barrier collapse: descending shimmer + glassy shatter.")
def barrier_down(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    sw = apply(sweep_filter(saw(semi(v, 110), 0.4), "lowpass", sweep(5000, 250, 0.4), 2.5), exp_env(0.4, 0.15)) * 0.4
    r = rng(seed)
    shards = np.zeros(n_samples(0.35))
    for _ in range(10):
        p = int(r.uniform(0, len(shards) - 2000))
        shards[p:p + 1800] += glass(r.uniform(1800, 5200), 1800 / SR, seed + p)[:1800] * r.uniform(0.2, 0.6)
    return layer(sw, shards * 0.6, offsets=[0, 0.03])


@recipe("root_snare", "cast", doc="Vines snap around a target: woody creak + rustle + a tight snap.")
def root_snare(seed, variant=0, hero=None, **_):
    creak = apply(bandpass(saw(sweep(90, 160, 0.3), 0.3), 700, 4.0), env_points(0.3, [(0, 0), (0.1, 0.8), (0.3, 0)])) * 0.4
    rustle = apply(bandpass(noise(0.3, seed, "white"), 3500, 0.8), env_points(0.3, [(0, 0), (0.05, 1), (0.3, 0)])) * 0.5
    snap = click(seed + 4, 0.008, 700) + apply(lowpass(noise(0.05, seed + 5), 500, 3), exp_env(0.05, 0.012))
    return layer(creak, rustle, snap, offsets=[0, 0, 0.22])


@recipe("freeze", "cast", doc="Freeze / stun: icy crystal tick cluster + a sub thud.")
def freeze(seed, variant=0, hero=None, **_):
    r = rng(seed)
    n = n_samples(0.4)
    ice = np.zeros(n)
    for _ in range(18):
        p = int(r.uniform(0, n - 1500))
        ice[p:p + 1400] += glass(r.uniform(2500, 7000), 1400 / SR, seed + p)[:1400] * r.uniform(0.2, 0.7)
    ice = apply(ice, env_points(0.4, [(0, 1), (0.4, 0.2)]))
    th = body(90, 45, 0.2, 0.05, 1.6)
    return layer(ice * 0.7, th * 0.8)


@recipe("lift", "cast", doc="Gravity lift: rising, hollow FM tone with air rush.")
def lift(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    tn = apply(fm(sweep(semi(v, 90), semi(v, 360), 0.5), 2.0, 1.5, 0.5), env_points(0.5, [(0, 0), (0.1, 0.8), (0.45, 0.8), (0.5, 0)]))
    air = whoosh(300, 2000, 0.5, seed, 1.5, "pink", (0.6, 0.8, 0.0))
    return layer(lowpass(tn, 2500) * 0.6, air * 0.6)


@recipe("pull", "cast", doc="Pull / undertow / riptide: descending whoosh with a low suction tone.")
def pull(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    w = whoosh(3000, 250, 0.45, seed, 1.5, "pink", (0.5, 1.0, 0.0))
    tn = apply(sine(sweep(semi(v, 240), semi(v, 60), 0.45), 0.45), env_points(0.45, [(0, 0), (0.15, 0.9), (0.45, 0)]))
    return layer(w, soft_clip(tn, 1.5) * 0.7)


@recipe("anchor", "cast", doc="Harpoon anchor fires: pneumatic bang + chain rattle + cable twang.")
def anchor(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    bang = _shot(seed, variant, hero, 900, (150, 45), 0.16, 1200, 0.04, 2.0)
    r = rng(seed)
    chain = np.zeros(n_samples(0.35))
    for _ in range(12):
        p = int(r.uniform(0, len(chain) - 600))
        chain[p:p + 500] += ring(r.uniform(2000, 4000), 500 / SR, seed + p, 10)[:500] * 0.3
    chain = apply(chain, env_points(0.35, [(0, 1), (0.35, 0.2)]))
    twang = pluck(semi(v, 220), 0.35, seed, 0.4) * 0.5
    return layer(bang, chain, twang, offsets=[0, 0.03, 0.05])


@recipe("heal_pulse", "cast", doc="Warm heal pulse: soft major dyad swell with a breath.")
def heal_pulse(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    root = semi(v, 523.25)
    d = apply(sine(root, 0.45) + 0.6 * sine(root * 1.25, 0.45) + 0.4 * sine(root * 1.5, 0.45) + 0.3 * sine(root * 2, 0.45),
              env_points(0.45, [(0, 0), (0.08, 1), (0.45, 0)]))
    breath = whoosh(800, 2500, 0.4, seed, 1.0, "pink", (0.3, 0.5, 0.0))
    return layer(d * 0.6, breath * 0.3)


@recipe("cleanse_chime", "cast", doc="Cleanse: bright three-note upward chime (bell) with sparkle.")
def cleanse_chime(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    notes = [(semi(v, 1046.5), 0.0), (semi(v, 1318.5), 0.07), (semi(v, 1568), 0.14)]
    parts = [bell(f, 0.4, seed + i, 0.8) * 0.5 for i, (f, _) in enumerate(notes)]
    sparkle = apply(bandpass(noise(0.35, seed, "white"), 7000, 1.5), env_points(0.35, [(0, 0), (0.15, 0.6), (0.35, 0)])) * 0.25
    return layer(*parts, sparkle, offsets=[o for _, o in notes] + [0.0])


@recipe("buff_chime", "cast", doc="Buff: rising two-note pluck + brass swell (speed / adrenaline).")
def buff_chime(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    p1 = pluck(semi(v, 440), 0.3, seed, 0.7) * 0.6
    p2 = pluck(semi(v, 659.25), 0.35, seed + 1, 0.7) * 0.6
    sw = brass(semi(v, 220), 0.35, seed, 0.5) * 0.3
    return layer(p1, p2, sw, offsets=[0, 0.08, 0.05])


@recipe("reveal_ping", "cast", doc="Reveal / scan: sonar ping with a tail echo and a soft lantern 'bloom'.")
def reveal_ping(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    p = apply(sine(semi(v, 1568), 0.5) + 0.3 * sine(semi(v, 3136), 0.5), exp_env(0.5, 0.12))
    p = S.delay(p, 140, 0.4, 0.35, 3)
    bloom = apply(lowpass(saw(semi(v, 196), 0.5), 800), env_points(0.5, [(0, 0), (0.1, 0.5), (0.5, 0)])) * 0.3
    return layer(p * 0.7, bloom)


@recipe("chain_zap", "cast", doc="Chain lightning jump: crackle burst + descending zap tone.")
def chain_zap(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    r = rng(seed)
    n = n_samples(0.2)
    imp = np.zeros(n)
    for _ in range(50):
        p = int(r.uniform(0, n - 40))
        imp[p:p + 20] += r.uniform(-1, 1) * np.linspace(1, 0, 20)
    crackle = apply(bandpass(imp, 3500, 0.7), exp_env(0.2, 0.07))
    zap = apply(square(sweep(semi(v, 1400), semi(v, 300), 0.15), 0.15, 0.4), exp_env(0.15, 0.04))
    return soft_clip(layer(crackle, lowpass(zap, 4000) * 0.5), 1.5)


@recipe("bounce_tick", "cast", doc="Disc bounce: bright metallic tick, 70 ms.")
def bounce_tick(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    return layer(click(seed + variant, 0.003, 3000) * 0.8, ring(semi(v, 3300) * var_jitter(seed, variant, 0.08), 0.07, seed + variant, 22) * 0.9)


@recipe("focus_on", "cast", doc="Scope / focus on: breath-in noise sweep up + a faint high sustained tone.")
def focus_on(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    br = whoosh(600, 4000, 0.35, seed, 1.5, "pink", (0.8, 1.0, 0.0))
    tn = apply(sine(semi(v, 2637), 0.35), env_points(0.35, [(0, 0), (0.3, 0.25), (0.35, 0)]))
    return layer(br * 0.7, tn)


@recipe("focus_off", "cast", doc="Focus release: short exhale sweep down + soft click.")
def focus_off(seed, variant=0, hero=None, **_):
    br = whoosh(3500, 500, 0.22, seed, 1.5, "pink", (0.2, 1.0, 0.0))
    return layer(br * 0.6, click(seed, 0.004, 1500) * 0.5)


@recipe("zip_fire", "cast", doc="Zipline anchor shot: pneumatic pop + cable whip + tensioning twang.")
def zip_fire(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    pop = _shot(seed, variant, hero, 1200, (200, 70), 0.1, 2000, 0.03, 1.6, body_g=0.7)
    whip = whoosh(800, 4000, 0.25, seed + 1, 2.5, "white", (0.3, 0.9, 0.0))
    twang = pluck(semi(v, 165), 0.4, seed, 0.5) * 0.6
    return layer(pop, whip * 0.6, twang, offsets=[0, 0.03, 0.18])


@recipe("zip_end", "cast", doc="Zipline detach: cable release click + short brake hiss.")
def zip_end(seed, variant=0, hero=None, **_):
    hiss = whoosh(3000, 900, 0.25, seed, 1.5, "white", (0.1, 0.8, 0.0))
    cl = click(seed, 0.006, 1200) * 0.9
    tw = pluck(110, 0.25, seed, 0.3) * 0.4
    return layer(cl, hiss * 0.5, tw, offsets=[0, 0.01, 0.02])


@recipe("ult_cast", "cast", doc="Ultimate activation: riser + big hit + the hero's motif root note as a bloom.")
def ult_cast(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    riser = whoosh(200, 5000, 0.6, seed, 1.2, "pink", (0.95, 1.0, 0.0))
    hit = layer(sub_kick(140, 38, 0.5, 2.5), crack(seed + 2, 0.08, 1800, 0.8) * 0.6)
    f = midi_to_hz(v["root"] + 12)
    bloom = INSTRUMENTS[v["timbre"]](f, 0.9, seed, v["bright"]) * 0.6
    fifth = INSTRUMENTS[v["timbre"]](f * 1.5, 0.8, seed + 1, v["bright"]) * 0.35
    sig = layer(riser * 0.6, hit, bloom, fifth, offsets=[0.0, 0.58, 0.6, 0.62])
    return reverb(sig, 0.8, 0.25, seed, 3500)[: n_samples(1.5)]


@recipe("jet_burst", "cast", doc="Jet / afterburner burst: thrust ignition whoosh with flutter.")
def jet_burst(seed, variant=0, hero=None, **_):
    th = apply(sweep_filter(noise(0.45, seed, "pink"), "lowpass", sweep(600, 4500, 0.45), 0.8),
               env_points(0.45, [(0, 0), (0.05, 1), (0.35, 0.8), (0.45, 0)]))
    flutter = apply(sine(38, 0.45), np.ones(n_samples(0.45))) * 0.5 + 0.5
    return th * flutter


@recipe("beam_end", "cast", doc="Beam cut: descending zap with a short hum decay.")
def beam_end(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    z = apply(sine(sweep(semi(v, 900), semi(v, 200), 0.2), 0.2), exp_env(0.2, 0.06))
    hum = apply(lowpass(saw(semi(v, 110), 0.25), 700), exp_env(0.25, 0.08))
    return layer(z * 0.6, hum * 0.4, click(seed, 0.003, 2000) * 0.5)


@recipe("shroud_on", "cast", doc="Stealth on: reversed-feel airy shimmer fading to nothing.")
def shroud_on(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    sh = apply(fm(semi(v, 660), 2.5, 1.0, 0.5), env_points(0.5, [(0, 0.8), (0.5, 0)]))
    air = whoosh(4000, 800, 0.5, seed, 1.0, "pink", (0.1, 0.8, 0.0))
    return layer(lowpass(sh, 4000) * 0.4, air * 0.5)


@recipe("burn_apply", "cast", doc="Ignite: quick flame catch (noise flare) + crackle.")
def burn_apply(seed, variant=0, hero=None, **_):
    fl = apply(sweep_filter(noise(0.3, seed, "pink"), "lowpass", sweep(4000, 800, 0.3), 1.0), env_points(0.3, [(0, 0), (0.03, 1), (0.3, 0)]))
    r = rng(seed)
    n = n_samples(0.3)
    cr = np.zeros(n)
    for _ in range(25):
        p = int(r.uniform(0, n - 40))
        cr[p:p + 25] += r.uniform(-1, 1) * np.linspace(1, 0, 25)
    return layer(fl * 0.8, bandpass(cr, 3000, 0.8) * 0.5)


@recipe("generic_blip", "cast", doc="Neutral fallback: soft two-tone blip so an unmapped id is still audible and obvious.")
def generic_blip(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    a = apply(sine(semi(v, 880), 0.09), exp_env(0.09, 0.03))
    b = apply(sine(semi(v, 1174.7), 0.12), exp_env(0.12, 0.04))
    return layer(a, b, offsets=[0, 0.08])


# ======================================================================================
# LOOPS (kind loop; seamless)
# ======================================================================================
def _loopify(sig: np.ndarray, xfade_ms: float = 50.0) -> np.ndarray:
    sig = S.remove_dc(sig)
    return seamless_loop(sig, xfade_ms)


@recipe("beam_loop", "loop", loop=True, doc="Steady beam: 220 Hz sine + detuned saw, lowpassed, with shimmer and 6 Hz LFO.")
def beam_loop(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    d = 1.0
    f = semi(v, 220)
    core = sine(f, d) + 0.5 * lowpass(saw(f * 1.002, d) + saw(f * 0.998, d), 1500)
    shimmer = apply(bandpass(noise(d, seed, "white"), 5000 + 3000 * v["bright"], 3.0), 0.5 + 0.5 * S.lfo(d, 6, 1.0))
    sig = core * (0.85 + 0.15 * S.lfo(d, 6.0)) + shimmer * 0.25
    return _loopify(sig)


@recipe("zipline_loop", "loop", loop=True, doc="Zipline ride: pulley whir (rising rattle) + wind rush.")
def zipline_loop(seed, variant=0, hero=None, **_):
    d = 1.2
    whir = bandpass(S.pulse_train(46.0, d, 6), 1800, 3.0) * 0.6 + bandpass(S.pulse_train(46.0, d, 6), 900, 2.0) * 0.4
    wind = apply(bandpass(noise(d, seed, "pink"), 1200, 0.7), 0.7 + 0.3 * S.lfo(d, 3.3, 1.0, "random", seed=seed))
    return _loopify(layer(whir * 0.6, wind * 0.9))


@recipe("flight_jets", "loop", loop=True, doc="Jet-rig flight: filtered noise thrust + 90 Hz turbine hum + flutter.")
def flight_jets(seed, variant=0, hero=None, **_):
    d = 1.5
    thrust = lowpass(noise(d, seed, "pink"), 2200, 0.8)
    hum = lowpass(saw(92.0, d) + 0.5 * saw(184.0, d), 600)
    flutter = 0.8 + 0.2 * S.lfo(d, 27.0)
    sig = layer(thrust * 0.8, hum * 0.5) * flutter
    k = ken("sci-fi-sounds", "thrusterFire_002", -10, 0, 150, 5000, d, trim_head=False)
    if k is not None:
        sig = layer(sig, k[: n_samples(d)] * 0.7)
    return _loopify(sig, 80)


@recipe("aura_beat", "loop", loop=True, doc="120 bpm aura: kick + hat pulse (0.5 s loop) with a warm sub hum.")
def aura_beat(seed, variant=0, hero=None, **_):
    d = 0.5
    kick = sub_kick(120, 45, 0.2, 2.0)
    hat = apply(highpass(noise(0.05, seed), 7000), exp_env(0.05, 0.012)) * 0.35
    hum = sine(55.0, d) * 0.35
    sig = layer(hum, kick * 0.8, hat, offsets=[0.0, 0.0, 0.25])[: n_samples(d)]
    return _loopify(sig, 20)


@recipe("meltdown", "loop", loop=True, doc="Meltdown: fire crackle + low furnace roar + metal stress.")
def meltdown(seed, variant=0, hero=None, **_):
    d = 1.6
    roar = lowpass(noise(d, seed, "brown"), 300) * 1.2
    r = rng(seed)
    n = n_samples(d)
    cr = np.zeros(n)
    for _ in range(140):
        p = int(r.uniform(0, n - 60))
        cr[p:p + 40] += r.uniform(-1, 1) * np.linspace(1, 0, 40)
    crackle = bandpass(cr, 2800, 0.7) * 0.5
    stress = apply(bandpass(noise(d, seed + 3), 1300, 12), S.lfo(d, 0.6, 1.0, "random", seed=seed)) * 0.3
    return _loopify(layer(roar, crackle, stress), 80)


@recipe("ult_loop", "loop", loop=True, doc="Ultimate active: warm pad on the hero's motif root + slow pulse.")
def ult_loop(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    d = 2.0
    f = midi_to_hz(v["root"])
    p = pad_note(f, d, seed, 0.3 + 0.4 * v["bright"], 0.01)
    p5 = pad_note(f * 1.5, d, seed + 1, 0.3, 0.01) * 0.5
    pulse = 0.75 + 0.25 * S.lfo(d, 1.0)
    shimmer = apply(bandpass(noise(d, seed, "white"), 6000, 2.0), S.lfo(d, 2.0)) * 0.15
    return _loopify(layer(p, p5, shimmer) * pulse, 120)


@recipe("ability_loop", "loop", loop=True, doc="Generic active-ability hum: soft filtered saw with slow motion.")
def ability_loop(seed, variant=0, hero=None, **_):
    v = hero_voice(hero)
    d = 1.5
    f = semi(v, 130.8)
    sig = lowpass(saw(f, d) + saw(f * 1.004, d), 900) * 0.6 + sine(f * 0.5, d) * 0.3
    return _loopify(sig * (0.85 + 0.15 * S.lfo(d, 2.0)), 100)


@recipe("shroud_loop", "loop", loop=True, doc="Stealth active: near-silent airy shimmer.")
def shroud_loop(seed, variant=0, hero=None, **_):
    d = 2.0
    air = bandpass(noise(d, seed, "pink"), 3000, 1.0) * 0.5
    sh = fm(660.0, 2.5, 0.8, d) * 0.15
    return _loopify(layer(air, sh) * (0.7 + 0.3 * S.lfo(d, 0.5)), 150)


@recipe("capacitor_loop", "loop", loop=True, doc="Capacitor charging: rising electrical hum with crackle ticks.")
def capacitor_loop(seed, variant=0, hero=None, **_):
    d = 1.5
    hum = lowpass(square(60.0, d, 0.5), 400) * 0.5 + sine(120.0, d) * 0.3
    r = rng(seed)
    n = n_samples(d)
    tk = np.zeros(n)
    for _ in range(30):
        p = int(r.uniform(0, n - 30))
        tk[p:p + 20] += r.uniform(-1, 1) * np.linspace(1, 0, 20)
    return _loopify(layer(hum, bandpass(tk, 4000, 1.0) * 0.4), 60)


@recipe("density_loop", "loop", loop=True, doc="Density active: heavy sub throb + slow metallic drone.")
def density_loop(seed, variant=0, hero=None, **_):
    d = 2.0
    sub = sine(41.0, d) * (0.7 + 0.3 * S.lfo(d, 1.5))
    drone = bandpass(noise(d, seed, "brown"), 220, 6.0) * 0.6
    return _loopify(layer(sub * 0.8, drone), 120)


# ======================================================================================
# IMPACTS (kind impact)
# ======================================================================================
def _impact(seed, variant, thud=(160, 50, 0.12), crack_fc=2500, crack_dur=0.03, extra=None, drive=1.4, dur=0.2):
    parts = [click(seed + variant, 0.003, 1500) * 0.7,
             crack(seed + variant + 3, crack_dur, crack_fc * var_jitter(seed, variant, 0.1), 1.0) * 0.8,
             body(thud[0] * var_jitter(seed, variant, 0.05), thud[1], thud[2], thud[2] / 3, drive)]
    if extra is not None:
        parts.append(extra)
    return S.limit_len(soft_clip(layer(*parts), 1.2), dur, 15)


@recipe("impact_generic", "impact", 3, doc="Bullet on surface: click + crack + short thud (Kenney generic light impact layered).")
def impact_generic(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactGeneric_light_", variant, 5, gain_db=-6, hp=300, max_dur=0.16)
    return _impact(seed, variant, extra=k, dur=0.16)


@recipe("impact_flesh", "impact", 3, doc="Body hit: soft wet thud, low crack, no ring (Kenney soft impact layered).")
def impact_flesh(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactSoft_medium_", variant, 5, gain_db=-8, lp=3000, max_dur=0.15)
    return _impact(seed, variant, thud=(130, 45, 0.11), crack_fc=900, crack_dur=0.04, extra=k, dur=0.15)


@recipe("impact_barrier", "impact", 3, doc="Energy barrier hit: glassy ping + electric fizz, higher pitch than body hits.")
def impact_barrier(seed, variant=0, **_):
    f = 2200 * var_jitter(seed, variant, 0.1)
    ping_ = glass(f, 0.18, seed + variant) * 0.7
    fizz = apply(bandpass(noise(0.12, seed + variant), 6000, 1.0), exp_env(0.12, 0.03)) * 0.4
    return _impact(seed, variant, thud=(200, 90, 0.06), crack_fc=4000, extra=layer(ping_, fizz), dur=0.2)


@recipe("impact_bolt", "impact", 3, doc="Energy bolt hit: zap fizz + small thud.")
def impact_bolt(seed, variant=0, **_):
    z = apply(sine(sweep(1500, 400, 0.08), 0.08), exp_env(0.08, 0.025)) * 0.5
    return _impact(seed, variant, thud=(170, 60, 0.1), crack_fc=3500, extra=z, dur=0.16)


@recipe("impact_orb", "impact", 3, doc="Orb burst: soft splash of FM shimmer + round thud.")
def impact_orb(seed, variant=0, **_):
    sh = apply(fm(700 * var_jitter(seed, variant, 0.1), 1.5, 2.0, 0.2), exp_env(0.2, 0.06)) * 0.5
    return _impact(seed, variant, thud=(140, 50, 0.14), crack_fc=1500, extra=sh, dur=0.22)


@recipe("impact_disc", "impact", 3, doc="Disc hit: metallic clang + short ring.")
def impact_disc(seed, variant=0, **_):
    r = ring(2900 * var_jitter(seed, variant, 0.1), 0.18, seed + variant, 25) * 0.8
    k = ken_pick("impact-sounds", "impactMetal_light_", variant, 5, gain_db=-8, hp=500, max_dur=0.2)
    return _impact(seed, variant, thud=(220, 90, 0.08), crack_fc=4500, extra=layer(r, k) if k is not None else r, dur=0.22)


@recipe("impact_shell", "impact", 3, doc="Shell burst: small explosion, mid crunch.")
def impact_shell(seed, variant=0, **_):
    boom = apply(lowpass(noise(0.3, seed + variant, "pink"), 1200), exp_env(0.3, 0.08)) * 0.9
    return _impact(seed, variant, thud=(120, 40, 0.28), crack_fc=1800, crack_dur=0.06, extra=boom, drive=2.0, dur=0.35)


@recipe("impact_mortar", "impact", 3, doc="Mortar shell landing: deep boom + debris crackle (Kenney explosion crunch layered).")
def impact_mortar(seed, variant=0, **_):
    k = ken_pick("sci-fi-sounds", "explosionCrunch_", variant, 5, gain_db=-8, max_dur=0.45)
    boom = apply(lowpass(noise(0.45, seed + variant, "brown"), 500), exp_env(0.45, 0.12)) * 1.2
    return _impact(seed, variant, thud=(100, 32, 0.4), crack_fc=1200, crack_dur=0.08, extra=layer(boom, k) if k is not None else boom, drive=2.4, dur=0.48)


@recipe("impact_needle", "impact", 3, doc="Needle hit: tiny high tick + pin ring.")
def impact_needle(seed, variant=0, **_):
    r = ring(5200 * var_jitter(seed, variant, 0.1), 0.06, seed + variant, 30) * 0.7
    return _impact(seed, variant, thud=(260, 120, 0.05), crack_fc=5000, crack_dur=0.015, extra=r, dur=0.09)


@recipe("impact_thorn", "impact", 3, doc="Thorn hit: woody knock + brittle snap.")
def impact_thorn(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactWood_light_", variant, 5, gain_db=-8, hp=300, max_dur=0.15)
    return _impact(seed, variant, thud=(210, 90, 0.08), crack_fc=3000, extra=k, dur=0.15)


@recipe("impact_candle", "impact", 3, doc="Lantern lands: glass tink + soft ignition puff.")
def impact_candle(seed, variant=0, **_):
    tink = glass(3400 * var_jitter(seed, variant, 0.1), 0.2, seed + variant) * 0.6
    puff = apply(lowpass(noise(0.15, seed + variant, "pink"), 1500), env_points(0.15, [(0, 0), (0.02, 0.6), (0.15, 0)])) * 0.5
    return _impact(seed, variant, thud=(150, 70, 0.08), crack_fc=2000, extra=layer(tink, puff), dur=0.22)


@recipe("impact_harpoon", "impact", 3, doc="Harpoon strikes: heavy metal clank + chain settle.")
def impact_harpoon(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactMetal_heavy_", variant, 5, gain_db=-6, hp=200, max_dur=0.25)
    r = ring(1500 * var_jitter(seed, variant, 0.1), 0.2, seed + variant, 15) * 0.5
    return _impact(seed, variant, thud=(140, 50, 0.16), crack_fc=2500, extra=layer(r, k) if k is not None else r, drive=1.8, dur=0.28)


@recipe("impact_spear", "impact", 3, doc="Spear hit: sharp thunk with a short shaft vibration.")
def impact_spear(seed, variant=0, **_):
    vib = apply(sine(180 * var_jitter(seed, variant, 0.1), 0.18), exp_env(0.18, 0.05)) * 0.4
    return _impact(seed, variant, thud=(180, 70, 0.1), crack_fc=2200, extra=vib, dur=0.2)


@recipe("impact_plasma", "impact", 3, doc="Plasma splash: sizzling hiss + FM bloom.")
def impact_plasma(seed, variant=0, **_):
    hiss = apply(bandpass(noise(0.22, seed + variant), 4500, 0.7), exp_env(0.22, 0.07)) * 0.6
    bloom = apply(fm(400 * var_jitter(seed, variant, 0.1), 2.0, 3.0, 0.18), exp_env(0.18, 0.05)) * 0.4
    return _impact(seed, variant, thud=(150, 55, 0.14), crack_fc=3000, extra=layer(hiss, bloom), dur=0.24)


@recipe("impact_flare", "impact", 3, doc="Flare lands: bright pop + sparkle fizz.")
def impact_flare(seed, variant=0, **_):
    fizz = apply(bandpass(noise(0.25, seed + variant), 7000, 1.0), env_points(0.25, [(0, 0.8), (0.25, 0)])) * 0.5
    return _impact(seed, variant, thud=(200, 80, 0.08), crack_fc=3500, extra=fizz, dur=0.26)


@recipe("impact_grenade", "impact", 3, doc="Grenade detonation: explosion_small at the impact point.")
def impact_grenade(seed, variant=0, **_):
    return explosion_small(seed + 100, variant)


@recipe("explosion_small", "impact", 3, doc="Small explosion: sub boom + crunch burst + debris (Kenney crunch layered).")
def explosion_small(seed, variant=0, **_):
    k = ken_pick("sci-fi-sounds", "explosionCrunch_", variant, 5, gain_db=-7, max_dur=0.5)
    boom = sub_kick(110, 35, 0.45, 3.0)
    crunch = apply(sweep_filter(noise(0.4, seed + variant, "white"), "lowpass", sweep(6000, 500, 0.4), 0.8), exp_env(0.4, 0.1))
    sig = layer(click(seed, 0.004, 1000), boom * 1.2, crunch * 0.9, *( [k * 0.8] if k is not None else []))
    return S.limit_len(soft_clip(sig, 1.5), 0.5, 20)


@recipe("explosion_large", "impact", 2, doc="Large explosion: long sub + wide crunch + rumble tail (Kenney low-frequency explosion layered).")
def explosion_large(seed, variant=0, **_):
    k = ken("sci-fi-sounds", f"lowFrequency_explosion_00{variant % 2}", -6, 0, None, 4000, 0.5)
    boom = sub_kick(90, 28, 0.5, 3.5)
    crunch = apply(sweep_filter(noise(0.5, seed + variant, "white"), "lowpass", sweep(5000, 300, 0.5), 0.8), exp_env(0.5, 0.14))
    sig = layer(click(seed, 0.005, 800), boom * 1.3, crunch, *([k * 0.9] if k is not None else []))
    return S.limit_len(soft_clip(sig, 1.8), 0.5, 30)


@recipe("melee_hit", "impact", 3, doc="Quick melee connects: punchy thud + short slap (Kenney punch layered).")
def melee_hit(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactPunch_medium_", variant, 5, gain_db=-8, lp=4000, max_dur=0.18)
    return _impact(seed, variant, thud=(150, 55, 0.12), crack_fc=1200, crack_dur=0.03, extra=k, drive=1.8, dur=0.18)


@recipe("deploy_break", "impact", 3, doc="Deployable destroyed: metal plate crash + electric fizz (Kenney plate impact layered).")
def deploy_break(seed, variant=0, **_):
    k = ken_pick("impact-sounds", "impactPlate_heavy_", variant, 5, gain_db=-6, hp=150, max_dur=0.4)
    fizz = apply(bandpass(noise(0.3, seed + variant), 5000, 0.8), exp_env(0.3, 0.08)) * 0.4
    return _impact(seed, variant, thud=(130, 45, 0.2), crack_fc=2000, crack_dur=0.05, extra=layer(fizz, k) if k is not None else fizz, drive=1.7, dur=0.42)


# ======================================================================================
# LAUNCH (projectile spawn cues; subtle, < 200 ms)
# ======================================================================================
def _launch(seed, variant, f0, f1, dur, q=1.5, color="white", tone_f=None, extra=None):
    w = whoosh(f0, f1, dur, seed + variant, q, color, (0.2, 1.0, 0.0))
    parts = [w]
    if tone_f:
        parts.append(apply(sine(sweep(tone_f, tone_f * 0.6, dur), dur), exp_env(dur, dur / 3)) * 0.4)
    if extra is not None:
        parts.append(extra)
    return soft_clip(layer(*parts), 1.1)


@recipe("launch_bolt", "cast", 2, doc="Bolt leaves: quick 'pew' whoosh.")
def launch_bolt(seed, variant=0, **_):
    return _launch(seed, variant, 1200, 3500, 0.1, 2.0, tone_f=1400)


@recipe("launch_orb", "cast", 2, doc="Orb leaves: round, soft whoosh with FM wobble.")
def launch_orb(seed, variant=0, **_):
    wob = apply(fm(500, 0.5, 2.0, 0.16), exp_env(0.16, 0.05)) * 0.4
    return _launch(seed, variant, 400, 1600, 0.16, 1.2, "pink", extra=wob)


@recipe("launch_disc", "cast", 2, doc="Disc leaves: spinning metallic whir.")
def launch_disc(seed, variant=0, **_):
    whir = apply(bandpass(S.pulse_train(60.0, 0.15, 5), 2500, 4.0), exp_env(0.15, 0.05)) * 0.5
    return _launch(seed, variant, 800, 3000, 0.15, 2.0, extra=whir)


@recipe("launch_shell", "cast", 2, doc="Shell leaves: short puff.")
def launch_shell(seed, variant=0, **_):
    return _launch(seed, variant, 600, 250, 0.12, 1.0, "pink")


@recipe("launch_mortar", "cast", 2, doc="Mortar shell leaves: hollow 'toonk'.")
def launch_mortar(seed, variant=0, **_):
    return _launch(seed, variant, 500, 200, 0.16, 1.5, "pink", tone_f=320)


@recipe("launch_needle", "cast", 2, doc="Needle leaves: tiny zip.")
def launch_needle(seed, variant=0, **_):
    return _launch(seed, variant, 3000, 6000, 0.06, 3.0, tone_f=3200)


@recipe("launch_thorn", "cast", 2, doc="Thorn leaves: organic thwip.")
def launch_thorn(seed, variant=0, **_):
    return _launch(seed, variant, 2200, 500, 0.08, 2.5)


@recipe("launch_candle", "cast", 2, doc="Lantern thrown: soft whoosh + faint glass.")
def launch_candle(seed, variant=0, **_):
    g = glass(2800, 0.12, seed + variant) * 0.25
    return _launch(seed, variant, 400, 1500, 0.15, 1.5, "pink", extra=g)


@recipe("launch_harpoon", "cast", 2, doc="Harpoon leaves: cable zip.")
def launch_harpoon(seed, variant=0, **_):
    z = apply(bandpass(S.pulse_train(120.0, 0.15, 4), 3000, 3.0), exp_env(0.15, 0.06)) * 0.4
    return _launch(seed, variant, 900, 3500, 0.15, 2.0, extra=z)


@recipe("launch_spear", "cast", 2, doc="Spear leaves: sharp whoosh.")
def launch_spear(seed, variant=0, **_):
    return _launch(seed, variant, 700, 3200, 0.14, 2.5)


@recipe("launch_plasma", "cast", 2, doc="Plasma leaves: sizzling pew.")
def launch_plasma(seed, variant=0, **_):
    sz = apply(bandpass(noise(0.12, seed + 9), 5000, 0.8), exp_env(0.12, 0.04)) * 0.4
    return _launch(seed, variant, 900, 2500, 0.12, 1.5, tone_f=900, extra=sz)


@recipe("launch_flare", "cast", 2, doc="Flare leaves: bright pop + hiss.")
def launch_flare(seed, variant=0, **_):
    return _launch(seed, variant, 2000, 6000, 0.14, 1.0, extra=click(seed + variant, 0.004, 2000) * 0.6)


@recipe("launch_grenade", "cast", 2, doc="Grenade leaves: pin click + short toss whoosh.")
def launch_grenade(seed, variant=0, **_):
    return _launch(seed, variant, 500, 1800, 0.14, 1.5, "pink", extra=click(seed + variant, 0.006, 1200) * 0.7)


# ======================================================================================
# UI (kind ui: < 250 ms)
# ======================================================================================
@recipe("hitmarker", "ui", doc="Body hit confirm: 2.4 kHz tick, 45 ms.")
def hitmarker(seed, variant=0, **_):
    return layer(click(seed, 0.002, 3000) * 0.6, apply(sine(2400, 0.045), exp_env(0.045, 0.012)))


@recipe("hitmarker_head", "ui", doc="Headshot confirm: brighter two-tone tick (3.2k -> 4.2k), 60 ms.")
def hitmarker_head(seed, variant=0, **_):
    a = apply(sine(3200, 0.03), exp_env(0.03, 0.01))
    b = apply(sine(4200, 0.04), exp_env(0.04, 0.012))
    return layer(click(seed, 0.002, 4000) * 0.5, a, b, offsets=[0, 0, 0.022])


@recipe("hitmarker_kill", "ui", doc="Kill confirm tick: tick + low thud + short shimmer, 120 ms.")
def hitmarker_kill(seed, variant=0, **_):
    t = apply(sine(2000, 0.04), exp_env(0.04, 0.012))
    th = body(160, 60, 0.09, 0.03, 1.5) * 0.7
    sh = apply(bandpass(noise(0.1, seed), 6000, 2.0), exp_env(0.1, 0.03)) * 0.3
    return layer(click(seed, 0.002, 3000) * 0.5, t, th, sh)


@recipe("kill_confirm", "ui", doc="Elimination chime: two rising bell notes E5 -> B5, 240 ms.")
def kill_confirm(seed, variant=0, **_):
    a = bell(659.25, 0.2, seed, 0.7) * 0.6
    b = bell(987.77, 0.18, seed + 1, 0.7) * 0.6
    return S.limit_len(layer(a, b, offsets=[0, 0.06]), 0.24, 20)


@recipe("ally_down", "ui", doc="Ally eliminated: two soft descending notes, darker, 240 ms.")
def ally_down(seed, variant=0, **_):
    a = glass(587.33, 0.14, seed) * 0.5
    b = glass(440.0, 0.16, seed + 1) * 0.5
    return S.limit_len(lowpass(layer(a, b, offsets=[0, 0.08]), 3000), 0.24, 20)


def _ken_ui(name, fallback, gain=-3, max_dur=0.24):
    k = ken("interface-sounds", name, gain, 0, 200, None, max_dur)
    return k if k is not None else fallback


@recipe("ui_click", "ui", doc="Menu click (Kenney interface click_001).")
def ui_click(seed, variant=0, **_):
    return _ken_ui("click_001", layer(click(seed, 0.004, 1500), apply(sine(1200, 0.04), exp_env(0.04, 0.012)) * 0.6))


@recipe("ui_hover", "ui", doc="Menu hover (Kenney ui rollover2).")
def ui_hover(seed, variant=0, **_):
    k = ken("ui-audio", "rollover2", -6, 0, 300, None, 0.1)
    return k if k is not None else apply(sine(1800, 0.05), exp_env(0.05, 0.015)) * 0.5


@recipe("ui_back", "ui", doc="Menu back (Kenney interface back_002).")
def ui_back(seed, variant=0, **_):
    return _ken_ui("back_002", layer(apply(sine(900, 0.06), exp_env(0.06, 0.02)), apply(sine(600, 0.08), exp_env(0.08, 0.025)), offsets=[0, 0.04]))


@recipe("ui_confirm", "ui", doc="Menu confirm (Kenney interface confirmation_001, trimmed to 240 ms).")
def ui_confirm(seed, variant=0, **_):
    return _ken_ui("confirmation_001", layer(bell(880, 0.12, seed), bell(1320, 0.14, seed + 1), offsets=[0, 0.06]) * 0.6)


@recipe("notification", "ui", doc="Soft notification: two-note blip C6 -> E6, 200 ms.")
def notification(seed, variant=0, **_):
    a = apply(sine(1046.5, 0.1) + 0.3 * sine(2093, 0.1), exp_env(0.1, 0.035))
    b = apply(sine(1318.5, 0.12) + 0.3 * sine(2637, 0.12), exp_env(0.12, 0.04))
    return layer(a, b, offsets=[0, 0.08]) * 0.8


@recipe("ping", "ui", doc="World ping: sonar 1.6 kHz ping with a tiny echo, 220 ms.")
def ping(seed, variant=0, **_):
    p = apply(sine(1568, 0.14) + 0.25 * sine(3136, 0.14), exp_env(0.14, 0.04))
    return S.limit_len(S.delay(p, 70, 0.4, 0.3, 2), 0.22, 20)


@recipe("health_pack", "ui", doc="Health pickup: three-note ascending warm glissando, 240 ms.")
def health_pack(seed, variant=0, **_):
    ns = [(523.25, 0.0), (659.25, 0.06), (783.99, 0.12)]
    parts = [apply(sine(f, 0.13) + 0.4 * sine(f * 2, 0.13), exp_env(0.13, 0.04)) * 0.6 for f, _ in ns]
    return S.limit_len(layer(*parts, offsets=[o for _, o in ns]), 0.24, 20)


@recipe("ult_ready", "ui", doc="Ultimate ready: rising shimmer chord (bell A4+E5+A5), 240 ms.")
def ult_ready(seed, variant=0, **_):
    c = layer(bell(440, 0.24, seed, 0.8), bell(659.25, 0.22, seed + 1, 0.8), bell(880, 0.2, seed + 2, 0.8), offsets=[0, 0.03, 0.06]) * 0.4
    sh = apply(bandpass(noise(0.2, seed), 7000, 1.5), env_points(0.2, [(0, 0), (0.1, 0.5), (0.2, 0)])) * 0.25
    return S.limit_len(layer(c, sh), 0.24, 20)


@recipe("respawn", "ui", doc="Respawn: rising sweep + soft major chord, 240 ms.")
def respawn(seed, variant=0, **_):
    sw = apply(sine(sweep(300, 1200, 0.2), 0.2), env_points(0.2, [(0, 0), (0.05, 0.7), (0.2, 0)])) * 0.5
    c = chord([69, 73, 76], 0.2, "glass", seed, 0.6, 0.6)
    return S.limit_len(layer(sw, c, offsets=[0, 0.05]), 0.24, 20)


@recipe("bounce", "ui", doc="Projectile bounce: metallic tick, 70 ms (3D, generic).")
def bounce(seed, variant=0, **_):
    return bounce_tick(seed, variant)


@recipe("blink", "ui", doc="Teleport arrival ping: short fold-in shimmer, 220 ms.")
def blink(seed, variant=0, **_):
    sh = apply(fm(sweep(1600, 400, 0.18), 1.5, 2.0, 0.18), exp_env(0.18, 0.06)) * 0.6
    return S.limit_len(layer(sh, click(seed, 0.003, 2500) * 0.5, body(120, 50, 0.1, 0.03, 1.4) * 0.6), 0.22, 20)


# ======================================================================================
# ANNOUNCER (kind stinger) — non-verbal musical stings with a shared "radio" family sound
# ======================================================================================
def _radio_open(seed):
    return layer(click(seed, 0.004, 2500) * 0.5, apply(bandpass(noise(0.05, seed), 2500, 1.0), exp_env(0.05, 0.015)) * 0.3)


def _sting(seed, notes_midi, beats, bpm, inst="bell", chord_midis=None, bright=0.7, chord_inst="pad", dur_cap=3.0, gain=0.8, reverb_mix=0.25):
    mel = play_notes(list(zip(notes_midi, beats)), bpm, inst, seed, bright, gain, 2.0)
    parts = [_radio_open(seed), mel]
    offs = [0.0, 0.02]
    if chord_midis:
        parts.append(chord(chord_midis, min(dur_cap, len(mel) / SR), chord_inst, seed + 50, 0.4, 0.5, 0.05))
        offs.append(0.02)
    sig = layer(*parts, offsets=offs)
    sig = reverb(sig, 0.9, reverb_mix, seed, 4000)
    return S.trim_tail(S.limit_len(sig, dur_cap, 60), -50, 60)


@recipe("announce_round_start", "stinger", doc="Round start: D major rising two notes + bright pad hit.")
def announce_round_start(seed, variant=0, **_):
    return _sting(seed, [74, 81], [0.5, 1.5], 120, "bell", [62, 66, 69, 74], dur_cap=1.8)


@recipe("announce_live", "stinger", doc="Objective live: quick ascending E-G-B staccato + snare-ish hit.")
def announce_live(seed, variant=0, **_):
    s = _sting(seed, [76, 79, 83], [0.25, 0.25, 1.0], 140, "pluck", None, dur_cap=1.2)
    hit = apply(bandpass(noise(0.12, seed), 1800, 0.7), exp_env(0.12, 0.03)) * 0.5
    return layer(s, hit, offsets=[0, 0.02 + 0.5 * 60 / 140])


@recipe("announce_capture_friendly", "stinger", doc="Point captured (yours): C-E-G-C bell arpeggio, warm.")
def announce_capture_friendly(seed, variant=0, **_):
    return _sting(seed, [72, 76, 79, 84], [0.25, 0.25, 0.25, 1.5], 132, "bell", [60, 64, 67, 72], dur_cap=1.8)


@recipe("announce_capture_enemy", "stinger", doc="Point captured (theirs): same contour, minor and descending, darker timbre.")
def announce_capture_enemy(seed, variant=0, **_):
    s = _sting(seed, [72, 68, 63, 60], [0.25, 0.25, 0.25, 1.5], 132, "glass", [48, 51, 55], chord_inst="pad", bright=0.3, dur_cap=1.8)
    return lowpass(s, 3500)


@recipe("announce_unlocked", "stinger", doc="Point unlocked: sus4 -> major swell (brass) with an upward sweep.")
def announce_unlocked(seed, variant=0, **_):
    sus = chord([62, 67, 69], 0.6, "brass", seed, 0.5, 0.5)
    maj = chord([62, 66, 69, 74], 0.9, "brass", seed + 3, 0.6, 0.5)
    sw = whoosh(300, 3000, 0.5, seed, 1.5, "pink", (0.9, 0.6, 0.0))
    sig = layer(_radio_open(seed), sw * 0.4, sus, maj, offsets=[0, 0, 0.05, 0.55])
    return S.trim_tail(reverb(sig, 0.8, 0.25, seed), -50, 60)


@recipe("announce_checkpoint", "stinger", doc="Checkpoint: two-note brass stamp G -> C.")
def announce_checkpoint(seed, variant=0, **_):
    return _sting(seed, [67, 72], [0.35, 1.0], 120, "brass", [48, 55, 60], bright=0.5, dur_cap=1.3)


@recipe("announce_overtime", "stinger", doc="Overtime: tense accelerating low pulse (D) with a tritone stab (G#).")
def announce_overtime(seed, variant=0, **_):
    parts, offs = [_radio_open(seed)], [0.0]
    t = 0.05
    gap = 0.3
    for i in range(8):
        parts.append(lowpass(apply(saw(73.4, 0.18), exp_env(0.18, 0.05)), 900) * 0.7)
        offs.append(t)
        t += gap
        gap *= 0.82
    stab = chord([62, 68, 74], 0.9, "brass", seed, 0.6, 0.6)
    parts.append(stab)
    offs.append(t)
    sig = layer(*parts, offsets=offs)
    return S.trim_tail(reverb(sig, 0.7, 0.2, seed), -50, 60)


@recipe("announce_round_end", "stinger", doc="Round end: descending V -> I cadence, A-F#-D with pad.")
def announce_round_end(seed, variant=0, **_):
    return _sting(seed, [81, 78, 74], [0.4, 0.4, 1.5], 110, "bell", [50, 57, 62, 66], dur_cap=2.2)


@recipe("announce_victory", "stinger", doc="Victory: rising D major fanfare D-F#-A-D + bright chord (brass + bell).")
def announce_victory(seed, variant=0, **_):
    mel = _sting(seed, [62, 66, 69, 74], [0.3, 0.3, 0.3, 2.0], 126, "brass", [62, 66, 69, 74, 78], bright=0.7, dur_cap=2.8)
    bells = play_notes([(74, 0.3), (78, 0.3), (81, 0.3), (86, 2.0)], 126, "bell", seed + 9, 0.8, 0.4, 2.0)
    return S.trim_tail(layer(mel, bells, offsets=[0, 0.02]), -50, 60)


@recipe("announce_defeat", "stinger", doc="Defeat: descending D minor D-A-F-D, low pad, slow.")
def announce_defeat(seed, variant=0, **_):
    s = _sting(seed, [74, 69, 65, 62], [0.5, 0.5, 0.5, 2.0], 96, "choir", [50, 53, 57, 62], bright=0.3, chord_inst="pad", dur_cap=3.0)
    return lowpass(s, 3000)


@recipe("announce_draw", "stinger", doc="Draw: two equal notes on a neutral sus2 chord.")
def announce_draw(seed, variant=0, **_):
    return _sting(seed, [69, 69], [0.5, 1.5], 110, "glass", [62, 64, 69], bright=0.5, dur_cap=2.0)


@recipe("announce_generic", "stinger", doc="Generic announcer chime: single bell + radio open.")
def announce_generic(seed, variant=0, **_):
    return _sting(seed, [76], [1.0], 120, "bell", None, dur_cap=0.9)


# ======================================================================================
# FOOTSTEPS (kind footstep: 60-120 ms), body sounds, movement
# ======================================================================================
KEN_SURFACE = {"concrete": "footstep_concrete_", "wood": "footstep_wood_", "snow": "footstep_snow_",
               "grass": "footstep_grass_", "carpet": "footstep_carpet_", "metal": "footstep_concrete_"}


def _synth_step(seed, variant, weight):
    f0 = {"light": 260, "medium": 190, "heavy": 130}[weight]
    dur = {"light": 0.07, "medium": 0.09, "heavy": 0.11}[weight]
    th = body(f0 * var_jitter(seed, variant, 0.1), f0 * 0.4, dur, dur / 3.5, 1.4)
    scuff = apply(bandpass(noise(dur, seed + variant), 1500 + 1500 * (weight == "light"), 0.7), exp_env(dur, dur / 4))
    return layer(click(seed + variant, 0.003, 1200) * 0.5, th, scuff * 0.7)


def footstep(seed: int, variant: int, weight: str = "medium", surface: str = "concrete") -> np.ndarray:
    pitch = {"light": 3.0, "medium": 0.0, "heavy": -2.0}[weight]
    hp = {"light": 400, "medium": 150, "heavy": 60}[weight]
    dur = {"light": 0.08, "medium": 0.1, "heavy": 0.12}[weight]
    prefix = KEN_SURFACE.get(surface, "footstep_concrete_")
    k = ken_pick("impact-sounds", prefix, variant, 5, gain_db=0, semitones=pitch, hp=hp, max_dur=dur)
    if k is None:
        sig = _synth_step(seed, variant, weight)
    else:
        sig = k
        if weight == "heavy":
            sig = layer(sig, body(90, 45, 0.1, 0.03, 1.5) * 0.7)
        if weight == "light":
            sig = sig * 0.8
    if surface == "metal":
        sig = layer(sig, ring(1900 * var_jitter(seed, variant, 0.1), 0.09, seed + variant, 18) * 0.35,
                    ring(3400, 0.06, seed + 3, 22) * 0.2)
    return S.limit_len(sig, dur, 15)


for _w in ("light", "medium", "heavy"):
    for _s in ("concrete", "metal", "wood", "grass", "snow", "carpet"):
        _name = f"boots_{_w}" if _s == "concrete" else f"boots_{_w}_{_s}"

        def _mk(w=_w, s=_s):
            def fn(seed, variant=0, **_):
                return footstep(seed, variant, w, s)
            fn.__doc__ = f"{w} boots on {s} (Kenney footstep recordings, pitched/EQ'd per weight)."
            return fn

        recipe(_name, "footstep", 4)(_mk())


@recipe("jump_generic", "cast", 2, doc="Jump: short cloth whoosh + gear jingle, 110 ms.")
def jump_generic(seed, variant=0, **_):
    w = whoosh(500, 1800, 0.11, seed + variant, 2.0, "pink", (0.4, 1.0, 0.0))
    j = ring(3200, 0.05, seed + variant, 15) * 0.2
    return layer(w, j)


@recipe("land_generic", "impact", 2, doc="Landing thud: 90->45 Hz body + short scuff, 130 ms.")
def land_generic(seed, variant=0, **_):
    th = body(95 * var_jitter(seed, variant, 0.08), 45, 0.12, 0.035, 1.8)
    sc = apply(bandpass(noise(0.1, seed + variant), 1200, 0.8), exp_env(0.1, 0.03)) * 0.5
    k = ken_pick("impact-sounds", "footstep_concrete_", variant, 5, gain_db=-4, semitones=-3, max_dur=0.12)
    return layer(th, sc, *([k] if k is not None else []))


@recipe("hurt_generic", "voice", 2, doc="Non-vocal hurt: chest thump + short exhale-like noise burst, 220 ms.")
def hurt_generic(seed, variant=0, **_):
    th = body(140 * var_jitter(seed, variant, 0.1), 60, 0.09, 0.03, 1.6)
    ex = whoosh(1600, 500, 0.18, seed + variant, 1.2, "pink", (0.15, 1.0, 0.0))
    ex = bandpass(ex, 1000, 0.8) + ex * 0.5
    return layer(th * 0.8, ex * 0.8, offsets=[0, 0.02])


@recipe("death_generic", "voice", 2, doc="Non-vocal death: heavier thump + long descending exhale + low tone drop, 600 ms.")
def death_generic(seed, variant=0, **_):
    th = body(110 * var_jitter(seed, variant, 0.08), 40, 0.25, 0.07, 2.0)
    ex = whoosh(1400, 300, 0.5, seed + variant, 1.0, "pink", (0.1, 1.0, 0.0))
    drop = apply(sine(sweep(220, 70, 0.5), 0.5), env_points(0.5, [(0, 0.5), (0.5, 0)])) * 0.4
    return layer(th, ex * 0.7, lowpass(drop, 800), offsets=[0, 0.03, 0.05])


@recipe("spawn_generic", "cast", doc="Spawn in: rising shimmer sweep + soft chord bloom, 500 ms.")
def spawn_generic(seed, variant=0, **_):
    sw = apply(sine(sweep(300, 1400, 0.4), 0.4), env_points(0.4, [(0, 0), (0.1, 0.6), (0.4, 0)])) * 0.5
    air = whoosh(500, 4000, 0.45, seed, 1.5, "pink", (0.6, 0.8, 0.0))
    c = chord([69, 73, 76, 81], 0.35, "glass", seed, 0.6, 0.5)
    return layer(sw, air * 0.5, c, offsets=[0, 0, 0.18])


@recipe("reload_generic", "cast", doc="Reload: mag out click, slide, mag in clack, bolt click; 650 ms.")
def reload_generic(seed, variant=0, **_):
    c1 = click(seed, 0.006, 1000) + apply(lowpass(noise(0.03, seed + 1), 1200, 2), exp_env(0.03, 0.008))
    slide = apply(bandpass(noise(0.1, seed + 2), 2500, 1.0), env_points(0.1, [(0, 0), (0.03, 0.6), (0.1, 0)])) * 0.5
    c2 = click(seed + 3, 0.008, 700) * 1.2 + apply(lowpass(noise(0.05, seed + 4), 600, 2), exp_env(0.05, 0.012))
    c3 = click(seed + 5, 0.005, 1500) + ring(2200, 0.05, seed + 6, 15) * 0.4
    return layer(c1, slide, c2, c3, offsets=[0.0, 0.15, 0.42, 0.55])


# ======================================================================================
# HERO ULT STINGERS + RADIO CALLOUTS (parametric on hero id)
# ======================================================================================
def _stinger_core(seed, hero, enemy: bool):
    v = hero_voice(hero)
    notes = motif_notes(v, minor=enemy)
    bpm = v["bpm"] * (0.9 if enemy else 1.0)
    timbre = v["timbre"]
    if enemy and timbre in ("bell", "glass"):
        timbre = "choir"
    if enemy and timbre == "pluck":
        timbre = "brass"
    mel = play_notes(notes, bpm, timbre, seed, v["bright"] * (0.5 if enemy else 1.0), 0.8, 1.8)
    if enemy:
        mel2 = play_notes(notes, bpm, timbre, seed + 7, v["bright"] * 0.5, 0.8, 1.8, detune_cents=-18)
        mel3 = play_notes(notes, bpm, timbre, seed + 9, v["bright"] * 0.5, 0.8, 1.8, detune_cents=+14)
        mel = layer(mel, mel2, mel3) / 2.2
    root = v["root"] - 12
    scale = MINOR if enemy else SCALES[v["scale"]]
    chord_m = [root, root + scale[2], root + 7, root + 12 + (scale[1] if not enemy else 0)]
    total = len(mel) / SR
    pad = chord(chord_m, total, "pad", seed + 20, 0.25 if enemy else 0.45, 0.55, 0.06)
    riser = whoosh(200 if enemy else 600, 4000, 0.35, seed, 1.2, "pink", (0.95, 0.5, 0.0))
    hit = layer(sub_kick(110, 36, 0.5, 2.5 if not enemy else 3.5), crack(seed + 2, 0.06, 1500, 0.8) * 0.4) * 0.8
    parts = [riser, hit, pad, mel]
    offs = [0.0, 0.33, 0.35, 0.35]
    if enemy:
        growl = apply(lowpass(soft_clip(fm(midi_to_hz(root - 12), 0.5, 4.0, total), 3.0), 500), env_points(total, [(0, 0), (0.2, 0.6), (total, 0)])) * 0.6
        parts.append(growl)
        offs.append(0.35)
    sig = layer(*parts, offsets=offs)
    if enemy:
        sig = lowpass(sig, 2200)
        sig = soft_clip(sig, 1.6)
    sig = reverb(sig, 1.2 if not enemy else 1.6, 0.28, seed, 4500 if not enemy else 2500)
    return S.trim_tail(S.limit_len(sig, 2.8, 120), -50, 80)


@recipe("hero_stinger", "stinger", doc="Per-hero ultimate stinger: 5-note motif from the hero-id hash (scale/timbre/rhythm), pad + hit.")
def hero_stinger(seed, variant=0, hero=None, enemy=False, **_):
    return _stinger_core(seed, hero or "generic", bool(enemy))


def _vowel_formants(i: int):
    vowels = [(730, 1090, 2440), (530, 1840, 2480), (390, 1990, 2550), (570, 840, 2410), (440, 1020, 2240)]
    return vowels[i % len(vowels)]


@recipe("hero_ult_line", "voice", doc="Radio callout texture: formant-filtered pulse source following the motif contour, band-limited + squelch.")
def hero_ult_line(seed, variant=0, hero=None, enemy=False, **_):
    v = hero_voice(hero or "generic")
    notes = motif_notes(v, minor=bool(enemy))
    dur = 0.6
    n = n_samples(dur)
    # pitch contour: compress the motif into a speaking range with glides
    midis = np.array([m for m, _ in notes], dtype=float)
    midis = 45 + (midis - midis.min()) * 0.6 + (-4 if enemy else 0)
    pts = np.linspace(0, 1, len(midis))
    contour = np.interp(np.linspace(0, 1, n), pts, midi_to_hz(midis))
    contour *= 1.0 + 0.02 * np.sin(S._phase(6.0, n))
    src = S.pulse_train(contour, dur, 12) + 0.2 * noise(dur, seed, "pink")
    out = np.zeros(n)
    seg = n // len(notes)
    for i in range(len(notes)):
        f1, f2, f3 = _vowel_formants(i + hero_hash(v["hero"]) % 5)
        s, e = i * seg, (n if i == len(notes) - 1 else (i + 1) * seg)
        chunk = np.zeros(n)
        chunk[s:e] = src[s:e]
        fx = bandpass(chunk, f1, 6) + 0.6 * bandpass(chunk, f2, 8) + 0.3 * bandpass(chunk, f3, 10)
        out += fx
    env = np.ones(n)
    for i in range(len(notes)):
        s = i * seg
        env[s:s + 300] *= np.linspace(0.3, 1.0, 300)[: len(env[s:s + 300])]
    out = apply(out, env * env_points(dur, [(0, 0), (0.03, 1), (0.55, 1), (0.6, 0)]))
    out = highpass(lowpass(out, 3400), 300)
    out = soft_clip(out / (np.abs(out).max() + 1e-9), 4.0 if enemy else 2.5)
    out = S.bitcrush(out, 10 if enemy else 12)
    if enemy:
        out *= 0.75 + 0.25 * np.sin(S._phase(31.0, n))
    static = apply(bandpass(noise(dur, seed + 5), 2500, 0.8), env_points(dur, [(0, 0.5), (0.05, 0.1), (0.55, 0.1), (0.6, 0.5)])) * (0.25 if enemy else 0.15)
    open_ = click(seed, 0.004, 2500) * 0.6
    close = click(seed + 1, 0.005, 1800) * 0.6
    return layer(open_, out * 0.9, static, close, offsets=[0, 0.01, 0, dur + 0.01])


# ======================================================================================
# AMBIENCE (kind ambience: stereo loops, ~20 s)
# ======================================================================================
AMB_DUR = 20.0


def _wind_bed(dur, seed, lo=250, hi=1100, gust_rate=0.09, color="pink", q=0.7):
    out = []
    for c in range(2):
        n = noise(dur, seed + c * 17, color)
        cutoff = lo + (hi - lo) * S.lfo(dur, gust_rate * (1 + 0.3 * c), 1.0, "random", seed=seed + 3 + c)
        w = sweep_filter(n, "lowpass", cutoff, q, block=512)
        gust = 0.35 + 0.65 * S.lfo(dur, gust_rate, 1.0, "random", seed=seed + 40 + c)
        out.append(w * gust)
    return np.stack(out, axis=1)


def _scatter(dur, seed, count, maker, pan_spread=0.9, min_gap=0.0):
    """Place `count` events (maker(i, rng) -> mono sig) at random times, random pans, into a stereo bed."""
    r = rng(seed)
    n = n_samples(dur)
    out = np.zeros((n, 2))
    times = np.sort(r.uniform(0, dur, count))
    for i, t in enumerate(times):
        ev = maker(i, r)
        st = S.pan(ev, r.uniform(-pan_spread, pan_spread))
        s = int(t * SR)
        e = min(n, s + len(st))
        out[s:e] += st[: e - s]
        if e < s + len(st):  # wrap the remainder to the loop start
            rem = st[e - s:]
            out[: len(rem)] += rem[: n]
    return out


def _amb_finish(sig: np.ndarray, seed: int) -> np.ndarray:
    sig = S.remove_dc(sig)
    sig = seamless_loop(sig, 400)
    return sig


@recipe("amb_wind", "ambience", stereo=True, loop=True, doc="Open-air wind: gusting filtered noise + a faint resonant whistle.")
def amb_wind(seed, variant=0, **_):
    bed = _wind_bed(AMB_DUR, seed)
    whistle = np.stack([sweep_filter(noise(AMB_DUR, seed + 9 + c), "bandpass", 700 + 300 * S.lfo(AMB_DUR, 0.05, 1.0, "random", seed=seed + c), 12, 512)
                        * (0.2 + 0.8 * S.lfo(AMB_DUR, 0.07, 1.0, "random", seed=seed + 60 + c)) for c in range(2)], axis=1)
    return _amb_finish(layer(bed, whistle * 0.25), seed)


@recipe("amb_harbor", "ambience", stereo=True, loop=True, doc="Drowned ferry port: lapping water, gulls, distant rope creak, soft wind.")
def amb_harbor(seed, variant=0, **_):
    bed = _wind_bed(AMB_DUR, seed, 200, 700) * 0.5
    water = np.stack([apply(bandpass(noise(AMB_DUR, seed + 30 + c, "pink"), 900, 0.6), 0.3 + 0.7 * S.lfo(AMB_DUR, 0.35 + 0.05 * c, 1.0, "random", seed=seed + 70 + c)) for c in range(2)], axis=1)

    def gull(i, r):
        d = r.uniform(0.25, 0.5)
        f0 = r.uniform(1100, 1500)
        f = sweep(f0, f0 * 0.65, d) * (1 + 0.03 * np.sin(S._phase(28.0, n_samples(d))))
        return apply(bandpass(saw(f, d), f0, 3.0) + 0.3 * sine(f, d), env_points(d, [(0, 0), (0.05, 1), (d * 0.8, 0.6), (d, 0)])) * r.uniform(0.15, 0.35)

    def creak(i, r):
        d = r.uniform(0.3, 0.6)
        return apply(bandpass(saw(sweep(80, 110, d), d), 600, 5.0), env_points(d, [(0, 0), (d * 0.3, 0.5), (d, 0)])) * 0.15

    gulls = _scatter(AMB_DUR, seed + 1, 9, gull)
    creaks = _scatter(AMB_DUR, seed + 2, 3, creak, 0.5)
    return _amb_finish(layer(bed, water * 0.8, gulls, creaks), seed)


@recipe("amb_snow_wind", "ambience", stereo=True, loop=True, doc="Summit wind: thin bright gusts, whistling partials, ice ticks.")
def amb_snow_wind(seed, variant=0, **_):
    bed = _wind_bed(AMB_DUR, seed, 500, 2600, 0.12, "white", 0.5)
    bed = highpass(bed, 350)
    partials = np.zeros((n_samples(AMB_DUR), 2))
    for c in range(2):
        for k, f in enumerate((640, 960)):
            partials[:, c] += sine(f * (1 + 0.01 * S.lfo(AMB_DUR, 0.11 + 0.03 * k, 1.0, "random", seed=seed + k + c)), AMB_DUR) * (0.15 + 0.85 * S.lfo(AMB_DUR, 0.06, 1.0, "random", seed=seed + 20 + k + c)) * 0.08

    def tick(i, r):
        return glass(r.uniform(3000, 6000), 0.08, seed + i) * 0.12

    ticks = _scatter(AMB_DUR, seed + 3, 10, tick)
    return _amb_finish(layer(bed * 0.8, partials, ticks), seed)


@recipe("amb_market", "ambience", stereo=True, loop=True, doc="Souk at noon: crowd murmur (chattering filtered noise), random bells/blips, footfall ticks, low wind.")
def amb_market(seed, variant=0, **_):
    murmur = np.zeros((n_samples(AMB_DUR), 2))
    for c in range(2):
        for k, (fc, q) in enumerate(((350, 3.0), (650, 4.0), (1100, 5.0))):
            n = noise(AMB_DUR, seed + 100 + k * 3 + c, "pink")
            chat = S.lfo(AMB_DUR, 4.5 + k, 1.0, "random", seed=seed + 200 + k + c) * S.lfo(AMB_DUR, 0.5 + 0.2 * k, 1.0, "random", seed=seed + 300 + k + c)
            murmur[:, c] += bandpass(n, fc, q) * (0.2 + 0.8 * chat) * (0.9 - 0.2 * k)
    bed = _wind_bed(AMB_DUR, seed, 150, 500) * 0.3

    def blip(i, r):
        f = midi_to_hz(r.choice([74, 76, 79, 81, 86]))
        return (bell(f, 0.5, seed + i, 0.7) if r.random() < 0.6 else pluck(f, 0.5, seed + i, 0.6)) * 0.12

    def step(i, r):
        return _synth_step(seed + 500 + i, i, "medium") * 0.15

    blips = _scatter(AMB_DUR, seed + 4, 10, blip)
    steps = _scatter(AMB_DUR, seed + 5, 16, step)
    return _amb_finish(layer(murmur * 0.9, bed, blips, steps), seed)


@recipe("amb_rain_city", "ambience", stereo=True, loop=True, doc="Night rain on wet asphalt: dense rain, distant transformer hum, passing car swells.")
def amb_rain_city(seed, variant=0, **_):
    rain = np.zeros((n_samples(AMB_DUR), 2))
    for c in range(2):
        r = rng(seed + 10 + c)
        n = n_samples(AMB_DUR)
        drops = np.zeros(n)
        idx = r.integers(0, n - 4, 22000)
        drops[idx] += r.uniform(0.3, 1.0, len(idx))
        drops = lowpass(highpass(drops, 1500), 9000)
        rain[:, c] = drops * 0.9 + highpass(noise(AMB_DUR, seed + 30 + c), 2500) * 0.25
    rain *= 0.7 + 0.3 * S.lfo(AMB_DUR, 0.08, 1.0, "random", seed=seed + 7)[:, None]
    hum = (sine(60, AMB_DUR) + 0.5 * sine(120, AMB_DUR) + 0.2 * sine(180, AMB_DUR)) * 0.12
    hum = np.stack([hum, hum * 0.9], axis=1)

    def car(i, r):
        d = r.uniform(2.0, 3.5)
        return whoosh(300, 900, d, seed + i, 0.8, "pink", (0.5, 1.0, 0.0)) * 0.25

    cars = _scatter(AMB_DUR, seed + 8, 3, car, 1.0)
    return _amb_finish(layer(rain, hum, cars), seed)


@recipe("amb_forest", "ambience", stereo=True, loop=True, doc="Misty seed-vault campus: bird chirps, leaves fluttering, low mist bed.")
def amb_forest(seed, variant=0, **_):
    leaves = np.stack([apply(bandpass(noise(AMB_DUR, seed + 40 + c, "white"), 2500, 0.6), 0.2 + 0.8 * S.lfo(AMB_DUR, 5.0 + c, 1.0, "random", seed=seed + 50 + c) * S.lfo(AMB_DUR, 0.1, 1.0, "random", seed=seed + 55 + c)) for c in range(2)], axis=1) * 0.35
    bed = _wind_bed(AMB_DUR, seed, 150, 600) * 0.35

    def bird(i, r):
        chirps = int(r.integers(2, 6))
        parts, offs = [], []
        base = r.uniform(2200, 4800)
        for k in range(chirps):
            d = r.uniform(0.05, 0.12)
            f = sweep(base * r.uniform(0.9, 1.1), base * r.uniform(0.7, 1.4), d)
            parts.append(apply(sine(f, d), env_points(d, [(0, 0), (d * 0.3, 1), (d, 0)])))
            offs.append(k * r.uniform(0.08, 0.16))
        return layer(*parts, offsets=offs) * r.uniform(0.08, 0.2)

    birds = _scatter(AMB_DUR, seed + 6, 14, bird)
    return _amb_finish(layer(bed, leaves, birds), seed)


@recipe("amb_station", "ambience", stereo=True, loop=True, doc="Inside a fallen Ring segment: 50 Hz hum stack, air vents, relay clicks and console blips.")
def amb_station(seed, variant=0, **_):
    hum = (sine(50, AMB_DUR) + 0.6 * sine(100, AMB_DUR) + 0.3 * sine(150.3, AMB_DUR) + 0.15 * sine(201, AMB_DUR)) * 0.14
    hum = np.stack([hum, sine(50.2, AMB_DUR) * 0.14 + hum * 0.5], axis=1)
    vents = _wind_bed(AMB_DUR, seed, 300, 900, 0.05, "pink", 1.0) * 0.45

    def relay(i, r):
        return click(seed + i, 0.008, 800) * 0.25 + apply(lowpass(noise(0.03, seed + i + 1), 1200, 2), exp_env(0.03, 0.008)) * 0.2

    def blip(i, r):
        f = r.choice([1760, 2093, 2637])
        return apply(sine(f, 0.09), exp_env(0.09, 0.03)) * 0.08

    relays = _scatter(AMB_DUR, seed + 9, 8, relay, 0.8)
    blips = _scatter(AMB_DUR, seed + 11, 6, blip, 0.9)
    return _amb_finish(layer(hum, vents, relays, blips), seed)


# ======================================================================================
# MUSIC (stereo)
# ======================================================================================
def _stereo_pad_chord(midis, dur, seed, bright=0.4, attack=0.6, gain=0.5):
    l = chord(midis, dur, "pad", seed, bright, gain, attack)
    r = chord(midis, dur, "pad", seed + 101, bright, gain, attack)
    return np.stack([l, r], axis=1)


@recipe("music_menu", "music", stereo=True, loop=True, doc="Menu theme: 72 bpm D major, 20 bars (66.7 s) of pads, slow bell arpeggio, sub bass, sparse high melody; seamless loop.")
def music_menu(seed, variant=0, **_):
    bpm = 72.0
    spb = 60.0 / bpm
    bar = 4 * spb
    # I V vi IV x4, then IV V x2 (20 bars) — D major
    D, A, Bm, G = [62, 66, 69, 74], [57, 61, 64, 69], [59, 62, 66, 71], [55, 59, 62, 67]
    prog = ([D, A, Bm, G] * 4) + [G, A, G, A]
    roots = [50, 45, 47, 43] * 4 + [43, 45, 43, 45]
    nbars = len(prog)
    passes = 2  # render twice, keep the second pass so the loop start already carries the tail of the end
    total = bar * nbars * passes + 3.0
    n = n_samples(total)
    out = np.zeros((n, 2))
    r = rng(seed)
    melody_seq = [(81, 2), (78, 1), (74, 1), (76, 2), (81, 2), (86, 1.5), (83, 0.5), (81, 2)]
    for p in range(passes):
        for b in range(nbars):
            t0 = (p * nbars + b) * bar
            ch = prog[b]
            padsig = _stereo_pad_chord(ch, bar * 1.15, seed + b, 0.35, 0.7, 0.45)
            out = mix_at(out, padsig, t0)[:n]
            # sub bass: root each bar, soft
            bass = apply(sine(midi_to_hz(roots[b] - 12), bar), adsr(bar, 0.05, 0.2, 0.7, 0.4)) * 0.28
            out = mix_at(out, np.stack([bass, bass], axis=1), t0)[:n]
            # slow arpeggio: chord tones over two octaves, one per beat (bell), alternating panning
            tones = ch + [m + 12 for m in ch]
            for k in range(4):
                m = tones[(b * 3 + k * 2) % len(tones)]
                sig = bell(midi_to_hz(m), spb * 2.2, seed + b * 4 + k, 0.55) * 0.22
                out = mix_at(out, S.pan(sig, -0.5 + k / 3.0), t0 + k * spb)[:n]
            # sparse high melody from bar 9 on (pluck), in both passes
            if b >= 8 and b < 16:
                tt = t0
                for i, (m, beats) in enumerate(melody_seq if b % 2 == 0 else melody_seq[::-1]):
                    if i % 2 == (b // 2) % 2:
                        sig = pluck(midi_to_hz(m), beats * spb * 1.5, seed + i, 0.5) * 0.18
                        out = mix_at(out, S.pan(sig, 0.2 * (-1) ** i), tt)[:n]
                    tt += beats * spb
    # air / tape bed
    air = np.stack([bandpass(noise(total, seed + 77 + c, "pink"), 4000, 0.8) for c in range(2)], axis=1) * 0.025
    out = layer(out, air)[:n]
    out = reverb(out, 2.2, 0.3, seed, 3500)[:n]
    start = int(bar * nbars * SR)
    end = start + int(bar * nbars * SR)
    loop = out[start:end]
    loop = S.remove_dc(loop)
    return seamless_loop(loop, 60)


@recipe("music_potg", "music", stereo=True, doc="Play-of-the-game: 10 s build (accelerating arpeggio, riser) into a bright add9 brass hit and shimmer tail.")
def music_potg(seed, variant=0, **_):
    total = 10.0
    n = n_samples(total)
    out = np.zeros((n, 2))
    # accelerating arpeggio on D major 6 s
    tones = [62, 66, 69, 74, 78, 81]
    t = 0.0
    gap = 0.32
    i = 0
    while t < 5.9:
        m = tones[i % len(tones)] + 12 * (i // len(tones) % 2)
        sig = pluck(midi_to_hz(m), 0.6, seed + i, 0.7) * 0.35
        out = mix_at(out, S.pan(sig, math.sin(i * 0.9) * 0.7), t)[:n]
        t += gap
        gap = max(0.09, gap * 0.94)
        i += 1
    padsig = _stereo_pad_chord([50, 57, 62, 66], 6.2, seed, 0.4, 2.5, 0.45)
    out = mix_at(out, padsig, 0.0)[:n]
    riser = whoosh(300, 6000, 5.8, seed, 1.0, "pink", (0.98, 0.7, 0.0))
    out = mix_at(out, np.stack([riser, riser * 0.9], axis=1) * 0.5, 0.2)[:n]
    hit = layer(sub_kick(120, 35, 0.6, 3.0), crack(seed + 3, 0.1, 1500, 0.8) * 0.5) * 0.9
    out = mix_at(out, np.stack([hit, hit], axis=1), 6.0)[:n]
    br = chord([62, 66, 69, 76, 81], 3.5, "brass", seed + 5, 0.7, 0.6)
    bl = chord([86, 90, 93], 3.5, "bell", seed + 9, 0.8, 0.35)
    out = mix_at(out, np.stack([br, br * 0.95], axis=1), 6.02)[:n]
    out = mix_at(out, S.to_stereo(bl, 0.4, 4.0, seed), 6.05)[:n]
    shimmer = apply(bandpass(noise(3.8, seed + 8), 7000, 1.5), env_points(3.8, [(0, 0.6), (3.8, 0)])) * 0.2
    out = mix_at(out, S.to_stereo(shimmer, 0.5, 2.0, seed), 6.05)[:n]
    out = reverb(out, 2.0, 0.28, seed, 4000)[:n]
    return fade(out, 5, 400)


@recipe("music_victory", "music", stereo=True, doc="Victory: 6 s rising D major cadence (I-IV-V-I) with brass, bells and a bright pad.")
def music_victory(seed, variant=0, **_):
    total = 6.0
    n = n_samples(total)
    out = np.zeros((n, 2))
    chords = [([62, 66, 69], 0.0, 1.0), ([67, 71, 74], 1.0, 1.0), ([69, 73, 76], 2.0, 1.0), ([74, 78, 81, 86], 3.0, 3.0)]
    for ch, t, d in chords:
        br = chord(ch, d * 1.2, "brass", seed + int(t * 10), 0.7, 0.55)
        out = mix_at(out, np.stack([br, br * 0.93], axis=1), t)[:n]
        bl = chord([m + 12 for m in ch], d * 1.4, "bell", seed + 30 + int(t * 10), 0.8, 0.3)
        out = mix_at(out, S.to_stereo(bl, 0.4, 3.0, seed), t + 0.02)[:n]
    padsig = _stereo_pad_chord([50, 57, 62, 66], 6.0, seed, 0.5, 1.0, 0.4)
    out = mix_at(out, padsig, 0.0)[:n]
    hit = sub_kick(110, 36, 0.5, 2.5) * 0.8
    out = mix_at(out, np.stack([hit, hit], axis=1), 3.0)[:n]
    out = reverb(out, 2.2, 0.3, seed, 4500)[:n]
    return fade(out, 5, 500)


@recipe("music_defeat", "music", stereo=True, doc="Defeat: 6 s descending D minor (i-bVI-iv-V) with low pad and slow dark bell.")
def music_defeat(seed, variant=0, **_):
    total = 6.0
    n = n_samples(total)
    out = np.zeros((n, 2))
    chords = [([50, 53, 57], 0.0, 1.5), ([46, 50, 53], 1.5, 1.5), ([43, 46, 50], 3.0, 1.5), ([45, 49, 52], 4.5, 1.5)]
    for ch, t, d in chords:
        p = _stereo_pad_chord(ch, d * 1.3, seed + int(t * 10), 0.2, 0.5, 0.5)
        out = mix_at(out, p, t)[:n]
        bl = bell(midi_to_hz(ch[0] + 24), d * 1.5, seed + 40 + int(t * 10), 0.3) * 0.25
        out = mix_at(out, S.to_stereo(bl, 0.3, 5.0, seed), t + 0.05)[:n]
    ch_mel = play_notes([(74, 1.5), (69, 1.5), (65, 1.5), (62, 2.0)], 60, "choir", seed + 7, 0.3, 0.35, 1.3)
    out = mix_at(out, S.to_stereo(ch_mel, 0.4, 6.0, seed), 0.1)[:n]
    out = lowpass(out, 3000)
    out = reverb(out, 2.6, 0.32, seed, 2500)[:n]
    return fade(out, 5, 600)


# --------------------------------------------------------------------------------------
# archetype documentation (used by README generation and the report)
# --------------------------------------------------------------------------------------
ARCHETYPE_TABLE = [
    ("rifle_semi", "Vesper", "dry tight crack, wooden 190->55 Hz body, 1.9 kHz ring; long tail", "highest crack, shortest body: 'one bullet, one decision'"),
    ("smg", "Harrier", "bright 4.2 kHz crack, thin 260->95 Hz body, 100 ms", "lightest, fastest; sits above everything else"),
    ("cannon", "(generic heavy)", "muffled boom, 110->34 Hz body, 240 ms, saturated", "no top end at all"),
    ("slug_cannon", "Kiln", "cannon + pink-noise sizzle band at 5.2 kHz", "boom with a molten hiss riding on top"),
    ("shotgun_wave", "Ballast", "broadband burst lowpass-swept 7k->350 + pressure whoosh", "wide and watery; no click"),
    ("mortar_thump", "Bombard", "hollow resonant tube thump 130->42 Hz + breathy puff", "round, no crack: heard as a 'toonk'"),
    ("gravity_mortar", "Rook", "mortar thump + downward FM womp 220->45 Hz", "the womp is the tell"),
    ("rock_lob", "Cairn", "low thud + 14-grain gravel crackle", "gritty, earthy, mid-heavy"),
    ("needle_burst", "Wisp", "three 2.6-3.2 kHz FM ticks 26 ms apart, tiny body", "a rhythm, not a bang"),
    ("thorn", "Bramble", "60 ms noise sweep 2.4k->500 + wooden knock", "organic, almost no low end"),
    ("disc_launch", "Ricochet", "inharmonic FM 'shing' (ratio 1.41) + rising whoosh", "metallic pitch bend up"),
    ("lightning_arc", "Coil", "40 random impulses through 4.2 kHz bandpass + 110 Hz square buzz", "crackle texture; no tonal body"),
    ("beam_fire", "Lumen", "zap sweep 1.8k->600 + 110 Hz saw hum bloom (then beam_loop)", "ignition + sustained hum"),
    ("staff_bolt", "Ferry", "FM shimmer sweep at 700 Hz, pink breath, soft 150 Hz body", "airy and soft; the gentlest 'fire'"),
    ("stapler", "Suture", "two clicks 40 ms apart + 1.8 kHz spring ping", "mechanical double-click"),
    ("flame_bolt", "Tallow", "pink-noise fwoosh lowpass-swept 3.5k->450 + puff", "breathy, mid-band, no click"),
    ("bass_cannon", "Cadence", "808-style sine 160->42 Hz saturated + click", "pure sub weight; the lowest fire in the game"),
    ("blade_swing", "Sable", "three band-swept whooshes (up / down / long up) + 5.2 kHz edge ring", "combo hits differ by arc"),
    ("mace_swing", "Cathedral", "slow pink whoosh 250->900 + chain rattle", "heavy and slow"),
    ("heal_bolt", "(generic support)", "880 Hz sine + 2nd harmonic, gentle attack, airy noise", "bell-like, no transient"),
]
