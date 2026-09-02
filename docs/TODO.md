# TODO ledger

Living list. Items move from *Open* to *Done* with the commit that closed them; nothing is deleted.

## Open

- [ ] Balance pass 2 after the full roster lands (see BALANCE_LOG.md)
- [ ] Per-map soak (10 min each) on all six maps with perf sampling
- [ ] Hero-specific first-person arm poses per weapon style (currently one generic two-handed/one-handed rig)
- [ ] Killcam (POTG exists; per-death killcam replay window not yet wired to the death screen)
- [ ] Voice chat is out of scope; text chat exists (console `say` not exposed in HUD input yet)

## Done

- [x] Fix the Play vs Bots crash: PlayMenu parse error, bot role-slot lockout, invalid mode/map
      combinations; add parse/UI/play smoke gates (c6c506d)

- [x] Project scaffold, sim core, ability framework, netcode, bot brain, presentation (67f0268)
- [x] Escort / Control / Hybrid / Push modes, sim harness, unit tests, asset library (123392e)
- [x] Tactical map bake + bot usage, status flags min_health_one/fire_rate_mult, multi-segment beams (6d8af18)
- [x] Environment exposure tuning, UI anchor fix, blocking screenshot capture (411857d)
- [x] Hero rig orientation fix, `rigshow` review command (this pass)
