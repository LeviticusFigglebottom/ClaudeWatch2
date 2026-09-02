extends AbilityBehavior
## Zipline: fire an anchor along the aim ray (max 40 m); if it hits a surface, pull the pawn along the
## line at 18 m/s. Ends on arrival, on releasing the direction (jump), or when the timer expires.

var anchor: Vector3
var valid: bool = false
var speed: float = 18.0
var arrived: bool = false


func can_activate(ctx: AbilityContext) -> bool:
	var res := ctx.world.raycast_world(ctx.aim_origin, ctx.aim_dir, 40.0, pawn.team, false)
	return not res.is_empty()


func on_activate(ctx: AbilityContext) -> void:
	var res := ctx.world.raycast_world(ctx.aim_origin, ctx.aim_dir, 40.0, pawn.team, false)
	valid = not res.is_empty()
	arrived = false
	if valid:
		anchor = (res["point"] as Vector3) + (res["normal"] as Vector3) * 0.9
		ctx.world.emit_custom(&"zipline", {"pawn": pawn.net_id, "from": ctx.aim_origin, "to": anchor, "on": true})


func wants_movement_control() -> bool:
	return valid and not arrived


func modify_velocity(_velocity: Vector3, dt: float) -> Vector3:
	var to := anchor - pawn.center()
	var d := to.length()
	if d < 1.2:
		arrived = true
		ability.end(false)
		return Vector3(_velocity.x * 0.3, maxf(_velocity.y, 3.5), _velocity.z * 0.3)
	return to.normalized() * speed


func on_tick(_ctx: AbilityContext, _dt: float) -> void:
	if pawn.last_cmd.just_pressed(RF.BTN_JUMP):
		arrived = true
		ability.end(true)


func on_end(ctx: AbilityContext, _cancelled: bool) -> void:
	ctx.world.emit_custom(&"zipline", {"pawn": pawn.net_id, "from": pawn.center(), "to": anchor, "on": false})
	valid = false
