class_name TallowHealProjectile
extends Projectile
## Wax Bolt: a projectile that also sweeps ALLY hitboxes. Touching an ally heals them for `heal`
## and ends the bolt; hitting an enemy does the (small) base damage; hitting the world bursts and
## heals every ally within `burst_radius` of the impact point.

var heal: float = 45.0
var burst_radius: float = 2.5


func step(dt: float) -> void:
	if not predicted and not stuck and age < lifetime:
		var v := vel
		v.y -= gravity * dt
		var motion := v * dt
		var dist := motion.length()
		if dist > 0.00001:
			var dir := motion / dist
			var from := global_position
			var best: HitboxSet.HitResult = null
			for p: Pawn in world.pawns.values():
				if not p.alive or p == owner_pawn or p.team != team:
					continue
				var r := p.hitboxes.raycast(from, dir, dist + radius, -1)
				if r.hit and (best == null or r.distance < best.distance):
					best = r
			if best != null:
				var wres := world.raycast_world(from, dir, best.distance, team, true)
				if wres.is_empty():
					_heal_touch(best.pawn, best.point, dir)
					return
	super.step(dt)


func _heal_touch(p: Pawn, point: Vector3, dir: Vector3) -> void:
	global_position = point
	world.apply_heal(owner_pawn, p, heal, ability_id)
	if owner_pawn:
		owner_pawn.stats.shots_hit += 1
	world.on_projectile_impact(self, point, -dir, p)
	queue_free_safe()


func _impact(point: Vector3, normal: Vector3, dir: Vector3, r: HitboxSet.HitResult) -> void:
	if not predicted and burst_radius > 0.0:
		for q: Pawn in world.pawns_in_radius(point, burst_radius, team):
			if world.has_line_of_sight(point + normal * 0.1, q.center(), RF.L_WORLD):
				world.apply_heal(owner_pawn, q, heal, ability_id)
	super._impact(point, normal, dir, r)
