extends AbilityBehavior
## Ricochet's disc launcher (primary `ricochet_disc`) and its arcing alt-fire (`ricochet_lob`).
## Discs are server projectiles that pass harmlessly through enemies until they have bounced off
## geometry once; every bounce arms them harder (see RicochetBounceEffect). If Bank Shot is primed
## (status `ricochet_bank_primed`), the next disc consumes it and homes after its first bounce.
## `launch()` is the shared spawner also used by Skip and Pinball.

const BounceEffectScript := preload("res://src/heroes/abilities/RicochetBounceEffect.gd")

var speed: float = 45.0
var gravity: float = 0.0
var bounces: int = 3
var damping: float = 0.95
var radius: float = 0.18
var lifetime: float = 4.0
var table: Array = [45.0, 70.0, 95.0]
var lob: bool = false
var spawn_offset: Vector3 = Vector3(0.28, -0.12, -0.45)


func setup(a: Ability, p: Pawn) -> void:
	super.setup(a, p)
	if a.data.id == &"ricochet_lob":
		speed = 28.0
		gravity = 16.0
		bounces = 3
		damping = 0.9
		radius = 0.24
		lifetime = 5.0
		table = [55.0, 80.0, 105.0]
		lob = true


func on_fire(ctx: AbilityContext) -> void:
	var primed := pawn.status.has(&"ricochet_bank_primed")
	if primed:
		pawn.status.remove(&"ricochet_bank_primed")
	var dir := ctx.aim_dir
	if lob:
		dir = (dir + Vector3(0, 0.12, 0)).normalized()
	var basis := Basis(Vector3.UP, ctx.view_yaw)
	var origin := ctx.aim_origin + basis * Vector3(spawn_offset.x, spawn_offset.y, 0) + dir * absf(spawn_offset.z)
	if not ctx.world.has_line_of_sight(ctx.aim_origin, origin):
		origin = ctx.aim_origin + dir * 0.1
	var cfg := {"bounces": bounces, "damping": damping, "radius": radius, "lifetime": lifetime, "gravity": gravity, "table": table}
	launch(ctx.world, pawn, ability.data.id, origin, dir * speed, cfg, ctx.seed, primed)
	if ctx.is_server:
		pawn.stats.shots_fired += 1


## Spawns one armed-on-bounce disc. Works on the server (authoritative) and on the predicting client
## (visual twin). Enemies are pre-listed in hits_done so the disc ignores them until it bounces.
static func launch(world: SimWorld, owner: Pawn, ability_id: StringName, origin: Vector3, vel: Vector3, cfg: Dictionary, seed: int, bank: bool) -> Projectile:
	var pr := Projectile.new()
	pr.setup(world, owner)
	pr.ability_id = ability_id
	pr.damage = 0.0
	pr.damage_type = RF.DamageType.PROJECTILE
	pr.radius = float(cfg.get("radius", 0.18))
	pr.lifetime = float(cfg.get("lifetime", 4.0))
	pr.gravity = float(cfg.get("gravity", 0.0))
	pr.bounces = int(cfg.get("bounces", 3))
	pr.bounce_damping = float(cfg.get("damping", 0.95))
	pr.knockback = 2.0
	pr.visual_id = &"disc"
	pr.rewind_tick = -1
	pr.ctx_seed = seed
	var bounce_fx := BounceEffectScript.new() as AbilityEffect
	pr.on_bounce_effects = [bounce_fx]
	var d := {"bounces": 0, "table": cfg.get("table", [45.0, 70.0, 95.0]), "bank": bank}
	pr.data = d
	d["projectile"] = pr
	for q: Pawn in world.pawns.values():
		if q.team != pr.team:
			pr.hits_done[q.net_id] = true
	world.spawn_projectile(pr, origin, vel)
	return pr
