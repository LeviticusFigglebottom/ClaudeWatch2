extends RefCounted
## COIL — Striker. Arc-welder turned duelist. ★ Chain: her gauntlet's lightning jumps between enemies
## within 6 m (up to 3 targets, 100% / 70% / 50%). Tesla Node is a zapping pylon the chain relays
## through, Capacitor absorbs 1.5 s of damage and releases it as a burst, Blackout silences and slows
## every enemy in 14 m for 3 s. Counters grouped teams; countered by barriers and cleanse.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"coil", "Coil", RF.Role.STRIKER, 225.0)
	h.codename = "The Welder"
	h.sort_order = 13
	h.tagline = "Stand together. Please."
	h.lore = "Coil welded hull plate in the Nightmarket towers, the neon stacks where the Pearl River Charter grows upward because it cannot grow out. Her gauntlet is a plasma welder with the safety filed off; the Tesla nodes are the same cheap lamp-posts she used to fix. She took the Runner contract for the money and stayed because nobody else on a drop site knew how the grid worked."
	h.playstyle = "Find the clump. Every shot on one target arcs to two more within 6 m, so aim at whoever is standing closest to the others. Drop a Tesla Node where the enemy has to pass and chain through it, pop Capacitor when the whole team turns on you and hand it back as a burst, and save Blackout for the moment the enemy commits to an ultimate."
	h.theme_color = Color(0.62, 0.42, 1.0)
	h.difficulty = 2
	h.unique_mechanic = "Chain: lightning from the gauntlet jumps from the enemy you hit to up to two more enemies within 6 m (70% then 50% damage). Friendly Tesla Nodes act as relays the chain can pass through."
	h.counters = [&"cathedral", &"cadence", &"suture"]
	h.countered_by = [&"cathedral", &"tallow", &"suture"]
	h.synergies = [&"rook", &"ballast", &"vesper"]
	h.hero_script = load("res://src/heroes/behaviors/CoilBehavior.gd")
	# Body
	h.movement = A.movement(5.6, 6.4, 60.0, 0.35)
	h.movement.footstep_interval = 0.42
	h.movement.mass = 1.05
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.84
	h.visual.shoulder_width = 0.58
	h.visual.head = HeroVisualData.HeadShape.ANTENNA
	h.visual.extras = [HeroVisualData.Extra.SHOULDER_PADS, HeroVisualData.Extra.TANK_CANISTERS]
	h.visual.primary_color = Color(0.2, 0.18, 0.26)
	h.visual.secondary_color = Color(0.85, 0.55, 0.2)
	h.visual.accent_color = Color(0.62, 0.42, 1.0)
	h.visual.emissive_color = Color(0.7, 0.5, 1.0)
	h.visual.emissive_strength = 2.4
	h.visual.metallic = 0.5
	h.visual.roughness = 0.5
	h.visual.weapon_style = &"gauntlet"
	h.visual.weapon_scale = 1.35
	h.visual.arms_color = Color(0.85, 0.55, 0.2)
	h.visual.stance = &"brace"
	h.visual.silhouette_notes = "Boxy welder's helmet with one antenna, canisters on the back, one oversized gauntlet on the right arm glowing violet. Orange safety-jacket sleeves. Reads as 'industrial' next to the cloaked and winged strikers."
	h.audio.footstep_set = &"boots_medium"
	h.audio.ult_stinger = &"ult_coil"
	h.audio.ult_stinger_enemy = &"ult_coil_enemy"
	h.audio.callout_tone = &"radio_a"
	# AI: mid aggression, plays with the tank, builds nodes, holds Blackout as a counter.
	h.ai.preferred_range = 11.0; h.ai.min_range = 2.0; h.ai.max_effective_range = 25.0
	h.ai.aggression = 0.5; h.ai.self_preservation = 0.5; h.ai.prefers_high_ground = 0.4
	h.ai.sticks_to_tank = 0.65; h.ai.builds = true
	h.ai.ult_style = &"counter"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.0
	# --- Primary: Arc Gauntlet (hitscan 30 + chain 70% / 50%)
	var prim := A.weapon(&"coil_chain", "Arc Gauntlet", "Hitscan lightning: 25 damage, 4 shots per second, 25 m range, no falloff. Each hit chains to up to two more enemies within 6 m of the target for 17 and 12 damage. 12 cells, 1.4 s recharge.", 4.0, 12, 1.4)
	# 25, not 30. Coil posted 17584 dmg/10m in balance pass 5 against 13600 for the next hero, on a
	# 64% win rate and the highest K/D in the game over 42 picks. Cutting the chain to a single jump
	# was tried first and moved damage by 3%: three enemies rarely sit inside the 6 m chain radius,
	# so the outlier was never the spread. It is the base weapon — 30 damage four times a second,
	# hitscan, no falloff to 25 m, and it headshots — so that is what moves, and the chain follows it
	# down proportionally. The kit keeps both jumps.
	var hs := A.hitscan(25.0, 25.0)
	hs.spread_deg = 0.5; hs.spread_moving_deg = 0.6; hs.spread_airborne_deg = 1.5
	hs.falloff_start = 25.0; hs.falloff_end = 25.0; hs.falloff_min = 1.0
	hs.headshot = true
	var chain := load("res://src/heroes/abilities/CoilChainEffect.gd").new() as AbilityEffect
	chain.set("radius", 6.0)
	chain.set("max_jumps", 2)
	chain.set("base_damage", 25.0)
	prim.effects = [hs, chain]
	A.pres(prim, &"coil_chain_fire", &"coil_chain_tail", &"arc", Color(0.75, 0.6, 1.0))
	prim.presentation.tracer_width = 0.035
	prim.presentation.muzzle_vfx = &"coil_chain_muzzle"
	prim.presentation.impact_vfx = &"coil_chain_impact"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.sound_impact = &"coil_chain_impact"
	prim.presentation.crosshair = &"dot"
	prim.presentation.anim_tag = &"fire"
	A.feel(prim, 1.0, 0.3, 0.05, 2.0, 0.05, 14.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 25.0, 10.0)
	h.primary = prim
	# --- Secondary: Arc Lance (long-range 70 damage bolt that also chains; big slow kick)
	var lance := A.ability(&"coil_lance", "Arc Lance", "Overcharge the gauntlet into a 40 m hitscan bolt: 70 damage, headshots double, then chains to two more enemies within 8 m for 49 and 35. 7 s cooldown.", AbilityData.Trigger.PRESS, 7.0)
	lance.is_weapon = true
	lance.usable_while_silenced = true
	var lhs := A.hitscan(70.0, 40.0)
	lhs.spread_deg = 0.0; lhs.spread_moving_deg = 0.4
	lhs.falloff_start = 40.0; lhs.falloff_end = 40.0; lhs.falloff_min = 1.0
	lhs.headshot = true
	lhs.knockback = 3.0
	var lchain := load("res://src/heroes/abilities/CoilChainEffect.gd").new() as AbilityEffect
	lchain.set("radius", 8.0)
	lchain.set("max_jumps", 2)
	lchain.set("base_damage", 70.0)
	lance.effects = [lhs, lchain]
	A.pres(lance, &"coil_lance_fire", &"coil_lance_tail", &"bolt", Color(0.9, 0.8, 1.0))
	lance.presentation.tracer_width = 0.06
	lance.presentation.muzzle_vfx = &"coil_lance_muzzle"
	lance.presentation.impact_vfx = &"coil_chain_impact"
	lance.presentation.impact_decal = &"scorch"
	lance.presentation.sound_impact = &"coil_lance_impact"
	lance.presentation.crosshair = &"dot"
	lance.presentation.anim_tag = &"fire"
	A.feel(lance, 2.6, 0.4, 0.14, 5.5, 0.14, 8.0)
	A.ai(lance, AbilityAIHints.Intent.DAMAGE, 6.0, 40.0, 10.0, 0.6)
	h.secondary = lance
	# --- Ability 1: Tesla Node (150 hp pylon, 12 s, zaps nearest enemy in 7 m every 0.8 s for 20)
	var node := A.ability(&"coil_tesla_node", "Tesla Node", "Plant a 150 hp pylon (12 s) where you aim, up to 12 m away. Every 0.8 s it zaps the nearest enemy within 7 m for 20 damage, and your Chain can jump through it. 12 s cooldown.", AbilityData.Trigger.PRESS, 12.0)
	var dep := DeployEffect.new()
	dep.kind = &"tesla_node"
	dep.visual_id = &"coil_tesla_node"
	dep.placement = DeployEffect.Placement.AIMED_GROUND
	dep.max_range = 12.0
	dep.health = 150.0
	dep.lifetime = 12.0
	dep.max_instances = 1
	dep.deployable_script = load("res://src/heroes/deployables/CoilTeslaNode.gd")
	dep.params = {"interval": 0.8, "damage": 20.0, "radius": 7.0}
	node.effects = [dep]
	node.presentation.sound_fire = &"coil_tesla_node_fire"
	node.presentation.sound_cast = &"coil_tesla_node_cast"
	node.presentation.sound_loop = &"coil_tesla_node_loop"
	node.presentation.sound_end = &"coil_tesla_node_end"
	node.presentation.cast_vfx = &"coil_tesla_node_cast"
	node.presentation.area_vfx = &"coil_chain_explosion"
	node.presentation.anim_tag = &"throw"
	A.ai(node, AbilityAIHints.Intent.DAMAGE, 0.0, 12.0, 6.0, 0.55)
	node.ai.target_ground = true
	node.ai.combo_tags = [&"zone"]
	h.ability_1 = node
	# --- Ability 2: Capacitor (absorb 1.5 s of damage, release min(stored, 250) in 5 m)
	var cap := A.ability(&"coil_capacitor", "Capacitor", "For 1.5 s every hit you take is absorbed instead of dealt. When it ends you release the stored damage (up to 250) as a burst in 5 m with knockback. Nothing stored, nothing released. 11 s cooldown.", AbilityData.Trigger.PRESS, 11.0)
	cap.behavior = load("res://src/heroes/abilities/CoilCapacitorBehavior.gd")
	cap.active_duration = 1.5
	cap.cooldown_starts_on_end = true
	cap.allow_airborne = true
	var cap_st := A.status(&"coil_capacitor_status", "Capacitor", 1.5)
	cap_st.cleansable = false
	cap_st.color = Color(0.7, 0.5, 1.0)
	cap_st.vfx_id = &"coil_capacitor_loop"
	cap.self_status_while_active = cap_st
	cap.presentation.sound_cast = &"coil_capacitor_cast"
	cap.presentation.sound_loop = &"coil_capacitor_loop"
	cap.presentation.sound_end = &"coil_capacitor_end"
	cap.presentation.cast_vfx = &"coil_capacitor_cast"
	cap.presentation.loop_vfx = &"coil_capacitor_loop"
	cap.presentation.end_vfx = &"coil_capacitor_end"
	cap.presentation.area_vfx = &"coil_capacitor_explosion"
	cap.presentation.anim_tag = &"cast"
	cap.presentation.self_glow = Color(0.7, 0.5, 1.0, 0.9)
	cap.presentation.camera_shake = 0.12
	A.ai(cap, AbilityAIHints.Intent.DEFENSIVE, 0.0, 12.0, 4.0, 0.6)
	cap.ai.use_when_health_below = 0.65
	cap.ai.needs_line_of_sight = false
	cap.ai.combo_tags = [&"aoe_damage"]
	h.ability_2 = cap
	# --- Ultimate: Blackout (silence + slow all enemies in 14 m for 3 s, 80 damage)
	var ult := A.ultimate(&"coil_blackout", "Blackout", "After a 0.4 s wind-up, every enemy within 14 m you can see takes 80 damage and is SILENCED and slowed to 70% speed for 3 s. Weapons still work. The answer to an enemy ultimate.", 1800.0)
	ult.cast_time = 0.4
	ult.cancel_on_cc = true
	var bo := A.status(&"coil_blackout_status", "Blackout", 3.0)
	bo.silenced = true
	bo.speed_mult = 0.7
	bo.is_debuff = true
	bo.is_crowd_control = true
	bo.cleansable = true
	bo.color = Color(0.35, 0.2, 0.6)
	bo.vfx_id = &"coil_blackout_loop"
	bo.sound_apply = &"coil_blackout_impact"
	var bo_fx := ApplyStatusEffect.new()
	bo_fx.status = bo
	bo_fx.who = ApplyStatusEffect.Who.ENEMIES_IN_RADIUS
	bo_fx.radius = 14.0
	bo_fx.requires_los = true
	var bo_dmg := AreaEffect.new()
	bo_dmg.radius = 14.0
	bo_dmg.damage = 80.0
	bo_dmg.min_fraction = 0.8
	bo_dmg.requires_los = true
	bo_dmg.damage_type = RF.DamageType.BEAM
	bo_dmg.vfx_id = &"coil_blackout_explosion"
	ult.effects = [bo_dmg, bo_fx]
	ult.presentation.sound_cast = &"coil_blackout_cast"
	ult.presentation.sound_fire = &"coil_blackout_fire"
	ult.presentation.sound_end = &"coil_blackout_end"
	ult.presentation.sound_impact = &"coil_blackout_impact"
	ult.presentation.cast_vfx = &"coil_blackout_cast"
	ult.presentation.end_vfx = &"coil_blackout_end"
	ult.presentation.area_vfx = &"coil_blackout_explosion"
	ult.presentation.voice_line = &"coil_ult_line"
	ult.presentation.voice_line_enemy = &"coil_ult_line_enemy"
	ult.presentation.self_glow = Color(0.4, 0.2, 0.8, 1.0)
	ult.presentation.camera_shake = 0.35
	A.ai(ult, AbilityAIHints.Intent.CROWD_CONTROL, 0.0, 14.0, 8.0, 0.7)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.hold_for_combo = true
	ult.ai.combo_tags = [&"silence", &"slow", &"cc"]
	ult.ai.counter_tags = [&"engage"]
	ult.ai.telegraph_seconds = 0.4
	h.ultimate = ult
	return h
