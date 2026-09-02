class_name BombardBarrageBehavior
extends AbilityBehavior
## Barrage: resolves the aimed ground point on fire, then drops 12 shells from ~20 m above it over
## 3 s. Shells are real Projectiles (server-simulated, client-mirrored); spawning runs on both
## sides so the owning client sees its own barrage immediately.

const SHELLS := 12
const SPAN := 3.0
const SPREAD := 4.0
const DROP_HEIGHT := 20.0
const DROP_SPEED := 25.0
const SHELL_DAMAGE := 70.0
const SHELL_SPLASH := 70.0
const SHELL_SPLASH_RADIUS := 3.5

var point: Vector3
var ceiling: float = DROP_HEIGHT
var fired: int = 0
var elapsed: float = 0.0
var _rng := RandomNumberGenerator.new()


func on_fire(ctx: AbilityContext) -> void:
	var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, 45.0, pawn, ctx.rewind_tick)
	point = res.point
	if not res.hit:
		point = ctx.world.ground_point(point + Vector3(0, 0.5, 0))
	elif res.pawn != null:
		point = ctx.world.ground_point(res.pawn.global_position + Vector3(0, 0.3, 0))
	ctx.point = point
	# Indoors: drop from just below the ceiling so shells never start above a roof.
	var up := ctx.world.raycast_world(point + Vector3(0, 0.6, 0), Vector3.UP, DROP_HEIGHT, pawn.team, false)
	ceiling = DROP_HEIGHT if up.is_empty() else maxf(float(up["distance"]) - 0.8, 3.0)
	_rng.seed = ctx.seed
	fired = 0
	elapsed = 0.0
	pawn.set_meta("barrage_point", point)


func on_tick(ctx: AbilityContext, dt: float) -> void:
	elapsed += dt
	while fired < SHELLS and elapsed >= float(fired) * (SPAN / SHELLS):
		_drop_shell(ctx)
		fired += 1
	if fired >= SHELLS and elapsed >= SPAN + 0.3:
		ability.end(false)


func _drop_shell(ctx: AbilityContext) -> void:
	var pr := Projectile.new()
	pr.setup(ctx.world, pawn)
	pr.ability_id = ability.data.id
	pr.damage = SHELL_DAMAGE
	pr.damage_type = RF.DamageType.PROJECTILE
	pr.gravity = 14.0
	pr.radius = 0.2
	pr.lifetime = 5.0
	pr.splash_radius = SHELL_SPLASH_RADIUS
	pr.splash_damage = SHELL_SPLASH
	pr.splash_min_fraction = 0.35
	pr.knockback = 3.0
	pr.visual_id = &"mortar"
	pr.ctx_seed = ctx.seed + fired
	var off := Vector3(_rng.randf_range(-SPREAD, SPREAD), 0.0, _rng.randf_range(-SPREAD, SPREAD))
	var pos := point + off + Vector3(0, ceiling, 0)
	ctx.world.spawn_projectile(pr, pos, Vector3(0, -DROP_SPEED, 0))


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	fired = SHELLS
