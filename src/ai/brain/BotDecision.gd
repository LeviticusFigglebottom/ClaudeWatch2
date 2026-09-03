class_name BotDecision
extends RefCounted
## Utility-based goal selection + ability policy. Goals are scored every 0.2 s from the bot's
## beliefs (never raw game state), the hero's kit, the coordinator's directive, and the bot's
## own "mistake" personality. Produces movement goals for the navigator and targets for aim.

enum Goal { IDLE, ENGAGE, HOLD_OBJECTIVE, ADVANCE, RETREAT, REGROUP, SEEK_HEALTH, SUPPORT_ALLY, FLANK, SETUP, CHASE }

var brain: BotBrain
var goal: Goal = Goal.IDLE
var goal_reason: String = ""
var target: Pawn
var support_target: Pawn
var eval_timer: float = 0.0
var position_timer: float = 0.0
var fight_position: Vector3
var has_fight_position: bool = false
var retreat_point: Vector3
var panic_until: float = 0.0
var time: float = 0.0
var kill_streak_seen: int = 0
var forgotten_slot: int = -1
var forgotten_until: float = 0.0
var last_ult_consider: float = 0.0
var ability_timers: Dictionary = {}    # slot -> next consider time
var last_goal_change: float = 0.0
var flank_point: Vector3
var _slot_offset: int = 0
var last_engage_time: float = -100.0
var chase_started: float = 0.0
var overextending: bool = false
var hero_ai: AIHeroProfile


func setup(b: BotBrain) -> void:
	brain = b
	_slot_offset = absi(b.controller.player.id) % 12


func reset() -> void:
	goal = Goal.IDLE
	target = null
	support_target = null
	has_fight_position = false
	panic_until = 0.0
	hero_ai = brain.pawn.hero.ai if brain.pawn and brain.pawn.hero.ai else AIHeroProfile.new()
	eval_timer = brain.rng.randf_range(0.0, 0.3)


func on_died() -> void:
	goal = Goal.IDLE
	target = null
	overextending = false


func update(dt: float) -> void:
	time += dt
	eval_timer -= dt
	position_timer -= dt
	var me := brain.pawn
	if eval_timer <= 0.0:
		eval_timer = 0.2 + brain.rng.randf() * 0.08
		_evaluate()
	_drive_movement(dt)
	_drive_abilities(dt)


## ---------------------------------------------------------------------------------------------

func _evaluate() -> void:
	var me := brain.pawn
	var per := brain.perception
	var skill := brain.skill
	var r := brain.rng
	var coord := brain.controller.coordinator()
	var mode := brain.world.mode
	var hp := me.health.fraction()
	var objective: Vector3 = mode.objective_position() if mode else me.global_position
	var attacking: bool = mode.is_attacker(me.team) if mode else true
	# --- Target selection from beliefs -------------------------------------------------------
	var best: Pawn = null
	var best_score := -INF
	for p: Pawn in per.known_enemies:
		var b := per.belief_for(p)
		var pos := b.predicted_pos(brain.world.tick)
		var dist := me.global_position.distance_to(pos)
		var s := 0.0
		s += b.confidence * 2.0
		if b.visible: s += 2.0
		s += clampf(1.0 - absf(dist - hero_ai.preferred_range) / maxf(hero_ai.max_effective_range, 1.0), -1.0, 1.0)
		if dist > hero_ai.max_effective_range * 1.3: s -= 2.0
		s += (1.0 - p.health.fraction()) * 1.2 if b.visible else 0.0
		if b.threat > 0.0: s += 1.0
		if coord and coord.focus_target == p.net_id: s += 1.2
		if p.hero.role == RF.Role.CONDUIT: s += 0.5
		if p.status.invulnerable: s -= 3.0
		# Tunnel vision: keep the current target even if a better one appeared.
		if p == target: s += 0.6 + skill.tunnel_vision * 1.5
		if s > best_score:
			best_score = s; best = p
	if best != target:
		target = best
		brain.aim.set_target(target if (target and (per.belief_for(target).visible or per.belief_for(target).confidence > 0.6)) else null)
	elif target and not per.belief_for(target).visible and per.belief_for(target).confidence < 0.35:
		brain.aim.set_target(null)
	elif target and per.belief_for(target).visible:
		brain.aim.set_target(target)
	# --- Situation ---------------------------------------------------------------------------
	var visible_n := per.visible_enemies.size()
	var allies_near := 0
	var ally_centroid := me.global_position
	var n := 1
	for a: Pawn in per.allies:
		if a.global_position.distance_to(me.global_position) < 15.0:
			allies_near += 1
		ally_centroid += a.global_position
		n += 1
	ally_centroid /= n
	var outnumbered := visible_n > allies_near + 1
	var panicking := time < panic_until
	if hp < skill.panic_threshold and per.is_under_fire() and not panicking and r.randf() < skill.panic_chance * 0.3:
		panic_until = time + r.randf_range(0.8, 2.0)
		panicking = true
	# Overextension after kills (a legible mistake): aggression creeps up on a streak.
	if me.kill_streak >= 2 and r.randf() < skill.overextend_bias * 0.5:
		overextending = true
	if me.kill_streak == 0 or hp < 0.5:
		overextending = false
	# --- Score goals -------------------------------------------------------------------------
	var scores: Dictionary = {}
	scores[Goal.IDLE] = 0.05
	var stance: int = coord.stance if coord else TeamCoordinator.Stance.PUSH
	var dist_obj := me.global_position.distance_to(objective)
	# Engage
	if target:
		var b := per.belief_for(target)
		var e := 0.4 + b.confidence * 0.5 + (0.5 if b.visible else 0.0)
		e += hero_ai.aggression * 0.3
		if hp > 0.6: e += 0.2
		if outnumbered and not overextending: e -= 0.5
		if stance == TeamCoordinator.Stance.STAGGER_WAIT and not b.visible: e -= 0.6
		if me.hero.role == RF.Role.CONDUIT: e -= 0.35
		if overextending: e += 0.5
		scores[Goal.ENGAGE] = e
		# Chase a fleeing low target (also a mistake vector)
		if b.visible and target.health.fraction() < 0.35 and hp > 0.4:
			scores[Goal.CHASE] = 0.5 + hero_ai.aggression * 0.4 + (0.5 if overextending else 0.0) - (0.3 if me.hero.role == RF.Role.CONDUIT else 0.0)
	# Objective
	var obj_score := 0.3
	if mode and mode.phase == ModeController.Phase.OVERTIME: obj_score += 0.8
	if attacking or (mode and mode.data.symmetric):
		obj_score += 0.3 if stance == TeamCoordinator.Stance.PUSH else 0.0
		if dist_obj > 30.0: obj_score += 0.2
	else:
		obj_score += 0.25
	if stance == TeamCoordinator.Stance.STAGGER_WAIT: obj_score -= 0.5
	if mode and mode.phase == ModeController.Phase.SETUP: obj_score = 0.6 if not attacking else 0.1
	# Teams that have to stand on the objective walk onto it (ADVANCE); teams that only have to deny
	# it take up positions around it (HOLD_OBJECTIVE).
	var occupy: bool = mode == null or bool(mode.must_occupy(me.team))
	scores[Goal.ADVANCE if occupy else Goal.HOLD_OBJECTIVE] = obj_score
	# Regroup / stagger
	var dist_team := me.global_position.distance_to(ally_centroid)
	var rg := 0.0
	if stance == TeamCoordinator.Stance.STAGGER_WAIT or stance == TeamCoordinator.Stance.GROUP:
		rg = 0.55 + skill.patience * 0.3
	if dist_team > 22.0 and per.allies.size() >= 2: rg += 0.35
	if hero_ai.sticks_to_tank > 0.5 and dist_team > 12.0: rg += 0.2
	if hero_ai.flanker: rg -= 0.3
	scores[Goal.REGROUP] = rg
	# Retreat
	var rt := 0.0
	if hp < 0.35: rt += 0.6 * hero_ai.self_preservation + 0.3
	if per.is_under_fire() and hp < 0.5: rt += 0.3
	if outnumbered and hp < 0.6: rt += 0.3
	if panicking: rt += 0.4
	if overextending: rt -= 0.3
	if me.status.has(&"striker_speed"): rt -= 0.1
	scores[Goal.RETREAT] = rt
	# Seek health
	var pack := _nearest_health_pack(me.global_position, 28.0)
	if pack != null and me.health.missing() > 60.0:
		var d: float = me.global_position.distance_to(pack.global_position)
		var sh := 0.35 + (1.0 - hp) * 0.6 - d / 40.0
		if not _healer_alive_near(me): sh += 0.2
		scores[Goal.SEEK_HEALTH] = sh
	# Support (conduits + anyone with a heal ability)
	if hero_ai.heals:
		var low := _lowest_ally(hero_ai.heal_range * 1.6)
		if low:
			var lf := low.health.fraction()
			var sup := 0.45 + (1.0 - lf) * 1.1
			if per.is_under_fire() and hp < 0.4: sup -= 0.2
			scores[Goal.SUPPORT_ALLY] = sup
			support_target = low
		else:
			support_target = null
	# Flank
	if hero_ai.flanker and target and hp > 0.55 and stance != TeamCoordinator.Stance.STAGGER_WAIT and coord and coord.alive_count >= 3:
		scores[Goal.FLANK] = 0.45 + hero_ai.aggression * 0.3
	# Setup (builders)
	if hero_ai.builds and mode and (mode.phase == ModeController.Phase.SETUP or not attacking) and visible_n == 0:
		scores[Goal.SETUP] = 0.5
	# Pick the best with a little noise (sub-optimal choices are human).
	var chosen: Goal = Goal.IDLE
	var chosen_s := -INF
	for g: Variant in scores.keys():
		var s: float = float(scores[g]) + r.randf() * 0.08 * (1.0 + skill.mistake_rate)
		# Hysteresis: prefer the current goal a bit.
		if int(g) == goal: s += 0.08
		if s > chosen_s:
			chosen_s = s; chosen = int(g) as Goal
	if chosen != goal:
		goal = chosen
		last_goal_change = time
		has_fight_position = false
		goal_reason = _reason_for(chosen, scores)
	if goal == Goal.ENGAGE or goal == Goal.CHASE:
		last_engage_time = time


func _reason_for(g: Goal, scores: Dictionary) -> String:
	return "%s (%.2f)" % [Goal.keys()[g], float(scores.get(g, 0.0))]


## ---------------------------------------------------------------------------------------------

func _drive_movement(dt: float) -> void:
	var me := brain.pawn
	var nav := brain.nav
	var per := brain.perception
	var mode := brain.world.mode
	var coord := brain.controller.coordinator()
	var r := brain.rng
	var objective: Vector3 = mode.objective_position() if mode else me.global_position
	nav.hold_position = false
	match goal:
		Goal.ENGAGE:
			nav.set_strafe(true, 1.0)
			if target == null:
				nav.clear_goal()
				return
			var b := per.belief_for(target)
			var tpos := b.predicted_pos(brain.world.tick)
			if position_timer <= 0.0 or not has_fight_position:
				position_timer = r.randf_range(0.7, 1.4)
				fight_position = _pick_fight_position(tpos, b.visible)
				has_fight_position = true
			if not b.visible and b.confidence < 0.6:
				# Investigate last known position cautiously.
				nav.set_goal(tpos, 3.0)
				nav.set_strafe(false)
			else:
				var d := me.global_position.distance_to(fight_position)
				if d > 1.5:
					nav.set_goal(fight_position, 1.0)
				else:
					nav.clear_goal()
					nav.hold_position = true
			if hero_ai.melee_brawler and b.visible:
				nav.set_goal(tpos, 1.6)
				nav.set_strafe(true, 0.6)
		Goal.CHASE:
			nav.set_strafe(false)
			if target:
				nav.set_goal(per.belief_for(target).predicted_pos(brain.world.tick), 2.0)
		Goal.HOLD_OBJECTIVE:
			var hold := _objective_hold_point(objective)
			nav.set_goal(hold, 2.0)
			nav.set_strafe(nav.at_goal(), 0.7)
			nav.hold_position = nav.at_goal()
		Goal.ADVANCE:
			var pt: Vector3 = objective
			if coord and coord.stance == TeamCoordinator.Stance.GROUP:
				pt = coord.rally_point
			if mode and mode.data.kind == ModeData.Kind.ESCORT or (mode and mode.data.kind == ModeData.Kind.HYBRID and mode.get("payload_phase")):
				pt = objective + _payload_offset()
			nav.set_goal(pt, 2.5)
			nav.set_strafe(nav.at_goal() and per.known_enemies.size() > 0, 0.6)
			nav.hold_position = nav.at_goal()
		Goal.REGROUP:
			var pt: Vector3 = coord.rally_point if coord else objective
			nav.set_goal(pt + _spread_offset(), 3.0)
			nav.set_strafe(false)
		Goal.RETREAT:
			if position_timer <= 0.0:
				position_timer = 0.8
				retreat_point = _pick_retreat_point()
			nav.set_goal(retreat_point, 1.5)
			nav.set_strafe(time < panic_until, 1.0)
			if time < panic_until and r.randf() < 0.05:
				brain.cmd.buttons |= RF.BTN_JUMP
		Goal.SEEK_HEALTH:
			var pack := _nearest_health_pack(me.global_position, 40.0)
			if pack:
				nav.set_goal(pack.global_position, 0.6)
			nav.set_strafe(false)
		Goal.SUPPORT_ALLY:
			if support_target and support_target.alive:
				var to := support_target.global_position - me.global_position
				var d := to.length()
				var want := clampf(hero_ai.heal_range * 0.55, 4.0, 12.0)
				if d > want + 2.0 or not brain.world.pawn_visible_from(me.eye_position(), support_target):
					nav.set_goal(support_target.global_position - to.normalized() * want * 0.6, 1.5)
					nav.set_strafe(false)
				else:
					nav.clear_goal()
					nav.set_strafe(true, 0.8)
					nav.hold_position = true
				# Look at the ally when we're going to heal (aim model handles enemies otherwise).
				if target == null or not per.belief_for(target).visible:
					brain.aim.set_target(null)
					brain.aim.look_at_point(support_target.center())
		Goal.FLANK:
			if position_timer <= 0.0 or flank_point == Vector3.ZERO:
				position_timer = 3.0
				flank_point = _pick_flank_point(objective)
			nav.set_goal(flank_point, 2.0)
			nav.set_strafe(false)
		Goal.SETUP:
			nav.set_goal(_objective_hold_point(objective), 2.0)
			nav.set_strafe(false)
		_:
			nav.clear_goal()
			nav.set_strafe(false)
	# Interact with own spawn: nothing; hero swaps are decided by the coordinator (rare).


func _payload_offset() -> Vector3:
	var r := brain.rng
	return Vector3(r.randf_range(-1.5, 1.5), 0, r.randf_range(-1.5, 1.5))


func _spread_offset() -> Vector3:
	var a := float(_slot_offset) / 12.0 * TAU
	return Vector3(cos(a), 0, sin(a)) * 3.0


func _objective_hold_point(objective: Vector3) -> Vector3:
	var me := brain.pawn
	var layout: MapLayout = brain.server.layout
	var r := brain.rng
	# Sample around the objective: prefer high ground for pokers, cover from the attack direction,
	# and staying within the zone for holders.
	var best := objective
	var best_s := -INF
	var enemy_dir := Vector3.ZERO
	for p: Pawn in brain.perception.known_enemies:
		enemy_dir += (brain.perception.belief_for(p).predicted_pos(brain.world.tick) - objective)
	if enemy_dir.length_squared() < 0.1 and brain.world.mode:
		var espawn: Vector3 = brain.world.mode.spawn_transform(RF.enemy_team(me.team)).origin
		enemy_dir = espawn - objective
	enemy_dir = Vector3(enemy_dir.x, 0, enemy_dir.z).normalized()
	# Stay inside the contest radius when this team has to occupy the objective, so "holding" it
	# still counts toward capture or pushing.
	var max_rad := 7.0
	var wmode: ModeController = brain.world.mode
	if wmode and wmode.must_occupy(me.team):
		max_rad = maxf(wmode.contest_radius() * 0.8, 1.5)
	for i in 10:
		var ang := (float(i) + _slot_offset * 0.37) / 10.0 * TAU
		var rad := minf(2.0 + r.randf() * 5.0, max_rad)
		if me.hero.role == RF.Role.BULWARK: rad *= 0.6
		var cand := objective + Vector3(cos(ang), 0, sin(ang)) * rad
		cand = brain.world.ground_point(cand + Vector3(0, 3, 0))
		if absf(cand.y - objective.y) > 6.0:
			continue
		var s := 0.0
		s += (cand.y - objective.y) * hero_ai.prefers_high_ground * 0.6
		var toward_enemy := Vector3(cand - objective).normalized().dot(enemy_dir)
		s -= toward_enemy * (0.8 if me.hero.role != RF.Role.BULWARK else 0.2)
		if _has_cover(cand, enemy_dir): s += 0.9 * brain.skill.positioning_iq
		s += r.randf() * 0.3
		if s > best_s:
			best_s = s; best = cand
	return best


func _has_cover(pos: Vector3, threat_dir: Vector3) -> bool:
	if threat_dir.length_squared() < 0.01:
		return false
	var from := pos + Vector3(0, 1.0, 0)
	var res := brain.world.raycast_world(from, threat_dir, 3.0, -1, false)
	return not res.is_empty()


## Choose a place to fight from: LOS to the target at a comfortable range, cover from other threats.
func _pick_fight_position(tpos: Vector3, visible: bool) -> Vector3:
	var me := brain.pawn
	var world := brain.world
	var r := brain.rng
	var best := me.global_position
	var best_s := -INF
	var to_t := tpos - me.global_position
	var dist := to_t.length()
	var ideal := hero_ai.preferred_range
	var other_threats: Array[Vector3] = []
	for p: Pawn in brain.perception.visible_enemies:
		if p != target:
			other_threats.append(p.center())
	var iq := brain.skill.positioning_iq
	var tm: TacticalMap = brain.server.tactical
	var tnodes: Array[TacticalMap.TNode] = tm.nodes_near(me.global_position, 8.0) if tm and tm.baked else []
	# Fight from on the objective when this team has to occupy it. Players brawl on the point rather
	# than backing off it, and in push nothing moves at all unless bodies are inside the robot's
	# contest radius. The pull fades with distance so bots away from the fight are not dragged in.
	var obj_pull := 0.0
	var obj_pos := Vector3.ZERO
	var obj_r := 1.0
	var wmode: ModeController = world.mode
	if wmode and wmode.must_occupy(me.team) and (wmode.phase == ModeController.Phase.LIVE or wmode.phase == ModeController.Phase.OVERTIME):
		obj_pos = wmode.objective_position()
		obj_r = maxf(wmode.contest_radius() - 0.7, 1.0)
		obj_pull = clampf(1.0 - me.global_position.distance_to(obj_pos) / 26.0, 0.0, 1.0) * 1.4
	var total := 12 + mini(tnodes.size(), 10)
	for i in total:
		var cand: Vector3
		var tnode: TacticalMap.TNode = null
		if i == 0:
			cand = me.global_position
		elif obj_pull > 0.0 and i <= 2:
			# Two candidates standing on the objective, spread so a team does not stack on one spot.
			var oa := (float(i) + _slot_offset * 1.7) / 3.0 * TAU
			cand = world.ground_point(obj_pos + Vector3(cos(oa), 0, sin(oa)) * obj_r * 0.6 + Vector3(0, 2.0, 0))
		elif i >= 12:
			tnode = tnodes[(i - 12 + _slot_offset) % tnodes.size()]
			cand = tnode.pos
		else:
			var ang := r.randf() * TAU
			var rad := r.randf_range(1.5, 7.0)
			cand = me.global_position + Vector3(cos(ang), 0, sin(ang)) * rad
			cand = world.ground_point(cand + Vector3(0, 2.0, 0))
			if absf(cand.y - me.global_position.y) > 4.0:
				continue
		var d := cand.distance_to(tpos)
		var s := 0.0
		s -= absf(d - ideal) / maxf(ideal, 1.0) * 1.2
		if d < hero_ai.min_range: s -= 1.5
		var eye := cand + Vector3(0, me.movement.profile.eye_height, 0)
		var los := world.has_line_of_sight(eye, tpos + Vector3(0, 1.0, 0))
		if los: s += 1.0
		else: s -= 1.0
		# Cover from other threats matters more to smart bots.
		var exposed := 0
		for t: Vector3 in other_threats:
			if world.has_line_of_sight(eye, t):
				exposed += 1
		s -= exposed * 0.5 * iq
		s += (cand.y - me.global_position.y) * 0.25 * hero_ai.prefers_high_ground
		if tnode != null:
			# Baked knowledge: cover toward the target direction and low openness are worth a lot to smart bots.
			if tm.has_cover(tnode, (tpos - cand)): s += 0.6 * iq
			s += (1.0 - tnode.openness) * 0.4 * iq
			s += tnode.height * 0.1 * hero_ai.prefers_high_ground
		if obj_pull > 0.0:
			var od := cand.distance_to(obj_pos)
			s += obj_pull * (1.0 if od <= obj_r else -clampf((od - obj_r) / 6.0, 0.0, 1.0))
		if i == 0: s += 0.35   # inertia
		# Bulwarks stand in front of allies; supports behind.
		if me.hero.role == RF.Role.BULWARK: s -= absf(d - ideal) * 0.05
		if me.hero.role == RF.Role.CONDUIT:
			var near_ally := false
			for a: Pawn in brain.perception.allies:
				if a.global_position.distance_to(cand) < 9.0: near_ally = true
			if near_ally: s += 0.7
		if s > best_s:
			best_s = s; best = cand
	return best


func _pick_retreat_point() -> Vector3:
	var me := brain.pawn
	var world := brain.world
	var per := brain.perception
	var threat := Vector3.ZERO
	for p: Pawn in per.known_enemies:
		threat += per.belief_for(p).predicted_pos(world.tick) - me.global_position
	if threat.length_squared() < 0.1:
		threat = per.last_damage_dir
	var away := -Vector3(threat.x, 0, threat.z).normalized()
	# Prefer toward allies / healers / own spawn.
	var toward := Vector3.ZERO
	var healer: Pawn = null
	for a: Pawn in per.allies:
		if a.hero.ai and a.hero.ai.heals:
			healer = a
	if healer:
		toward = (healer.global_position - me.global_position)
	elif brain.world.mode:
		toward = brain.world.mode.spawn_transform(me.team).origin - me.global_position
	toward = Vector3(toward.x, 0, toward.z).normalized()
	var dir := (away * 1.0 + toward * 0.8).normalized()
	var best := me.global_position + dir * 8.0
	var best_s := -INF
	for i in 8:
		var ang := (float(i) / 8.0 - 0.5) * PI
		var d := dir.rotated(Vector3.UP, ang)
		var cand := world.ground_point(me.global_position + d * brain.rng.randf_range(6.0, 12.0) + Vector3(0, 2, 0))
		var s := d.dot(dir) * 1.5
		var eye := cand + Vector3(0, 1.5, 0)
		var seen := 0
		for p: Pawn in per.visible_enemies:
			if world.has_line_of_sight(eye, p.center()):
				seen += 1
		s -= seen * 0.8
		var pack := _nearest_health_pack(cand, 10.0)
		if pack: s += 0.6
		if s > best_s:
			best_s = s; best = cand
	return best


func _pick_flank_point(objective: Vector3) -> Vector3:
	var layout: MapLayout = brain.server.layout
	var me := brain.pawn
	var r := brain.rng
	if layout and not layout.flank_routes.is_empty():
		var route: PackedVector3Array = layout.flank_routes[r.randi() % layout.flank_routes.size()]
		if route.size() > 0:
			# Pick the far end of the route that's closer to the objective.
			var a := route[0]; var b := route[route.size() - 1]
			return b if b.distance_to(objective) < a.distance_to(objective) else a
	var tpos := target.global_position if target else objective
	var side := Vector3(-(tpos - me.global_position).z, 0, (tpos - me.global_position).x).normalized()
	return brain.world.ground_point(tpos + side * (1.0 if r.randf() < 0.5 else -1.0) * 12.0 + Vector3(0, 2, 0))


func _nearest_health_pack(pos: Vector3, max_d: float) -> HealthPack:
	var best: HealthPack = null
	var best_d := max_d
	for pk: Variant in brain.world.pickups:
		var hp := pk as HealthPack
		if hp == null or not hp.available:
			continue
		var d := hp.global_position.distance_to(pos)
		if d < best_d:
			best_d = d; best = hp
	return best


func _lowest_ally(range_: float) -> Pawn:
	var me := brain.pawn
	var best: Pawn = null
	var best_f := 0.85
	for a: Pawn in brain.perception.allies:
		var d := a.global_position.distance_to(me.global_position)
		if d > range_:
			continue
		var f := a.health.fraction() + d / range_ * 0.15
		if a.hero.role == RF.Role.BULWARK: f -= 0.08
		if f < best_f:
			best_f = f; best = a
	return best


func _healer_alive_near(me: Pawn) -> bool:
	for a: Pawn in brain.perception.allies:
		if a.hero.ai and a.hero.ai.heals and a.global_position.distance_to(me.global_position) < 18.0:
			return true
	return false


## ---------------------------------------------------------------------------------------------
## Ability policy: per slot, decide from AI hints whether now is a good moment.

func _drive_abilities(dt: float) -> void:
	var me := brain.pawn
	var cmd := brain.cmd
	var per := brain.perception
	var skill := brain.skill
	var r := brain.rng
	var coord := brain.controller.coordinator()
	# Weapon trigger from the aim model.
	var trigger_slot := brain.aim.trigger_slot
	if brain.aim.want_fire and me.abilities.get_slot(trigger_slot):
		cmd.buttons |= RF.SLOT_BUTTONS[trigger_slot]
	# Healing weapons: hold primary/secondary on the ally.
	if goal == Goal.SUPPORT_ALLY and support_target and support_target.alive:
		var heal_slot := _find_slot_with_intent(AbilityAIHints.Intent.HEAL, true)
		if heal_slot >= 0:
			var ab := me.abilities.get_slot(heal_slot)
			var to := support_target.center() - me.eye_position()
			var facing := to.normalized().dot(me.aim_dir())
			if facing > 0.94 and to.length() <= (ab.data.ai.max_range if ab.data.ai else 15.0) and (brain.aim.target == null or not per.belief_for(brain.aim.target).visible):
				if ab.data.trigger == AbilityData.Trigger.HOLD or ab.data.trigger == AbilityData.Trigger.CHANNEL or ab.data.trigger == AbilityData.Trigger.TOGGLE:
					cmd.buttons |= RF.SLOT_BUTTONS[heal_slot]
				elif ab.is_ready():
					cmd.buttons |= RF.SLOT_BUTTONS[heal_slot]
	# Reload when safe.
	var prim := me.abilities.get_slot(RF.Slot.PRIMARY)
	if prim and prim.uses_ammo() and prim.ammo < prim.data.ammo * 0.3 and not brain.aim.want_fire and prim.reload_remaining <= 0.0:
		if r.randf() < 0.3:
			cmd.buttons |= RF.BTN_RELOAD
	# "Forgot an ability" mistake window.
	if forgotten_slot >= 0 and time > forgotten_until:
		forgotten_slot = -1
	if forgotten_slot < 0 and r.randf() < skill.mistake_rate * 0.002:
		forgotten_slot = [RF.Slot.ABILITY_1, RF.Slot.ABILITY_2, RF.Slot.ABILITY_3][r.randi() % 3]
		forgotten_until = time + r.randf_range(4.0, 12.0)
	# Cooldown abilities
	for slot: int in [RF.Slot.ABILITY_1, RF.Slot.ABILITY_2, RF.Slot.ABILITY_3, RF.Slot.SECONDARY]:
		var ab := me.abilities.get_slot(slot)
		if ab == null or ab.data.ai == null:
			continue
		if slot == forgotten_slot:
			continue
		if slot == RF.Slot.SECONDARY and (ab.data.trigger == AbilityData.Trigger.HOLD or ab.data.ai.spam_ok):
			# Secondary weapons handled by aim (alt fire) below.
			continue
		var next_t: float = float(ability_timers.get(slot, 0.0))
		if time < next_t:
			continue
		if not ab.is_ready():
			continue
		var u := _ability_utility(ab)
		if u <= 0.0:
			continue
		# Discipline: good moments are taken with probability; poor ones sometimes anyway.
		var p := u * skill.cooldown_discipline + (1.0 - skill.cooldown_discipline) * 0.15
		if r.randf() < p:
			cmd.buttons |= RF.SLOT_BUTTONS[slot]
			ability_timers[slot] = time + 0.5
		else:
			ability_timers[slot] = time + r.randf_range(0.25, 0.6)
	# Secondary fire as a weapon alternative (e.g. Vesper's scope, shotgun alt).
	var sec := me.abilities.get_slot(RF.Slot.SECONDARY)
	if sec and sec.data.ai and sec.data.is_weapon and target and per.belief_for(target).visible:
		var d := me.global_position.distance_to(target.global_position)
		if d >= sec.data.ai.min_range and d <= sec.data.ai.max_range and brain.aim.want_fire:
			if sec.data.ai.ideal_range > (prim.data.ai.ideal_range if prim and prim.data.ai else 10.0) and d > (prim.data.ai.ideal_range if prim and prim.data.ai else 10.0):
				cmd.buttons &= ~RF.BTN_PRIMARY
				cmd.buttons |= RF.BTN_SECONDARY
	# Melee when very close
	if target and per.belief_for(target).visible and me.global_position.distance_to(target.global_position) < 2.2 and r.randf() < 0.08:
		cmd.buttons |= RF.BTN_MELEE
	# Ultimate
	_consider_ultimate(dt)


func _find_slot_with_intent(intent: int, target_ally: bool) -> int:
	var me := brain.pawn
	for slot in [RF.Slot.PRIMARY, RF.Slot.SECONDARY, RF.Slot.ABILITY_1, RF.Slot.ABILITY_2, RF.Slot.ABILITY_3]:
		var ab := me.abilities.get_slot(slot)
		if ab and ab.data.ai and ab.data.ai.intent == intent and ab.data.ai.target_ally == target_ally:
			return slot
	return -1


func _enemies_within(pos: Vector3, radius: float, visible_only: bool = true) -> int:
	var n := 0
	var per := brain.perception
	for p: Pawn in (per.visible_enemies if visible_only else per.known_enemies):
		if per.belief_for(p).predicted_pos(brain.world.tick).distance_to(pos) <= radius:
			n += 1
	return n


func _allies_within(pos: Vector3, radius: float) -> int:
	var n := 0
	for a: Pawn in brain.perception.allies:
		if a.global_position.distance_to(pos) <= radius:
			n += 1
	return n


func _ability_utility(ab: Ability) -> float:
	var me := brain.pawn
	var h := ab.data.ai
	var per := brain.perception
	var hp := me.health.fraction()
	var tvis := target != null and per.belief_for(target).visible
	var tdist := me.global_position.distance_to(target.global_position) if target else INF
	var u := 0.0
	match h.intent:
		AbilityAIHints.Intent.DAMAGE, AbilityAIHints.Intent.CROWD_CONTROL:
			if tvis and tdist >= h.min_range and tdist <= h.max_range:
				u = 0.5 + h.cast_priority * 0.5
				if h.intent == AbilityAIHints.Intent.CROWD_CONTROL and tdist < h.ideal_range * 1.2: u += 0.3
				if target.health.fraction() < 0.4: u += 0.2
				if h.needs_line_of_sight and not brain.world.pawn_visible_from(me.eye_position(), target): u = 0.0
		AbilityAIHints.Intent.HEAL:
			var low := _lowest_ally(h.max_range) if h.target_ally else me
			if low and low.health.fraction() < 0.7:
				u = 0.4 + (1.0 - low.health.fraction()) * 0.9
			elif not h.target_ally and hp < 0.6:
				u = 0.4 + (1.0 - hp)
		AbilityAIHints.Intent.ESCAPE:
			if hp < maxf(h.use_when_health_below, 0.35) and per.is_under_fire():
				u = 0.9
			elif goal == Goal.RETREAT and per.is_under_fire():
				u = 0.6
		AbilityAIHints.Intent.MOBILITY:
			if goal == Goal.CHASE or goal == Goal.FLANK:
				u = 0.5
			elif goal == Goal.ENGAGE and target and tdist > h.ideal_range * 1.5 and hp > 0.5:
				u = 0.4 + brain.pawn.hero.ai.aggression * 0.3 if brain.pawn.hero.ai else 0.4
			elif goal == Goal.RETREAT and hp < 0.4:
				u = 0.7
			elif goal == Goal.ADVANCE and brain.nav.has_goal and me.global_position.distance_to(brain.nav.goal) > 20.0:
				u = 0.25
		AbilityAIHints.Intent.ENGAGE:
			if tvis and tdist <= h.max_range and hp > 0.55 and (goal == Goal.ENGAGE or goal == Goal.CHASE):
				u = 0.4 + brain.pawn.hero.ai.aggression * 0.4 if brain.pawn.hero.ai else 0.4
				if _allies_within(me.global_position, 12.0) >= 2: u += 0.2
		AbilityAIHints.Intent.DEFENSIVE:
			if per.is_under_fire() and (hp < maxf(h.use_when_health_below, 0.6) or per.recent_damage_taken > 80.0):
				u = 0.7
			elif _enemies_within(me.global_position, 12.0) >= 2:
				u = 0.35
		AbilityAIHints.Intent.UTILITY, AbilityAIHints.Intent.REVEAL:
			if per.known_enemies.size() > 0 or goal == Goal.ADVANCE:
				u = 0.25 + h.cast_priority * 0.3
		AbilityAIHints.Intent.BUFF_ALLIES:
			var n := _allies_within(me.global_position, h.max_range)
			if n >= maxi(h.needs_allies_in_radius, 1) and (per.known_enemies.size() > 0):
				u = 0.4 + n * 0.12
		AbilityAIHints.Intent.ZONE:
			var obj: Vector3 = brain.world.mode.objective_position() if brain.world.mode else me.global_position
			var n := _enemies_within(obj, h.max_range * 0.6, false)
			if n >= maxi(h.needs_enemies_in_radius, 1):
				u = 0.4 + n * 0.15
			elif tvis and tdist <= h.max_range:
				u = 0.3
	if h.needs_enemies_in_radius > 0 and _enemies_within(me.global_position, h.max_range, false) < h.needs_enemies_in_radius:
		u *= 0.3
	return clampf(u, 0.0, 1.0)


func _consider_ultimate(dt: float) -> void:
	var me := brain.pawn
	var ult := me.abilities.get_slot(RF.Slot.ULTIMATE)
	if ult == null or not ult.is_ready():
		return
	if time - last_ult_consider < 0.35:
		return
	last_ult_consider = time
	var skill := brain.skill
	var r := brain.rng
	var coord := brain.controller.coordinator()
	var per := brain.perception
	var h := ult.data.ai if ult.data.ai else AbilityAIHints.new()
	var style: StringName = brain.pawn.hero.ai.ult_style if brain.pawn.hero.ai else &"engage"
	var min_targets := maxi(h.needs_enemies_in_radius, brain.pawn.hero.ai.ult_min_targets if brain.pawn.hero.ai else 1)
	var enemies := _enemies_within(me.global_position, h.max_range, false)
	var allies := _allies_within(me.global_position, h.max_range)
	var u := 0.0
	match h.intent:
		AbilityAIHints.Intent.DAMAGE, AbilityAIHints.Intent.ZONE, AbilityAIHints.Intent.CROWD_CONTROL, AbilityAIHints.Intent.ENGAGE:
			if enemies >= min_targets: u = 0.5 + (enemies - min_targets) * 0.2
			if target and per.belief_for(target).visible and enemies >= 1: u += 0.15
		AbilityAIHints.Intent.HEAL, AbilityAIHints.Intent.DEFENSIVE, AbilityAIHints.Intent.BUFF_ALLIES:
			var low := 0
			for a: Pawn in per.allies:
				if a.global_position.distance_to(me.global_position) <= h.max_range and a.health.fraction() < 0.5:
					low += 1
			if me.health.fraction() < 0.5: low += 1
			if low >= maxi(h.needs_allies_in_radius, 2) or (coord and coord.enemy_used_ult_recently(&"engage", 120)):
				u = 0.6 + low * 0.15
			elif allies >= 3 and per.visible_enemies.size() >= 3:
				u = 0.3
		AbilityAIHints.Intent.REVEAL, AbilityAIHints.Intent.UTILITY, AbilityAIHints.Intent.MOBILITY:
			if per.known_enemies.size() >= 2 and (goal == Goal.ENGAGE or goal == Goal.ADVANCE):
				u = 0.5
		AbilityAIHints.Intent.ESCAPE:
			if me.health.fraction() < 0.3 and per.is_under_fire(): u = 0.9
	# Coordinator: combos and stacking
	if coord:
		if coord.should_hold_ult(brain.controller.player):
			u *= 0.15
		if style == &"combo_payoff" and coord.ult_plan.size() >= 2 and int(coord.ult_plan[0]) != brain.controller.player.id:
			var enabler_used := brain.server.tick - int(coord.get_meta("last_engage_ult", -10000)) < 180
			if not enabler_used:
				u *= 0.3
		if style == &"counter" and coord.enemy_used_ult_recently(&"engage", 90):
			u = maxf(u, 0.9)
	# Human-shaped mistakes: panic ults, early ults, holding too long.
	if time < panic_until and r.randf() < 0.05:
		u = 1.0
	if u < 0.5 and r.randf() < (1.0 - skill.ult_discipline) * 0.01:
		u = 1.0
	var pressed := u >= 0.5 and r.randf() < (0.35 + skill.ult_discipline * 0.6)
	if pressed:
		brain.cmd.buttons |= RF.BTN_ULTIMATE
		last_ult_consider = time + 1.0
