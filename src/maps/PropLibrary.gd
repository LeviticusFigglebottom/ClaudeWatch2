class_name PropLibrary
## Instances Kenney glTF props from res://assets/models/ with a scene cache and box collision.

static var _cache: Dictionary = {}


static func instance(rel_path: String) -> Node3D:
	var path := "res://assets/models/%s" % rel_path
	if not _cache.has(path):
		if ResourceLoader.exists(path):
			_cache[path] = load(path)
		else:
			_cache[path] = null
			push_warning("PropLibrary: missing %s" % path)
	var scene: PackedScene = _cache[path]
	if scene == null:
		return null
	var node := scene.instantiate() as Node3D
	return node


static func add_box_collision(node: Node3D, static_root: StaticBody3D, pos: Vector3, yaw: float, scale_f: float) -> void:
	var aabb := _aabb(node)
	if aabb.size.length() < 0.05:
		return
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = aabb.size * scale_f
	cs.shape = bs
	cs.position = pos + (aabb.position + aabb.size * 0.5).rotated(Vector3.UP, yaw) * scale_f
	cs.rotation.y = yaw
	static_root.add_child(cs)


static func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var local := mi.get_aabb()
			var xf := _relative_transform(mi, node)
			var box := xf * local
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c: Node in n.get_children():
			stack.append(c)
	return result


static func _relative_transform(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D()
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
