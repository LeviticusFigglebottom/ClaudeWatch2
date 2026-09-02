extends RefCounted
## BOMBARD — Striker. Artillery spotter whose mortar arcs over cover. Signature: indirect fire — the
## shell's landing point is shown as a reticle through walls (BombardBehavior + BombardVfx.reticle).
## Counters stationary bulwarks; countered by dive.


## Registers a status with StatusLibrary without ever firing it (scanner reads effects, not params).
static func _reg(status: StatusData) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = status
	e.enabled = false
	return e


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"bombard", "Bombard", RF.Role.STRIKER, 225.0)
	h.codename = "The Spotter"
	h.sort_order = 15
	h.tagline = "You don't need to see it. I do."
	h.lore = "Bombard called fire for the Andean Charter's border militia until a ceasefire made her obsolete. She kept the mortar, rebuilt the spotter drone from a weather satellite that fell in her yard, and hires out to whoever holds the high ground. She talks to her shells while they're in the air."
	h.playstyle = "Sit behind cover on high ground and drop shells where the reticle says they land: you never need a sightline. Tag the fight with the Spotter drone, airburst anyone hiding behind a wall, and save Barrage for a held point. You are helpless when dived: Kick Charge is your only way out."
	h.theme_color = Color(0.86, 0.64, 0.24)
	h.difficulty = 3
	h.unique_mechanic = "Indirect fire: the mortar's predicted landing point is drawn as a world-space reticle visible through walls, so every shell can be lobbed over cover blind."
	h.counters = [&"cathedral", &"rook", &"cairn", &"kiln"]
	h.countered_by = [&"harrier", &"sable", &"wisp"]
	h.synergies = [&"vesper", &"rook", &"cairn"]
	h.hero_script = load("res://src/heroes/behaviors/BombardBehavior.gd")
	# Body: heavy-ish medium build carrying a mortar tube and an ammo backpack.
	h.movement = A.movement(5.3, 6.0, 55.0, 0.3)
	h.movement.footstep_interval = 0.46
	h.movement.mass = 1.15
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.9
	h.visual.shoulder_width = 0.64
	h.visual.head = HeroVisualData.HeadShape.HELMET_ROUND
	h.visual.extras = [HeroVisualData.Extra.BACKPACK, HeroVisualData.Extra.SHOULDER_PADS]
	h.visual.primary_color = Color(0.42, 0.44, 0.32)
	h.visual.secondary_color = Color(0.22, 0.2, 0.16)
	h.visual.accent_color = Color(0.82, 0.62, 0.24)
	h.visual.emissive_color = Color(1.0, 0.62, 0.2)
	h.visual.emissive_strength = 1.8
	h.visual.metallic = 0.45
	h.visual.roughness = 0.65
	h.visual.weapon_style = &"mortar"
	h.visual.weapon_scale = 1.25
	h.visual.arms_color = Color(0.36, 0.36, 0.3)
	h.visual.stance = &"brace"
	h.visual.silhouette_notes = "Broad shoulders, round helmet, a square ammo pack and a stubby mortar tube held at the hip. Reads as artillery: wide, planted, not fast."
	h.audio.footstep_set = &"boots_medium"
	h.audio.footstep_volume = 1.1
	h.audio.ult_stinger = &"ult_bombard"
	h.audio.ult_stinger_enemy = &"ult_bombard_enemy"
	# AI: long-range poker who wants elevation and hates being dived.
	h.ai.preferred_range = 24.0; h.ai.min_range = 8.0; h.ai.max_effective_range = 45.0
	h.ai.aggression = 0.25; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 1.0
	h.ai.poke_style = true; h.ai.sticks_to_tank = 0.35
	h.ai.ult_style = &"zone"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"crouch"
	h.ai.aim_difficulty_scale = 1.3
	# --- Primary: Field Mortar (lobbed shell, splash)
	var prim := A.weapon(&"bombard_mortar", "Field Mortar", "Lob a mortar shell. 60 direct damage plus 60 splash in 3.5 m. The reticle shows where it lands, even through walls. 4 shells, 2.2 s reload.", 1.1, 4, 2.2)
	var shell := A.projectile(60.0, 28.0)
	shell.gravity = 14.0; shell.radius = 0.18; shell.lifetime = 6.0
	shell.splash_radius = 3.5; shell.splash_damage = 60.0; shell.splash_min_fraction = 0.35
	shell.knockback = 2.5; shell.lob_arc = true; shell.visual_id = &"mortar"
	shell.spawn_offset = Vector3(0.3, -0.1, -0.5)
	prim.effects = [shell]
	A.pres(prim, &"bombard_mortar_fire", &"bombard_mortar_tail", &"shell", Color(1.0, 0.72, 0.35))
	prim.presentation.tracer_width = 0.05
	prim.presentation.muzzle_vfx = &"bombard_mortar_muzzle"
	prim.presentation.impact_vfx = &"explosion"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.sound_impact = &"bombard_mortar_impact"
	prim.presentation.projectile_vfx = &"mortar"
	prim.presentation.crosshair = &"bracket"
	A.feel(prim, 2.8, 0.5, 0.16, 6.0, 0.14, 9.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 6.0, 50.0, 24.0)
	prim.ai.telegraph_seconds = 0.9
	h.primary = prim
	# --- Secondary: Airburst (proximity-fused shell that bursts above targets)
	var air := A.ability(&"bombard_airburst", "Airburst", "Fire a shell with a proximity fuse: it bursts in the air when it passes above an enemy, dealing 90 splash damage in 4.5 m with no cover to hide behind.", AbilityData.Trigger.PRESS, 8.0)
	air.is_weapon = true
	air.usable_while_silenced = true
	var burst := BombardAirburstEffect.new()
	burst.damage = 30.0; burst.speed = 28.0; burst.gravity = 14.0; burst.radius = 0.18
	burst.lifetime = 1.5; burst.explode_on_expire = true
	burst.splash_radius = 4.5; burst.splash_damage = 90.0; burst.splash_min_fraction = 0.4
	burst.knockback = 3.0; burst.lob_arc = true; burst.visual_id = &"mortar"
	burst.proximity_radius = 3.2
	burst.spawn_offset = Vector3(0.3, -0.1, -0.5)
	air.effects = [burst]
	A.pres(air, &"bombard_airburst_fire", &"bombard_airburst_tail", &"shell", Color(1.0, 0.85, 0.45))
	air.presentation.tracer_width = 0.05
	air.presentation.muzzle_vfx = &"bombard_mortar_muzzle"
	air.presentation.impact_vfx = &"bombard_airburst_flash"
	air.presentation.impact_decal = &""
	air.presentation.sound_impact = &"bombard_airburst_impact"
	air.presentation.projectile_vfx = &"mortar"
	air.presentation.crosshair = &"bracket"
	air.presentation.anim_tag = &"fire"
	A.feel(air, 3.2, 0.6, 0.18, 7.0, 0.16, 9.0)
	A.ai(air, AbilityAIHints.Intent.DAMAGE, 8.0, 40.0, 22.0, 0.65)
	air.ai.needs_line_of_sight = false
	air.ai.telegraph_seconds = 0.8
	h.secondary = air
	# --- Ability 1: Spotter Drone (hovering reveal zone)
	var spot := A.ability(&"bombard_spotter", "Spotter Drone", "Launch a drone to a point up to 35 m away. For 8 s it hovers 4 m up and reveals every enemy within 10 m to your whole team through walls.", AbilityData.Trigger.PRESS, 14.0)
	var spotted := A.status(&"bombard_spotted", "Spotted", 1.2)
	spotted.revealed = true; spotted.is_debuff = true; spotted.cleansable = true
	spotted.color = Color(1.0, 0.7, 0.25)
	var drone := DeployEffect.new()
	drone.kind = &"spotter"
	drone.visual_id = &"spotter_drone"
	drone.placement = DeployEffect.Placement.AIMED_GROUND
	drone.max_range = 35.0
	drone.lifetime = 8.0
	drone.health = 0.0
	drone.max_instances = 1
	drone.deployable_script = load("res://src/heroes/deployables/BombardSpotterDrone.gd")
	drone.params = {"radius": 10.0, "hover": 4.0, "status": &"bombard_spotted", "interval": 0.5}
	spot.effects = [drone, _reg(spotted)]
	spot.presentation.sound_fire = &"bombard_spotter_fire"
	spot.presentation.sound_loop = &"bombard_spotter_loop"
	spot.presentation.sound_end = &"bombard_spotter_end"
	spot.presentation.cast_vfx = &"cast_generic"
	spot.presentation.area_vfx = &"bombard_spotter_light"
	spot.presentation.anim_tag = &"throw"
	spot.presentation.crosshair = &"circle"
	A.ai(spot, AbilityAIHints.Intent.REVEAL, 6.0, 35.0, 20.0, 0.6)
	spot.ai.needs_line_of_sight = false
	spot.ai.target_ground = true
	spot.ai.combo_tags = [&"reveal"]
	h.ability_1 = spot
	# --- Ability 2: Kick Charge (mortar-assisted backward leap)
	var kick := A.ability(&"bombard_kick", "Kick Charge", "Fire a charge at your feet and ride the recoil up and backward about 8 m. Your only answer to a dive, and the quickest way onto a perch.", AbilityData.Trigger.PRESS, 11.0)
	var leap := DashEffect.new()
	leap.direction = DashEffect.Dir.BACKWARD
	leap.speed = 7.5
	leap.vertical_boost = 9.5
	leap.preserve_momentum = 0.0
	kick.effects = [leap]
	kick.presentation.sound_fire = &"bombard_kick_fire"
	kick.presentation.sound_tail = &"bombard_kick_tail"
	kick.presentation.cast_vfx = &"explosion"
	kick.presentation.anim_tag = &"cast"
	kick.presentation.camera_shake = 0.22
	kick.presentation.viewmodel_kick = 0.1
	kick.presentation.camera_kick_pitch = 3.0
	A.ai(kick, AbilityAIHints.Intent.ESCAPE, 0.0, 8.0, 3.0, 0.6)
	kick.ai.use_when_health_below = 0.5
	kick.ai.needs_line_of_sight = false
	h.ability_2 = kick
	# --- Ultimate: Barrage (12 shells rain onto a marked 10 m area over 3 s)
	var ult := A.ultimate(&"bombard_barrage", "Barrage", "Mark a 10 m area up to 45 m away. Over the next 3 s, twelve shells fall on it from above: 70 direct, 70 splash each. Cover does not help.", 1800.0)
	ult.active_duration = 3.4
	ult.cancel_on_cc = false
	ult.behavior = load("res://src/heroes/abilities/BombardBarrageBehavior.gd")
	var mark := AreaEffect.new()
	mark.center_on_aim_hit = true
	mark.max_aim_distance = 45.0
	mark.radius = 10.0
	mark.damage = 0.0
	mark.requires_los = false
	mark.vfx_id = &"bombard_barrage_mark"
	ult.effects = [mark]
	ult.presentation.sound_cast = &"bombard_barrage_cast"
	ult.presentation.sound_loop = &"bombard_barrage_loop"
	ult.presentation.sound_end = &"bombard_barrage_end"
	ult.presentation.sound_impact = &"bombard_barrage_impact"
	ult.presentation.cast_vfx = &"bombard_barrage_cast"
	ult.presentation.loop_vfx = &"bombard_barrage_loop"
	ult.presentation.area_vfx = &"bombard_barrage_mark"
	ult.presentation.voice_line = &"bombard_ult_line"
	ult.presentation.voice_line_enemy = &"bombard_ult_line_enemy"
	ult.presentation.camera_shake = 0.3
	ult.presentation.crosshair = &"bracket"
	A.ai(ult, AbilityAIHints.Intent.ZONE, 8.0, 40.0, 24.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.target_ground = true
	ult.ai.telegraph_seconds = 0.7
	ult.ai.combo_tags = [&"aoe_damage"]
	h.ultimate = ult
	return h
