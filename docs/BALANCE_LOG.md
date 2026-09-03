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

Each match's seed is `--seed * 1000000 + proc * 1000 + index`, so two runs with different `--seed`
values can never share a match. `analyze` counts a repeated map/mode/seed as one match and says so,
because two runs of the same seed are the same match and adding them together only inflates `n`.

`--limit` must cover every round: a truncated round is scored for whoever was ahead, which flatters
the team that attacks first. `tools/sim.py run` warns when the limit is too short for the mode.

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
- **Ult uptime above ~10% means ults are being hoarded, not that the ult is strong.** Through pass 4
  the support heroes showed 14-30% because `BotDecision` held their ults for a condition that rarely
  arrived. Pass 5 added a patience term that raises the urge to fire the longer an ult sits ready,
  and the supports now sit near 10-12%. Read any figure above that as policy, not power.
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

> **Correction (pass 5).** Only 32 of those 56 matches were distinct. `tools/sim.py` derived each
> process's seed as `--seed + proc * 1000`, so two runs whose `--seed` differed by less than
> `1000 * --procs` shared most of their matches, and separate output directories preserved the
> duplicates instead of hiding them. The findings below still hold — the duplicated matches were
> real matches, just counted twice — but the sample was half the size stated, and every per-hero
> pick count on this page should be read as approximately doubled. Passes 1, 2 and 3 are unaffected;
> their seeds do not overlap. The seed layout is fixed and `analyze` now warns about repeats.

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

## Pass 5 — repairing the measurement, then re-measuring

Pass 5 changed one hero number. Four of the five items pass 4 left for "next pass" turned out to be
properties of the harness or the bot code rather than of any hero, so this pass fixed those and then
re-measured from scratch. Every figure from passes 1-4 that ranked heroes against each other should
be treated as superseded.

### 1. Kiln was never weak

Kiln read 21-28% across four passes while posting the highest damage in the game. A controlled
mirror settles it: both teams play Vesper, Harrier, Suture and Ferry, and only the bulwark slot
differs. 16 matches per pairing on Training Range/Control, sides swapped halfway so neither hero
gets the spawn.

| matchup | Kiln wins | opponent wins | draws |
|---|---|---|---|
| Kiln vs Cairn | 4 | 0 | 12 |
| Kiln vs Cathedral | 6 | 5 | 5 |

Kiln is fine. Its win rate was measuring the composition the picker always built around it. With the
picker fixed (below) Kiln reads 52.9% over 34 picks.

### 2. The hero picker was measuring compositions, not heroes

`HeroPicker` took the argmax of a synergy score plus a small random term, so once the first hero on a
team was locked the rest of the composition followed almost deterministically. It now samples from a
weight instead: synergy and counters bias the draw, they no longer decide it. Measured over 120 team
draws on 60 distinct seeds, with the same seeds for each variant:

| picker | distinct comps | mean top-teammate share | worst pick count vs role-uniform | rarest–commonest hero |
|---|---|---|---|---|
| argmax (passes 1-4) | 64% | 75% | +123% | 9 – 71 |
| weighted, multiplicative | 95% | 49% | +27% | 18 – 52 |
| weighted, additive (kept) | 93% | 49% | +37% | 18 – 54 |

"Role-uniform" is what the 1/2/2 role limits alone would produce with no preferences at all: 24
picks per bulwark, 30 per striker, 48 per conduit over 120 draws. Argmax missed that by up to 123%;
sampling lands within 37% of it. Under argmax several pairs never separated at all — three heroes
shared 100% of their games with one particular teammate.

The two weighted variants are indistinguishable, so the additive one is kept for being bounded
rather than for measuring better. Rook, which pass 4 could not measure at all, now draws 27 picks.

### 3. Overlapping seeds inflated the sample size

`tools/sim.py` gave each process `--seed + proc * 1000`, so two runs whose `--seed` differed by less
than `1000 * --procs` shared most of their matches. Pass 4's 56 telemetry files were 32 distinct
matches. Passes 1-3 are unaffected. The seed layout is fixed and `analyze` now reports repeats
instead of counting them twice.

### 4. The escort side skew was a scoring bug, and it was the whole skew

Team A had won more in every batch since pass 1 (89 to 53 overall). Splitting pass 5 by mode:

| mode | A | B | draws |
|---|---|---|---|
| control | 11 | 7 | 6 |
| push | 10 | 14 | 0 |
| escort (before fix) | 13 | 3 | 8 |

Control and push are even; together A won 21 and B won 21. All of it was escort, and it was not a
tuning problem. In round two the attacker's round ends the instant it passes the other team's
distance, so its recorded distance is about a centimetre ahead — and `compute_winner` treats a gap
under half a metre as a tie. The second attacker could therefore only ever draw or deliver the
payload outright. `EscortMode` now records that the distance was beaten and wins on it. Re-running
the same 24 seeds:

| | A | B | draws |
|---|---|---|---|
| before | 13 | 3 | 8 |
| after | 11 | 13 | 0 |

The draws were not close matches. They were team B winning and not being credited.

### 5. Ults are no longer hoarded

`BotDecision` held ults for a condition that rarely arrived. It now adds pressure that grows the
longer an ult sits ready, scaled by the bot's discipline. Measured on the same 32 seeds before and
after, with the picker unchanged so the compositions are identical:

| hero | ult uptime before | after | ults/10m before | after |
|---|---|---|---|---|
| cadence | 26.7% | 11.5% | 3.34 | 4.96 |
| tallow | 22.0% | 12.6% | 4.06 | 4.74 |
| suture | 19.4% | 10.4% | 2.87 | 3.19 |
| cathedral | 16.4% | 24.6% | 5.17 | 3.96 |

Three of the four moved the right way on both measures. Cathedral went the other way on 6 picks,
which is noise.

### 6. `ctx.ability` was null everywhere

Found while reading the pass-5 kill data: 90% of Cathedral's and Sable's kills were credited to
"Quick Melee" while every other hero sat between 1.5% and 9%. Both are melee-primary heroes, and
`MeleeEffect` falls back to `quick_melee` when it cannot see which ability fired it. `ctx.ability`
turned out to be assigned in exactly one place in the codebase, so it was null for every ability in
the game. Three systems were degraded by it:

- Kill attribution fell back to a blank or generic id, so the kill feed and killcam named the wrong
  thing. 68% of kills were unattributed and 19% were credited to quick melee; after the fix those
  are 0% and 5.5%, and every hero's weapon appears under its own name.
- Per-shot weapon bloom is stored on the ability, so it never accumulated. Only Suture authors any,
  and only 0.15 degrees per shot, so the balance effect is negligible — but it was inert.
- Hitscan and beam events carried `slot: -1`, so the client could not look up the firing ability and
  drew every hitscan weapon and beam with a default presentation instead of its authored muzzle
  flash, tracer colour and impact VFX.

`Ability` now stamps itself onto each context before running effects.

### Pass 5 measurement

72 matches: Training Range/Control 24 at a 360 s limit, Nightmarket/Push 24 at 500 s, Saltmarsh/
Escort 24 at 900 s, with the fixed picker, the fixed escort scoring and the ult change. Team A won
32, B 34, 6 draws. Average duration 351 s. Time-to-kill median 7.37 s, p10 1.90, p90 41.17.

| hero | picks | win% | K/D | dmg/10m | heal/10m | ult uptime% | obj% |
|---|---|---|---|---|---|---|---|
| suture | 64 | 39.1 | 2.26 | 4887 | 2349 | 7.5 | 18.8 |
| cadence | 62 | 51.6 | 1.97 | 3983 | 6245 | 10.7 | 25.7 |
| tallow | 60 | 53.3 | 2.91 | 6442 | 9280 | 14.7 | 22.2 |
| ferry | 52 | 36.5 | 1.62 | 4007 | 1211 | 4.8 | 19.1 |
| lumen | 50 | 48.0 | 3.14 | 7848 | 1253 | 1.2 | 20.9 |
| coil | 42 | 64.3 | 6.48 | 17584 | 0 | 6.3 | 31.9 |
| bramble | 41 | 31.7 | 2.47 | 8652 | 587 | 3.2 | 30.2 |
| bombard | 41 | 26.8 | 1.75 | 3791 | 0 | 0.2 | 18.7 |
| sable | 36 | 47.2 | 2.20 | 13600 | 0 | 0.4 | 20.1 |
| ricochet | 35 | 45.7 | 0.62 | 3180 | 0 | 0.4 | 26.9 |
| harrier | 34 | 52.9 | 2.83 | 8922 | 0 | 1.1 | 31.2 |
| kiln | 34 | 52.9 | 6.06 | 11606 | 0 | 3.6 | 34.2 |
| ballast | 31 | 41.9 | 4.61 | 12272 | 0 | 4.2 | 25.6 |
| wisp | 30 | 50.0 | 4.12 | 8910 | 0 | 8.7 | 22.8 |
| vesper | 29 | 51.7 | 3.34 | 8292 | 0 | 0.7 | 17.6 |
| cathedral | 28 | 64.3 | 3.74 | 12010 | 1483 | 16.3 | 25.1 |
| rook | 27 | 37.0 | 1.51 | 4056 | 0 | 0.3 | 30.4 |
| cairn | 24 | 29.2 | 2.78 | 9808 | 0 | 4.0 | 33.0 |

This is the first table on this page where every hero has a usable sample and no composition
repeats more than twice, so it is the first one that can be read as being about heroes.

### Findings

1. **Coil is the clearest outlier.** 64.3% over 42 picks, the highest K/D in the game, and 17584
   damage per ten minutes alive against 13600 for the next hero. Damage is measured directly rather
   than attributed, so this one does not depend on the attribution bug above.
2. **Cathedral reads 64.3% again**, but the pass-3 diagnosis that named Censer as the lever was
   built on the kill attribution that turned out to be broken. Not touched this pass: with
   attribution fixed, the next pass can see which of his abilities actually does the work.
3. **Bombard at 26.8% over 41 picks** is the lowest win rate with a large sample, on the lowest
   damage in the game. This is the bot-competence caveat: Bombard lobs shells over cover and the
   bots cannot use it. Do not buff it on this data.
3. **Cairn at 29.2%** is now the weakest bulwark, having read mid-table under the old picker. 24
   picks is thin; it needs a mirror test like Kiln's rather than a tuning change.
5. **Side skew is gone.** 32-34 across 72 matches once escort scores correctly.

### Changes

| Change | From | To | Why |
|---|---|---|---|
| Coil Arc Gauntlet damage | 30 | 25 | The highest damage and K/D in the game over 42 picks. The chain follows the base damage down; the Arc Lance is untouched |

### Verifying the Coil change, and what it cost to find the lever

Two attempts, each re-run on the pass-5 seeds for Control and Push (48 matches, 28 Coil picks):

| build | Coil win% | Coil dmg/10m |
|---|---|---|
| pass 5 baseline | 60.7 | 18852 |
| chain cut to one jump | 64.3 | 18220 |
| chain restored, base damage 30 → 25 | 57.1 | 18052 |

The first attempt assumed the chain carried Coil's output and moved damage by 3%: three enemies
rarely stand inside the 6 m chain radius, so it was reverted rather than left in place for no
measured benefit. The second cut the base weapon 17% and moved damage by 4%. Both attempts were
guesses, because the telemetry recorded damage per hero but not per ability.

It does now, and the answer was in neither ability:

| Coil's damage | share |
|---|---|
| Arc Gauntlet (primary) | 53.7% |
| **Tesla Node (deployable)** | **23.0%** |
| Arc Lance | 10.5% |
| Capacitor | 6.7% |
| Blackout (ult) | 5.4% |

A deployable that is placed once and then ignored does nearly a quarter of his damage, and it also
relays chain arcs without spending a jump, so it feeds the primary as well. That is the lever, and
it is the next pass's to pull. The 25-damage cut stays: the direction is right and it is the highest
damage in the game either way, but its measured effect is inside the noise on 28 picks and should be
read that way.

The same data settles Cathedral, whose lever pass 3 named on the strength of the broken attribution:
the Reliquary Mace is 63.7% of his damage and Censer is 9.9%. Pass 3 blamed Censer. Quick melee is
another 23.4%, which is worth a look on its own.

Non-hero changes: `HeroPicker` samples instead of taking the argmax; `EscortMode` wins on a beaten
distance; `BotDecision` grows ult pressure over time; `Ability` populates `ctx.ability`;
`tools/sim.py` cannot hand two runs the same match, and `analyze` warns when it is given repeats.

### After pass 4 (kept for the record; 1-5 were resolved in pass 5)

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
5. **Time-to-kill.** A median near 8.9 s from first damage to death is long for the genre, but the
   measure spans an entire life including disengages and healing, so it needs a cleaner definition
   (damage within a continuous engagement window) before it can be tuned against.

## Next pass

1. **Coil's Tesla Node**, which the new per-ability damage data shows is 23% of his output and also
   relays his chain. Two cuts to the wrong abilities moved his damage by 3% and 4%; this is where to
   look.
2. **Cathedral.** 64.3% over 28 picks. The Reliquary Mace is 63.7% of his damage and quick melee
   another 23.4%, so pass 3's diagnosis (Censer, at 9.9%) was wrong and his mace is the lever.
4. **Cairn**, and **Bramble** at 31.7% over 41 picks: mirror tests like Kiln's, not tuning changes.
   A mirror is the only measurement here that isolates one hero from its composition.
4. **Bombard and Ricochet** cannot be balanced from this harness at all. Bombard lobs over cover and
   Ricochet needs bounces to arm; the bots do neither. They need either a bot that can use them or a
   human playtest before any number moves.
6. **Time-to-kill.** A median of 7.4 s from first damage to death is long for the genre, but the
   measure spans an entire life including disengages and healing, so it needs a cleaner definition
   (damage within a continuous engagement window) before it can be tuned against.
6. **Map-specific balance** is still out of reach: one map per mode, and Hybrid has no map.
