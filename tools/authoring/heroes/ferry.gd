extends RefCounted
## FERRY — Conduit. Boat-woman of the drowned cities; carries the dead. ★ Waystone: a beacon allies can
## teleport to from spawn. Lantern bolts (damage) and Ferrylight (heal), Undertow pulls an ally to her,
## ult Crossing resurrects up to two dead allies near her over 3 s. Tempo support; countered by
## targeting the beacon and killing her first.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"ferry", "Ferry", RF.Role.CONDUIT, 200.0)
	h.codename = "The Boatwoman"
	h.sort_order = 24
	h.tagline = "Nobody stays behind."
	h.lore = "When the Adriatic Charter drowned, Ferry poled a flat-bottomed boat through the flooded streets bringing the living out and the dead home. The lantern on her prow was a salvaged Ring beacon: it remembers a place, and it remembers a person. The Charters hired her for the first trick. Her team keeps her for the second."
	h.playstyle = "Plant the Waystone somewhere safe near the fight and your team's respawns become a ten-second walk instead of a thirty-second one. Ferrylight is your heal: lob it at the ally, it bursts on contact. Undertow pulls an overextended ally back to you. Hold Crossing for the moment two allies drop together, then stand over them and raise the lantern."
	h.theme_color = Color(0.45, 0.88, 0.92)
	h.difficulty = 2
	h.unique_mechanic = "Waystone: a beacon (250 hp, 60 s). For 5 s after spawning, any ally can press INTERACT to cross straight to it. Crossing (ult) brings back up to two allies who died within 10 m in the last 15 s, where they fell."
	h.counters = [&"bombard", &"vesper", &"cairn"]
	h.countered_by = [&"sable", &"harrier", &"wisp"]
	h.synergies = [&"harrier", &"sable", &"wisp"]
	h.hero_script = load("res://src/heroes/behaviors/FerryBehavior.gd")
	# Body
	h.movement = A.movement(5.5, 6.4)
	h.movement.footstep_interval = 0.4
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.8
	h.visual.head = HeroVisualData.HeadShape.HOOD
	h.visual.extras = [HeroVisualData.Extra.CLOAK, HeroVisualData.Extra.HALO]
	h.visual.primary_color = Color(0.2, 0.33, 0.4)
	h.visual.secondary_color = Color(0.1, 0.14, 0.19)
	h.visual.accent_color = Color(0.6, 0.95, 0.9)
	h.visual.emissive_color = Color(0.5, 0.9, 1.0)
	h.visual.emissive_strength = 2.6
	h.visual.metallic = 0.1
	h.visual.roughness = 0.75
	h.visual.weapon_style = &"lantern"
	h.visual.weapon_scale = 1.35
	h.visual.arms_color = Color(0.18, 0.26, 0.3)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Tall and narrow: deep hood, long sea-dark cloak, a faint halo of drowned light behind the head and a lantern held out in front. Reads as 'the one who walks in the dark' - and as a support, not a sniper, because of the halo and lantern."
	h.audio.footstep_set = &"boots_light"
	h.audio.ult_stinger = &"ult_ferry"
	h.audio.ult_stinger_enemy = &"ult_ferry_enemy"
	h.audio.callout_tone = &"radio_c"
	h.audio.voice_pitch = 0.95
	# AI
	h.ai.preferred_range = 12.0; h.ai.min_range = 3.0; h.ai.max_effective_range = 35.0
	h.ai.aggression = 0.3; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 0.5
	h.ai.sticks_to_tank = 0.7; h.ai.heals = true; h.ai.heal_range = 20.0; h.ai.builds = true
	h.ai.ult_style = &"save"; h.ai.ult_min_targets = 1; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.1
	# --- Primary: Lantern Bolt (fast damage projectile)
	var prim := A.weapon(&"ferry_bolt", "Lantern Bolt", "Fast bolts of drowned light: 35 damage, 2.5 shots/s, 10 per lantern.", 2.5, 10, 1.4)
	var bolt := A.projectile(35.0, 45.0)
	bolt.radius = 0.12; bolt.lifetime = 2.5; bolt.headshot = false
	bolt.visual_id = &"flare"
	prim.effects = [bolt]
	A.pres(prim, &"ferry_bolt_fire", &"ferry_bolt_tail", &"", Color(0.6, 0.95, 1.0))
	prim.presentation.muzzle_vfx = &"ferry_bolt_muzzle"
	prim.presentation.impact_vfx = &"ferry_bolt_impact"
	prim.presentation.projectile_vfx = &"flare"
	prim.presentation.crosshair = &"dot"
	A.feel(prim, 0.7, 0.25, 0.06, 2.5, 0.03)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 36.0, 14.0)
	h.primary = prim
	# --- Secondary: Ferrylight (healing lantern that bursts on the first ally or surface)
	var light := A.weapon(&"ferry_light", "Ferrylight", "Hold: lob a lantern of healing light once a second. It bursts on the first ally, enemy or surface it touches: allies within 2.5 m are healed for 50; an enemy hit directly takes 10.", 1.0, 0, 0.0)
	var orb := HealingShellEffect.new()
	orb.count = 1; orb.speed = 40.0; orb.damage = 10.0; orb.radius = 0.16; orb.lifetime = 1.2
	orb.heal = 50.0; orb.heal_radius = 2.5; orb.heal_self = false
	orb.visual_id = &"orb"
	orb.burst_vfx = &"ferry_light_burst"
	light.effects = [orb]
	A.pres(light, &"ferry_light_fire", &"", &"", Color(0.5, 1.0, 0.95))
	light.presentation.muzzle_vfx = &"ferry_light_muzzle"
	light.presentation.impact_vfx = &"ferry_light_burst"
	light.presentation.impact_decal = &""
	light.presentation.projectile_vfx = &"orb"
	light.presentation.crosshair = &"circle"
	A.feel(light, 0.4, 0.15, 0.05, 2.0, 0.01)
	A.ai(light, AbilityAIHints.Intent.HEAL, 0.0, 30.0, 10.0, 0.75)
	light.ai.target_ally = true
	h.secondary = light
	# --- Ability 1: Undertow (pull the aimed ally to Ferry)
	var under := A.ability(&"ferry_undertow", "Undertow", "Aim at an ally 4-20 m away: the current drags them to your side and heals them for 40.", AbilityData.Trigger.PRESS, 10.0)
	under.behavior = load("res://src/heroes/abilities/FerryUndertowBehavior.gd")
	var us := A.status(&"ferry_undertow", "Undertow", 1.0)
	us.cleansable = false
	us.color = Color(0.5, 0.9, 1.0)
	var us_apply := ApplyStatusEffect.new()
	us_apply.who = ApplyStatusEffect.Who.TARGET
	us_apply.status = us
	var uh := HealEffect.new()
	uh.who = HealEffect.Who.TARGET
	uh.amount = 40.0
	under.effects = [us_apply, uh]
	under.presentation.sound_fire = &"ferry_undertow_fire"
	under.presentation.cast_vfx = &"ferry_undertow_cast"
	under.presentation.anim_tag = &"throw"
	under.presentation.crosshair = &"bracket"
	under.presentation.camera_shake = 0.03
	A.ai(under, AbilityAIHints.Intent.HEAL, 4.0, 20.0, 10.0, 0.6)
	under.ai.target_ally = true
	under.ai.combo_tags = [&"pull_ally"]
	h.ability_1 = under
	# --- Ability 2: Waystone (spawn teleport beacon)
	var way := A.ability(&"ferry_waystone", "Waystone", "Plant a beacon (250 hp, 60 s). For 5 s after spawning, allies can press INTERACT to cross straight to it. One waystone at a time; planting again moves it.", AbilityData.Trigger.PRESS, 20.0)
	var dep := DeployEffect.new()
	dep.deployable_script = load("res://src/heroes/deployables/FerryWaystone.gd")
	dep.placement = DeployEffect.Placement.IN_FRONT
	dep.distance = 2.0
	dep.health = 250.0
	dep.lifetime = 60.0
	dep.max_instances = 1
	dep.kind = &"waystone"
	dep.visual_id = &"waystone"
	way.effects = [dep]
	way.presentation.sound_fire = &"ferry_waystone_fire"
	way.presentation.cast_vfx = &"ferry_waystone_cast"
	way.presentation.anim_tag = &"cast"
	A.ai(way, AbilityAIHints.Intent.UTILITY, 0.0, 6.0, 3.0, 0.5)
	way.ai.needs_line_of_sight = false
	way.ai.target_ground = true
	h.ability_2 = way
	# --- Ultimate: Crossing (3 s cast, resurrect up to two dead allies within 10 m)
	var ult := A.ultimate(&"ferry_crossing", "Crossing", "Raise the lantern for 3 s (rooted, invulnerable). Then up to two allies who died within 10 m in the last 15 s return where they fell. Living allies nearby are healed for 30/s during the cast and 60 when it completes.", 1700.0)
	ult.cast_time = 3.0
	ult.lock_movement = true
	ult.cancel_on_cc = false
	ult.cancel_on_damage = false
	ult.behavior = load("res://src/heroes/abilities/FerryCrossingBehavior.gd")
	var inv := A.status(&"ferry_crossing", "Crossing", 3.0)
	inv.invulnerable = true
	inv.unstoppable = true
	inv.cleansable = false
	inv.color = Color(0.6, 0.95, 1.0)
	ult.self_status_while_active = inv
	var burst := AreaEffect.new()
	burst.radius = 10.0; burst.heal = 60.0; burst.heal_self = true; burst.damage = 0.0
	burst.requires_los = false; burst.min_fraction = 0.7
	burst.vfx_id = &"ferry_crossing_ring"
	ult.effects = [burst]
	ult.presentation.sound_cast = &"ferry_crossing_cast"
	ult.presentation.sound_loop = &"ferry_crossing_loop"
	ult.presentation.sound_fire = &"ferry_crossing_fire"
	ult.presentation.sound_end = &"ferry_crossing_end"
	ult.presentation.cast_vfx = &"ferry_crossing_cast"
	ult.presentation.loop_vfx = &"ferry_crossing_loop"
	ult.presentation.voice_line = &"ferry_ult_line"
	ult.presentation.voice_line_enemy = &"ferry_ult_line_enemy"
	ult.presentation.camera_shake = 0.1
	ult.presentation.self_glow = Color(0.6, 0.95, 1.0, 1.0)
	A.ai(ult, AbilityAIHints.Intent.UTILITY, 0.0, 10.0, 5.0, 0.8)
	ult.ai.needs_line_of_sight = false
	ult.ai.telegraph_seconds = 3.0
	ult.ai.combo_tags = [&"resurrect"]
	h.ultimate = ult
	return h
