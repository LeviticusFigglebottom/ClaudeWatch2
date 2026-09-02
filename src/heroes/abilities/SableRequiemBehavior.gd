class_name SableRequiemBehavior
extends AbilityBehavior
## Requiem: marks every enemy within 12 m, then takes movement control and dashes to a point just
## behind each marked enemy in turn at 30 m/s. On arrival (or after 1.2 s of chasing) a 100 damage
## backstab-eligible cut lands (server only), then a 0.2 s pause before the next target.
## Movement runs on both sides (prediction); marks and cuts are server-authoritative.

const RADIUS := 12.0
const DASH_SPEED := 30.0
const PAUSE := 0.2
const ARRIVE := 1.6
const CHASE_LIMIT := 1.2
const BEHIND := 1.1
const CUT_DAMAGE := 100.0

var targets: Array[Pawn] = []
var index: int = 0
var pause: float = 0.0
var chase_t: float = 0.0
var _cut: MeleeEffect
var _mark: StatusData
var _running: bool = false


func setup(_ability: Ability, _pawn: Pawn) -> void:
	super.setup(_ability, _pawn)
	_cut = MeleeEffect.new()
	_cut.damage = CUT_DAMAGE
	_cut.range = 3.2
	_cut.arc_deg = 360.0
	_cut.knockback = 3.0
	_cut.max_targets = 1
	_cut.backstab_multiplier = 2.5
	_cut.hit_deployables = false


func _enemies_in_range(world: SimWorld) -> Array[Pawn]:
	var out: Array[Pawn] = []
	for q: Pawn in world.pawns_in_radius(pawn.center(), RADIUS, RF.enemy_team(pawn.team)):
		if q.alive:
			out.append(q)
	return out


func can_activate(ctx: AbilityContext) -> bool:
	return not _enemies_in_range(ctx.world).is_empty()


func on_fire(ctx: AbilityContext) -> void:
	targets = _enemies_in_range(ctx.world)
	var origin := pawn.global_position
	targets.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	index = 0
	pause = 0.0
	chase_t = 0.0
	_running = not targets.is_empty()
	if _mark == null:
		_mark = StatusLibrary.get_status(&"sable_requiem_mark")
	if ctx.is_server and _mark:
		for t: Pawn in targets:
			t.status.apply(_mark, pawn)
	ctx.world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": pawn.global_position, "radius": RADIUS,
		"vfx": &"sable_requiem_mark", "ability": ability.data.id, "predicted": not ctx.is_server})
	pawn.set_meta("requiem_targets", targets.size())


func wants_movement_control() -> bool:
	return _running


func _current() -> Pawn:
	while index < targets.size():
		var t := targets[index]
		if is_instance_valid(t) and t.alive:
			return t
		index += 1
		chase_t = 0.0
	return null


func _behind_point(t: Pawn) -> Vector3:
	return t.center() - t.forward_flat() * BEHIND


func modify_velocity(velocity: Vector3, dt: float) -> Vector3:
	if pause > 0.0:
		pause -= dt
		return Vector3(velocity.x * 0.2, 0.0, velocity.z * 0.2)
	var t := _current()
	if t == null:
		_running = false
		ability.end(false)
		return Vector3(velocity.x * 0.3, maxf(velocity.y, 0.0), velocity.z * 0.3)
	var to := _behind_point(t) - pawn.center()
	var d := to.length()
	chase_t += dt
	if d <= ARRIVE or chase_t >= CHASE_LIMIT:
		_strike(t)
		index += 1
		chase_t = 0.0
		pause = PAUSE
		return Vector3.ZERO
	return to / maxf(d, 0.001) * DASH_SPEED


func _strike(t: Pawn) -> void:
	if not pawn.is_server:
		return
	var ctx := AbilityContext.new()
	ctx.pawn = pawn
	ctx.world = pawn.world
	ctx.ability = ability
	ctx.tick = pawn.world.tick
	ctx.is_server = true
	ctx.aim_origin = pawn.center()
	ctx.aim_dir = (t.center() - pawn.center()).normalized()
	if ctx.aim_dir.length_squared() < 0.01:
		ctx.aim_dir = pawn.forward_flat()
	ctx.view_yaw = pawn.yaw
	ctx.seed = pawn.world.tick
	_cut.apply(ctx)


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	_running = false
	targets.clear()
	pawn.velocity = Vector3(pawn.velocity.x * 0.3, 0.0, pawn.velocity.z * 0.3)
