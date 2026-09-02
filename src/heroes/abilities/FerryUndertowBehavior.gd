extends AimedAllyGate
## Undertow: yank the aimed ally (4-20 m) to Ferry. One impulse sized so the ally lands about a metre
## in front of her regardless of distance. The ability's TARGET effects (small heal + marker status) use
## the ctx.target the gate resolves. Velocity changes are server-side only: the pulled pawn is not
## predicted by Ferry's client.

const MIN_DIST := 4.0
const MAX_DIST := 20.0


func _init() -> void:
	range = MAX_DIST
	cone_deg = 16.0
	min_distance = MIN_DIST


func on_fire(ctx: AbilityContext) -> void:
	super.on_fire(ctx)
	if target == null:
		return
	if not ctx.is_server:
		return
	var dest := pawn.global_position + pawn.forward_flat() * 1.2
	var to := dest - target.global_position
	var flat := Vector3(to.x, 0, to.z)
	var d := flat.length()
	var g: float = ctx.world.tuning.gravity * maxf(target.movement.profile.gravity_mult, 0.2)
	var vy := clampf(3.5 + d * 0.12, 3.5, 6.5) + maxf(to.y, 0.0) * 1.5
	var airtime := 2.0 * vy / g
	var vh := clampf(d / maxf(airtime, 0.2) * 1.05, 4.0, 26.0)
	var impulse := flat.normalized() * vh + Vector3(0, vy, 0)
	target.velocity = Vector3.ZERO
	target.movement.apply_impulse(impulse)
	ctx.world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": target.global_position, "radius": 1.6, "vfx": &"ferry_undertow", "ability": ability.data.id})
	ctx.world.emit_custom(&"ferry_undertow", {"pawn": pawn.net_id, "ally": target.net_id, "from": target.center(), "to": dest})
