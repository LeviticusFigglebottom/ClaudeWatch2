extends Control
## Quick play setup: mode, map, difficulty, team size.

var mode_opt: OptionButton
var map_opt: OptionButton
var diff_opt: OptionButton
var size_opt: OptionButton
var desc: Label


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new(); bg.color = UITheme.BG; bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
	var c := CenterContainer.new(); c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(c)
	var p := UITheme.panel(28)
	p.custom_minimum_size = Vector2(620, 0)
	c.add_child(p)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 12); p.add_child(vb)
	vb.add_child(UITheme.heading("Play vs Bots", 36))
	mode_opt = OptionButton.new()
	for id: StringName in Registry.mode_ids():
		mode_opt.add_item(Registry.mode(id).display_name)
		mode_opt.set_item_metadata(mode_opt.item_count - 1, id)
	mode_opt.item_selected.connect(func(_i: int) -> void: _refresh_maps())
	vb.add_child(_row("Mode", mode_opt))
	map_opt = OptionButton.new()
	vb.add_child(_row("Map", map_opt))
	desc = UITheme.label("", 14, UITheme.TEXT_DIM, true)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.y = 60
	vb.add_child(desc)
	map_opt.item_selected.connect(func(_i: int) -> void: _refresh_desc())
	diff_opt = OptionButton.new()
	for n: String in ["Recruit", "Regular", "Veteran", "Elite"]:
		diff_opt.add_item(n)
	diff_opt.selected = int(Settings.get_value(&"gameplay", "bot_difficulty"))
	vb.add_child(_row("Bot skill", diff_opt))
	size_opt = OptionButton.new()
	size_opt.add_item("5v5"); size_opt.add_item("6v6"); size_opt.add_item("3v3"); size_opt.add_item("1v1 duel")
	vb.add_child(_row("Team size", size_opt))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 10); vb.add_child(row)
	var back := UITheme.button("Back", 18); back.pressed.connect(func() -> void: UIRouter.show(&"main_menu")); row.add_child(back)
	var start := UITheme.button("Start Match", 20); start.pressed.connect(_start); row.add_child(start)
	_refresh_maps()


func _row(label: String, ctrl: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := UITheme.label(label, 16, UITheme.TEXT_DIM)
	l.custom_minimum_size.x = 140
	h.add_child(l)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	return h


func _refresh_maps() -> void:
	map_opt.clear()
	var mode_id: StringName = mode_opt.get_item_metadata(mode_opt.selected) if mode_opt.item_count > 0 else &""
	for m: MapData in Registry.maps_for_mode(mode_id):
		if m.id == &"test_range":
			continue
		map_opt.add_item(m.display_name)
		map_opt.set_item_metadata(map_opt.item_count - 1, m.id)
	if map_opt.item_count == 0:
		for id: StringName in Registry.map_ids():
			map_opt.add_item(Registry.map(id).display_name)
			map_opt.set_item_metadata(map_opt.item_count - 1, id)
	_refresh_desc()


func _refresh_desc() -> void:
	if map_opt.item_count == 0:
		desc.text = ""
		return
	var m := Registry.map(map_opt.get_item_metadata(map_opt.selected))
	desc.text = "%s — %s\n%s" % [m.location, m.time_of_day, m.description] if m else ""


func _start() -> void:
	if map_opt.item_count == 0:
		return
	var team := [5, 6, 3, 1][size_opt.selected]
	Settings.set_value(&"gameplay", "bot_difficulty", diff_opt.selected)
	App.start_local_match(map_opt.get_item_metadata(map_opt.selected), mode_opt.get_item_metadata(mode_opt.selected), team * 2 - 1,
		{"difficulty": diff_opt.selected, "team_size": team})
