extends RefCounted
## HARRIER — Striker. Courier in a jet-rig. ★ Flight: hold jump in the air to fly on fuel. Twin SMGs
## shred up close, Dive slams down out of the sky, Afterburn refuels mid-flight, Strafing Run carpets
## her flight path with rockets. Counters snipers and ground poke; countered by hitscan.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"harrier", "Harrier", RF.Role.STRIKER, 200.0)
	h.codename = "The Courier"
	h.sort_order = 11
	h.tagline = "Nothing on the ground can catch me."
	h.lore = "Harrier ran parcels between the hab-stacks of the Pearl River Charter on a jet-rig she rebuilt from a crashed maintenance drone: three and a half seconds of thrust, then glide, then pray. Couriers who lived learned to land on people. When the Cores started dropping, the Charters worked out that a woman who can deliver anything can also deliver herself, twin SMGs first, into the middle of your backline."
	h.playstyle = "Hold jump to fly. Take angles nobody else can reach, shred one target with the SMGs, Dive onto whoever is low, and Afterburn out before hitscan finds you. Fuel is your second health bar: never start a fight on an empty tank."
	h.theme_color = Color(0.36, 0.78, 0.98)
	h.difficulty = 2
	h.unique_mechanic = "Flight: hold jump while airborne to fly on 3.5 s of fuel (refills 1.2 s of fuel per second on the ground). Dive only works in the air, Afterburn refills the tank instantly, Strafing Run makes it bottomless."
	h.counters = [&"vesper", &"bombard", &"cairn"]
	h.countered_by = [&"vesper", &"coil", &"ballast"]
	h.synergies = [&"cadence", &"ferry", &"wisp"]
	h.hero_script = load("res://src/heroes/behaviors/HarrierBehavior.gd")
	h.hero_resource_name = "Fuel"
	h.hero_resource_max = 3.5
	h.hero_resource_regen = 0.0
	# Body
	h.movement = A.movement(6.0, 6.4, 65.0, 0.6)
	h.movement.hover_enabled = true
	h.movement.hover_thrust = 5.5
	h.movement.hover_fuel = 3.5
	h.movement.hover_fuel_regen = 1.2
	h.movement.jump_count = 1
	h.movement.air_accel = 22.0
	h.movement.air_friction = 0.35
	h.movement.footstep_interval = 0.38
	h.movement.camera_bob_scale = 0.8
	h.movement.mass = 0.9
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.78
	h.visual.shoulder_width = 0.5
	h.visual.head = HeroVisualData.HeadShape.HELMET_VISOR
	h.visual.extras = [HeroVisualData.Extra.WINGS, HeroVisualData.Extra.JETPACK]
	h.visual.primary_color = Color(0.9, 0.91, 0.94)
	h.visual.secondary_color = Color(0.2, 0.24, 0.3)
	h.visual.accent_color = Color(0.98, 0.55, 0.2)
	h.visual.emissive_color = Color(0.4, 0.85, 1.0)
	h.visual.emissive_strength = 2.5
	h.visual.metallic = 0.45
	h.visual.roughness = 0.45
	h.visual.weapon_style = &"pistols"
	h.visual.weapon_scale = 1.05
	h.visual.arms_color = Color(0.22, 0.25, 0.3)
	h.visual.stance = &"hover"
	h.visual.silhouette_notes = "Small and winged: visored helmet, swept glowing wings over twin jet cans, a pistol in each hand. Reads as 'the one in the air' at any range; the wing glow doubles as her fuel tell."
	h.audio.footstep_set = &"boots_light"
	h.audio.footstep_volume = 0.8
	h.audio.ult_stinger = &"ult_harrier"
	h.audio.ult_stinger_enemy = &"ult_harrier_enemy"
	h.audio.jump = &"harrier_jet_jump"
	h.audio.land = &"harrier_jet_land"
	h.audio.callout_tone = &"radio_b"
	# AI
	h.ai.preferred_range = 9.0; h.ai.min_range = 2.0; h.ai.max_effective_range = 26.0
	h.ai.aggression = 0.75; h.ai.self_preservation = 0.45; h.ai.flanker = true; h.ai.dives = true
	h.ai.prefers_high_ground = 0.65; h.ai.sticks_to_tank = 0.2
	h.ai.ult_style = &"engage"; h.ai.ult_min_targets = 1; h.ai.strafe_style = &"hover"
	h.ai.aim_difficulty_scale = 1.0
	# --- Primary: Twin SMGs (hitscan, small fast kicks)
	var prim := A.weapon(&"harrier_smg", "Twin SMGs", "Two machine pistols firing together: 7 damage per bullet, 16 bullets per second (112 DPS), headshots double. Accurate to 15 m, falls to half damage by 30 m. 40 rounds, 1.3 s reload.", 16.0, 40, 1.3)
	var hs := A.hitscan(7.0, 60.0)
	hs.spread_deg = 1.6; hs.spread_moving_deg = 1.2; hs.spread_airborne_deg = 0.8
	hs.falloff_start = 15.0; hs.falloff_end = 30.0; hs.falloff_min = 0.5
	hs.headshot = true
	prim.effects = [hs]
	A.pres(prim, &"harrier_smg_fire", &"harrier_smg_tail", &"bullet", Color(0.78, 0.92, 1.0))
	prim.presentation.tracer_width = 0.022
	prim.presentation.muzzle_vfx = &"harrier_smg_muzzle"
	prim.presentation.impact_vfx = &"harrier_smg_impact"
	prim.presentation.impact_decal = &"bullet_hole"
	prim.presentation.sound_impact = &"harrier_smg_impact"
	prim.presentation.crosshair = &"cross"
	prim.presentation.spread_visual_scale = 1.2
	prim.presentation.anim_tag = &"fire"
	A.feel(prim, 0.32, 0.28, 0.02, 1.1, 0.015, 20.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 30.0, 9.0)
	h.primary = prim
	# --- Secondary: Pod Rockets (two micro-rockets from the jet-rig pods; big slow kick)
	var sec := A.ability(&"harrier_rockets", "Pod Rockets", "Fire two micro-rockets from the jet-rig pods: 35 damage on a direct hit plus 25 splash damage in 2.5 m. 4 s cooldown.", AbilityData.Trigger.PRESS, 4.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	var rk := A.projectile(35.0, 45.0)
	rk.count = 2; rk.spread_deg = 3.0; rk.radius = 0.12; rk.lifetime = 2.5
	rk.splash_radius = 2.5; rk.splash_damage = 25.0; rk.splash_min_fraction = 0.4; rk.knockback = 2.0
	rk.inherit_velocity = 0.3
	rk.visual_id = &"shell"
	sec.effects = [rk]
	A.pres(sec, &"harrier_rockets_fire", &"harrier_rockets_tail", &"", Color(1.0, 0.7, 0.4))
	sec.presentation.muzzle_vfx = &"harrier_rockets_muzzle"
	sec.presentation.impact_vfx = &"explosion"
	sec.presentation.impact_decal = &"scorch"
	sec.presentation.sound_impact = &"harrier_rockets_impact"
	sec.presentation.projectile_vfx = &"shell"
	sec.presentation.crosshair = &"circle"
	sec.presentation.anim_tag = &"fire"
	A.feel(sec, 2.4, 0.5, 0.12, 5.0, 0.12, 8.0)
	A.ai(sec, AbilityAIHints.Intent.DAMAGE, 3.0, 30.0, 9.0, 0.55)
	sec.ai.combo_tags = [&"aoe_damage"]
	h.secondary = sec
	# --- Ability 1: Dive (airborne only: slam down, splash on landing)
	var dive := A.ability(&"harrier_dive", "Dive", "Only in the air: cut thrust and slam straight down at 30 m/s. Landing deals 80 damage in 4 m and knocks enemies away. 9 s cooldown.", AbilityData.Trigger.PRESS, 9.0)
	dive.behavior = load("res://src/heroes/abilities/HarrierDiveBehavior.gd")
	dive.active_duration = 2.5
	dive.allow_airborne = true
	dive.requires_ground = false
	dive.cancel_on_cc = false
	dive.cooldown_starts_on_end = true
	dive.presentation.sound_cast = &"harrier_dive_cast"
	dive.presentation.sound_loop = &"harrier_dive_loop"
	dive.presentation.sound_end = &"harrier_dive_end"
	dive.presentation.sound_impact = &"harrier_dive_impact"
	dive.presentation.cast_vfx = &"harrier_dive_cast"
	dive.presentation.loop_vfx = &"harrier_dive_loop"
	dive.presentation.end_vfx = &"harrier_dive_end"
	dive.presentation.area_vfx = &"harrier_dive_explosion"
	dive.presentation.anim_tag = &"cast"
	dive.presentation.camera_shake = 0.3
	dive.presentation.self_glow = Color(0.4, 0.85, 1.0, 0.8)
	dive.presentation.crosshair = &"bracket"
	A.ai(dive, AbilityAIHints.Intent.DAMAGE, 0.0, 7.0, 3.0, 0.8)
	dive.ai.needs_line_of_sight = false
	dive.ai.combo_tags = [&"aoe_damage"]
	h.ability_1 = dive
	# --- Ability 2: Afterburn (speed + instant fuel refill)
	var burn := A.ability(&"harrier_afterburn", "Afterburn", "Dump the reserve tank: +40% move speed for 3 s and your Flight fuel refills instantly. 10 s cooldown.", AbilityData.Trigger.PRESS, 10.0)
	burn.behavior = load("res://src/heroes/abilities/HarrierAfterburnBehavior.gd")
	burn.allow_airborne = true
	var burn_st := A.status(&"harrier_afterburn_status", "Afterburn", 3.0)
	burn_st.speed_mult = 1.4
	burn_st.cleansable = false
	burn_st.color = Color(0.4, 0.85, 1.0)
	burn_st.vfx_id = &"harrier_afterburn_loop"
	var burn_fx := ApplyStatusEffect.new()
	burn_fx.status = burn_st
	burn_fx.who = ApplyStatusEffect.Who.SELF
	burn.effects = [burn_fx]
	burn.presentation.sound_fire = &"harrier_afterburn_fire"
	burn.presentation.sound_tail = &"harrier_afterburn_tail"
	burn.presentation.sound_end = &"harrier_afterburn_end"
	burn.presentation.cast_vfx = &"harrier_afterburn_cast"
	burn.presentation.anim_tag = &"cast"
	burn.presentation.camera_shake = 0.08
	burn.presentation.self_glow = Color(0.4, 0.85, 1.0, 0.6)
	A.ai(burn, AbilityAIHints.Intent.MOBILITY, 0.0, 40.0, 15.0, 0.5)
	burn.ai.use_when_health_below = 0.4
	burn.ai.needs_line_of_sight = false
	h.ability_2 = burn
	# --- Ultimate: Strafing Run (4 s of rockets straight down along her flight path)
	var ult := A.ultimate(&"harrier_strafing_run", "Strafing Run", "For 4 s: +50% speed, bottomless fuel, and a rocket drops straight down from your position every 0.25 s, each dealing 90 damage in 3.5 m. Fly the line you want carpeted.", 1700.0)
	ult.active_duration = 4.0
	ult.behavior = load("res://src/heroes/abilities/HarrierStrafingRunBehavior.gd")
	ult.cancel_on_cc = false
	ult.allow_airborne = true
	var run_st := A.status(&"harrier_strafing_status", "Strafing Run", 4.0)
	run_st.speed_mult = 1.5
	run_st.cleansable = false
	run_st.color = Color(1.0, 0.6, 0.3)
	ult.self_status_while_active = run_st
	ult.presentation.sound_cast = &"harrier_strafing_run_cast"
	ult.presentation.sound_loop = &"harrier_strafing_run_loop"
	ult.presentation.sound_end = &"harrier_strafing_run_end"
	ult.presentation.sound_fire = &"harrier_strafing_run_fire"
	ult.presentation.sound_impact = &"harrier_strafing_run_impact"
	ult.presentation.cast_vfx = &"harrier_strafing_run_cast"
	ult.presentation.loop_vfx = &"harrier_strafing_run_loop"
	ult.presentation.end_vfx = &"harrier_strafing_run_end"
	ult.presentation.projectile_vfx = &"shell"
	ult.presentation.voice_line = &"harrier_ult_line"
	ult.presentation.voice_line_enemy = &"harrier_ult_line_enemy"
	ult.presentation.self_glow = Color(1.0, 0.6, 0.3, 0.9)
	ult.presentation.camera_shake = 0.2
	A.ai(ult, AbilityAIHints.Intent.DAMAGE, 0.0, 12.0, 5.0, 0.7)
	ult.ai.needs_enemies_in_radius = 1
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"aoe_damage"]
	h.ultimate = ult
	return h
