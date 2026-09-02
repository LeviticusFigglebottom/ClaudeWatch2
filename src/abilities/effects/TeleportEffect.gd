class_name TeleportEffect
extends AbilityEffect
## Blink forward (checked against geometry) or to the resolved point.

@export var distance: float = 8.0
@export var to_point: bool = false
@export var keep_velocity: bool = false
@export var flat: bool = true


func apply(ctx: AbilityContext) -> void:
	_do(ctx)


func predict(ctx: AbilityContext) -> void:
	_do(ctx)


func _do(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var dest: Vector3
	if to_point:
		dest = ctx.point
	else:
		var dir := ctx.aim_dir
		if flat:
			dir = Vector3(dir.x, 0, dir.z).normalized()
			if dir.length_squared() < 0.01:
				dir = p.forward_flat()
		var from := p.center()
		var res := ctx.world.raycast_world(from, dir, distance, p.team, false)
		var d: float = minf(distance, float(res.get("distance", INF)) - p.movement.profile.capsule_radius - 0.1)
		dest = p.global_position + dir * maxf(d, 0.0)
	p.global_position = dest
	if not keep_velocity:
		p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	ctx.world.emit_custom(&"teleport", {"pawn": p.net_id, "from": ctx.aim_origin, "to": dest})
