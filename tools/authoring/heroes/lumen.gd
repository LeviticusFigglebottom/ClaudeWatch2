extends RefCounted
## LUMEN — Conduit. Optics researcher with a mirror-staff. ★ Her beam bounces off placed mirrors,
## healing allies / burning enemies along the path. Prism splits the beam three ways, Refract places a
## mirror, Sunstroke is a wide blinding beam. Geometry healer; countered by mobility that breaks lines.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"lumen", "Lumen", RF.Role.CONDUIT, 200.0)
	h.codename = "The Refractor"
	h.sort_order = 22
	h.tagline = "Every angle is a way in."
	h.lore = "Lumen spent a decade in the Meridian Station optics lab coaxing sunlight through kilometres of salvaged Ring glass to grow crops in the dark. When the lab was sold for scrap she kept one thing: the staff, a coherent-light emitter that can be steered with mirrors. She heals the way she farmed - by finding the angle nobody else saw."
	h.playstyle = "Hold Mirror Beam on whoever needs it; it burns enemies just as well. Place Refract mirrors at corners so the beam can reach allies you cannot see, and pop Prism when the team clumps to heal three at once. Sunstroke is both a blind and a big heal: fire it down the lane where the fight is."
	h.theme_color = Color(1.0, 0.9, 0.5)
	h.difficulty = 3
	h.unique_mechanic = "Bouncing beam: Mirror Beam reflects off Refract mirrors (up to 3 bounces), healing the first ally / burning the first enemy along the full folded path. Prism splits it into up to 3 targets in a 25 degree cone."
	h.counters = [&"bombard", &"rook", &"ballast"]
	h.countered_by = [&"harrier", &"wisp", &"sable"]
	h.synergies = [&"vesper", &"cathedral", &"cairn"]
	h.hero_script = load("res://src/heroes/behaviors/LumenBehavior.gd")
	# Body
	h.movement = A.movement(5.5, 6.4)
	h.movement.footstep_interval = 0.4
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.76
	h.visual.head = HeroVisualData.HeadShape.DOME
	h.visual.extras = [HeroVisualData.Extra.PRISM]
	h.visual.primary_color = Color(0.92, 0.9, 0.84)
	h.visual.secondary_color = Color(0.36, 0.32, 0.44)
	h.visual.accent_color = Color(1.0, 0.8, 0.35)
	h.visual.emissive_color = Color(1.0, 0.95, 0.7)
	h.visual.emissive_strength = 2.6
	h.visual.metallic = 0.2
	h.visual.roughness = 0.5
	h.visual.weapon_style = &"staff"
	h.visual.weapon_scale = 1.05
	h.visual.arms_color = Color(0.82, 0.8, 0.76)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Light build, glowing glass dome for a head, a floating prism above the shoulders and a tall staff. Pale coat, gold trim: reads as 'light' even in shadow."
	h.audio.footstep_set = &"boots_light"
	h.audio.ult_stinger = &"ult_lumen"
	h.audio.ult_stinger_enemy = &"ult_lumen_enemy"
	h.audio.callout_tone = &"radio_c"
	# AI
	h.ai.preferred_range = 11.0; h.ai.min_range = 2.0; h.ai.max_effective_range = 25.0
	h.ai.aggression = 0.3; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 0.6
	h.ai.sticks_to_tank = 0.7; h.ai.heals = true; h.ai.heal_range = 22.0; h.ai.builds = true
	h.ai.ult_style = &"combo_enabler"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	# --- Primary: Mirror Beam (channelled heal/damage beam that bounces off mirrors)
	var beam := A.ability(&"lumen_beam", "Mirror Beam", "Hold: a beam of light up to 25 m that heals the first ally it touches for 65/s or burns the first enemy for 55/s. It reflects off Refract mirrors (up to 3 bounces), so it can reach around corners.", AbilityData.Trigger.CHANNEL, 0.0)
	beam.is_weapon = true
	beam.usable_while_silenced = true
	beam.tick_interval = 0.0
	var be := LumenBeamEffect.new()
	be.heal_per_second = 65.0; be.dps = 55.0; be.range = 25.0
	be.max_bounces = 3; be.lock_on_deg = 7.0
	be.prism_cone_deg = 25.0; be.prism_targets = 3; be.prism_share = 0.75
	beam.tick_effects = [be]
	A.pres(beam, &"lumen_beam_fire", &"", &"beam", Color(1.0, 0.92, 0.6))
	beam.presentation.tracer_width = 0.06
	beam.presentation.sound_cast = &"lumen_beam_cast"
	beam.presentation.sound_loop = &"lumen_beam_loop"
	beam.presentation.sound_end = &"lumen_beam_end"
	beam.presentation.muzzle_vfx = &"lumen_beam_muzzle"
	beam.presentation.impact_vfx = &"lumen_beam_impact"
	beam.presentation.impact_decal = &""
	beam.presentation.crosshair = &"circle"
	beam.presentation.self_glow = Color(1.0, 0.9, 0.5, 0.35)
	A.feel(beam, 0.0, 0.0, 0.02, 0.6, 0.0)
	A.ai(beam, AbilityAIHints.Intent.HEAL, 0.0, 25.0, 10.0, 0.6)
	beam.ai.target_ally = true
	beam.ai.spam_ok = true
	h.primary = beam
	# --- Secondary: Glint (instant burst heal on the aimed ally)
	var glint := A.ability(&"lumen_glint", "Glint", "Flash the staff at an ally: heals them for 70 instantly (25 m). Only fires with an ally under the crosshair.", AbilityData.Trigger.PRESS, 5.0)
	glint.behavior = load("res://src/heroes/abilities/SutureAimedAllyGate.gd")
	glint.usable_while_silenced = false
	var gh := HealEffect.new()
	gh.who = HealEffect.Who.TARGET
	gh.amount = 70.0
	glint.effects = [gh]
	glint.presentation.sound_fire = &"lumen_glint_fire"
	glint.presentation.cast_vfx = &"lumen_glint_cast"
	glint.presentation.anim_tag = &"cast"
	glint.presentation.crosshair = &"circle"
	glint.presentation.viewmodel_kick = 0.04
	A.ai(glint, AbilityAIHints.Intent.HEAL, 0.0, 25.0, 10.0, 0.7)
	glint.ai.target_ally = true
	glint.ai.spam_ok = true
	h.secondary = glint
	# --- Ability 1: Prism (beam splits into 3 targets for 4 s)
	var prism := A.ability(&"lumen_prism", "Prism", "For 4 s the beam passes through the prism and splits: it heals or burns up to 3 targets inside a 25 degree cone, each at 75% strength.", AbilityData.Trigger.PRESS, 12.0)
	var ps := A.status(&"lumen_prism", "Prism", 4.0)
	ps.cleansable = false
	ps.color = Color(1.0, 0.85, 0.5)
	var ps_apply := ApplyStatusEffect.new()
	ps_apply.who = ApplyStatusEffect.Who.SELF
	ps_apply.status = ps
	prism.effects = [ps_apply]
	prism.presentation.sound_fire = &"lumen_prism_fire"
	prism.presentation.cast_vfx = &"lumen_prism_cast"
	prism.presentation.anim_tag = &"cast"
	prism.presentation.self_glow = Color(1.0, 0.85, 0.5, 0.8)
	A.ai(prism, AbilityAIHints.Intent.BUFF_ALLIES, 0.0, 20.0, 10.0, 0.6)
	prism.ai.needs_allies_in_radius = 2
	prism.ai.needs_line_of_sight = false
	prism.ai.combo_tags = [&"multi_heal"]
	h.ability_1 = prism
	# --- Ability 2: Refract (place a mirror)
	var refract := A.ability(&"lumen_refract", "Refract", "Place a mirror (120 hp, 15 s, two at a time) where you aim, facing you. Mirror Beam reflects off it, so you can heal around corners and over cover. Enemies can shoot it down.", AbilityData.Trigger.PRESS, 8.0)
	refract.charges = 2
	var dep := DeployEffect.new()
	dep.deployable_script = load("res://src/heroes/deployables/LumenMirror.gd")
	dep.placement = DeployEffect.Placement.AIMED_GROUND
	dep.max_range = 14.0
	dep.health = 120.0
	dep.lifetime = 15.0
	dep.max_instances = 2
	dep.kind = &"mirror"
	dep.visual_id = &"mirror"
	dep.face_caster = true
	dep.params = {"width": 1.4, "height": 1.8}
	refract.effects = [dep]
	refract.presentation.sound_fire = &"lumen_refract_fire"
	refract.presentation.cast_vfx = &"lumen_refract_cast"
	refract.presentation.anim_tag = &"throw"
	A.ai(refract, AbilityAIHints.Intent.UTILITY, 2.0, 14.0, 7.0, 0.45)
	refract.ai.target_ground = true
	refract.ai.needs_line_of_sight = false
	h.ability_2 = refract
	# --- Ultimate: Sunstroke (3 s wide blinding beam that also heals allies in it)
	var ult := A.ultimate(&"lumen_sunstroke", "Sunstroke", "3 s: a blazing beam as wide as a doorway, 30 m. Enemies in it burn for 120/s and are blinded (60% speed, revealed); allies in it are healed for 100/s. Lumen moves at half speed while channelling.", 1750.0)
	ult.active_duration = 3.0
	ult.cancel_on_cc = true
	ult.blocks_primary_while_active = true
	var slow := A.status(&"lumen_sunstroke", "Sunstroke", 3.0)
	slow.speed_mult = 0.5
	slow.cleansable = false
	slow.color = Color(1.0, 0.97, 0.8)
	ult.self_status_while_active = slow
	var blind := A.status(&"lumen_blind", "Blinded", 1.5)
	blind.speed_mult = 0.6
	blind.revealed = true
	blind.is_debuff = true
	blind.is_crowd_control = true
	blind.cleansable = true
	blind.color = Color(1.0, 1.0, 0.8)
	blind.sound_apply = &"lumen_blind_apply"
	var sun := LumenSunstrokeEffect.new()
	sun.dps = 120.0; sun.heal_per_second = 100.0; sun.range = 30.0; sun.half_angle_deg = 10.0
	sun.enemy_status = blind
	ult.tick_effects = [sun]
	A.pres(ult, &"lumen_sunstroke_fire", &"", &"beam", Color(1.0, 0.97, 0.8))
	ult.presentation.tracer_width = 0.5
	ult.presentation.sound_cast = &"lumen_sunstroke_cast"
	ult.presentation.sound_loop = &"lumen_sunstroke_loop"
	ult.presentation.sound_end = &"lumen_sunstroke_end"
	ult.presentation.cast_vfx = &"lumen_sunstroke_cast"
	ult.presentation.loop_vfx = &"lumen_sunstroke_loop"
	ult.presentation.end_vfx = &"lumen_sunstroke_end"
	ult.presentation.impact_vfx = &"lumen_beam_impact"
	ult.presentation.voice_line = &"lumen_ult_line"
	ult.presentation.voice_line_enemy = &"lumen_ult_line_enemy"
	ult.presentation.camera_shake = 0.12
	ult.presentation.crosshair = &"circle"
	ult.presentation.self_glow = Color(1.0, 0.95, 0.7, 1.0)
	A.ai(ult, AbilityAIHints.Intent.DAMAGE, 0.0, 30.0, 12.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_allies_in_radius = 1
	ult.ai.combo_tags = [&"blind", &"aoe_damage", &"heal"]
	h.ultimate = ult
	return h
