# Architecture

RINGFALL is a Godot 4.7.2 project written in statically-typed GDScript. The simulation is
server-authoritative and runs at a fixed 60 Hz tick; presentation is entirely client-side and never
touches simulation state. The same code path serves offline play (in-process server + client),
listen-server hosting, and a headless dedicated server.

```
                ┌──────────────────────────── one process ────────────────────────────┐
                │  /root/Main                                                          │
   offline /    │   ├── World                                                          │
   host         │   │    ├── Server (GameServer)  ── MultiplayerAPI #1 ── ENet server  │
                │   │    │    ├── ServerViewport (own World3D)                          │
                │   │    │    │    └── World (SimWorld): Map, Pawns, Projectiles, ...   │
                │   │    │    ├── Bots (BotController × N) ── BotBrain                  │
                │   │    │    ├── Mode (ModeController subclass)                        │
                │   │    │    ├── Coordinator_0 / Coordinator_1 (TeamCoordinator)       │
                │   │    │    └── Net (NetChannel: RPC endpoint)                        │
                │   │    └── Client (GameClient) ── MultiplayerAPI #2 ── ENet client    │
                │   │         ├── World (SimWorld, is_server=false): predicted local    │
                │   │         │    pawn + interpolated remote pawns + map (visual)      │
                │   │         ├── Presentation (ClientWorld): visuals, VFX, audio, HUD  │
                │   │         ├── Input (InputCollector)                                │
                │   │         └── Net (NetChannel)                                      │
                │   └── UI (CanvasLayer) ── UIRouter screens/overlays                   │
                └──────────────────────────────────────────────────────────────────────┘
```

`SceneTree.set_multiplayer(api, path)` gives the Server and Client branches independent
MultiplayerAPIs, so the in-process client talks to the in-process server over a real ENet socket on
localhost — offline play exercises the exact netcode used online. The server's world lives in a
`SubViewport` with its own `World3D`, so server and client physics never touch.

## Module map

| Directory | Responsibility | Depends on |
|---|---|---|
| `src/core` | `RF` constants, `Registry` (content discovery), `Settings`, `Console`, `EventBus` | — |
| `src/data` | Resource classes: `HeroData`, `AbilityData`, `StatusData`, `MapData`, `ModeData`, tuning, profiles | core |
| `src/combat` | `SimWorld`, `HealthComponent`, `StatusController`, `DamagePipeline`, `HitboxSet`, `Projectile`, `Deployable`, `HealthPack` | data |
| `src/abilities` | `Ability` (runtime lifecycle), `AbilityRunner`, `AbilityEffect` library, `AbilityBehavior` hooks | combat, data |
| `src/heroes` | `Pawn`, `MovementController`, `PlayerStats`, per-hero behaviors/deployables | combat, abilities |
| `src/modes` | `ModeController` + Escort/Control/Hybrid/Push, `MapLayout` | combat |
| `src/maps` | `MapBuilder` DSL, `MaterialLibrary`, `PropLibrary`, per-map builders | modes |
| `src/ai` | `BotController`, `BotBrain` (perception, aim, navigation, decision), `TeamCoordinator`, `HeroPicker`, `TacticalMap` | heroes, modes |
| `src/net` | `GameServer`, `GameClient`, `NetCodec`, `NetChannel`, `InputCmd`, `PlayerState`, `LagSimulator`, telemetry, replay recorder | everything above |
| `src/client` | `ClientWorld`, `PawnVisual`/`HeroRig`, `FirstPersonRig`, `VfxLibrary`, `AudioLibrary`, projectile/deployable visuals, `ReplayPlayer` | heroes, net |
| `src/ui` | `UITheme`, `UIRouter`, screens | client |
| `src/sim` | `SimHarness` headless match runner | net |
| `src/app` | `App` flow, `Main.tscn` | all |

Dependency direction is downward in this table: presentation depends on simulation, never the
reverse. Hero content depends only on `abilities`/`combat` interfaces documented in
`docs/AUTHORING.md`. There are no circular class dependencies; cross-cutting communication goes
through `SimWorld.sim_event` (simulation → owner) and `EventBus` (client presentation → UI).

## Simulation loop

Each server tick (`GameServer._tick`):
1. Gather one `InputCmd` per player (queued network cmd for this tick, a bot's `think()`, or the
   last cmd with edges cleared when a packet is late).
2. `Pawn.simulate(cmd, dt)`: view angles → `StatusController.step` (DoT/HoT batching,
   modifier aggregation) → `MovementController.step` (deterministic Quake-style movement with
   ability-driven velocity overrides) → `AbilityRunner.step` (cooldowns, casts, channels, bursts,
   effects) → hero behavior tick → regen/ult passive → hitbox history record.
3. `SimWorld.step_entities`: projectiles (analytic sweeps), deployables, pickups.
4. `ModeController.step`: phases, contest, scoring, overtime.
5. Respawns, coordinators, telemetry, replay recorder.
6. Every 2nd tick: snapshots; every tick: reliable event flush.

Damage is resolved only through `SimWorld.apply_damage → DamagePipeline.resolve_damage`:
team/self rules → invulnerability/spawn protection → headshot multiplier → outgoing/incoming
modifiers (statuses + hero behaviors) → health layers (overhealth → shield → armor(flat
reduction) → health) → ult charge/stats → knockback → death (assists, streaks, role passives).

## Content model

Everything a hero *is* lives in `data/heroes/<id>.tres`, generated from a builder script by
`tools/build_data.tscn`. An ability is `AbilityData` = timing/resource rules + a list of
`AbilityEffect` resources (composition) + an optional `AbilityBehavior` script for unique logic.
Statuses are `StatusData` resources with flags/modifiers; `StatusController` aggregates them.
Maps are code-authored (`MapBuilder`) so lanes and cover are reviewable, and they publish a
`MapLayout` the modes and AI read.

## Client presentation

`GameClient` predicts the local pawn with the same `Pawn.simulate` and reconciles against
server snapshots (rewind + replay of unacked inputs). Remote pawns are interpolated between
snapshots with a configurable delay. `ClientWorld` turns simulation events (both predicted-local
and server-sent) into tracers, impacts, damage numbers, hitmarkers, audio, and hero animation.
Local feel lives in `FirstPersonRig` (kick, sway, bob, hitstop, trauma shake, flinch, FOV).

## Tooling

- `tools/check.sh` — import, build data, run a headless bot match, list script errors.
- `tools/test.sh` — GUT unit suite.
- `tools/sim.py` — parallel headless matches + telemetry analysis.
- `tools/bake_tactical.tscn` — bake per-map tactical nodes.
- `tools/screenshot.sh` — capture frames through the console (`map`, `cam`, `shot`).
- `tools/audio/gen_audio.py` — synthesize every referenced sound id.
