class_name LanternDeployable
extends Deployable
## Vesper's lantern: a lit zone that re-applies Reveal to enemies inside every 0.5 s.

var _accum: float = 0.0


func step(dt: float) -> void:
	super.step(dt)
	if not world.is_server or destroyed:
		return
	_accum += dt
	if _accum < 0.5:
		return
	_accum = 0.0
	var radius: float = float(data.get("radius", 12.0))
	var sd := StatusLibrary.get_status(StringName(String(data.get("status", "revealed_lantern"))))
	if sd == null:
		return
	for p: Pawn in world.pawns_in_radius(global_position, radius, RF.enemy_team(team)):
		p.status.apply(sd, owner_pawn, 1.2)
