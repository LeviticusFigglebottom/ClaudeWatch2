extends AbilityBehavior
## Cairn Upthrust: the launch itself is a DashEffect in data. This behavior watches for the landing
## and turns it into a stone slam: enemies within SLAM_RADIUS take damage, a shove and a short slow.
## Ends the ability on landing so the slam happens exactly once, on the ground, and never on death.

const SLAM_RADIUS := 3.5
const SLAM_DAMAGE := 55.0
const SLAM_KNOCKBACK := 5.0
const MIN_AIR_TIME := 0.18

var air_time: float = 0.0
var slammed: bool = false


func on_activate(_ctx: AbilityContext) -> void:
	air_time = 0.0
	slammed = false


func on_tick(ctx: AbilityContext, dt: float) -> void:
	air_time += dt
	if air_time < MIN_AIR_TIME or slammed:
		return
	if not pawn.is_on_floor():
		return
	slammed = true
	var c := pawn.global_position + Vector3(0, 0.4, 0)
	if ctx.is_server:
		var slow := _slow_status()
		for q: Pawn in ctx.world.pawns_in_radius(c, SLAM_RADIUS, RF.enemy_team(pawn.team)):
			var closest := q.hitboxes.closest_point(c)
			if not ctx.world.has_line_of_sight(c, closest):
				continue
			var frac := lerpf(1.0, 0.6, clampf(closest.distance_to(c) / SLAM_RADIUS, 0.0, 1.0))
			var ev := DamageEvent.new()
			ev.source = pawn; ev.target = q; ev.amount = SLAM_DAMAGE * frac
			ev.type = RF.DamageType.SPLASH; ev.ability_id = ability.data.id
			ev.position = closest; ev.direction = (closest - c).normalized(); ev.knockback = SLAM_KNOCKBACK * frac
			ctx.world.apply_damage(ev)
			if slow and ev.dealt > 0.0:
				q.status.apply(slow, pawn)
	ctx.world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": pawn.global_position, "radius": SLAM_RADIUS, "vfx": &"cairn_upthrust_explosion", "ability": ability.data.id, "predicted": not ctx.is_server})
	ability.end(false)


func _slow_status() -> StatusData:
	for e: AbilityEffect in ability.data.effects:
		if e is ApplyStatusEffect and (e as ApplyStatusEffect).status:
			return (e as ApplyStatusEffect).status
	return null
