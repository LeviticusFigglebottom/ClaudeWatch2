extends AbilityBehavior
## Strafing Run: for 4 s Harrier drops a rocket straight down from her position every 0.25 s while
## her jet-rig runs on infinite fuel (and the ability's self status gives +50% speed). Rockets are
## server-simulated projectiles; the predicting client spawns visual twins through the same call.
## Fly a line over the enemy and the rockets carpet it; stand still and they carpet your feet.

const ROCKET_INTERVAL := 0.25
const ROCKET_DAMAGE := 90.0
const ROCKET_SPLASH := 3.5
const ROCKET_SPEED := 40.0
const ROCKET_KNOCKBACK := 4.0

var _accum: float = 0.0
var _count: int = 0


func on_activate(_ctx: AbilityContext) -> void:
	_accum = 0.0
	_count = 0
	_refuel()


func on_fire(ctx: AbilityContext) -> void:
	_drop(ctx)


func on_tick(ctx: AbilityContext, dt: float) -> void:
	_refuel()
	_accum += dt
	while _accum >= ROCKET_INTERVAL:
		_accum -= ROCKET_INTERVAL
		_drop(ctx)


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	_refuel()


func _refuel() -> void:
	var m := pawn.movement
	m.hover_fuel = m.base_profile.hover_fuel


func _drop(ctx: AbilityContext) -> void:
	if not pawn.alive:
		return
	var pr := Projectile.new()
	pr.setup(ctx.world, pawn)
	pr.ability_id = ability.data.id
	pr.damage = ROCKET_DAMAGE
	pr.damage_type = RF.DamageType.PROJECTILE
	pr.radius = 0.15
	pr.lifetime = 3.0
	pr.splash_radius = ROCKET_SPLASH
	pr.splash_damage = ROCKET_DAMAGE
	pr.splash_min_fraction = 0.4
	pr.knockback = ROCKET_KNOCKBACK
	pr.explode_on_expire = true
	pr.visual_id = &"shell"
	pr.ctx_seed = ctx.seed + _count
	pr.rewind_tick = -1
	pr.data = {"rocket_index": _count}
	var origin := pawn.global_position + Vector3(0, 0.45, 0)
	var vel := Vector3(pawn.velocity.x * 0.3, -ROCKET_SPEED, pawn.velocity.z * 0.3)
	ctx.world.spawn_projectile(pr, origin, vel)
	if ctx.is_server:
		pawn.stats.shots_fired += 1
	_count += 1
