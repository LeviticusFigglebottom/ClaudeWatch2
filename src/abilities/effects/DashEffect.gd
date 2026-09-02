class_name DashEffect
extends AbilityEffect
## Instant velocity change: dash toward aim/move direction, leap up, or a launch.

enum Dir { AIM, MOVE_OR_FORWARD, UP, BACKWARD, AIM_FLAT }

@export var speed: float = 18.0
@export var direction: Dir = Dir.MOVE_OR_FORWARD
@export var vertical_boost: float = 0.0
@export var preserve_momentum: float = 0.0     # 0 = replace velocity, 1 = add


func apply(ctx: AbilityContext) -> void:
	_do(ctx)


func predict(ctx: AbilityContext) -> void:
	_do(ctx)


func _do(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var d := Vector3.ZERO
	match direction:
		Dir.AIM: d = ctx.aim_dir
		Dir.AIM_FLAT: d = Vector3(ctx.aim_dir.x, 0, ctx.aim_dir.z).normalized()
		Dir.UP: d = Vector3.UP
		Dir.BACKWARD: d = -p.forward_flat()
		Dir.MOVE_OR_FORWARD:
			d = p.movement.wish_dir.normalized() if p.movement.wish_dir.length_squared() > 0.01 else p.forward_flat()
	var v := d * speed + Vector3(0, vertical_boost, 0)
	p.velocity = p.velocity * preserve_momentum + v
	p.movement.grounded = false
