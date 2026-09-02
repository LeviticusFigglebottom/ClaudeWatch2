class_name HitboxSet
extends RefCounted
## Analytic hitboxes (head sphere + body capsule) with a position history ring for lag compensation.
## No physics Areas: hit tests are pure math so rewinding is exact and cheap.

class HistoryEntry:
	var tick: int = -1
	var position: Vector3
	var yaw: float
	var crouch: float   # 0..1
	var alive: bool

class HitResult:
	var hit: bool = false
	var distance: float = INF
	var point: Vector3
	var normal: Vector3
	var part: StringName = &""   # "head", "body"
	var pawn: Pawn

var profile: HitboxProfile
var pawn: Pawn
var _history: Array[HistoryEntry] = []
var _head: int = 0


func setup(p: Pawn, prof: HitboxProfile) -> void:
	pawn = p
	profile = prof
	_history.resize(RF.HISTORY_TICKS)
	for i in RF.HISTORY_TICKS:
		_history[i] = HistoryEntry.new()


func record(tick: int) -> void:
	_head = (_head + 1) % RF.HISTORY_TICKS
	var e := _history[_head]
	e.tick = tick
	e.position = pawn.global_position
	e.yaw = pawn.yaw
	e.crouch = pawn.movement.crouch_amount if pawn.movement else 0.0
	e.alive = pawn.alive


func entry_at(tick: int) -> HistoryEntry:
	if tick < 0:
		return null
	for i in RF.HISTORY_TICKS:
		var idx := (_head - i + RF.HISTORY_TICKS) % RF.HISTORY_TICKS
		var e := _history[idx]
		if e.tick == tick:
			return e
		if e.tick < tick and e.tick >= 0:
			return e   # closest older tick
	return null


## Ray test against this pawn's hitboxes at the given tick (or current if tick < 0 / not found).
func raycast(origin: Vector3, dir: Vector3, max_dist: float, at_tick: int = -1) -> HitResult:
	var res := HitResult.new()
	var pos := pawn.global_position
	var crouch := pawn.movement.crouch_amount if pawn.movement else 0.0
	var alive := pawn.alive
	if at_tick >= 0:
		var e := entry_at(at_tick)
		if e:
			pos = e.position; crouch = e.crouch; alive = e.alive
	if not alive:
		return res
	# Head sphere
	if profile.headshot_enabled:
		var head_c := pos + Vector3(0, lerpf(profile.head_height, profile.head_crouch_height, crouch), 0)
		var t := _ray_sphere(origin, dir, head_c, profile.head_radius)
		if t >= 0.0 and t <= max_dist:
			res.hit = true; res.distance = t; res.part = &"head"
			res.point = origin + dir * t
			res.normal = (res.point - head_c).normalized()
	# Body capsule
	var a := pos + Vector3(0, profile.body_bottom, 0)
	var b := pos + Vector3(0, lerpf(profile.body_top, profile.body_crouch_top, crouch), 0)
	var tb := _ray_capsule(origin, dir, a, b, profile.body_radius)
	if tb >= 0.0 and tb <= max_dist and tb < res.distance:
		res.hit = true; res.distance = tb; res.part = &"body"
		res.point = origin + dir * tb
		var closest := Geometry3D.get_closest_point_to_segment(res.point, a, b)
		res.normal = (res.point - closest).normalized()
	if res.hit:
		res.pawn = pawn
	return res


## Whether a sphere overlaps the pawn's body (for splash / melee / area checks). Uses current position.
func overlaps_sphere(center: Vector3, radius: float, at_tick: int = -1) -> bool:
	var pos := pawn.global_position
	var crouch := pawn.movement.crouch_amount if pawn.movement else 0.0
	if at_tick >= 0:
		var e := entry_at(at_tick)
		if e:
			pos = e.position; crouch = e.crouch
	var a := pos + Vector3(0, profile.body_bottom, 0)
	var b := pos + Vector3(0, lerpf(profile.head_height + profile.head_radius, profile.head_crouch_height + profile.head_radius, crouch), 0)
	var closest := Geometry3D.get_closest_point_to_segment(center, a, b)
	return closest.distance_to(center) <= radius + profile.body_radius


func closest_point(from: Vector3) -> Vector3:
	var pos := pawn.global_position
	var a := pos + Vector3(0, profile.body_bottom, 0)
	var b := pos + Vector3(0, profile.body_top, 0)
	return Geometry3D.get_closest_point_to_segment(from, a, b)


static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var m := o - c
	var b := m.dot(d)
	var cc := m.dot(m) - r * r
	if cc > 0.0 and b > 0.0:
		return -1.0
	var disc := b * b - cc
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return maxf(t, 0.0)


## Ray vs capsule (segment a-b with radius r). Returns distance along ray or -1.
static func _ray_capsule(o: Vector3, d: Vector3, a: Vector3, b: Vector3, r: float) -> float:
	var ab := b - a
	var ao := o - a
	var ab_len2 := ab.dot(ab)
	var best := -1.0
	if ab_len2 > 0.000001:
		# Infinite cylinder intersection
		var ab_d := ab.dot(d)
		var ab_ao := ab.dot(ao)
		var A := ab_len2 - ab_d * ab_d
		var B := ab_len2 * ao.dot(d) - ab_ao * ab_d
		var C := ab_len2 * ao.dot(ao) - ab_ao * ab_ao - r * r * ab_len2
		if absf(A) > 0.000001:
			var disc := B * B - A * C
			if disc >= 0.0:
				var t := (-B - sqrt(disc)) / A
				if t >= 0.0:
					var y := ab_ao + t * ab_d
					if y >= 0.0 and y <= ab_len2:
						best = t
	# Caps
	var t1 := _ray_sphere(o, d, a, r)
	var t2 := _ray_sphere(o, d, b, r)
	for t: float in [t1, t2]:
		if t >= 0.0 and (best < 0.0 or t < best):
			best = t
	return best
