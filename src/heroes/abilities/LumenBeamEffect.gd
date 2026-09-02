class_name LumenBeamEffect
extends AbilityEffect
## Lumen's mirror beam (tick effect of a CHANNEL primary). A thin ray that heals the first ally or
## damages the first enemy it touches. When the ray hits a deployable of kind "mirror" it reflects off
## the mirror's plane and continues (up to `max_bounces` times), so a placed mirror lets Lumen heal
## around corners. While Lumen has the `lumen_prism` status the beam splits at its last segment into
## up to `prism_targets` targets inside a cone, each receiving `prism_share` of the rate.
## Presentation: emits `beam` (single segment) or `beam_segments` (bounced path) every 3 ticks.

@export var heal_per_second: float = 65.0
@export var dps: float = 55.0
@export var range: float = 25.0
@export var max_bounces: int = 3
@export var lock_on_deg: float = 7.0
@export var prism_cone_deg: float = 25.0
@export var prism_targets: int = 3
@export var prism_share: float = 0.75
@export var enemy_status: StatusData
@export var ally_status: StatusData
@export var damage_type: RF.DamageType = RF.DamageType.BEAM
@export var mirror_kind: StringName = &"mirror"


## Traces the beam path. Returns {points: Array[Vector3], targets: Array[Pawn], bounces: int, barrier: Deployable}.
func trace(ctx: AbilityContext, rewind: int) -> Dictionary:
	var p := ctx.pawn
	var world := ctx.world
	var origin := ctx.aim_origin
	var dir := ctx.aim_dir
	var remaining := range
	var points: Array = []
	var targets: Array[Pawn] = []
	var bounces := 0
	var barrier: Deployable = null
	var prism := p.status.has(&"lumen_prism")
	var exclude: Deployable = null
	for seg in range(max_bounces + 1):
		var res := world.hitscan(origin, dir, remaining, p, rewind, true)
		var end := res.point
		if res.pawn:
			targets = [res.pawn]
		elif lock_on_deg > 0.0:
			var t := _soft_lock(world, p, origin, dir, minf(remaining, res.distance + 0.5), lock_on_deg)
			if t:
				targets = [t]
				end = t.center()
		if prism:
			var extra := _cone_targets(world, p, origin, dir, remaining, prism_cone_deg, prism_targets, targets)
			if not extra.is_empty():
				targets = extra
				if res.pawn == null and targets.size() > 0:
					end = targets[0].center()
		points.append(end)
		if not targets.is_empty():
			break
		if res.deployable != null and res.deployable.kind == mirror_kind and res.deployable != exclude and seg < max_bounces:
			var n: Vector3 = res.deployable.global_transform.basis.z.normalized()
			if n.length_squared() < 0.5:
				n = res.normal
			if dir.dot(n) > 0.0:
				n = -n
			dir = dir.bounce(n).normalized()
			origin = res.point + n * 0.06
			remaining -= res.distance
			bounces += 1
			exclude = res.deployable
			if remaining <= 0.5:
				break
			continue
		barrier = res.barrier
		break
	return {"points": points, "targets": targets, "bounces": bounces, "barrier": barrier}


func _soft_lock(world: SimWorld, p: Pawn, origin: Vector3, dir: Vector3, max_d: float, cone: float) -> Pawn:
	var cos_c := cos(deg_to_rad(cone))
	var best: Pawn = null
	var best_d := -1.0
	for q: Pawn in world.pawns.values():
		if not q.alive or q == p:
			continue
		var to := q.center() - origin
		var dist := to.length()
		if dist > max_d or dist < 0.01:
			continue
		var d := to.normalized().dot(dir)
		if d > cos_c and d > best_d and world.pawn_visible_from(origin, q):
			best_d = d
			best = q
	return best


func _cone_targets(world: SimWorld, p: Pawn, origin: Vector3, dir: Vector3, max_d: float, cone: float, count: int, seed_targets: Array[Pawn]) -> Array[Pawn]:
	var cos_c := cos(deg_to_rad(cone * 0.5))
	var scored: Array = []
	for q: Pawn in world.pawns.values():
		if not q.alive or q == p:
			continue
		var to := q.center() - origin
		var dist := to.length()
		if dist > max_d or dist < 0.01:
			continue
		var d := to.normalized().dot(dir)
		if seed_targets.has(q):
			d = 2.0
		elif d < cos_c or not world.pawn_visible_from(origin, q):
			continue
		scored.append([d, q])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array[Pawn] = []
	for s: Array in scored:
		if out.size() >= count:
			break
		out.append(s[1] as Pawn)
	return out


func tick(ctx: AbilityContext, dt: float) -> void:
	var p := ctx.pawn
	var world := ctx.world
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &"lumen_beam"
	var tr := trace(ctx, ctx.rewind_tick)
	var targets: Array[Pawn] = tr["targets"]
	var points: Array = tr["points"]
	var share := prism_share if targets.size() > 1 else 1.0
	for t: Pawn in targets:
		if t.team != p.team:
			if dps > 0.0:
				var ev := DamageEvent.new()
				ev.source = p; ev.target = t; ev.amount = dps * dt * share; ev.type = damage_type
				ev.ability_id = ability_id; ev.position = t.center(); ev.direction = ctx.aim_dir
				world.apply_damage(ev)
				if enemy_status and ev.dealt > 0.0:
					t.status.apply(enemy_status, p)
		elif heal_per_second > 0.0:
			world.apply_heal(p, t, heal_per_second * dt * share, ability_id)
			if ally_status:
				t.status.apply(ally_status, p, 0.3)
	var barrier: Deployable = tr["barrier"]
	if barrier != null and dps > 0.0:
		barrier.absorb(dps * dt, p)
	var hb := p.behavior as LumenBehavior
	if hb:
		hb.note_beam(int(tr["bounces"]), targets.size(), ctx.tick)
	var end: Vector3 = points[points.size() - 1] if not points.is_empty() else ctx.aim_origin + ctx.aim_dir * range
	ctx.data["beam_end"] = end
	ctx.data["beam_target"] = targets[0].net_id if not targets.is_empty() else -1
	ctx.data["beam_bounces"] = tr["bounces"]
	if ctx.tick % 3 == 0:
		_emit(ctx, points, targets, false)
	if int(tr["bounces"]) > 0 and ctx.tick % 15 == 0:
		world.emit_custom(&"lumen_bounce", {"pawn": p.net_id, "bounces": tr["bounces"], "pos": ctx.aim_origin, "targets": targets.size()})


func _emit(ctx: AbilityContext, points: Array, targets: Array[Pawn], predicted: bool) -> void:
	var p := ctx.pawn
	var slot := ctx.ability.slot if ctx.ability else -1
	var tgt := targets[0].net_id if not targets.is_empty() else -1
	if points.size() > 1:
		ctx.world.emit_custom(&"beam_segments", {"pawn": p.net_id, "slot": slot, "points": points, "tgt": tgt, "end": points[points.size() - 1], "on": true, "predicted": predicted})
	else:
		var end: Vector3 = points[0] if not points.is_empty() else ctx.aim_origin + ctx.aim_dir * range
		ctx.world.emit_custom(&"beam", {"pawn": p.net_id, "slot": slot, "end": end, "tgt": tgt, "on": true, "predicted": predicted})


func apply(ctx: AbilityContext) -> void:
	tick(ctx, RF.TICK_DT)


func predict(ctx: AbilityContext) -> void:
	var tr := trace(ctx, -1)
	_emit(ctx, tr["points"], tr["targets"], true)
