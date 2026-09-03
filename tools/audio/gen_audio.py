#!/usr/bin/env python3
"""Render every game sound to assets/audio/ from the procedural recipes in recipes.py.

    python3 tools/audio/gen_audio.py            # render everything (skips up-to-date files)
    python3 tools/audio/gen_audio.py --force    # re-render all
    python3 tools/audio/gen_audio.py --only kiln_  # ids containing a substring
    python3 tools/audio/gen_audio.py --list     # print the manifest without rendering

Ids the game references (hero ability sounds, footsteps, stingers) are mapped to archetype recipes by
MANIFEST below; every registered recipe is also rendered under its own name. Output layout matches
AudioLibrary.gd: `<id>.wav` for single sounds, `<id>_1..n.wav` for variant sets. Loops carry a `smpl`
chunk so Godot imports them looping. `manifest.json` records recipe/kind/files/Kenney sources, and
SOURCES.md lists every Kenney CC0 sample folded into a render (for ATTRIBUTION.md).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from multiprocessing import Pool

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import numpy as np  # noqa: E402

import recipes as R  # noqa: E402
import synth as S  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "audio")

HEROES = ["ballast", "bombard", "bramble", "cadence", "cairn", "cathedral", "coil", "ferry", "harrier", "kiln",
          "lumen", "ricochet", "rook", "sable", "suture", "tallow", "vesper", "wisp"]

# Duration windows per kind (seconds): (min, max). Renders outside the window are reported, not rejected.
KIND_LIMITS = {
    "gunshot": (0.04, 0.7), "swing": (0.1, 0.8), "tail": (0.3, 1.6), "cast": (0.05, 1.7), "impact": (0.04, 1.6),
    "ui": (0.03, 0.6), "stinger": (0.3, 4.0), "voice": (0.1, 1.5), "footstep": (0.04, 0.16), "loop": (0.3, 12.0),
    # ult casts are the long end of "cast" at ~1.65 s

    "ambience": (6.0, 60.0), "music": (4.0, 120.0),
}

# --- hero ability ids -> archetype recipes -------------------------------------------------------------
# Keys are the ids used in tools/authoring/heroes/*.gd (see AbilityPresentation.sound_*). The value is the
# recipe name, optionally with a params dict. `hero` is filled in automatically so voice-derived
# recipes (stingers, ult lines, loops with a motif root) stay unique per hero.
MANIFEST: dict[str, tuple[str, dict]] = {}


def _m(id_: str, recipe: str, **params) -> None:
    MANIFEST[id_] = (recipe, params)


for _h in HEROES:
    _m(f"ult_{_h}", "hero_stinger", hero=_h)
    _m(f"ult_{_h}_enemy", "hero_stinger", hero=_h, enemy=True)
    _m(f"{_h}_ult_line", "hero_ult_line", hero=_h)
    _m(f"{_h}_ult_line_enemy", "hero_ult_line", hero=_h, enemy=True)

_m("ult_ready_generic", "ult_ready")
# Callout chirp sets: heroes pick one via HeroAudioData.callout_tone. Same recipe, pitched apart
# by the hero-voice offset so teammates' pings stay tellable from each other.
_m("radio_a", "ping", hero="radio_a")
_m("radio_b", "ping", hero="radio_b")
_m("radio_c", "ping", hero="radio_c")
_m("melee_swing", "whoosh")
_m("harrier_jet_jump", "jet_burst")
_m("harrier_jet_land", "land_generic")

# Weapon fire/tail ids were absent here for thirteen weapons, so every hero primary and secondary
# below fell back to silence. Nothing reported it: the client resolved a firing ability's
# presentation from the `slot` on a hitscan or beam event, and that slot was always -1, so the
# sounds were never asked for. Fixing that (see Ability._make_ctx) surfaced 26 missing ids at once.
_HERO_MAP = {
    "ballast": dict(anchor_fire="anchor", anchor_impact="impact_harpoon", anchor_loop="ability_loop", anchor_end="zip_end",
                    riptide_cast="pull", riptide_loop="ult_loop", riptide_end="beam_end", slug_impact="impact_shell",
                    surge_cast="buff_chime", surge_loop="ability_loop", surge_end="focus_off", wave_impact="impact_generic"),
    "bombard": dict(kick_fire="mortar_thump", kick_tail="cannon_tail", airburst_impact="explosion_small",
                    barrage_cast="ult_cast", barrage_loop="ult_loop", barrage_end="beam_end", barrage_impact="impact_mortar",
                    mortar_impact="impact_mortar", spotter_fire="reveal_ping", spotter_loop="ability_loop", spotter_end="focus_off"),
    "bramble": dict(root_apply="root_snare", snare_apply="root_snare", snare_impact="impact_thorn", overgrowth_cast="ult_cast",
                    overgrowth_fire="root_snare", overgrowth_impact="impact_thorn", overgrowth_end="barrier_down",
                    thicket_fire="deploy_place", thicket_loop="ability_loop", thicket_end="deploy_break",
                    fan_impact="impact_thorn", thorns_impact="impact_thorn"),
    "cadence": dict(anthem_cast="ult_cast", anthem_fire="buff_chime", bass_impact="impact_orb", crescendo_fire="bass_cannon",
                    discord_fire="launch_orb", groove_cast="buff_chime", groove_loop="aura_beat", groove_end="focus_off"),
    "cairn": dict(lobber_fire="rock_lob", lobber_tail="short_tail", boulder_fire="rock_lob", boulder_tail="cannon_tail", boulder_impact="impact_mortar", landslide_cast="ult_cast", landslide_fire="rock_lob", landslide_end="beam_end",
                  lobber_impact="impact_shell", slab_cast="deploy_place", slab_fire="barrier_up", slab_end="barrier_down",
                  upthrust_cast="lift", upthrust_impact="explosion_small", upthrust_end="short_tail"),
    "cathedral": dict(censer_cast="throw_whoosh", censer_fire="throw_whoosh", censer_impact="impact_candle",
                      guard_cast="barrier_up", guard_loop="ability_loop", guard_end="barrier_down", mace_fire="mace_swing",
                      mace_impact="melee_hit", mace_tail="short_tail", sanctuary_cast="ult_cast", sanctuary_loop="ult_loop",
                      sanctuary_end="barrier_down", wall_cast="deploy_place", wall_fire="barrier_up", wall_end="barrier_down"),
    "coil": dict(chain_fire="lightning_arc", chain_tail="short_tail", lance_fire="lightning_arc", lance_tail="cannon_tail", blackout_cast="ult_cast", blackout_fire="lightning_arc", blackout_impact="impact_bolt", blackout_end="beam_end",
                 capacitor_cast="buff_chime", capacitor_loop="capacitor_loop", capacitor_end="focus_off",
                 chain_impact="chain_zap", lance_impact="impact_bolt", tesla_node_cast="deploy_place",
                 tesla_node_fire="deploy_place", tesla_node_loop="ability_loop", tesla_node_end="deploy_break"),
    "ferry": dict(bolt_fire="staff_bolt", bolt_tail="short_tail", light_fire="heal_bolt", crossing_cast="ult_cast", crossing_fire="teleport_out", crossing_loop="ult_loop", crossing_end="teleport_in",
                  undertow_fire="pull", waystone_fire="deploy_place"),
    "harrier": dict(afterburn_fire="jet_burst", afterburn_tail="short_tail", afterburn_end="beam_end", dive_cast="dash",
                    dive_loop="flight_jets", dive_impact="explosion_small", dive_end="land_generic",
                    rockets_impact="explosion_small", smg_impact="impact_generic", strafing_run_cast="ult_cast",
                    strafing_run_fire="smg", strafing_run_loop="flight_jets", strafing_run_impact="explosion_small",
                    strafing_run_end="beam_end"),
    "kiln": dict(slug_fire="slug_cannon", slug_tail="cannon_tail", blast_fire="flame_bolt", blast_tail="short_tail", blast_impact="explosion_small", meltdown_cast="ult_cast", meltdown_loop="meltdown", meltdown_end="beam_end",
                 slag_cast="whoosh", slag_fire="flame_bolt", slag_end="short_tail", slug_impact="impact_shell",
                 vent_cast="whoosh", vent_fire="jet_burst", vent_end="focus_off"),
    "lumen": dict(beam_cast="beam_fire", beam_loop="beam_loop", beam_end="beam_end", blind_apply="reveal_ping",
                  glint_fire="reveal_ping", prism_fire="barrier_up", refract_fire="teleport_out", sunstroke_cast="ult_cast",
                  sunstroke_loop="ult_loop", sunstroke_end="beam_end"),
    "ricochet": dict(bank_shot_cast="focus_on", bank_shot_end="focus_off", disc_impact="impact_disc", lob_impact="impact_grenade",
                     pinball_cast="ult_cast", pinball_fire="disc_launch", pinball_impact="impact_disc", pinball_loop="ult_loop",
                     pinball_end="beam_end", skip_fire="launch_grenade", skip_tail="short_tail"),
    "rook": dict(density_cast="lift", density_loop="density_loop", density_end="focus_off", ground_zero_cast="ult_cast",
                 ground_zero_loop="ult_loop", ground_zero_end="explosion_large", lift_cast="lift", lift_fire="lift",
                 lift_end="short_tail", mortar_impact="impact_mortar", singularity_impact="explosion_large"),
    "sable": dict(blades_fire="blade_swing", blades_tail="short_tail", blades_impact="melee_hit", lunge_cast="dash", lunge_impact="melee_hit", lunge_end="short_tail",
                  requiem_cast="ult_cast", requiem_loop="ult_loop", requiem_impact="melee_hit", requiem_end="beam_end",
                  shroud_cast="shroud_on", shroud_loop="shroud_loop", shroud_end="focus_off", vault_fire="dash",
                  vault_tail="short_tail"),
    "suture": dict(stapler_fire="stapler", stapler_tail="short_tail", volley_fire="heal_bolt", volley_tail="short_tail", adrenaline_apply="buff_chime", adrenaline_fire="buff_chime", tether_fire="heal_bolt", triage_cast="ult_cast",
                   triage_fire="heal_pulse"),
    "tallow": dict(bolt_fire="flame_bolt", bolt_tail="short_tail", wax_fire="heal_bolt", wax_tail="short_tail", bolt_impact="impact_candle", last_light_apply="cleanse_chime", snuff_apply="burn_apply", snuff_fire="flame_bolt",
                   snuff_tail="short_tail", vigil_apply="heal_pulse", vigil_cast="ult_cast", vigil_fire="barrier_up",
                   vigil_end="barrier_down", wax_impact="impact_candle", wicks_fire="deploy_place", wicks_loop="ability_loop",
                   wicks_end="deploy_break"),
    "vesper": dict(fire="rifle_semi", tail="rifle_tail", focus_on="focus_on", focus_off="focus_off", lantern_throw="throw_whoosh", ult="ult_cast", ult_loop="ult_loop",
                   zip_fire="zip_fire", zip_end="zip_end", zip_loop="zipline_loop"),
    "wisp": dict(displacement_cast="ult_cast", displacement_fire="teleport_out", displacement_impact="teleport_in",
                 displacement_end="beam_end", exchange_impact="teleport_in", exchange_end="teleport_out", fold_fire="teleport_out",
                 fold_tail="short_tail", mark_fire="reveal_ping", mark_tail="short_tail", mark_end="focus_off",
                 needle_impact="impact_needle"),
}
for _h, _table in _HERO_MAP.items():
    for _suffix, _recipe in _table.items():
        _m(f"{_h}_{_suffix}", _recipe, hero=_h)


# --- rendering -----------------------------------------------------------------------------------------
def _seed(id_: str, variant: int) -> int:
    return int(hashlib.sha1(f"{id_}#{variant}".encode()).hexdigest()[:8], 16)


def _semitone_shift(sig: np.ndarray, semis: float) -> np.ndarray:
    """Tiny per-hero pitch offset by resampling (keeps archetype identity, makes heroes distinguishable)."""
    if abs(semis) < 0.01:
        return sig
    ratio = 2.0 ** (semis / 12.0)
    n = sig.shape[0]
    idx = np.arange(0, n, ratio)
    idx = idx[idx < n - 1]
    if sig.ndim == 1:
        return np.interp(idx, np.arange(n), sig)
    return np.stack([np.interp(idx, np.arange(n), sig[:, c]) for c in range(sig.shape[1])], axis=1)


def plan() -> list[dict]:
    """One entry per output id: recipe, params, kind, variants, loop, stereo."""
    items = []
    for name, r in R.RECIPES.items():
        items.append(dict(id=name, recipe=name, params={}, kind=r.kind, variants=r.variants, loop=r.loop, stereo=r.stereo))
    for id_, (recipe, params) in MANIFEST.items():
        if id_ in R.RECIPES:
            continue
        r = R.RECIPES[recipe]
        items.append(dict(id=id_, recipe=recipe, params=params, kind=r.kind, variants=r.variants, loop=r.loop, stereo=r.stereo))
    return items


def files_for(item: dict) -> list[str]:
    if item["variants"] <= 1:
        return [os.path.join(OUT_DIR, item["id"] + ".wav")]
    return [os.path.join(OUT_DIR, f"{item['id']}_{i + 1}.wav") for i in range(item["variants"])]


def render_item(item: dict) -> dict:
    out = dict(id=item["id"], recipe=item["recipe"], kind=item["kind"], files=[], sources=set(), warnings=[])
    lo, hi = KIND_LIMITS.get(item["kind"], (0.01, 120.0))
    hero = item["params"].get("hero")
    semis = 0.0
    if hero and item["recipe"] not in ("hero_stinger", "hero_ult_line", "ult_loop", "ability_loop"):
        semis = R.hero_voice(hero)["semi"] * 0.5
    for i, path in enumerate(files_for(item)):
        seed = _seed(item["id"], i)
        try:
            sig, sources = R.render(item["recipe"], seed, i, **item["params"])
        except Exception as exc:  # keep going: one broken recipe must not block the whole set
            import traceback
            tb = traceback.extract_tb(exc.__traceback__)[-1]
            out["warnings"].append(f"FAILED {item['id']} ({item['recipe']}): {type(exc).__name__}: {exc} @ {os.path.basename(tb.filename)}:{tb.lineno}")
            out["failed"] = True
            break
        sig = np.asarray(sig, dtype=float)
        if not np.all(np.isfinite(sig)):
            out["warnings"].append(f"{os.path.basename(path)}: non-finite samples, zeroed")
            sig = np.nan_to_num(sig)
        if semis and not item["loop"]:
            sig = _semitone_shift(sig, semis)
        peak = float(np.max(np.abs(sig))) if sig.size else 0.0
        if peak < 0.02:
            out["warnings"].append(f"{os.path.basename(path)}: nearly silent (peak {peak:.3f})")
        elif peak > 1.0:
            sig = sig / peak * 0.98
        dur = sig.shape[0] / S.SR
        if not (lo <= dur <= hi):
            out["warnings"].append(f"{os.path.basename(path)}: {dur:.2f}s outside {item['kind']} window {lo}-{hi}s")
        S.write_wav(path, sig, S.SR, loop=item["loop"])
        out["files"].append(os.path.relpath(path, ROOT))
        out["sources"].update(sources)
    out["sources"] = sorted(out["sources"])
    return out


def _up_to_date(item: dict, stamp: float) -> bool:
    return all(os.path.exists(p) and os.path.getmtime(p) >= stamp for p in files_for(item))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 2) - 1))
    args = ap.parse_args()
    items = [it for it in plan() if args.only in it["id"]]
    if args.list:
        for it in items:
            print(f"{it['id']:<34} {it['recipe']:<22} {it['kind']:<9} x{it['variants']}{' loop' if it['loop'] else ''}")
        print(f"{len(items)} ids")
        return 0
    os.makedirs(OUT_DIR, exist_ok=True)
    stamp = max(os.path.getmtime(os.path.join(HERE, f)) for f in ("recipes.py", "synth.py", "gen_audio.py"))
    todo = items if args.force else [it for it in items if not _up_to_date(it, stamp)]
    print(f"rendering {len(todo)} / {len(items)} ids with {args.jobs} jobs")
    t0 = time.time()
    results = []
    if args.jobs > 1 and len(todo) > 4:
        with Pool(args.jobs) as pool:
            for res in pool.imap_unordered(render_item, todo):
                results.append(res)
                for w in res["warnings"]:
                    print("  warn:", w)
    else:
        for it in todo:
            res = render_item(it)
            results.append(res)
            for w in res["warnings"]:
                print("  warn:", w)
    # Manifest covers every id (re-rendered or not).
    manifest_path = os.path.join(OUT_DIR, "manifest.json")
    manifest = {}
    if os.path.exists(manifest_path):
        try:
            manifest = json.load(open(manifest_path))
        except Exception:
            manifest = {}
    for it in items:
        manifest.setdefault(it["id"], dict(recipe=it["recipe"], kind=it["kind"], files=[os.path.relpath(p, ROOT) for p in files_for(it)], sources=[]))
    for res in results:
        if res.get("failed"):
            manifest.pop(res["id"], None)
            continue
        manifest[res["id"]] = dict(recipe=res["recipe"], kind=res["kind"], files=res["files"], sources=res["sources"])
    json.dump(manifest, open(manifest_path, "w"), indent=1, sort_keys=True)
    # Attribution for Kenney samples folded into renders.
    sources = sorted({s for m in manifest.values() for s in m.get("sources", [])})
    with open(os.path.join(OUT_DIR, "SOURCES.md"), "w") as f:
        f.write("# Audio sources\n\nAll sounds are rendered by tools/audio/gen_audio.py from procedural recipes. "
                "The following Kenney CC0 samples (https://kenney.nl, CC0 1.0) are layered into some renders:\n\n")
        for s in sources:
            f.write(f"- {s}\n")
        if not sources:
            f.write("- (none: pure synthesis)\n")
    n_files = sum(len(m["files"]) for m in manifest.values())
    n_warn = sum(len(r["warnings"]) for r in results)
    failed = sorted(r["id"] for r in results if r.get("failed"))
    print(f"done: {len(manifest)} ids, {n_files} files, {n_warn} warnings, {len(failed)} failed, {time.time() - t0:.1f}s")
    if failed:
        print("failed:", " ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
