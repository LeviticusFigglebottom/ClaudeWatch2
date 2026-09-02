extends RefCounted
## TALLOW — Conduit. A candle-maker who sells light. Signature: Wicks — up to three candles that
## heal allies within 6 m; enemies who walk into them are burned and snuff them. Positional healer;
## countered by dive onto candles.


static func _reg(status: StatusData) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = status
	e.enabled = false
	return e


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"tallow", "Tallow", RF.Role.CONDUIT, 200.0)
	h.codename = "The Chandler"
	h.sort_order = 30
	h.tagline = "Light is a thing you leave behind."
	h.lore = "Tallow ran the last candle works in the Adriatic Charter's drowned quarter, where the power failed more nights than not. Her candles burn on rendered kelp-fat and a pinch of reactor ash, and they burn hot enough to matter. She hires out because a Charter with a Core has no need for candles, and she would like that to be true everywhere."
	h.playstyle = "Place candles where your team will actually stand, not where they are now: a doorway, the cart, the high ground. Heal with the wax bolt between fights, burn divers with the flame bolt, and hold Snuff for the ally about to eat a stun. Vigil turns a lost fight into a stalemate for 5 s; use it when the enemy commits."
	h.theme_color = Color(1.0, 0.72, 0.38)
	h.difficulty = 2
	h.unique_mechanic = "Wicks: up to three candles (25 s) that heal allies within 6 m for 18 hp/s. An enemy who walks onto one is burned and, after a moment of contact, snuffs it."
	h.counters = [&"bramble", &"coil", &"kiln"]
	h.countered_by = [&"sable", &"harrier", &"wisp"]
	h.synergies = [&"sable", &"cathedral", &"ballast"]
	h.hero_script = load("res://src/heroes/behaviors/TallowBehavior.gd")
	# Body: medium, bare head, three lit candles on the shoulders, a lantern in hand.
	h.movement = A.movement(5.5, 6.4, 60.0, 0.35)
	h.movement.footstep_interval = 0.42
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.78
	h.visual.shoulder_width = 0.52
	h.visual.head = HeroVisualData.HeadShape.BARE
	h.visual.extras = [HeroVisualData.Extra.CANDLES]
	h.visual.primary_color = Color(0.9, 0.82, 0.68)
	h.visual.secondary_color = Color(0.45, 0.3, 0.22)
	h.visual.accent_color = Color(1.0, 0.6, 0.25)
	h.visual.emissive_color = Color(1.0, 0.72, 0.35)
	h.visual.emissive_strength = 2.6
	h.visual.metallic = 0.05
	h.visual.roughness = 0.8
	h.visual.skin_color = Color(0.78, 0.6, 0.48)
	h.visual.weapon_style = &"lantern"
	h.visual.weapon_scale = 1.1
	h.visual.arms_color = Color(0.85, 0.76, 0.62)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Pale wax-colored coat, bare head, three candle flames riding the shoulders, a boxy lantern in the off hand. Warm and lit from within at any distance."
	h.audio.footstep_set = &"boots_medium"
	h.audio.footstep_volume = 0.85
	h.audio.ult_stinger = &"ult_tallow"
	h.audio.ult_stinger_enemy = &"ult_tallow_enemy"
	# AI: builder-healer who sticks to the tank and saves the ult for a committed fight.
	h.ai.preferred_range = 12.0; h.ai.min_range = 3.0; h.ai.max_effective_range = 30.0
	h.ai.aggression = 0.25; h.ai.self_preservation = 0.75; h.ai.prefers_high_ground = 0.3
	h.ai.heals = true; h.ai.heal_range = 25.0; h.ai.builds = true; h.ai.sticks_to_tank = 0.85
	h.ai.ult_style = &"save"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.1
	# --- Primary: Flame Bolt (projectile, burn on hit)
	var prim := A.weapon(&"tallow_bolt", "Flame Bolt", "A bolt of candle-fire: 28 damage and a 10 per second burn for 2 s. 12 bolts, 1.4 s reload.", 3.0, 12, 1.4)
	var burn := A.status(&"tallow_burn", "Burning", 2.0)
	burn.dot_dps = 10.0; burn.is_debuff = true; burn.cleansable = true
	burn.color = Color(1.0, 0.5, 0.15)
	var bolt := A.projectile(28.0, 40.0)
	bolt.radius = 0.12; bolt.lifetime = 2.5; bolt.hit_status = burn; bolt.visual_id = &"flare"
	bolt.spawn_offset = Vector3(0.25, -0.15, -0.4)
	prim.effects = [bolt]
	A.pres(prim, &"tallow_bolt_fire", &"tallow_bolt_tail", &"bolt", Color(1.0, 0.62, 0.25))
	prim.presentation.tracer_width = 0.035
	prim.presentation.muzzle_vfx = &"tallow_flame_muzzle"
	prim.presentation.impact_vfx = &"tallow_flame_hit"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.sound_impact = &"tallow_bolt_impact"
	prim.presentation.projectile_vfx = &"flare"
	prim.presentation.crosshair = &"dot"
	A.feel(prim, 0.8, 0.2, 0.05, 2.0, 0.03, 14.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 30.0, 12.0)
	h.primary = prim
	# --- Secondary: Wax Bolt (heal projectile: heals the ally it touches, bursts on surfaces)
	var heal := A.weapon(&"tallow_wax", "Wax Bolt", "A warm wax bolt that heals the first ally it touches for 45 (or every ally within 2.5 m of where it lands). Enemies it hits take 12. No ammo.", 2.4, 0, 0.0)
	var wax := TallowHealBoltEffect.new()
	wax.damage = 12.0; wax.speed = 40.0; wax.radius = 0.28; wax.lifetime = 1.6
	wax.heal = 45.0; wax.burst_radius = 2.5; wax.visual_id = &"candle"
	wax.spawn_offset = Vector3(0.25, -0.15, -0.4)
	heal.effects = [wax]
	A.pres(heal, &"tallow_wax_fire", &"tallow_wax_tail", &"bolt", Color(1.0, 0.9, 0.6))
	heal.presentation.tracer_width = 0.04
	heal.presentation.muzzle_vfx = &"tallow_flame_muzzle"
	heal.presentation.impact_vfx = &"heal_burst"
	heal.presentation.impact_decal = &""
	heal.presentation.sound_impact = &"tallow_wax_impact"
	heal.presentation.projectile_vfx = &"candle"
	heal.presentation.crosshair = &"circle"
	A.feel(heal, 0.5, 0.15, 0.04, 1.5, 0.02, 14.0)
	A.ai(heal, AbilityAIHints.Intent.HEAL, 0.0, 30.0, 10.0, 0.6)
	heal.ai.target_ally = true
	h.secondary = heal
	# --- Ability 1: Wicks (three candles)
	var wicks := A.ability(&"tallow_wicks", "Wicks", "Place a candle (up to three, 25 s each). Allies within 6 m are healed 18 per second. An enemy who walks onto a candle is burned for 12 per second and snuffs it after a moment.", AbilityData.Trigger.PRESS, 6.0)
	wicks.charges = 3
	var candle_burn := A.status(&"tallow_candle_burn", "Scorched", 1.5)
	candle_burn.dot_dps = 12.0; candle_burn.is_debuff = true; candle_burn.cleansable = true
	candle_burn.color = Color(1.0, 0.55, 0.2)
	var candle := DeployEffect.new()
	candle.kind = &"wick"
	candle.visual_id = &"tallow_candle"
	candle.placement = DeployEffect.Placement.AIMED_GROUND
	candle.max_range = 12.0
	candle.health = 60.0
	candle.lifetime = 25.0
	candle.max_instances = 3
	candle.deployable_script = load("res://src/heroes/deployables/TallowCandle.gd")
	candle.params = {"radius": 6.0, "hps": 18.0, "burn_radius": 1.5, "burn": &"tallow_candle_burn", "snuff_time": 0.75, "interval": 0.25}
	wicks.effects = [candle, _reg(candle_burn)]
	wicks.presentation.sound_fire = &"tallow_wicks_fire"
	wicks.presentation.sound_loop = &"tallow_wicks_loop"
	wicks.presentation.sound_end = &"tallow_wicks_end"
	wicks.presentation.cast_vfx = &"tallow_flame_hit"
	wicks.presentation.area_vfx = &"tallow_candle_glow"
	wicks.presentation.anim_tag = &"throw"
	wicks.presentation.crosshair = &"circle"
	A.ai(wicks, AbilityAIHints.Intent.BUFF_ALLIES, 0.0, 12.0, 4.0, 0.7)
	wicks.ai.target_ground = true
	wicks.ai.needs_line_of_sight = false
	wicks.ai.needs_allies_in_radius = 1
	h.ability_1 = wicks
	# --- Ability 2: Snuff (cleanse + 1 s invulnerability on the aimed ally, or self)
	var snuff := A.ability(&"tallow_snuff", "Snuff", "Pinch out the ally under your crosshair (or yourself): cleansed of every debuff, healed 30, and invulnerable for 1 s.", AbilityData.Trigger.PRESS, 12.0)
	var pinched := A.status(&"tallow_snuffed", "Snuffed", 1.0)
	pinched.invulnerable = true; pinched.cleansable = false
	pinched.color = Color(1.0, 0.95, 0.8)
	pinched.sound_apply = &"tallow_snuff_apply"
	var pinch := TallowSnuffEffect.new()
	pinch.status = pinched
	pinch.heal = 30.0
	pinch.range = 25.0
	pinch.cone_deg = 14.0
	snuff.effects = [pinch]
	snuff.presentation.sound_fire = &"tallow_snuff_fire"
	snuff.presentation.sound_tail = &"tallow_snuff_tail"
	snuff.presentation.cast_vfx = &"smoke_puff"
	snuff.presentation.area_vfx = &"tallow_snuff"
	snuff.presentation.anim_tag = &"cast"
	snuff.presentation.crosshair = &"circle"
	A.ai(snuff, AbilityAIHints.Intent.HEAL, 0.0, 25.0, 10.0, 0.75)
	snuff.ai.target_ally = true
	snuff.ai.counter_tags = [&"cleanse", &"dot", &"root"]
	snuff.ai.use_when_health_below = 0.5
	h.ability_2 = snuff
	# --- Ultimate: Vigil (allies within 12 m cannot fall for 5 s)
	var ult := A.ultimate(&"tallow_vigil", "Vigil", "For 5 s every ally within 12 m keeps their light: 70% damage reduction, 30 healing per second, cleansed, and a Last Light that makes them briefly untouchable if they would fall. Tallow herself cannot drop below 1 hp.", 1900.0)
	ult.cast_time = 0.25
	ult.cancel_on_cc = false
	var vigil := A.status(&"tallow_vigil", "Vigil", 5.0)
	vigil.damage_taken_mult = 0.3; vigil.hot_hps = 30.0; vigil.cleansable = false
	vigil.color = Color(1.0, 0.85, 0.5)
	vigil.sound_apply = &"tallow_vigil_apply"
	var last_light := A.status(&"tallow_last_light", "Last Light", 1.0)
	last_light.invulnerable = true; last_light.cleansable = false
	last_light.stacking = StatusData.Stacking.IGNORE_IF_ACTIVE
	last_light.color = Color(1.0, 1.0, 0.9)
	last_light.sound_apply = &"tallow_last_light_apply"
	var grant := ApplyStatusEffect.new()
	grant.status = vigil
	grant.who = ApplyStatusEffect.Who.ALLIES_IN_RADIUS_INCLUDING_SELF
	grant.radius = 12.0
	grant.requires_los = false
	var cleanse := CleanseEffect.new()
	cleanse.who = CleanseEffect.Who.ALLIES_IN_RADIUS
	cleanse.radius = 12.0
	cleanse.include_self = true
	var ward := DeployEffect.new()
	ward.kind = &"vigil_ward"
	ward.visual_id = &"tallow_vigil_ward"
	ward.placement = DeployEffect.Placement.AT_FEET
	ward.lifetime = 5.0
	ward.health = 0.0
	ward.max_instances = 1
	ward.deployable_script = load("res://src/heroes/deployables/TallowVigilWard.gd")
	ward.params = {"radius": 12.0, "status": &"tallow_vigil", "trigger": &"tallow_last_light", "threshold": 30.0}
	var telegraph := AreaEffect.new()
	telegraph.radius = 12.0
	telegraph.requires_los = false
	telegraph.vfx_id = &"tallow_vigil_ring"
	ult.effects = [cleanse, grant, ward, telegraph, _reg(last_light)]
	ult.presentation.sound_cast = &"tallow_vigil_cast"
	ult.presentation.sound_fire = &"tallow_vigil_fire"
	ult.presentation.sound_end = &"tallow_vigil_end"
	ult.presentation.cast_vfx = &"tallow_vigil_cast"
	ult.presentation.area_vfx = &"tallow_vigil_ring"
	ult.presentation.voice_line = &"tallow_ult_line"
	ult.presentation.voice_line_enemy = &"tallow_ult_line_enemy"
	ult.presentation.camera_shake = 0.12
	ult.presentation.crosshair = &"circle"
	A.ai(ult, AbilityAIHints.Intent.DEFENSIVE, 0.0, 12.0, 6.0, 0.75)
	ult.ai.needs_allies_in_radius = 1
	ult.ai.needs_line_of_sight = false
	ult.ai.counter_tags = [&"aoe_damage", &"engage"]
	ult.ai.hold_for_combo = true
	h.ultimate = ult
	return h
