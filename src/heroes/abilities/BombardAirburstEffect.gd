class_name BombardAirburstEffect
extends ProjectileEffect
## ProjectileEffect variant that spawns a BombardAirburstShell (proximity-fused mortar round).
## Mirrors ProjectileEffect._spawn exactly so bots' lead/gravity compensation and client
## prediction behave like any other projectile.

@export var proximity_radius: float = 3.2


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
		var pr := BombardAirburstShell.new()
		pr.setup(ctx.world, p)
		pr.proximity_radius = proximity_radius
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
		var basis2 := Basis(Vector3.UP, ctx.view_yaw)
		var origin := ctx.aim_origin + basis2 * Vector3(spawn_offset.x, spawn_offset.y, 0) + dir * absf(spawn_offset.z)
		if not ctx.world.has_line_of_sight(ctx.aim_origin, origin):
			origin = ctx.aim_origin + dir * 0.1
		var v := dir * speed + p.velocity * inherit_velocity
		ctx.world.spawn_projectile(pr, origin, v)
		ctx.data["projectile"] = pr
		if ctx.is_server:
			p.stats.shots_fired += 1
