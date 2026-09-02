extends RefCounted
## WISP — Striker. A cartographer who folds space. ★ Exchange: swap positions with a placed Mark or
## with an enemy you hit with the marked needle. Burst needle rifle, Mark (place / swap), Fold (a
## short blink), ult Displacement folds every nearby enemy behind her. Ultimate disruptor; countered
## by unstoppable heroes and quick burst.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"wisp", "Wisp", RF.Role.STRIKER, 200.0)
	h.codename = "The Cartographer"
	h.sort_order = 14
	h.tagline = "You are exactly where I drew you."
	h.lore = "Wisp mapped the Ring for the Cascadian Charter: eleven thousand pieces of falling city, every orbit re-surveyed by hand. Somewhere in the math of a debris field that never settles she found a way to fold the distance between two points she had marked. She stopped selling the maps. She sells the shortcut now, one needle at a time."
	h.playstyle = "Place a Mark somewhere safe, then go where you should not be. Open with the needle rifle, Exchange an out-of-position enemy into your team (and yourself into theirs), and swap back to the Mark when the trade is done. Displacement is a fight-starter: fold the enemy behind you, into your team's guns."
	h.theme_color = Color(0.62, 0.98, 0.85)
	h.difficulty = 3
	h.unique_mechanic = "Exchange: trade places with your Mark on a second press, or with an enemy hit by the marked needle. Nothing else on the roster moves the enemy AND you at once."
	h.counters = [&"bombard", &"vesper", &"tallow"]
	h.countered_by = [&"kiln", &"rook", &"sable"]
	h.synergies = [&"ferry", &"cadence", &"harrier"]
	# Body
	h.movement = A.movement(5.8, 6.6, 62.0, 0.45)
	h.movement.footstep_interval = 0.38
	h.movement.camera_bob_scale = 0.9
	h.movement.mass = 0.9
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.8
	h.visual.shoulder_width = 0.5
	h.visual.head = HeroVisualData.HeadShape.HOOD
	h.visual.extras = [HeroVisualData.Extra.HALO, HeroVisualData.Extra.CLOAK]
	h.visual.primary_color = Color(0.86, 0.9, 0.9)
	h.visual.secondary_color = Color(0.18, 0.3, 0.32)
	h.visual.accent_color = Color(0.62, 0.98, 0.85)
	h.visual.emissive_color = Color(0.7, 1.0, 0.9)
	h.visual.emissive_strength = 2.2
	h.visual.metallic = 0.2
	h.visual.roughness = 0.65
	# Needle rifle: the long, thin harpoon archetype reads as a needle and keeps the
	# (LIGHT, HOOD, weapon) triple distinct from Vesper's (LIGHT, HOOD, rifle).
	h.visual.weapon_style = &"harpoon"
	h.visual.weapon_scale = 0.85
	h.visual.arms_color = Color(0.2, 0.32, 0.34)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Pale hooded figure with a tilted glowing halo and a short teal cloak, carrying a needle-thin rifle. Vesper is tall, dark and long-rifled; Wisp is pale, haloed and slender."
	h.audio.footstep_set = &"boots_light"
	h.audio.footstep_volume = 0.7
	h.audio.ult_stinger = &"ult_wisp"
	h.audio.ult_stinger_enemy = &"ult_wisp_enemy"
	h.audio.callout_tone = &"radio_b"
	# AI: flanker who dives, opens fights with Displacement.
	h.ai.preferred_range = 14.0; h.ai.min_range = 4.0; h.ai.max_effective_range = 45.0
	h.ai.aggression = 0.65; h.ai.self_preservation = 0.55; h.ai.flanker = true; h.ai.dives = true
	h.ai.prefers_high_ground = 0.5; h.ai.sticks_to_tank = 0.25
	h.ai.ult_style = &"combo_enabler"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"jump"
	h.ai.aim_difficulty_scale = 1.0
	# --- Primary: Needle Rifle (3-round hitscan bursts)
	var prim := A.weapon(&"wisp_needle", "Needle Rifle", "Three-round hitscan bursts: 18 damage per needle (54 per burst), 2.5 bursts per second, headshots double. Full damage to 25 m, 60% by 45 m. 24 needles, 1.4 s reload.", 2.5, 24, 1.4)
	prim.burst_count = 3
	prim.burst_interval = 0.06
	prim.ammo_per_use = 3
	var hs := A.hitscan(18.0, 60.0)
	hs.spread_deg = 0.3; hs.spread_moving_deg = 1.0; hs.spread_airborne_deg = 1.5
	hs.falloff_start = 25.0; hs.falloff_end = 45.0; hs.falloff_min = 0.6
	hs.headshot = true
	prim.effects = [hs]
	A.pres(prim, &"wisp_needle_fire", &"wisp_needle_tail", &"bolt", Color(0.75, 1.0, 0.9))
	prim.presentation.tracer_width = 0.018
	prim.presentation.muzzle_vfx = &"wisp_needle_muzzle"
	prim.presentation.impact_vfx = &"wisp_needle_impact"
	prim.presentation.impact_decal = &"bullet_hole"
	prim.presentation.sound_impact = &"wisp_needle_impact"
	prim.presentation.crosshair = &"dot"
	prim.presentation.anim_tag = &"fire"
	A.feel(prim, 0.8, 0.2, 0.05, 2.2, 0.035, 16.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 50.0, 14.0)
	h.primary = prim
	# --- Secondary: Exchange (marked needle: swap with the enemy it hits)
	var ex := A.ability(&"wisp_exchange", "Exchange", "Fire a marked needle (60 m/s, 20 damage). If it hits an enemy, you and that enemy trade places. Unstoppable enemies refuse the trade. 9 s cooldown.", AbilityData.Trigger.PRESS, 9.0)
	ex.is_weapon = false
	ex.usable_while_silenced = false
	var needle := A.projectile(20.0, 60.0)
	needle.radius = 0.12
	needle.lifetime = 1.5
	needle.visual_id = &"needle"
	needle.headshot = false
	var displaced := A.status(&"wisp_displaced", "Displaced", 1.2)
	displaced.speed_mult = 0.85
	displaced.is_debuff = true
	displaced.cleansable = true
	displaced.color = Color(0.62, 0.98, 0.85)
	displaced.sound_apply = &"wisp_exchange_impact"
	var swap := load("res://src/heroes/abilities/WispSwapEffect.gd").new() as AbilityEffect
	swap.set("status", displaced)
	needle.on_hit_effects = [swap]
	ex.effects = [needle]
	A.pres(ex, &"wisp_exchange_fire", &"wisp_exchange_tail", &"", Color(0.9, 1.0, 0.95))
	ex.presentation.muzzle_vfx = &"wisp_exchange_muzzle"
	ex.presentation.impact_vfx = &"wisp_needle_impact"
	ex.presentation.sound_impact = &"wisp_exchange_impact"
	ex.presentation.sound_end = &"wisp_exchange_end"
	ex.presentation.projectile_vfx = &"needle"
	ex.presentation.crosshair = &"bracket"
	ex.presentation.anim_tag = &"fire"
	A.feel(ex, 1.4, 0.2, 0.08, 3.0, 0.05, 12.0)
	A.ai(ex, AbilityAIHints.Intent.ENGAGE, 3.0, 30.0, 14.0, 0.6)
	ex.ai.combo_tags = [&"displace"]
	h.secondary = ex
	# --- Ability 1: Mark (press: place; press again: exchange places with it)
	var mark := A.ability(&"wisp_mark", "Mark", "Press once to leave a Mark at your feet (lasts 20 s, cannot be destroyed). Press again to Exchange with it: you appear at the Mark and the Mark appears where you stood. 3 s between presses.", AbilityData.Trigger.PRESS, 3.0)
	mark.behavior = load("res://src/heroes/abilities/WispMarkBehavior.gd")
	mark.effects = []
	mark.allow_airborne = true
	mark.presentation.sound_fire = &"wisp_mark_fire"
	mark.presentation.sound_tail = &"wisp_mark_tail"
	mark.presentation.sound_end = &"wisp_mark_end"
	mark.presentation.cast_vfx = &"wisp_mark_cast"
	mark.presentation.anim_tag = &"cast"
	mark.presentation.camera_shake = 0.05
	A.ai(mark, AbilityAIHints.Intent.MOBILITY, 0.0, 30.0, 10.0, 0.5)
	mark.ai.needs_line_of_sight = false
	h.ability_1 = mark
	# --- Ability 2: Fold (short blink)
	var fold := A.ability(&"wisp_fold", "Fold", "Fold 8 m of ground: blink forward along your aim (stops at walls). 7 s cooldown.", AbilityData.Trigger.PRESS, 7.0)
	var blink := TeleportEffect.new()
	blink.distance = 8.0
	blink.flat = true
	blink.keep_velocity = false
	fold.effects = [blink]
	fold.allow_airborne = true
	fold.presentation.sound_fire = &"wisp_fold_fire"
	fold.presentation.sound_tail = &"wisp_fold_tail"
	fold.presentation.cast_vfx = &"wisp_fold_cast"
	fold.presentation.anim_tag = &"cast"
	fold.presentation.camera_shake = 0.06
	A.ai(fold, AbilityAIHints.Intent.ESCAPE, 0.0, 20.0, 8.0, 0.5)
	fold.ai.use_when_health_below = 0.45
	fold.ai.needs_line_of_sight = false
	h.ability_2 = fold
	# --- Ultimate: Displacement (fold every nearby enemy behind you; +100 overhealth)
	var ult := A.ultimate(&"wisp_displacement", "Displacement", "After a 0.5 s fold, every enemy within 10 m you can see is teleported to a random point 8-12 m behind you, and you gain 100 overhealth. Unstoppable enemies are immune. Turn your back to your team and pull the fight into it.", 1900.0)
	ult.cast_time = 0.5
	ult.cancel_on_cc = true
	ult.behavior = load("res://src/heroes/abilities/WispDisplacementBehavior.gd")
	var unfolded := A.status(&"wisp_unfolded", "Unfolded", 6.0)
	unfolded.overhealth_on_apply = 100.0
	unfolded.overhealth_max = 100.0
	unfolded.cleansable = false
	unfolded.color = Color(0.62, 0.98, 0.85)
	var un_fx := ApplyStatusEffect.new()
	un_fx.status = unfolded
	un_fx.who = ApplyStatusEffect.Who.SELF
	ult.effects = [un_fx]
	ult.presentation.sound_cast = &"wisp_displacement_cast"
	ult.presentation.sound_fire = &"wisp_displacement_fire"
	ult.presentation.sound_end = &"wisp_displacement_end"
	ult.presentation.sound_impact = &"wisp_displacement_impact"
	ult.presentation.cast_vfx = &"wisp_displacement_cast"
	ult.presentation.end_vfx = &"wisp_displacement_end"
	ult.presentation.area_vfx = &"wisp_displacement_explosion"
	ult.presentation.voice_line = &"wisp_ult_line"
	ult.presentation.voice_line_enemy = &"wisp_ult_line_enemy"
	ult.presentation.self_glow = Color(0.62, 0.98, 0.85, 1.0)
	ult.presentation.camera_shake = 0.25
	A.ai(ult, AbilityAIHints.Intent.CROWD_CONTROL, 0.0, 10.0, 5.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"displace", &"group"]
	ult.ai.telegraph_seconds = 0.5
	h.ultimate = ult
	return h
