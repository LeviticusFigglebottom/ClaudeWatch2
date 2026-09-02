class_name BotNavigator
extends RefCounted
## Path following on the navmesh plus combat movement (strafing with rhythm, cover approach,
## jumps at ledges, unstick). Writes cmd.move / jump / crouch relative to the bot's current yaw.

var brain: BotBrain
var path: PackedVector3Array = PackedVector3Array()
var path_index: int = 0
var goal: Vector3
var has_goal: bool = false
var repath_timer: float = 0.0
var stuck_timer: float = 0.0
var last_pos: Vector3
var unstick_dir: Vector3 = Vector3.ZERO
var unstick_timer: float = 0.0
var strafe_dir: float = 1.0
var strafe_timer: float = 0.0
var strafe_enabled: bool = false
var strafe_intensity: float = 1.0
var hold_position: bool = false
var crouch_timer: float = 0.0
var want_crouch: bool = false
var jump_cooldown: float = 0.0
var arrive_radius: float = 1.2
var map_rid: RID
var _dir_cache: Vector3 = Vector3.ZERO
var wander_offset: Vector3 = Vector3.ZERO
var wander_timer: float = 0.0
var sprint_wiggle: float = 0.0


func setup(b: BotBrain) -> void:
	brain = b


func reset() -> void:
	path = PackedVector3Array()
	path_index = 0
	has_goal = false
	stuck_timer = 0.0
	if brain.pawn:
		last_pos = brain.pawn.global_position
		map_rid = brain.pawn.get_world_3d().navigation_map


func set_goal(p: Vector3, radius: float = 1.2) -> void:
	arrive_radius = radius
	if not has_goal or p.distance_to(goal) > 1.5:
		goal = p
		has_goal = true
		repath_timer = 0.0


func clear_goal() -> void:
	has_goal = false
	path = PackedVector3Array()


func at_goal() -> bool:
	return has_goal and brain.pawn.global_position.distance_to(goal) <= arrive_radius


func has_direction() -> bool:
	return _dir_cache.length_squared() > 0.01


func current_direction() -> Vector3:
	return _dir_cache


func set_strafe(enabled: bool, intensity: float = 1.0) -> void:
	strafe_enabled = enabled
	strafe_intensity = intensity


func update(dt: float) -> void:
	var me := brain.pawn
	var cmd := brain.cmd
	var r := brain.rng
	jump_cooldown -= dt
	repath_timer -= dt
	var move_world := Vector3.ZERO
	if has_goal:
		if repath_timer <= 0.0:
			repath_timer = r.randf_range(0.6, 1.1)
			_compute_path()
		move_world = _follow_path(dt)
	# Combat strafing layered on top (only when holding position or nearly there).
	if strafe_enabled:
		strafe_timer -= dt
		if strafe_timer <= 0.0:
			var rhythm := brain.skill.strafe_rhythm
			# Varied rhythm: humans don't AD-spam on a metronome.
			strafe_timer = r.randf_range(0.25, 0.55) + r.randf() * rhythm * 0.9
			var flip := r.randf() < 0.75
			if flip:
				strafe_dir = -strafe_dir
			if r.randf() < 0.15:
				strafe_timer *= 2.0   # occasional long hold
		var facing := brain.pawn.aim_dir()
		var right := Vector3(-facing.z, 0, facing.x).normalized()
		var s := right * strafe_dir * strafe_intensity
		if hold_position or move_world.length_squared() < 0.05:
			move_world = s
		else:
			move_world = (move_world.normalized() * 0.8 + s * 0.6)
		# Crouch peeks
		crouch_timer -= dt
		if crouch_timer <= 0.0:
			crouch_timer = r.randf_range(0.6, 2.0)
			want_crouch = r.randf() < 0.18 * brain.skill.positioning_iq
		if want_crouch:
			cmd.buttons |= RF.BTN_CROUCH
		# Hop occasionally when jumps are part of the hero's style.
		var style: StringName = me.hero.ai.strafe_style if me.hero.ai else &"weave"
		if style == &"jump" and jump_cooldown <= 0.0 and r.randf() < 0.02:
			cmd.buttons |= RF.BTN_JUMP
			jump_cooldown = r.randf_range(0.8, 1.6)
		if style == &"hover" and me.movement.profile.hover_enabled and r.randf() < 0.01:
			cmd.buttons |= RF.BTN_JUMP
	else:
		want_crouch = false
	# Unstick
	if unstick_timer > 0.0:
		unstick_timer -= dt
		move_world = unstick_dir
		if r.randf() < 0.1:
			cmd.buttons |= RF.BTN_JUMP
	elif has_goal and move_world.length_squared() > 0.1:
		var moved := me.global_position.distance_to(last_pos)
		if moved < 0.04 and me.is_on_floor():
			stuck_timer += dt
		else:
			stuck_timer = maxf(stuck_timer - dt, 0.0)
		if stuck_timer > 0.5:
			stuck_timer = 0.0
			unstick_timer = r.randf_range(0.3, 0.7)
			var side := Vector3(-move_world.z, 0, move_world.x).normalized()
			unstick_dir = (side * (1.0 if r.randf() < 0.5 else -1.0) - move_world.normalized() * 0.4).normalized()
			if jump_cooldown <= 0.0:
				cmd.buttons |= RF.BTN_JUMP
				jump_cooldown = 0.6
	last_pos = me.global_position
	# Convert to view-relative input
	if move_world.length_squared() > 0.001:
		_dir_cache = Vector3(move_world.x, 0, move_world.z).normalized()
		var yaw := brain.yaw
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		cmd.move = Vector2(clampf(_dir_cache.dot(right), -1, 1), clampf(_dir_cache.dot(fwd), -1, 1))
	else:
		cmd.move = Vector2.ZERO


func _compute_path() -> void:
	var me := brain.pawn
	if not map_rid.is_valid():
		map_rid = me.get_world_3d().navigation_map
	var from := me.global_position
	var to := goal
	if NavigationServer3D.map_get_iteration_id(map_rid) == 0:
		path = PackedVector3Array([from, to])
		path_index = 1
		return
	var params := NavigationPathQueryParameters3D.new()
	params.map = map_rid
	params.start_position = from
	params.target_position = to
	params.path_postprocessing = NavigationPathQueryParameters3D.PATH_POSTPROCESSING_CORRIDORFUNNEL
	params.navigation_layers = 1
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(params, result)
	path = result.path
	if path.size() < 2:
		path = PackedVector3Array([from, to])
	path_index = 1


func _follow_path(dt: float) -> Vector3:
	var me := brain.pawn
	var cmd := brain.cmd
	if path.size() < 2:
		var d := goal - me.global_position
		d.y = 0
		return d.normalized() if d.length() > arrive_radius else Vector3.ZERO
	# Advance waypoints
	while path_index < path.size() - 1 and me.global_position.distance_to(path[path_index]) < 0.9:
		path_index += 1
	var wp := path[path_index]
	var to := wp - me.global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist_goal := me.global_position.distance_to(goal)
	if path_index >= path.size() - 1 and dist_goal <= arrive_radius:
		return Vector3.ZERO
	# Jump if the waypoint is noticeably above us and close.
	if to.y > 0.7 and flat.length() < 2.2 and me.is_on_floor() and jump_cooldown <= 0.0:
		cmd.buttons |= RF.BTN_JUMP
		jump_cooldown = 0.5
	# Wander: small lateral offset so bots don't walk the exact same line.
	wander_timer -= dt
	if wander_timer <= 0.0:
		wander_timer = brain.rng.randf_range(1.0, 2.5)
		var side := Vector3(-flat.z, 0, flat.x).normalized()
		wander_offset = side * brain.rng.randf_range(-0.5, 0.5) * brain.skill.strafe_rhythm
	var dir := (flat.normalized() + wander_offset).normalized() if flat.length() > 0.1 else Vector3.ZERO
	return dir
