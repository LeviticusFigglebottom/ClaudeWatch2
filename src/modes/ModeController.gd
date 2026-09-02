class_name ModeController
extends Node
## Base for objective modes. Server-side authority over phase, score, timers, spawns and overtime.
## Subclasses implement the objective loop; this class handles rounds, freeze time and shared HUD state.

enum Phase { WAITING, SETUP, LIVE, OVERTIME, ROUND_END, MATCH_END }

signal match_ended(winner: int, summary: Dictionary)
signal phase_changed(phase: int)

var server: GameServer
var world: SimWorld
var data: ModeData
var layout: MapLayout
var phase: Phase = Phase.WAITING
var round_index: int = 0
var attacking_team: int = RF.Team.A
var time_remaining: float = 0.0
var overtime_fuse: float = 0.0
var overtime_active: bool = false
var score: Array[int] = [0, 0]
var winner: int = -1
var phase_time: float = 0.0
var objective_index: int = 0
var round_results: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var announcements: Array = []
var last_hud: Dictionary = {}
var match_elapsed: float = 0.0
var contest_count: Array[int] = [0, 0]   # pawns from each team on the current objective


func setup(s: GameServer, w: SimWorld, d: ModeData, l: MapLayout) -> void:
	server = s; world = w; data = d; layout = l
	rng.seed = s.config.seed if s.config.seed != 0 else int(Time.get_unix_time_from_system())
	attacking_team = RF.Team.A if d.team_a_attacks_first else RF.Team.B
	world.mode = self
	on_setup()


func on_setup() -> void:
	pass


func start_match() -> void:
	round_index = 0
	score = [0, 0]
	begin_round()


func begin_round() -> void:
	objective_index = 0
	overtime_active = false
	overtime_fuse = data.overtime_grace
	on_round_begin()
	var setup_t := data.setup_time
	if server.config.skip_setup:
		setup_t = minf(setup_t, 2.0)
	set_phase(Phase.SETUP)
	phase_time = setup_t
	world.frozen = false
	server.respawn_everyone()
	announce(&"round_start", {"attacking": attacking_team, "round": round_index})


func on_round_begin() -> void:
	pass


func set_phase(p: Phase) -> void:
	if phase == p:
		return
	phase = p
	phase_changed.emit(p)
	server.on_mode_phase(p)


func step(dt: float) -> void:
	match_elapsed += dt
	match phase:
		Phase.SETUP:
			phase_time -= dt
			if phase_time <= 0.0:
				set_phase(Phase.LIVE)
				on_live_begin()
				announce(&"live", {})
		Phase.LIVE, Phase.OVERTIME:
			update_contest()
			step_objective(dt)
		Phase.ROUND_END:
			phase_time -= dt
			if phase_time <= 0.0:
				next_round_or_end()
		Phase.MATCH_END:
			pass
	on_step(dt)


func on_step(_dt: float) -> void:
	pass


func on_live_begin() -> void:
	pass


func step_objective(_dt: float) -> void:
	pass


func update_contest() -> void:
	pass


func is_attacker(team: int) -> bool:
	return team == attacking_team


func defending_team() -> int:
	return RF.enemy_team(attacking_team)


## Overtime: attackers touching the objective keep the fuse alive; otherwise it burns down.
func handle_overtime(dt: float, attackers_on: bool) -> bool:
	if not overtime_active:
		return false
	if attackers_on:
		overtime_fuse = minf(overtime_fuse + dt * 0.5, data.overtime_grace)
		set_phase(Phase.OVERTIME)
		return true
	overtime_fuse -= dt
	if overtime_fuse <= 0.0:
		overtime_active = false
		return false
	return true


func end_round(round_winner: int, reason: StringName) -> void:
	round_results.append({"round": round_index, "winner": round_winner, "reason": reason, "score": score.duplicate(), "attacking": attacking_team, "elapsed": match_elapsed})
	set_phase(Phase.ROUND_END)
	phase_time = 6.0
	world.frozen = true
	announce(&"round_end", {"winner": round_winner, "reason": reason})
	on_round_end(round_winner)


func on_round_end(_round_winner: int) -> void:
	pass


func next_round_or_end() -> void:
	round_index += 1
	if round_index >= data.max_rounds or decided():
		finish_match()
	else:
		attacking_team = RF.enemy_team(attacking_team)
		begin_round()


func decided() -> bool:
	return false


func finish_match() -> void:
	winner = compute_winner()
	set_phase(Phase.MATCH_END)
	world.frozen = true
	announce(&"match_end", {"winner": winner})
	match_ended.emit(winner, summary())


func compute_winner() -> int:
	if score[0] > score[1]: return RF.Team.A
	if score[1] > score[0]: return RF.Team.B
	return -1


func summary() -> Dictionary:
	return {"mode": data.id, "score": score.duplicate(), "winner": winner, "rounds": round_results.duplicate(), "elapsed": match_elapsed}


## Spawn point for a team given current objective phase.
func spawn_transform(team: int) -> Transform3D:
	var role: StringName = &"attack" if is_attacker(team) else &"defend"
	if data.symmetric:
		role = &"a" if team == RF.Team.A else &"b"
	var rooms := layout.rooms_for(role, spawn_phase_for(team))
	if rooms.is_empty():
		return Transform3D(Basis(), Vector3(0, 2, 0))
	var r: MapLayout.SpawnRoom = rooms[rng.randi() % rooms.size()]
	if r.points.is_empty():
		return Transform3D(Basis(), r.zone.center)
	return r.points[rng.randi() % r.points.size()]


func spawn_phase_for(_team: int) -> int:
	return objective_index


func respawn_time(team: int) -> float:
	var base := data.respawn_time_attack if is_attacker(team) else data.respawn_time_defend
	return base * server.config.respawn_scale


func in_own_spawn(p: Pawn) -> bool:
	var role: StringName = &"attack" if is_attacker(p.team) else &"defend"
	if data.symmetric:
		role = &"a" if p.team == RF.Team.A else &"b"
	for r: MapLayout.SpawnRoom in layout.rooms_for(role, spawn_phase_for(p.team)):
		if r.zone and r.zone.contains(p.global_position):
			return true
	return false


func in_enemy_spawn(p: Pawn) -> bool:
	var role: StringName = &"defend" if is_attacker(p.team) else &"attack"
	if data.symmetric:
		role = &"b" if p.team == RF.Team.A else &"a"
	for r: MapLayout.SpawnRoom in layout.rooms_for(role, spawn_phase_for(RF.enemy_team(p.team))):
		if r.zone and r.zone.contains(p.global_position):
			return true
	return false


## Where the fight is now (AI + spawn logic).
func objective_position() -> Vector3:
	return Vector3.ZERO


func objective_positions_for(_team: int) -> Array[Vector3]:
	return [objective_position()]


func on_pawn_killed(_victim: Pawn, _killer: Pawn) -> void:
	pass


func announce(kind: StringName, payload: Dictionary) -> void:
	payload["kind"] = kind
	server.broadcast_event(&"mode_announce", payload)


## Compact HUD state sent in snapshots (subclasses extend).
func hud_state() -> Dictionary:
	return {"phase": phase, "time": time_remaining, "score_a": score[0], "score_b": score[1],
		"attacking": attacking_team, "overtime": overtime_active, "setup": phase_time if phase == Phase.SETUP else 0.0,
		"objective": objective_index, "round": round_index, "contest_a": contest_count[0], "contest_b": contest_count[1]}


func count_on_zone(zone: MapLayout.Zone) -> Array[int]:
	var c: Array[int] = [0, 0]
	for p: Pawn in world.pawns.values():
		p.on_objective = false
		if not p.alive:
			continue
		if zone.contains(p.global_position):
			c[p.team] += 1
			p.on_objective = true
	return c
