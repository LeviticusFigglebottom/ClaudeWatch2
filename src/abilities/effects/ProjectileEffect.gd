class_name ProjectileEffect
extends AbilityEffect
## Spawns a server-simulated projectile (client spawns a visual twin for instant feedback).

@export var damage: float = 60.0
@export var speed: float = 40.0
@export var gravity: float = 0.0
@export var radius: float = 0.12
@export var lifetime: float = 4.0
@export var count: int = 1
@export var spread_deg: float = 0.0
@export var splash_radius: float = 0.0
@export var splash_damage: float = 0.0
@export var splash_min_fraction: float = 0.3
@export var knockback: float = 0.0
@export var self_knockback: float = 0.0
@export var headshot: bool = false
@export var pierce: bool = false
@export var bounces: int = 0
@export var bounce_damping: float = 0.85
@export var homing_strength: float = 0.0
@export var homing_cone_deg: float = 20.0
@export var sticky: bool = false
@export var explode_on_expire: bool = false
@export var falloff_start: float = 0.0
@export var falloff_end: float = 0.0
@export var falloff_min: float = 1.0
@export var inherit_velocity: float = 0.0
@export var spawn_offset: Vector3 = Vector3(0.25, -0.15, -0.4)   # view-space
@export var hit_status: StatusData
@export var visual_id: StringName = &"bolt"
@export var on_hit_effects: Array[AbilityEffect] = []
@export var on_expire_effects: Array[AbilityEffect] = []
@export var on_bounce_effects: Array[AbilityEffect] = []
@export var damage_type: RF.DamageType = RF.DamageType.PROJECTILE
@export var lob_arc: bool = false            # aim assist for lobbed weapons: pitch up slightly


func apply(ctx: AbilityContext) -> void:
	_spawn(ctx)


func predict(ctx: AbilityContext) -> void:
	_spawn(ctx)


func _spawn(ctx: AbilityContext) -> void:
	var r := ctx.rng()
	var p := ctx.pawn
	for i in maxi(count, 1):
		var dir := ctx.aim_dir
		if spread_deg > 0.0:
			var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
			var ang := deg_to_rad(spread_deg * 0.5)
			var a := r.randf() * TAU
			var rr := sqrt(r.randf()) * ang
			dir = (basis * Vector3(sin(rr) * cos(a), sin(rr) * sin(a), -cos(rr))).normalized()
		if lob_arc:
			dir = (dir + Vector3(0, 0.08, 0)).normalized()
		var pr := Projectile.new()
		pr.setup(ctx.world, p)
		pr.ability_id = ctx.ability.data.id if ctx.ability else &""
		pr.damage = damage; pr.damage_type = damage_type
		pr.gravity = gravity; pr.radius = radius; pr.lifetime = lifetime
		pr.headshot_enabled = headshot; pr.pierce = pierce
		pr.splash_radius = splash_radius; pr.splash_damage = splash_damage; pr.splash_min_fraction = splash_min_fraction
		pr.knockback = knockback; pr.self_knockback = self_knockback
		pr.bounces = bounces; pr.bounce_damping = bounce_damping
		pr.homing_strength = homing_strength; pr.sticky = sticky; pr.explode_on_expire = explode_on_expire
		pr.falloff_start = falloff_start; pr.falloff_end = falloff_end; pr.falloff_min = falloff_min
		pr.hit_status = hit_status; pr.visual_id = visual_id
		pr.on_hit_effects = on_hit_effects; pr.on_expire_effects = on_expire_effects; pr.on_bounce_effects = on_bounce_effects
		pr.rewind_tick = ctx.rewind_tick
		pr.ctx_seed = ctx.seed + i
		pr.data = ctx.data
		if homing_strength > 0.0:
			pr.homing_target = _pick_homing_target(ctx, dir)
		# Spawn slightly in front of the eye so the projectile doesn't clip the shooter.
		var basis2 := Basis(Vector3.UP, ctx.view_yaw)
		var origin := ctx.aim_origin + basis2 * Vector3(spawn_offset.x, spawn_offset.y, 0) + dir * absf(spawn_offset.z)
		# If the offset origin is behind geometry relative to the eye, fall back to the eye.
		if not ctx.world.has_line_of_sight(ctx.aim_origin, origin):
			origin = ctx.aim_origin + dir * 0.1
		var v := dir * speed + p.velocity * inherit_velocity
		ctx.world.spawn_projectile(pr, origin, v)
		ctx.data["projectile"] = pr
		if ctx.is_server:
			p.stats.shots_fired += 1


func _pick_homing_target(ctx: AbilityContext, dir: Vector3) -> Pawn:
	var best: Pawn = null
	var best_dot := cos(deg_to_rad(homing_cone_deg))
	for q: Pawn in ctx.world.pawns.values():
		if not q.alive or q.team == ctx.pawn.team:
			continue
		var to := (q.center() - ctx.aim_origin).normalized()
		var d := to.dot(dir)
		if d > best_dot and ctx.world.pawn_visible_from(ctx.aim_origin, q):
			best_dot = d
			best = q
	return best
