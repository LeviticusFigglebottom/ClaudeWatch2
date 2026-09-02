extends Control
## Hero select overlay: roster grid by role, detail panel with kit, counters, and confirm.

var selected: StringName = &""
var detail: VBoxContainer
var grid_root: VBoxContainer
var confirm_btn: Button
var buttons: Dictionary = {}


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 50; root.offset_top = 50; root.offset_right = -50; root.offset_bottom = -50
	root.add_theme_constant_override("separation", 24)
	add_child(root)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	root.add_child(left)
	left.add_child(UITheme.heading("Choose your Runner", 36))
	grid_root = VBoxContainer.new()
	grid_root.add_theme_constant_override("separation", 14)
	left.add_child(grid_root)
	for role in 3:
		var rl := UITheme.label(RF.role_name(role).to_upper() + "  ·  " + RF.ROLE_DESCRIPTIONS[role], 14, UITheme.role_color(role), true)
		grid_root.add_child(rl)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		grid_root.add_child(flow)
		for h: HeroData in Registry.heroes_by_role(role):
			var b := HeroCard.new()
			b.setup(h)
			b.pressed.connect(func() -> void: _select(h.id))
			flow.add_child(b)
			buttons[h.id] = b
	var right := UITheme.panel(20)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 420
	root.add_child(right)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	right.add_child(detail)
	var current: StringName = App.client.my_hero_id if App.client else &""
	if current != &"":
		_select(current)
	elif not Registry.hero_ids().is_empty():
		_select(Registry.hero_ids()[0])
	EventBus.scoreboard_updated.connect(func(_rows: Array) -> void: _refresh_taken())
	_refresh_taken()


func _refresh_taken() -> void:
	if App.client == null:
		return
	var my_team := App.client.team
	var taken: Dictionary = {}
	for r: Variant in App.client.roster:
		var row: Dictionary = r
		if int(row["team"]) == my_team and int(row["id"]) != App.client.player_id and String(row["hero"]) != "":
			taken[StringName(String(row["hero"]))] = String(row["name"])
	for id: Variant in buttons.keys():
		var b: HeroCard = buttons[id]
		b.set_taken(taken.get(id, ""))


func _select(id: StringName) -> void:
	selected = id
	for k: Variant in buttons.keys():
		(buttons[k] as HeroCard).set_selected(k == id)
	for c: Node in detail.get_children():
		c.queue_free()
	var h := Registry.hero(id)
	if h == null:
		return
	var name_row := HBoxContainer.new()
	detail.add_child(name_row)
	name_row.add_child(UITheme.heading(h.display_name, 34))
	var role := UITheme.label(RF.role_name(h.role).to_upper(), 14, UITheme.role_color(h.role), true)
	role.size_flags_vertical = Control.SIZE_SHRINK_END
	name_row.add_child(role)
	detail.add_child(UITheme.label(h.tagline, 15, UITheme.TEXT_DIM, true))
	var hp := UITheme.label("HP %d%s%s   ·   Difficulty %s" % [int(h.health), ("  Armor %d" % int(h.armor)) if h.armor > 0 else "", ("  Shield %d" % int(h.shield)) if h.shield > 0 else "", "★".repeat(h.difficulty)], 13, UITheme.TEXT_DIM, true)
	detail.add_child(hp)
	detail.add_child(UITheme.separator())
	var slots := [[RF.Slot.PRIMARY, "LMB"], [RF.Slot.SECONDARY, "RMB"], [RF.Slot.ABILITY_1, Settings.action_display_string("ability_1")], [RF.Slot.ABILITY_2, Settings.action_display_string("ability_2")], [RF.Slot.ABILITY_3, Settings.action_display_string("ability_3")], [RF.Slot.ULTIMATE, Settings.action_display_string("ultimate")]]
	for s: Array in slots:
		var ab := h.slot_ability(s[0])
		if ab == null:
			continue
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var head := HBoxContainer.new()
		var key := UITheme.label("[%s]" % s[1], 12, UITheme.AMBER, true)
		key.custom_minimum_size.x = 54
		head.add_child(key)
		head.add_child(UITheme.label(ab.display_name.to_upper() + ("  (ULT)" if ab.is_ultimate() else ""), 14, UITheme.TEXT))
		if ab.cooldown > 0.0 and not ab.is_ultimate() and ab.trigger != AbilityData.Trigger.HOLD:
			var cd := UITheme.label("%.0fs" % ab.cooldown, 12, UITheme.TEXT_DIM, true)
			cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			head.add_child(cd)
		row.add_child(head)
		var d := UITheme.label(ab.description, 12, UITheme.TEXT_DIM, true)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
		detail.add_child(row)
	detail.add_child(UITheme.separator())
	if h.unique_mechanic != "":
		var um := UITheme.label("Signature: " + h.unique_mechanic, 12, UITheme.GOOD, true)
		um.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(um)
	var cw := HBoxContainer.new()
	detail.add_child(cw)
	cw.add_child(_hero_list("Strong vs", h.counters, UITheme.GOOD))
	cw.add_child(_hero_list("Weak vs", h.countered_by, UITheme.DANGER))
	var spacer := Control.new(); spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	detail.add_child(btn_row)
	if App.client and App.client.my_hero_id != &"":
		var cancel := UITheme.button("Cancel", 16)
		cancel.pressed.connect(func() -> void: UIRouter.hide_overlay(&"hero_select"))
		btn_row.add_child(cancel)
	confirm_btn = UITheme.button("Select %s" % h.display_name, 18)
	confirm_btn.pressed.connect(_confirm)
	btn_row.add_child(confirm_btn)


func _hero_list(title: String, ids: Array[StringName], color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UITheme.label(title, 12, color, true))
	var names: Array[String] = []
	for id: StringName in ids:
		var h := Registry.hero(id)
		if h: names.append(h.display_name)
	var l := UITheme.label(", ".join(names) if not names.is_empty() else "—", 12, UITheme.TEXT_DIM, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return v


func _confirm() -> void:
	if selected == &"" or App.client == null:
		return
	App.client.select_hero(selected)
	if App.client.my_hero_id != &"":
		UIRouter.hide_overlay(&"hero_select")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hero_select") or event.is_action_pressed("pause_menu"):
		if App.client and App.client.my_hero_id != &"":
			UIRouter.hide_overlay(&"hero_select")
			get_viewport().set_input_as_handled()


class HeroCard extends Button:
	var hero: HeroData
	var swatch: ColorRect
	var name_label: Label
	var taken_label: Label
	var is_selected: bool = false
	func setup(h: HeroData) -> void:
		hero = h
		custom_minimum_size = Vector2(120, 96)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.offset_left = 6; vb.offset_top = 6; vb.offset_right = -6; vb.offset_bottom = -6
		add_child(vb)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top)
		swatch = ColorRect.new()
		swatch.color = h.theme_color
		swatch.custom_minimum_size = Vector2(22, 22)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(swatch)
		var portrait := PortraitDraw.new()
		portrait.hero = h
		portrait.custom_minimum_size = Vector2(36, 36)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(portrait)
		name_label = UITheme.label(h.display_name.to_upper(), 14, UITheme.TEXT)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(name_label)
		taken_label = UITheme.label("", 11, UITheme.DANGER, true)
		taken_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(taken_label)
		text = ""
	func set_selected(s: bool) -> void:
		is_selected = s
		modulate = Color(1, 1, 1) if s else Color(0.82, 0.82, 0.85)
		if s:
			var sb := (UITheme.theme().get_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.border_color = UITheme.AMBER; sb.set_border_width_all(2)
			add_theme_stylebox_override("normal", sb)
		else:
			remove_theme_stylebox_override("normal")
	func set_taken(by: String) -> void:
		taken_label.text = by
		disabled = by != ""

class PortraitDraw extends Control:
	var hero: HeroData
	func _draw() -> void:
		if hero == null or hero.visual == null:
			return
		var v := hero.visual
		var c := size * 0.5
		# A tiny silhouette glyph: head + shoulders shaped by build/head type, in the hero's colors.
		var bulk: float = [0.7, 0.85, 1.05, 1.25][v.build]
		draw_circle(c + Vector2(0, -8), 7.0 * (1.0 + 0.1 * bulk), v.primary_color)
		var sw: float = 13.0 * bulk
		draw_rect(Rect2(c.x - sw, c.y + 1, sw * 2.0, 14.0), v.secondary_color)
		draw_rect(Rect2(c.x - 3, c.y + 3, 6.0, 4.0), v.emissive_color if v.emissive_color.v > 0.05 else v.accent_color)
		match v.head:
			HeroVisualData.HeadShape.HOOD: draw_arc(c + Vector2(0, -8), 9.0, PI, TAU, 12, v.secondary_color, 3.0)
			HeroVisualData.HeadShape.CROWN, HeroVisualData.HeadShape.ANTENNA: draw_line(c + Vector2(0, -15), c + Vector2(0, -22), v.accent_color, 2.0)
			HeroVisualData.HeadShape.HELMET_VISOR: draw_rect(Rect2(c.x - 6, c.y - 10, 12, 3), v.emissive_color if v.emissive_color.v > 0.05 else v.accent_color)
