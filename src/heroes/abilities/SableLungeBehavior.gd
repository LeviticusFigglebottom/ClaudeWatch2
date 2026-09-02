class_name SableLungeBehavior
extends AbilityBehavior
## Lunge: 16 m/s controlled dash toward the aim direction for the ability's active window
## (0.25 s). The strike is the ability's end_effect (MeleeEffect), so it lands on arrival.

const SPEED := 16.0

var _dir: Vector3 = Vector3.FORWARD
var _active: bool = false


func on_activate(ctx: AbilityContext) -> void:
	var d := ctx.aim_dir
	d.y = clampf(d.y, -0.2, 0.45)
	if d.length_squared() < 0.01:
		d = pawn.forward_flat()
	_dir = d.normalized()
	_active = true
	pawn.movement.grounded = false


func wants_movement_control() -> bool:
	return _active


func modify_velocity(_velocity: Vector3, _dt: float) -> Vector3:
	return _dir * SPEED


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	_active = false
	pawn.velocity = _dir * SPEED * 0.35
