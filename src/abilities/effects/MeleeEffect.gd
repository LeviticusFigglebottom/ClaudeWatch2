class_name MeleeEffect
extends AbilityEffect
## Short-range cone/arc hit. Used by quick melee and melee heroes.

@export var damage: float = 40.0
@export var range: float = 2.4
@export var arc_deg: float = 70.0
@export var knockback: float = 1.5
@export var max_targets: int = 1
@export var hit_status: StatusData
@export var backstab_multiplier: float = 1.0   # >1: bonus when hitting from behind
@export var hit_deployables: bool = true
@export var damage_type: RF.DamageType = RF.DamageType.MELEE


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var origin := ctx.aim_origin
	var dir := ctx.aim_dir
	var candidates: Array = []
	for q: Pawn in ctx.world.pawns.values():
		if not q.alive or q == p or q.team == p.team:
			continue
		var closest := q.hitboxes.closest_point(origin)
		var to := closest - origin
		var dist := to.length()
		if dist > range + q.hitboxes.profile.body_radius:
			continue
		var ang := rad_to_deg(acos(clampf(to.normalized().dot(dir), -1.0, 1.0))) if dist > 0.05 else 0.0
		if ang > arc_deg * 0.5:
			continue
		if not ctx.world.pawn_visible_from(origin, q):
			continue
		candidates.append([dist, q])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var n := 0
	for c: Array in candidates:
		if n >= max_targets:
			break
		var q: Pawn = c[1]
		var ev := DamageEvent.new()
		ev.source = p; ev.target = q; ev.amount = damage; ev.type = damage_type
		ev.ability_id = ctx.ability.data.id if ctx.ability else &"quick_melee"
		ev.position = q.center(); ev.direction = dir; ev.knockback = knockback
		if backstab_multiplier > 1.0:
			var behind := q.forward_flat().dot((q.global_position - p.global_position).normalized()) > 0.4
			if behind:
				ev.amount *= backstab_multiplier
				ev.critical = true
		ctx.world.apply_damage(ev)
		if hit_status and ev.dealt > 0.0:
			q.status.apply(hit_status, p)
		n += 1
	if n == 0 and hit_deployables:
		var res := ctx.world.raycast_world(origin, dir, range, p.team, true)
		if not res.is_empty() and res.has("deployable") and res["deployable"] != null:
			(res["deployable"] as Deployable).damage(damage, p)
	ctx.data["melee_hits"] = n
	ctx.world.emit_custom(&"melee", {"pawn": p.net_id, "hits": n, "pos": origin + dir * 1.2, "dir": dir})


func predict(ctx: AbilityContext) -> void:
	ctx.world.emit_custom(&"melee", {"pawn": ctx.pawn.net_id, "hits": 0, "pos": ctx.aim_origin + ctx.aim_dir * 1.2, "dir": ctx.aim_dir, "predicted": true})
