class_name HealthPack
extends Node3D
## Map pickup: heals the first pawn that walks over it, then respawns after a timer.

var large: bool = false
var world: SimWorld
var available: bool = true
var respawn_timer: float = 0.0
var radius: float = 1.1


func step(dt: float) -> void:
	if not available:
		respawn_timer -= dt
		if respawn_timer <= 0.0:
			available = true
			world.emit_custom(&"pickup_state", {"pos": global_position, "on": true})
		return
	if not world.is_server:
		return
	for p: Pawn in world.pawns.values():
		if not p.alive:
			continue
		if p.health.missing() <= 0.0:
			continue
		if p.global_position.distance_to(global_position) <= radius:
			var amount := world.tuning.health_pack_large if large else world.tuning.health_pack_small
			world.apply_heal(null, p, amount, &"health_pack")
			available = false
			respawn_timer = world.tuning.health_pack_large_respawn if large else world.tuning.health_pack_small_respawn
			world.emit_custom(&"pickup_state", {"pos": global_position, "on": false, "pawn": p.net_id, "large": large})
			return


func time_until_available() -> float:
	return 0.0 if available else respawn_timer
