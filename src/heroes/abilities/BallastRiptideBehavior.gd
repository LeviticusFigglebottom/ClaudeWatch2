extends AbilityBehavior
## Ballast ult Riptide: a 3 s channel. The tidal center is fixed where Ballast aimed on activation
## (ground point within 12 m). Every tick enemies within RADIUS are dragged toward the center by a
## velocity blend (single impulses die to ground friction within two ticks, so a blend is what makes
## the pull feel inevitable). Damage, the slow and the closing burst are AreaEffects in data
## (tick_effects / end_effects) that read ctx.point, which this behavior refreshes every tick.

const RADIUS := 9.0
const PULL_SPEED := 5.5
const AIM_RANGE := 12.0

var point: Vector3
var has_point: bool = false


func on_fire(ctx: AbilityContext) -> void:
	var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, AIM_RANGE, pawn, ctx.rewind_tick)
	var p := res.point
	if res.pawn:
		p = res.pawn.global_position
	point = ctx.world.ground_point(p + Vector3(0, 0.3, 0))
	# Aiming at the sky: fall back to the ground ahead of Ballast.
	if point.distance_to(pawn.global_position) > AIM_RANGE + 2.0 or point.y < pawn.global_position.y - 12.0:
		point = ctx.world.ground_point(pawn.global_position + pawn.forward_flat() * 6.0 + Vector3(0, 0.5, 0))
	has_point = true
	ctx.point = point
	ctx.world.emit_custom(&"riptide", {"pawn": pawn.net_id, "pos": point, "radius": RADIUS, "on": true})


func on_tick(ctx: AbilityContext, _dt: float) -> void:
	if not has_point:
		return
	ctx.point = point
	if not ctx.is_server:
		return
	var center := point + Vector3(0, 0.8, 0)
	for q: Pawn in ctx.world.pawns_in_radius(center, RADIUS, RF.enemy_team(pawn.team)):
		if q.status.unstoppable:
			continue
		var to := center - q.center()
		var flat := Vector3(to.x, 0, to.z)
		var d := flat.length()
		if d < 1.2:
			# At the eye of the tide: hold them there.
			q.velocity.x *= 0.5
			q.velocity.z *= 0.5
			continue
		var want := flat / d * PULL_SPEED * clampf(d / 3.0, 0.6, 1.0)
		q.velocity.x = lerpf(q.velocity.x, want.x, 0.5)
		q.velocity.z = lerpf(q.velocity.z, want.z, 0.5)


func on_end(ctx: AbilityContext, _cancelled: bool) -> void:
	ctx.point = point
	has_point = false
	ctx.world.emit_custom(&"riptide", {"pawn": pawn.net_id, "pos": point, "radius": RADIUS, "on": false})
