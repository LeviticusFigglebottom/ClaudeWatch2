extends RefCounted
## SUTURE — Conduit. Field medic with a stapler-gun. ★ Tether links two allies for 6 s: healing on one
## is copied to the other. Bandage Volley (healing shells with small damage), Adrenaline (+25% fire rate
## and speed), ult Triage (everyone within 10 m healed to full and cleansed). Burst healer; countered by
## tether-breaking displacement.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"suture", "Suture", RF.Role.CONDUIT, 225.0)
	h.codename = "The Medic"
	h.sort_order = 23
	h.tagline = "Hold still. This part hurts."
	h.lore = "Suture ran a rooftop clinic in the Nightmarket towers where the only anaesthetic was speed. Her stapler-gun closes a wound in one shot and her bandage shells were made for patching people who will not stop moving. She took the runner contract because the Charters pay in medical stock, and because somebody on every drop is going to need her."
	h.playstyle = "Tether the bulwark and the striker who is taking the most fire, then every bandage you land on one of them heals both. Bandage Volley is your main heal: shoot it AT the ally, the shells burst on contact. Staple enemies to keep the pressure up, staple allies in a pinch. Adrenaline on your best duelist; Triage when the fight turns."
	h.theme_color = Color(0.55, 0.92, 0.75)
	h.difficulty = 2
	h.unique_mechanic = "Tether: links the two most recently tethered allies (or one ally and Suture) for 6 s. Every point of healing Suture puts into one end of the tether is copied to the other end."
	h.counters = [&"bramble", &"kiln", &"coil"]
	h.countered_by = [&"wisp", &"ballast", &"rook"]
	h.synergies = [&"ballast", &"cathedral", &"kiln"]
	h.hero_script = load("res://src/heroes/behaviors/SutureBehavior.gd")
	# Body
	h.movement = A.movement(5.5, 6.4)
	h.movement.footstep_interval = 0.42
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.8
	h.visual.head = HeroVisualData.HeadShape.HELMET_ROUND
	h.visual.extras = [HeroVisualData.Extra.BACKPACK]
	h.visual.primary_color = Color(0.88, 0.86, 0.8)
	h.visual.secondary_color = Color(0.32, 0.36, 0.4)
	h.visual.accent_color = Color(0.9, 0.28, 0.32)
	h.visual.emissive_color = Color(0.5, 1.0, 0.8)
	h.visual.emissive_strength = 1.8
	h.visual.metallic = 0.3
	h.visual.roughness = 0.6
	h.visual.weapon_style = &"launcher"
	h.visual.weapon_scale = 1.0
	h.visual.arms_color = Color(0.3, 0.33, 0.36)
	h.visual.stance = &"brace"
	h.visual.silhouette_notes = "Medium build in an off-white coat with a red cross accent, round helmet with a mint visor, a boxy medkit backpack and a drum-fed launcher. Reads as 'medic' at a glance."
	h.audio.footstep_set = &"boots_medium"
	h.audio.ult_stinger = &"ult_suture"
	h.audio.ult_stinger_enemy = &"ult_suture_enemy"
	h.audio.callout_tone = &"radio_a"
	# AI
	h.ai.preferred_range = 10.0; h.ai.min_range = 2.0; h.ai.max_effective_range = 30.0
	h.ai.aggression = 0.3; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 0.4
	h.ai.sticks_to_tank = 0.7; h.ai.heals = true; h.ai.heal_range = 20.0
	h.ai.ult_style = &"save"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	# --- Primary: Stapler (rapid hitscan; staples into allies close wounds)
	var prim := A.weapon(&"suture_stapler", "Stapler", "Rapid hitscan stapler: 12 damage, 9 shots/s, 30 staples. Staples fired into an ally close wounds for 6 each.", 9.0, 30, 1.3)
	var hs := A.hitscan(12.0, 60.0)
	hs.spread_deg = 1.4; hs.spread_moving_deg = 1.2; hs.spread_airborne_deg = 2.5
	hs.bloom_per_shot_deg = 0.15; hs.bloom_max_deg = 1.5; hs.bloom_recovery_per_sec = 8.0
	hs.falloff_start = 18.0; hs.falloff_end = 35.0; hs.falloff_min = 0.5
	hs.headshot = true
	hs.hit_allies = true; hs.ally_heal = 6.0
	prim.effects = [hs]
	A.pres(prim, &"suture_stapler_fire", &"suture_stapler_tail", &"bullet", Color(0.75, 1.0, 0.9))
	prim.presentation.tracer_width = 0.02
	prim.presentation.muzzle_vfx = &"muzzle_generic"
	prim.presentation.impact_vfx = &"suture_staple_impact"
	prim.presentation.crosshair = &"cross"
	A.feel(prim, 0.35, 0.2, 0.03, 1.5, 0.015, 16.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 30.0, 12.0)
	h.primary = prim
	# --- Secondary: Bandage Volley (healing shells that burst on allies, enemies or surfaces)
	var volley := A.ability(&"suture_volley", "Bandage Volley", "Fire three bandage shells (6 degree spread, 21 m). Each shell bursts on the first ally, enemy or surface it meets: allies within 3 m are healed for 45, an enemy hit directly takes 15. Shoot the floor at your feet to patch yourself for half.", AbilityData.Trigger.PRESS, 2.5)
	volley.is_weapon = true
	volley.usable_while_silenced = true
	var shells := HealingShellEffect.new()
	shells.count = 3; shells.spread_deg = 6.0; shells.speed = 35.0
	shells.damage = 15.0; shells.radius = 0.15; shells.lifetime = 0.6
	shells.heal = 45.0; shells.heal_radius = 3.0
	shells.heal_self = true; shells.heal_self_fraction = 0.5
	shells.visual_id = &"flare"
	shells.burst_vfx = &"suture_bandage_burst"
	volley.effects = [shells]
	A.pres(volley, &"suture_volley_fire", &"suture_volley_tail", &"", Color(0.6, 1.0, 0.85))
	volley.presentation.muzzle_vfx = &"suture_volley_muzzle"
	volley.presentation.impact_vfx = &"suture_bandage_burst"
	volley.presentation.impact_decal = &""
	volley.presentation.projectile_vfx = &"flare"
	volley.presentation.crosshair = &"circle"
	volley.presentation.anim_tag = &"fire"
	A.feel(volley, 0.8, 0.3, 0.08, 3.0, 0.03)
	A.ai(volley, AbilityAIHints.Intent.HEAL, 0.0, 20.0, 8.0, 0.75)
	volley.ai.target_ally = true
	volley.ai.spam_ok = true
	h.secondary = volley
	# --- Ability 1: Tether (link two allies; healing on one is copied to the other)
	var tether := A.ability(&"suture_tether", "Tether", "Link the aimed ally for 6 s and heal them for 30. The two most recently tethered allies (or one ally and Suture) share every point of healing Suture puts into either of them.", AbilityData.Trigger.PRESS, 10.0)
	tether.behavior = load("res://src/heroes/abilities/SutureTetherBehavior.gd")
	var ts := A.status(&"suture_tether", "Tethered", 6.0)
	ts.cleansable = false
	ts.color = Color(0.6, 1.0, 0.85)
	var ts_apply := ApplyStatusEffect.new()
	ts_apply.who = ApplyStatusEffect.Who.TARGET
	ts_apply.status = ts
	var tether_heal := HealEffect.new()
	tether_heal.who = HealEffect.Who.TARGET
	tether_heal.amount = 30.0
	tether.effects = [ts_apply, tether_heal]
	tether.presentation.sound_fire = &"suture_tether_fire"
	tether.presentation.cast_vfx = &"suture_tether_cast"
	tether.presentation.anim_tag = &"cast"
	tether.presentation.crosshair = &"bracket"
	A.ai(tether, AbilityAIHints.Intent.BUFF_ALLIES, 0.0, 25.0, 10.0, 0.65)
	tether.ai.target_ally = true
	tether.ai.needs_allies_in_radius = 1
	tether.ai.combo_tags = [&"tether"]
	h.ability_1 = tether
	# --- Ability 2: Adrenaline (+25% fire rate and move speed on an ally)
	var adr := A.ability(&"suture_adrenaline", "Adrenaline", "Inject the aimed ally: +25% fire rate and +25% move speed for 4 s.", AbilityData.Trigger.PRESS, 12.0)
	adr.behavior = load("res://src/heroes/abilities/SutureAimedAllyGate.gd")
	var adr_status := A.status(&"suture_adrenaline", "Adrenaline", 4.0)
	adr_status.speed_mult = 1.25
	adr_status.fire_rate_mult = 1.25
	adr_status.cleansable = false
	adr_status.color = Color(1.0, 0.6, 0.4)
	adr_status.sound_apply = &"suture_adrenaline_apply"
	var adr_apply := ApplyStatusEffect.new()
	adr_apply.who = ApplyStatusEffect.Who.TARGET
	adr_apply.status = adr_status
	adr.effects = [adr_apply]
	adr.presentation.sound_fire = &"suture_adrenaline_fire"
	adr.presentation.cast_vfx = &"suture_adrenaline_cast"
	adr.presentation.anim_tag = &"throw"
	adr.presentation.crosshair = &"bracket"
	A.ai(adr, AbilityAIHints.Intent.BUFF_ALLIES, 0.0, 25.0, 10.0, 0.55)
	adr.ai.target_ally = true
	adr.ai.needs_allies_in_radius = 1
	adr.ai.combo_tags = [&"speed", &"damage_buff"]
	h.ability_2 = adr
	# --- Ultimate: Triage (everyone within 10 m healed to full and cleansed)
	var ult := A.ultimate(&"suture_triage", "Triage", "Everyone within 10 m, Suture included, is cleansed and healed to full.", 1600.0)
	var cl := CleanseEffect.new()
	cl.who = CleanseEffect.Who.ALLIES_IN_RADIUS
	cl.radius = 10.0
	cl.include_self = true
	var full := HealEffect.new()
	full.who = HealEffect.Who.ALLIES_IN_RADIUS
	full.radius = 10.0
	full.include_self = true
	full.amount = 999.0
	var ring := AreaEffect.new()
	ring.radius = 10.0; ring.heal = 0.0; ring.damage = 0.0; ring.requires_los = false
	ring.vfx_id = &"suture_triage_ring"
	ult.effects = [cl, full, ring]
	ult.presentation.sound_cast = &"suture_triage_cast"
	ult.presentation.sound_fire = &"suture_triage_fire"
	ult.presentation.cast_vfx = &"suture_triage_cast"
	ult.presentation.voice_line = &"suture_ult_line"
	ult.presentation.voice_line_enemy = &"suture_ult_line_enemy"
	ult.presentation.camera_shake = 0.15
	ult.presentation.self_glow = Color(0.6, 1.0, 0.85, 1.0)
	A.ai(ult, AbilityAIHints.Intent.HEAL, 0.0, 10.0, 6.0, 0.75)
	ult.ai.target_ally = true
	ult.ai.needs_allies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"cleanse", &"full_heal"]
	ult.ai.counter_tags = [&"cleanse"]
	h.ultimate = ult
	return h
