extends AbilityBehavior
## Ballast ★ Anchor: throws a harpoon-anchor. On a world hit Ballast is winched to the surface
## (movement control, like Zipline). On an enemy hit the enemy is reeled to Ballast and briefly
## hooked (rooted). Unstoppable enemies take the harpoon damage but are not reeled.
## Runs on the server and the predicting client; only Ballast's own movement is predicted.

const AnchorHit := preload("res://src/heroes/abilities/BallastAnchorHit.gd")

const HARPOON_SPEED := 46.0
const HARPOON_GRAVITY := 5.0
const HARPOON_LIFETIME := 1.0
const HARPOON_RADIUS := 0.16
const HIT_DAMAGE := 40.0
const PULL_SPEED := 24.0
const REEL_SPEED := 22.0
const REEL_TIME := 0.7
const HOOK_STATUS := &"ballast_hooked"

var harpoon: Projectile
var harpoon_id: int = -1
var resolved: bool = false
var pulling: bool = false
var anchor_point: Vector3
var reeling: Pawn
var reel_left: float = 0.0
var pull_time: float = 0.0
var last_dist: float = INF
var stall_ticks: int = 0


func on_activate(_ctx: AbilityContext) -> void:
	harpoon = null
	harpoon_id = -1
	resolved = false
	pulling = false
	reeling = null
	reel_left = 0.0
	pull_time = 0.0
	last_dist = INF
	stall_ticks = 0


func on_fire(ctx: AbilityContext) -> void:
	var pr := Projectile.new()
	pr.setup(ctx.world, pawn)
	pr.ability_id = ability.data.id
	pr.damage = HIT_DAMAGE
	pr.damage_type = RF.DamageType.PROJECTILE
	pr.gravity = HARPOON_GRAVITY
	pr.radius = HARPOON_RADIUS
	pr.lifetime = HARPOON_LIFETIME
	pr.visual_id = &"harpoon"
	pr.rewind_tick = ctx.rewind_tick
	pr.ctx_seed = ctx.seed
	pr.data = ctx.data
	var hit := AnchorHit.new()
	hit.behavior = self
	var fx: Array[AbilityEffect] = [hit]
	pr.on_hit_effects = fx
	var basis := Basis(Vector3.UP, ctx.view_yaw)
	var origin := ctx.aim_origin + basis * Vector3(0.3, -0.2, 0) + ctx.aim_dir * 0.5
	if not ctx.world.has_line_of_sight(ctx.aim_origin, origin):
		origin = ctx.aim_origin + ctx.aim_dir * 0.1
	ctx.world.spawn_projectile(pr, origin, ctx.aim_dir * HARPOON_SPEED + pawn.velocity * 0.3)
	# The client's twin also sweeps pawns so a hooked-enemy outcome is not mispredicted as a wall pull.
	# Damage/status stay server-only: SimWorld.apply_damage is a no-op off the server.
	pr.predicted = false
	harpoon = pr
	harpoon_id = pr.id
	if ctx.is_server:
		pawn.stats.shots_fired += 1
	ctx.world.emit_custom(&"anchor", {"pawn": pawn.net_id, "from": origin, "dir": ctx.aim_dir, "on": true})


## Called by BallastAnchorHit from the projectile impact. ctx.target is the enemy hit (or null).
func on_anchor_hit(ctx: AbilityContext, authoritative: bool) -> void:
	if resolved:
		return
	resolved = true
	var target := ctx.target
	if target != null and target != pawn and target.team != pawn.team and target.alive:
		if not authoritative:
			return
		if target.status.unstoppable:
			return
		var hook := _hook_status()
		if hook:
			target.status.apply(hook, pawn)
		reeling = target
		reel_left = REEL_TIME
		if pawn.behavior and pawn.behavior.has_method("note_hook"):
			pawn.behavior.call("note_hook", target)
		ctx.world.emit_custom(&"anchor", {"pawn": pawn.net_id, "target": target.net_id, "on": true, "hooked": true})
		return
	# World hit: winch Ballast to the surface (predicted on the owning client).
	anchor_point = ctx.point + ctx.normal * 0.9
	var to := anchor_point - pawn.center()
	if to.length() < 1.5:
		ability.end(false)
		return
	pulling = true
	pull_time = 0.0
	last_dist = to.length()
	stall_ticks = 0


func _hook_status() -> StatusData:
	for e: AbilityEffect in ability.data.effects:
		if e is ApplyStatusEffect and (e as ApplyStatusEffect).status:
			return (e as ApplyStatusEffect).status
	return StatusLibrary.get_status(HOOK_STATUS)


func wants_movement_control() -> bool:
	return pulling


func modify_velocity(_velocity: Vector3, _dt: float) -> Vector3:
	var to := anchor_point - pawn.center()
	var d := to.length()
	if d < 1.3:
		pulling = false
		ability.end(false)
		return Vector3(_velocity.x * 0.3, maxf(_velocity.y, 3.5), _velocity.z * 0.3)
	# Stall detection: hooked around a corner or against a ledge -> let go.
	if d > last_dist - 0.02:
		stall_ticks += 1
	else:
		stall_ticks = 0
	last_dist = d
	if stall_ticks > 14:
		pulling = false
		ability.end(false)
		return Vector3(_velocity.x * 0.3, maxf(_velocity.y, 2.0), _velocity.z * 0.3)
	return to.normalized() * PULL_SPEED


func on_tick(ctx: AbilityContext, dt: float) -> void:
	if pulling:
		pull_time += dt
		if pawn.last_cmd.just_pressed(RF.BTN_JUMP):
			pulling = false
			ability.end(true)
		return
	if reeling != null:
		if not ctx.is_server:
			return
		if not is_instance_valid(reeling) or not reeling.alive or reeling.status.unstoppable:
			reeling = null
			ability.end(false)
			return
		reel_left -= dt
		var dest := pawn.center() + pawn.forward_flat() * 1.5
		var to := dest - reeling.center()
		var d := to.length()
		if d < 1.6 or reel_left <= 0.0:
			reeling.velocity = Vector3(0.0, minf(reeling.velocity.y, 0.0), 0.0)
			reeling = null
			ability.end(false)
			return
		var v := to.normalized() * REEL_SPEED
		if reeling.is_on_floor():
			v.y = maxf(v.y, 2.5)
		reeling.velocity = v
		reeling.movement.grounded = false
		return
	# Harpoon in flight: end when it is gone without a hit (expired / out of range).
	if harpoon_id >= 0 and not ctx.world.projectiles.has(harpoon_id) and not resolved:
		ability.end(false)


func on_end(ctx: AbilityContext, _cancelled: bool) -> void:
	pulling = false
	if reeling and is_instance_valid(reeling):
		reeling.velocity = Vector3(reeling.velocity.x * 0.2, reeling.velocity.y, reeling.velocity.z * 0.2)
	reeling = null
	ctx.world.emit_custom(&"anchor", {"pawn": pawn.net_id, "on": false})
