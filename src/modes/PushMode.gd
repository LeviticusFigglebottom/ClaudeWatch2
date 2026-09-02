class_name PushMode
extends ModeController
## Push: a robot starts mid-map and walks toward the enemy side when a team is near it with no
## enemies. It pushes that team's barrier (the barrier waits where it was left). Symmetric spawns.
## Win by pushing the barrier to the end, or by farther distance when time runs out (overtime on touch).

var robot_progress: float = 0.0        # -half..+half along the track (negative = toward A's side)
var barrier_pos: Array[float] = [0.0, 0.0]   # where each team's barrier currently sits
var half_length: float = 0.0
var robot: Node3D
var pusher_team: int = -1
var contested: bool = false
var robot_body: EscortMode.Payload


func on_setup() -> void:
	data.symmetric = true


func on_round_begin() -> void:
	half_length = layout.push_track.get_baked_length() * 0.5 if layout.push_track else 30.0
	robot_progress = 0.0
	barrier_pos = [-half_length * 0.1, half_length * 0.1]
	time_remaining = data.push_time
	if robot_body == null:
		robot_body = EscortMode.Payload.new()
		robot_body.name = "PushRobot"
		world.add_child(robot_body)
		robot_body.setup(world, layout.push_track)
		robot_body.team = RF.Team.NONE
	_place_robot()


func _place_robot() -> void:
	if robot_body:
		robot_body.set_progress(half_length + robot_progress)


func objective_position() -> Vector3:
	return robot_body.global_position if robot_body else Vector3.ZERO


func objective_positions_for(team: int) -> Array[Vector3]:
	return [objective_position()]


func update_contest() -> void:
	contest_count = [0, 0]
	for p: Pawn in world.pawns.values():
		p.on_objective = false
		if not p.alive:
			continue
		if p.global_position.distance_to(objective_position()) <= 3.2:
			contest_count[p.team] += 1
			p.on_objective = true


func step_objective(dt: float) -> void:
	if phase == Phase.LIVE:
		time_remaining -= dt
	var a := contest_count[RF.Team.A]
	var b := contest_count[RF.Team.B]
	contested = a > 0 and b > 0
	pusher_team = -1
	if a > 0 and b == 0:
		pusher_team = RF.Team.A
	elif b > 0 and a == 0:
		pusher_team = RF.Team.B
	if pusher_team >= 0:
		var dir := 1.0 if pusher_team == RF.Team.A else -1.0   # A pushes toward +, B toward -
		var speed := data.push_robot_speed
		var target_barrier := barrier_pos[pusher_team]
		# Robot walks faster alone; once it reaches its barrier it pushes it slower.
		var pushing_barrier := (dir > 0 and robot_progress >= target_barrier - 0.01) or (dir < 0 and robot_progress <= target_barrier + 0.01)
		if not pushing_barrier:
			speed *= data.push_barrier_speed_mult
		robot_progress = clampf(robot_progress + dir * speed * dt, -half_length, half_length)
		if pushing_barrier:
			barrier_pos[pusher_team] = robot_progress
		if absf(robot_progress) >= half_length - 0.05:
			score[pusher_team] = 100
			end_round(pusher_team, &"push_complete")
			return
	_place_robot()
	if time_remaining <= 0.0:
		var touching := pusher_team >= 0 and pusher_team == _trailing_team()
		if touching:
			overtime_active = true
		if handle_overtime(dt, touching):
			pass
		elif not overtime_active:
			finish_match()


func _trailing_team() -> int:
	var da := barrier_pos[RF.Team.A] + half_length      # distance A pushed forward
	var db := half_length - barrier_pos[RF.Team.B]
	return RF.Team.A if da < db else RF.Team.B


func compute_winner() -> int:
	var da := barrier_pos[RF.Team.A] + half_length
	var db := half_length - barrier_pos[RF.Team.B]
	if absf(da - db) < 0.3:
		return -1
	return RF.Team.A if da > db else RF.Team.B


func decided() -> bool:
	return true


func next_round_or_end() -> void:
	finish_match()


func spawn_transform(team: int) -> Transform3D:
	# Forward spawns: each team spawns near its barrier once pushed past a third of the way.
	var role: StringName = &"a" if team == RF.Team.A else &"b"
	var progress := (barrier_pos[team] + half_length) / (2.0 * half_length) if team == RF.Team.A else (half_length - barrier_pos[team]) / (2.0 * half_length)
	var phase_idx := 1 if progress > 0.66 else 0
	var rooms := layout.rooms_for(role, phase_idx)
	if rooms.is_empty():
		return super.spawn_transform(team)
	var r: MapLayout.SpawnRoom = rooms[rng.randi() % rooms.size()]
	return r.points[rng.randi() % r.points.size()] if not r.points.is_empty() else Transform3D(Basis(), r.zone.center)


func hud_state() -> Dictionary:
	var d := super.hud_state()
	d["kind"] = "push"
	d["push_progress"] = (robot_progress + half_length) / maxf(2.0 * half_length, 1.0)
	d["barrier_a"] = (barrier_pos[0] + half_length) / maxf(2.0 * half_length, 1.0)
	d["barrier_b"] = (barrier_pos[1] + half_length) / maxf(2.0 * half_length, 1.0)
	d["pusher_team"] = pusher_team
	d["contested"] = contested
	d["time"] = time_remaining
	return d
