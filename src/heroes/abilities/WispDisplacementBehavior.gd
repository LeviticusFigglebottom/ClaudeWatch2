extends AbilityBehavior
## Displacement: after the cast, every enemy within 10 m that Wisp can see is folded to a random
## ground point in a ring 8–12 m behind her facing (±60°), never through geometry (LOS from Wisp to
## the destination is required, and the point is dropped to the ground). Unstoppable enemies are
## immune. Enemy positions are authoritative, so this runs on the server only; the ability's
## effects grant Wisp her 100 overhealth. Emits `teleport` per moved enemy for the blink VFX.

const RADIUS := 10.0
const RING_MIN := 8.0
const RING_MAX := 12.0
const HALF_ARC := 1.05
const ATTEMPTS := 8

var _tag: StatusData


func on_fire(ctx: AbilityContext) -> void:
	if not ctx.is_server:
		return
	if _tag == null:
		_tag = StatusLibrary.get_status(&"wisp_displaced")
	var r := ctx.rng()
	var back := -pawn.forward_flat()
	var moved := 0
	for q: Pawn in ctx.world.pawns_in_radius(pawn.center(), RADIUS, RF.enemy_team(pawn.team)):
		if q.status.unstoppable:
			continue
		if not ctx.world.pawn_visible_from(pawn.eye_position(), q):
			continue
		var dest := _find_spot(ctx, r, back)
		if dest == Vector3.INF:
			continue
		var from := q.global_position
		q.global_position = dest
		q.velocity = Vector3.ZERO
		q.movement.external_impulse = Vector3.ZERO
		q.reset_physics_interpolation()
		if _tag:
			q.status.apply(_tag, pawn)
		ctx.world.emit_custom(&"teleport", {"pawn": q.net_id, "from": from, "to": dest})
		moved += 1
	ctx.data["displaced"] = moved


func _find_spot(ctx: AbilityContext, r: RandomNumberGenerator, back: Vector3) -> Vector3:
	for _i in ATTEMPTS:
		var ang := r.randf_range(-HALF_ARC, HALF_ARC)
		var dir := back.rotated(Vector3.UP, ang)
		var dist := r.randf_range(RING_MIN, RING_MAX)
		var cand := pawn.global_position + dir * dist + Vector3(0, 1.4, 0)
		if not ctx.world.has_line_of_sight(pawn.center(), cand):
			continue
		var g := ctx.world.ground_point(cand, 8.0)
		if g.is_equal_approx(cand):
			continue
		return g + Vector3(0, 0.05, 0)
	return Vector3.INF
