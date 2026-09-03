# RINGFALL

A team-based hero shooter built in **Godot 4.7.2**: 5v5 objective combat, 18 mechanically distinct
Runners across three roles, hand-built maps, four objective modes, server-authoritative netcode
with prediction and lag compensation, and bots designed to be mistaken for people.

**Current content:** 18 heroes, all four modes implemented, and three playable maps (Nightmarket on
Push, Saltmarsh on Escort, Training Range on Control). Three further maps are designed but not yet
built, so Hybrid has no map to run on; see `docs/TODO.md`.

> Ten Runners. Two Charters. One Core.

- `docs/DESIGN.md` — world, tone, roster, maps, feel commitments
- `docs/HEROES.md` / `docs/heroes/*.md` — every hero's kit, numbers and counter-web
- `docs/MAPS.md` / `docs/maps/*.md` — every map's lanes, timings and story
- `docs/ARCHITECTURE.md`, `docs/NETCODE.md`, `docs/AI.md` — how it works
- `docs/BALANCE_LOG.md` — data-driven balance passes from the simulation harness
- `docs/AUTHORING.md` — how to add a hero or a map
- `docs/BLOCKERS.md` — environment limitations and what was done about them

## Requirements

- Godot **4.7.2** (Forward+ renderer; Vulkan). Download from https://godotengine.org/download/archive/4.7.2-stable/
- A GPU with Vulkan 1.1. On machines without one, the game runs on Mesa lavapipe (slowly).
- Linux export templates 4.7.2 for building binaries (`Editor → Manage Export Templates`).
- Python 3.10+ with `numpy scipy pillow` for the sim analysis and audio tooling.

## First run after cloning

Godot builds its `class_name` registry during import, so a fresh clone must be imported **once**
before scripts resolve each other. Opening the project in the editor does this automatically; from
the command line run:

```bash
godot --headless --path . --import
```

Skipping it produces a wall of "Identifier not declared" errors that are not real.

## Run

```bash
# Play (opens the main menu)
godot --path .

# Straight into a match against bots
godot --path . -- --cmd "map saltmarsh escort 9"

# Training range with a specific hero
godot --path . -- --cmd "map test_range control 4; wait 120; hero vesper"
```

The developer console opens with `` ` `` (tilde). `help` lists commands: `map`, `hero`, `status`,
`net_stats`, `lag`, `shot`, `cam*`, `timescale`, `set`.

## Dedicated server

```bash
godot --headless --path . -- --server --map=saltmarsh --mode=escort --port=27015 --bots=0
```

The server backfills empty slots with bots (`bot_fill`), accepts joins mid-match, hands pawns to
stand-in bots when a client drops, and restores them on reconnect. Clients connect from
`Main Menu → Join Match` with `address[:port]`. Hosting from the client (`Host Match`) runs the same
server in-process.

## Build

```bash
godot --headless --path . --export-release "Linux Client" build/linux/ringfall.x86_64
godot --headless --path . --export-release "Linux Dedicated Server" build/server/ringfall_server.x86_64
./build/server/ringfall_server.x86_64 --headless -- --server --map=kestrel --mode=control
```

## Tests and tooling

```bash
tools/parse_check.sh                           # parse gate: every .gd, catches runtime-only script errors
tools/test.sh                                  # GUT unit suite (combat math, statuses, codec, rays)
tools/check.sh saltmarsh escort 1800           # import + build data + headless bot match, lists script errors
tools/sim.py run --map kestrel --mode control --matches 40 --procs 4 --out sim_out/kestrel
tools/sim.py analyze sim_out/kestrel           # pick/win/K-D/damage/heal/ult-uptime/TTK tables
tools/net_stress.sh 150 0.1 40                 # bot match with simulated latency/loss/jitter
tools/screenshot.sh "map aurelia hybrid 9; wait 600; shot screenshots/aurelia.png; quit"
python3 tools/audio/gen_audio.py               # synthesize every referenced sound id
tools/godot.sh --headless res://tools/bake_tactical.tscn   # bake bot spatial data per map
tools/godot.sh --headless res://tools/build_data.tscn      # rebuild data/heroes/*.tres from builders
```

`tools/godot.sh` wraps the engine binary (set `GODOT_BIN` if yours is elsewhere) and serializes runs
through a lock so tooling can be automated safely.

## Controls (defaults)

WASD move · Space jump · Ctrl/C crouch · LMB primary · RMB secondary · Shift ability 1 · E ability 2
· F ability 3 · Q ultimate · R reload · V melee · G ping · Tab scoreboard · H hero select · Esc menu.
Everything is rebindable in Settings → Controls.

## Layout

```
project.godot            Godot project (Forward+, 60 Hz physics, input map, layers)
src/                     all code (see docs/ARCHITECTURE.md)
data/                    heroes, maps, modes, tuning, baked tactical data (resources/JSON)
assets/                  textures (ambientCG), HDRIs (Poly Haven), models/fonts/audio (Kenney + synthesized)
tools/                   check/test/sim/screenshot/audio/bake scripts
tests/unit/              GUT tests
docs/                    design and engineering documentation
```

## License and credits

Code is MIT (see `LICENSE`). Third-party assets are CC0 and listed with sources in `CREDITS.md`
and `ATTRIBUTION.md`.
