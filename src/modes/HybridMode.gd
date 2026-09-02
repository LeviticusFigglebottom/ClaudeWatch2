class_name HybridMode
extends ModeController
## Hybrid: attackers first capture a point (0->100% by standing on it, contested freezes), then the
## payload unlocks and they escort it through checkpoints. Reuses Escort's payload logic.

var capture_progress: float = 0.0
var payload_phase: bool = false
var escort: EscortMode
var point: MapLayout.Zone
var capture_results: Array[float] = [0.0, 0.0]


func on_setup() -> void:
	data.symmetric = false
	escort = EscortMode.new()
	escort.name = "EscortPart"
	add_child(escort)
	escort.server = server; escort.world = world; escort.data = data; escort.layout = layout
	escort.rng = rng


func on_round_begin() -> void:
	capture_progress = 0.0
	payload_phase = false
	point = layout.capture_points[0] if not layout.capture_points.is_empty() else layout.make_zone("A", Vector3.ZERO, Vector3(5, 3, 5))
	escort.attacking_team = attacking_team
	escort.round_index = round_index
	escort.on_round_begin()
	time_remaining = data.round_time
	if round_index == 1 and capture_results[RF.enemy_team(attacking_team)] < 1.0:
		escort.target_progress_to_beat = -1.0


func objective_position() -> Vector3:
	return escort.objective_position() if payload_phase else point.center


func spawn_phase_for(team: int) -> int:
	return (escort.checkpoint_index + 1) if payload_phase else 0


func update_contest() -> void:
	if payload_phase:
		escort.update_contest()
		contest_count = escort.contest_count
	else:
		contest_count = count_on_zone(point)


func step_objective(dt: float) -> void:
	if payload_phase:
		escort.phase = phase
		escort.time_remaining = time_remaining
		escort.overtime_active = overtime_active
		escort.overtime_fuse = overtime_fuse
		escort.step_objective(dt)
		time_remaining = escort.time_remaining
		overtime_active = escort.overtime_active
		overtime_fuse = escort.overtime_fuse
		if escort.phase == Phase.ROUND_END:
			escort.phase = Phase.LIVE
			capture_results[attacking_team] = 1.0
		return
	if phase == Phase.LIVE:
		time_remaining -= dt
	var att := contest_count[attacking_team]
	var def := contest_count[defending_team()]
	if att > 0 and def == 0:
		var mult := 1.0 + 0.25 * minf(att - 1, 2)
		capture_progress = minf(capture_progress + dt / data.point_capture_time * mult, 1.0)
		if capture_progress >= 1.0:
			payload_phase = true
			capture_results[attacking_team] = 1.0
			time_remaining += data.time_per_checkpoint
			announce(&"point_captured", {"team": attacking_team})
			server.respawn_pending_positions_changed()
			return
	elif att == 0 and capture_progress > 0.0 and capture_progress < 1.0:
		capture_progress = maxf(capture_progress - dt / (data.point_capture_time * 3.0), 0.0)
	capture_results[attacking_team] = maxf(capture_results[attacking_team], capture_progress)
	if time_remaining <= 0.0:
		if att > 0:
			overtime_active = true
		if handle_overtime(dt, att > 0):
			pass
		elif not overtime_active:
			end_round(defending_team(), &"time_expired")


func _end_from_escort(winner_team: int, reason: StringName) -> void:
	end_round(winner_team, reason)


func on_step(_dt: float) -> void:
	# Escort part signals round end through its own end_round; mirror it.
	if payload_phase and escort.round_results.size() > round_results.size() and phase == Phase.LIVE or phase == Phase.OVERTIME and payload_phase and escort.round_results.size() > round_results.size():
		var r: Dictionary = escort.round_results[escort.round_results.size() - 1]
		end_round(int(r["winner"]), StringName(String(r["reason"])))


func compute_winner() -> int:
	var a := capture_results[0] + (escort.distance_results[0] / maxf(escort.path_length, 1.0) if capture_results[0] >= 1.0 else 0.0)
	var b := capture_results[1] + (escort.distance_results[1] / maxf(escort.path_length, 1.0) if capture_results[1] >= 1.0 else 0.0)
	if escort.completed[0] and escort.completed[1]:
		return RF.Team.A if escort.time_results[0] > escort.time_results[1] else (RF.Team.B if escort.time_results[1] > escort.time_results[0] else -1)
	if absf(a - b) < 0.005:
		return -1
	return RF.Team.A if a > b else RF.Team.B


func hud_state() -> Dictionary:
	var d := super.hud_state()
	d["kind"] = "hybrid"
	if payload_phase:
		var e := escort.hud_state()
		d["payload_progress"] = e["payload_progress"]
		d["checkpoints"] = e["checkpoints"]
		d["pushers"] = e["pushers"]
		d["contested"] = e["contested"]
	else:
		d["capture_progress"] = capture_progress
		d["contested"] = contest_count[0] > 0 and contest_count[1] > 0
	return d
