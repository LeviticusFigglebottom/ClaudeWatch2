extends RefCounted
## CAIRN — Bulwark. Stone-shaper botanist from the Andean Charter. ★ Raise Slab: lifts a stone
## pillar under a target point (ally = elevator, enemy = displacement). Primary: rock lobber with an
## arc. Bulwark of height. Ult Landslide: a wave of stone that knocks enemies back and leaves cover
## behind. Countered by fast ranged dps; counters ground-bound melee.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"cairn", "Cairn", RF.Role.BULWARK, 375.0, 175.0)
	h.codename = "The Terrace Keeper"
	h.sort_order = 4
	h.tagline = "The ground is wherever I say it is."
	h.lore = "Cairn grew potatoes on the terraces above Kestrel Summit until a Core drop buried the lower fields under a kilometer of wreckage. He learned to shape stone the way his grandmother taught him to shape soil: patiently, and always upward. The Andean Charter hires him out to pay for new terraces. He still talks to the rock while he works, and it still seems to listen."
	h.playstyle = "Lob rocks from behind cover and make your own cover when there is none. Raise Slab under a teammate to give them the high ground, or under an enemy to lift them into your team's sightlines. Upthrust gets you onto your own slabs and slams whoever is beneath you when you land. Landslide clears a choke and leaves three pillars behind it: fight from them."
	h.theme_color = Color(0.62, 0.78, 0.42)
	h.difficulty = 2
	h.unique_mechanic = "Raise Slab: a 2.4 m stone pillar rises 3 m out of the ground at the aimed point in half a second, carrying whoever stands on it. Allies get an elevator; enemies get displaced into the open."
	h.counters = [&"sable", &"cathedral", &"ballast", &"bramble"]
	h.countered_by = [&"harrier", &"vesper", &"coil", &"wisp"]
	h.synergies = [&"vesper", &"bombard", &"kiln", &"lumen"]
	h.hero_script = load("res://src/heroes/behaviors/CairnBehavior.gd")
	# Body: broad, unhurried, lighter than the iron bulwarks.
	h.movement = A.movement(5.3, 6.4, 55.0, 0.32)
	h.movement.footstep_interval = 0.46
	h.movement.capsule_height = 1.95
	h.movement.eye_height = 1.66
	h.movement.crouch_eye_height = 1.05
	h.movement.landing_recovery = 0.1
	h.hitbox.body_radius = 0.44
	h.hitbox.head_radius = 0.22
	h.hitbox.head_height = 1.7
	h.hitbox.head_crouch_height = 1.1
	h.hitbox.body_top = 1.4
	h.hitbox.body_crouch_top = 0.9
	h.visual.build = HeroVisualData.Build.HEAVY
	h.visual.height = 1.92
	h.visual.shoulder_width = 0.62
	h.visual.head = HeroVisualData.HeadShape.HOOD
	h.visual.extras = [HeroVisualData.Extra.SHOULDER_PADS, HeroVisualData.Extra.VINES]
	h.visual.primary_color = Color(0.5, 0.46, 0.4)
	h.visual.secondary_color = Color(0.3, 0.36, 0.26)
	h.visual.accent_color = Color(0.62, 0.78, 0.42)
	h.visual.emissive_color = Color(0.7, 0.95, 0.5)
	h.visual.emissive_strength = 1.4
	h.visual.metallic = 0.05
	h.visual.roughness = 0.9
	h.visual.skin_color = Color(0.5, 0.36, 0.28)
	h.visual.weapon_style = &"launcher"
	h.visual.weapon_scale = 1.25
	h.visual.arms_color = Color(0.46, 0.42, 0.36)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "A heavy hooded figure in stone-grey with green vines wrapped around the torso, big rounded shoulder pads and a drum-fed rock launcher. Earthy, matte, no metal shine."
	h.audio.footstep_set = &"boots_heavy"
	h.audio.ult_stinger = &"ult_cairn"
	h.audio.ult_stinger_enemy = &"ult_cairn_enemy"
	h.audio.voice_pitch = 0.9
	h.audio.callout_tone = &"radio_a"
	# AI
	h.ai.preferred_range = 12.0; h.ai.min_range = 3.0; h.ai.max_effective_range = 26.0
	h.ai.aggression = 0.45; h.ai.self_preservation = 0.5; h.ai.prefers_high_ground = 0.9; h.ai.sticks_to_tank = 0.0
	h.ai.builds = true
	h.ai.ult_style = &"zone"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.25
	# --- Primary: Rock Lobber (arcing projectile with splash)
	var prim := A.weapon(&"cairn_lobber", "Rock Lobber", "Lobs a stone at 30 m/s in a heavy arc: 80 damage on a direct hit, 50 splash within 2.5 m. Arcs over cover; lead your targets.", 1.5, 6, 1.6)
	var rock := A.projectile(80.0, 30.0)
	rock.gravity = 12.0
	rock.radius = 0.22
	rock.lifetime = 3.0
	rock.splash_radius = 2.5
	rock.splash_damage = 50.0
	rock.splash_min_fraction = 0.4
	rock.knockback = 2.0
	rock.lob_arc = true
	rock.visual_id = &"shell"
	prim.effects = [rock]
	A.pres(prim, &"cairn_lobber_fire", &"cairn_lobber_tail", &"", Color(0.75, 0.85, 0.55))
	prim.presentation.muzzle_vfx = &"cairn_rock_muzzle"
	prim.presentation.impact_vfx = &"cairn_rock_impact"
	prim.presentation.sound_impact = &"cairn_lobber_impact"
	prim.presentation.projectile_vfx = &"shell"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.crosshair = &"circle"
	A.feel(prim, 2.8, 0.4, 0.16, 6.0, 0.12, 9.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 2.0, 30.0, 12.0)
	prim.ai.needs_line_of_sight = false
	h.primary = prim
	# --- Secondary: Boulder (heavy lob, big splash, knockback)
	var sec := A.ability(&"cairn_boulder", "Boulder", "Heave a boulder: 120 damage on a direct hit, 70 splash within 4 m, and everyone caught is shoved away. Slow and heavy; aim it at a choke.", AbilityData.Trigger.PRESS, 5.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	sec.recovery = 0.35
	var boulder := A.projectile(120.0, 22.0)
	boulder.gravity = 14.0
	boulder.radius = 0.35
	boulder.lifetime = 3.0
	boulder.splash_radius = 4.0
	boulder.splash_damage = 70.0
	boulder.splash_min_fraction = 0.35
	boulder.knockback = 7.0
	boulder.lob_arc = true
	boulder.visual_id = &"shell"
	sec.effects = [boulder]
	A.pres(sec, &"cairn_boulder_fire", &"cairn_boulder_tail", &"", Color(0.7, 0.8, 0.5))
	sec.presentation.muzzle_vfx = &"cairn_rock_muzzle"
	sec.presentation.impact_vfx = &"explosion"
	sec.presentation.sound_impact = &"cairn_boulder_impact"
	sec.presentation.projectile_vfx = &"shell"
	sec.presentation.impact_decal = &"scorch"
	sec.presentation.crosshair = &"circle"
	A.feel(sec, 4.0, 0.6, 0.22, 8.0, 0.18)
	A.ai(sec, AbilityAIHints.Intent.DAMAGE, 4.0, 26.0, 12.0, 0.6)
	sec.ai.needs_line_of_sight = false
	sec.ai.combo_tags = [&"aoe_damage"]
	h.secondary = sec
	# --- Ability 1: Raise Slab (★ signature)
	var slab := A.ability(&"cairn_slab", "Raise Slab", "A 2.4 m wide stone pillar rises 3 m out of the ground where you aim (within 18 m) in half a second and stands for 5 s (450 hp). Anyone on it rides up: an elevator for allies, a lift into the open for enemies. Blocks shots and movement.", AbilityData.Trigger.PRESS, 10.0)
	slab.recovery = 0.2
	var sdep := DeployEffect.new()
	sdep.kind = &"slab"
	sdep.visual_id = &"cairn_slab"
	sdep.placement = DeployEffect.Placement.AIMED_GROUND
	sdep.max_range = 18.0
	sdep.health = 450.0
	sdep.lifetime = 5.0
	sdep.max_instances = 2
	sdep.deployable_script = load("res://src/heroes/deployables/CairnSlab.gd")
	sdep.params = {"height": 3.0, "width": 2.4, "rise_time": 0.5}
	slab.effects = [sdep]
	slab.presentation.sound_cast = &"cairn_slab_cast"
	slab.presentation.sound_fire = &"cairn_slab_fire"
	slab.presentation.sound_end = &"cairn_slab_end"
	slab.presentation.cast_vfx = &"cast_generic"
	slab.presentation.muzzle_vfx = &"cairn_slab_dust"
	slab.presentation.anim_tag = &"cast"
	slab.presentation.crosshair = &"bracket"
	A.feel(slab, 0.0, 0.0, 0.08, 3.0, 0.14)
	A.ai(slab, AbilityAIHints.Intent.CROWD_CONTROL, 3.0, 18.0, 9.0, 0.6)
	slab.ai.target_ground = true
	slab.ai.needs_line_of_sight = true
	slab.ai.telegraph_seconds = 0.5
	slab.ai.combo_tags = [&"displace", &"high_ground", &"barrier"]
	h.ability_1 = slab
	# --- Ability 2: Upthrust (leap + landing slam)
	var up := A.ability(&"cairn_upthrust", "Upthrust", "Kick off the ground: a 3 m leap in the direction you face. When you land, the stone answers: 55 damage within 3.5 m, enemies shoved away and slowed to 70% for a second. Your way onto your own slabs.", AbilityData.Trigger.PRESS, 9.0)
	up.behavior = load("res://src/heroes/abilities/CairnUpthrustBehavior.gd")
	up.active_duration = 3.0
	up.requires_ground = true
	up.cancel_on_cc = false
	up.recovery = 0.1
	var leap := DashEffect.new()
	leap.direction = DashEffect.Dir.AIM_FLAT
	leap.speed = 6.0
	leap.vertical_boost = 11.0
	leap.preserve_momentum = 0.2
	var tremor := A.status(&"cairn_tremor", "Tremor", 1.0)
	tremor.speed_mult = 0.7
	tremor.is_debuff = true
	tremor.is_crowd_control = true
	tremor.cleansable = true
	tremor.color = Color(0.7, 0.8, 0.5)
	tremor.tags = [&"slow"]
	var tremor_carrier := ApplyStatusEffect.new()   # status carrier for the behavior's slam
	tremor_carrier.status = tremor
	tremor_carrier.who = ApplyStatusEffect.Who.TARGET
	tremor_carrier.enabled = false
	up.effects = [leap, tremor_carrier]
	up.presentation.sound_cast = &"cairn_upthrust_cast"
	up.presentation.sound_end = &"cairn_upthrust_end"
	up.presentation.sound_impact = &"cairn_upthrust_impact"
	up.presentation.cast_vfx = &"cairn_slab_dust"
	up.presentation.end_vfx = &"cairn_rock_impact"
	up.presentation.anim_tag = &"cast"
	A.feel(up, 0.0, 0.0, 0.1, 4.0, 0.2)
	A.ai(up, AbilityAIHints.Intent.MOBILITY, 3.0, 20.0, 8.0, 0.5)
	up.ai.use_when_health_below = 0.5
	up.ai.combo_tags = [&"high_ground"]
	h.ability_2 = up
	# --- Ultimate: Landslide (knockback wave + 3 pillars of cover)
	var ult := A.ultimate(&"cairn_landslide", "Landslide", "Shove a wave of stone through a 60 degree cone to 12 m: 90 damage and a hard knockback. Three stone pillars then rise at 4, 7 and 10 m in front of you and stand for 6 s: cover for your team, a wall for theirs.", 1800.0)
	ult.recovery = 0.5
	var wave := KnockbackEffect.new()
	wave.radius = 12.0
	wave.cone_deg = 60.0
	wave.force = 14.0
	wave.upward = 0.35
	wave.damage = 90.0
	wave.requires_los = true
	var pillars: Array[AbilityEffect] = [wave]
	var dists := [4.0, 7.0, 10.0]
	for i in 3:
		var pdep := DeployEffect.new()
		pdep.kind = &"cairn_wave"
		pdep.visual_id = &"cairn_wave_slab"
		pdep.placement = DeployEffect.Placement.IN_FRONT
		pdep.distance = float(dists[i])
		pdep.health = 500.0
		pdep.lifetime = 6.0
		pdep.max_instances = 3
		pdep.delay = 0.12 * i
		pdep.deployable_script = load("res://src/heroes/deployables/CairnSlab.gd")
		pdep.params = {"height": 2.6, "width": 3.2, "rise_time": 0.35}
		pillars.append(pdep)
	ult.effects = pillars
	ult.presentation.sound_cast = &"cairn_landslide_cast"
	ult.presentation.sound_fire = &"cairn_landslide_fire"
	ult.presentation.sound_end = &"cairn_landslide_end"
	ult.presentation.cast_vfx = &"cairn_landslide"
	ult.presentation.muzzle_vfx = &"cairn_slab_dust"
	ult.presentation.voice_line = &"cairn_ult_line"
	ult.presentation.voice_line_enemy = &"cairn_ult_line_enemy"
	ult.presentation.self_glow = Color(0.62, 0.78, 0.42, 1.0)
	A.feel(ult, 3.0, 0.0, 0.2, 6.0, 0.4)
	A.ai(ult, AbilityAIHints.Intent.CROWD_CONTROL, 0.0, 12.0, 6.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.combo_tags = [&"displace", &"barrier"]
	ult.ai.telegraph_seconds = 0.3
	h.ultimate = ult
	return h
