extends RefCounted
## SABLE — Striker. Shadow-dancer, melee only. Signature: Backstab (2.5x from behind) on every
## blade hit, plus Shroud (invisible while creeping below 40% speed). Counters supports and
## snipers; countered by reveal and AoE.


static func _reg(status: StatusData) -> ApplyStatusEffect:
	var e := ApplyStatusEffect.new()
	e.status = status
	e.enabled = false
	return e


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"sable", "Sable", RF.Role.STRIKER, 225.0)
	h.codename = "The Shadow-dancer"
	h.sort_order = 16
	h.tagline = "You'll hear the second cut."
	h.lore = "Sable danced in the Pearl River Charter's lantern theatres until the theatres were bought by a Charter that preferred quiet. She kept the blades from the last show, learned that stillness is the only real camouflage, and now takes contracts against the loud. She never runs in; she arrives."
	h.playstyle = "Creep in Shroud below 40% speed, open from behind for 2.5x, finish the three-hit combo and Vault out before the team turns. Lunge closes the last gap. Requiem is a team wipe if they are clumped and nobody has reveal or a save."
	h.theme_color = Color(0.58, 0.32, 0.8)
	h.difficulty = 3
	h.unique_mechanic = "Backstab: every blade hit from behind deals 2.5x. Shroud keeps you invisible only while moving below 40% speed; sprinting or striking breaks it for 1 s."
	h.counters = [&"tallow", &"suture", &"vesper", &"lumen"]
	h.countered_by = [&"vesper", &"bombard", &"coil", &"rook"]
	h.synergies = [&"tallow", &"wisp", &"ballast"]
	h.hero_script = load("res://src/heroes/behaviors/SableBehavior.gd")
	# Body: light, hooded, a long tail of cloth, twin blades, hunched stance.
	h.movement = A.movement(5.8, 7.0, 72.0, 0.55)
	h.movement.footstep_interval = 0.34
	h.movement.mass = 0.85
	h.movement.air_accel = 16.0
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.74
	h.visual.shoulder_width = 0.48
	h.visual.head = HeroVisualData.HeadShape.HOOD
	h.visual.extras = [HeroVisualData.Extra.TAIL, HeroVisualData.Extra.CLOAK]
	h.visual.primary_color = Color(0.12, 0.1, 0.16)
	h.visual.secondary_color = Color(0.22, 0.14, 0.3)
	h.visual.accent_color = Color(0.6, 0.32, 0.82)
	h.visual.emissive_color = Color(0.72, 0.42, 1.0)
	h.visual.emissive_strength = 1.6
	h.visual.metallic = 0.15
	h.visual.roughness = 0.75
	h.visual.weapon_style = &"blades"
	h.visual.weapon_scale = 1.05
	h.visual.arms_color = Color(0.14, 0.12, 0.18)
	h.visual.stance = &"hunched"
	h.visual.silhouette_notes = "Small, low and narrow: a hood, a short cloak, a long tail of cloth and two blades. Hunched, always looks about to move."
	h.audio.footstep_set = &"boots_light"
	h.audio.footstep_volume = 0.6
	h.audio.ult_stinger = &"ult_sable"
	h.audio.ult_stinger_enemy = &"ult_sable_enemy"
	# AI: flanker that dives supports and fights at blade range.
	h.ai.preferred_range = 2.0; h.ai.min_range = 0.0; h.ai.max_effective_range = 7.0
	h.ai.aggression = 0.9; h.ai.self_preservation = 0.45; h.ai.prefers_high_ground = 0.3
	h.ai.flanker = true; h.ai.dives = true; h.ai.melee_brawler = true; h.ai.sticks_to_tank = 0.1
	h.ai.ult_style = &"engage"; h.ai.ult_min_targets = 1; h.ai.strafe_style = &"jump"
	h.ai.aim_difficulty_scale = 0.8
	# --- Primary: Twin Blades (three-hit combo driven by SableComboBehavior)
	var prim := A.weapon(&"sable_blades", "Twin Blades", "Three-hit combo: 40, 40 (wide sweep, two targets), then 70 (thrust). Reach 2.6 m. Every hit from behind deals 2.5x. The combo resets after 1.2 s without a swing.", 2.4, 0, 0.0)
	prim.behavior = load("res://src/heroes/abilities/SableComboBehavior.gd")
	prim.effects = []
	A.pres(prim, &"sable_blades_fire", &"sable_blades_tail", &"", Color(0.75, 0.45, 1.0))
	prim.presentation.muzzle_vfx = &""
	prim.presentation.impact_vfx = &"melee_hit"
	prim.presentation.impact_decal = &""
	prim.presentation.sound_impact = &"sable_blades_impact"
	prim.presentation.crosshair = &"cross"
	prim.presentation.anim_tag = &"melee"
	prim.presentation.hitstop_on_hit = 0.02
	A.feel(prim, 0.5, 0.35, 0.07, 3.5, 0.04, 14.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 3.2, 2.0)
	h.primary = prim
	# --- Secondary: Lunge (16 m/s dash toward aim for 0.25 s, strike on arrival)
	var lunge := A.ability(&"sable_lunge", "Lunge", "Dash 4 m toward your aim in a quarter second and cut for 30 on arrival (backstab-eligible). The gap closer that starts every combo.", AbilityData.Trigger.PRESS, 6.0)
	lunge.active_duration = 0.25
	lunge.cancel_on_cc = true
	lunge.behavior = load("res://src/heroes/abilities/SableLungeBehavior.gd")
	var cut := MeleeEffect.new()
	cut.damage = 30.0; cut.range = 2.8; cut.arc_deg = 140.0; cut.knockback = 2.0
	cut.backstab_multiplier = 2.5; cut.max_targets = 1
	lunge.end_effects = [cut]
	lunge.presentation.sound_cast = &"sable_lunge_cast"
	lunge.presentation.sound_end = &"sable_lunge_end"
	lunge.presentation.sound_impact = &"sable_lunge_impact"
	lunge.presentation.cast_vfx = &"sable_shadow_step"
	lunge.presentation.impact_vfx = &"melee_hit"
	lunge.presentation.anim_tag = &"melee"
	lunge.presentation.camera_shake = 0.08
	lunge.presentation.viewmodel_kick = 0.05
	lunge.presentation.crosshair = &"cross"
	A.ai(lunge, AbilityAIHints.Intent.ENGAGE, 2.0, 9.0, 4.5, 0.75)
	lunge.ai.combo_tags = [&"dive"]
	h.secondary = lunge
	# --- Ability 1: Shroud (toggle; invisible only while below 40% speed)
	var shroud := A.ability(&"sable_shroud", "Shroud", "Toggle. While Shroud is on you are invisible whenever you move below 40% speed. Moving faster or striking breaks it for 1 s.", AbilityData.Trigger.TOGGLE, 2.0)
	shroud.cooldown_starts_on_end = true
	shroud.cancel_on_cc = false
	var veil := A.status(&"sable_shroud", "Shrouded", 0.0)   # duration 0: lives until the toggle ends
	veil.invisible = true
	veil.cleansable = false
	veil.color = Color(0.5, 0.3, 0.8)
	veil.stacking = StatusData.Stacking.REFRESH
	shroud.self_status_while_active = veil
	shroud.presentation.sound_cast = &"sable_shroud_cast"
	shroud.presentation.sound_end = &"sable_shroud_end"
	shroud.presentation.sound_loop = &"sable_shroud_loop"
	shroud.presentation.cast_vfx = &"smoke_puff"
	shroud.presentation.end_vfx = &"smoke_puff"
	shroud.presentation.self_glow = Color(0.4, 0.2, 0.7, 0.6)
	shroud.presentation.anim_tag = &"cast"
	shroud.presentation.crosshair = &"cross"
	A.ai(shroud, AbilityAIHints.Intent.UTILITY, 0.0, 60.0, 15.0, 0.7)
	shroud.ai.needs_line_of_sight = false
	h.ability_1 = shroud
	# --- Ability 2: Vault (up-and-forward leap)
	var vault := A.ability(&"sable_vault", "Vault", "Leap high in your movement direction: onto ledges, over a wall, or out of a fight that turned.", AbilityData.Trigger.PRESS, 8.0)
	var leap := DashEffect.new()
	leap.direction = DashEffect.Dir.MOVE_OR_FORWARD
	leap.speed = 8.0
	leap.vertical_boost = 9.5
	leap.preserve_momentum = 0.2
	vault.effects = [leap]
	vault.presentation.sound_fire = &"sable_vault_fire"
	vault.presentation.sound_tail = &"sable_vault_tail"
	vault.presentation.cast_vfx = &"sable_shadow_step"
	vault.presentation.anim_tag = &"cast"
	vault.presentation.camera_shake = 0.05
	vault.presentation.crosshair = &"cross"
	A.ai(vault, AbilityAIHints.Intent.MOBILITY, 3.0, 30.0, 6.0, 0.5)
	vault.ai.use_when_health_below = 0.4
	vault.ai.needs_line_of_sight = false
	h.ability_2 = vault
	# --- Ultimate: Requiem (mark all enemies in 12 m, dash through each; invulnerable)
	var ult := A.ultimate(&"sable_requiem", "Requiem", "Mark every enemy within 12 m (revealed 4 s), then dash through each in turn at 30 m/s, cutting for 100 (2.5x from behind). You are invulnerable and unstoppable until the last cut.", 1750.0)
	ult.active_duration = 6.0
	ult.cancel_on_cc = false
	ult.behavior = load("res://src/heroes/abilities/SableRequiemBehavior.gd")
	var dance := A.status(&"sable_requiem", "Requiem", 0.0)
	dance.invulnerable = true
	dance.unstoppable = true
	dance.cleansable = false
	dance.color = Color(0.8, 0.5, 1.0)
	ult.self_status_while_active = dance
	var mark := A.status(&"sable_requiem_mark", "Marked", 4.0)
	mark.revealed = true; mark.is_debuff = true; mark.cleansable = true
	mark.color = Color(0.9, 0.4, 1.0)
	ult.effects = [_reg(mark)]
	ult.presentation.sound_cast = &"sable_requiem_cast"
	ult.presentation.sound_loop = &"sable_requiem_loop"
	ult.presentation.sound_end = &"sable_requiem_end"
	ult.presentation.sound_impact = &"sable_requiem_impact"
	ult.presentation.cast_vfx = &"sable_requiem_cast"
	ult.presentation.loop_vfx = &"sable_requiem_loop"
	ult.presentation.end_vfx = &"smoke_puff"
	ult.presentation.area_vfx = &"sable_requiem_mark"
	ult.presentation.voice_line = &"sable_ult_line"
	ult.presentation.voice_line_enemy = &"sable_ult_line_enemy"
	ult.presentation.camera_shake = 0.2
	ult.presentation.crosshair = &"cross"
	A.ai(ult, AbilityAIHints.Intent.ENGAGE, 0.0, 12.0, 4.0, 0.7)
	ult.ai.needs_enemies_in_radius = 1
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"dive"]
	h.ultimate = ult
	return h
