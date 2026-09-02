extends AbilityBehavior
## Pinball: for 6 s a disc leaves Ricochet every 0.3 s in a random direction (deterministic per
## tick, so server and predicting client spawn the same fan). Each disc bounces up to 6 times,
## arming on the first bounce like every other disc. She keeps her weapons during the ult.

const DiscScript := preload("res://src/heroes/abilities/RicochetDiscBehavior.gd")
const INTERVAL := 0.3
const DISC_SPEED := 40.0

var _accum: float = 0.0
var _count: int = 0


func on_activate(_ctx: AbilityContext) -> void:
	_accum = 0.0
	_count = 0


func on_fire(ctx: AbilityContext) -> void:
	_spawn_one(ctx)


func on_tick(ctx: AbilityContext, dt: float) -> void:
	_accum += dt
	while _accum >= INTERVAL:
		_accum -= INTERVAL
		_spawn_one(ctx)


func _spawn_one(ctx: AbilityContext) -> void:
	if not pawn.alive:
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(pawn.net_id, ctx.tick, _count))
	var yaw := r.randf() * TAU
	var pitch := r.randf_range(-0.3, 0.35)
	var dir := Vector3(cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch)).normalized()
	var origin := pawn.center() + dir * 0.7
	if not ctx.world.has_line_of_sight(pawn.center(), origin):
		origin = pawn.center() + dir * 0.1
	var cfg := {"bounces": 6, "damping": 0.95, "radius": 0.2, "lifetime": 6.0, "gravity": 0.0, "table": [45.0, 70.0, 95.0]}
	DiscScript.launch(ctx.world, pawn, ability.data.id, origin, dir * DISC_SPEED, cfg, ctx.seed + _count, false)
	if ctx.is_server:
		pawn.stats.shots_fired += 1
	_count += 1
