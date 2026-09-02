class_name ControlMode
extends ModeController
## Control (king of the hill): one point, best of 3 rounds. Capture 0->100% by holding the point;
## the holding team's progress ticks toward 100; contested points freeze; overtime when the
## non-holding team is on the point at 99%.

var control_progress: float = 0.0        # 0..1 for the current owner
var owner_team: int = -1
var capture_progress: Array[float] = [0.0, 0.0]   # 0..1 per team toward taking the point
var unlock_timer: float = 0.0
var point: MapLayout.Zone
var round_wins: Array[int] = [0, 0]
var point_index: int = 0


func on_setup() -> void:
	data.symmetric = true


func on_round_begin() -> void:
	control_progress = 0.0
	owner_team = -1
	capture_progress = [0.0, 0.0]
	unlock_timer = data.control_unlock_delay
	point_index = round_index % maxi(layout.control_points.size(), 1)
	point = layout.control_points[point_index] if not layout.control_points.is_empty() else layout.make_zone("p", Vector3.ZERO, Vector3(5, 3, 5))
	score = round_wins.duplicate()
	time_remaining = 0.0


func on_live_begin() -> void:
	unlock_timer = data.control_unlock_delay


func spawn_phase_for(_team: int) -> int:
	return point_index


func update_contest() -> void:
	contest_count = count_on_zone(point)


func step_objective(dt: float) -> void:
	if unlock_timer > 0.0:
		unlock_timer -= dt
		time_remaining = unlock_timer
		if unlock_timer <= 0.0:
			announce(&"point_unlocked", {})
		return
	var a := contest_count[0] > 0
	var b := contest_count[1] > 0
	var contested := a and b
	# Capture logic
	if not contested:
		for t in RF.TEAM_COUNT:
			var on := contest_count[t] > 0
			if on and owner_team != t:
				var speed := 1.0 / data.control_capture_time * (1.0 + 0.25 * minf(contest_count[t] - 1, 2))
				capture_progress[t] = minf(capture_progress[t] + speed * dt, 1.0)
				if capture_progress[t] >= 1.0:
					owner_team = t
					capture_progress = [0.0, 0.0]
					announce(&"point_captured", {"team": t})
			elif not on and capture_progress[t] > 0.0:
				capture_progress[t] = maxf(capture_progress[t] - dt / (data.control_capture_time * 2.0), 0.0)
	# Progress for the owner
	if owner_team >= 0:
		var enemy_on := contest_count[RF.enemy_team(owner_team)] > 0
		if control_progress >= 0.99 and enemy_on:
			overtime_active = true
		if not enemy_on or control_progress < 0.99:
			control_progress = minf(control_progress + dt / 100.0 * (100.0 / 100.0), 1.0)
		if handle_overtime(dt, enemy_on):
			# Overtime: owner can't finish while enemies touch.
			pass
		elif control_progress >= 1.0:
			score[owner_team] += 1
			round_wins[owner_team] += 1
			end_round(owner_team, &"control_complete")
			return
		time_remaining = (1.0 - control_progress) * 100.0
	# Overtime fuse expired while enemy left: owner completes
	if overtime_active and not overtime_active:
		pass


func decided() -> bool:
	return round_wins[0] >= data.control_rounds_to_win or round_wins[1] >= data.control_rounds_to_win


func compute_winner() -> int:
	if round_wins[0] > round_wins[1]: return RF.Team.A
	if round_wins[1] > round_wins[0]: return RF.Team.B
	return -1


func next_round_or_end() -> void:
	round_index += 1
	if decided() or round_index >= 5:
		finish_match()
	else:
		begin_round()


func objective_position() -> Vector3:
	return point.center if point else Vector3.ZERO


func is_attacker(team: int) -> bool:
	# In control, whoever doesn't own the point is "attacking".
	return owner_team != team


func hud_state() -> Dictionary:
	var d := super.hud_state()
	d["owner"] = owner_team
	d["progress"] = control_progress
	d["cap_a"] = capture_progress[0]
	d["cap_b"] = capture_progress[1]
	d["unlock"] = maxf(unlock_timer, 0.0)
	d["wins_a"] = round_wins[0]
	d["wins_b"] = round_wins[1]
	d["point_name"] = point.name if point else ""
	d["contested"] = contest_count[0] > 0 and contest_count[1] > 0
	return d


func respawn_time(_team: int) -> float:
	return data.respawn_time_attack * server.config.respawn_scale
