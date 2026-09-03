# TODO ledger

Living list. Items move from *Open* to *Done* with the commit that closed them; nothing is deleted.

## Open

- [ ] Three of six designed maps are unbuilt (Kestrel, Aurelia, Orchard/Meridian). Hybrid has no map.
- [ ] Time-to-kill is measured across a whole life, so disengages and healing inflate it. It needs a
      continuous-engagement window before it can be tuned against.
- [ ] Balance passes 1-4 were run before the seed-collision fix, so pass 4's stated 56 matches were
      really 32 distinct ones. Its conclusions still hold but its sample was half what it claimed.
- [ ] Coil's Tesla Node is 23% of his damage and also relays his chain; the 25-damage cut to his
      primary moved his output by only 4%. See BALANCE_LOG.md pass 5.
- [ ] Per-map soak (10 min each) with perf sampling; network stress run.
- [ ] Long audio (ambience, music) ships as WAV; converting those to OGG would cut ~60 MB.
- [ ] Headless runs abort with a heap error at shutdown *after* completing, which corrupts CI exit
      codes. Every gate currently has to be judged on its printed output, not its status.
- [ ] Voice chat is out of scope.

## Done

- [x] Fix the Play vs Bots crash: PlayMenu parse error, bot role-slot lockout, invalid mode/map
      combinations; add parse/UI/play smoke gates (c6c506d)

- [x] Project scaffold, sim core, ability framework, netcode, bot brain, presentation (67f0268)
- [x] Escort / Control / Hybrid / Push modes, sim harness, unit tests, asset library (123392e)
- [x] Tactical map bake + bot usage, status flags min_health_one/fire_rate_mult, multi-segment beams (6d8af18)
- [x] Environment exposure tuning, UI anchor fix, blocking screenshot capture (411857d)
- [x] Hero rig orientation fix, `rigshow` review command
- [x] First-person viewmodel rebuilt: per-archetype arm poses, gripped weapons, viewmodel projection (b28e158)
- [x] Prop placement audit + footprint-based placement; 636 findings down to 0 (aaeb2fc)
- [x] Static geometry merging, prop LOD, texture compression, detail-distance setting (965527b)
- [x] All 435 sounds render and load; audio coverage is complete (b44ef0b)
- [x] Bots stand on the objective; Push no longer stalls at 0-0 (38c34c4)
- [x] The five missing hero VFX modules (Vesper, Cadence, Ferry, Lumen, Suture); loop VFX now play (7222ae5)
- [x] Killcam on the death screen, and text chat in the HUD (22de1ae)
- [x] Generated docs/HEROES.md and docs/MAPS.md; README corrected to the real map count
- [x] Balance passes 1 and 2 with the data recorded in BALANCE_LOG.md
- [x] Every authored VFX id resolves; `area_vfx` is read by area effects (9274b08)
- [x] Exported server and client builds produced for the first time; fixed the registry finding no
      heroes or maps in an exported build, which broke every export completely (f5601d4)
- [x] Bots no longer hoard ultimates: support ult uptime roughly halved and usage rose (b51e0a6)
- [x] `HeroPicker` samples instead of taking the argmax, so comps vary and per-hero win rate
      measures the hero rather than the one comp the picker always built
- [x] `tools/sim.py` no longer hands overlapping seeds to separate runs, and `analyze` warns when
      the directories it is given repeat a match
- [x] Balance passes 3, 4 and 5 recorded in BALANCE_LOG.md; Cathedral and Cadence back in band (2a94a3b)
- [x] Escort scored a beaten distance as a draw, so the second attacker could only ever draw or
      deliver outright. It was the entire source of the side skew seen since pass 1
- [x] `ctx.ability` was null for every ability in the game, which mis-credited kills, left per-shot
      weapon bloom inert, and made the client draw every hitscan weapon and beam with a default
      presentation instead of its authored muzzle flash, tracer and impact VFX
- [x] Coil's Arc Gauntlet cut from 30 damage to 25; the highest damage and K/D in the game
- [x] 27 weapon fire/tail sounds were never rendered: fourteen hero primaries and secondaries were
      silent, and nothing reported it because the client never resolved their presentation. Wired
      into the audio manifest and rendered; all three maps now report zero missing sound ids
- [x] The prop audit reported only the first map when run over all of them, so a clean summary
      covered one map in three. All three now audit in one run: 404 props, 0 findings
- [x] Telemetry records damage per ability, not just per hero, so a lever can be identified before
      it is pulled rather than after two failed guesses
