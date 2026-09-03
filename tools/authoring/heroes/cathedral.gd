extends RefCounted
## CATHEDRAL — Bulwark. Mother Seraphine, a wandering abbess in ceramic plate. ★ Stained-glass Wall:
## a barrier that also heals allies standing behind it. Mace primary (wide arc), Censer (short dash +
## AoE damage), ult Sanctuary: a dome that blocks damage and cleanses inside. Anchor tank; countered
## by dive-through and long fights.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"cathedral", "Cathedral", RF.Role.BULWARK, 400.0, 200.0)
	h.codename = "Mother Seraphine"
	h.sort_order = 2
	h.tagline = "Stand behind me and be whole."
	h.lore = "Seraphine took her vows in a chapel built inside the nave of a fallen relay station, where the stained glass was cut from the station's own solar panels. When the Charters began fighting over Cores she walked out of the chapel carrying its window on her back. She does not preach. She plants the glass, lifts the mace, and everyone behind her gets to keep breathing."
	h.playstyle = "Pick the spot the fight will happen and put the Wall there first; your team heals behind it while it soaks. Hold Guard while closing distance, then swing the mace in wide arcs to hit everyone at once. Censer punishes anyone who steps around the glass. Save Sanctuary to erase an enemy ultimate: it blocks, cleanses and makes everyone inside briefly untouchable."
	h.theme_color = Color(0.98, 0.84, 0.5)
	h.difficulty = 1
	h.unique_mechanic = "Stained-glass Wall: a 700 hp barrier that blocks enemy fire for 8 s AND heals every ally standing within 4 m behind it for 15 hp/s."
	h.counters = [&"vesper", &"coil", &"bombard", &"lumen"]
	h.countered_by = [&"harrier", &"sable", &"wisp", &"ricochet"]
	h.synergies = [&"vesper", &"suture", &"tallow", &"bombard"]
	# Body: ceramic plate. Tall, heavy, steady.
	h.movement = A.movement(5.1, 6.3, 52.0, 0.3)
	h.movement.footstep_interval = 0.48
	h.movement.capsule_height = 1.95
	h.movement.eye_height = 1.68
	h.movement.crouch_eye_height = 1.05
	h.movement.landing_recovery = 0.12
	h.hitbox.body_radius = 0.45
	h.hitbox.head_radius = 0.22
	h.hitbox.head_height = 1.72
	h.hitbox.head_crouch_height = 1.1
	h.hitbox.body_top = 1.42
	h.hitbox.body_crouch_top = 0.9
	h.visual.build = HeroVisualData.Build.HEAVY
	h.visual.height = 1.95
	h.visual.shoulder_width = 0.6
	h.visual.head = HeroVisualData.HeadShape.CROWN
	h.visual.extras = [HeroVisualData.Extra.BANNER, HeroVisualData.Extra.CLOAK]
	h.visual.primary_color = Color(0.92, 0.9, 0.84)
	h.visual.secondary_color = Color(0.36, 0.22, 0.4)
	h.visual.accent_color = Color(0.85, 0.66, 0.28)
	h.visual.emissive_color = Color(1.0, 0.85, 0.45)
	h.visual.emissive_strength = 1.8
	h.visual.metallic = 0.15
	h.visual.roughness = 0.4
	h.visual.skin_color = Color(0.6, 0.42, 0.32)
	h.visual.weapon_style = &"shield_mace"
	h.visual.weapon_scale = 1.3
	h.visual.arms_color = Color(0.9, 0.88, 0.82)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Bright ceramic plate under a dark purple cloak, a five-point crown, a banner rising over one shoulder and a heavy mace. The only bulwark whose silhouette is pale."
	h.audio.footstep_set = &"boots_heavy"
	h.audio.ult_stinger = &"ult_cathedral"
	h.audio.ult_stinger_enemy = &"ult_cathedral_enemy"
	h.audio.voice_pitch = 1.0
	h.audio.callout_tone = &"radio_c"
	h.hero_script = load("res://src/heroes/behaviors/CathedralBehavior.gd")
	# AI
	h.ai.preferred_range = 2.4; h.ai.min_range = 0.0; h.ai.max_effective_range = 9.0
	h.ai.aggression = 0.55; h.ai.self_preservation = 0.5; h.ai.prefers_high_ground = 0.2; h.ai.sticks_to_tank = 0.0
	h.ai.melee_brawler = true; h.ai.builds = true
	h.ai.ult_style = &"counter"; h.ai.ult_min_targets = 1; h.ai.strafe_style = &"weave"
	# --- Primary: Reliquary Mace (wide melee arc)
	var prim := A.weapon(&"cathedral_mace", "Reliquary Mace", "A slow, wide swing: 58 damage to up to three enemies in a 90 degree arc within 3 m, and they are slowed to 80% for a second.", 1.1, 0, 0.0)
	var mace := MeleeEffect.new()
	mace.damage = 58.0
	mace.range = 3.0
	mace.arc_deg = 90.0
	mace.knockback = 3.0
	mace.max_targets = 3
	mace.delay = 0.12
	var weight := A.status(&"cathedral_weight", "Weight of Glass", 1.0)
	weight.speed_mult = 0.8
	weight.is_debuff = true
	weight.is_crowd_control = true
	weight.cleansable = true
	weight.color = Color(0.9, 0.8, 0.5)
	weight.tags = [&"slow"]
	mace.hit_status = weight
	prim.effects = [mace]
	prim.presentation.sound_fire = &"cathedral_mace_fire"
	prim.presentation.sound_tail = &"cathedral_mace_tail"
	prim.presentation.sound_impact = &"cathedral_mace_impact"
	prim.presentation.impact_vfx = &"cathedral_mace_impact"
	prim.presentation.tracer_style = &""
	prim.presentation.tracer_color = Color(1.0, 0.9, 0.6)
	prim.presentation.anim_tag = &"melee"
	prim.presentation.crosshair = &"bracket"
	A.feel(prim, 1.2, 0.4, 0.12, 6.0, 0.12, 8.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 3.4, 2.2)
	h.primary = prim
	# --- Secondary: Guard (hold: raise the shield)
	var guard := A.ability(&"cathedral_guard", "Guard", "Hold to raise the shield: you take 40% less damage from all sides but move at 70% speed and cannot swing. Hold it while closing the distance; drop it to strike.", AbilityData.Trigger.CHANNEL, 0.0)
	guard.is_weapon = true
	guard.usable_while_silenced = true
	guard.blocks_primary_while_active = true
	guard.cancel_on_cc = true
	var guarding := A.status(&"cathedral_guard", "Guard", 0.0)   # duration 0: lives until the channel ends
	guarding.damage_taken_mult = 0.6
	guarding.speed_mult = 0.7
	guarding.cleansable = false
	guarding.color = Color(0.95, 0.9, 0.7)
	guard.self_status_while_active = guarding
	guard.presentation.sound_cast = &"cathedral_guard_cast"
	guard.presentation.sound_loop = &"cathedral_guard_loop"
	guard.presentation.sound_end = &"cathedral_guard_end"
	guard.presentation.self_glow = Color(0.95, 0.9, 0.7, 1.0)
	guard.presentation.anim_tag = &"cast"
	guard.presentation.crosshair = &"bracket"
	A.ai(guard, AbilityAIHints.Intent.DEFENSIVE, 3.5, 30.0, 14.0, 0.4)
	guard.ai.spam_ok = true
	guard.ai.use_when_health_below = 0.9
	h.secondary = guard
	# --- Ability 1: Stained-glass Wall (★ signature)
	var wall := A.ability(&"cathedral_wall", "Stained-glass Wall", "Plant a 6 m wide, 3.2 m tall window 3 m in front of you for 8 s (700 hp). Enemy shots break on the glass; every ally standing within 4 m behind it heals 15 hp per second.", AbilityData.Trigger.PRESS, 12.0)
	wall.recovery = 0.2
	var dep := DeployEffect.new()
	dep.kind = &"cathedral_wall"
	dep.visual_id = &"cathedral_wall"
	dep.placement = DeployEffect.Placement.IN_FRONT
	dep.distance = 3.0
	dep.health = 700.0
	dep.lifetime = 8.0
	dep.max_instances = 1
	dep.deployable_script = load("res://src/heroes/deployables/CathedralWall.gd")
	dep.params = {"width": 6.0, "height": 3.2, "heal_radius": 4.0, "heal_per_second": 15.0}
	wall.effects = [dep]
	wall.presentation.sound_cast = &"cathedral_wall_cast"
	wall.presentation.sound_fire = &"cathedral_wall_fire"
	wall.presentation.sound_end = &"cathedral_wall_end"
	wall.presentation.cast_vfx = &"cast_generic"
	wall.presentation.muzzle_vfx = &"deploy_place"
	wall.presentation.anim_tag = &"cast"
	A.feel(wall, 0.0, 0.0, 0.08, 3.0, 0.1)
	A.ai(wall, AbilityAIHints.Intent.DEFENSIVE, 0.0, 22.0, 6.0, 0.75)
	wall.ai.use_when_health_below = 0.8
	wall.ai.needs_enemies_in_radius = 1
	wall.ai.counter_tags = [&"hitscan", &"poke"]
	wall.ai.combo_tags = [&"barrier"]
	h.ability_1 = wall
	# --- Ability 2: Censer (short dash + AoE damage)
	var censer := A.ability(&"cathedral_censer", "Censer", "Swing the censer and lunge forward; 0.4 s later burning incense bursts around you: 70 damage within 4 m, enemies knocked back and set burning for 10 damage per second over 2 s.", AbilityData.Trigger.PRESS, 9.0)
	censer.recovery = 0.3
	censer.requires_ground = false
	var dash := DashEffect.new()
	dash.direction = DashEffect.Dir.AIM_FLAT
	dash.speed = 15.0
	dash.vertical_boost = 2.5
	dash.preserve_momentum = 0.2
	var incense := A.status(&"cathedral_incense", "Incense", 2.0)
	incense.dot_dps = 10.0
	incense.is_debuff = true
	incense.cleansable = true
	incense.color = Color(1.0, 0.7, 0.35)
	incense.tags = [&"dot", &"burn"]
	var puff := AreaEffect.new()
	puff.delay = 0.4
	puff.radius = 4.0
	puff.damage = 70.0
	puff.min_fraction = 0.6
	puff.knockback = 4.0
	puff.enemy_status = incense
	puff.vfx_id = &"cathedral_censer_explosion"
	censer.effects = [dash, puff]
	censer.presentation.sound_cast = &"cathedral_censer_cast"
	censer.presentation.sound_fire = &"cathedral_censer_fire"
	censer.presentation.sound_impact = &"cathedral_censer_impact"
	censer.presentation.cast_vfx = &"cathedral_censer"
	censer.presentation.impact_vfx = &"explosion"
	censer.presentation.anim_tag = &"cast"
	A.feel(censer, 1.5, 0.3, 0.1, 4.0, 0.16)
	A.ai(censer, AbilityAIHints.Intent.ENGAGE, 2.0, 9.0, 5.0, 0.6)
	censer.ai.combo_tags = [&"dot"]
	h.ability_2 = censer
	# --- Ultimate: Sanctuary (dome that blocks + cleanses + brief invulnerability)
	var ult := A.ultimate(&"cathedral_sanctuary", "Sanctuary", "Raise a 6 m dome around you for 6 s (1500 hp) that blocks all enemy fire from outside. On cast every ally inside is cleansed, healed for 60 and made invulnerable for 0.5 s: the answer to an enemy ultimate.", 1900.0)
	ult.recovery = 0.4
	var dome := DeployEffect.new()
	dome.kind = &"barrier_dome"
	dome.visual_id = &"cathedral_sanctuary"
	dome.placement = DeployEffect.Placement.AT_FEET
	dome.health = 1500.0
	dome.lifetime = 6.0
	dome.max_instances = 1
	dome.deployable_script = load("res://src/heroes/deployables/BarrierDome.gd")
	dome.params = {"radius": 6.0}
	var cleanse := CleanseEffect.new()
	cleanse.who = CleanseEffect.Who.ALLIES_IN_RADIUS
	cleanse.radius = 6.0
	cleanse.include_self = true
	var sanctified := A.status(&"cathedral_sanctified", "Sanctified", 0.5)
	sanctified.invulnerable = true
	sanctified.cleansable = false
	sanctified.color = Color(1.0, 0.95, 0.7)
	var bless := ApplyStatusEffect.new()
	bless.status = sanctified
	bless.who = ApplyStatusEffect.Who.ALLIES_IN_RADIUS_INCLUDING_SELF
	bless.radius = 6.0
	bless.requires_los = false
	var mend := HealEffect.new()
	mend.who = HealEffect.Who.ALLIES_IN_RADIUS
	mend.radius = 6.0
	mend.include_self = true
	mend.amount = 60.0
	ult.effects = [dome, cleanse, bless, mend]
	ult.presentation.sound_cast = &"cathedral_sanctuary_cast"
	ult.presentation.sound_loop = &"cathedral_sanctuary_loop"
	ult.presentation.sound_end = &"cathedral_sanctuary_end"
	ult.presentation.cast_vfx = &"cathedral_sanctuary"
	ult.presentation.voice_line = &"cathedral_ult_line"
	ult.presentation.voice_line_enemy = &"cathedral_ult_line_enemy"
	ult.presentation.self_glow = Color(1.0, 0.9, 0.6, 1.0)
	A.feel(ult, 0.0, 0.0, 0.1, 4.0, 0.25)
	A.ai(ult, AbilityAIHints.Intent.DEFENSIVE, 0.0, 12.0, 4.0, 0.8)
	ult.ai.needs_allies_in_radius = 1
	ult.ai.use_when_health_below = 0.5
	ult.ai.counter_tags = [&"cleanse", &"barrier", &"engage"]
	h.ultimate = ult
	return h
