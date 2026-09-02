class_name BombardSpotterDrone
extends Deployable
## Bombard's spotter drone: parked at a ground point, it hovers `hover` m up and re-applies the
## short Spotted (revealed) status to every enemy within `radius` of the hover point every
## `interval` seconds. It has no body: only time (lifetime) removes it.

var _accum: float = 0.0
var _status: StatusData


func on_placed() -> void:
	targetable = false
	if visual_id == &"":
		visual_id = &"spotter_drone"


func hover_point() -> Vector3:
	return global_position + Vector3(0, float(data.get("hover", 4.0)), 0)


func step(dt: float) -> void:
	super.step(dt)
	if not world.is_server or destroyed:
		return
	_accum += dt
	var interval: float = float(data.get("interval", 0.5))
	if _accum < interval:
		return
	_accum = 0.0
	if _status == null:
		_status = StatusLibrary.get_status(StringName(String(data.get("status", "bombard_spotted"))))
		if _status == null:
			return
	var radius: float = float(data.get("radius", 10.0))
	var eye := hover_point()
	for p: Pawn in world.pawns_in_radius(eye, radius, RF.enemy_team(team)):
		p.status.apply(_status, owner_pawn, 1.2)
