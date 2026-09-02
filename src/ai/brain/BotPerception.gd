class_name BotPerception
extends RefCounted
## Bounded perception. The bot knows only what it could plausibly see, hear, or be told.
## Beliefs about enemies decay, extrapolate, and can be wrong.

class Belief:
	var pawn: Pawn
	var visible: bool = false
	var noticed: bool = false          # has crossed the attention threshold this encounter
	var last_seen_tick: int = -100000
	var last_pos: Vector3
	var last_vel: Vector3
	var confidence: float = 0.0        # 0..1
	var attention: float = 0.0         # accumulates while in FOV until noticed
	var source: StringName = &"none"   # sight, sound, callout
	var first_seen_time: float = 0.0
	var threat: float = 0.0            # recent damage from this pawn
	func predicted_pos(now_tick: int) -> Vector3:
		var dt := clampf((now_tick - last_seen_tick) * RF.TICK_DT, 0.0, 1.2)
		return last_pos + last_vel * dt * 0.6

var brain: BotBrain
var beliefs: Dictionary = {}          # net_id -> Belief
var fov_deg: float = 110.0
var max_sight: float = 90.0
var under_fire_until: float = 0.0
var last_damage_dir: Vector3 = Vector3.ZERO
var last_damage_from: int = -1
var time: float = 0.0
var _slot: int = 0
var visible_enemies: Array[Pawn] = []
var known_enemies: Array[Pawn] = []   # visible or remembered with confidence > 0.2
var allies: Array[Pawn] = []
var nearest_enemy_dist: float = INF
var incoming_projectiles: Array = []  # simple: projectile positions heading our way (seen)
var recent_damage_taken: float = 0.0
var last_hp: float = 0.0


func setup(b: BotBrain) -> void:
	brain = b
	_slot = absi(b.controller.player.id) % 3
	b.world.sound_listeners.append(_on_sound)


func reset() -> void:
	beliefs.clear()
	under_fire_until = 0.0
	if brain.pawn:
		last_hp = brain.pawn.health.total()


func belief_for(p: Pawn) -> Belief:
	var b: Belief = beliefs.get(p.net_id)
	if b == null:
		b = Belief.new()
		b.pawn = p
		beliefs[p.net_id] = b
	return b


func update(dt: float) -> void:
	time += dt
	var me := brain.pawn
	var world := brain.world
	var skill := brain.skill
	# Damage awareness: taking damage is always noticed (direction known from the hit).
	var hp := me.health.total()
	if hp < last_hp - 0.5:
		recent_damage_taken += last_hp - hp
		under_fire_until = time + 1.2
		if me.last_damage_source and me.last_damage_source.alive and (world.tick - me.last_damage_source_tick) < 3:
			var src := me.last_damage_source
			var b := belief_for(src)
			b.threat += last_hp - hp
			# Getting shot tells you roughly where from; tunnel-visioned bots may ignore it.
			if not b.noticed and brain.rng.randf() > skill.tunnel_vision * 0.6:
				b.noticed = true
				b.first_seen_time = time
			b.last_pos = src.global_position + _pos_error(src.global_position.distance_to(me.global_position) * 0.15)
			b.last_vel = src.velocity
			b.last_seen_tick = maxi(b.last_seen_tick, world.tick - 6)
			b.confidence = maxf(b.confidence, 0.6)
			b.source = &"damage"
			last_damage_from = src.net_id
			last_damage_dir = (src.global_position - me.global_position).normalized()
	last_hp = hp
	recent_damage_taken = maxf(recent_damage_taken - 120.0 * dt, 0.0)
	# Staggered visual scan: each bot scans every 3rd tick.
	if (world.tick + _slot) % 3 == 0:
		_scan(dt * 3.0)
	# Callouts from teammates (delayed, lower confidence).
	var coord := brain.controller.coordinator()
	if coord and (world.tick + _slot) % 20 == 0:
		for nid: Variant in coord.shared_sightings.keys():
			var s: Dictionary = coord.shared_sightings[nid]
			var age := world.tick - int(s["tick"])
			if age < 30 or age > 240:
				continue
			if int(s["by"]) == me.net_id:
				continue
			var e := world.get_pawn(int(nid))
			if e == null or not e.alive:
				continue
			var b := belief_for(e)
			if b.visible or (world.tick - b.last_seen_tick) < 60:
				continue
			b.last_pos = s["pos"]
			b.last_vel = Vector3.ZERO
			b.last_seen_tick = maxi(b.last_seen_tick, int(s["tick"]))
			b.confidence = maxf(b.confidence, 0.45)
			b.noticed = true
			b.source = &"callout"
	# Decay
	visible_enemies.clear()
	known_enemies.clear()
	nearest_enemy_dist = INF
	for nid: Variant in beliefs.keys():
		var b: Belief = beliefs[nid]
		if not is_instance_valid(b.pawn) or not b.pawn.alive:
			b.visible = false
			b.confidence = 0.0
			b.noticed = false
			continue
		if not b.visible:
			b.confidence = maxf(b.confidence - dt / maxf(skill.memory_seconds, 1.0), 0.0)
			if b.confidence <= 0.05:
				b.noticed = false
				b.attention = maxf(b.attention - dt, 0.0)
		b.threat = maxf(b.threat - 40.0 * dt, 0.0)
		if b.visible:
			visible_enemies.append(b.pawn)
		if b.noticed and b.confidence > 0.2:
			known_enemies.append(b.pawn)
			nearest_enemy_dist = minf(nearest_enemy_dist, me.global_position.distance_to(b.predicted_pos(world.tick)))
	allies.clear()
	for p: Pawn in world.pawns.values():
		if p.alive and p.team == me.team and p != me:
			allies.append(p)


func _scan(dt: float) -> void:
	var me := brain.pawn
	var world := brain.world
	var skill := brain.skill
	var eye := me.eye_position()
	var fwd := me.aim_dir()
	var cos_half := cos(deg_to_rad(fov_deg * 0.5))
	var coord := brain.controller.coordinator()
	for p: Pawn in world.pawns.values():
		if p == me or not p.alive or p.team == me.team:
			continue
		var b := belief_for(p)
		var to := p.center() - eye
		var dist := to.length()
		var dir := to / maxf(dist, 0.001)
		var facing := dir.dot(fwd)
		var in_fov := facing > cos_half
		var can_see := false
		var invis := p.status.invisible and not p.status.revealed
		if in_fov and dist < max_sight and not invis:
			can_see = world.pawn_visible_from(eye, p)
		elif p.status.revealed and dist < max_sight * 1.5:
			can_see = true
		if can_see:
			# Attention: central, close, moving, shooting things are noticed faster.
			var salience := 1.0
			salience += clampf(1.0 - dist / max_sight, 0.0, 1.0) * 1.5
			salience += (facing - cos_half) / (1.0 - cos_half) * 1.2      # closer to center of view
			if p.velocity.length() > 2.0: salience += 0.5
			if world.tick - p.abilities.get_slot(RF.Slot.PRIMARY).last_fire_tick < 20 if p.abilities.get_slot(RF.Slot.PRIMARY) else false: salience += 1.0
			if p.hero.role == RF.Role.BULWARK: salience += 0.4
			if b.threat > 0.0: salience += 2.0
			b.attention += salience * skill.awareness * dt * 3.0
			if not b.noticed and b.attention >= 1.0:
				b.noticed = true
				b.first_seen_time = time
			if b.noticed:
				b.visible = true
				b.last_seen_tick = world.tick
				b.last_pos = p.global_position
				b.last_vel = p.velocity
				b.confidence = 1.0
				b.source = &"sight"
				if coord:
					coord.report_sighting(p, p.global_position, me)
		else:
			if b.visible:
				b.visible = false
			b.attention = maxf(b.attention - dt * 0.5, 0.0)


func _on_sound(p: Pawn, kind: StringName, loudness: float, pos: Vector3) -> void:
	var me := brain.pawn
	if me == null or not me.alive or p == me or p.team == me.team:
		return
	var dist := me.global_position.distance_to(pos)
	var reach := loudness * brain.skill.hearing * 1.6
	if dist > reach:
		return
	var b := belief_for(p)
	if b.visible:
		return
	var err := dist * 0.12 * (1.5 - brain.skill.hearing)
	b.last_pos = pos + _pos_error(err)
	b.last_vel = Vector3.ZERO
	b.last_seen_tick = maxi(b.last_seen_tick, brain.world.tick - 4)
	var conf := clampf(1.0 - dist / reach, 0.3, 0.85)
	if kind == &"footstep": conf *= 0.6
	if kind == &"ultimate": conf = 0.95
	b.confidence = maxf(b.confidence, conf)
	b.noticed = b.noticed or conf > 0.4
	b.source = &"sound"


func _pos_error(radius: float) -> Vector3:
	var r := brain.rng
	return Vector3(r.randf_range(-radius, radius), 0.0, r.randf_range(-radius, radius))


func is_under_fire() -> bool:
	return time < under_fire_until


func best_target() -> Pawn:
	return null  # decision layer chooses; perception only reports


func visible_allies_low() -> Array[Pawn]:
	var out: Array[Pawn] = []
	for a: Pawn in allies:
		if a.health.fraction() < 0.7:
			out.append(a)
	return out
