class_name TacticalMap
extends RefCounted
## Baked spatial knowledge for a map: sampled navmesh nodes with cover directions, height, and
## visibility to objectives. Loaded from data/maps/tactical/<id>.json (produced by tools/bake_tactical)
## or baked at runtime on the server if the file is missing (a few hundred ms on the sim thread).

class TNode:
	var pos: Vector3
	var cover_mask: int = 0        # 8 bits: direction i (0 = +Z, clockwise 45°) has cover within 2.5 m
	var height: float = 0.0        # height above the map's median floor
	var openness: float = 1.0      # 0..1 fraction of 8 directions open to 30 m
	var obj_vis: PackedFloat32Array = PackedFloat32Array()   # per objective: 1 if LOS to the objective center

var nodes: Array[TNode] = []
var objectives: Array[Vector3] = []
var cell: float = 3.0
var baked: bool = false
var _grid: Dictionary = {}       # Vector2i -> Array[int]
var median_y: float = 0.0

const DIRS := [Vector3(0, 0, 1), Vector3(0.707, 0, 0.707), Vector3(1, 0, 0), Vector3(0.707, 0, -0.707), Vector3(0, 0, -1), Vector3(-0.707, 0, -0.707), Vector3(-1, 0, 0), Vector3(-0.707, 0, 0.707)]


static func load_or_bake(map_id: StringName, world: SimWorld, layout: MapLayout) -> TacticalMap:
	var tm := TacticalMap.new()
	var path := "res://data/maps/tactical/%s.json" % map_id
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var data: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if data is Dictionary:
			tm._from_dict(data)
			tm.baked = true
			return tm
	tm.bake(world, layout)
	return tm


func bake(world: SimWorld, layout: MapLayout) -> void:
	nodes.clear()
	_grid.clear()
	objectives.clear()
	for z: MapLayout.Zone in layout.control_points + layout.capture_points + layout.clash_points:
		objectives.append(z.center)
	if layout.payload_path:
		var L := layout.payload_path.get_baked_length()
		var steps := maxi(int(L / 15.0), 1)
		for i in steps + 1:
			objectives.append(layout.payload_path.sample_baked(L * i / steps, true))
	if layout.push_track:
		var L := layout.push_track.get_baked_length()
		for i in 5:
			objectives.append(layout.push_track.sample_baked(L * i / 4.0, true))
	if objectives.is_empty():
		objectives.append(Vector3.ZERO)
	var map_rid := world.get_world_3d().navigation_map
	var lo := layout.bounds_min
	var hi := layout.bounds_max
	var ys: Array[float] = []
	var x := lo.x
	while x <= hi.x:
		var z := lo.z
		while z <= hi.z:
			# Probe several heights: multi-level maps have stacked walkable surfaces.
			var y := hi.y
			var found: Array[float] = []
			while y > lo.y:
				var g := world.ground_point(Vector3(x, y, z), hi.y - lo.y)
				if g.y <= lo.y + 0.01 or g.y >= y - 0.05:
					break
				var closest := NavigationServer3D.map_get_closest_point(map_rid, g)
				if closest.distance_to(g) < 1.0 and not _near_existing(found, closest.y):
					found.append(closest.y)
					var n := TNode.new()
					n.pos = closest
					nodes.append(n)
					ys.append(closest.y)
				y = g.y - 2.2
			z += cell
		x += cell
	if ys.is_empty():
		baked = true
		return
	ys.sort()
	median_y = ys[ys.size() / 2]
	for n: TNode in nodes:
		n.height = n.pos.y - median_y
		var open := 0
		for i in 8:
			var d: Vector3 = DIRS[i]
			var from := n.pos + Vector3(0, 1.0, 0)
			var near := world.raycast_world(from, d, 2.5, -1, false)
			if not near.is_empty():
				n.cover_mask |= 1 << i
			var far := world.raycast_world(from, d, 30.0, -1, false)
			if far.is_empty():
				open += 1
		n.openness = open / 8.0
		n.obj_vis.resize(objectives.size())
		for oi in objectives.size():
			var o: Vector3 = objectives[oi]
			n.obj_vis[oi] = 1.0 if world.has_line_of_sight(n.pos + Vector3(0, 1.5, 0), o + Vector3(0, 1.0, 0)) else 0.0
	_rebuild_grid()
	baked = true


func _near_existing(found: Array[float], y: float) -> bool:
	for f: float in found:
		if absf(f - y) < 1.5:
			return true
	return false


func _rebuild_grid() -> void:
	_grid.clear()
	for i in nodes.size():
		var k := _key(nodes[i].pos)
		var arr: Array = _grid.get(k, [])
		arr.append(i)
		_grid[k] = arr


func _key(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / 12.0)), int(floor(p.z / 12.0)))


## Nodes within radius of a point.
func nodes_near(p: Vector3, radius: float) -> Array[TNode]:
	var out: Array[TNode] = []
	var k := _key(p)
	var r := int(ceil(radius / 12.0))
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for i: Variant in _grid.get(Vector2i(k.x + dx, k.y + dz), []):
				var n: TNode = nodes[int(i)]
				if n.pos.distance_to(p) <= radius:
					out.append(n)
	return out


## Does the node have cover against a threat direction (world-space, from node toward threat)?
func has_cover(n: TNode, toward_threat: Vector3) -> bool:
	var f := Vector3(toward_threat.x, 0, toward_threat.z).normalized()
	if f.length_squared() < 0.01:
		return false
	var ang := atan2(f.x, f.z)          # 0 = +Z
	var i := int(round(fposmod(ang, TAU) / (TAU / 8.0))) % 8
	return (n.cover_mask & (1 << i)) != 0


func nearest_objective_index(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in objectives.size():
		var d := objectives[i].distance_to(p)
		if d < bd:
			bd = d; best = i
	return best


func to_dict() -> Dictionary:
	var arr: Array = []
	for n: TNode in nodes:
		arr.append([snappedf(n.pos.x, 0.01), snappedf(n.pos.y, 0.01), snappedf(n.pos.z, 0.01), n.cover_mask, snappedf(n.height, 0.01), snappedf(n.openness, 0.01), Array(n.obj_vis)])
	var objs: Array = []
	for o: Vector3 in objectives:
		objs.append([o.x, o.y, o.z])
	return {"cell": cell, "median_y": median_y, "objectives": objs, "nodes": arr}


func _from_dict(d: Dictionary) -> void:
	cell = float(d.get("cell", 3.0))
	median_y = float(d.get("median_y", 0.0))
	objectives.clear()
	for o: Variant in d.get("objectives", []):
		objectives.append(Vector3(float(o[0]), float(o[1]), float(o[2])))
	nodes.clear()
	for a: Variant in d.get("nodes", []):
		var n := TNode.new()
		n.pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
		n.cover_mask = int(a[3])
		n.height = float(a[4])
		n.openness = float(a[5])
		var ov: Array = a[6]
		n.obj_vis.resize(ov.size())
		for i in ov.size():
			n.obj_vis[i] = float(ov[i])
		nodes.append(n)
	_rebuild_grid()
