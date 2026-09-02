extends Node
## Bakes tactical maps for every registered map into data/maps/tactical/<id>.json.
## Run: tools/godot.sh --headless res://tools/bake_tactical.tscn [-- --map=<id>]

func _ready() -> void:
	var only := String(App.launch_args.get("map", ""))
	DirAccess.make_dir_recursive_absolute("res://data/maps/tactical")
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
		# Let physics/navigation settle.
		for i in 3:
			await get_tree().physics_frame
		var layout := world.map_root.get_node_or_null("Layout") as MapLayout
		if layout == null:
			print("no layout for %s" % id)
			vp.queue_free()
			continue
		var tm := TacticalMap.new()
		var t0 := Time.get_ticks_msec()
		tm.bake(world, layout)
		var path := "res://data/maps/tactical/%s.json" % id
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(tm.to_dict()))
		f.close()
		print("baked %s: %d nodes, %d objectives in %d ms -> %s" % [id, tm.nodes.size(), tm.objectives.size(), Time.get_ticks_msec() - t0, path])
		vp.queue_free()
		await get_tree().process_frame
	get_tree().quit()
