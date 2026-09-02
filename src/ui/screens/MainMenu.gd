extends Control
## Main menu: PLAY (vs bots), TRAINING, HOST, JOIN, SETTINGS, QUIT. Background is a slow map flythrough
## when a world is loaded; otherwise a styled gradient with the ring motif.

var bg_layer: Control


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ring := RingMotif.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ring)
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 80; root.offset_top = 60; root.offset_right = -80; root.offset_bottom = -60
	add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 10)
	root.add_child(left)
	var title := UITheme.heading("RINGFALL", 92)
	left.add_child(title)
	var sub := UITheme.label("Ten Runners. Two Charters. One Core.", 20, UITheme.TEXT_DIM, true)
	left.add_child(sub)
	left.add_child(_spacer(30))
	var items := [
		["Play vs Bots", func() -> void: UIRouter.show(&"play")],
		["Training Range", func() -> void: App.start_local_match(&"test_range", &"control", 4, {"difficulty": 1})],
		["Host Match", func() -> void: UIRouter.show(&"lobby")],
		["Join Match", func() -> void: _show_join()],
		["Settings", func() -> void: UIRouter.show_overlay(&"settings")],
		["Quit", func() -> void: App.quit()],
	]
	for it: Array in items:
		var b := UITheme.button(it[0], 22, 320)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[1])
		left.add_child(b)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(right)
	var info := UITheme.label("v%s  ·  %d heroes  ·  %d maps  ·  %d modes" % [RF.VERSION, Registry.heroes.size(), Registry.maps.size(), Registry.modes.size()], 14, UITheme.TEXT_DIM, true)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(info)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(name_row)
	name_row.add_child(UITheme.label("Runner name", 14, UITheme.TEXT_DIM))
	var name_edit := LineEdit.new()
	name_edit.text = String(Settings.get_value(&"gameplay", "player_name"))
	name_edit.custom_minimum_size.x = 200
	name_edit.max_length = 20
	name_edit.text_changed.connect(func(t: String) -> void: Settings.set_value(&"gameplay", "player_name", t))
	name_row.add_child(name_edit)
	if App.client == null and App.client == null:
		pass


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _show_join() -> void:
	var d := UITheme.panel(20)
	d.set_anchors_preset(Control.PRESET_CENTER)
	d.custom_minimum_size = Vector2(420, 200)
	d.position = Vector2(size.x * 0.5 - 210, size.y * 0.5 - 100)
	add_child(d)
	var vb := VBoxContainer.new()
	d.add_child(vb)
	vb.add_child(UITheme.heading("Join", 28))
	var addr := LineEdit.new()
	addr.text = String(Settings.get_value(&"network", "last_address"))
	addr.placeholder_text = "address[:port]"
	vb.add_child(addr)
	var row := HBoxContainer.new()
	vb.add_child(row)
	var go := UITheme.button("Connect", 18)
	go.pressed.connect(func() -> void:
		var parts := addr.text.split(":")
		var host := parts[0].strip_edges()
		var port := int(parts[1]) if parts.size() > 1 else int(Settings.get_value(&"network", "port"))
		Settings.set_value(&"network", "last_address", addr.text)
		App.join_online(host, port))
	row.add_child(go)
	var cancel := UITheme.button("Cancel", 18)
	cancel.pressed.connect(d.queue_free)
	row.add_child(cancel)


class RingMotif extends Control:
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
	func _draw() -> void:
		var c := Vector2(size.x * 0.72, size.y * 0.42)
		for i in 5:
			var r := 180.0 + i * 70.0
			var col := UITheme.AMBER
			col.a = 0.06 - i * 0.008
			draw_arc(c, r, t * 0.05 * (1 + i * 0.3), t * 0.05 * (1 + i * 0.3) + PI * 1.4, 96, col, 3.0 + i * 2.0, true)
		var cb := Color(0.16, 0.66, 0.98, 0.05)
		draw_arc(c, 120.0, -t * 0.1, -t * 0.1 + PI * 0.8, 64, cb, 6.0, true)
		# Falling "core" sparks
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 40:
			var x := rng.randf() * size.x
			var speed := 20.0 + rng.randf() * 40.0
			var y := fposmod(rng.randf() * size.y + t * speed, size.y)
			var a := 0.05 + rng.randf() * 0.15
			draw_line(Vector2(x, y), Vector2(x - 3.0, y - 12.0), Color(1, 0.8, 0.5, a), 1.0)
