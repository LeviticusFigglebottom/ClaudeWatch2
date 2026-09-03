#!/usr/bin/env python3
"""Parallel sim runner + analysis. Runs N headless matches across P processes and aggregates telemetry.

  tools/sim.py run --map kestrel --mode control --matches 40 --procs 4 --difficulty 2 --out sim_out/kestrel
  tools/sim.py analyze sim_out/kestrel [more dirs...]
"""
import argparse, json, os, subprocess, sys, glob, statistics, time, itertools, random
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT_BIN", "/opt/godot/Godot_v4.7.2-stable_linux.x86_64")

# Seconds a single round can last, per mode, from data/modes/*.tres: setup + round_time + the time
# checkpoints can add. A match of `max_rounds` rounds needs at least this much per round, and a
# limit shorter than that truncates the last round. Escort matches run two rounds with the sides
# swapped, so a 420 s limit used to cut round 2 off and hand every match to whoever attacked first.
MODE_ROUND_SECONDS = {"escort": 450, "hybrid": 450, "control": 360, "push": 500}
MODE_ROUNDS = {"escort": 2, "hybrid": 2, "control": 1, "push": 1}


def minimum_limit(mode):
    return MODE_ROUND_SECONDS.get(mode, 400) * MODE_ROUNDS.get(mode, 1)


def run(args):
    need = minimum_limit(args.mode)
    if args.limit < need:
        print(f"[sim] warning: --limit {args.limit} is short for {args.mode}, which can need {need}s "
              f"({MODE_ROUNDS.get(args.mode, 1)} round(s)). Truncated rounds are scored for whoever "
              f"was ahead, which biases the result toward the team that attacks first.")
    os.makedirs(args.out, exist_ok=True)
    per = max(1, args.matches // args.procs)
    procs = []
    for i in range(args.procs):
        n = per if i < args.procs - 1 else args.matches - per * (args.procs - 1)
        if n <= 0: continue
        seed = args.seed + i * 1000
        cmd = [GODOT, "--headless", "--fixed-fps", "60", "--path", ROOT, "--",
               "--sim", f"--map={args.map}", f"--mode={args.mode}", f"--matches={n}", f"--difficulty={args.difficulty}",
               f"--seed={seed}", f"--out={os.path.abspath(args.out)}", f"--limit={args.limit}"]
        if args.teamA: cmd.append(f"--teamA={args.teamA}")
        if args.teamB: cmd.append(f"--teamB={args.teamB}")
        log = open(os.path.join(args.out, f"proc_{i}.log"), "w")
        procs.append(subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT))
    t0 = time.time()
    for p in procs: p.wait()
    print(f"done in {time.time()-t0:.0f}s; logs in {args.out}")
    for i in range(len(procs)):
        with open(os.path.join(args.out, f"proc_{i}.log")) as f:
            for line in f:
                if "[sim] match" in line or "[sim] finished" in line: print(line.rstrip())

def analyze(dirs, min_games=1):
    files = []
    for d in dirs: files += glob.glob(os.path.join(d, "match_*.json"))
    if not files:
        print("no telemetry files"); return
    games = []
    for f in files:
        try: games.append(json.load(open(f)))
        except Exception as e: print("bad", f, e)
    hero = {}
    def H(h):
        return hero.setdefault(h, {"picks":0,"wins":0,"kills":0,"deaths":0,"damage":0.0,"healing":0.0,"ult_uptime":0.0,"obj":0.0,"ults":0,"time":0.0})
    comp_wins = {}
    ttk = []
    durations = []
    winners = [0,0,0]
    for g in games:
        w = g.get("winner", -1); winners[w if w in (0,1) else 2] += 1
        durations.append(g.get("elapsed", 0))
        ttk += g.get("ttk", [])
        teams = g.get("teams", [[],[]])
        for t in (0,1):
            key = tuple(sorted(teams[t]))
            c = comp_wins.setdefault(key, [0,0]); c[1]+=1
            if w == t: c[0]+=1
        for p in g.get("players", []):
            h = p.get("hero","?"); r = H(h)
            r["picks"] += 1; r["kills"] += p.get("kills",0); r["deaths"] += p.get("deaths",0)
            r["damage"] += p.get("damage",0.0); r["healing"] += p.get("healing",0.0); r["ults"] += p.get("ults_used",0)
            r["time"] += p.get("time_alive",0.0)
            if w == p.get("team"): r["wins"] += 1
        for h, v in g.get("ult_uptime_by_hero", {}).items(): H(h)["ult_uptime"] += v
        for h, v in g.get("objective_time_by_hero", {}).items(): H(h)["obj"] += v
    n = len(games)
    print(f"== {n} matches | A wins {winners[0]}  B wins {winners[1]}  draws {winners[2]} | avg duration {statistics.mean(durations):.0f}s")
    if ttk: print(f"   TTK: median {statistics.median(ttk):.2f}s  mean {statistics.mean(ttk):.2f}s  p10 {sorted(ttk)[len(ttk)//10]:.2f}  p90 {sorted(ttk)[len(ttk)*9//10]:.2f}")
    print(f"{'hero':12s} {'picks':>5s} {'win%':>6s} {'K/D':>6s} {'dmg/10m':>8s} {'heal/10m':>9s} {'ult uptime%':>11s} {'ults/10m':>8s} {'obj%':>6s}")
    for h, r in sorted(hero.items(), key=lambda kv: -kv[1]["picks"]):
        if r["picks"] < min_games: continue
        mins = max(r["time"]/60.0, 0.01)
        print(f"{h:12s} {r['picks']:5d} {100.0*r['wins']/max(r['picks'],1):6.1f} {r['kills']/max(r['deaths'],1):6.2f} {r['damage']/mins*10:8.0f} {r['healing']/mins*10:9.0f} {100.0*r['ult_uptime']/max(r['time'],1):11.1f} {r['ults']/mins*10:8.2f} {100.0*r['obj']/max(r['time'],1):6.1f}")
    print("-- compositions with >= 3 games:")
    for comp, (w, t) in sorted(comp_wins.items(), key=lambda kv: -kv[1][1])[:15]:
        if t >= 3: print(f"   {w}/{t} ({100.0*w/t:.0f}%) {','.join(comp)}")

if __name__ == "__main__":
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd")
    r = sub.add_parser("run"); r.add_argument("--map", default="test_range"); r.add_argument("--mode", default="control")
    r.add_argument("--matches", type=int, default=4); r.add_argument("--procs", type=int, default=2); r.add_argument("--difficulty", type=int, default=2)
    r.add_argument("--seed", type=int, default=1); r.add_argument("--out", default="sim_out/run"); r.add_argument("--limit", type=float, default=600.0)
    r.add_argument("--teamA", default=""); r.add_argument("--teamB", default="")
    a = sub.add_parser("analyze"); a.add_argument("dirs", nargs="+"); a.add_argument("--min-games", type=int, default=1)
    args = ap.parse_args()
    if args.cmd == "run": run(args)
    elif args.cmd == "analyze": analyze(args.dirs, args.min_games)
    else: ap.print_help()
