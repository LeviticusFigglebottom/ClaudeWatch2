# Balance log

Every pass records the data it was based on, what changed, and what the next pass measured. Nothing
here is deleted; a reversed change is recorded as a later pass.

## Method

`tools/sim.py run` plays accelerated bot-vs-bot matches headlessly (four processes, roughly 7x real
time each) and writes one JSON per match. `tools/sim.py analyze <dirs>` aggregates them into the
tables below. Every match is 5v5 with hero picks chosen by `src/ai/HeroPicker.gd` under the normal
role limits, at Veteran difficulty.

    tools/sim.py run --map nightmarket --mode push --matches 8 --procs 4 --limit 480 --seed 1000 --out out/push
    tools/sim.py analyze out/push out/escort out/control

Columns: `picks` is hero-slots sampled, not matches. `dmg/10m` and `heal/10m` are per ten minutes
**alive**, so they are not diluted by respawn time. `ult uptime%` is the share of alive time spent
sitting at a full ult meter, which measures bot ult policy more than hero strength. `obj%` is the
share of alive time on the objective.

### What this data can and cannot show

- **Bot competence is not uniform across the roster.** Heroes whose damage depends on indirect fire
  or geometry read far worse than heroes who point and click. Ricochet needs discs to bounce before
  they arm, and Bombard lobs shells over cover; both sit near 3300-3900 dmg/10m while the field runs
  8000-14000. That is an AI limitation, not evidence that either hero is weak. Do not buff a hero on
  simulated damage alone when its kit needs a skill the bots lack.
- **Ult uptime above ~10% means ults are being hoarded, not that the ult is strong.** The support
  heroes show 14-30% because `BotDecision` holds their ults for a condition that rarely arrives.
- Sample sizes per hero are small (single digits to ~50 picks). A win rate on fewer than ~20 picks
  is noise. Changes below were made only where the sample supported them, and the log says where it
  did not.
- There are three maps and three mode pairings, so map-specific balance is out of reach. Hybrid has
  no map at all yet.

## Pass 1 — first measured baseline

48 matches (Nightmarket/Push 16, Saltmarsh/Escort 16, Training Range/Control 16), seeds 1000-3000
and 7000-9000. Team A won 24, B 18, 6 draws. Average duration 331 s. Time-to-kill, measured from
first damage on a life to death, median 8.55 s, p10 2.03 s, p90 45.38 s.

| hero | picks | win% | K/D | dmg/10m | heal/10m | ult uptime% | obj% |
|---|---|---|---|---|---|---|---|
| lumen | 49 | 32.7 | 2.49 | 8178 | 1016 | 0.9 | 18.3 |
| ricochet | 48 | 43.8 | 0.93 | 3332 | 0 | 1.0 | 28.6 |
| bombard | 48 | 35.4 | 2.15 | 3883 | 0 | 0.2 | 21.1 |
| suture | 44 | 31.8 | 2.06 | 5697 | 2739 | 13.9 | 19.6 |
| cadence | 37 | 64.9 | 2.48 | 4437 | 9863 | 27.0 | 28.6 |
| ferry | 35 | 51.4 | 2.04 | 4148 | 1450 | 8.0 | 21.7 |
| cairn | 33 | 30.3 | 2.52 | 10893 | 0 | 4.0 | 32.4 |
| harrier | 28 | 57.1 | 3.04 | 8390 | 0 | 0.7 | 30.0 |
| tallow | 27 | 44.4 | 2.63 | 6591 | 9567 | 17.3 | 22.6 |
| kiln | 25 | 28.0 | 3.63 | 12354 | 0 | 3.9 | 28.2 |
| cathedral | 25 | 64.0 | 5.65 | 14258 | 1543 | 27.9 | 25.9 |
| wisp | 18 | 38.9 | 3.29 | 8977 | 0 | 7.3 | 23.2 |
| vesper | 17 | 29.4 | 2.92 | 9769 | 0 | 0.3 | 23.8 |
| ballast | 12 | 66.7 | 8.53 | 12636 | 0 | 2.5 | 33.8 |
| coil | 12 | 58.3 | 7.57 | 19218 | 0 | 2.9 | 39.1 |
| sable | 12 | 83.3 | 2.96 | 13304 | 0 | 0.6 | 20.8 |
| bramble | 9 | 11.1 | 2.42 | 8962 | 716 | 9.1 | 23.8 |
| rook | 1 | 100.0 | 3.75 | 3540 | 0 | 0.0 | 10.2 |

### Findings

1. **Cadence was the clearest outlier with a usable sample.** 64.9% win over 37 picks, and 9863
   healing per ten minutes alive. Groove healed 12 per beat at 120 bpm, which is 24 hp/s to every
   ally inside 9 m, on a toggle with no cooldown and no resource. The next-best sustained team heal
   is Tallow's candles at 18 hp/s in 6 m, limited to three candles that expire and can be snuffed.
   Cadence's was unconditional and unlimited.
2. **Cathedral, a bulwark, was out-damaging every striker.** 14258 dmg/10m with a 5.65 K/D and a
   64% win rate over 25 picks.
3. **Kiln and Cairn invert the usual pattern:** top-three damage with the two worst win rates
   (28.0% and 30.3%). High output that does not convert. Left alone pending a look at whether bots
   simply feed with them.
4. **Ricochet is the only hero under a 1.0 K/D** and has the lowest damage in the game. Read as the
   bot-competence caveat above rather than a hero problem.
5. **Rook is almost never picked** (1 slot in 48 matches). That is a `HeroPicker` weighting issue,
   not balance, and it means Rook has no data at all.

### Changes

| Change | From | To | Why |
|---|---|---|---|
| Cadence Groove heal per beat | 12 | 8 | 24 hp/s unconditional team sustain cut to 16 hp/s; still the strongest aura in the game |
| Cathedral Reliquary Mace damage | 70 | 58 | Reduce a bulwark's striker-level output |

Also corrected the mace description, which promised "each enemy struck heals you for 8". No such
effect was ever implemented, so the text was wrong rather than the behaviour.

## Pass 2 — verification, same seeds

24 matches, seeds 1000-3000, so this is a like-for-like rerun of the first half of pass 1 with only
the two changes above differing.

| hero | picks | win% (p1 → p2) | heal/10m (p1 → p2) | dmg/10m (p1 → p2) |
|---|---|---|---|---|
| cadence | 15 | 80.0 → 66.7 | 9274 → 8322 | 4467 → 4595 |
| cathedral | 9 | 55.6 → 77.8 | 1804 → 1670 | 16337 → 16296 |

### Findings

1. **The Cadence change landed and did roughly what it should.** Win rate fell 13 points and
   healing fell about 10%. Healing fell less than the 33% cut to the aura because her on-beat shell
   heals 30 in a 4 m radius on hit, and that is untouched: the aura was a smaller share of her
   output than expected. She is still above a healthy band and is a candidate for pass 3.
2. **The Cathedral change was aimed at the wrong ability.** His damage per ten minutes did not move
   at all (16337 → 16296). Reading the kit again: the mace is one of two 70-damage sources, and the
   other is Censer, a 4 m burst on a 9 s cooldown that also applies a burn. With bots now brawling
   on the objective (see the AI change in commit 38c34c4) targets are clustered, so the AoE, not the
   mace, is carrying his numbers. His win rate went *up*, but on 9 picks that is noise either way.
3. Side skew was much stronger in this batch (A 18, B 5) than in pass 1 on the same seeds (A 12,
   B 9). With one batch it cannot be told apart from variance.

### Changes

None. Pass 2 was a verification run, and the Cathedral result says to measure before nudging again
rather than change a second lever on a 9-pick sample.

## Next pass

1. **Cathedral, with a real sample.** The lever to test is Censer's burst damage or its radius, not
   the mace. Needs at least 25 Cathedral picks before and after.
2. **Cadence again.** If she stays above roughly 60% with a decent sample, the next lever is the
   on-beat shell heal (30 in 4 m), which pass 2 showed is the larger part of her healing.
3. **Kiln and Cairn.** Determine whether the low win rate is the hero or bots feeding with it, by
   reading their death positions and objective time rather than by changing numbers.
4. **Rook needs picks.** Fix the `HeroPicker` weighting so it appears, then it can be measured.
5. **Ult hoarding.** 14-30% ult uptime on the supports is a bot policy problem in `BotDecision`, and
   it distorts every support's apparent strength. Worth fixing before trusting support win rates.
6. **Time-to-kill.** A median of 8.55 s from first damage to death is long for the genre, but the
   measure spans an entire life including disengages and healing, so it needs a cleaner definition
   (damage within a continuous engagement window) before it can be tuned against.
