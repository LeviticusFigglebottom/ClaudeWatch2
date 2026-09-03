# Heroes

Generated from `data/heroes/*.tres` by `tools/gen_docs.tscn`; design notes per hero live in `docs/heroes/<id>.md`.

| Hero | Role | HP / Armor / Shield | Speed | Signature | Counters | Countered by |
|---|---|---|---|---|---|---|
| **Ballast** | Bulwark | 300 / 250 / 0 | 5.0 | Anchor: throws a harpoon-anchor. Hit a wall or floor and Ballast is winched to it; hit an enemy and they are reeled to Ballast and briefly hooked (rooted). Unstoppable enemies cannot be reeled. | Sable, Harrier, Wisp, Ricochet | Vesper, Bombard, Lumen, Kiln |
| **Cathedral** | Bulwark | 400 / 200 / 0 | 5.1 | Stained-glass Wall: a 700 hp barrier that blocks enemy fire for 8 s AND heals every ally standing within 4 m behind it for 15 hp/s. | Vesper, Coil, Bombard, Lumen | Harrier, Sable, Wisp, Ricochet |
| **Kiln** | Bulwark | 425 / 175 / 0 | 5.0 | Heat: a 0-100 resource built by dealing (0.3/pt) and taking (0.15/pt) damage that decays 4/s. Vent costs 30 heat, Slag Cast costs 40. Meltdown refills it. | Ballast, Sable, Bramble, Tallow | Suture, Vesper, Bombard, Harrier |
| **Cairn** | Bulwark | 375 / 175 / 0 | 5.3 | Raise Slab: a 2.4 m stone pillar rises 3 m out of the ground at the aimed point in half a second, carrying whoever stands on it. Allies get an elevator; enemies get displaced into the open. | Sable, Cathedral, Ballast, Bramble | Harrier, Vesper, Coil, Wisp |
| **Rook** | Bulwark | 350 / 0 / 200 | 5.2 | Lift: every enemy in a 35 degree cone within 12 m floats helplessly for 1.6 s. They can still aim, shoot and use abilities, but cannot move or jump. Unstoppable enemies are immune. | Harrier, Sable, Ricochet, Wisp | Kiln, Tallow, Suture, Cathedral |
| **Vesper** | Striker | 200 / 0 / 0 | 5.5 | Lantern: throws a lamp that REVEALS all enemies in a 12 m radius through walls for 6 s to your entire team. | Sable, Harrier, Wisp | Cathedral, Ballast, Rook |
| **Harrier** | Striker | 200 / 0 / 0 | 6.0 | Flight: hold jump while airborne to fly on 3.5 s of fuel (refills 1.2 s of fuel per second on the ground). Dive only works in the air, Afterburn refills the tank instantly, Strafing Run makes it bottomless. | Vesper, Bombard, Cairn | Vesper, Coil, Ballast |
| **Ricochet** | Striker | 225 / 0 / 0 | 5.7 | Discs only damage after bouncing at least once: a fresh disc flies straight through enemies. Each bounce arms it harder, 45 -> 70 -> 95 damage, up to three bounces. | Cathedral, Kiln, Cairn | Vesper, Bombard, Harrier |
| **Coil** | Striker | 225 / 0 / 0 | 5.6 | Chain: lightning from the gauntlet jumps from the enemy you hit to up to two more enemies within 6 m (70% then 50% damage). Friendly Tesla Nodes act as relays the chain can pass through. | Cathedral, Cadence, Suture | Cathedral, Tallow, Suture |
| **Wisp** | Striker | 200 / 0 / 0 | 5.8 | Exchange: trade places with your Mark on a second press, or with an enemy hit by the marked needle. Nothing else on the roster moves the enemy AND you at once. | Bombard, Vesper, Tallow | Kiln, Rook, Sable |
| **Bombard** | Striker | 225 / 0 / 0 | 5.3 | Indirect fire: the mortar's predicted landing point is drawn as a world-space reticle visible through walls, so every shell can be lobbed over cover blind. | Cathedral, Rook, Cairn, Kiln | Harrier, Sable, Wisp |
| **Sable** | Striker | 225 / 0 / 0 | 5.8 | Backstab: every blade hit from behind deals 2.5x. Shroud keeps you invisible only while moving below 40% speed; sprinting or striking breaks it for 1 s. | Tallow, Suture, Vesper, Lumen | Vesper, Bombard, Coil, Rook |
| **Bramble** | Striker | 200 / 0 / 0 | 5.7 | Roots: the third consecutive thorn hit on the same target (within 2 s of the last) roots it for 1.2 s. Switching targets or pausing resets the count. | Harrier, Sable, Wisp, Ballast | Tallow, Suture, Cathedral, Vesper |
| **Cadence** | Conduit | 220 / 0 / 0 | 5.5 | On the beat: a 120 bpm clock. Groove heals allies within 9 m for 8 on every beat; Bassline shots fired within 66 ms of a beat deal 1.5x, heal allies within 4 m of the impact for 30, and make the next Groove pulse heal 16. | Bombard, Bramble, Rook | Coil, Wisp, Sable |
| **Lumen** | Conduit | 200 / 0 / 0 | 5.5 | Bouncing beam: Mirror Beam reflects off Refract mirrors (up to 3 bounces), healing the first ally / burning the first enemy along the full folded path. Prism splits it into up to 3 targets in a 25 degree cone. | Bombard, Rook, Ballast | Harrier, Wisp, Sable |
| **Suture** | Conduit | 225 / 0 / 0 | 5.5 | Tether: links the two most recently tethered allies (or one ally and Suture) for 6 s. Every point of healing Suture puts into one end of the tether is copied to the other end. | Bramble, Kiln, Coil | Wisp, Ballast, Rook |
| **Ferry** | Conduit | 200 / 0 / 0 | 5.5 | Waystone: a beacon (250 hp, 60 s). For 5 s after spawning, any ally can press INTERACT to cross straight to it. Crossing (ult) brings back up to two allies who died within 10 m in the last 15 s, where they fell. | Bombard, Vesper, Cairn | Sable, Harrier, Wisp |
| **Tallow** | Conduit | 200 / 0 / 0 | 5.5 | Wicks: up to three candles (25 s) that heal allies within 6 m for 18 hp/s. An enemy who walks onto one is burned and, after a moment of contact, snuffs it. | Bramble, Coil, Kiln | Sable, Harrier, Wisp |

## Ballast — Bulwark

*The deep does not let go.*  
Walk forward. Hook anyone who flanks or peeks and drop them at your feet, then finish with the Wave Cannon. Use Anchor on walls to reposition without giving up the front line. Surge when the poke starts hurting: you get slower but far tougher. Riptide drags an entire team into one spot for your strikers.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Wave Cannon** | 1.1/s, 5 ammo | 11 dmg hitscan ×10, falloff 6–16 m | Pressure-driven shotgun. 10 pellets of 11 damage (110 up close); falloff from 6 to 16 m. Devastating at point blank, harmless past 20 m. |
| RMB | **Pressure Slug** | 3 s | 60 dmg hitscan, falloff 20–40 m | Chamber a single slug: 60 hitscan damage with no spread, falling off from 20 to 40 m. Your only answer to ranged poke. |
| Shift | **Anchor** | 11 s | status Hooked | Throw the harpoon-anchor (40 damage). Hit a surface: you are winched to it (press jump to let go). Hit an enemy: they are reeled to your feet and hooked for 0.7 s. Unstoppable enemies cannot be reeled. |
| E | **Surge** | 12 s |  | Over-pressurize the suit for 5 s: +150 armor, but you move at 60% speed. Press it when the poke starts, not when you are already dying. |
| Q | **Riptide** | ult 1850 | area r9 6 dmg | Open the tide where you aim (within 12 m). For 3 s every enemy within 9 m is dragged toward the center, slowed to 55% and takes 30 damage per second; when it closes, a 120 damage burst throws them upward. Sets up any area ultimate. |

Synergies: Coil, Rook, Suture, Cadence  

## Cathedral — Bulwark

*Stand behind me and be whole.*  
Pick the spot the fight will happen and put the Wall there first; your team heals behind it while it soaks. Hold Guard while closing distance, then swing the mace in wide arcs to hit everyone at once. Censer punishes anyone who steps around the glass. Save Sanctuary to erase an enemy ultimate: it blocks, cleanses and makes everyone inside briefly untouchable.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Reliquary Mace** | 1.1/s | 58 melee | A slow, wide swing: 58 damage to up to three enemies in a 90 degree arc within 3 m, and they are slowed to 80% for a second. |
| RMB | **Guard** |  |  | Hold to raise the shield: you take 40% less damage from all sides but move at 70% speed and cannot swing. Hold it while closing the distance; drop it to strike. |
| Shift | **Stained-glass Wall** | 12 s | deploy cathedral_wall | Plant a 6 m wide, 3.2 m tall window 3 m in front of you for 8 s (700 hp). Enemy shots break on the glass; every ally standing within 4 m behind it heals 15 hp per second. |
| E | **Censer** | 9 s | dash 15 m/s, area r4 52 dmg | Swing the censer and lunge forward; 0.4 s later burning incense bursts around you: 52 damage within 4 m, enemies knocked back and set burning for 10 damage per second over 2 s. |
| Q | **Sanctuary** | ult 1900 | deploy barrier_dome, status Sanctified, heal 60 | Raise a 6 m dome around you for 6 s (1500 hp) that blocks all enemy fire from outside. On cast every ally inside is cleansed, healed for 60 and made invulnerable for 0.5 s: the answer to an enemy ultimate. |

Synergies: Vesper, Suture, Tallow, Bombard  

## Kiln — Bulwark

*Every fight is a foundry.*  
Trade damage to build Heat, then spend it on terrain: Slag Cast a wall you and your team can stand on, Vent an ally onto a ledge nobody expected them to reach. Fight close so the slugs and the Furnace Blast connect; the burn does the rest. Meltdown when you are surrounded: 300 overhealth, unstoppable, and everything near you burns.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Slug Thrower** | 1.8/s, 8 ammo | 65 dmg proj 55 m/s | Lobs molten slugs at 55 m/s: 65 damage on hit and the target burns for 10 damage per second over 2 s. Slight drop past 20 m. |
| RMB | **Furnace Blast** | 4 s | 10 dmg hitscan ×9, falloff 4–9 m | Open the furnace door: a 30 degree cone of flame to 8 m, 9 gouts of 10 damage that set enemies burning. Brutal inside 5 m, a warm breeze past 9. |
| Shift | **Vent** | 8 s | deploy vent | Costs 30 Heat. Blow a vent grate into the ground where you aim (within 10 m) for 5 s: any ally (you included) who steps on it is launched about 4 m straight up. Reaches ledges, slabs and rooftops. |
| E | **Slag Cast** | 10 s | deploy slag | Costs 40 Heat. Pour a 4.2 m wide, 1.5 m tall slag wall 3 m in front of you for 6 s (600 hp). It blocks shots and movement for both teams, and the step on your side lets you climb on top of it. |
| Q | **Meltdown** | ult 1750 | area r5 50 dmg, area r4 10 dmg | For 8 s the furnace runs open: +300 overhealth, unstoppable, 10% faster, Heat refilled, and the ground within 4.5 m of you burns for 40 damage per second and sets enemies alight. Casting it scorches everything within 5 m for 50. |

Synergies: Harrier, Vesper, Cadence, Cairn  

## Cairn — Bulwark

*The ground is wherever I say it is.*  
Lob rocks from behind cover and make your own cover when there is none. Raise Slab under a teammate to give them the high ground, or under an enemy to lift them into your team's sightlines. Upthrust gets you onto your own slabs and slams whoever is beneath you when you land. Landslide clears a choke and leaves three pillars behind it: fight from them.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Rock Lobber** | 1.5/s, 6 ammo | 80 dmg proj 30 m/s, splash 50/2m | Lobs a stone at 30 m/s in a heavy arc: 80 damage on a direct hit, 50 splash within 2.5 m. Arcs over cover; lead your targets. |
| RMB | **Boulder** | 5 s | 120 dmg proj 22 m/s, splash 70/4m | Heave a boulder: 120 damage on a direct hit, 70 splash within 4 m, and everyone caught is shoved away. Slow and heavy; aim it at a choke. |
| Shift | **Raise Slab** | 10 s | deploy slab | A 2.4 m wide stone pillar rises 3 m out of the ground where you aim (within 18 m) in half a second and stands for 5 s (450 hp). Anyone on it rides up: an elevator for allies, a lift into the open for enemies. Blocks shots and movement. |
| E | **Upthrust** | 9 s | dash 6 m/s, status Tremor | Kick off the ground: a 3 m leap in the direction you face. When you land, the stone answers: 55 damage within 3.5 m, enemies shoved away and slowed to 70% for a second. Your way onto your own slabs. |
| Q | **Landslide** | ult 1800 | deploy cairn_wave, deploy cairn_wave, deploy cairn_wave | Shove a wave of stone through a 60 degree cone to 12 m: 90 damage and a hard knockback. Three stone pillars then rise at 4, 7 and 10 m in front of you and stand for 6 s: cover for your team, a wall for theirs. |

Synergies: Vesper, Bombard, Kiln, Lumen  

## Rook — Bulwark

*Down is a suggestion.*  
Hold a zone and make it expensive to enter. Mortar shells arc over cover and punish groups; Lift freezes a whole cone of divers in the air where your strikers can pick them off. Density when you are focused: 30% less damage, unstoppable, and landing on someone hurts them. Ground Zero is the payoff for any pull or slow: everything in 8 m is dragged to the center and detonated.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Gravity Mortar** | 1.1/s, 5 ammo | 55 dmg proj 24 m/s, splash 45/3m | Lobs a gravity shell at 24 m/s in a high arc: 55 damage on a direct hit, 45 splash within 3 m. Slow, generous, arcs over any wall. |
| RMB | **Singularity Shell** | 7 s | 40 dmg proj 26 m/s, splash 30/3m | Fire a collapsing shell: 40 damage on hit, 30 splash, and every enemy within 4.5 m of the impact is yanked toward it and slowed to 50% for 1.2 s. Groups them for the mortar. |
| Shift | **Lift** | 12 s | status Lifted | Cut gravity in a 35 degree cone to 12 m: every enemy caught floats helplessly for 1.6 s. They can still shoot, but cannot move, jump or escape. Unstoppable enemies are immune. |
| E | **Density** | 10 s |  | Triple your mass for 3 s: 30% less damage taken, unstoppable, 2.5x gravity, 85% speed. Land on enemies from height while dense to slam them for 45. |
| Q | **Ground Zero** | ult 2000 | deploy rook_well, status Event Horizon | Drop a gravity well where you aim (within 22 m). For 2.5 s every enemy within 8 m is dragged toward the center and slowed; then it detonates for 200 damage (120 at the edge) and throws them into the air. The payoff for any pull, root or slow. |

Synergies: Bombard, Coil, Ballast, Vesper  

## Vesper — Striker

*Light finds everyone.*  
Hold long sightlines, tag targets with the Lantern so your team can see them coming, and punish anyone who peeks. You are weakest up close: keep the zipline for escapes.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Surveyor Rifle** | 2.4/s, 8 ammo | 55 dmg hitscan, falloff 35–60 m | Semi-automatic hitscan rifle. 55 damage, headshots deal double. Falloff beyond 35 m. |
| RMB | **Focus** |  |  | Hold to steady your aim: movement slows to 60% and the next rifle shot within the window deals 85 damage. |
| Shift | **Lantern** | 12 s | 0 dmg proj 22 m/s | Throw a lantern. Where it lands it lights a 12 m radius for 6 s: enemies inside are revealed to your whole team through walls. |
| E | **Zipline** | 10 s |  | Fire an anchor line to a surface and ride it. Mobility for reaching perches or escaping dives. |
| Q | **Long Night** | ult 1650 |  | For 8 s: no reload, no falloff, and every enemy you hit is revealed to your team for 4 s. |

Synergies: Bombard, Coil, Lumen  

## Harrier — Striker

*Nothing on the ground can catch me.*  
Hold jump to fly. Take angles nobody else can reach, shred one target with the SMGs, Dive onto whoever is low, and Afterburn out before hitscan finds you. Fuel is your second health bar: never start a fight on an empty tank.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Twin SMGs** | 16.0/s, 40 ammo | 7 dmg hitscan, falloff 15–30 m | Two machine pistols firing together: 7 damage per bullet, 16 bullets per second (112 DPS), headshots double. Accurate to 15 m, falls to half damage by 30 m. 40 rounds, 1.3 s reload. |
| RMB | **Pod Rockets** | 4 s | 35 dmg proj 45 m/s, splash 25/2m | Fire two micro-rockets from the jet-rig pods: 35 damage on a direct hit plus 25 splash damage in 2.5 m. 4 s cooldown. |
| Shift | **Dive** | 9 s |  | Only in the air: cut thrust and slam straight down at 30 m/s. Landing deals 80 damage in 4 m and knocks enemies away. 9 s cooldown. |
| E | **Afterburn** | 10 s | status Afterburn | Dump the reserve tank: +40% move speed for 3 s and your Flight fuel refills instantly. 10 s cooldown. |
| Q | **Strafing Run** | ult 1700 |  | For 4 s: +50% speed, bottomless fuel, and a rocket drops straight down from your position every 0.25 s, each dealing 90 damage in 3.5 m. Fly the line you want carpeted. |

Synergies: Cadence, Ferry, Wisp  

## Ricochet — Striker

*The wall is on my side.*  
Never shoot straight at anyone. Skip discs off floors, walls and ceilings so they arrive armed; fight in corridors and rooms where every surface is a friend. Bank Shot when you cannot find the angle, Skip to break contact and leave a trap, and Pinball inside a room to make the whole room lethal.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Disc Launcher** | 1.6/s, 5 ammo |  | Launch a disc at 45 m/s. It passes through enemies until it bounces; after 1 / 2 / 3 bounces it deals 45 / 70 / 95 damage. 1.6 discs per second, 5 per clip, 1.5 s reload. |
| RMB | **Lob** | 5 s |  | Throw a heavy disc in an arc (28 m/s, drops fast). It arms on its first bounce like any disc but hits harder: 55 / 80 / 105 damage. Arcs over barriers. 5 s cooldown. |
| Shift | **Bank Shot** | 8 s | status Bank Shot | Prime your launcher for 6 s: the next disc you fire locks onto the nearest enemy it can see after its first bounce and curves into them. 8 s cooldown. |
| E | **Skip** | 7 s | dash 14 m/s | Dash 14 m/s in your movement direction and leave a disc bouncing on the spot you left for 4 s. It arms on its first bounce (40 / 55 / 70 damage) and hits the first enemy who walks into it. 7 s cooldown. |
| Q | **Pinball** | ult 1800 |  | For 6 s a disc leaves you every 0.3 s in a random direction. Each bounces up to 6 times and arms like any disc (45 / 70 / 95). Inside a room, the room becomes the weapon. You keep your launcher. |

Synergies: Cairn, Coil, Rook  

## Coil — Striker

*Stand together. Please.*  
Find the clump. Every shot on one target arcs to two more within 6 m, so aim at whoever is standing closest to the others. Drop a Tesla Node where the enemy has to pass and chain through it, pop Capacitor when the whole team turns on you and hand it back as a burst, and save Blackout for the moment the enemy commits to an ultimate.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Arc Gauntlet** | 4.0/s, 12 ammo | 25 dmg hitscan | Hitscan lightning: 25 damage, 4 shots per second, 25 m range, no falloff. Each hit chains to up to two more enemies within 6 m of the target for 17 and 12 damage. 12 cells, 1.4 s recharge. |
| RMB | **Arc Lance** | 7 s | 70 dmg hitscan | Overcharge the gauntlet into a 40 m hitscan bolt: 70 damage, headshots double, then chains to two more enemies within 8 m for 49 and 35. 7 s cooldown. |
| Shift | **Tesla Node** | 12 s | deploy tesla_node | Plant a 150 hp pylon (12 s) where you aim, up to 12 m away. Every 0.8 s it zaps the nearest enemy within 7 m for 20 damage, and your Chain can jump through it. 12 s cooldown. |
| E | **Capacitor** | 11 s |  | For 1.5 s every hit you take is absorbed instead of dealt. When it ends you release the stored damage (up to 250) as a burst in 5 m with knockback. Nothing stored, nothing released. 11 s cooldown. |
| Q | **Blackout** | ult 1800 | area r14 80 dmg, status Blackout | After a 0.4 s wind-up, every enemy within 14 m you can see takes 80 damage and is SILENCED and slowed to 70% speed for 3 s. Weapons still work. The answer to an enemy ultimate. |

Synergies: Rook, Ballast, Vesper  

## Wisp — Striker

*You are exactly where I drew you.*  
Place a Mark somewhere safe, then go where you should not be. Open with the needle rifle, Exchange an out-of-position enemy into your team (and yourself into theirs), and swap back to the Mark when the trade is done. Displacement is a fight-starter: fold the enemy behind you, into your team's guns.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Needle Rifle** | 2.5/s, 24 ammo | 18 dmg hitscan, falloff 25–45 m | Three-round hitscan bursts: 18 damage per needle (54 per burst), 2.5 bursts per second, headshots double. Full damage to 25 m, 60% by 45 m. 24 needles, 1.4 s reload. |
| RMB | **Exchange** | 9 s | 20 dmg proj 60 m/s | Fire a marked needle (60 m/s, 20 damage). If it hits an enemy, you and that enemy trade places. Unstoppable enemies refuse the trade. 9 s cooldown. |
| Shift | **Mark** | 3 s |  | Press once to leave a Mark at your feet (lasts 20 s, cannot be destroyed). Press again to Exchange with it: you appear at the Mark and the Mark appears where you stood. 3 s between presses. |
| E | **Fold** | 7 s |  | Fold 8 m of ground: blink forward along your aim (stops at walls). 7 s cooldown. |
| Q | **Displacement** | ult 1900 | status Unfolded | After a 0.5 s fold, every enemy within 10 m you can see is teleported to a random point 8-12 m behind you, and you gain 100 overhealth. Unstoppable enemies are immune. Turn your back to your team and pull the fight into it. |

Synergies: Ferry, Cadence, Harrier  

## Bombard — Striker

*You don't need to see it. I do.*  
Sit behind cover on high ground and drop shells where the reticle says they land: you never need a sightline. Tag the fight with the Spotter drone, airburst anyone hiding behind a wall, and save Barrage for a held point. You are helpless when dived: Kick Charge is your only way out.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Field Mortar** | 1.1/s, 4 ammo | 60 dmg proj 28 m/s, splash 60/3m | Lob a mortar shell. 60 direct damage plus 60 splash in 3.5 m. The reticle shows where it lands, even through walls. 4 shells, 2.2 s reload. |
| RMB | **Airburst** | 8 s | 30 dmg proj 28 m/s, splash 90/4m | Fire a shell with a proximity fuse: it bursts in the air when it passes above an enemy, dealing 90 splash damage in 4.5 m with no cover to hide behind. |
| Shift | **Spotter Drone** | 14 s | deploy spotter, status Spotted | Launch a drone to a point up to 35 m away. For 8 s it hovers 4 m up and reveals every enemy within 10 m to your whole team through walls. |
| E | **Kick Charge** | 11 s | dash 7 m/s | Fire a charge at your feet and ride the recoil up and backward about 8 m. Your only answer to a dive, and the quickest way onto a perch. |
| Q | **Barrage** | ult 1800 | area r10 | Mark a 10 m area up to 45 m away. Over the next 3 s, twelve shells fall on it from above: 70 direct, 70 splash each. Cover does not help. |

Synergies: Vesper, Rook, Cairn  

## Sable — Striker

*You'll hear the second cut.*  
Creep in Shroud below 40% speed, open from behind for 2.5x, finish the three-hit combo and Vault out before the team turns. Lunge closes the last gap. Requiem is a team wipe if they are clumped and nobody has reveal or a save.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Twin Blades** | 2.4/s |  | Three-hit combo: 40, 40 (wide sweep, two targets), then 70 (thrust). Reach 2.6 m. Every hit from behind deals 2.5x. The combo resets after 1.2 s without a swing. |
| RMB | **Lunge** | 6 s |  | Dash 4 m toward your aim in a quarter second and cut for 30 on arrival (backstab-eligible). The gap closer that starts every combo. |
| Shift | **Shroud** | 2 s |  | Toggle. While Shroud is on you are invisible whenever you move below 40% speed. Moving faster or striking breaks it for 1 s. |
| E | **Vault** | 8 s | dash 8 m/s | Leap high in your movement direction: onto ledges, over a wall, or out of a fight that turned. |
| Q | **Requiem** | ult 1750 | status Marked | Mark every enemy within 12 m (revealed 4 s), then dash through each in turn at 30 m/s, cutting for 100 (2.5x from behind). You are invulnerable and unstoppable until the last cut. |

Synergies: Tallow, Wisp, Ballast  

## Bramble — Striker

*Stand still. It's easier.*  
Poke at mid range and stack three thorns on one target to root it, then land the Snare or a Thicket to keep it there for your team. Overgrowth roots a whole fight and heals your side of it. You lose to cleanse and to anyone who out-ranges 30 m.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Thorn Bow** | 5.0/s, 20 ammo | 22 dmg proj 60 m/s, status Rooted | Rapid thorns: 22 damage, 5 per second, headshots deal double. Your third consecutive hit on the same target roots it for 1.2 s. 20 thorns, 1.5 s reload. |
| RMB | **Thorn Fan** | 5 s | 16 dmg proj 55 m/s | Loose five thorns in a 14 degree fan for 16 each. Every thorn counts toward Roots, so a fan on one target at close range is a root. |
| Shift | **Snare** | 10 s | 40 dmg proj 35 m/s, splash 20/1m | Lob a vine seed. On hit it deals 40 and roots the target for 2 s. Cleansable. |
| E | **Thicket** | 12 s | deploy thicket, status Thorned | Grow a 6 m thorn hedge in front of you for 8 s. Enemies crossing it take 30 on entry, 20 per second inside, and are slowed to half. Trampling wears it down (300 hp). |
| Q | **Overgrowth** | ult 1800 | area r12 60 dmg | Thorn erupts in 12 m: every enemy takes 60 and is rooted for 2.5 s; every ally is healed 150 over 2.5 s. Roots go through cover. |

Synergies: Coil, Rook, Bombard  

## Cadence — Conduit

*Keep time. Keep breathing.*  
Stand in the middle of your team with the Groove on and let the beat do the healing. Learn the metronome: Bassline shells fired on the beat hit harder, heal around the impact and double the next pulse. Crescendo to reposition the whole team, Discord to open a target, Anthem before the enemy commits.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Bassline** | 1.5/s, 6 ammo | 45 dmg proj 30 m/s, splash 30/2m | Bass-cannon. A slow, heavy shell: 45 damage plus 30 splash in 2 m. Shots fired ON THE BEAT (120 bpm) deal 1.5x and heal allies within 4 m of the impact for 30. |
| RMB | **Groove** |  |  | Toggle. While the groove is on, every beat (twice a second) heals allies within 9 m for 8 and Cadence for 4. Fire Bassline on the beat and the next pulse heals double. |
| Shift | **Crescendo** | 10 s | area r10 20 heal, status Crescendo | A swelling chord: allies within 10 m (and Cadence) are healed for 20 and move 30% faster for 3 s. |
| E | **Discord** | 9 s |  | A dissonant blast in a 60 degree cone, 15 m: every enemy caught takes 25% more damage for 4 s. |
| Q | **Anthem** | ult 1900 | heal 60, area r14 | The drop. Allies within 14 m (Cadence included) are cleansed, healed for 60 and given 300 overhealth. Overhealth decays 2 s after the last hit. |

Synergies: Harrier, Ballast, Sable  

## Lumen — Conduit

*Every angle is a way in.*  
Hold Mirror Beam on whoever needs it; it burns enemies just as well. Place Refract mirrors at corners so the beam can reach allies you cannot see, and pop Prism when the team clumps to heal three at once. Sunstroke is both a blind and a big heal: fire it down the lane where the fight is.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Mirror Beam** |  |  | Hold: a beam of light up to 25 m that heals the first ally it touches for 65/s or burns the first enemy for 55/s. It reflects off Refract mirrors (up to 3 bounces), so it can reach around corners. |
| RMB | **Glint** | 5 s | heal 70 | Flash the staff at an ally: heals them for 70 instantly (25 m). Only fires with an ally under the crosshair. |
| Shift | **Prism** | 12 s | status Prism | For 4 s the beam passes through the prism and splits: it heals or burns up to 3 targets inside a 25 degree cone, each at 75% strength. |
| E | **Refract** | 8 s ×2 | deploy mirror | Place a mirror (120 hp, 15 s, two at a time) where you aim, facing you. Mirror Beam reflects off it, so you can heal around corners and over cover. Enemies can shoot it down. |
| Q | **Sunstroke** | ult 1750 |  | 3 s: a blazing beam as wide as a doorway, 30 m. Enemies in it burn for 120/s and are blinded (60% speed, revealed); allies in it are healed for 100/s. Lumen moves at half speed while channelling. |

Synergies: Vesper, Cathedral, Cairn  

## Suture — Conduit

*Hold still. This part hurts.*  
Tether the bulwark and the striker who is taking the most fire, then every bandage you land on one of them heals both. Bandage Volley is your main heal: shoot it AT the ally, the shells burst on contact. Staple enemies to keep the pressure up, staple allies in a pinch. Adrenaline on your best duelist; Triage when the fight turns.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Stapler** | 9.0/s, 30 ammo | 12 dmg hitscan, falloff 18–35 m | Rapid hitscan stapler: 12 damage, 9 shots/s, 30 staples. Staples fired into an ally close wounds for 6 each. |
| RMB | **Bandage Volley** | 2 s | 15 dmg proj 35 m/s | Fire three bandage shells (6 degree spread, 21 m). Each shell bursts on the first ally, enemy or surface it meets: allies within 3 m are healed for 45, an enemy hit directly takes 15. Shoot the floor at your feet to patch yourself for half. |
| Shift | **Tether** | 10 s | status Tethered, heal 30 | Link the aimed ally for 6 s and heal them for 30. The two most recently tethered allies (or one ally and Suture) share every point of healing Suture puts into either of them. |
| E | **Adrenaline** | 12 s | status Adrenaline | Inject the aimed ally: +25% fire rate and +25% move speed for 4 s. |
| Q | **Triage** | ult 1600 | heal 999, area r10 | Everyone within 10 m, Suture included, is cleansed and healed to full. |

Synergies: Ballast, Cathedral, Kiln  

## Ferry — Conduit

*Nobody stays behind.*  
Plant the Waystone somewhere safe near the fight and your team's respawns become a ten-second walk instead of a thirty-second one. Ferrylight is your heal: lob it at the ally, it bursts on contact. Undertow pulls an overextended ally back to you. Hold Crossing for the moment two allies drop together, then stand over them and raise the lantern.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Lantern Bolt** | 2.5/s, 10 ammo | 35 dmg proj 45 m/s | Fast bolts of drowned light: 35 damage, 2.5 shots/s, 10 per lantern. |
| RMB | **Ferrylight** | 1.0/s | 10 dmg proj 40 m/s | Hold: lob a lantern of healing light once a second. It bursts on the first ally, enemy or surface it touches: allies within 2.5 m are healed for 50; an enemy hit directly takes 10. |
| Shift | **Undertow** | 10 s | status Undertow, heal 40 | Aim at an ally 4-20 m away: the current drags them to your side and heals them for 40. |
| E | **Waystone** | 20 s | deploy waystone | Plant a beacon (250 hp, 60 s). For 5 s after spawning, allies can press INTERACT to cross straight to it. One waystone at a time; planting again moves it. |
| Q | **Crossing** | ult 1700 | area r10 60 heal | Raise the lantern for 3 s (rooted, invulnerable). Then up to two allies who died within 10 m in the last 15 s return where they fell. Living allies nearby are healed for 30/s during the cast and 60 when it completes. |

Synergies: Harrier, Sable, Wisp  

## Tallow — Conduit

*Light is a thing you leave behind.*  
Place candles where your team will actually stand, not where they are now: a doorway, the cart, the high ground. Heal with the wax bolt between fights, burn divers with the flame bolt, and hold Snuff for the ally about to eat a stun. Vigil turns a lost fight into a stalemate for 5 s; use it when the enemy commits.

| Key | Ability | Cooldown / rate | Numbers | Description |
|---|---|---|---|---|
| LMB | **Flame Bolt** | 3.0/s, 12 ammo | 28 dmg proj 40 m/s | A bolt of candle-fire: 28 damage and a 10 per second burn for 2 s. 12 bolts, 1.4 s reload. |
| RMB | **Wax Bolt** | 2.4/s | 12 dmg proj 40 m/s | A warm wax bolt that heals the first ally it touches for 45 (or every ally within 2.5 m of where it lands). Enemies it hits take 12. No ammo. |
| Shift | **Wicks** | 6 s ×3 | deploy wick, status Scorched | Place a candle (up to three, 25 s each). Allies within 6 m are healed 18 per second. An enemy who walks onto a candle is burned for 12 per second and snuffs it after a moment. |
| E | **Snuff** | 12 s |  | Pinch out the ally under your crosshair (or yourself): cleansed of every debuff, healed 30, and invulnerable for 1 s. |
| Q | **Vigil** | ult 1900 | status Vigil, deploy vigil_ward, area r12, status Last Light | For 5 s every ally within 12 m keeps their light: 70% damage reduction, 30 healing per second, cleansed, and a Last Light that makes them briefly untouchable if they would fall. Tallow herself cannot drop below 1 hp. |

Synergies: Sable, Cathedral, Ballast  

