# Bot AI

Bots are not scripted opponents; they are players with bounded senses, imperfect hands and a
team on comms. Every bot is a `BotController` on the server that produces an `InputCmd` per tick,
exactly like a remote client. Nothing in the AI reads the world directly except through its
perception layer and public match state (kill feed, objective state, teammates' HUD).

```
BotBrain
 ├── BotPerception   what it can see/hear/was told   → beliefs (decay, error, staleness)
 ├── BotDecision     utility goals + ability policy   → goal, target, movement intent
 ├── BotNavigator    navmesh paths + combat movement  → cmd.move / jump / crouch
 └── AimModel        human-like aiming + trigger      → yaw / pitch / fire button
TeamCoordinator (one per team)  stance, rally point, focus target, ult sequencing, comp
```

## Bounded perception (`BotPerception`)

- **Sight**: 110° field of view, 90 m, occlusion raycasts to head/center/feet, scanned every third
  tick per bot. Seeing is not noticing: an *attention* accumulator grows with salience (central in
  view, close, moving, shooting, a bulwark, a known threat) scaled by the bot's `awareness`; only
  when it crosses a threshold does the belief become "noticed". Peripheral, distant, still targets
  can go unnoticed for a while — like a human.
- **Hearing**: `SimWorld.on_pawn_sound` events (gunfire 20–22 m loudness, abilities, footsteps 9–12,
  ults 40) reach bots within loudness × hearing; the belief position gets error proportional to
  distance and lower confidence; footsteps are quieter facts than gunfire.
- **Damage**: being hit reveals roughly where from (with position error), unless tunnel vision.
- **Callouts**: teammates report sightings to the coordinator; bots read them 0.5–4 s later at 45%
  confidence — "there's one behind the crates" quality, not exact.
- **Memory**: beliefs decay over `memory_seconds` (4–8 s by tier), extrapolate along the last seen
  velocity for up to 1.2 s, and are forgotten below 5% confidence. Invisible enemies are perceived
  only when revealed; revealed enemies are seen through walls.

## Human-like aim (`AimModel`)

1. **Reaction**: a new target starts a reaction timer (170–600 ms by tier, jittered, shorter if the
   bot was already looking that way). Eyes drift toward the target during the reaction.
2. **Flick**: an eased turn at the tier's flick speed with an **overshoot** proportional to the flick
   distance and a spring-like settle, retargeting mid-flick as the target moves.
3. **Tracking**: an Ornstein–Uhlenbeck noise process (std 0.7–3.8°, mean-reverting) on yaw/pitch,
   scaled up by pressure (being shot at), movement speed, being airborne, and the hero's
   projectile difficulty; tracking lags fast lateral targets.
4. **Recoil**: each shot kicks the view; only `recoil_compensation` (20–90%) of it is countered.
5. **Lead**: projectile heroes lead the target using an imperfect multiplier re-rolled every ~1 s.
6. **Trigger discipline**: fire when angular error is inside the target's angular size (bigger
   tolerance for spray weapons); HOLD weapons fire in bursts of 0.5–1.4 s with gaps; occasional
   early shots and over-holds proportional to the tier's mistake rate.
7. **Idle look**: glance at remembered threats, look where you're going, scan corners.

There is no accuracy dice roll and no snapping. Difficulty tiers shift the *distributions* of all
of the above (`BotSkillProfile.for_tier`), and each bot samples its own values so two bots of the
same tier differ.

## Individual intent (`BotDecision`)

Every 0.2 s the bot scores goals from its beliefs and picks the best with hysteresis and a little
noise: **Engage** (target quality, range fit, health advantage, focus target, tunnel vision bonus
for the current target), **Chase** (low visible target — also where overextension comes from),
**Hold objective / Advance** (mode phase, coordinator stance, overtime), **Regroup** (stagger
waits, distance to the team, sticking to the tank), **Retreat** (health, being focused,
outnumbered, panic), **Seek health** (packs the bot knows about), **Support ally** (healers: lowest
ally in range with LOS), **Flank** (flankers when the team is alive), **Setup** (builders before
the round).

Fight positions are sampled around the bot and scored: line of sight to the target, distance vs
the hero's ideal range, cover from *other* visible threats, high ground preference, staying near
allies for supports, plus baked `TacticalMap` cover/openness/height for the map. Retreats go away
from threats toward healers/spawn/health packs and prefer points enemies can't see.

Abilities are used from their `AbilityAIHints` (intent, ranges, health thresholds, target counts)
with a per-tier *cooldown discipline*: good moments are taken with probability, bad ones sometimes
anyway. Ultimates use hint thresholds plus the coordinator's plan.

**Legible mistakes** (all tier-scaled): overextending on a streak, forgetting an ability for
4–12 s, panic (random movement, wasted cooldowns, panic ults) below a health threshold, tunnel
vision on the current target, mistimed ults, over-holding fire, predictable strafing rhythm at
low tiers, sub-optimal goal choices from scoring noise.

## Team-level strategy (`TeamCoordinator`)

Every 0.75 s each team's coordinator computes stance from *legitimately known* information (alive
counts, kill feed, shared sightings): **Group** (stage outside the fight), **Push**, **Hold**,
**Stagger-wait** (don't trickle: wait for respawns), and picks a rally point (staging point
between spawn and objective, or a hold point behind the objective). It sets a **focus target**
(low, isolated, support-first) and plans **ultimates**: enablers before payoffs (`ult_style`
combo_enabler / combo_payoff), payoffs hold while an enabler is nearly ready, no stacking two
engage ults within 4 s, and counter ults (`ult_style = counter`) fire in response to enemy engage
ults seen in the last 1.5 s. Hero selection (`HeroPicker`) fills 1/2/2 with synergy and counter
scores against the enemy composition.

## Navigation (`BotNavigator`)

Paths come from Godot's NavigationServer over a navmesh baked from each map's static colliders.
Bots jump at ledges, add lateral wander so they don't share a line, un-stick with side-steps and
hops, and layer **combat movement**: rhythmic but irregular strafing (rhythm varies by tier),
crouch peeks, hero-style hops or hover. Movement input is expressed relative to the current view
so aiming and moving are independent, like a human's hands.

## Difficulty tiers

| Tier | Reaction | Tracking noise | Flick overshoot | Recoil comp | Discipline | Mistakes |
|---|---|---|---|---|---|---|
| Recruit | 420–600 ms | 2.6–3.8° | 30–45% | 20–40% | 35% | 50% |
| Regular | 300–420 ms | 1.8–2.6° | 20–32% | 40–60% | 55% | 35% |
| Veteran | 220–320 ms | 1.1–1.8° | 12–22% | 60–78% | 72% | 22% |
| Elite | 170–240 ms | 0.7–1.2° | 6–14% | 78–90% | 88% | 12% |

## Teammates and backfill

Teammate bots use the same brain: healers prioritize the lowest ally with LOS and stay behind the
bulwark, bulwarks hold the front of the fight position set, strikers follow up on the focus target.
Bots backfill leavers within 2 s (`bot_fill`) and inherit the leaver's pawn and stats; when a human
reconnects the stand-in bot is removed.
