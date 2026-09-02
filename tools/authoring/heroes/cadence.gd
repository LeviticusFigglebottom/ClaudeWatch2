extends RefCounted
## CADENCE — Conduit. Street musician with a bass-cannon. ★ On the beat: her Groove aura pulses a heal
## on every beat (120 bpm), Bassline shells fired on the beat hit 1.5x and heal around their impact,
## and an on-beat shot doubles the next pulse. Tempo support; countered by silence and by splitting
## the team.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"cadence", "Cadence", RF.Role.CONDUIT, 220.0)
	h.codename = "The Bassline"
	h.sort_order = 21
	h.tagline = "Keep time. Keep breathing."
	h.lore = "Cadence busked the transit tunnels of the Pearl River Charter with a sub-woofer bolted to a scavenged pressure cannon, and discovered that a crowd that moves together bleeds less. The Charters call it acoustic field therapy. She calls it a set. Her runner contract has one clause: the cannon stays tuned to 120."
	h.playstyle = "Stand in the middle of your team with the Groove on and let the beat do the healing. Learn the metronome: Bassline shells fired on the beat hit harder, heal around the impact and double the next pulse. Crescendo to reposition the whole team, Discord to open a target, Anthem before the enemy commits."
	h.theme_color = Color(0.95, 0.38, 0.72)
	h.difficulty = 2
	h.unique_mechanic = "On the beat: a 120 bpm clock. Groove heals allies within 9 m for 12 on every beat; Bassline shots fired within 66 ms of a beat deal 1.5x, heal allies within 4 m of the impact for 30, and make the next Groove pulse heal 24."
	h.counters = [&"bombard", &"bramble", &"rook"]
	h.countered_by = [&"coil", &"wisp", &"sable"]
	h.synergies = [&"harrier", &"ballast", &"sable"]
	h.hero_script = load("res://src/heroes/behaviors/CadenceBehavior.gd")
	# Body
	h.movement = A.movement(5.5, 6.4)
	h.movement.footstep_interval = 0.42
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.78
	h.visual.head = HeroVisualData.HeadShape.BARE
	h.visual.extras = [HeroVisualData.Extra.SPEAKERS]
	h.visual.primary_color = Color(0.34, 0.2, 0.46)
	h.visual.secondary_color = Color(0.14, 0.11, 0.2)
	h.visual.accent_color = Color(0.95, 0.4, 0.75)
	h.visual.emissive_color = Color(0.95, 0.35, 0.8)
	h.visual.emissive_strength = 2.2
	h.visual.skin_color = Color(0.55, 0.38, 0.3)
	h.visual.metallic = 0.25
	h.visual.roughness = 0.65
	h.visual.weapon_style = &"cannon"
	h.visual.weapon_scale = 1.15
	h.visual.arms_color = Color(0.3, 0.18, 0.4)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Medium build, bare head with a cropped hair cap, two glowing speaker boxes on the hips and a short fat cannon. Reads as 'sound system' from any angle."
	h.audio.footstep_set = &"boots_medium"
	h.audio.ult_stinger = &"ult_cadence"
	h.audio.ult_stinger_enemy = &"ult_cadence_enemy"
	h.audio.callout_tone = &"radio_b"
	# AI
	h.ai.preferred_range = 12.0; h.ai.min_range = 3.0; h.ai.max_effective_range = 30.0
	h.ai.aggression = 0.35; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 0.4
	h.ai.sticks_to_tank = 0.7; h.ai.heals = true; h.ai.heal_range = 9.0
	h.ai.ult_style = &"save"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.2
	# --- Primary: Bassline (bass-cannon shell; on-beat shots hit 1.5x and heal around the impact)
	var prim := A.weapon(&"cadence_bass", "Bassline", "Bass-cannon. A slow, heavy shell: 45 damage plus 30 splash in 2 m. Shots fired ON THE BEAT (120 bpm) deal 1.5x and heal allies within 4 m of the impact for 30.", 1.5, 6, 1.6)
	var shell := CadenceBassEffect.new()
	shell.damage = 45.0; shell.speed = 30.0; shell.radius = 0.25; shell.lifetime = 3.0
	shell.splash_radius = 2.0; shell.splash_damage = 30.0; shell.splash_min_fraction = 0.4
	shell.knockback = 2.0
	shell.visual_id = &"orb"
	shell.beat_mult = 1.5
	var beat_heal := CadenceBeatHealEffect.new()
	beat_heal.heal = 30.0; beat_heal.radius = 4.0; beat_heal.vfx_id = &"cadence_beat_burst"
	shell.on_hit_effects = [beat_heal]
	prim.effects = [shell]
	A.pres(prim, &"cadence_bass_fire", &"cadence_bass_tail", &"", Color(0.95, 0.45, 0.8))
	prim.presentation.muzzle_vfx = &"cadence_bass_muzzle"
	prim.presentation.impact_vfx = &"cadence_bass_impact"
	prim.presentation.impact_decal = &"scorch"
	prim.presentation.projectile_vfx = &"orb"
	prim.presentation.sound_impact = &"cadence_bass_impact"
	prim.presentation.crosshair = &"circle"
	A.feel(prim, 1.4, 0.4, 0.14, 6.0, 0.10, 9.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 34.0, 14.0)
	prim.ai.telegraph_seconds = 0.3
	h.primary = prim
	# --- Secondary: Groove (toggle aura; heals on every beat)
	var groove := A.ability(&"cadence_groove", "Groove", "Toggle. While the groove is on, every beat (twice a second) heals allies within 9 m for 12 and Cadence for 6. Fire Bassline on the beat and the next pulse heals double.", AbilityData.Trigger.TOGGLE, 0.0)
	groove.behavior = load("res://src/heroes/abilities/CadenceGrooveBehavior.gd")
	var groove_status := A.status(&"cadence_groove", "Groove", 0.6)
	groove_status.cleansable = false
	groove_status.color = Color(0.95, 0.45, 0.8)
	groove.self_status_while_active = groove_status
	groove.presentation.sound_cast = &"cadence_groove_cast"
	groove.presentation.sound_loop = &"cadence_groove_loop"
	groove.presentation.sound_end = &"cadence_groove_end"
	groove.presentation.loop_vfx = &"cadence_aura"
	groove.presentation.self_glow = Color(0.95, 0.4, 0.8, 0.6)
	groove.presentation.anim_tag = &"cast"
	groove.presentation.crosshair = &"dot"
	A.ai(groove, AbilityAIHints.Intent.HEAL, 0.0, 9.0, 6.0, 0.8)
	groove.ai.target_ally = true
	groove.ai.needs_line_of_sight = false
	groove.ai.combo_tags = [&"aura"]
	h.secondary = groove
	# --- Ability 1: Crescendo (team speed pulse)
	var cres := A.ability(&"cadence_crescendo", "Crescendo", "A swelling chord: allies within 10 m (and Cadence) are healed for 20 and move 30% faster for 3 s.", AbilityData.Trigger.PRESS, 10.0)
	var speed := A.status(&"cadence_crescendo", "Crescendo", 3.0)
	speed.speed_mult = 1.3
	speed.cleansable = false
	speed.color = Color(1.0, 0.6, 0.85)
	var chord := AreaEffect.new()
	chord.radius = 10.0; chord.heal = 20.0; chord.heal_self = true; chord.damage = 0.0
	chord.requires_los = false; chord.min_fraction = 0.6
	chord.vfx_id = &"cadence_crescendo"
	var speed_area := ApplyStatusEffect.new()
	speed_area.status = speed
	speed_area.who = ApplyStatusEffect.Who.ALLIES_IN_RADIUS_INCLUDING_SELF
	speed_area.radius = 10.0
	speed_area.requires_los = false
	cres.effects = [chord, speed_area]
	cres.presentation.sound_fire = &"cadence_crescendo_fire"
	cres.presentation.cast_vfx = &"cadence_crescendo_cast"
	cres.presentation.area_vfx = &"cadence_crescendo"
	cres.presentation.anim_tag = &"cast"
	cres.presentation.camera_shake = 0.04
	A.ai(cres, AbilityAIHints.Intent.BUFF_ALLIES, 0.0, 10.0, 6.0, 0.6)
	cres.ai.needs_allies_in_radius = 1
	cres.ai.needs_line_of_sight = false
	cres.ai.combo_tags = [&"speed"]
	h.ability_1 = cres
	# --- Ability 2: Discord (cone damage amp)
	var disc := A.ability(&"cadence_discord", "Discord", "A dissonant blast in a 60 degree cone, 15 m: every enemy caught takes 25% more damage for 4 s.", AbilityData.Trigger.PRESS, 9.0)
	var disc_status := A.status(&"cadence_discord", "Discord", 4.0)
	disc_status.damage_taken_mult = 1.25
	disc_status.is_debuff = true
	disc_status.cleansable = true
	disc_status.color = Color(0.75, 0.2, 0.9)
	var cone := CadenceDiscordEffect.new()
	cone.status = disc_status
	cone.range = 15.0; cone.cone_deg = 60.0
	cone.vfx_id = &"cadence_discord"
	disc.effects = [cone]
	disc.presentation.sound_fire = &"cadence_discord_fire"
	disc.presentation.cast_vfx = &"cadence_discord_cast"
	disc.presentation.anim_tag = &"throw"
	disc.presentation.camera_shake = 0.06
	disc.presentation.camera_kick_pitch = 0.8
	A.ai(disc, AbilityAIHints.Intent.DAMAGE, 0.0, 15.0, 8.0, 0.65)
	disc.ai.needs_enemies_in_radius = 1
	disc.ai.combo_tags = [&"amp"]
	h.ability_2 = disc
	# --- Ultimate: Anthem (cleanse + 300 overhealth to allies in 14 m)
	var ult := A.ultimate(&"cadence_anthem", "Anthem", "The drop. Allies within 14 m (Cadence included) are cleansed, healed for 60 and given 300 overhealth. Overhealth decays 2 s after the last hit.", 1900.0)
	var cleanse := CleanseEffect.new()
	cleanse.who = CleanseEffect.Who.ALLIES_IN_RADIUS
	cleanse.radius = 14.0
	cleanse.include_self = true
	var oh := HealEffect.new()
	oh.who = HealEffect.Who.ALLIES_IN_RADIUS
	oh.radius = 14.0; oh.include_self = true
	oh.amount = 60.0; oh.overhealth = 300.0; oh.overhealth_cap = 300.0
	var ring := AreaEffect.new()
	ring.radius = 14.0; ring.heal = 0.0; ring.damage = 0.0; ring.requires_los = false
	ring.vfx_id = &"cadence_anthem_ring"
	ult.effects = [cleanse, oh, ring]
	ult.presentation.sound_cast = &"cadence_anthem_cast"
	ult.presentation.sound_fire = &"cadence_anthem_fire"
	ult.presentation.cast_vfx = &"cadence_anthem_cast"
	ult.presentation.voice_line = &"cadence_ult_line"
	ult.presentation.voice_line_enemy = &"cadence_ult_line_enemy"
	ult.presentation.camera_shake = 0.2
	ult.presentation.self_glow = Color(1.0, 0.5, 0.9, 1.0)
	A.ai(ult, AbilityAIHints.Intent.DEFENSIVE, 0.0, 14.0, 8.0, 0.7)
	ult.ai.needs_allies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"overhealth", &"cleanse"]
	ult.ai.counter_tags = [&"cleanse"]
	h.ultimate = ult
	return h
