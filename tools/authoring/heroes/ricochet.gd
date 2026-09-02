extends RefCounted
## RICOCHET — Striker. Trick-shot artist with a disc launcher. ★ Discs pass through enemies until
## they have bounced off geometry once; every bounce adds damage (45 / 70 / 95, three bounces max).
## Bank Shot makes the next disc home after its first bounce, Skip dashes away leaving a bouncing
## disc behind, Pinball fills the area with discs for 6 s. Rewards geometry; countered by open ground.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"ricochet", "Ricochet", RF.Role.STRIKER, 225.0)
	h.codename = "The Trick Shot"
	h.sort_order = 12
	h.tagline = "The wall is on my side."
	h.lore = "Ricochet learned angles in the pit-arenas under Aurelia Bazaar, where the crowd only paid for shots that came from somewhere impossible. The launcher was a prize; the discs he cuts himself from Ring alloy that never dulls. He does not aim at people. He aims at the world and lets it deliver."
	h.playstyle = "Never shoot straight at anyone. Skip discs off floors, walls and ceilings so they arrive armed; fight in corridors and rooms where every surface is a friend. Bank Shot when you cannot find the angle, Skip to break contact and leave a trap, and Pinball inside a room to make the whole room lethal."
	h.theme_color = Color(0.95, 0.4, 0.75)
	h.difficulty = 3
	h.unique_mechanic = "Discs only damage after bouncing at least once: a fresh disc flies straight through enemies. Each bounce arms it harder, 45 -> 70 -> 95 damage, up to three bounces."
	h.counters = [&"cathedral", &"kiln", &"cairn"]
	h.countered_by = [&"vesper", &"bombard", &"harrier"]
	h.synergies = [&"cairn", &"coil", &"rook"]
	# Body
	h.movement = A.movement(5.7, 6.6, 60.0, 0.4)
	h.movement.footstep_interval = 0.4
	h.movement.camera_bob_scale = 1.1
	h.visual.build = HeroVisualData.Build.MEDIUM
	h.visual.height = 1.86
	h.visual.shoulder_width = 0.56
	h.visual.head = HeroVisualData.HeadShape.BEAKED
	h.visual.extras = [HeroVisualData.Extra.SHOULDER_PADS, HeroVisualData.Extra.BACKPACK]
	h.visual.primary_color = Color(0.16, 0.14, 0.2)
	h.visual.secondary_color = Color(0.62, 0.58, 0.55)
	h.visual.accent_color = Color(0.95, 0.4, 0.75)
	h.visual.emissive_color = Color(1.0, 0.45, 0.8)
	h.visual.emissive_strength = 2.2
	h.visual.metallic = 0.35
	h.visual.roughness = 0.55
	h.visual.weapon_style = &"launcher"
	h.visual.weapon_scale = 1.2
	h.visual.arms_color = Color(0.5, 0.46, 0.44)
	h.visual.stance = &"upright"
	h.visual.silhouette_notes = "Beaked mask, padded shoulders, a fat drum-fed disc launcher held low. Magenta disc-glow on the drum. Reads as 'the one with the weird gun' from across a room."
	h.audio.footstep_set = &"boots_medium"
	h.audio.ult_stinger = &"ult_ricochet"
	h.audio.ult_stinger_enemy = &"ult_ricochet_enemy"
	h.audio.callout_tone = &"radio_c"
	# AI: he wants walls close by, not high ground; short preferred range so bank shots are likely.
	h.ai.preferred_range = 9.0; h.ai.min_range = 3.0; h.ai.max_effective_range = 22.0
	h.ai.aggression = 0.55; h.ai.self_preservation = 0.5; h.ai.prefers_high_ground = 0.15
	h.ai.sticks_to_tank = 0.5; h.ai.flanker = false
	h.ai.ult_style = &"zone"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"weave"
	h.ai.aim_difficulty_scale = 1.25
	# --- Primary: Disc Launcher (behavior-driven projectile: arms on bounce)
	var prim := A.weapon(&"ricochet_disc", "Disc Launcher", "Launch a disc at 45 m/s. It passes through enemies until it bounces; after 1 / 2 / 3 bounces it deals 45 / 70 / 95 damage. 1.6 discs per second, 5 per clip, 1.5 s reload.", 1.6, 5, 1.5)
	prim.behavior = load("res://src/heroes/abilities/RicochetDiscBehavior.gd")
	prim.effects = []
	A.pres(prim, &"ricochet_disc_fire", &"ricochet_disc_tail", &"", Color(1.0, 0.5, 0.85))
	prim.presentation.muzzle_vfx = &"ricochet_disc_muzzle"
	prim.presentation.impact_vfx = &"ricochet_disc_impact"
	prim.presentation.impact_decal = &"bullet_hole"
	prim.presentation.sound_impact = &"ricochet_disc_impact"
	prim.presentation.projectile_vfx = &"disc"
	prim.presentation.crosshair = &"bracket"
	prim.presentation.anim_tag = &"fire"
	A.feel(prim, 1.3, 0.35, 0.08, 3.0, 0.05, 10.0)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 28.0, 9.0)
	h.primary = prim
	# --- Secondary: Lob (arcing heavy disc; lands behind cover and bounces up)
	var lob := A.ability(&"ricochet_lob", "Lob", "Throw a heavy disc in an arc (28 m/s, drops fast). It arms on its first bounce like any disc but hits harder: 55 / 80 / 105 damage. Arcs over barriers. 5 s cooldown.", AbilityData.Trigger.PRESS, 5.0)
	lob.is_weapon = true
	lob.usable_while_silenced = true
	lob.behavior = load("res://src/heroes/abilities/RicochetDiscBehavior.gd")
	lob.effects = []
	A.pres(lob, &"ricochet_lob_fire", &"ricochet_lob_tail", &"", Color(1.0, 0.35, 0.7))
	lob.presentation.muzzle_vfx = &"ricochet_lob_muzzle"
	lob.presentation.impact_vfx = &"ricochet_disc_impact"
	lob.presentation.sound_impact = &"ricochet_lob_impact"
	lob.presentation.projectile_vfx = &"disc"
	lob.presentation.crosshair = &"circle"
	lob.presentation.anim_tag = &"throw"
	A.feel(lob, 2.2, 0.4, 0.14, 6.0, 0.08, 7.0)
	A.ai(lob, AbilityAIHints.Intent.DAMAGE, 4.0, 30.0, 9.0, 0.5)
	lob.ai.needs_line_of_sight = false
	h.secondary = lob
	# --- Ability 1: Bank Shot (primes the next disc to home after its first bounce)
	var bank := A.ability(&"ricochet_bank_shot", "Bank Shot", "Prime your launcher for 6 s: the next disc you fire locks onto the nearest enemy it can see after its first bounce and curves into them. 8 s cooldown.", AbilityData.Trigger.PRESS, 8.0)
	var primed := A.status(&"ricochet_bank_primed", "Bank Shot", 6.0)
	primed.cleansable = false
	primed.color = Color(1.0, 0.45, 0.8)
	primed.vfx_id = &"ricochet_bank_shot_loop"
	primed.stacking = StatusData.Stacking.REFRESH
	var prime_fx := ApplyStatusEffect.new()
	prime_fx.status = primed
	prime_fx.who = ApplyStatusEffect.Who.SELF
	bank.effects = [prime_fx]
	bank.presentation.sound_cast = &"ricochet_bank_shot_cast"
	bank.presentation.sound_end = &"ricochet_bank_shot_end"
	bank.presentation.cast_vfx = &"ricochet_bank_shot_cast"
	bank.presentation.anim_tag = &"cast"
	bank.presentation.self_glow = Color(1.0, 0.45, 0.8, 0.7)
	A.ai(bank, AbilityAIHints.Intent.DAMAGE, 0.0, 26.0, 10.0, 0.6)
	bank.ai.needs_line_of_sight = false
	h.ability_1 = bank
	# --- Ability 2: Skip (short dash; leaves a bouncing disc where you were)
	var skip := A.ability(&"ricochet_skip", "Skip", "Dash 14 m/s in your movement direction and leave a disc bouncing on the spot you left for 4 s. It arms on its first bounce (40 / 55 / 70 damage) and hits the first enemy who walks into it. 7 s cooldown.", AbilityData.Trigger.PRESS, 7.0)
	skip.behavior = load("res://src/heroes/abilities/RicochetSkipBehavior.gd")
	var dash := DashEffect.new()
	dash.speed = 14.0
	dash.direction = DashEffect.Dir.MOVE_OR_FORWARD
	dash.vertical_boost = 3.5
	dash.preserve_momentum = 0.2
	skip.effects = [dash]
	skip.allow_airborne = true
	skip.presentation.sound_fire = &"ricochet_skip_fire"
	skip.presentation.sound_tail = &"ricochet_skip_tail"
	skip.presentation.cast_vfx = &"ricochet_skip_cast"
	skip.presentation.projectile_vfx = &"disc"
	skip.presentation.anim_tag = &"cast"
	skip.presentation.camera_shake = 0.1
	A.ai(skip, AbilityAIHints.Intent.ESCAPE, 0.0, 12.0, 4.0, 0.55)
	skip.ai.use_when_health_below = 0.5
	skip.ai.needs_line_of_sight = false
	h.ability_2 = skip
	# --- Ultimate: Pinball (6 s of discs in every direction)
	var ult := A.ultimate(&"ricochet_pinball", "Pinball", "For 6 s a disc leaves you every 0.3 s in a random direction. Each bounces up to 6 times and arms like any disc (45 / 70 / 95). Inside a room, the room becomes the weapon. You keep your launcher.", 1800.0)
	ult.active_duration = 6.0
	ult.behavior = load("res://src/heroes/abilities/RicochetPinballBehavior.gd")
	ult.cancel_on_cc = false
	ult.allow_airborne = true
	var pin_st := A.status(&"ricochet_pinball_status", "Pinball", 6.0)
	pin_st.cleansable = false
	pin_st.color = Color(1.0, 0.45, 0.8)
	ult.self_status_while_active = pin_st
	ult.presentation.sound_cast = &"ricochet_pinball_cast"
	ult.presentation.sound_loop = &"ricochet_pinball_loop"
	ult.presentation.sound_end = &"ricochet_pinball_end"
	ult.presentation.sound_fire = &"ricochet_pinball_fire"
	ult.presentation.sound_impact = &"ricochet_pinball_impact"
	ult.presentation.cast_vfx = &"ricochet_pinball_cast"
	ult.presentation.loop_vfx = &"ricochet_pinball_loop"
	ult.presentation.end_vfx = &"ricochet_pinball_end"
	ult.presentation.projectile_vfx = &"disc"
	ult.presentation.voice_line = &"ricochet_ult_line"
	ult.presentation.voice_line_enemy = &"ricochet_ult_line_enemy"
	ult.presentation.self_glow = Color(1.0, 0.45, 0.8, 1.0)
	ult.presentation.camera_shake = 0.15
	A.ai(ult, AbilityAIHints.Intent.ZONE, 0.0, 12.0, 6.0, 0.65)
	ult.ai.needs_enemies_in_radius = 2
	ult.ai.needs_line_of_sight = false
	ult.ai.combo_tags = [&"aoe_damage"]
	h.ultimate = ult
	return h
