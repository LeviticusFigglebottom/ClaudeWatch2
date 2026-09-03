extends Node
## Placement audit for map props: flags props that float above their support, sink into it, or sit
## embedded inside other geometry. Run:
##   tools/godot.sh --headless res://tools/prop_audit.tscn [-- --map=<id>] [--tol=0.06] [--decos]
## Model props (Kenney glTF) are audited by default; --decos also audits primitive-mesh decorations.
## Output: one line per finding, plus a summary. Exit code 0 always (this is a report, not a gate).

const FLOAT_TOL := 0.06     # metres of air under a prop's footprint before it counts as floating
const SINK_TOL := 0.25      # metres of the prop below the surface it rests on before it counts as sunk
const EMBED_FRAC := 0.5     # fraction of the prop's height covered by other geometry -> embedded


func _ready() -> void:
	var only := String(App.launch_args.get("map", ""))
	var tol := float(App.launch_args.get("tol", FLOAT_TOL))
	var include_decos := App.launch_args.has("decos")
	# Merged chunks span a whole grid cell, which hides the individual surfaces props rest on.
	MapBuilder.merge_enabled = false
	var total := 0
	var findings := 0
	var maps_done := 0
	for id: StringName in Registry.map_ids():
		if only != "" and String(id) != only:
			continue
		var md := Registry.map(id)
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
		var builder := world.map_root as MapBuilder
		if builder == null or builder.props_root == null:
			print("[%s] no MapBuilder props root" % id)
			vp.queue_free()
			continue
		var space := world.space()
		# Every visual box in the map (blocks, decos, other props): supports that have no collision still count.
		var boxes: Array[AABB] = []
		var owners: Array[Node] = []
		_collect_boxes(builder, boxes, owners)
		var n := 0
		var bad := 0
		var ignored := 0
		for prop: Node in builder.props_root.get_children():
			if not (prop is Node3D):
				continue
			var p3 := prop as Node3D
			var ab := _world_aabb(p3)
			if ab.size.length() < 0.05:
				continue
			# Primitive decos (signs, lanterns, ropes, neon) are expected to hang on walls; audit them only on request.
			if not include_decos and p3 is MeshInstance3D:
				continue
			n += 1
			var label := "%s '%s'" % [id, _describe(p3)]
			if _is_waterborne(_describe(p3)):
				continue   # boats sit in water, which has no collision and no "top" to rest on
			if p3.has_meta("audit_ignore"):
				ignored += 1   # the map author marked this one as deliberately not resting on anything
				continue
			var centre := ab.get_center()
			var bottom := ab.position.y
			var top := ab.end.y
			# Support under the footprint: any visual box whose top is at the prop's bottom (within tol) and whose
			# XZ extent overlaps the footprint. Falls back to a physics ray (starting just above the bottom: a ray
			# that starts inside a slab never reports it).
			var supported := false
			var foot := Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z).grow(0.05)
			for i in boxes.size():
				if owners[i] == p3 or p3.is_ancestor_of(owners[i]):
					continue
				var b := boxes[i]
				var top_y := b.end.y
				if top_y > bottom - tol and top_y < bottom + SINK_TOL and b.position.y < bottom - 0.01:
					if foot.intersects(Rect2(b.position.x, b.position.z, b.size.x, b.size.z)):
						supported = true
						break
			if supported:
				continue
			var gap := _ray_gap(space, Vector3(centre.x, bottom + 0.02, centre.z), 6.0) - 0.02
			if gap < -0.02:
				print("FLOAT   %s: nothing under the footprint within 6 m (bottom y=%.2f at %s)" % [label, bottom, _v(centre)])
				bad += 1
			elif gap > tol:
				# Try the four footprint corners: a prop may rest on an edge (e.g. crates on a ledge).
				var best := gap
				for sx in [-0.45, 0.45]:
					for sz in [-0.45, 0.45]:
						var g := _ray_gap(space, Vector3(centre.x + ab.size.x * sx, bottom + 0.02, centre.z + ab.size.z * sz), 6.0)
						if g >= 0.0:
							best = minf(best, g - 0.02)
				if best > tol:
					print("FLOAT   %s: %.2f m of air under it (bottom y=%.2f at %s)" % [label, best, bottom, _v(centre)])
					bad += 1
			# Sunk: a ray from above the prop hits geometry well above its bottom but the hit is NOT the prop's own top.
			var hit := _ray_hit(space, Vector3(centre.x, top + 0.5, centre.z), Vector3.DOWN, top + 0.5 + 6.0)
			if hit.has("position"):
				var hy: float = hit["position"].y
				if hy > top + 0.05:
					var covered := (hy - bottom) / maxf(top - bottom, 0.01)
					if covered >= 1.0 + EMBED_FRAC:
						print("COVERED %s: geometry %.2f m above its top (hit y=%.2f at %s) - under a roof or embedded" % [label, hy - top, hy, _v(centre)])
						bad += 1
			# Sunk into the floor: support surface found well above the bottom (ray from the prop's mid-height down).
			var mid_hit := _ray_hit(space, Vector3(centre.x, bottom + (top - bottom) * 0.5, centre.z), Vector3.DOWN, 6.0)
			if mid_hit.has("position"):
				var sink: float = mid_hit["position"].y - bottom
				if sink > SINK_TOL and sink < (top - bottom) * 0.95:
					print("SUNK    %s: support surface %.2f m above its bottom (at %s)" % [label, sink, _v(centre)])
					bad += 1
		print("[%s] audited %d props, %d findings (%d marked audit_ignore)" % [id, n, bad, ignored])
		maps_done += 1
		total += n
		findings += bad
		# Deliberately not freed: tearing a loaded SimWorld down while the next map is being built
		# aborted the process partway through the loop, so an all-maps run reported only the first
		# map and looked like a clean pass. Three maps' geometry costs less than a silent gate.
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	print("prop audit: %d maps, %d props, %d findings" % [maps_done, total, findings])
	get_tree().quit(0)


func _collect_boxes(root: Node, boxes: Array[AABB], owners: Array[Node]) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh:
				boxes.append(mi.global_transform * mi.get_aabb())
				owners.append(_prop_owner(mi, root))
		for c: Node in n.get_children():
			stack.append(c)


## The props_root child that contains this mesh (so a prop's own parts don't count as its support).
func _prop_owner(n: Node, root: Node) -> Node:
	var cur := n
	while cur and cur.get_parent() and cur.get_parent().name != "Props" and cur != root:
		cur = cur.get_parent()
	return cur


func _ray_hit(space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, length: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * length, RF.L_WORLD)
	return space.intersect_ray(q)


## Air gap under a point; -1 if nothing within `length`.
func _ray_gap(space: PhysicsDirectSpaceState3D, from: Vector3, length: float) -> float:
	var hit := _ray_hit(space, from, Vector3.DOWN, length)
	if hit.is_empty():
		return -1.0
	return from.y - float(hit["position"].y)


func _world_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var box := mi.global_transform * mi.get_aabb()
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c: Node in n.get_children():
			stack.append(c)
	return result


func _is_waterborne(name: String) -> bool:
	for k: String in ["boat", "canoe", "ship", "mast", "buoy", "raft"]:
		if name.to_lower().contains(k):
			return true
	return false


func _describe(n: Node3D) -> String:
	if n.scene_file_path != "":
		return n.scene_file_path.get_file().get_basename()
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		return (n as MeshInstance3D).mesh.get_class()
	return n.name


func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]
