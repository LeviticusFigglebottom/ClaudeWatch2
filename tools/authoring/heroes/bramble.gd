extends RefCounted
## BRAMBLE — Striker. Ex-terraformer with a thorn bow. Signature: Roots — the third consecutive
## thorn hit on the same target roots it for 1.2 s (BrambleBehavior). Counters mobile heroes;
## countered by cleanse and range.


static func _reg(status: StatusData) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = status
	e.enabled = false
	return e


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"bramble", "Bramble", RF.Role.STRIKER, 200.0)
	h.codename = "The Terraformer"
	h.sort_order = 17
	h.tagline = "Stand still. It's easier."
	h.lore = "Bramble spent a decade seeding the Cascadian seed-vault campus with engineered thorn that could hold a hillside together after the fires. When the Charter that hired her tried to burn it back, the hillside held and the Charter did not. She carries the thorn in a bow now, and still talks about drainage."
	h.playstyle = "Poke at mid range and stack three thorns on one target to root it, then land the Snare or a Thicket to keep it there for your team. Overgrowth roots a whole fight and heals your side of it. You lose to cleanse and to anyone who out-ranges 30 m."
	h.theme_color = Color(0.46, 0.74, 0.28)
	h.difficulty = 2
	h.unique_mechanic = "Roots: the third consecutive thorn hit on the same target (within 2 s of the last) roots it for 1.2 s. Switching targets or pausing resets the count."
	h.counters = [&"harrier", &"sable", &"wisp", &"ballast"]
	h.countered_by = [&"tallow", &"suture", &"cathedral", &"vesper"]
	h.synergies = [&"coil", &"rook", &"bombard"]
	h.hero_script = load("res://src/heroes/behaviors/BrambleBehavior.gd")
	# Body: medium, thorn crown, vines trailing from the shoulders, a tall bow.
	h.movement = A.movement(5.7, 6.6, 62.0, 0.4)
	h.movement.footstep_interval = 0.4
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.84
	h.visual.shoulder_width = 0.54
	h.visual.head = HeroVisualData.HeadShape.CROWN
	h.visual.extras = [HeroVisualData.Extra.VINES]
	h.visual.primary_color = Color(0.24, 0.38, 0.2)
	h.visual.secondary_color = Color(0.32, 0.22, 0.14)
	h.visual.accent_color = Color(0.56, 0.82, 0.3)
	h.visual.emissive_color = Color(0.6, 1.0, 0.4)
	h.visual.emissive_strength = 1.4
	h.visual.metallic = 0.1
	h.visual.roughness = 0.85
	h.visual.skin_color = Color(0.62, 0.48, 0.36)
	h.visual.weapon_style = &"bow"
	h.visual.weapon_scale = 1.1
	h.visual.arms_color = Color(0.3, 0.24, 0.16)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Upright with a spiked crown and a tall bow; vines trail from the shoulders and hips. Reads as a ranger from far, a plant from close."
	h.audio.footstep_set = &"boots_medium"
	h.audio.footstep_volume = 0.9
	h.audio.ult_stinger = &"ult_bramble"
	h.audio.ult_stinger_enemy = &"ult_bramble_enemy"
	# AI: mid-range striker that holds with the team and zones with the ult.
	h.ai.preferred_range = 14.0; h.ai.min_range = 4.0; h.ai.max_effective_range = 32.0
	h.ai.aggression = 0.5; h.ai.self_preservation = 0.55; h.ai.prefers_high_ground = 0.5
	h.ai.sticks_to_tank = 0.5
	h.ai.ult_style = &"zone"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.15
	# Shared statuses
	var root := A.status(&"bramble_root", "Rooted", 1.2)
	root.rooted = true; root.is_crowd_control = true; root.is_debuff = true; root.cleansable = true
	root.color = Color(0.4, 0.8, 0.25)
	root.sound_apply = &"bramble_root_apply"
	# --- Primary: Thorn Bow (fast thorns, headshots, roots on the third consecutive hit)
	var prim := A.weapon(&"bramble_thorns", "Thorn Bow", "Rapid thorns: 22 damage, 5 per second, headshots deal double. Your third consecutive hit on the same target roots it for 1.2 s. 20 thorns, 1.5 s reload.", 5.0, 20, 1.5)
	var thorn := A.projectile(22.0, 60.0)
	thorn.gravity = 0.0; thorn.radius = 0.1; thorn.lifetime = 2.5
	thorn.headshot = true; thorn.visual_id = &"thorn"
	thorn.spawn_offset = Vector3(0.2, -0.12, -0.35)
	prim.effects = [thorn, _reg(root)]
	A.pres(prim, &"bramble_thorns_fire", &"bramble_thorns_tail", &"bolt", Color(0.6, 1.0, 0.4))
	prim.presentation.tracer_width = 0.025
	prim.presentation.muzzle_vfx = &"muzzle_generic"
	prim.presentation.impact_vfx = &"impact_generic"
	prim.presentation.sound_impact = &"bramble_thorns_impact"
	prim.presentation.projectile_vfx = &"thorn"
	prim.presentation.crosshair = &"dot"
	A.feel(prim, 0.9, 0.2, 0.05, 2.5, 0.03, 14.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 40.0, 14.0)
	h.primary = prim
	# --- Secondary: Thorn Fan (close-range spread; each thorn counts toward Roots)
	var fan := A.ability(&"bramble_fan", "Thorn Fan", "Loose five thorns in a 14 degree fan for 16 each. Every thorn counts toward Roots, so a fan on one target at close range is a root.", AbilityData.Trigger.PRESS, 5.0)
	fan.is_weapon = true
	fan.usable_while_silenced = true
	var spread := A.projectile(16.0, 55.0)
	spread.count = 5; spread.spread_deg = 14.0; spread.radius = 0.1; spread.lifetime = 1.0
	spread.visual_id = &"thorn"
	spread.spawn_offset = Vector3(0.2, -0.12, -0.35)
	fan.effects = [spread]
	A.pres(fan, &"bramble_fan_fire", &"bramble_fan_tail", &"bolt", Color(0.7, 1.0, 0.45))
	fan.presentation.tracer_width = 0.025
	fan.presentation.muzzle_vfx = &"muzzle_generic"
	fan.presentation.impact_vfx = &"impact_generic"
	fan.presentation.sound_impact = &"bramble_fan_impact"
	fan.presentation.projectile_vfx = &"thorn"
	fan.presentation.crosshair = &"circle"
	A.feel(fan, 2.0, 0.4, 0.09, 4.0, 0.06, 12.0)
	A.ai(fan, AbilityAIHints.Intent.DAMAGE, 0.0, 12.0, 5.0, 0.6)
	h.secondary = fan
	# --- Ability 1: Snare (lobbed vine seed: 40 damage + 2 s root)
	var snare := A.ability(&"bramble_snare", "Snare", "Lob a vine seed. On hit it deals 40 and roots the target for 2 s. Cleansable.", AbilityData.Trigger.PRESS, 10.0)
	var snared := A.status(&"bramble_snare", "Snared", 2.0)
	snared.rooted = true; snared.is_crowd_control = true; snared.is_debuff = true; snared.cleansable = true
	snared.color = Color(0.3, 0.7, 0.2)
	snared.sound_apply = &"bramble_snare_apply"
	var seed := A.projectile(40.0, 35.0)
	seed.gravity = 6.0; seed.radius = 0.22; seed.lifetime = 3.0
	seed.hit_status = snared; seed.lob_arc = true; seed.visual_id = &"orb"
	seed.splash_radius = 1.6; seed.splash_damage = 20.0; seed.splash_min_fraction = 0.5
	snare.effects = [seed]
	A.pres(snare, &"bramble_snare_fire", &"bramble_snare_tail", &"arc", Color(0.45, 0.9, 0.35))
	snare.presentation.muzzle_vfx = &"muzzle_generic"
	snare.presentation.impact_vfx = &"bramble_vine_burst"
	snare.presentation.sound_impact = &"bramble_snare_impact"
	snare.presentation.projectile_vfx = &"orb"
	snare.presentation.anim_tag = &"throw"
	snare.presentation.crosshair = &"circle"
	A.feel(snare, 1.4, 0.3, 0.08, 3.0, 0.05)
	A.ai(snare, AbilityAIHints.Intent.CROWD_CONTROL, 3.0, 26.0, 12.0, 0.65)
	snare.ai.combo_tags = [&"root"]
	snare.ai.telegraph_seconds = 0.5
	h.ability_1 = snare
	# --- Ability 2: Thicket (thorn hedge that punishes crossing)
	var thicket := A.ability(&"bramble_thicket", "Thicket", "Grow a 6 m thorn hedge in front of you for 8 s. Enemies crossing it take 30 on entry, 20 per second inside, and are slowed to half. Trampling wears it down (300 hp).", AbilityData.Trigger.PRESS, 12.0)
	var slow := A.status(&"bramble_thicket_slow", "Thorned", 0.8)
	slow.speed_mult = 0.5; slow.is_debuff = true; slow.cleansable = true
	slow.color = Color(0.4, 0.6, 0.2)
	var hedge := DeployEffect.new()
	hedge.kind = &"thicket"
	hedge.visual_id = &"thicket_wall"
	hedge.placement = DeployEffect.Placement.IN_FRONT
	hedge.distance = 4.0
	hedge.health = 300.0
	hedge.lifetime = 8.0
	hedge.max_instances = 1
	hedge.deployable_script = load("res://src/heroes/deployables/BrambleThicket.gd")
	hedge.params = {"width": 6.0, "height": 2.2, "band": 1.2, "dps": 20.0, "entry_damage": 30.0, "slow": &"bramble_thicket_slow", "trample": 60.0}
	thicket.effects = [hedge, _reg(slow)]
	thicket.presentation.sound_fire = &"bramble_thicket_fire"
	thicket.presentation.sound_loop = &"bramble_thicket_loop"
	thicket.presentation.sound_end = &"bramble_thicket_end"
	thicket.presentation.cast_vfx = &"bramble_vine_burst"
	thicket.presentation.area_vfx = &"bramble_thicket_zone"
	thicket.presentation.anim_tag = &"cast"
	thicket.presentation.camera_shake = 0.06
	thicket.presentation.crosshair = &"bracket"
	A.ai(thicket, AbilityAIHints.Intent.CROWD_CONTROL, 0.0, 9.0, 4.0, 0.5)
	thicket.ai.needs_line_of_sight = true
	thicket.ai.combo_tags = [&"zone"]
	h.ability_2 = thicket
	# --- Ultimate: Overgrowth (12 m: enemies rooted 2.5 s + 60 damage, allies healed 150 over 2.5 s)
	var ult := A.ultimate(&"bramble_overgrowth", "Overgrowth", "Thorn erupts in 12 m: every enemy takes 60 and is rooted for 2.5 s; every ally is healed 150 over 2.5 s. Roots go through cover.", 1800.0)
	ult.cast_time = 0.3
	ult.cancel_on_cc = false
	var held := A.status(&"bramble_overgrowth_root", "Overgrown", 2.5)
	held.rooted = true; held.is_crowd_control = true; held.is_debuff = true; held.cleansable = true
	held.color = Color(0.35, 0.85, 0.25)
	held.sound_apply = &"bramble_root_apply"
	var bloom := A.status(&"bramble_overgrowth_bloom", "Bloom", 2.5)
	bloom.hot_hps = 60.0; bloom.cleansable = false
	bloom.color = Color(0.7, 1.0, 0.5)
	var area := AreaEffect.new()
	area.radius = 12.0
	area.damage = 60.0
	area.min_fraction = 0.8
	area.requires_los = false
	area.enemy_status = held
	area.ally_status = bloom
	area.heal_self = true
	area.vfx_id = &"bramble_overgrowth"
	area.damage_type = RF.DamageType.SPLASH
	ult.effects = [area]
	ult.presentation.sound_cast = &"bramble_overgrowth_cast"
	ult.presentation.sound_fire = &"bramble_overgrowth_fire"
	ult.presentation.sound_end = &"bramble_overgrowth_end"
	ult.presentation.sound_impact = &"bramble_overgrowth_impact"
	ult.presentation.cast_vfx = &"bramble_overgrowth_cast"
	ult.presentation.area_vfx = &"bramble_overgrowth"
	ult.presentation.voice_line = &"bramble_ult_line"
	ult.presentation.voice_line_enemy = &"bramble_ult_line_enemy"
	ult.presentation.camera_shake = 0.25
	ult.presentation.crosshair = &"bracket"
	A.ai(ult, AbilityAIHints.Intent.ZONE, 0.0, 12.0, 6.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"root", &"aoe_cc"]
	ult.ai.telegraph_seconds = 0.3
	h.ultimate = ult
	return h
