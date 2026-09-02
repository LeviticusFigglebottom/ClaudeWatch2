class_name RookGroundZero
extends Deployable
## Rook ult Ground Zero: a gravity well. For `charge_time` seconds every enemy within `radius` is
## dragged toward the center (velocity blend each tick: single impulses die to ground friction) and
## slowed; then it detonates for `damage` (falloff to 60% at the edge) with an upward shove, and
## removes itself. Indestructible (health 0) and not targetable. data: radius, charge_time, damage,
## slow (status id).

const PULL_SPEED := 6.0
const SLOW_TICK := 0.1
const RING_EVERY := 0.5

var _slow_accum: float = 0.0
var _ring_accum: float = 0.0
var _detonated: bool = false


func on_placed() -> void:
	targetable = false
	lifetime = 0.0
	if visual_id == &"":
		visual_id = &"rook_well"


func step(dt: float) -> void:
	age += dt
	if destroyed or world == null or not world.is_server or _detonated:
		return
	var radius: float = float(data.get("radius", 8.0))
	var charge: float = float(data.get("charge_time", 2.5))
	var center := global_position + Vector3(0, 0.9, 0)
	_slow_accum += dt
	_ring_accum += dt
	var apply_slow := _slow_accum >= SLOW_TICK
	if apply_slow:
		_slow_accum -= SLOW_TICK
	var slow: StatusData = StatusLibrary.get_status(StringName(String(data.get("slow", "rook_well_slow"))))
	for q: Pawn in world.pawns_in_radius(center, radius, RF.enemy_team(team)):
		if q.status.unstoppable:
			continue
		var to := center - q.center()
		var flat := Vector3(to.x, 0, to.z)
		var d := flat.length()
		if d > 1.0:
			var want := flat / d * PULL_SPEED * clampf(d / 3.0, 0.5, 1.0)
			q.velocity.x = lerpf(q.velocity.x, want.x, 0.5)
			q.velocity.z = lerpf(q.velocity.z, want.z, 0.5)
		else:
			q.velocity.x *= 0.4
			q.velocity.z *= 0.4
		if apply_slow and slow:
			q.status.apply(slow, owner_pawn)
	if _ring_accum >= RING_EVERY:
		_ring_accum -= RING_EVERY
		world.emit_custom(&"area", {"pawn": owner_pawn.net_id if owner_pawn else -1, "pos": global_position, "radius": radius, "vfx": &"rook_ground_zero_pull", "ability": ability_id})
	if age >= charge:
		_detonate(center, radius)


func _detonate(center: Vector3, radius: float) -> void:
	_detonated = true
	var dmg: float = float(data.get("damage", 200.0))
	for q: Pawn in world.pawns_in_radius(center, radius, RF.enemy_team(team)):
		var closest := q.hitboxes.closest_point(center)
		if not world.has_line_of_sight(center, closest):
			continue
		var frac := lerpf(1.0, 0.6, clampf(closest.distance_to(center) / radius, 0.0, 1.0))
		var ev := DamageEvent.new()
		ev.source = owner_pawn; ev.target = q; ev.amount = dmg * frac
		ev.type = RF.DamageType.SPLASH; ev.ability_id = ability_id
		ev.position = closest; ev.direction = Vector3(0, 1, 0); ev.knockback = 9.0 * frac
		world.apply_damage(ev)
	world.emit_custom(&"area", {"pawn": owner_pawn.net_id if owner_pawn else -1, "pos": global_position, "radius": radius, "vfx": &"rook_ground_zero_explosion", "ability": ability_id})
	destroy(null)
