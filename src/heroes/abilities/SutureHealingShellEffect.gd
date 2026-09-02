class_name HealingShellEffect
extends ProjectileEffect
## A projectile that detonates on ALLIES as well as on enemies and the world: on impact (or expiry) it
## heals every ally within `heal_radius` of the point for `heal`. Enemies hit directly still take the
## normal projectile `damage`. Base Projectile only sweeps enemy hitboxes, so this spawns a subclass
## that also sweeps friendly hitboxes. Used by Suture's Bandage Volley and Ferry's Ferrylight.
## (Lives under Suture's prefix; see docs/REQUESTS.md about promoting it to src/abilities/effects.)

@export var heal: float = 40.0
@export var heal_radius: float = 3.0
@export var heal_self: bool = false
@export var heal_self_fraction: float = 0.5
@export var burst_vfx: StringName = &"heal_burst"


class HealingShell extends Projectile:
	var heal: float = 40.0
	var heal_radius: float = 3.0
	var heal_self: bool = false
	var heal_self_fraction: float = 0.5
	var burst_vfx: StringName = &"heal_burst"
	var detonated: bool = false

	func step(dt: float) -> void:
		if not predicted and not stuck and age < lifetime:
			var motion := vel * dt
			var dist := motion.length()
			if dist > 0.00001:
				var dir := motion / dist
				var from := global_position
				var best: HitboxSet.HitResult = null
				for p: Pawn in world.pawns.values():
					if not p.alive or p == owner_pawn or p.team != team:
						continue
					var r := p.hitboxes.raycast(from, dir, dist + radius + 0.3, -1)
					if r.hit and (best == null or r.distance < best.distance):
						best = r
				if best != null:
					var wres := world.raycast_world(from, dir, best.distance, team, true)
					if wres.is_empty():
						age += dt
						_impact(best.point, best.normal, dir, null)
						return
		super.step(dt)

	func _heal_burst(center_pos: Vector3) -> void:
		if predicted or detonated or owner_pawn == null:
			return
		detonated = true
		var healed := 0.0
		for p: Pawn in world.pawns_in_radius(center_pos, heal_radius, team):
			if p == owner_pawn and not heal_self:
				continue
			var closest := p.hitboxes.closest_point(center_pos)
			if not world.has_line_of_sight(center_pos, closest):
				continue
			var amt := heal * (heal_self_fraction if p == owner_pawn else 1.0)
			healed += world.apply_heal(owner_pawn, p, amt, ability_id)
		world.emit_custom(&"area", {"pawn": owner_pawn.net_id, "pos": center_pos, "radius": heal_radius, "vfx": burst_vfx, "ability": ability_id, "healed": healed})

	func _impact(point: Vector3, normal: Vector3, dir: Vector3, r: HitboxSet.HitResult) -> void:
		_heal_burst(point)
		super._impact(point, normal, dir, r)

	func _hit_barrier(barrier: Node, point: Vector3, normal: Vector3, dir: Vector3) -> void:
		_heal_burst(point)
		super._hit_barrier(barrier, point, normal, dir)

	func _expire() -> void:
		_heal_burst(global_position)
		super._expire()


func apply(ctx: AbilityContext) -> void:
	_spawn_shells(ctx)


func predict(ctx: AbilityContext) -> void:
	_spawn_shells(ctx)


## Mirrors ProjectileEffect._spawn but instantiates HealingShell.
func _spawn_shells(ctx: AbilityContext) -> void:
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
		var pr := HealingShell.new()
		pr.setup(ctx.world, p)
		pr.heal = heal; pr.heal_radius = heal_radius; pr.heal_self = heal_self
		pr.heal_self_fraction = heal_self_fraction; pr.burst_vfx = burst_vfx
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
