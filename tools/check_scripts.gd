extends Node
## Loads every .gd under res://src, res://tools, res://tests and reports scripts that fail to compile.

func _ready() -> void:
	var bad := 0
	var total := 0
	for root: String in ["res://src", "res://tools", "res://tests"]:
		for path: String in _collect(root):
			total += 1
			var s := ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE) as GDScript
			if s == null:
				print("LOAD FAIL: " + path)
				bad += 1
				continue
			if not s.can_instantiate() and not s.is_abstract():
				var err := s.reload(true)
				if err != OK:
					print("COMPILE FAIL: %s (%s)" % [path, error_string(err)])
					bad += 1
	print("checked %d scripts, %d failed" % [total, bad])
	get_tree().quit(1 if bad > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var p := dir_path.path_join(f)
		if dir.current_is_dir():
			if not f.begins_with("."):
				out.append_array(_collect(p))
		elif f.ends_with(".gd"):
			out.append(p)
		f = dir.get_next()
	return out
