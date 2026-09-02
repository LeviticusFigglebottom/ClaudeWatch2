class_name KilnVent
extends Deployable
## Kiln Vent: a floor grate that fires an updraft for its lifetime (5 s). Any ally (Kiln included)
## standing on it is launched straight up (about 4 m with the default impulse), at most once per
## LAUNCH_INTERVAL per pawn. Uses MovementController.apply_impulse directly so the bulwark knockback
## resistance does not weaken Kiln's own ride. data: radius, launch.

const LAUNCH_INTERVAL := 0.8

var _last_launch: Dictionary = {}   # net_id -> age at last launch


func on_placed() -> void:
	targetable = false
	if visual_id == &"":
		visual_id = &"kiln_vent"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or world == null or not world.is_server:
		return
	var radius: float = float(data.get("radius", 1.6))
	var launch: float = float(data.get("launch", 13.5))
	var probe := global_position + Vector3(0, 0.4, 0)
	for p: Pawn in world.pawns_in_radius(probe, radius, team):
		# Only pawns actually on the grate (not someone already flying above it).
		if p.global_position.y > global_position.y + 1.0 or p.global_position.y < global_position.y - 0.6:
			continue
		var last: float = float(_last_launch.get(p.net_id, -100.0))
		if age - last < LAUNCH_INTERVAL:
			continue
		_last_launch[p.net_id] = age
		p.velocity.y = maxf(p.velocity.y, 0.0)
		p.movement.apply_impulse(Vector3.UP * launch)
		p.movement.grounded = false
		world.emit_custom(&"area", {"pawn": owner_pawn.net_id if owner_pawn else -1, "pos": global_position, "radius": radius, "vfx": &"kiln_vent_gust", "ability": ability_id})
