extends RefCounted
## VESPER — Striker. Long-range hitscan marksman whose Lantern reveals enemies through walls for the
## whole team. Signature: information. Counters flankers; countered by dive and shields.


static func build() -> HeroData:
	var A := HeroAuthor
	var h := A.hero(&"vesper", "Vesper", RF.Role.STRIKER, 200.0)
	h.codename = "The Lamplighter"
	h.sort_order = 10
	h.tagline = "Light finds everyone."
	h.lore = "Vesper ran salvage routes on the dark side of the Ring for eleven years, navigating by the glow of lantern buoys she planted herself. When the Charters started paying for Cores, she brought the lanterns down with her. Her rifle is a converted surveying laser; her calm is not an act."
	h.playstyle = "Hold long sightlines, tag targets with the Lantern so your team can see them coming, and punish anyone who peeks. You are weakest up close: keep the zipline for escapes."
	h.theme_color = Color(0.98, 0.78, 0.35)
	h.difficulty = 2
	h.unique_mechanic = "Lantern: throws a lamp that REVEALS all enemies in a 12 m radius through walls for 6 s to your entire team."
	h.counters = [&"sable", &"harrier", &"wisp"]
	h.countered_by = [&"cathedral", &"ballast", &"rook"]
	h.synergies = [&"bombard", &"coil", &"lumen"]
	# Body
	h.movement = A.movement(5.5, 6.4)
	h.movement.footstep_interval = 0.4
	h.visual.build = HeroVisualData.Build.LIGHT
	h.visual.height = 1.82
	h.visual.head = HeroVisualData.HeadShape.HOOD
	h.visual.extras = [HeroVisualData.Extra.CLOAK, HeroVisualData.Extra.BACKPACK]
	h.visual.primary_color = Color(0.32, 0.28, 0.26)
	h.visual.secondary_color = Color(0.16, 0.15, 0.17)
	h.visual.accent_color = Color(0.98, 0.78, 0.35)
	h.visual.emissive_color = Color(1.0, 0.75, 0.3)
	h.visual.emissive_strength = 2.0
	h.visual.weapon_style = &"rifle"
	h.visual.weapon_scale = 1.15
	h.visual.arms_color = Color(0.28, 0.25, 0.24)
	h.visual.silhouette_notes = "Tall and narrow: hood, long cloak, long rifle. Reads as a sniper at any distance."
	h.audio.footstep_set = &"boots_light"
	h.audio.ult_stinger = &"ult_vesper"
	h.audio.ult_stinger_enemy = &"ult_vesper_enemy"
	# AI
	h.ai.preferred_range = 26.0; h.ai.min_range = 10.0; h.ai.max_effective_range = 70.0
	h.ai.aggression = 0.3; h.ai.self_preservation = 0.7; h.ai.prefers_high_ground = 0.9; h.ai.poke_style = true
	h.ai.ult_style = &"combo_enabler"; h.ai.ult_min_targets = 2; h.ai.strafe_style = &"crouch"
	# --- Primary: Surveyor Rifle (semi-auto hitscan, headshots, falloff)
	var prim := A.weapon(&"vesper_rifle", "Surveyor Rifle", "Semi-automatic hitscan rifle. 55 damage, headshots deal double. Falloff beyond 35 m.", 2.4, 8, 1.4)
	var hs := A.hitscan(55.0, 150.0)
	hs.spread_deg = 0.0; hs.spread_moving_deg = 0.9; hs.spread_airborne_deg = 2.5
	hs.falloff_start = 35.0; hs.falloff_end = 60.0; hs.falloff_min = 0.5
	prim.effects = [hs]
	A.pres(prim, &"vesper_fire", &"vesper_tail", &"bullet", Color(1.0, 0.85, 0.5))
	prim.presentation.muzzle_vfx = &"muzzle_generic"
	prim.presentation.crosshair = &"dot"
	A.feel(prim, 1.6, 0.35, 0.09, 4.0, 0.06)
	A.ai(prim, AbilityAIHints.Intent.DAMAGE, 0.0, 80.0, 28.0)
	h.primary = prim
	# --- Secondary: Focus (hold to steady: no spread, +damage after 0.8 s charge, slower)
	var sec := A.ability(&"vesper_focus", "Focus", "Hold to steady your aim: movement slows to 60% and the next rifle shot within the window deals 85 damage.", AbilityData.Trigger.CHANNEL, 0.0)
	sec.is_weapon = true
	sec.usable_while_silenced = true
	var focus_status := A.status(&"vesper_focused", "Focused", 0.5)
	focus_status.speed_mult = 0.6
	focus_status.damage_dealt_mult = 1.55
	focus_status.color = Color(1, 0.8, 0.4)
	focus_status.cleansable = false
	sec.self_status_while_active = focus_status
	sec.presentation.sound_cast = &"vesper_focus_on"
	sec.presentation.sound_end = &"vesper_focus_off"
	sec.presentation.crosshair = &"circle"
	A.ai(sec, AbilityAIHints.Intent.DAMAGE, 20.0, 80.0, 40.0, 0.3)
	sec.ai.spam_ok = true
	h.secondary = sec
	# --- Ability 1: Lantern (thrown projectile that reveals on impact)
	var lantern := A.ability(&"vesper_lantern", "Lantern", "Throw a lantern. Where it lands it lights a 12 m radius for 6 s: enemies inside are revealed to your whole team through walls.", AbilityData.Trigger.PRESS, 12.0)
	var lp := A.projectile(0.0, 22.0)
	lp.gravity = 14.0; lp.radius = 0.2; lp.lifetime = 3.0; lp.visual_id = &"candle"
	var reveal := A.status(&"revealed_lantern", "Revealed", 6.0)
	reveal.revealed = true; reveal.is_debuff = true; reveal.cleansable = true
	reveal.color = Color(1.0, 0.8, 0.3)
	var reveal_area := ApplyStatusEffect.new()
	reveal_area.status = reveal
	reveal_area.who = ApplyStatusEffect.Who.ENEMIES_IN_RADIUS
	reveal_area.radius = 12.0
	reveal_area.center_on_point = true
	reveal_area.requires_los = false
	var lantern_zone := DeployEffect.new()
	lantern_zone.kind = &"lantern"
	lantern_zone.visual_id = &"candle"
	lantern_zone.placement = DeployEffect.Placement.AT_FEET
	lantern_zone.lifetime = 6.0
	lantern_zone.deployable_script = load("res://src/heroes/deployables/LanternDeployable.gd")
	lantern_zone.params = {"radius": 12.0, "status": &"revealed_lantern"}
	lp.on_hit_effects = [lantern_zone]
	lantern.effects = [lp]
	lantern.presentation.sound_fire = &"vesper_lantern_throw"
	lantern.presentation.anim_tag = &"throw"
	lantern.presentation.area_vfx = &"lantern_light"
	A.ai(lantern, AbilityAIHints.Intent.REVEAL, 6.0, 30.0, 18.0, 0.55)
	lantern.ai.needs_line_of_sight = false
	lantern.ai.target_ground = true
	h.ability_1 = lantern
	# --- Ability 2: Zipline (deploys a line; hold interact to ride) -> implemented as a fast dash toward aim with hover
	var zip := A.ability(&"vesper_zipline", "Zipline", "Fire an anchor line to a surface and ride it. Mobility for reaching perches or escaping dives.", AbilityData.Trigger.PRESS, 10.0)
	zip.behavior = load("res://src/heroes/abilities/ZiplineBehavior.gd")
	zip.active_duration = 2.5
	zip.cancel_on_cc = true
	zip.presentation.sound_cast = &"vesper_zip_fire"
	zip.presentation.sound_loop = &"vesper_zip_loop"
	zip.presentation.sound_end = &"vesper_zip_end"
	zip.presentation.anim_tag = &"cast"
	A.ai(zip, AbilityAIHints.Intent.MOBILITY, 8.0, 40.0, 20.0, 0.4)
	zip.ai.use_when_health_below = 0.45
	h.ability_2 = zip
	# --- Ultimate: Long Night (8 s: infinite ammo, no falloff, reveal everyone you damage)
	var ult := A.ultimate(&"vesper_long_night", "Long Night", "For 8 s: no reload, no falloff, and every enemy you hit is revealed to your team for 4 s.", 1650.0)
	ult.active_duration = 8.0
	var night := A.status(&"vesper_long_night_status", "Long Night", 8.0)
	night.cleansable = false
	night.color = Color(0.9, 0.7, 0.3)
	night.cooldown_rate_mult = 1.5
	ult.self_status_while_active = night
	ult.behavior = load("res://src/heroes/abilities/LongNightBehavior.gd")
	ult.presentation.sound_cast = &"vesper_ult"
	ult.presentation.loop_vfx = &"long_night_glow"
	ult.presentation.sound_loop = &"vesper_ult_loop"
	ult.presentation.voice_line = &"vesper_ult_line"
	ult.presentation.voice_line_enemy = &"vesper_ult_line_enemy"
	A.ai(ult, AbilityAIHints.Intent.REVEAL, 10.0, 70.0, 30.0, 0.6)
	ult.ai.needs_enemies_in_radius = 2
	h.ultimate = ult
	return h
