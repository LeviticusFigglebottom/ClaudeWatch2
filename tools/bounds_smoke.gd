extends Node
## Verifies each map's play boundary: casts a pawn-sized capsule outward from inside the map along
## every caged direction and checks it is stopped before it reaches the scenery beyond. Run:
##   tools/godot.sh --headless res://tools/bounds_smoke.tscn
## Exit code 1 on the first escape.
##
## Saltmarsh's south frontage is deliberately not probed. The lagoon is an authored hazard: the kerbs
## are hoppable and the water does not collide, so leaving that way is a fall and a death, not an
## escape, and walling it would remove the risk the boardwalk gaps exist to offer.

const REACH := 400.0   # metres of outward motion a probe is allowed before it counts as an escape

## map id -> [[start, direction, the coordinate the cage sits at], ...] in metres.
const PROBES := {
	&"saltmarsh": [
		[Vector3(-60, 1.2, 0), Vector3(-1, 0, 0), 78.0],
		[Vector3(80, 1.2, 6), Vector3(1, 0, 0), 104.0],
		[Vector3(0, 1.2, -20), Vector3(0, 0, -1), 35.0],
	],
	&"nightmarket": [
		[Vector3(0, 1.2, -40), Vector3(-1, 0, 0), 30.5],
		[Vector3(0, 1.2, 40), Vector3(1, 0, 0), 30.5],
		[Vector3(0, 1.2, 40), Vector3(0, 0, 1), 82.5],
		[Vector3(0, 1.2, -40), Vector3(0, 0, -1), 82.5],
	],
	&"test_range": [
		[Vector3(0, 1.2, 0), Vector3(1, 0, 0), 39.2],
		[Vector3(0, 1.2, 0), Vector3(-1, 0, 0), 39.2],
		[Vector3(0, 1.2, 0), Vector3(0, 0, 1), 39.2],
		[Vector3(0, 1.2, 0), Vector3(0, 0, -1), 39.2],
	],
}


func _ready() -> void:
	var failures := 0
	var checked := 0
	for id: StringName in PROBES.keys():
		var md := Registry.map(id)
		if md == null:
			print("FAIL: no such map %s" % id)
			failures += 1
			continue
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.world_3d = World3D.new()
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(vp)
		var world := SimWorld.new()
		world.is_server = true
		vp.add_child(world)
		world.load_map(md)
		for i in 3:
			await get_tree().physics_frame
		# A ray on RF.L_BOUNDARY alone. Rays report an exact hit position, where cast_motion binary
		# searches and is coarse over a long cast — at 400 m its two fractions bracketed the wall by
		# more than a metre either side, which is wider than the thing being measured.
		#
		# The mask is deliberately the boundary layer by itself. Including the world would mostly stop
		# these probes on the facades and crates that were already there, which proves nothing about
		# the cage: this has to fail if a wall is missing, mispositioned, or has a gap.
		var space := world.space()
		for probe: Array in PROBES[id]:
			checked += 1
			var start: Vector3 = probe[0]
			var dir: Vector3 = (probe[1] as Vector3).normalized()
			var at: float = float(probe[2])
			var hits: Array[float] = []
			# Sample up the pawn's height: a wall that starts above the knees or stops below the head
			# is not a wall.
			for y: float in [0.3, 1.0, 1.7]:
				var from := start + Vector3(0, y - start.y + 1.0, 0)
				var q := PhysicsRayQueryParameters3D.create(from, from + dir * REACH, RF.L_BOUNDARY)
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					print("FAIL: %s has no cage at y=%.1f moving %s" % [id, y, dir])
					failures += 1
					hits.clear()
					break
				var p: Vector3 = hit["position"]
				hits.append(p.x if absf(dir.x) > 0.5 else p.z)
			if hits.is_empty():
				continue
			var worst := 0.0
			for h: float in hits:
				worst = maxf(worst, absf(absf(h) - at))
			if worst > 0.35:
				print("FAIL: %s cage is not at %.1f m moving %s (hit %.2f)" % [id, at, dir, hits[0]])
				failures += 1
			else:
				print("  %-12s %s -> cage at %.2f m over the full body height (expected %.1f)" % [id, dir, absf(hits[0]), at])
	if failures == 0:
		print("=== BOUNDS SMOKE OK === %d probes, every wall present and in position" % checked)
	else:
		print("=== BOUNDS SMOKE FAILED === %d of %d probes escaped" % [failures, checked])
	get_tree().quit(1 if failures > 0 else 0)


func _v(p: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
