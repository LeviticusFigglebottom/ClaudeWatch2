extends Node
## Checks that every VFX id the hero data references actually resolves to a builder or spawner,
## and that each one builds without error. Run:
##   tools/godot.sh --headless res://tools/vfx_audit.tscn
## Prints one line per unresolved id and a summary. Exit code 1 if anything is unresolved, so this
## can be used as a gate.

func _ready() -> void:
	VfxLibrary.load_extensions()
	var lib := VfxLibrary.new()
	add_child(lib)
	var referenced: Dictionary = {}        # id -> Array of "hero/ability/field"
	for hid: StringName in Registry.hero_ids():
		var h := Registry.hero(hid)
		if h == null:
			continue
		for ab: AbilityData in [h.primary, h.secondary, h.ability_1, h.ability_2, h.ability_3, h.ultimate]:
			if ab == null:
				continue
			var pres: AbilityPresentation = ab.presentation
			if pres == null:
				continue
			for field: String in ["muzzle_vfx", "impact_vfx", "cast_vfx", "loop_vfx", "end_vfx", "area_vfx"]:
				var id: StringName = pres.get(field)
				if id == &"":
					continue
				if not referenced.has(id):
					referenced[id] = []
				referenced[id].append("%s/%s/%s" % [hid, ab.id, field])
	var missing := 0
	var built := 0
	var failed := 0
	for id: StringName in referenced.keys():
		var has_builder: bool = VfxLibrary.custom_builders.has(id)
		var has_spawner: bool = VfxLibrary.custom_spawners.has(id)
		var has_builtin: bool = lib.has_builtin(id)
		if not (has_builder or has_spawner or has_builtin):
			print("UNRESOLVED %s  <- %s" % [id, ", ".join(referenced[id])])
			missing += 1
			continue
		if has_spawner:
			built += 1
			continue
		var p := lib.build_particles(id)
		if p == null:
			print("BUILD FAILED %s  <- %s" % [id, ", ".join(referenced[id])])
			failed += 1
		else:
			built += 1
			p.queue_free()
	print("vfx audit: %d referenced ids, %d resolved, %d unresolved, %d failed to build" % [referenced.size(), built, missing, failed])
	print("  registered: %d builders, %d spawners across %d hero modules" % [
		VfxLibrary.custom_builders.size(), VfxLibrary.custom_spawners.size(), _module_count()])
	get_tree().quit(1 if (missing + failed) > 0 else 0)


func _module_count() -> int:
	var n := 0
	var dir := DirAccess.open("res://src/vfx/hero_vfx")
	if dir == null:
		return 0
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			n += 1
		f = dir.get_next()
	return n
