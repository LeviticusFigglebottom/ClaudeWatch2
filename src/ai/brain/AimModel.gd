class_name AimModel
extends RefCounted
## Human-like aiming: reaction latency, flick with overshoot, noisy tracking (Ornstein-Uhlenbeck),
## imperfect projectile lead, recoil mis-compensation, and pressure/movement degradation.
## Also decides *when* to pull the trigger. Never snaps to a target.

enum Phase { IDLE, REACTING, FLICKING, TRACKING }

var brain: BotBrain
var target: Pawn
var phase: Phase = Phase.IDLE
var reaction_left: float = 0.0
var flick_progress: float = 0.0
var flick_from_yaw: float = 0.0
var flick_from_pitch: float = 0.0
var flick_to_yaw: float = 0.0
var flick_to_pitch: float = 0.0
var flick_time: float = 0.3
var overshoot_yaw: float = 0.0
var overshoot_pitch: float = 0.0
var noise_yaw: float = 0.0
var noise_pitch: float = 0.0
var recoil_offset: float = 0.0
var aim_head: bool = false
var head_reroll: float = 0.0
var lead_error: float = 1.0
var lead_reroll: float = 0.0
var look_yaw: float = 0.0        # where to look when idle
var look_pitch: float = 0.0
var idle_scan_timer: float = 0.0
var want_fire: bool = false
var burst_timer: float = 0.0
var burst_on: bool = true
var trigger_slot: int = RF.Slot.PRIMARY
var last_target_id: int = -1
var switch_timer: float = 0.0
var max_turn_speed: float = 540.0  # deg/s absolute cap for tracking
var _time: float = 0.0
var target_switch_pending: Pawn


func setup(b: BotBrain) -> void:
	brain = b


func reset() -> void:
	target = null
	phase = Phase.IDLE
	noise_yaw = 0.0; noise_pitch = 0.0
	if brain.pawn:
		look_yaw = brain.pawn.yaw
		look_pitch = 0.0
		brain.yaw = brain.pawn.yaw
		brain.pitch = 0.0


func set_target(t: Pawn) -> void:
	if t == target:
		return
	if t != null and target != null:
		# Switching targets takes a moment (decision latency), unless the current one is dead.
		if target.alive and switch_timer < brain.skill.target_switch_delay:
			target_switch_pending = t
			return
	_begin_target(t)


func _begin_target(t: Pawn) -> void:
	target = t
	target_switch_pending = null
	switch_timer = 0.0
	if t == null:
		phase = Phase.IDLE
		return
	var skill := brain.skill
	phase = Phase.REACTING
	var r := brain.rng
	reaction_left = maxf(skill.reaction_time + r.randfn(0.0, skill.reaction_jitter), 0.08)
	# If we were already vaguely looking that way, reaction is faster (attention was there).
	var to := (t.center() - brain.pawn.eye_position()).normalized()
	var facing := to.dot(brain.pawn.aim_dir())
	if facing > 0.95:
		reaction_left *= 0.6
	last_target_id = t.net_id


func set_look(yaw: float, pitch: float) -> void:
	look_yaw = yaw
	look_pitch = pitch


func look_at_point(p: Vector3) -> void:
	var eye := brain.pawn.eye_position()
	var d := (p - eye)
	if d.length_squared() < 0.01:
		return
	look_yaw = atan2(-d.x, -d.z)
	look_pitch = atan2(d.y, Vector2(d.x, d.z).length())


func update(dt: float) -> void:
	_time += dt
	switch_timer += dt
	var me := brain.pawn
	var skill := brain.skill
	var r := brain.rng
	want_fire = false
	if target_switch_pending and switch_timer >= skill.target_switch_delay:
		_begin_target(target_switch_pending)
	if target and (not is_instance_valid(target) or not target.alive):
		target = null
		phase = Phase.IDLE
	# Noise process (OU): mean-reverting random walk in degrees.
	var pressure := 1.0
	if brain.perception.is_under_fire(): pressure += skill.pressure_penalty
	var hs := Vector2(me.velocity.x, me.velocity.z).length()
	pressure += skill.move_penalty * clampf(hs / maxf(me.movement.profile.max_speed, 1.0), 0.0, 1.0)
	if not me.is_on_floor(): pressure += 0.3
	var sigma := skill.tracking_noise * pressure * (brain.pawn.hero.ai.aim_difficulty_scale if brain.pawn.hero.ai else 1.0)
	var theta := skill.tracking_smoothness
	noise_yaw += -theta * noise_yaw * dt + sigma * sqrt(2.0 * theta * dt) * r.randfn(0.0, 1.0)
	noise_pitch += -theta * noise_pitch * dt + sigma * 0.7 * sqrt(2.0 * theta * dt) * r.randfn(0.0, 1.0)
	# Recoil: the weapon kicked our view; we counter only part of it.
	recoil_offset = maxf(recoil_offset - 40.0 * dt, 0.0)

	var desired_yaw := look_yaw
	var desired_pitch := look_pitch
	if target == null:
		phase = Phase.IDLE
		_idle_look(dt)
		desired_yaw = look_yaw; desired_pitch = look_pitch
		_turn_toward(desired_yaw, desired_pitch, dt, 240.0)
		return
	# Where on the target, with imperfect projectile lead.
	head_reroll -= dt
	if head_reroll <= 0.0:
		head_reroll = r.randf_range(0.8, 2.0)
		aim_head = r.randf() < skill.headshot_intent and target.movement.crouch_amount < 0.5
	lead_reroll -= dt
	if lead_reroll <= 0.0:
		lead_reroll = r.randf_range(0.5, 1.5)
		lead_error = 1.0 + r.randfn(0.0, 0.25 * (1.6 - skill.recoil_compensation))
	var aim_point := _aim_point()
	var eye := me.eye_position()
	var d := aim_point - eye
	var dist := d.length()
	var t_yaw := atan2(-d.x, -d.z)
	var t_pitch := atan2(d.y, Vector2(d.x, d.z).length())
	# Angular size of the target: bigger targets = easier
	var ang_size := rad_to_deg(atan2(0.45, maxf(dist, 0.5)))

	match phase:
		Phase.REACTING:
			reaction_left -= dt
			# Eyes drift toward the target a little even before the "conscious" reaction.
			_turn_toward(lerp_angle(brain.yaw, t_yaw, 0.15), lerpf(brain.pitch, t_pitch, 0.15), dt, 90.0)
			if reaction_left <= 0.0:
				phase = Phase.FLICKING
				flick_from_yaw = brain.yaw; flick_from_pitch = brain.pitch
				flick_to_yaw = t_yaw; flick_to_pitch = t_pitch
				var ang := rad_to_deg(absf(wrapf(t_yaw - brain.yaw, -PI, PI))) + rad_to_deg(absf(t_pitch - brain.pitch))
				flick_time = clampf(ang / skill.flick_speed, 0.06, 0.5) + skill.acquisition_time * 0.5
				flick_progress = 0.0
				var os := skill.flick_overshoot * (0.6 + r.randf() * 0.8)
				overshoot_yaw = wrapf(t_yaw - brain.yaw, -PI, PI) * os
				overshoot_pitch = (t_pitch - brain.pitch) * os * 0.6
		Phase.FLICKING:
			flick_progress += dt / flick_time
			var s := clampf(flick_progress, 0.0, 1.0)
			# Ease-out with overshoot then settle (a damped spring shape).
			var eased := 1.0 - pow(1.0 - s, 3.0)
			var os_k := sin(s * PI) * (1.0 - s)
			# Retarget mid-flick toward the *current* target position (humans do this).
			flick_to_yaw = lerp_angle(flick_to_yaw, t_yaw, 0.3)
			flick_to_pitch = lerpf(flick_to_pitch, t_pitch, 0.3)
			brain.yaw = lerp_angle(flick_from_yaw, flick_to_yaw, eased) + overshoot_yaw * os_k + deg_to_rad(noise_yaw) * 0.3
			brain.pitch = lerpf(flick_from_pitch, flick_to_pitch, eased) + overshoot_pitch * os_k + deg_to_rad(noise_pitch) * 0.3
			if flick_progress >= 1.0:
				phase = Phase.TRACKING
		Phase.TRACKING:
			var goal_yaw := t_yaw + deg_to_rad(noise_yaw)
			var goal_pitch := t_pitch + deg_to_rad(noise_pitch) - deg_to_rad(recoil_offset) * (1.0 - skill.recoil_compensation)
			# Tracking lags the target slightly (smoothing), more for fast lateral motion.
			var lateral := target.velocity.length()
			var smooth := clampf(14.0 - lateral * 0.6, 6.0, 14.0) * (0.7 + 0.3 * skill.recoil_compensation)
			var new_yaw := lerp_angle(brain.yaw, goal_yaw, clampf(smooth * dt, 0.0, 1.0))
			var new_pitch := lerpf(brain.pitch, goal_pitch, clampf(smooth * dt, 0.0, 1.0))
			_turn_toward(new_yaw, new_pitch, dt, max_turn_speed)
	brain.pitch = clampf(brain.pitch, -PI * 0.49, PI * 0.49)
	brain.yaw = wrapf(brain.yaw, -PI, PI)

	# Trigger discipline
	if phase == Phase.TRACKING or (phase == Phase.FLICKING and flick_progress > 0.75):
		var err_yaw := rad_to_deg(absf(wrapf(brain.yaw - t_yaw, -PI, PI)))
		var err_pitch := rad_to_deg(absf(brain.pitch - t_pitch))
		var err := sqrt(err_yaw * err_yaw + err_pitch * err_pitch)
		var tolerance := ang_size * 1.6 + 0.8
		var weapon := me.abilities.get_slot(trigger_slot)
		if weapon and weapon.data.trigger == AbilityData.Trigger.HOLD:
			tolerance *= 1.5   # spray weapons fire more liberally
		var in_range := dist <= (weapon.data.ai.max_range if weapon and weapon.data.ai else 40.0)
		var los := brain.perception.belief_for(target).visible
		if los and in_range and err <= tolerance:
			want_fire = true
		# Human-shaped mistake: sometimes fire a little early / keep firing a little after.
		if los and in_range and err <= tolerance * 1.8 and r.randf() < skill.mistake_rate * 0.02:
			want_fire = true
		# Burst rhythm for HOLD weapons: fire in 0.5-1.4 s bursts with 0.15-0.4 s gaps.
		burst_timer -= dt
		if burst_timer <= 0.0:
			burst_on = not burst_on
			burst_timer = r.randf_range(0.5, 1.4) if burst_on else r.randf_range(0.12, 0.4) * (1.0 + (1.0 - skill.recoil_compensation))
		if weapon and weapon.data.trigger == AbilityData.Trigger.HOLD and not burst_on:
			want_fire = false


func on_weapon_fired(kick_deg: float) -> void:
	recoil_offset += kick_deg


## Choose a point on the target; imperfect lead for projectiles.
func _aim_point() -> Vector3:
	var me := brain.pawn
	var weapon := me.abilities.get_slot(trigger_slot)
	var base := target.eye_position() if aim_head else target.center()
	var speed := 0.0
	var grav := 0.0
	if weapon:
		for e: AbilityEffect in weapon.data.effects:
			if e is ProjectileEffect:
				speed = (e as ProjectileEffect).speed
				grav = (e as ProjectileEffect).gravity
				break
	if speed > 0.0:
		var dist := base.distance_to(me.eye_position())
		var t := dist / speed
		var lead := target.velocity * t * lead_error
		lead.y *= 0.5
		base += lead
		if grav > 0.0:
			base.y += 0.5 * grav * t * t * (0.8 + 0.4 * lead_error)
	return base


func _turn_toward(yaw: float, pitch: float, dt: float, max_speed_deg: float) -> void:
	var max_step := deg_to_rad(max_speed_deg) * dt
	var dy := wrapf(yaw - brain.yaw, -PI, PI)
	var dp := pitch - brain.pitch
	brain.yaw += clampf(dy, -max_step, max_step)
	brain.pitch += clampf(dp, -max_step, max_step)


func _idle_look(dt: float) -> void:
	# Look where we're going, glance toward remembered threats, scan occasionally.
	idle_scan_timer -= dt
	var me := brain.pawn
	var nav := brain.nav
	var best: BotPerception.Belief = null
	for b: Variant in brain.perception.beliefs.values():
		var bb := b as BotPerception.Belief
		if bb.noticed and bb.confidence > 0.3 and (best == null or bb.confidence > best.confidence):
			best = bb
	if best != null and brain.rng.randf() < 0.7:
		look_at_point(best.predicted_pos(brain.world.tick) + Vector3(0, 1.2, 0))
	elif nav.has_direction():
		var d := nav.current_direction()
		look_yaw = atan2(-d.x, -d.z)
		look_pitch = lerpf(look_pitch, 0.0, 0.1)
		if idle_scan_timer <= 0.0:
			idle_scan_timer = brain.rng.randf_range(1.5, 4.0)
			look_yaw += brain.rng.randf_range(-0.6, 0.6)
	else:
		if idle_scan_timer <= 0.0:
			idle_scan_timer = brain.rng.randf_range(1.0, 3.0)
			var objective: Vector3 = brain.world.mode.objective_position() if brain.world.mode else me.global_position
			var to: Vector3 = objective - me.global_position
			if to.length() > 2.0:
				look_yaw = atan2(-to.x, -to.z) + brain.rng.randf_range(-0.8, 0.8)
			else:
				look_yaw += brain.rng.randf_range(-1.2, 1.2)
			look_pitch = brain.rng.randf_range(-0.1, 0.1)
