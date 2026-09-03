# TODO ledger

Living list. Items move from *Open* to *Done* with the commit that closed them; nothing is deleted.

## Open

- [ ] Three of six designed maps are unbuilt (Kestrel, Aurelia, Orchard/Meridian). Hybrid has no map.
- [ ] Balance pass 3: Cathedral's Censer is the lever, not the mace; Cadence may need one more cut.
      See BALANCE_LOG.md "Next pass" for the full list.
- [ ] `HeroPicker` almost never picks Rook (1 slot in 48 matches), so Rook has no balance data.
- [ ] Bots hoard support ultimates (14-30% ult uptime), which distorts every support's win rate.
- [ ] 26 VFX ids across 13 heroes resolve to the generic fallback (8 loop, 18 area). `area_vfx` is
      authored on abilities but never read by any client code, so area telegraphs are unwired.
- [ ] Per-map soak (10 min each) with perf sampling; network stress run.
- [ ] Export builds have never been produced or launched (two presets are configured).
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
