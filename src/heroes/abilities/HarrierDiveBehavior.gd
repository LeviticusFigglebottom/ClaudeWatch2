extends AbilityBehavior
## Dive: only usable in the air. Harrier cuts thrust and slams straight down at 30 m/s (with a little
## forward carry so she can land on a target). On touching the floor the dive ends and releases a
## 4 m slam: 80 splash damage + knockback. Death cancels the dive (no slam); stuns do not (she is a
## falling object). Movement is driven on both server and predicting client; the slam damage is
## gated by apply/predict inside the AreaEffect.

const DIVE_SPEED := 30.0
const FORWARD_CARRY := 5.0
const SLAM_DAMAGE := 80.0
const SLAM_RADIUS := 4.0
const SLAM_KNOCKBACK := 9.0

var diving: bool = false
var _ticks: int = 0
var _slam: AreaEffect


func setup(a: Ability, p: Pawn) -> void:
	super.setup(a, p)
	_slam = AreaEffect.new()
	_slam.radius = SLAM_RADIUS
	_slam.damage = SLAM_DAMAGE
	_slam.min_fraction = 0.5
	_slam.knockback = SLAM_KNOCKBACK
	_slam.center_on_point = true
	_slam.requires_los = true
	_slam.damage_type = RF.DamageType.SPLASH
	_slam.vfx_id = &"harrier_dive_explosion"


func can_activate(_ctx: AbilityContext) -> bool:
	return not pawn.is_on_floor()


func on_activate(_ctx: AbilityContext) -> void:
	diving = true
	_ticks = 0
	pawn.movement.grounded = false
	pawn.movement.hovering = false


func wants_movement_control() -> bool:
	return diving


func modify_velocity(_velocity: Vector3, _dt: float) -> Vector3:
	var f := pawn.forward_flat()
	return Vector3(f.x * FORWARD_CARRY, -DIVE_SPEED, f.z * FORWARD_CARRY)


func on_tick(_ctx: AbilityContext, _dt: float) -> void:
	_ticks += 1
	if _ticks >= 2 and pawn.is_on_floor():
		ability.end(false)


func on_end(ctx: AbilityContext, cancelled: bool) -> void:
	if not diving:
		return
	diving = false
	if cancelled or not pawn.alive or not pawn.is_on_floor():
		return
	ctx.point = pawn.global_position + Vector3(0, 0.4, 0)
	if ctx.is_server:
		_slam.apply(ctx)
	else:
		_slam.predict(ctx)
	pawn.velocity = Vector3(pawn.velocity.x * 0.2, 0.0, pawn.velocity.z * 0.2)
