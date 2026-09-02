# Netcode

## Transport: ENet (via `ENetMultiplayerPeer`)

Chosen over WebRTC and Steam sockets because it is built into Godot, gives us both
unreliable-sequenced and reliable-ordered channels on one UDP socket, has a tiny header, works
identically for the in-process offline server and remote dedicated servers, and needs no signaling
or platform SDK. Everything on the wire is our own binary format packed into `PackedByteArray`
and moved with four RPCs on `NetChannel`:

| RPC | Direction | Channel | Payload |
|---|---|---|---|
| `c_input` | client → server | unreliable ordered | last 3 `InputCmd`s (redundancy vs loss) |
| `c_msg` | client → server | reliable | hello / ready / ping / commands (hero select, chat) |
| `s_snapshot` | server → client | unreliable | delta-compressed world state |
| `s_event` / `s_msg` | server → client | reliable | batched events, welcome, roster |

## Ticks and clocks

- Server: fixed 60 Hz simulation (`Engine.physics_ticks_per_second`), snapshots every 2 ticks (30 Hz).
- Client: runs its own tick counter ahead of the server by a *lead* of 2–6 ticks. Every snapshot
  carries the average lead at which this client's inputs arrived; the client nudges its tick
  counter so inputs land just before they are needed. Late inputs are dropped and the server reuses
  the previous cmd with press/release edges cleared.
- The render clock for remote entities is `server_tick − interp_delay` (default 66 ms), advanced
  smoothly per frame; the client reports the tick it is rendering in every input for lag compensation.

## Input

`InputCmd` = tick, move (2×i8), yaw (u16), pitch (i16), buttons/pressed/released (3×u16), ack
snapshot id (u32), render tick (u32), hero request (i8), optional ping point. ≈22 bytes; three are
sent per tick (~4 KB/s upstream).

## Snapshots and delta compression

`NetCodec.capture_pawn` quantizes each pawn: position int32 @ 1/256 m, yaw u16, pitch i16,
velocity 3×i16 @ 1/64 m/s, health layers 4×u16, flags u16, anim u32, plus (for the owning client
only) full ability state (cooldowns @ 1/100 s, charges, ammo, reload, active timers, locks).

Per client the server stores the fields it sent in each snapshot (last 40). The client acks the
newest snapshot it decoded in every input. The next snapshot is written as a delta against that
acked baseline: a per-pawn field mask (pos/rot/vel/health/state/anim) and only changed groups.
If no baseline is acked (join, loss burst) the snapshot is full. Interest tiering: pawns farther
than 45 m and not visible to the client's pawn (occlusion test) are refreshed every third snapshot.

Measured on the training range with 10 pawns in a teamfight: 14–23 KB/s to one client at 30 Hz
(`status` console command prints the live number); idle spawn ~3 KB/s.

## Prediction and reconciliation

The client simulates its own pawn immediately with the same `Pawn.simulate` code as the server
and stores predicted position/velocity per tick. When a snapshot acknowledges input tick *T* it
applies the authoritative pawn state (position, velocity, view, health, ability cooldowns/ammo,
movement locks) and, if the predicted position at *T* differs by more than 2 cm, rewinds and
replays every unacknowledged input after *T* with edges cleared so abilities never re-fire. Large
corrections (>1.5 m, e.g. a teleport) reset physics interpolation to avoid a smear.

Ability presentation is predicted: the local client runs `AbilityEffect.predict()` which spawns
tracers, muzzle flashes, projectile visual twins and casting FX at once; the server's echo of the
same shot is used only to confirm hits (hitmarkers/damage numbers come from server `damage` events).

## Lag compensation (favor the shooter)

Every pawn records 64 ticks (~1.07 s) of position/crouch/alive history (`HitboxSet.record`).
Hit tests are analytic (head sphere + body capsule), so rewinding is exact: the server resolves a
hitscan against each victim's pose at the shooter's reported render tick, then checks static world
occlusion along the same ray. Projectiles use the rewound poses for their first 0.2 s of flight.
Rewind is clamped to the history window and never later than the current tick.

## Events

Reliable, batched per tick, per client, with interest filtering: damage/heal only to the parties
involved; footsteps within 28 m; VFX-class events within 90 m or involving the client. Hot event
kinds (hitscan, damage, footstep, heal) have hand-packed binary layouts; the rest use
`var_to_bytes` of a small dictionary.

## Anti-cheat posture

Clients send only intent: view angles, movement axes, buttons, and a claim of which server tick
they were rendering. Every damage, position, ability activation, cooldown, ammo count and
objective interaction is computed on the server. The render-tick claim is bounded to the history
window, so a client cannot "rewind" beyond 1 s; hero requests are validated against role limits.

## Join, leave, reconnect, backfill

`HELLO` carries a session token; a reconnecting client with a valid token gets its player record,
stats and hero back (a stand-in bot drove the pawn meanwhile). Late joiners receive a full state
dump of pawns, statuses, deployables and mode state, then snapshots. Leaving players are replaced
by bots after 60 s; `bot_fill` keeps both teams at team size every 2 s, removing bots when humans
join.

## Network condition simulation and testing

`lag <ms> <loss> <jitter>` (console) or the `network` settings section route the client's sends and
receives through `LagSimulator`. `tools/net_stress.sh 150 0.1 40` runs a bot match with those
conditions and prints ping, bandwidth, and reconciliation error. Unit tests cover codec round trips.
