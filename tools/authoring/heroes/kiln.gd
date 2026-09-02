extends RefCounted
## KILN — Bulwark. A furnace-golem industrial worker. Hero resource ★ Heat, built by taking and
## dealing damage; spent on Vent (an updraft that launches allies to high ground) and Slag Cast (a
## temporary wall you can stand on). Primary: molten slugs. Ult Meltdown: burning ground and massive
## overhealth. Brawler that builds terrain.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"kiln", "Kiln", RF.Role.BULWARK, 425.0, 175.0)
	h.codename = "Unit K-17"
	h.sort_order = 3
	h.tagline = "Every fight is a foundry."
	h.lore = "K-17 was a foundry golem in the Ruhr Charter's salvage smelters, poured to pull white-hot reactor plate out of the melt by hand. When the smelters shut down the crew could not bring themselves to scrap it, so they taught it to walk the drop sites instead. Kiln does not know it is not a person. Nobody on its team has ever wanted to correct it. It builds cover the way other people breathe: because there is heat inside and it has to go somewhere."
	h.playstyle = "Trade damage to build Heat, then spend it on terrain: Slag Cast a wall you and your team can stand on, Vent an ally onto a ledge nobody expected them to reach. Fight close so the slugs and the Furnace Blast connect; the burn does the rest. Meltdown when you are surrounded: 300 overhealth, unstoppable, and everything near you burns."
	h.theme_color = Color(1.0, 0.5, 0.15)
	h.difficulty = 2
	h.unique_mechanic = "Heat: a 0-100 resource built by dealing (0.3/pt) and taking (0.15/pt) damage that decays 4/s. Vent costs 30 heat, Slag Cast costs 40. Meltdown refills it."
	h.counters = [&"ballast", &"sable", &"bramble", &"tallow"]
	h.countered_by = [&"suture", &"vesper", &"bombard", &"harrier"]
	h.synergies = [&"harrier", &"vesper", &"cadence", &"cairn"]
	h.hero_script = load("res://src/heroes/behaviors/KilnBehavior.gd")
	h.hero_resource_name = "Heat"
	h.hero_resource_max = 100.0
	h.hero_resource_regen = -4.0
	# Body: massive furnace golem.
	h.movement = A.movement(5.0, 6.0, 48.0, 0.28)
	h.movement.footstep_interval = 0.55
	h.movement.capsule_height = 2.1
	h.movement.crouch_height = 1.4
	h.movement.eye_height = 1.8
	h.movement.crouch_eye_height = 1.15
	h.movement.landing_recovery = 0.2
	h.movement.backpedal_mult = 0.85
	h.hitbox.body_radius = 0.48
	h.hitbox.head_radius = 0.22
	h.hitbox.head_height = 1.88
	h.hitbox.head_crouch_height = 1.2
	h.hitbox.body_top = 1.55
	h.hitbox.body_crouch_top = 0.95
	h.visual.build = HeroVisualData.Build.MASSIVE
	h.visual.height = 2.15
	h.visual.shoulder_width = 0.68
	h.visual.head = HeroVisualData.HeadShape.LANTERN
	h.visual.extras = [HeroVisualData.Extra.TANK_CANISTERS]
	h.visual.primary_color = Color(0.3, 0.24, 0.2)
	h.visual.secondary_color = Color(0.16, 0.12, 0.1)
	h.visual.accent_color = Color(0.72, 0.45, 0.22)
	h.visual.emissive_color = Color(1.0, 0.45, 0.1)
	h.visual.emissive_strength = 3.2
	h.visual.metallic = 0.5
	h.visual.roughness = 0.7
	h.visual.weapon_style = &"cannon"
	h.visual.weapon_scale = 1.35
	h.visual.arms_color = Color(0.28, 0.22, 0.18)
	h.visual.stance = &"hunched"
	h.visual.silhouette_notes = "The biggest thing on the field: a hunched iron body with a furnace-door lantern for a head that glows orange, two heat canisters on the back and a stubby cannon. Blocks a doorway by standing in it."
	h.audio.footstep_set = &"boots_heavy"
	h.audio.ult_stinger = &"ult_kiln"
	h.audio.ult_stinger_enemy = &"ult_kiln_enemy"
	h.audio.voice_pitch = 0.7
	h.audio.callout_tone = &"radio_b"
	# AI
	h.ai.preferred_range = 9.0; h.ai.min_range = 0.0; h.ai.max_effective_range = 24.0
	h.ai.aggression = 0.65; h.ai.self_preservation = 0.4; h.ai.prefers_high_ground = 0.3; h.ai.sticks_to_tank = 0.0
	h.ai.builds = true
	h.ai.ult_style = &"engage"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.1
	# --- Primary: Slug Thrower (molten projectiles that burn)
	var prim := A.weapon(&"kiln_slug", "Slug Thrower", "Lobs molten slugs at 55 m/s: 65 damage on hit and the target burns for 10 damage per second over 2 s. Slight drop past 20 m.", 1.8, 8, 1.7)
	var slug := A.projectile(65.0, 55.0)
	slug.gravity = 3.0
	slug.radius = 0.14
	slug.lifetime = 2.5
	slug.visual_id = &"plasma"
	var burn := A.status(&"kiln_burn", "Burning", 2.0)
	burn.dot_dps = 10.0
	burn.is_debuff = true
	burn.cleansable = true
	burn.color = Color(1.0, 0.5, 0.15)
	burn.tags = [&"dot", &"burn"]
	slug.hit_status = burn
	prim.effects = [slug]
	A.pres(prim, &"kiln_slug_fire", &"kiln_slug_tail", &"", Color(1.0, 0.6, 0.2))
	prim.presentation.muzzle_vfx = &"kiln_slug_muzzle"
	prim.presentation.impact_vfx = &"kiln_slug_impact"
	prim.presentation.sound_impact = &"kiln_slug_impact"
	prim.presentation.projectile_vfx = &"plasma"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.crosshair = &"circle"
	A.feel(prim, 2.4, 0.5, 0.14, 5.5, 0.1, 10.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 28.0, 10.0)
	prim.ai.needs_line_of_sight = true
	h.primary = prim
	# --- Secondary: Furnace Blast (short flame cone)
	var sec := A.ability(&"kiln_blast", "Furnace Blast", "Open the furnace door: a 30 degree cone of flame to 8 m, 9 gouts of 10 damage that set enemies burning. Brutal inside 5 m, a warm breeze past 9.", AbilityData.Trigger.PRESS, 4.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	sec.recovery = 0.35
	var flame := A.hitscan(10.0, 9.0)
	flame.pellets = 9
	flame.spread_deg = 30.0
	flame.falloff_start = 4.5
	flame.falloff_end = 9.0
	flame.falloff_min = 0.35
	flame.headshot = false
	flame.knockback = 2.5
	flame.hit_status = burn
	sec.effects = [flame]
	A.pres(sec, &"kiln_blast_fire", &"kiln_blast_tail", &"beam", Color(1.0, 0.55, 0.15))
	sec.presentation.tracer_width = 0.08
	sec.presentation.muzzle_vfx = &"kiln_blast_muzzle"
	sec.presentation.impact_vfx = &"kiln_slug_impact"
	sec.presentation.impact_decal = &"scorch"
	sec.presentation.sound_impact = &"kiln_blast_impact"
	sec.presentation.crosshair = &"circle"
	A.feel(sec, 1.4, 0.6, 0.18, 4.0, 0.16)
	A.ai(sec, AbilityAIHints.Intent.DAMAGE, 0.0, 8.0, 4.0, 0.65)
	sec.ai.combo_tags = [&"dot"]
	h.secondary = sec
	# --- Ability 1: Vent (heat-powered updraft pad)
	var vent := A.ability(&"kiln_vent", "Vent", "Costs 30 Heat. Blow a vent grate into the ground where you aim (within 10 m) for 5 s: any ally (you included) who steps on it is launched about 4 m straight up. Reaches ledges, slabs and rooftops.", AbilityData.Trigger.PRESS, 8.0)
	vent.resource = AbilityData.Cost.HERO_RESOURCE
	vent.hero_resource_cost = 30.0
	vent.recovery = 0.2
	var vdep := DeployEffect.new()
	vdep.kind = &"vent"
	vdep.visual_id = &"kiln_vent"
	vdep.placement = DeployEffect.Placement.AIMED_GROUND
	vdep.max_range = 10.0
	vdep.health = 0.0
	vdep.lifetime = 5.0
	vdep.max_instances = 1
	vdep.deployable_script = load("res://src/heroes/deployables/KilnVent.gd")
	vdep.params = {"radius": 1.6, "launch": 13.5}
	vent.effects = [vdep]
	vent.presentation.sound_cast = &"kiln_vent_cast"
	vent.presentation.sound_fire = &"kiln_vent_fire"
	vent.presentation.sound_end = &"kiln_vent_end"
	vent.presentation.cast_vfx = &"cast_generic"
	vent.presentation.muzzle_vfx = &"deploy_place"
	vent.presentation.anim_tag = &"cast"
	A.feel(vent, 0.0, 0.0, 0.06, 2.0, 0.06)
	A.ai(vent, AbilityAIHints.Intent.UTILITY, 0.0, 10.0, 3.0, 0.5)
	vent.ai.target_ground = true
	vent.ai.needs_line_of_sight = false
	vent.ai.combo_tags = [&"mobility", &"high_ground"]
	h.ability_1 = vent
	# --- Ability 2: Slag Cast (standable wall)
	var slag := A.ability(&"kiln_slag", "Slag Cast", "Costs 40 Heat. Pour a 4.2 m wide, 1.5 m tall slag wall 3 m in front of you for 6 s (600 hp). It blocks shots and movement for both teams, and the step on your side lets you climb on top of it.", AbilityData.Trigger.PRESS, 10.0)
	slag.resource = AbilityData.Cost.HERO_RESOURCE
	slag.hero_resource_cost = 40.0
	slag.recovery = 0.25
	var sdep := DeployEffect.new()
	sdep.kind = &"slag"
	sdep.visual_id = &"kiln_slag"
	sdep.placement = DeployEffect.Placement.IN_FRONT
	sdep.distance = 3.0
	sdep.health = 600.0
	sdep.lifetime = 6.0
	sdep.max_instances = 1
	sdep.deployable_script = load("res://src/heroes/deployables/KilnSlag.gd")
	sdep.params = {"width": 4.2, "height": 1.5}
	slag.effects = [sdep]
	slag.presentation.sound_cast = &"kiln_slag_cast"
	slag.presentation.sound_fire = &"kiln_slag_fire"
	slag.presentation.sound_end = &"kiln_slag_end"
	slag.presentation.cast_vfx = &"cast_generic"
	slag.presentation.muzzle_vfx = &"smoke_puff"
	slag.presentation.anim_tag = &"cast"
	A.feel(slag, 0.0, 0.0, 0.08, 3.0, 0.12)
	A.ai(slag, AbilityAIHints.Intent.DEFENSIVE, 0.0, 16.0, 4.0, 0.7)
	slag.ai.use_when_health_below = 0.7
	slag.ai.counter_tags = [&"hitscan", &"poke"]
	slag.ai.combo_tags = [&"barrier", &"high_ground"]
	h.ability_2 = slag
	# --- Ultimate: Meltdown (8 s: unstoppable, +300 overhealth, burning ground)
	var ult := A.ultimate(&"kiln_meltdown", "Meltdown", "For 8 s the furnace runs open: +300 overhealth, unstoppable, 10% faster, Heat refilled, and the ground within 4.5 m of you burns for 40 damage per second and sets enemies alight. Casting it scorches everything within 5 m for 50.", 1750.0)
	ult.active_duration = 8.0
	ult.tick_interval = 0.25
	ult.cancel_on_cc = false
	ult.recovery = 0.3
	var melt := A.status(&"kiln_meltdown", "Meltdown", 8.0)
	melt.unstoppable = true
	melt.overhealth_on_apply = 300.0
	melt.overhealth_max = 300.0
	melt.speed_mult = 1.1
	melt.cleansable = false
	melt.color = Color(1.0, 0.45, 0.1)
	ult.self_status_while_active = melt
	var refill := ResourceEffect.new()
	refill.hero_resource_delta = 100.0
	var ignite := AreaEffect.new()
	ignite.radius = 5.0
	ignite.damage = 50.0
	ignite.min_fraction = 0.6
	ignite.knockback = 5.0
	ignite.enemy_status = burn
	ignite.vfx_id = &"kiln_meltdown_explosion"
	ult.effects = [refill, ignite]
	var ground := AreaEffect.new()
	ground.radius = 4.5
	ground.damage = 10.0
	ground.min_fraction = 0.6
	ground.requires_los = true
	ground.enemy_status = burn
	ground.vfx_id = &"kiln_meltdown_ground"
	ult.tick_effects = [ground]
	ult.presentation.sound_cast = &"kiln_meltdown_cast"
	ult.presentation.sound_loop = &"kiln_meltdown_loop"
	ult.presentation.sound_end = &"kiln_meltdown_end"
	ult.presentation.cast_vfx = &"kiln_meltdown"
	ult.presentation.loop_vfx = &"kiln_meltdown_loop"
	ult.presentation.end_vfx = &"smoke_puff"
	ult.presentation.area_vfx = &"kiln_meltdown_ground"
	ult.presentation.voice_line = &"kiln_ult_line"
	ult.presentation.voice_line_enemy = &"kiln_ult_line_enemy"
	ult.presentation.self_glow = Color(1.0, 0.45, 0.1, 1.0)
	A.feel(ult, 0.0, 0.0, 0.12, 4.0, 0.35)
	A.ai(ult, AbilityAIHints.Intent.ENGAGE, 0.0, 12.0, 5.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.counter_tags = [&"displace", &"root"]
	ult.ai.combo_tags = [&"engage"]
	h.ultimate = ult
	return h
