extends Control
## Host a match on this machine (friends join by address) — plus a direct-connect box.

const TEAM_SIZES := [5, 6, 3, 1]

var name_edit: LineEdit
var port_edit: LineEdit
var mode_opt: OptionButton
var map_opt: OptionButton
var size_opt: OptionButton
var diff_opt: OptionButton
var fill_toggle: ToggleSwitch
var desc: Label
var addr_edit: LineEdit
var ip_box: VBoxContainer
var ips: Array[String] = []


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)
	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	vb.add_child(head)
	head.add_child(UITheme.heading("Host a Match", 40))
	var sub := UITheme.label("The server runs on this machine. Friends join with one of your addresses.", 14, UITheme.TEXT_DIM, true)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	var back := UITheme.button("Back", 16, 130)
	back.pressed.connect(func() -> void: UIRouter.show(&"main_menu"))
	head.add_child(back)
	# Body
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	body.add_child(_build_host_panel())
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 440
	body.add_child(right)
	right.add_child(_build_address_panel())
	right.add_child(_build_connect_panel())
	_refresh_maps()
	_refresh_ips()


## --- Host ---------------------------------------------------------------------------------------

func _build_host_panel() -> Control:
	var p := UITheme.panel(24)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 1.35
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(_section("Match setup"))
	name_edit = LineEdit.new()
	name_edit.text = String(Settings.get_value(&"gameplay", "player_name"))
	name_edit.max_length = 20
	name_edit.placeholder_text = "Runner"
	v.add_child(_row("Runner name", name_edit))
	port_edit = LineEdit.new()
	port_edit.text = str(int(Settings.get_value(&"network", "port")))
	port_edit.max_length = 5
	port_edit.custom_minimum_size.x = 140
	port_edit.text_changed.connect(func(_t: String) -> void: _refresh_ips())
	var port_row := HBoxContainer.new()
	port_row.add_theme_constant_override("separation", 12)
	port_row.add_child(port_edit)
	var port_hint := UITheme.label("UDP · forward it on your router for internet play", 12, UITheme.TEXT_DIM, true)
	port_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	port_row.add_child(port_hint)
	v.add_child(_row("Port", port_row))
	v.add_child(UITheme.separator())
	mode_opt = OptionButton.new()
	for id: StringName in Registry.mode_ids():
		mode_opt.add_item(Registry.mode(id).display_name)
		mode_opt.set_item_metadata(mode_opt.item_count - 1, id)
	mode_opt.item_selected.connect(func(_i: int) -> void: _refresh_maps())
	v.add_child(_row("Mode", mode_opt))
	map_opt = OptionButton.new()
	map_opt.item_selected.connect(func(_i: int) -> void: _refresh_desc())
	v.add_child(_row("Map", map_opt))
	desc = UITheme.label("", 13, UITheme.TEXT_DIM, true)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 40
	v.add_child(_row("", desc))
	v.add_child(UITheme.separator())
	size_opt = OptionButton.new()
	for n: String in ["5v5", "6v6", "3v3", "1v1 duel"]:
		size_opt.add_item(n)
	v.add_child(_row("Team size", size_opt))
	fill_toggle = ToggleSwitch.new()
	fill_toggle.button_pressed = true
	var fill_row := HBoxContainer.new()
	fill_row.add_theme_constant_override("separation", 12)
	fill_row.add_child(fill_toggle)
	var fill_hint := UITheme.label("Bots hold empty slots and step out as friends join", 12, UITheme.TEXT_DIM, true)
	fill_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fill_row.add_child(fill_hint)
	v.add_child(_row("Fill with bots", fill_row))
	diff_opt = OptionButton.new()
	for n: String in ["Recruit", "Regular", "Veteran", "Elite"]:
		diff_opt.add_item(n)
	diff_opt.selected = clampi(int(Settings.get_value(&"gameplay", "bot_difficulty")), 0, 3)
	v.add_child(_row("Bot skill", diff_opt))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 10)
	v.add_child(actions)
	var start := UITheme.button("Start Hosting", 20, 240)
	start.pressed.connect(_start_hosting)
	actions.add_child(start)
	return p


func _row(label: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := UITheme.label(label, 15, UITheme.TEXT_DIM)
	l.custom_minimum_size.x = 150
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	return h


func _section(title: String) -> Label:
	return UITheme.label(title.to_upper(), 13, UITheme.AMBER, true)


func _refresh_maps() -> void:
	map_opt.clear()
	var mode_id: StringName = mode_opt.get_item_metadata(mode_opt.selected) if mode_opt.item_count > 0 else &""
	for m: MapData in Registry.maps_for_mode(mode_id):
		map_opt.add_item(m.display_name)
		map_opt.set_item_metadata(map_opt.item_count - 1, m.id)
	if map_opt.item_count == 0:
		for id: StringName in Registry.map_ids():
			map_opt.add_item(Registry.map(id).display_name)
			map_opt.set_item_metadata(map_opt.item_count - 1, id)
	_refresh_desc()


func _refresh_desc() -> void:
	if map_opt.item_count == 0:
		desc.text = "No maps available."
		return
	var m := Registry.map(map_opt.get_item_metadata(map_opt.selected))
	desc.text = "%s — %s\n%s" % [m.location, m.time_of_day, m.description] if m else ""


func _port() -> int:
	var p := int(port_edit.text) if port_edit.text.is_valid_int() else int(Settings.get_value(&"network", "port"))
	return clampi(p, 1024, 65535)


func _start_hosting() -> void:
	if map_opt.item_count == 0:
		EventBus.notification.emit("No map available for this mode.", &"error")
		return
	var port := _port()
	Settings.set_value(&"network", "port", port)
	if name_edit.text.strip_edges() != "":
		Settings.set_value(&"gameplay", "player_name", name_edit.text.strip_edges())
	Settings.set_value(&"gameplay", "bot_difficulty", diff_opt.selected)
	var team: int = TEAM_SIZES[clampi(size_opt.selected, 0, TEAM_SIZES.size() - 1)]
	var fill := fill_toggle.button_pressed
	var cfg := MatchConfig.new()
	cfg.map_id = map_opt.get_item_metadata(map_opt.selected)
	cfg.mode_id = mode_opt.get_item_metadata(mode_opt.selected)
	cfg.bot_count = 0
	cfg.bot_fill = fill
	cfg.bot_difficulty = diff_opt.selected
	cfg.team_size = team
	cfg.max_players = maxi(team * 2, 2)
	App.host_online(port, cfg)


## --- Addresses --------------------------------------------------------------------------------------

func _build_address_panel() -> Control:
	var p := UITheme.panel(20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_section("Your addresses"))
	var hint := UITheme.label("Friends on the same network connect to one of these. For the internet, share your public IP and forward the port.", 12, UITheme.TEXT_DIM, true)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	ip_box = VBoxContainer.new()
	ip_box.add_theme_constant_override("separation", 6)
	v.add_child(ip_box)
	return p


func _refresh_ips() -> void:
	ips.clear()
	for a: String in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254.") or a.begins_with("0."):
			continue
		if not ips.has(a):
			ips.append(a)
	for c: Node in ip_box.get_children():
		ip_box.remove_child(c)
		c.queue_free()
	var port := _port()
	if ips.is_empty():
		ip_box.add_child(UITheme.label("No network address found — you can still host on 127.0.0.1 for a local test.", 13, UITheme.TEXT_DIM, true))
	for ip: String in ips:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var addr := "%s:%d" % [ip, port]
		var l := UITheme.label(addr, 18, UITheme.TEXT)
		l.add_theme_font_override("font", UITheme.font_mono())
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var copy := UITheme.button("Copy", 13)
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(addr)
			copy.text = "COPIED"
			EventBus.notification.emit("Copied %s" % addr, &"info")
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if is_instance_valid(copy):
					copy.text = "COPY"))
		row.add_child(copy)
		ip_box.add_child(row)


## --- Direct connect ----------------------------------------------------------------------------------

func _build_connect_panel() -> Control:
	var p := UITheme.panel(20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_section("Direct connect"))
	v.add_child(UITheme.label("Join a friend's match by address.", 12, UITheme.TEXT_DIM, true))
	addr_edit = LineEdit.new()
	addr_edit.text = String(Settings.get_value(&"network", "last_address"))
	addr_edit.placeholder_text = "address[:port]"
	addr_edit.text_submitted.connect(func(_t: String) -> void: _connect())
	v.add_child(addr_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var go := UITheme.button("Connect", 16, 160)
	go.pressed.connect(_connect)
	row.add_child(go)
	return p


func _connect() -> void:
	var text := addr_edit.text.strip_edges()
	if text == "":
		return
	var parts := text.split(":")
	var host := parts[0].strip_edges()
	var port := int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else int(Settings.get_value(&"network", "port"))
	Settings.set_value(&"network", "last_address", text)
	App.join_online(host, port)
