# HANDOFF — state of the build, and what to do next

Written at the point where the parallel authoring pass was cut off by usage limits. Everything
below was **verified by running it**, not assumed. Commands quoted here are the exact ones used.

Branch: `claude/game-repo-setup-q94hom`

---

## 1. Where we are in one paragraph

The engine, the simulation, the netcode, the bot AI and the presentation layer are **complete and
working**. All **18 heroes exist, build, and play** — full-roster bot matches run with **zero
script errors** across three maps and three modes. **Two of the six designed maps are built and
playable** (Nightmarket Vertical on Push, Saltmarsh Terminal on Escort), plus the training range;
Kestrel, Aurelia, Orchard and Meridian do not exist yet. The UI has all 13 screens written but only
4 are screenshot-verified. **Audio is the largest single gap: 0 sound files exist.** Per-hero and
per-map design docs were never written, and nothing has been balance-tested with data.

Scale: 29,091 lines of GDScript across 203 source files, 18 hero builders, 18 passing unit tests.

---

## 2. Verified working (with the evidence)

| System | Status | How it was verified |
|---|---|---|
| Project import | Clean | `tools/godot.sh --headless --import` → 0 errors |
| 18 hero data build | Clean | `tools/godot.sh --headless res://tools/build_data.tscn` → "built 18 heroes" |
| Full-roster match | Clean | `map test_range control 9; wait 1800` → 0 SCRIPT ERROR, 0 missing props, bots at 5/0, 4/1, 6/0 K/D |
| Nightmarket (Push) | Clean | `map nightmarket push 9; wait 1800` → 0 SCRIPT ERROR, 0 missing props, push phase advancing |
| Saltmarsh (Escort) | Clean | registered this session; `map saltmarsh escort 9; wait 2400` → 0 SCRIPT ERROR, 0 missing props |
| Multi-seed bot sweep | Clean | 7 sim matches across 3 maps / 3 modes / varied comps → **0 SCRIPT ERROR total** |
| Unit tests | 18/18 pass | `tools/test.sh` — health layers, hitbox rays, net codec, status stacking, re-entrancy |
| Netcode under load | Works | 20–31 KB/s to one client at 30 Hz, server tick 4.4–5.1 ms with 10 pawns |
| Screenshot harness | Works | `tools/screenshot.sh` under Xvfb + lavapipe; FP/TP/overview/rig views captured and reviewed |
| Visual regression | Works | `tools/visual_check.py screenshots/*.png` → 13 files, 0 failed |
| **Parse gate** | Clean | `tools/parse_check.sh` → 232 scripts, 0 parse errors, 20 s |
| **UI smoke** | Clean | `tools/ui_smoke.tscn` → all 12 screens/overlays instantiate and render, 0 errors |
| **Play vs Bots end to end** | Works | `tools/play_smoke.tscn` → menu → hero select → spawned as Vesper on Nightmarket/Push, alive at 8 s, 10 pawns, 0 errors |

**Do not re-litigate these.** They are done. Spend the next session's budget on §4 and §5.

---

## 3. Bugs fixed while assessing

Seven real bugs. Worth reading — the same classes will recur as more content lands:

1. **`ClientWorld` assigned freed instances.** `projectile_visuals` is a pooled dictionary whose
   nodes `queue_free()` on impact; the typed lookup `var pv: ProjectileVisual = dict.get(id)` throws
   once the node is gone. Fixed with a `_projectile_visual(id)` helper that validates and erases
   stale entries. **Any pooled-node dictionary needs this pattern.**
2. **Nightmarket never loaded.** A stray `_ = col` discard statement (a Go/Python idiom GDScript
   does not accept) was a parse error, so the map failed to load, there was no `Layout`, and every
   pawn spawned at the origin and fell to `kill_z`. A map that "runs but everyone dies instantly"
   almost always means the builder failed to parse — check for the parse error above the match log.
3. **40 props were silently missing on Nightmarket.** Map code called `prop("car_kit/sedan", ...)`
   without the `.glb` extension. `PropLibrary` now resolves optional `.glb`/`.gltf` and
   dash/underscore variants, so both spellings work. This was invisible except as warnings — the
   map just quietly had no cars in it.
4. **`StatusController.step()` indexed an array that death emptied underneath it.** A
   damage-over-time tick can kill the pawn; death calls `clear_all()` re-entrantly; the loop then
   read `active[i]` out of bounds. Now iterates a snapshot and re-checks membership after every
   call that can re-enter. Covered by a new regression test.
5. **The Play vs Bots menu path was broken in three separate ways**, none of which any headless
   bot match could catch, because every automated test so far used the console `map` command and
   bypassed the UI entirely. A player hit all three:
   - `PlayMenu` had a parse error (`var team := [5, 6, 3, 1][i]` cannot infer from an untyped array
     literal). The screen crashed the moment it was opened. Root cause was `RF.ROLE_LIMIT` being an
     untyped array; it is now `Array[int]`.
   - Bots filled all five role slots before a joining human picked, so the 1/2/2 role limit
     rejected **every** hero and the player was stuck at hero select permanently. Bots now yield a
     contested hero or role slot to a human and re-pick into a role with room.
   - The menu offered modes with no map, then fell back to listing every map, producing invalid
     combinations such as Hybrid on a Push-only map. It now lists only modes that have a map.
6. **Deployables outlived their owner pawn and kept a dangling reference** — 2,791 errors in a
   single 2-match sim once Bramble's thicket was in a comp, and it would have hit almost every
   hero with a placeable. `SimWorld.remove_pawn()` now severs owner references held by
   deployables, projectiles, homing targets and status instances; `DamagePipeline` degrades a
   freed source to environment damage; `Deployable.owner_alive()` is the accessor hero code should
   gate on. **Hero authors: never assume `owner_pawn` is alive.**

---

## 4. What is incomplete, in priority order

### P0 — Audio: nothing exists (blocks "nothing ships unsounded")

`tools/audio/synth.py` and `tools/audio/recipes.py` were written; **`gen_audio.py`, the manifest,
and all sound files were not.** `assets/audio/` contains 0 files. Every sound id referenced by the
18 heroes' `AbilityPresentation` resources currently resolves to the fallback click.

**Next step:** read the two existing files, then write `tools/audio/manifest.json` and
`tools/audio/gen_audio.py` per the spec in this file's §6, and run it. Verify with:
```bash
tools/godot.sh --headless -- --client --cmd "map test_range control 9; wait 900; quit" 2>&1 \
  | grep "missing sound id" | sort -u
```
That list is the exact work queue; it should end up empty.

### P0 — Maps: 4 of 6 missing or unregistered

| Map | Mode | Builder | `.tscn` | `data/maps/*.tres` | Playable |
|---|---|---|---|---|---|
| Nightmarket Vertical | Push | ✅ 743 lines | ✅ | ✅ | ✅ verified |
| Saltmarsh Terminal | Escort | ✅ 1149 lines | ✅ | ✅ | ✅ verified |
| Kestrel Summit | Control | ❌ empty dir | ❌ | ❌ | ❌ |
| Aurelia Bazaar | Hybrid | ❌ empty dir | ❌ | ❌ | ❌ |
| Orchard Reach | Escort/Hybrid | ❌ | ❌ | ❌ | ❌ |
| Meridian Station | Control | ❌ | ❌ | ❌ | ❌ |

**Saltmarsh was registered and validated this session** — the builder was already complete, so it
only needed a `.tscn` and a `MapData` resource. Escort is now covered.

Build **Kestrel (Control)** and **Aurelia (Hybrid)** next so all four modes have a real map; their
directories exist but are empty. Orchard and Meridian are the stretch to clear the 5-map floor.
Neither Kestrel nor Aurelia has any code — budget a full map's work for each.

### P1 — Per-hero and per-map design docs: 0 written

`docs/heroes/` and `docs/maps/` are **empty directories**. `docs/HEROES.md` and `docs/MAPS.md`
don't exist yet either, but `tools/gen_docs.tscn` was written to generate them from the built data —
just run it:
```bash
tools/godot.sh --headless res://tools/gen_docs.tscn
```
The per-hero notes (identity, kit table, counter reasoning, TTK math, bot behavior, limitations)
still need to be written by hand, 18 of them.

### P1 — Balance: never run

`docs/BALANCE_LOG.md` does not exist. No tuning telemetry has been collected. The harness and
analyzer both work.

**Correction to an earlier reading:** a lopsided K/D spread seen via the `map` console command is a
**test artifact, not a balance bug**. That path seats the headless client as a real player who
never picks a hero, so one team plays 4v5. Always balance-test through `--sim`, which seats 10
bots. Confirmed: in true 5v5 sims the spread disappears.

Two genuine signals to check on the first real pass:
- **Objective scoring never fires in short sims.** Every sim so far ends `score [0, 0]`. For
  Control that is the 150 s limit versus a 30 s unlock plus 100 s of progress — raise the limit to
  **≥ 400 s for Control/Escort** before concluding anything. Verify a round can actually complete.
- **Median TTK measured 14.6 s** (first damage → death). Before tuning damage down or up, confirm
  what the metric means: it spans disengages and healing in a 5v5 with two Conduits per side, so it
  is not the same number as a focused duel's time-to-kill.

```bash
python3 tools/sim.py run --map nightmarket --mode push --matches 40 --procs 4 --out sim_out/nm
python3 tools/sim.py analyze sim_out/nm
```
Sims run ~4.5x real time per process, so 40 matches at a 300 s limit across 4 processes is roughly
half an hour. Write each pass into `docs/BALANCE_LOG.md` with the data that motivated it.

### P2 — Hero VFX modules: 5 of 18 missing

Present: ballast, bombard, bramble, cairn, cathedral, coil, harrier, kiln, ricochet, rook, sable,
tallow, wisp.
**Missing: vesper, cadence, lumen, suture, ferry.** These heroes fall back to generic particle
recipes — they work, they just have no signature look.

### P2 — UI: written but mostly unverified

All 13 screens exist. Only MainMenu, HUD, HeroSelect and Connecting have been screenshot-reviewed.
**Scoreboard, PauseMenu, SettingsMenu, PostMatch, Lobby, Training have never been rendered.** The
POTG replay path in PostMatch has never been executed end-to-end.

### P3 — Remaining

- Tactical bake has never been run over the real maps: `tools/godot.sh --headless res://tools/bake_tactical.tscn`
- Soak tests (`tools/soak.sh`) and the net-stress run were started but not reviewed.
- Export presets are written and templates installed, but **no build has ever been produced**.
- A heap corruption message (`malloc_consolidate(): invalid chunk size`) appears **at process exit**
  on some runs. It has never affected a match in progress. Worth one look, not a blocker.

---

## 5. Recommended order for the next session

1. **Write `gen_audio.py` + manifest, generate all audio, verify no missing ids.** Biggest single
   quality win; the whole game is currently silent.
2. **Build Kestrel (Control) and Aurelia (Hybrid).** Follow `docs/AUTHORING.md` §Maps and use
   Nightmarket (743 lines) and Saltmarsh (1149 lines) as references for scale and dressing density.
4. **Run `gen_docs`, then write the 18 hero notes and the map notes.**
5. **Balance pass 1**: 40+ matches per map/mode, analyze, tune, log. Investigate the Team A skew.
6. **Screenshot and fix the 6 unverified UI screens**; exercise the POTG replay.
7. **Fill the 5 missing hero VFX modules.**
8. **Bake tactical data, run soaks, produce both export builds.**

Parallelize with subagents again — the file-ownership discipline from the last pass worked; there
were **zero merge conflicts across 8 concurrent agents**. Keep the same rules: one agent owns a
disjoint file set, never touches shared code, appends to `docs/REQUESTS.md` when blocked.

---

## 5b. Test discipline (this is how a crash reached a player)

Every automated check up to that point drove the game through the console `map` command, which
skips the entire menu. The UI was therefore completely untested, and a parse error in the play
screen shipped. Three gates now cover that gap and **all three should run before saying anything
works**:

```bash
tools/parse_check.sh                      # every .gd, catches runtime-only script errors, 20 s
tools/godot.sh --headless res://tools/ui_smoke.tscn        # all 12 screens instantiate + render
tools/godot.sh --headless res://tools/play_smoke.tscn      # the real menu -> match path
```

`--import` alone is **not** a parse check. It imports a broken UI screen without complaint.
Both smoke tests carry watchdogs: an unguarded failure previously left Godot running forever and
held the tool lock, which blocks every other run in the repo.

---

## 6. Traps discovered the hard way (read before writing code)

- **`set_anchors_preset` keeps the current rect.** Calling it in `_ready` on a zero-sized Control
  leaves it zero-sized, so full-screen UI collapses into the top-left corner. Always use
  **`set_anchors_and_offsets_preset`**.
- **`enum Resource` shadows a native class** and breaks the whole dependency chain. Renamed to
  `Cost`. Don't name an enum after a Godot class.
- **`extends SceneTree` tool scripts can't touch autoloads.** All tools are `extends Node` with a
  one-node `.tscn` wrapper, run as `tools/godot.sh --headless res://tools/x.tscn`.
- **Shell redirect order matters when grepping logs.** `cmd 2>&1 > log` sends stderr to the
  *terminal*, not the file — it will make a broken run look clean. Always `cmd > log 2>&1`.
- **Forward is −Z.** A camera at −Z with yaw 180 sees a rig's front. Rig extras mount at +Z.
- **Limb rotation sign**: limbs extend along −Y, so a *positive* X rotation swings them forward.
- **Godot's ray queries ignore shapes the origin is inside**, which is exactly why Cathedral's
  barrier dome lets allies inside shoot out while blocking incoming fire. Don't "fix" that.
- **`prop()` paths take an optional extension now** — but prefer writing `.glb` explicitly.
- **Pooled-node dictionaries must validate on read** (see §3.1).
- **Entities outlive pawns.** Deployables, projectiles and statuses can all survive their owner's
  death. Gate on `Deployable.owner_alive()`; never touch `owner_pawn` unguarded.
- **Anything that applies damage inside a loop can kill the target and mutate the list you are
  iterating.** Snapshot, then re-check membership.
- **Balance-test via `--sim`, never via the `map` console command** — the latter is 4v5 (§4).
- **The console `map` command is not a test of the game.** It bypasses the menu, hero select and
  composition rules. Use the smoke tests in §5b for anything a player actually touches.
- **Untyped array literals poison `:=`.** `[1, 2, 3][i]` is Variant, so `var x := arr[i]` fails to
  infer. Type the constant (`const X: Array[int] = ...`) or annotate the variable.
- **Bots must always yield to humans** in composition rules; a strict limit locks players out.
- **A fresh clone must be imported once** (`godot --headless --path . --import`) before any script
  check, or every `class_name` reads as undeclared and you get hundreds of false failures.
  `tools/parse_check.sh` now does this automatically when `.godot/` is missing.
- Godot runs are serialized through a lock in `tools/godot.sh`. Parallel agents will wait on it;
  keep individual sim limits ≤ 200–300 s so nobody starves.

---

## 7. Command reference

```bash
tools/check.sh <map> <mode> <ticks>     # import + build data + headless match, lists script errors
tools/test.sh                           # GUT unit suite
tools/godot.sh --headless res://tools/build_data.tscn      # rebuild data/heroes/*.tres
tools/godot.sh --headless res://tools/gen_docs.tscn        # regenerate docs/HEROES.md + MAPS.md
tools/godot.sh --headless res://tools/bake_tactical.tscn   # bake per-map bot spatial data
tools/sim.py run --map X --mode Y --matches 40 --procs 4 --out sim_out/X
tools/sim.py analyze sim_out/X
tools/screenshot.sh "map X mode 9; wait 600; shot screenshots/x.png; quit"
tools/visual_check.py screenshots/*.png
tools/net_stress.sh 150 0.08 40 2400
tools/soak.sh <map> <mode> <minutes>
```

In-game console (`` ` ``): `map`, `hero`, `rigshow`, `status`, `perf`, `net_stats`, `lag`, `shot`,
`cam`, `cam_follow`, `cam_overview`, `timescale`, `set`.
