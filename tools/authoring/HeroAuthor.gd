class_name HeroAuthor
extends RefCounted
## Helpers for hero builder scripts. A builder returns a fully-populated HeroData; build_data.gd
## saves it (and its sub-resources inline) to data/heroes/<id>.tres. The runtime only ever loads .tres.

static func hero(id: StringName, display: String, role: int, hp: float, armor: float = 0.0, shield: float = 0.0) -> HeroData:
	var h := HeroData.new()
	h.id = id
	h.display_name = display
	h.role = role
	h.health = hp; h.armor = armor; h.shield = shield
	h.movement = MovementProfile.new()
	h.hitbox = HitboxProfile.new()
	h.visual = HeroVisualData.new()
	h.audio = HeroAudioData.new()
	h.ai = AIHeroProfile.new()
	return h


static func movement(max_speed: float = 5.5, jump: float = 6.4, accel: float = 60.0, air_control: float = 0.35, gravity_mult: float = 1.0) -> MovementProfile:
	var m := MovementProfile.new()
	m.max_speed = max_speed; m.jump_velocity = jump; m.ground_accel = accel; m.air_control = air_control; m.gravity_mult = gravity_mult
	return m


static func ability(id: StringName, display: String, desc: String, trigger: int = AbilityData.Trigger.PRESS, cooldown: float = 0.0) -> AbilityData:
	var a := AbilityData.new()
	a.id = id
	a.display_name = display
	a.description = desc
	a.trigger = trigger
	a.cooldown = cooldown
	a.presentation = AbilityPresentation.new()
	a.ai = AbilityAIHints.new()
	return a


static func weapon(id: StringName, display: String, desc: String, fire_rate: float, ammo: int, reload: float) -> AbilityData:
	var a := ability(id, display, desc, AbilityData.Trigger.HOLD)
	a.fire_rate = fire_rate
	a.is_weapon = true
	a.resource = AbilityData.Cost.AMMO if ammo > 0 else AbilityData.Cost.NONE
	a.ammo = ammo
	a.reload_time = reload
	a.usable_while_silenced = true
	a.ai.spam_ok = true
	return a


static func ultimate(id: StringName, display: String, desc: String, cost: float, trigger: int = AbilityData.Trigger.PRESS) -> AbilityData:
	var a := ability(id, display, desc, trigger)
	a.resource = AbilityData.Cost.ULTIMATE
	a.ult_cost = cost
	a.presentation.anim_tag = &"ult"
	a.presentation.cast_vfx = &"ult_burst"
	return a


static func status(id: StringName, display: String, duration: float) -> StatusData:
	var s := StatusData.new()
	s.id = id
	s.display_name = display
	s.duration = duration
	return s


static func hitscan(damage: float, range_: float = 100.0) -> HitscanEffect:
	var e := HitscanEffect.new()
	e.damage = damage
	e.range = range_
	return e


static func projectile(damage: float, speed: float) -> ProjectileEffect:
	var e := ProjectileEffect.new()
	e.damage = damage
	e.speed = speed
	return e


static func pres(a: AbilityData, fire: StringName, tail: StringName = &"", tracer: StringName = &"", color: Color = Color(1, 0.85, 0.5)) -> AbilityPresentation:
	var p := a.presentation
	p.sound_fire = fire
	p.sound_tail = tail
	p.tracer_style = tracer
	p.tracer_color = color
	return p


static func ai(a: AbilityData, intent: int, min_r: float, max_r: float, ideal: float, priority: float = 0.5) -> AbilityAIHints:
	a.ai.intent = intent
	a.ai.min_range = min_r
	a.ai.max_range = max_r
	a.ai.ideal_range = ideal
	a.ai.cast_priority = priority
	return a.ai


static func feel(a: AbilityData, kick_pitch: float, kick_yaw: float, vm_kick: float, vm_rot: float, shake: float, recovery: float = 12.0) -> void:
	var p := a.presentation
	p.camera_kick_pitch = kick_pitch
	p.camera_kick_yaw_random = kick_yaw
	p.viewmodel_kick = vm_kick
	p.viewmodel_kick_rot = vm_rot
	p.camera_shake = shake
	p.kick_recovery = recovery
