extends Node
## Headless: builds every hero from tools/authoring/heroes/*.gd into data/heroes/<id>.tres.
## Run: godot --headless --path . -s tools/build_data.gd

func _ready() -> void:
	var dir := DirAccess.open("res://tools/authoring/heroes")
	var count := 0
	var names: Array[String] = []
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".gd"):
				names.append(f)
			f = dir.get_next()
	names.sort()
	DirAccess.make_dir_recursive_absolute("res://data/heroes")
	for f: String in names:
		var script := load("res://tools/authoring/heroes/" + f) as GDScript
		if script == null:
			push_error("cannot load " + f)
			continue
		var h: HeroData = script.call("build")
		if h == null:
			push_error("builder returned null: " + f)
			continue
		_mark_local(h)
		var path := "res://data/heroes/%s.tres" % h.id
		var err := ResourceSaver.save(h, path)
		if err != OK:
			push_error("save failed for %s: %s" % [h.id, error_string(err)])
		else:
			count += 1
			print("built %s -> %s" % [h.id, path])
	print("built %d heroes" % count)
	get_tree().quit()


## Ensure sub-resources are saved inline (no separate files).
func _mark_local(r: Resource, seen: Dictionary = {}) -> void:
	if r == null or seen.has(r):
		return
	seen[r] = true
	r.resource_local_to_scene = false
	for prop: Dictionary in r.get_property_list():
		if prop["type"] == TYPE_OBJECT:
			var v: Variant = r.get(prop["name"])
			if v is Resource and not (v is Script) and not (v is Texture2D):
				var sub := v as Resource
				if sub.resource_path == "" or sub.resource_path.begins_with("res://data/"):
					pass
				_mark_local(sub, seen)
		elif prop["type"] == TYPE_ARRAY:
			var arr: Variant = r.get(prop["name"])
			if arr is Array:
				for item: Variant in arr:
					if item is Resource and not (item is Script):
						_mark_local(item, seen)
