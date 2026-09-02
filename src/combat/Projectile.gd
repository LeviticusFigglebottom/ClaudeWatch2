class_name Projectile
extends Node3D
## Server-simulated projectile with analytic sweeps against the world and pawn hitboxes.
## Clients mirror it visually from the spawn event (same kinematics), so no per-tick sync.

var id: int = 0
var owner_pawn: Pawn
var team: int = RF.Team.A
var world: SimWorld
var ability_id: StringName = &""
var vel: Vector3 = Vector3.ZERO
var gravity: float = 0.0
var radius: float = 0.1
var lifetime: float = 5.0
var age: float = 0.0
var damage: float = 0.0
var damage_type: RF.DamageType = RF.DamageType.PROJECTILE
var headshot_enabled: bool = false
var splash_radius: float = 0.0
var splash_damage: float = 0.0
var splash_min_fraction: float = 0.3
var self_knockback: float = 0.0
var knockback: float = 0.0
var pierce: bool = false
var bounces: int = 0
var bounce_damping: float = 0.8
var homing_strength: float = 0.0
var homing_target: Pawn
var sticky: bool = false
var stuck: bool = false
var stuck_to: Node3D
var stuck_offset: Vector3
var falloff_start: float = 0.0
var falloff_end: float = 0.0
var falloff_min: float = 1.0
var on_hit_effects: Array[AbilityEffect] = []
var on_expire_effects: Array[AbilityEffect] = []
var on_bounce_effects: Array[AbilityEffect] = []
var hit_status: StatusData
var visual_id: StringName = &""
var rewind_tick: int = -1
var hits_done: Dictionary = {}     # net_id -> true (pierce)
var ctx_seed: int = 0
var start_pos: Vector3
var traveled: float = 0.0
var explode_on_expire: bool = false
var affects_barriers: bool = true
var data: Dictionary = {}          # ability-specific payload for effects
var predicted: bool = false        # client-side visual only
var trail_node: Node3D


func setup(w: SimWorld, owner_p: Pawn) -> void:
	world = w
	owner_pawn = owner_p
	team = owner_p.team if owner_p else RF.Team.NONE


func step(dt: float) -> void:
	age += dt
	if stuck:
		if is_instance_valid(stuck_to):
			global_position = stuck_to.global_position + stuck_offset
		if age >= lifetime:
			_expire()
		return
	if age >= lifetime:
		_expire()
		return
	if homing_strength > 0.0 and is_instance_valid(homing_target) and homing_target.alive:
		var to := (homing_target.center() - global_position).normalized()
		var speed := vel.length()
		vel = vel.normalized().slerp(to, clampf(homing_strength * dt, 0.0, 1.0)) * speed
	vel.y -= gravity * dt
	var motion := vel * dt
	var dist := motion.length()
	if dist <= 0.00001:
		return
	var dir := motion / dist
	var from := global_position
	# World sweep
	var wres := world.raycast_world(from, dir, dist + radius, team, affects_barriers)
	var wdist: float = wres.get("distance", INF)
	# Pawn sweep (thick ray approximated by radius-inflated hitboxes)
	var best_pawn: HitboxSet.HitResult = null
	if not predicted:
		for p: Pawn in world.pawns.values():
			if not p.alive or p == owner_pawn or p.team == team:
				continue
			if hits_done.has(p.net_id):
				continue
			var r := p.hitboxes.raycast(from, dir, dist + radius, rewind_tick if age < 0.2 else -1)
			if r.hit and r.distance < wdist and (best_pawn == null or r.distance < best_pawn.distance):
				best_pawn = r
	if best_pawn != null:
		_hit_pawn(best_pawn, dir)
		if pierce:
			global_position = from + dir * dist
			hits_done[best_pawn.pawn.net_id] = true
			return
		return
	if wdist < INF and wdist <= dist + radius:
		var point: Vector3 = wres["point"]
		var normal: Vector3 = wres["normal"]
		global_position = point + normal * radius * 0.5
		traveled += wdist
		if wres.get("barrier", null) != null:
			_hit_barrier(wres["barrier"] as Node, point, normal, dir)
			return
		if bounces > 0:
			bounces -= 1
			vel = vel.bounce(normal) * bounce_damping
			for e: AbilityEffect in on_bounce_effects:
				_run(e, point, normal, null)
			world.on_projectile_bounce(self, point, normal)
			return
		if sticky:
			stuck = true
			stuck_to = wres.get("collider", null) as Node3D
			if stuck_to:
				stuck_offset = global_position - stuck_to.global_position
			world.on_projectile_stuck(self, point, normal)
			return
		_impact(point, normal, dir, null)
		return
	global_position = from + motion
	traveled += dist


func _hit_pawn(r: HitboxSet.HitResult, dir: Vector3) -> void:
	global_position = r.point
	if sticky and not stuck:
		stuck = true
		stuck_to = r.pawn
		stuck_offset = r.point - r.pawn.global_position
		world.on_projectile_stuck(self, r.point, r.normal)
		return
	_impact(r.point, r.normal, dir, r)


func _hit_barrier(barrier: Node, point: Vector3, normal: Vector3, dir: Vector3) -> void:
	if barrier.has_method("absorb"):
		barrier.call("absorb", damage, owner_pawn)
	if splash_radius > 0.0:
		_splash(point)
	world.on_projectile_impact(self, point, normal, null)
	queue_free_safe()


func _impact(point: Vector3, normal: Vector3, dir: Vector3, r: HitboxSet.HitResult) -> void:
	if r != null and r.pawn != null and damage > 0.0:
		var ev := DamageEvent.new()
		ev.source = owner_pawn; ev.target = r.pawn; ev.amount = damage * _falloff_mult()
		ev.type = damage_type; ev.ability_id = ability_id
		ev.headshot = headshot_enabled and r.part == &"head"
		ev.position = point; ev.direction = dir; ev.knockback = knockback; ev.tick = world.tick
		world.apply_damage(ev)
		if hit_status and ev.dealt > 0.0:
			r.pawn.status.apply(hit_status, owner_pawn)
		if owner_pawn:
			owner_pawn.stats.shots_hit += 1
			if ev.headshot: owner_pawn.stats.headshots += 1
	if splash_radius > 0.0:
		_splash(point, r.pawn if r else null)
	for e: AbilityEffect in on_hit_effects:
		_run(e, point, normal, r.pawn if r else null)
	world.on_projectile_impact(self, point, normal, r.pawn if r else null)
	queue_free_safe()


func _splash(center_pos: Vector3, direct: Pawn = null) -> void:
	for p: Pawn in world.pawns.values():
		if not p.alive:
			continue
		if p.team == team and p != owner_pawn:
			continue
		var closest := p.hitboxes.closest_point(center_pos)
		var d := closest.distance_to(center_pos)
		if d > splash_radius:
			continue
		if not world.has_line_of_sight(center_pos, closest, RF.L_WORLD):
			continue
		var frac := 1.0 - clampf(d / splash_radius, 0.0, 1.0) * (1.0 - splash_min_fraction)
		if p == owner_pawn:
			if self_knockback > 0.0:
				var dir := (p.center() - center_pos).normalized()
				p.apply_knockback(dir * self_knockback * frac)
			continue
		if p == direct:
			continue   # no double-dip on direct hit
		var ev := DamageEvent.new()
		ev.source = owner_pawn; ev.target = p; ev.amount = splash_damage * frac
		ev.type = RF.DamageType.SPLASH; ev.ability_id = ability_id
		ev.position = closest; ev.direction = (closest - center_pos).normalized()
		ev.knockback = knockback * frac; ev.tick = world.tick
		world.apply_damage(ev)
		if hit_status and ev.dealt > 0.0:
			p.status.apply(hit_status, owner_pawn)


func _falloff_mult() -> float:
	if falloff_end <= falloff_start:
		return 1.0
	var d := global_position.distance_to(start_pos)
	return lerpf(1.0, falloff_min, clampf((d - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))


func _expire() -> void:
	if explode_on_expire and splash_radius > 0.0:
		_splash(global_position)
	for e: AbilityEffect in on_expire_effects:
		_run(e, global_position, Vector3.UP, null)
	world.on_projectile_expired(self)
	queue_free_safe()


func _run(e: AbilityEffect, point: Vector3, normal: Vector3, target: Pawn) -> void:
	if e == null or owner_pawn == null:
		return
	var ctx := AbilityContext.new()
	ctx.pawn = owner_pawn; ctx.world = world; ctx.tick = world.tick
	ctx.is_server = not predicted; ctx.is_predicted = predicted
	ctx.aim_origin = point; ctx.aim_dir = vel.normalized(); ctx.point = point; ctx.normal = normal
	ctx.target = target; ctx.seed = ctx_seed; ctx.data = data
	if predicted:
		e.predict(ctx)
	else:
		e.apply(ctx)


func queue_free_safe() -> void:
	if world:
		world.unregister_projectile(self)
	queue_free()
