class_name TeamCoordinator
extends Node
## Team-level strategy for one side: composition, rally points, focus targets, ult sequencing.
## Bots read `directive` each think; the coordinator re-plans at a low rate from bounded team knowledge.

enum Stance { GROUP, PUSH, HOLD, RETREAT, STAGGER_WAIT, FLANK_SPLIT }

var server: GameServer
var team: int = RF.Team.A
var stance: Stance = Stance.GROUP
var rally_point: Vector3 = Vector3.ZERO
var focus_target: int = -1          # net_id
var ult_plan: Array = []            # [player id, ...] order to commit
var ult_hold: Dictionary = {}       # player id -> true (hold for combo)
var enemy_comp: Array[StringName] = []
var last_plan_time: float = 0.0
var plan_interval: float = 0.75
var shared_sightings: Dictionary = {}   # enemy net_id -> {pos, tick, by}
var alive_count: int = 0
var enemy_alive_estimate: int = 5
var engage_threshold: float = 0.0
var fight_state: StringName = &"neutral"
var _time: float = 0.0
var rng := RandomNumberGenerator.new()
var comp_plan: Array[StringName] = []
var last_death_tick: int = -10000
var team_ult_ready: int = 0
var enemy_ults_seen: Dictionary = {}    # hero id -> tick used
var directive_reason: String = ""


func setup(s: GameServer, t: int) -> void:
	server = s
	team = t
	rng.seed = hash(str(s.config.seed, t))


## Composition: fill roles 1/2/2 with synergy-aware picks; respond to enemy comp on swaps.
func pick_hero_for(ps: PlayerState) -> StringName:
	var lock: Variant = server.config.bot_hero_lock.get(team, null)
	if lock != null:
		var taken: Array[StringName] = []
		for other: PlayerState in server.team_players(team):
			if other != ps and other.hero_id != &"":
				taken.append(other.hero_id)
		for h: Variant in lock:
			if not taken.has(StringName(h)) or server.config.allow_hero_duplicates:
				return StringName(h)
	return HeroPicker.pick(server, team, ps, rng)


func step(dt: float) -> void:
	_time += dt
	if _time - last_plan_time < plan_interval:
		return
	last_plan_time = _time
	_plan()


func report_sighting(enemy: Pawn, pos: Vector3, by: Pawn) -> void:
	shared_sightings[enemy.net_id] = {"pos": pos, "tick": server.tick, "by": by.net_id, "hero": enemy.hero_id()}


func _plan() -> void:
	var mode := server.mode
	if mode == null:
		return
	var mine := server.team_players(team)
	alive_count = 0
	team_ult_ready = 0
	var dead_recent := 0
	var positions: Array[Vector3] = []
	var lowest_hp := 1.0
	for ps: PlayerState in mine:
		if ps.pawn and ps.pawn.alive:
			alive_count += 1
			positions.append(ps.pawn.global_position)
			lowest_hp = minf(lowest_hp, ps.pawn.health.fraction())
			if ps.pawn.ult_fraction() >= 1.0:
				team_ult_ready += 1
		elif ps.pawn and (server.tick - ps.pawn.death_tick) < 600:
			dead_recent += 1
	# Enemy strength from shared sightings (decays).
	var enemy_seen := 0
	for nid: Variant in shared_sightings.keys():
		var s: Dictionary = shared_sightings[nid]
		if server.tick - int(s["tick"]) < 300:
			enemy_seen += 1
	var enemy_team := RF.enemy_team(team)
	var enemies_dead := 0
	for ps: PlayerState in server.team_players(enemy_team):
		if ps.pawn and not ps.pawn.alive and (server.tick - ps.pawn.death_tick) < 480:
			enemies_dead += 1    # kills are announced (kill feed) so this is legitimately known
	enemy_alive_estimate = clampi(RF.TEAM_SIZE - enemies_dead, 0, RF.TEAM_SIZE)
	var objective := mode.objective_position()
	var attacking := mode.is_attacker(team)
	var total := mine.size()
	# Stance selection
	var prev := stance
	if alive_count <= maxi(total / 2, 1) and dead_recent >= 2:
		stance = Stance.STAGGER_WAIT
		rally_point = _staging_point(objective)
		directive_reason = "staggered: waiting for respawns"
	elif enemy_alive_estimate <= 2 and alive_count >= 4:
		stance = Stance.PUSH
		rally_point = objective
		directive_reason = "numbers advantage: push"
	elif alive_count >= total - 1 and (attacking or mode.data.symmetric):
		stance = Stance.PUSH if _grouped(positions, 14.0) else Stance.GROUP
		rally_point = objective if stance == Stance.PUSH else _staging_point(objective)
		directive_reason = "grouped push" if stance == Stance.PUSH else "grouping before push"
	elif not attacking and not mode.data.symmetric:
		# Symmetric modes have no defender: both sides want the same thing from the same place, so
		# they must follow the same stance ladder. Team B used to fall through to HOLD here purely
		# because attacking_team defaults to A, which gave the two teams different behaviour in
		# Push and Control.
		stance = Stance.HOLD
		rally_point = _hold_point(objective)
		directive_reason = "holding objective"
	else:
		stance = Stance.GROUP
		rally_point = _staging_point(objective)
		directive_reason = "regrouping"
	if stance != prev:
		server.broadcast_event(&"bot_directive", {"team": team, "stance": stance, "reason": directive_reason}, team)
	# Focus target: lowest-health visible enemy, prefer supports and isolated targets.
	focus_target = -1
	var best_score := -INF
	for nid: Variant in shared_sightings.keys():
		var s: Dictionary = shared_sightings[nid]
		if server.tick - int(s["tick"]) > 120:
			continue
		var e := server.world.get_pawn(int(nid))
		if e == null or not e.alive:
			continue
		var sc := (1.0 - e.health.fraction()) * 2.0
		if e.hero.role == RF.Role.CONDUIT: sc += 0.8
		elif e.hero.role == RF.Role.STRIKER: sc += 0.4
		var iso := INF
		for ps: PlayerState in server.team_players(enemy_team):
			if ps.pawn and ps.pawn.alive and ps.pawn != e:
				iso = minf(iso, ps.pawn.global_position.distance_to(e.global_position))
		if iso > 12.0: sc += 0.6
		if sc > best_score:
			best_score = sc; focus_target = e.net_id
	_plan_ults()


func _grouped(positions: Array[Vector3], radius: float) -> bool:
	if positions.size() < 2:
		return true
	var c := Vector3.ZERO
	for p: Vector3 in positions: c += p
	c /= positions.size()
	var n := 0
	for p: Vector3 in positions:
		if p.distance_to(c) <= radius:
			n += 1
	return n >= positions.size() - 1


func _staging_point(objective: Vector3) -> Vector3:
	var spawn := server.mode.spawn_transform(team).origin
	var dir := (objective - spawn)
	var dist := dir.length()
	if dist < 1.0:
		return objective
	var t := clampf(1.0 - 24.0 / dist, 0.25, 0.85)
	var pt := spawn + dir * t
	return server.world.ground_point(pt + Vector3(0, 2, 0))


func _hold_point(objective: Vector3) -> Vector3:
	# Teams that must occupy the objective rally on it, not 4 m behind it: in push that offset put
	# the whole team outside the robot's contest radius, so holding the robot never moved it.
	if server.mode.must_occupy(team):
		return objective
	var spawn := server.mode.spawn_transform(team).origin
	var dir := (spawn - objective)
	if dir.length() < 1.0:
		return objective
	return objective + dir.normalized() * 4.0


## Ultimate sequencing: enablers first, then payoffs; hold when the enemy just used a defensive ult.
func _plan_ults() -> void:
	ult_plan.clear()
	ult_hold.clear()
	var ready: Array[PlayerState] = []
	for ps: PlayerState in server.team_players(team):
		if ps.pawn and ps.pawn.alive and ps.pawn.ult_fraction() >= 1.0:
			ready.append(ps)
	if ready.is_empty():
		return
	var enablers: Array[PlayerState] = []
	var payoffs: Array[PlayerState] = []
	var others: Array[PlayerState] = []
	for ps: PlayerState in ready:
		var h := Registry.hero(ps.hero_id)
		var style: StringName = h.ai.ult_style if h and h.ai else &"engage"
		match style:
			&"combo_enabler": enablers.append(ps)
			&"combo_payoff": payoffs.append(ps)
			_: others.append(ps)
	# A payoff waits for an enabler that's ready; an enabler goes when a payoff is ready or the fight is on.
	if not enablers.is_empty() and not payoffs.is_empty():
		ult_plan.append(enablers[0].id)
		ult_plan.append(payoffs[0].id)
		ult_hold[payoffs[0].id] = true
	elif not payoffs.is_empty() and enablers.is_empty():
		# Check if an enabler on the team is close to ready: hold briefly.
		for ps: PlayerState in server.team_players(team):
			var h := Registry.hero(ps.hero_id)
			if h and h.ai and h.ai.ult_style == &"combo_enabler" and ps.pawn and ps.pawn.alive and ps.pawn.ult_fraction() > 0.8:
				ult_hold[payoffs[0].id] = true
	for ps: PlayerState in others:
		ult_plan.append(ps.id)
	# Don't stack: if a teammate committed an engage ult in the last 4 s, hold other engage ults.
	if server.tick - int(get_meta("last_engage_ult", -10000)) < 240:
		for ps: PlayerState in others:
			var h := Registry.hero(ps.hero_id)
			if h and h.ai and h.ai.ult_style == &"engage":
				ult_hold[ps.id] = true


func on_event(kind: StringName, pl: Dictionary) -> void:
	match kind:
		&"ability":
			if pl.get("ult", false) and pl.get("phase", &"") == &"activate":
				var p := server.world.get_pawn(int(pl["pawn"]))
				if p == null:
					return
				if p.team == team:
					var h := p.hero
					if h.ai and h.ai.ult_style == &"engage":
						set_meta("last_engage_ult", server.tick)
					if h.ai and h.ai.ult_style == &"combo_enabler":
						# Release payoff holds: the enabler went in.
						ult_hold.clear()
				else:
					enemy_ults_seen[p.hero_id()] = server.tick
		&"kill":
			var v := server.world.get_pawn(int(pl["victim"]))
			if v and v.team == team:
				last_death_tick = server.tick


func should_hold_ult(ps: PlayerState) -> bool:
	return ult_hold.has(ps.id)


func enemy_used_ult_recently(style: StringName, within_ticks: int = 300) -> bool:
	for hid: Variant in enemy_ults_seen.keys():
		var h := Registry.hero(StringName(hid))
		if h and h.ai and h.ai.ult_style == style and server.tick - int(enemy_ults_seen[hid]) < within_ticks:
			return true
	return false


func is_ally_dead_recently(within: int = 300) -> bool:
	return server.tick - last_death_tick < within
