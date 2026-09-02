class_name MovementController
extends RefCounted
## Deterministic first-person character movement. Runs identically on server and predicting client.
## Feel notes: ground accel is snappy (OW-style near-instant), air control is limited, gravity is heavy.

var pawn: Pawn
var profile: MovementProfile
var base_profile: MovementProfile

var grounded: bool = false
var was_grounded: bool = false
var crouching: bool = false
var crouch_amount: float = 0.0
var jumps_left: int = 1
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var landing_timer: float = 0.0
var fall_speed_peak: float = 0.0
var hover_fuel: float = 0.0
var hovering: bool = false
var external_impulse: Vector3 = Vector3.ZERO
var move_lock_timer: float = 0.0        # abilities that lock movement
var footstep_accum: float = 0.0
var last_land_impact: float = 0.0       # for camera/audio feedback (read by client)
var speed_override_mult: float = 1.0    # temporary (e.g. striker elim speed)
var speed_override_timer: float = 0.0
var wish_dir: Vector3 = Vector3.ZERO
var shape: CapsuleShape3D
var collider: CollisionShape3D


func setup(p: Pawn, prof: MovementProfile) -> void:
	pawn = p
	base_profile = prof
	profile = prof
	jumps_left = prof.jump_count
	hover_fuel = prof.hover_fuel
	shape = CapsuleShape3D.new()
	shape.radius = prof.capsule_radius
	shape.height = prof.capsule_height
	collider = CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(0, prof.capsule_height * 0.5, 0)
	pawn.add_child(collider)
	pawn.floor_max_angle = deg_to_rad(48.0)
	pawn.floor_snap_length = 0.35
	pawn.floor_stop_on_slope = true
	pawn.floor_constant_speed = true
	pawn.wall_min_slide_angle = deg_to_rad(12.0)
	pawn.safe_margin = 0.01


func set_profile_override(prof: MovementProfile) -> void:
	profile = prof if prof != null else base_profile


func eye_height() -> float:
	return lerpf(profile.eye_height, profile.crouch_eye_height, crouch_amount)


func apply_impulse(v: Vector3) -> void:
	external_impulse += v / maxf(profile.mass, 0.1)


func step(cmd: InputCmd, dt: float) -> void:
	var st := pawn.status
	var g := pawn.world.tuning.gravity * profile.gravity_mult * st.gravity_mult
	var vel := pawn.velocity
	was_grounded = grounded
	grounded = pawn.is_on_floor()

	if speed_override_timer > 0.0:
		speed_override_timer -= dt
		if speed_override_timer <= 0.0:
			speed_override_mult = 1.0
	if landing_timer > 0.0:
		landing_timer -= dt
	if move_lock_timer > 0.0:
		move_lock_timer -= dt

	# Crouch (toggle held) with ceiling check on stand-up.
	var want_crouch := cmd.has(RF.BTN_CROUCH) and not st.stunned
	if want_crouch != crouching:
		if want_crouch or _can_stand():
			crouching = want_crouch
	var target_crouch := 1.0 if crouching else 0.0
	crouch_amount = move_toward(crouch_amount, target_crouch, dt / maxf(profile.crouch_transition, 0.01))
	var h := lerpf(profile.capsule_height, profile.crouch_height, crouch_amount)
	if absf(shape.height - h) > 0.001:
		shape.height = h
		collider.position.y = h * 0.5

	# Input -> wish direction in world space (yaw only).
	var forward := Vector3(-sin(pawn.yaw), 0, -cos(pawn.yaw))
	var right := Vector3(cos(pawn.yaw), 0, -sin(pawn.yaw))
	var input := cmd.move
	if input.length_squared() > 1.0:
		input = input.normalized()
	var can_move := st.can_move() and move_lock_timer <= 0.0 and pawn.alive
	if not can_move:
		input = Vector2.ZERO
	wish_dir = (forward * input.y + right * input.x)
	var dir_mult := 1.0
	if input.y < -0.01:
		dir_mult = profile.backpedal_mult
	elif absf(input.x) > 0.01 and absf(input.y) < 0.3:
		dir_mult = profile.strafe_mult
	var max_speed := profile.max_speed * st.speed_mult * speed_override_mult * dir_mult
	if crouching or crouch_amount > 0.5:
		max_speed *= profile.crouch_speed_mult
	if landing_timer > 0.0:
		max_speed *= 0.6

	# Ability-driven movement (dashes, flight) replaces normal integration.
	var controlled := false
	for ab: Ability in pawn.abilities.slots:
		if ab and ab.behavior and ab.is_active() and ab.behavior.wants_movement_control():
			vel = ab.behavior.modify_velocity(vel, dt)
			controlled = true
			break

	if not controlled:
		var horiz := Vector3(vel.x, 0, vel.z)
		if grounded and not st.airborne:
			# Ground: friction then accelerate toward wish.
			var speed := horiz.length()
			if speed > 0.0:
				var drop := maxf(speed, 2.0) * profile.ground_friction * dt / maxf(profile.max_speed, 1.0) * 1.0
				var ns := maxf(speed - drop, 0.0)
				horiz *= ns / speed
			if wish_dir.length_squared() > 0.0:
				var wish := wish_dir.normalized()
				var cur := horiz.dot(wish)
				var add := minf(profile.ground_accel * dt, max_speed - cur)
				if add > 0.0:
					horiz += wish * add
			# Clamp to max speed on the ground (external impulses excepted briefly).
			if horiz.length() > max_speed and external_impulse.length_squared() < 0.01:
				horiz = horiz.normalized() * maxf(max_speed, horiz.length() - profile.ground_friction * dt)
		else:
			# Air: limited steering.
			if wish_dir.length_squared() > 0.0:
				var wish := wish_dir.normalized()
				var cur := horiz.dot(wish)
				var add := minf(profile.air_accel * profile.air_control * 3.0 * dt, max_speed - cur)
				if add > 0.0:
					horiz += wish * add
			horiz -= horiz * profile.air_friction * dt * 0.2
		vel.x = horiz.x; vel.z = horiz.z

		# Vertical
		if st.airborne:
			vel.y = move_toward(vel.y, 0.0, g * dt)
		elif grounded:
			if vel.y < 0.0:
				vel.y = -0.5
		else:
			vel.y -= g * dt
			if profile.slow_fall and vel.y < -profile.slow_fall_terminal and not cmd.has(RF.BTN_CROUCH):
				vel.y = move_toward(vel.y, -profile.slow_fall_terminal, g * 2.0 * dt)
			vel.y = maxf(vel.y, -pawn.world.tuning.terminal_velocity)

		# Jump (with coyote time and buffer)
		if grounded:
			coyote_timer = profile.coyote_time
			jumps_left = profile.jump_count
		else:
			coyote_timer -= dt
		if cmd.just_pressed(RF.BTN_JUMP):
			jump_buffer_timer = profile.jump_buffer
		else:
			jump_buffer_timer -= dt
		var can_jump := can_move and not st.grounded_lock and not st.airborne
		if jump_buffer_timer > 0.0 and can_jump:
			if (grounded or coyote_timer > 0.0) and jumps_left > 0:
				vel.y = profile.jump_velocity * st.jump_mult
				jumps_left -= 1
				jump_buffer_timer = 0.0
				coyote_timer = 0.0
				grounded = false
				pawn.on_jumped()
			elif jumps_left > 0 and profile.jump_count > 1:
				vel.y = profile.jump_velocity * st.jump_mult * 0.9
				jumps_left -= 1
				jump_buffer_timer = 0.0
				pawn.on_jumped()

		# Hover (Harrier-style): hold jump in the air burns fuel for upward thrust.
		hovering = false
		if profile.hover_enabled and not grounded and cmd.has(RF.BTN_JUMP) and hover_fuel > 0.0 and jumps_left == 0 and can_jump:
			vel.y = move_toward(vel.y, profile.hover_thrust, g * 2.5 * dt)
			hover_fuel = maxf(hover_fuel - dt, 0.0)
			hovering = true
		elif profile.hover_enabled and grounded:
			hover_fuel = minf(hover_fuel + profile.hover_fuel_regen * dt, profile.hover_fuel)

	# External impulses (knockback, launches) apply once then decay.
	if external_impulse.length_squared() > 0.0:
		vel += external_impulse
		external_impulse = Vector3.ZERO
		grounded = false

	if not grounded:
		fall_speed_peak = minf(fall_speed_peak, vel.y)

	pawn.velocity = vel
	if pawn.global_position.y > 12.0 and Console.cvar("dbg_high", 0.0) > 0.0:
		var act := pawn.abilities.active_ability()
		print("[dbg] %s y=%.1f vel=%s controlled=%s active=%s grounded=%s ext=%s" % [pawn.display_name, pawn.global_position.y, pawn.velocity, controlled, act.data.id if act else "-", grounded, external_impulse])
	pawn.move_and_slide()
	_try_step_up(dt)

	# Landing
	if pawn.is_on_floor() and not was_grounded:
		last_land_impact = -fall_speed_peak
		if last_land_impact > 12.0 and profile.landing_recovery > 0.0:
			landing_timer = profile.landing_recovery
		pawn.on_landed(last_land_impact)
		fall_speed_peak = 0.0

	# Footsteps
	var hs := Vector2(pawn.velocity.x, pawn.velocity.z).length()
	if pawn.is_on_floor() and hs > 1.0:
		footstep_accum += dt * (hs / maxf(profile.max_speed, 1.0))
		if footstep_accum >= profile.footstep_interval:
			footstep_accum = 0.0
			pawn.on_footstep()
	else:
		footstep_accum = profile.footstep_interval * 0.7


func _can_stand() -> bool:
	var space := pawn.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var s := CapsuleShape3D.new()
	s.radius = profile.capsule_radius * 0.95
	s.height = profile.capsule_height
	params.shape = s
	params.transform = Transform3D(Basis(), pawn.global_position + Vector3(0, profile.capsule_height * 0.5 + 0.02, 0))
	params.collision_mask = RF.L_WORLD | RF.L_DEPLOYABLE
	params.exclude = [pawn.get_rid()]
	return space.intersect_shape(params, 1).is_empty()


## Simple stair stepping: if we hit a wall while grounded and moving, try to hop up to step_height.
func _try_step_up(_dt: float) -> void:
	if not pawn.is_on_floor() or not pawn.is_on_wall() or wish_dir.length_squared() < 0.01:
		return
	var horiz := Vector3(pawn.velocity.x, 0, pawn.velocity.z)
	var wish := wish_dir.normalized()
	if horiz.length() > 1.5:
		return   # not actually blocked
	# Only step up onto static world geometry, never onto other pawns (that builds ladders).
	var last := pawn.get_last_slide_collision()
	if last and last.get_collider() is Pawn:
		return
	var up := Vector3(0, profile.step_height, 0)
	var fwd := wish * (profile.capsule_radius + 0.15)
	var from := pawn.global_transform
	# Up
	var col := pawn.move_and_collide(up, true)
	if col:
		return
	var test_up := from.translated(up)
	var p := PhysicsTestMotionParameters3D.new()
	p.from = test_up
	p.motion = fwd
	p.margin = 0.01
	var fwd_res := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(pawn.get_rid(), p, fwd_res):
		return
	# Down
	p.from = test_up.translated(fwd)
	p.motion = Vector3(0, -profile.step_height - 0.02, 0)
	var down_res := PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(pawn.get_rid(), p, down_res):
		var n := down_res.get_collision_normal()
		if down_res.get_collider() is Pawn:
			return
		if n.y > 0.7:
			pawn.global_position = p.from.origin + p.motion * down_res.get_collision_safe_fraction()
			pawn.velocity = Vector3(wish.x * maxf(profile.max_speed * 0.8, horiz.length()), 0, wish.z * maxf(profile.max_speed * 0.8, horiz.length()))
