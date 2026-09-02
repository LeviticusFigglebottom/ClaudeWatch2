extends RefCounted
## ROOK — Bulwark. Gravity engineer in a hover-frame. ★ Lift: enemies in a cone float helplessly for
## 1.6 s (can still shoot, cannot move). Primary: gravity mortar (slow, splash). Density: self damage
## reduction + heavier. Ult Ground Zero: a gravity well that pulls everything in and detonates.
## Zone tank; countered by unstoppable/cleanse.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"rook", "Rook", RF.Role.BULWARK, 350.0, 0.0, 200.0)
	h.codename = "The Engineer"
	h.sort_order = 5
	h.tagline = "Down is a suggestion."
	h.lore = "Rook kept Meridian Station's gravity plating alive for six years after the rest of the segment went dark, alone with the hum and a workshop full of field coils. When the Charters finally sent a salvage team she met them at the airlock in a hover-frame she had built from the station's own bones, and asked, politely, what they were offering. She has never fully trusted the ground since. She does not need to."
	h.playstyle = "Hold a zone and make it expensive to enter. Mortar shells arc over cover and punish groups; Lift freezes a whole cone of divers in the air where your strikers can pick them off. Density when you are focused: 30% less damage, unstoppable, and landing on someone hurts them. Ground Zero is the payoff for any pull or slow: everything in 8 m is dragged to the center and detonated."
	h.theme_color = Color(0.6, 0.42, 0.98)
	h.difficulty = 3
	h.unique_mechanic = "Lift: every enemy in a 35 degree cone within 12 m floats helplessly for 1.6 s. They can still aim, shoot and use abilities, but cannot move or jump. Unstoppable enemies are immune."
	h.counters = [&"harrier", &"sable", &"ricochet", &"wisp"]
	h.countered_by = [&"kiln", &"tallow", &"suture", &"cathedral"]
	h.synergies = [&"bombard", &"coil", &"ballast", &"vesper"]
	h.hero_script = load("res://src/heroes/behaviors/RookBehavior.gd")
	# Body: hover frame. Shields regenerate; floaty jumps, slow fall.
	h.movement = A.movement(5.2, 6.8, 54.0, 0.45, 0.85)
	h.movement.footstep_interval = 0.5
	h.movement.capsule_height = 1.95
	h.movement.eye_height = 1.66
	h.movement.crouch_eye_height = 1.05
	h.movement.slow_fall = true
	h.movement.slow_fall_terminal = 5.5
	h.movement.air_friction = 0.3
	h.movement.camera_bob_scale = 0.6
	h.hitbox.body_radius = 0.44
	h.hitbox.head_radius = 0.22
	h.hitbox.head_height = 1.7
	h.hitbox.head_crouch_height = 1.1
	h.hitbox.body_top = 1.4
	h.hitbox.body_crouch_top = 0.9
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.9
	h.visual.shoulder_width = 0.62
	h.visual.head = HeroVisualData.HeadShape.ANTENNA
	h.visual.extras = [HeroVisualData.Extra.JETPACK, HeroVisualData.Extra.HALO]
	h.visual.primary_color = Color(0.82, 0.84, 0.9)
	h.visual.secondary_color = Color(0.2, 0.18, 0.3)
	h.visual.accent_color = Color(0.98, 0.6, 0.2)
	h.visual.emissive_color = Color(0.6, 0.42, 0.98)
	h.visual.emissive_strength = 2.4
	h.visual.metallic = 0.7
	h.visual.roughness = 0.3
	h.visual.weapon_style = &"mortar"
	h.visual.weapon_scale = 1.2
	h.visual.arms_color = Color(0.3, 0.28, 0.4)
	h.visual.stance = &"hover"
	h.visual.silhouette_notes = "White station-panel plating with amber warning stripes, a boxy antenna head, twin field coils on the back and a violet gravity ring floating above the shoulders. A stubby mortar held low. Reads as a hovering machine, not a soldier."
	h.audio.footstep_set = &"boots_medium"
	h.audio.ult_stinger = &"ult_rook"
	h.audio.ult_stinger_enemy = &"ult_rook_enemy"
	h.audio.voice_pitch = 1.05
	h.audio.callout_tone = &"radio_c"
	# AI
	h.ai.preferred_range = 13.0; h.ai.min_range = 4.0; h.ai.max_effective_range = 28.0
	h.ai.aggression = 0.4; h.ai.self_preservation = 0.55; h.ai.prefers_high_ground = 0.6; h.ai.sticks_to_tank = 0.0
	h.ai.ult_style = &"combo_payoff"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.3
	# --- Primary: Gravity Mortar (slow arcing shell, splash)
	var prim := A.weapon(&"rook_mortar", "Gravity Mortar", "Lobs a gravity shell at 24 m/s in a high arc: 55 damage on a direct hit, 45 splash within 3 m. Slow, generous, arcs over any wall.", 1.1, 5, 1.8)
	var shell := A.projectile(55.0, 24.0)
	shell.gravity = 9.0
	shell.radius = 0.25
	shell.lifetime = 4.0
	shell.splash_radius = 3.0
	shell.splash_damage = 45.0
	shell.splash_min_fraction = 0.4
	shell.knockback = 3.0
	shell.lob_arc = true
	shell.visual_id = &"mortar"
	prim.effects = [shell]
	A.pres(prim, &"rook_mortar_fire", &"rook_mortar_tail", &"", Color(0.7, 0.55, 1.0))
	prim.presentation.muzzle_vfx = &"rook_mortar_muzzle"
	prim.presentation.impact_vfx = &"rook_mortar_impact"
	prim.presentation.sound_impact = &"rook_mortar_impact"
	prim.presentation.projectile_vfx = &"mortar"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.crosshair = &"circle"
	A.feel(prim, 3.0, 0.3, 0.2, 7.0, 0.14, 8.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 4.0, 30.0, 14.0)
	prim.ai.needs_line_of_sight = false
	h.primary = prim
	# --- Secondary: Singularity Shell (pulls on impact)
	var sec := A.ability(&"rook_singularity", "Singularity Shell", "Fire a collapsing shell: 40 damage on hit, 30 splash, and every enemy within 4.5 m of the impact is yanked toward it and slowed to 50% for 1.2 s. Groups them for the mortar.", AbilityData.Trigger.PRESS, 7.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	sec.recovery = 0.3
	var sing := A.projectile(40.0, 26.0)
	sing.gravity = 9.0
	sing.radius = 0.25
	sing.lifetime = 4.0
	sing.splash_radius = 3.0
	sing.splash_damage = 30.0
	sing.splash_min_fraction = 0.5
	sing.lob_arc = true
	sing.visual_id = &"orb"
	var crush := A.status(&"rook_singularity_slow", "Crushed", 1.2)
	crush.speed_mult = 0.5
	crush.is_debuff = true
	crush.is_crowd_control = true
	crush.cleansable = true
	crush.color = Color(0.6, 0.42, 0.98)
	crush.tags = [&"slow"]
	var yank := KnockbackEffect.new()
	yank.pull = true
	yank.radius = 4.5
	yank.force = 8.0
	yank.upward = 0.35
	yank.center_on_point = true
	yank.requires_los = false
	var crush_area := ApplyStatusEffect.new()
	crush_area.status = crush
	crush_area.who = ApplyStatusEffect.Who.ENEMIES_IN_RADIUS
	crush_area.radius = 4.5
	crush_area.center_on_point = true
	crush_area.requires_los = false
	sing.on_hit_effects = [yank, crush_area]
	sec.effects = [sing]
	A.pres(sec, &"rook_singularity_fire", &"rook_singularity_tail", &"", Color(0.5, 0.3, 1.0))
	sec.presentation.muzzle_vfx = &"rook_mortar_muzzle"
	sec.presentation.impact_vfx = &"rook_mortar_impact"
	sec.presentation.sound_impact = &"rook_singularity_impact"
	sec.presentation.projectile_vfx = &"orb"
	sec.presentation.crosshair = &"circle"
	A.feel(sec, 3.2, 0.3, 0.2, 7.0, 0.14)
	A.ai(sec, AbilityAIHints.Intent.CROWD_CONTROL, 5.0, 26.0, 13.0, 0.6)
	sec.ai.needs_line_of_sight = false
	sec.ai.combo_tags = [&"pull", &"group"]
	h.secondary = sec
	# --- Ability 1: Lift (★ signature)
	var lift := A.ability(&"rook_lift", "Lift", "Cut gravity in a 35 degree cone to 12 m: every enemy caught floats helplessly for 1.6 s. They can still shoot, but cannot move, jump or escape. Unstoppable enemies are immune.", AbilityData.Trigger.PRESS, 12.0)
	lift.behavior = load("res://src/heroes/abilities/RookLiftBehavior.gd")
	lift.recovery = 0.3
	lift.cast_time = 0.15
	lift.cancel_on_cc = true
	var lifted := A.status(&"rook_lifted", "Lifted", 1.6)
	lifted.airborne = true
	lifted.rooted = true
	lifted.speed_mult = 0.0
	lifted.is_debuff = true
	lifted.is_crowd_control = true
	lifted.cleansable = true
	lifted.color = Color(0.7, 0.55, 1.0)
	lifted.tags = [&"displace", &"root"]
	var lift_carrier := ApplyStatusEffect.new()   # carries the status into data / StatusLibrary
	lift_carrier.status = lifted
	lift_carrier.who = ApplyStatusEffect.Who.TARGET
	lift_carrier.enabled = false
	lift.effects = [lift_carrier]
	lift.presentation.sound_cast = &"rook_lift_cast"
	lift.presentation.sound_fire = &"rook_lift_fire"
	lift.presentation.sound_end = &"rook_lift_end"
	lift.presentation.cast_vfx = &"rook_lift"
	lift.presentation.muzzle_vfx = &"rook_lift"
	lift.presentation.anim_tag = &"cast"
	lift.presentation.crosshair = &"bracket"
	A.feel(lift, 0.0, 0.0, 0.1, 4.0, 0.15)
	A.ai(lift, AbilityAIHints.Intent.CROWD_CONTROL, 2.0, 12.0, 7.0, 0.75)
	lift.ai.needs_line_of_sight = true
	lift.ai.hold_for_combo = true
	lift.ai.combo_tags = [&"lift", &"root", &"setup"]
	lift.ai.telegraph_seconds = 0.15
	h.ability_1 = lift
	# --- Ability 2: Density
	var dens := A.ability(&"rook_density", "Density", "Triple your mass for 3 s: 30% less damage taken, unstoppable, 2.5x gravity, 85% speed. Land on enemies from height while dense to slam them for 45.", AbilityData.Trigger.PRESS, 10.0)
	dens.active_duration = 3.0
	dens.cancel_on_cc = false
	dens.recovery = 0.1
	var dense := A.status(&"rook_density", "Dense", 3.0)
	dense.damage_taken_mult = 0.7
	dense.gravity_mult = 2.5
	dense.unstoppable = true
	dense.speed_mult = 0.85
	dense.cleansable = false
	dense.color = Color(0.98, 0.6, 0.2)
	dens.self_status_while_active = dense
	dens.presentation.sound_cast = &"rook_density_cast"
	dens.presentation.sound_loop = &"rook_density_loop"
	dens.presentation.sound_end = &"rook_density_end"
	dens.presentation.cast_vfx = &"rook_density_cast"
	dens.presentation.loop_vfx = &"rook_density_loop"
	dens.presentation.self_glow = Color(0.98, 0.6, 0.2, 1.0)
	dens.presentation.anim_tag = &"cast"
	A.feel(dens, 0.0, 0.0, 0.08, 2.0, 0.12)
	A.ai(dens, AbilityAIHints.Intent.DEFENSIVE, 0.0, 16.0, 5.0, 0.6)
	dens.ai.use_when_health_below = 0.7
	dens.ai.counter_tags = [&"displace", &"pull", &"root"]
	h.ability_2 = dens
	# --- Ultimate: Ground Zero (gravity well -> detonation)
	var ult := A.ultimate(&"rook_ground_zero", "Ground Zero", "Drop a gravity well where you aim (within 22 m). For 2.5 s every enemy within 8 m is dragged toward the center and slowed; then it detonates for 200 damage (120 at the edge) and throws them into the air. The payoff for any pull, root or slow.", 2000.0)
	ult.recovery = 0.4
	var well := DeployEffect.new()
	well.kind = &"rook_well"
	well.visual_id = &"rook_well"
	well.placement = DeployEffect.Placement.AIMED_GROUND
	well.max_range = 22.0
	well.health = 0.0
	well.lifetime = 0.0
	well.max_instances = 1
	well.deployable_script = load("res://src/heroes/deployables/RookGroundZero.gd")
	well.params = {"radius": 8.0, "charge_time": 2.5, "damage": 200.0, "slow": "rook_well_slow"}
	var well_slow := A.status(&"rook_well_slow", "Event Horizon", 0.4)
	well_slow.speed_mult = 0.55
	well_slow.is_debuff = true
	well_slow.is_crowd_control = true
	well_slow.cleansable = true
	well_slow.color = Color(0.5, 0.3, 1.0)
	well_slow.tags = [&"slow", &"pull"]
	var slow_carrier := ApplyStatusEffect.new()   # status carrier for the deployable (StatusLibrary)
	slow_carrier.status = well_slow
	slow_carrier.who = ApplyStatusEffect.Who.TARGET
	slow_carrier.enabled = false
	ult.effects = [well, slow_carrier]
	ult.presentation.sound_cast = &"rook_ground_zero_cast"
	ult.presentation.sound_loop = &"rook_ground_zero_loop"
	ult.presentation.sound_end = &"rook_ground_zero_end"
	ult.presentation.cast_vfx = &"rook_ground_zero"
	ult.presentation.area_vfx = &"rook_ground_zero_pull"
	ult.presentation.voice_line = &"rook_ult_line"
	ult.presentation.voice_line_enemy = &"rook_ult_line_enemy"
	ult.presentation.self_glow = Color(0.6, 0.42, 0.98, 1.0)
	ult.presentation.crosshair = &"circle"
	A.feel(ult, 0.0, 0.0, 0.12, 4.0, 0.3)
	A.ai(ult, AbilityAIHints.Intent.ZONE, 4.0, 22.0, 12.0, 0.75)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.target_ground = true
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"aoe_damage", &"payoff"]
	ult.ai.telegraph_seconds = 2.5
	h.ultimate = ult
	return h
