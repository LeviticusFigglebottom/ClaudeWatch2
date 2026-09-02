#!/usr/bin/env python3
"""Visual regression checks over screenshots: black/blank frames, missing-material magenta,
extreme exposure, and (optionally) drift against reference images.

  tools/visual_check.py screenshots/*.png
  tools/visual_check.py --ref screenshots/ref screenshots/*.png   # compare same-named files
Exit code 1 if any check fails."""
import sys, os, argparse
import numpy as np
from PIL import Image

def analyze(path):
    im = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    lum = 0.2126 * im[..., 0] + 0.7152 * im[..., 1] + 0.0722 * im[..., 2]
    mean = float(lum.mean()); std = float(lum.std())
    dark = float((lum < 0.03).mean()); bright = float((lum > 0.97).mean())
    # Godot's missing-material color is magenta (1,0,1); flag if >0.5% of pixels are near it.
    mag = float(((im[..., 0] > 0.85) & (im[..., 1] < 0.2) & (im[..., 2] > 0.85)).mean())
    problems = []
    if mean < 0.04: problems.append("black frame (mean lum %.3f)" % mean)
    if std < 0.02: problems.append("flat frame (std %.3f)" % std)
    if dark > 0.92: problems.append("mostly black (%.0f%%)" % (dark * 100))
    if bright > 0.6: problems.append("blown out (%.0f%% white)" % (bright * 100))
    if mag > 0.005: problems.append("missing-material magenta (%.2f%%)" % (mag * 100))
    return {"mean": mean, "std": std, "dark": dark, "bright": bright, "magenta": mag, "problems": problems}

def compare(a, b):
    ia = np.asarray(Image.open(a).convert("RGB").resize((320, 180)), dtype=np.float32)
    ib = np.asarray(Image.open(b).convert("RGB").resize((320, 180)), dtype=np.float32)
    return float(np.abs(ia - ib).mean() / 255.0)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--ref", default="")
    ap.add_argument("--max-drift", type=float, default=0.25)
    args = ap.parse_args()
    failed = 0
    for f in args.files:
        if not f.lower().endswith(".png"): continue
        r = analyze(f)
        line = "%-48s lum %.2f std %.2f dark %.0f%% bright %.0f%%" % (os.path.basename(f), r["mean"], r["std"], r["dark"] * 100, r["bright"] * 100)
        if args.ref:
            rf = os.path.join(args.ref, os.path.basename(f))
            if os.path.exists(rf):
                d = compare(f, rf)
                line += " drift %.3f" % d
                if d > args.max_drift: r["problems"].append("drift %.3f > %.2f" % (d, args.max_drift))
        if r["problems"]:
            failed += 1
            line += "  FAIL: " + "; ".join(r["problems"])
        else:
            line += "  ok"
        print(line)
    print("%d files, %d failed" % (len(args.files), failed))
    sys.exit(1 if failed else 0)
