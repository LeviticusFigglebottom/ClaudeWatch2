extends RefCounted
## BALLAST — Bulwark. Deep-salvage diver in a pressure suit. ★ Anchor: a harpoon-anchor that either
## drags him to a surface or reels an enemy to him. Wave-cannon shotgun, Surge (armor while walking
## slow), ult Riptide: a tidal pull that drags enemies to a point and slows them. Heavy, slow,
## inevitable. Counters flankers; countered by ranged poke.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"ballast", "Ballast", RF.Role.BULWARK, 300.0, 250.0)
	h.codename = "The Diver"
	h.sort_order = 1
	h.tagline = "The deep does not let go."
	h.lore = "Ballast spent twenty years walking the drowned floors of the Adriatic Charter, cutting reactor plate out of stations that fell into the sea. The pressure suit is his own design; the anchor was the first tool he ever forged. He talks slowly, moves slowly, and has never once lost a grip on anything he decided to hold. The Charters hire him when the drop site is somewhere nobody else can stand."
	h.playstyle = "Walk forward. Hook anyone who flanks or peeks and drop them at your feet, then finish with the Wave Cannon. Use Anchor on walls to reposition without giving up the front line. Surge when the poke starts hurting: you get slower but far tougher. Riptide drags an entire team into one spot for your strikers."
	h.theme_color = Color(0.25, 0.74, 0.78)
	h.difficulty = 2
	h.unique_mechanic = "Anchor: throws a harpoon-anchor. Hit a wall or floor and Ballast is winched to it; hit an enemy and they are reeled to Ballast and briefly hooked (rooted). Unstoppable enemies cannot be reeled."
	h.counters = [&"sable", &"harrier", &"wisp", &"ricochet"]
	h.countered_by = [&"vesper", &"bombard", &"lumen", &"kiln"]
	h.synergies = [&"coil", &"rook", &"suture", &"cadence"]
	# Body: heavy, armored, slow.
	h.movement = A.movement(5.0, 6.2, 50.0, 0.3)
	h.movement.footstep_interval = 0.5
	h.movement.capsule_height = 2.0
	h.movement.crouch_height = 1.3
	h.movement.eye_height = 1.72
	h.movement.crouch_eye_height = 1.05
	h.movement.landing_recovery = 0.15
	h.movement.backpedal_mult = 0.85
	h.hitbox.body_radius = 0.46
	h.hitbox.head_radius = 0.22
	h.hitbox.head_height = 1.76
	h.hitbox.head_crouch_height = 1.12
	h.hitbox.body_top = 1.46
	h.hitbox.body_crouch_top = 0.92
	h.visual.build = HeroVisualData.Build.HEAVY
	h.visual.height = 2.0
	h.visual.shoulder_width = 0.64
	h.visual.head = HeroVisualData.HeadShape.DIVER
	h.visual.extras = [HeroVisualData.Extra.ANCHOR, HeroVisualData.Extra.SHOULDER_PADS]
	h.visual.primary_color = Color(0.22, 0.4, 0.44)
	h.visual.secondary_color = Color(0.13, 0.17, 0.2)
	h.visual.accent_color = Color(0.82, 0.62, 0.3)
	h.visual.emissive_color = Color(0.35, 0.95, 0.9)
	h.visual.emissive_strength = 2.2
	h.visual.metallic = 0.65
	h.visual.roughness = 0.5
	h.visual.weapon_style = &"harpoon"
	h.visual.weapon_scale = 1.25
	h.visual.arms_color = Color(0.2, 0.34, 0.38)
	h.visual.stance = &"brace"
	h.visual.silhouette_notes = "Round diving helmet with three brass bolts, an anchor strapped across the back, wide braced stance and a long harpoon gun. Reads as 'the heavy one' from across the map."
	h.audio.footstep_set = &"boots_heavy"
	h.audio.ult_stinger = &"ult_ballast"
	h.audio.ult_stinger_enemy = &"ult_ballast_enemy"
	h.audio.voice_pitch = 0.85
	h.audio.callout_tone = &"radio_b"
	h.hero_script = load("res://src/heroes/behaviors/BallastBehavior.gd")
	# AI
	h.ai.preferred_range = 6.0; h.ai.min_range = 0.0; h.ai.max_effective_range = 18.0
	h.ai.aggression = 0.7; h.ai.self_preservation = 0.4; h.ai.prefers_high_ground = 0.2; h.ai.sticks_to_tank = 0.0
	h.ai.ult_style = &"combo_enabler"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 0.9
	# --- Primary: Wave Cannon (10-pellet hitscan shotgun)
	var prim := A.weapon(&"ballast_wave", "Wave Cannon", "Pressure-driven shotgun. 10 pellets of 11 damage (110 up close); falloff from 6 to 16 m. Devastating at point blank, harmless past 20 m.", 1.1, 5, 1.9)
	var hs := A.hitscan(11.0, 32.0)
	hs.pellets = 10
	hs.spread_deg = 8.0; hs.spread_moving_deg = 1.0; hs.spread_airborne_deg = 3.0
	hs.falloff_start = 6.0; hs.falloff_end = 16.0; hs.falloff_min = 0.3
	hs.knockback = 1.2
	hs.headshot = true
	prim.effects = [hs]
	A.pres(prim, &"ballast_wave_fire", &"ballast_wave_tail", &"shell", Color(0.45, 0.95, 0.95))
	prim.presentation.muzzle_vfx = &"ballast_wave_muzzle"
	prim.presentation.impact_vfx = &"impact_generic"
	prim.presentation.sound_impact = &"ballast_wave_impact"
	prim.presentation.crosshair = &"circle"
	prim.presentation.spread_visual_scale = 1.3
	A.feel(prim, 3.4, 0.7, 0.18, 7.0, 0.14, 9.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 18.0, 6.0)
	h.primary = prim
	# --- Secondary: Pressure Slug (tight single slug for poke)
	var sec := A.ability(&"ballast_slug", "Pressure Slug", "Chamber a single slug: 60 hitscan damage with no spread, falling off from 20 to 40 m. Your only answer to ranged poke.", AbilityData.Trigger.PRESS, 3.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	sec.recovery = 0.25
	var slug := A.hitscan(60.0, 60.0)
	slug.falloff_start = 20.0; slug.falloff_end = 40.0; slug.falloff_min = 0.5
	slug.headshot = true
	slug.knockback = 2.0
	sec.effects = [slug]
	A.pres(sec, &"ballast_slug_fire", &"ballast_slug_tail", &"bullet", Color(0.6, 1.0, 0.95))
	sec.presentation.muzzle_vfx = &"muzzle_generic"
	sec.presentation.sound_impact = &"ballast_slug_impact"
	sec.presentation.crosshair = &"dot"
	A.feel(sec, 2.6, 0.3, 0.14, 5.0, 0.1)
	A.ai(sec, AbilityAIHints.Intent.DAMAGE, 8.0, 45.0, 22.0, 0.45)
	h.secondary = sec
	# --- Ability 1: Anchor (★ signature)
	var anchor := A.ability(&"ballast_anchor", "Anchor", "Throw the harpoon-anchor (40 damage). Hit a surface: you are winched to it (press jump to let go). Hit an enemy: they are reeled to your feet and hooked for 0.7 s. Unstoppable enemies cannot be reeled.", AbilityData.Trigger.PRESS, 11.0)
	anchor.behavior = load("res://src/heroes/abilities/BallastAnchorBehavior.gd")
	anchor.active_duration = 2.6
	anchor.cancel_on_cc = true
	anchor.recovery = 0.1
	var hooked := A.status(&"ballast_hooked", "Hooked", 0.7)
	hooked.rooted = true
	hooked.is_debuff = true
	hooked.is_crowd_control = true
	hooked.cleansable = true
	hooked.color = Color(0.3, 0.9, 0.9)
	hooked.tags = [&"displace", &"root"]
	var hook_carrier := ApplyStatusEffect.new()   # carries the status into the data / StatusLibrary
	hook_carrier.status = hooked
	hook_carrier.who = ApplyStatusEffect.Who.TARGET
	hook_carrier.enabled = false
	anchor.effects = [hook_carrier]
	anchor.presentation.sound_fire = &"ballast_anchor_fire"
	anchor.presentation.sound_loop = &"ballast_anchor_loop"
	anchor.presentation.sound_end = &"ballast_anchor_end"
	anchor.presentation.sound_impact = &"ballast_anchor_impact"
	anchor.presentation.muzzle_vfx = &"muzzle_generic"
	anchor.presentation.impact_vfx = &"ballast_anchor_impact"
	anchor.presentation.projectile_vfx = &"harpoon"
	anchor.presentation.anim_tag = &"throw"
	anchor.presentation.crosshair = &"bracket"
	A.feel(anchor, 2.0, 0.2, 0.12, 4.0, 0.1)
	A.ai(anchor, AbilityAIHints.Intent.CROWD_CONTROL, 3.0, 26.0, 10.0, 0.7)
	anchor.ai.needs_line_of_sight = true
	anchor.ai.combo_tags = [&"pull", &"displace"]
	anchor.ai.telegraph_seconds = 0.3
	h.ability_1 = anchor
	# --- Ability 2: Surge (armor while walking slow)
	var surge := A.ability(&"ballast_surge", "Surge", "Over-pressurize the suit for 5 s: +150 armor, but you move at 60% speed. Press it when the poke starts, not when you are already dying.", AbilityData.Trigger.PRESS, 12.0)
	surge.behavior = load("res://src/heroes/abilities/BallastSurgeBehavior.gd")
	surge.active_duration = 5.0
	surge.cancel_on_cc = false
	var surging := A.status(&"ballast_surge", "Surge", 5.0)
	surging.speed_mult = 0.6
	surging.cleansable = false
	surging.color = Color(0.85, 0.65, 0.3)
	surge.self_status_while_active = surging
	surge.presentation.sound_cast = &"ballast_surge_cast"
	surge.presentation.sound_loop = &"ballast_surge_loop"
	surge.presentation.sound_end = &"ballast_surge_end"
	surge.presentation.cast_vfx = &"ballast_surge_cast"
	surge.presentation.loop_vfx = &"ballast_surge_loop"
	surge.presentation.self_glow = Color(0.85, 0.65, 0.3, 1.0)
	surge.presentation.anim_tag = &"cast"
	A.feel(surge, 0.0, 0.0, 0.06, 2.0, 0.08)
	A.ai(surge, AbilityAIHints.Intent.DEFENSIVE, 0.0, 20.0, 8.0, 0.6)
	surge.ai.use_when_health_below = 0.65
	surge.ai.counter_tags = [&"poke"]
	h.ability_2 = surge
	# --- Ultimate: Riptide (3 s channel: pull + slow, then a burst)
	var ult := A.ultimate(&"ballast_riptide", "Riptide", "Open the tide where you aim (within 12 m). For 3 s every enemy within 9 m is dragged toward the center, slowed to 55% and takes 30 damage per second; when it closes, a 120 damage burst throws them upward. Sets up any area ultimate.", 1850.0)
	ult.behavior = load("res://src/heroes/abilities/BallastRiptideBehavior.gd")
	ult.active_duration = 3.0
	ult.tick_interval = 0.2
	ult.cancel_on_cc = true
	ult.blocks_primary_while_active = true
	ult.recovery = 0.3
	var channel := A.status(&"ballast_riptide_channel", "Riptide", 3.0)
	channel.speed_mult = 0.5
	channel.cleansable = false
	channel.color = Color(0.25, 0.74, 0.78)
	ult.self_status_while_active = channel
	var tide_slow := A.status(&"ballast_riptide_slow", "Undertow", 0.6)
	tide_slow.speed_mult = 0.55
	tide_slow.is_debuff = true
	tide_slow.is_crowd_control = true
	tide_slow.cleansable = true
	tide_slow.color = Color(0.3, 0.8, 0.9)
	tide_slow.tags = [&"slow"]
	var tide := AreaEffect.new()
	tide.radius = 9.0
	tide.damage = 6.0
	tide.min_fraction = 0.8
	tide.center_on_point = true
	tide.requires_los = false
	tide.enemy_status = tide_slow
	tide.vfx_id = &"ballast_riptide_ring"
	ult.tick_effects = [tide]
	var burst := AreaEffect.new()
	burst.radius = 9.0
	burst.damage = 120.0
	burst.min_fraction = 0.5
	burst.knockback = 7.0
	burst.center_on_point = true
	burst.requires_los = false
	burst.vfx_id = &"ballast_riptide_explosion"
	ult.end_effects = [burst]
	ult.presentation.sound_cast = &"ballast_riptide_cast"
	ult.presentation.sound_loop = &"ballast_riptide_loop"
	ult.presentation.sound_end = &"ballast_riptide_end"
	ult.presentation.cast_vfx = &"ballast_riptide"
	ult.presentation.loop_vfx = &"ballast_riptide_loop"
	ult.presentation.end_vfx = &"ballast_riptide_end"
	ult.presentation.area_vfx = &"ballast_riptide_ring"
	ult.presentation.voice_line = &"ballast_ult_line"
	ult.presentation.voice_line_enemy = &"ballast_ult_line_enemy"
	ult.presentation.self_glow = Color(0.25, 0.74, 0.78, 1.0)
	ult.presentation.crosshair = &"circle"
	A.feel(ult, 0.0, 0.0, 0.1, 3.0, 0.3)
	A.ai(ult, AbilityAIHints.Intent.CROWD_CONTROL, 0.0, 12.0, 7.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.hold_for_combo = true
	ult.ai.combo_tags = [&"pull", &"group"]
	ult.ai.telegraph_seconds = 0.5
	h.ultimate = ult
	return h
