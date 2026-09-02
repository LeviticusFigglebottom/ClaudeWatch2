class_name TallowVigilWard
extends Deployable
## Vigil's ward: follows Tallow for its 5 s lifetime. Every 0.25 s it grants `status` (Vigil) to
## allies within `radius` who lack it (late arrivals), and every tick it watches Vigil'd allies:
## the first time one drops below `threshold` total health it applies `trigger` (Last Light, 1 s
## invulnerable) once. Together with Vigil's 70% damage reduction this approximates "cannot drop
## below 1 hp" until a shared status flag exists (docs/REQUESTS.md).

var _accum: float = 0.0
var _fired: Dictionary = {}     # net_id -> true once Last Light has triggered for that ally
var _vigil: StatusData
var _trigger: StatusData


func on_placed() -> void:
	targetable = false
	if visual_id == &"":
		visual_id = &"tallow_vigil_ward"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or not world.is_server:
		return
	if owner_pawn == null or not owner_pawn.alive:
		destroy(null)
		return
	global_position = owner_pawn.global_position
	if _vigil == null:
		_vigil = StatusLibrary.get_status(StringName(String(data.get("status", "tallow_vigil"))))
	if _trigger == null:
		_trigger = StatusLibrary.get_status(StringName(String(data.get("trigger", "tallow_last_light"))))
	var radius: float = float(data.get("radius", 12.0))
	var threshold: float = float(data.get("threshold", 30.0))
	var remaining := maxf(lifetime - age, 0.1)
	_accum += dt
	var refresh := _accum >= 0.25
	if refresh:
		_accum = 0.0
	for a: Pawn in world.pawns_in_radius(global_position, radius, team):
		if _vigil and refresh and not a.status.has(_vigil.id):
			a.status.apply(_vigil, owner_pawn, remaining)
		if _trigger and a.status.has(_vigil.id if _vigil else &"tallow_vigil") and not _fired.has(a.net_id) and a.health.total() < threshold:
			a.status.apply(_trigger, owner_pawn)
			_fired[a.net_id] = true
			world.emit_custom(&"area", {"pawn": owner_pawn.net_id, "pos": a.global_position, "radius": 1.8, "vfx": &"tallow_last_light", "ability": ability_id})
