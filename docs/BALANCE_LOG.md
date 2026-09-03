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

## Pass 3 — larger sample at the pass-1 numbers

32 matches, seeds 4000-6000. (Intended 56: several batches were written into one `--out` directory
and later seeds overwrote earlier files, since match filenames only encode map, mode and index. Use
one directory per seed.)

| hero | picks | win% | dmg/10m | heal/10m |
|---|---|---|---|---|
| cadence | 31 | 45.2 | 5290 | 8007 |
| cathedral | 14 | 71.4 | 13593 | 1543 |
| kiln | 19 | 21.1 | 12158 | 0 |

### Findings

1. **Cadence is fixed.** 64.9% over 37 picks before the change, 45.2% over 31 picks after. Healing
   fell from 9863 to 8007 per ten minutes alive.
2. **Cathedral was still an outlier** at 71.4%, and his damage had barely moved, confirming pass 2's
   reading that Censer rather than the mace carries him.
3. **Kiln is now a real finding, not noise.** 28.0%, 23.5%, 21.1% across three passes and roughly
   60 cumulative picks, with the second-highest damage in the game every time.

### Changes

| Change | From | To | Why |
|---|---|---|---|
| Cathedral Censer burst damage | 70 | 52 | The actual source of a bulwark's striker-level output, and it got stronger when bots began clustering on the objective |

## Pass 4 — verification, largest sample

56 matches, seeds 4000-6000, one output directory per seed. Team A won 30, B 20, 6 draws. Average
duration 322 s.

| hero | picks | win% | K/D | dmg/10m | heal/10m | obj% |
|---|---|---|---|---|---|---|
| bombard | 71 | 46.5 | 2.30 | 3662 | 0 | 20.3 |
| lumen | 65 | 43.1 | 2.93 | 7538 | 970 | 18.4 |
| cadence | 56 | 53.6 | 2.03 | 4720 | 7517 | 26.3 |
| ferry | 42 | 35.7 | 1.41 | 3677 | 1489 | 16.7 |
| suture | 41 | 39.0 | 2.34 | 4869 | 2828 | 21.9 |
| cairn | 39 | 53.8 | 4.09 | 9896 | 0 | 35.9 |
| harrier | 38 | 39.5 | 2.20 | 8530 | 0 | 27.3 |
| vesper | 31 | 41.9 | 3.18 | 8985 | 0 | 21.4 |
| kiln | 27 | 25.9 | 3.29 | 12691 | 0 | 30.3 |
| ricochet | 24 | 45.8 | 1.12 | 3810 | 0 | 28.9 |
| wisp | 21 | 19.0 | 2.35 | 8962 | 0 | 17.9 |
| cathedral | 20 | 55.0 | 3.75 | 13211 | 1568 | 20.7 |
| tallow | 20 | 55.0 | 3.03 | 6393 | 9039 | 21.1 |
| bramble | 19 | 63.2 | 3.75 | 8938 | 557 | 28.4 |
| ballast | 19 | 52.6 | 7.41 | 12477 | 0 | 30.1 |
| sable | 11 | 63.6 | 2.65 | 10936 | 0 | 18.8 |
| coil | 9 | 55.6 | 6.35 | 13979 | 0 | 32.2 |
| rook | 7 | 14.3 | 1.06 | 3837 | 0 | 28.6 |

### Findings

1. **Both changes did what they were meant to.** Cathedral 64.0 → 71.4 → **55.0%** once the right
   ability was cut, with damage 14258 → **13211**. Cadence 64.9 → **53.6%** on a 56-pick sample.
   Neither is an outlier any more, and neither was gutted: both sit slightly above even.
2. **Kiln is the clearest remaining problem.** 25.9% on 27 picks, and 21-28% in every pass so far,
   while posting the highest damage in the game. Damage that does not convert to wins.
3. **Wisp is consistently low** (19.0% here, 10-39% across passes) on middling damage.
4. **Rook now gets picked** occasionally (7 slots, up from 1) but is still under-sampled.
5. **Persistent side skew:** team A has won more in every batch (24/18, 18/5, 17/10, 30/20). Across
   160 matches that is unlikely to be pure variance and is worth a look at spawn advantage or the
   attacker-first ordering in the symmetric modes.

### Changes

None. Pass 4 was a verification run and both targets landed in band.

## Next pass

1. **Kiln.** Four passes, ~90 picks, 21-28% win with the highest damage in the game. Before touching
   a number, read where Kiln dies and how the bots spend Heat: this looks like output that never
   converts, which is usually positioning or resource policy rather than tuning.
2. **Wisp**, same treatment: consistently low across passes on ordinary damage.
3. **The side skew.** Team A has won more in all four batches (89 to 53 overall). Check spawn
   advantage and the attacker-first ordering in the symmetric modes before reading any more
   per-hero win rates, because a systematic side bias contaminates all of them.
4. **Rook needs picks.** `HeroPicker` selects it 7 times in 56 matches where the average hero gets
   30. Fix the weighting, then it can be measured.
5. **Ult hoarding.** 16-23% ult uptime on the supports is a bot policy problem in `BotDecision`, and
   it distorts every support's apparent strength. Worth fixing before trusting support win rates.
6. **Time-to-kill.** A median near 8.9 s from first damage to death is long for the genre, but the
   measure spans an entire life including disengages and healing, so it needs a cleaner definition
   (damage within a continuous engagement window) before it can be tuned against.
