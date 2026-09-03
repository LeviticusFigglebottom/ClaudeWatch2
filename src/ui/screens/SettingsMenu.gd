extends Control
## Settings: Controls / Video / Audio / Accessibility / Gameplay. Every control reads Settings.get_value
## and writes Settings.set_value immediately (settings apply live). Works as a full screen (Back → main
## menu) or stacked as an overlay over the HUD / pause menu (Close → hide overlay).

const TABS := ["Controls", "Video", "Audio", "Accessibility", "Gameplay"]
const ACTIONS := [
	["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"], ["move_right", "Move right"],
	["jump", "Jump"], ["crouch", "Crouch"], ["primary_fire", "Primary fire"], ["secondary_fire", "Secondary fire"],
	["ability_1", "Ability 1"], ["ability_2", "Ability 2"], ["ability_3", "Ability 3"], ["ultimate", "Ultimate"],
	["reload", "Reload"], ["melee", "Quick melee"], ["interact", "Interact"], ["scoreboard", "Scoreboard"],
	["hero_select", "Hero select"], ["ping", "Ping"], ["console", "Console"], ["pause_menu", "Pause menu"],
	["voice_line", "Voice line"],
]
const CROSSHAIR_PRESETS := [Color(0.95, 0.95, 0.95), Color(0.98, 0.72, 0.22), Color(0.35, 0.9, 0.5), Color(0.25, 0.75, 1.0), Color(0.98, 0.3, 0.9), Color(0.95, 0.3, 0.28)]
const LABEL_W := 300.0
const SAVE_DELAY := 0.5

var is_overlay: bool = false
var pages: Dictionary = {}          # tab -> Control
var tab_buttons: Dictionary = {}    # tab -> Button
var bind_buttons: Dictionary = {}   # action -> Button
var rebinding: String = ""
var rebind_hint: Label
var scroll: ScrollContainer
var content: VBoxContainer
var active_tab: String = ""
var team_preview: TeamPreview
var _save_pending: bool = false
var _save_timer: float = 0.0


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	is_overlay = UIRouter.current != self
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.04, 0.88) if is_overlay else UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 150)
	margin.add_theme_constant_override("margin_right", 150)
	margin.add_theme_constant_override("margin_top", 52)
	margin.add_theme_constant_override("margin_bottom", 52)
	add_child(margin)
	var panel := UITheme.panel(28)
	margin.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	vb.add_child(head)
	head.add_child(UITheme.heading("Settings", 36))
	var hsub := UITheme.label("Changes apply immediately and are saved.", 13, UITheme.TEXT_DIM, true)
	hsub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hsub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(hsub)
	var close := UITheme.button("Close" if is_overlay else "Back", 16, 130)
	close.pressed.connect(_close)
	head.add_child(close)
	# Tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	vb.add_child(tabs)
	var group := ButtonGroup.new()
	for t: String in TABS:
		var b := UITheme.button(t, 15, 150)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func() -> void: select_tab(t))
		tabs.add_child(b)
		tab_buttons[t] = b
	vb.add_child(UITheme.separator())
	# Scrolling content
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_style_scrollbar(scroll.get_v_scroll_bar())
	vb.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 0)
	scroll.add_child(content)
	pages["Controls"] = _build_controls()
	pages["Video"] = _build_video()
	pages["Audio"] = _build_audio()
	pages["Accessibility"] = _build_accessibility()
	pages["Gameplay"] = _build_gameplay()
	for k: String in pages.keys():
		content.add_child(pages[k])
	EventBus.settings_changed.connect(func(section: StringName) -> void:
		if section == &"controls":
			_refresh_bind_labels())
	select_tab("Controls")


func select_tab(tab: String) -> void:
	if not pages.has(tab):
		return
	if rebinding != "":
		_cancel_rebind()
	active_tab = tab
	for k: String in pages.keys():
		(pages[k] as Control).visible = k == tab
	(tab_buttons[tab] as Button).set_pressed_no_signal(true)
	scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	if _save_pending:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_save_pending = false
			Settings.save_settings()


func _exit_tree() -> void:
	if _save_pending:
		Settings.save_settings()


func _schedule_save() -> void:
	_save_pending = true
	_save_timer = SAVE_DELAY


func _close() -> void:
	if rebinding != "":
		_cancel_rebind()
	if UIRouter.overlays.get(&"settings") == self:
		UIRouter.hide_overlay(&"settings")
	else:
		UIRouter.show(&"main_menu")


## --- Page builders --------------------------------------------------------------------------------

func _page() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.visible = false
	return v


func _build_controls() -> Control:
	var p := _page()
	_section(p, "Mouse & camera")
	_row(p, "Mouse sensitivity", _slider(&"controls", "mouse_sensitivity", 0.02, 1.0, 0.01, func(v: float) -> String: return "%.2f" % v), "Degrees per mouse count")
	_row(p, "Gamepad sensitivity", _slider(&"controls", "gamepad_sensitivity", 60.0, 360.0, 5.0, func(v: float) -> String: return "%d°/s" % int(v)), "Turn speed at full stick")
	_row(p, "Invert Y", _toggle(&"controls", "invert_y"), "", false)
	_row(p, "Field of view", _slider(&"controls", "fov", 80.0, 120.0, 1.0, func(v: float) -> String: return "%d°" % int(v)), "Applies live in-match")
	_section(p, "Buttons")
	_row(p, "Toggle crouch", _toggle(&"controls", "toggle_crouch"), "Press once to crouch, again to stand", false)
	_row(p, "Hold to aim", _toggle(&"controls", "ads_hold"), "Off: aim is a toggle", false)
	_row(p, "Hold ultimate", _toggle(&"controls", "hold_ultimate"), "Require holding the key to confirm", false)
	_section(p, "Keybinds")
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 16)
	p.add_child(bar)
	rebind_hint = UITheme.label("Click a binding, then press a key, mouse or gamepad button.", 13, UITheme.TEXT_DIM, true)
	rebind_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rebind_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(rebind_hint)
	var reset := UITheme.button("Reset to defaults", 13)
	reset.pressed.connect(func() -> void:
		if rebinding != "":
			_cancel_rebind()
		Settings.reset_keybinds()
		_refresh_bind_labels()
		rebind_hint.text = "Keybinds reset to defaults."
		rebind_hint.add_theme_color_override("font_color", UITheme.GOOD))
	bar.add_child(reset)
	p.add_child(_gap(8))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	p.add_child(grid)
	for a: Array in ACTIONS:
		var l := UITheme.label(String(a[1]), 15, UITheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(l)
		var b := Button.new()
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(190, 34)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_begin_rebind.bind(String(a[0])))
		grid.add_child(b)
		bind_buttons[String(a[0])] = b
	_refresh_bind_labels()
	p.add_child(_gap(12))
	return p


func _build_video() -> Control:
	var p := _page()
	_section(p, "Display")
	_row(p, "Window mode", _option(&"video", "window_mode", ["Windowed", "Fullscreen", "Borderless"], [0, 1, 2]))
	_row(p, "V-Sync", _toggle(&"video", "vsync"), "", false)
	_row(p, "Max FPS", _option(&"video", "max_fps", ["60", "120", "144", "165", "240", "Unlimited"], [60, 120, 144, 165, 240, 0]))
	_row(p, "Show FPS counter", _toggle(&"video", "show_fps"), "", false)
	_section(p, "Quality")
	_row(p, "Render scale", _slider(&"video", "render_scale", 0.5, 1.5, 0.05, func(v: float) -> String: return "%d%%" % int(round(v * 100.0))), "3D resolution relative to the window")
	_row(p, "MSAA", _option(&"video", "msaa", ["Off", "2×", "4×", "8×"], [0, 1, 2, 3]))
	_row(p, "FXAA", _toggle(&"video", "fxaa"), "Cheap edge smoothing", false)
	_row(p, "Shadow quality", _option(&"video", "shadow_quality", ["Off", "Low", "Medium", "High"], [0, 1, 2, 3]))
	_row(p, "Prop detail distance", _option(&"video", "detail_distance", ["Near", "Normal", "Far", "Max"], [0.6, 1.0, 1.5, 2.0]), "How far away small props stay visible")
	_row(p, "Ambient occlusion", _toggle(&"video", "ssao"), "", false)
	_row(p, "Glow", _toggle(&"video", "glow"), "", false)
	_row(p, "Volumetric fog", _toggle(&"video", "volumetric_fog"), "", false)
	_row(p, "Motion blur", _toggle(&"video", "motion_blur"), "", false)
	return p


func _build_audio() -> Control:
	var p := _page()
	_section(p, "Volume")
	var pct := func(v: float) -> String: return "%d%%" % int(round(v * 100.0))
	_row(p, "Master", _slider(&"audio", "master", 0.0, 1.0, 0.01, pct))
	_row(p, "Effects", _slider(&"audio", "sfx", 0.0, 1.0, 0.01, pct), "Weapons, abilities, footsteps")
	_row(p, "Music", _slider(&"audio", "music", 0.0, 1.0, 0.01, pct))
	_row(p, "Interface", _slider(&"audio", "ui", 0.0, 1.0, 0.01, pct), "Hitmarkers, menus, announcer stingers")
	_row(p, "Voice", _slider(&"audio", "voice", 0.0, 1.0, 0.01, pct), "Runner lines and callouts")
	return p


func _build_accessibility() -> Control:
	var p := _page()
	_section(p, "Color")
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 16)
	team_preview = TeamPreview.new()
	team_preview.mode = int(Settings.get_value(&"accessibility", "colorblind_mode"))
	team_preview.custom_minimum_size = Vector2(230, 30)
	var opt := _option(&"accessibility", "colorblind_mode", ["Off", "Deuteranopia", "Protanopia", "Tritanopia"], [0, 1, 2, 3], func(v: Variant) -> void:
		team_preview.mode = int(v)
		team_preview.queue_redraw())
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cb.add_child(opt)
	cb.add_child(team_preview)
	_row(p, "Colorblind mode", cb, "Team colors stay distinguishable")
	_row(p, "High-contrast enemies", _toggle(&"accessibility", "high_contrast_enemies"), "Stronger enemy outlines", false)
	_section(p, "Crosshair")
	_row(p, "Crosshair color", _crosshair_color_ctrl())
	_row(p, "Crosshair size", _slider(&"accessibility", "crosshair_size", 0.5, 2.0, 0.1, func(v: float) -> String: return "%.1f×" % v))
	_section(p, "Motion & effects")
	var pct := func(v: float) -> String: return "%d%%" % int(round(v * 100.0))
	_row(p, "Screen shake", _slider(&"accessibility", "screen_shake", 0.0, 1.0, 0.05, pct))
	_row(p, "Camera bob", _slider(&"accessibility", "camera_bob", 0.0, 1.0, 0.05, pct))
	_row(p, "Hitstop", _toggle(&"accessibility", "hitstop"), "Brief freeze on kills and headshots", false)
	_row(p, "Reduce flashing", _toggle(&"accessibility", "reduce_flashing"), "Tones down bright bursts and strobes", false)
	_section(p, "Interface")
	_row(p, "HUD scale", _slider(&"accessibility", "hud_scale", 0.7, 1.3, 0.05, pct), "Applies when the HUD is rebuilt")
	_row(p, "Damage numbers", _toggle(&"accessibility", "damage_numbers"), "", false)
	_row(p, "Subtitles", _toggle(&"accessibility", "subtitles"), "Runner voice lines as text", false)
	return p


func _build_gameplay() -> Control:
	var p := _page()
	_section(p, "Runner")
	var name_edit := LineEdit.new()
	name_edit.text = String(Settings.get_value(&"gameplay", "player_name"))
	name_edit.max_length = 20
	name_edit.custom_minimum_size.x = 260
	name_edit.text_changed.connect(func(t: String) -> void:
		if t.strip_edges() != "":
			Settings.set_value(&"gameplay", "player_name", t.strip_edges(), false)
			_schedule_save())
	_row(p, "Player name", name_edit, "Shown on the scoreboard and kill feed")
	_row(p, "Preferred role", _option(&"gameplay", "preferred_role", ["Any", RF.role_name(0), RF.role_name(1), RF.role_name(2)], [-1, 0, 1, 2]), "Hero select opens on this role")
	_section(p, "Match")
	_row(p, "Bot difficulty", _option(&"gameplay", "bot_difficulty", ["Recruit", "Regular", "Veteran", "Elite"], [0, 1, 2, 3]), "Default for Play vs Bots and Training")
	_row(p, "Killcam", _toggle(&"gameplay", "killcam"), "Replay the killer's last seconds after you die")
	_row(p, "Ally outlines", _toggle(&"gameplay", "show_ally_outlines"), "See teammates through walls", false)
	_row(p, "Hero swap hints", _toggle(&"gameplay", "auto_hero_swap_hint"), "Suggest a counter-pick when you are being countered", false)
	return p


## --- Row / control helpers --------------------------------------------------------------------------

func _section(parent: Control, title: String) -> void:
	parent.add_child(_gap(14 if parent.get_child_count() > 0 else 4))
	var l := UITheme.label(title.to_upper(), 13, UITheme.AMBER, true)
	parent.add_child(l)
	parent.add_child(_gap(4))


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _row(parent: Control, label: String, ctrl: Control, hint: String = "", expand: bool = true) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var lv := VBoxContainer.new()
	lv.custom_minimum_size.x = LABEL_W
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lv.add_theme_constant_override("separation", 0)
	lv.add_child(UITheme.label(label, 16, UITheme.TEXT))
	if hint != "":
		lv.add_child(UITheme.label(hint, 12, UITheme.TEXT_DIM, true))
	h.add_child(lv)
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ctrl)
	h.custom_minimum_size.y = 46
	parent.add_child(h)
	var line := UITheme.separator()
	line.modulate.a = 0.6
	parent.add_child(line)


func _slider(section: StringName, key: String, minv: float, maxv: float, step: float, fmt: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = float(Settings.get_value(section, key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(240, 22)
	s.focus_mode = Control.FOCUS_ALL
	var v := UITheme.label(String(fmt.call(s.value)), 15, UITheme.AMBER, true)
	v.custom_minimum_size.x = 74
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(val: float) -> void:
		v.text = String(fmt.call(val))
		Settings.set_value(section, key, val, false)
		_schedule_save())
	h.add_child(s)
	h.add_child(v)
	return h


func _toggle(section: StringName, key: String, on_change: Callable = Callable()) -> ToggleSwitch:
	var t := ToggleSwitch.new()
	var cur: Variant = Settings.get_value(section, key)
	var as_int := typeof(cur) == TYPE_INT
	t.button_pressed = (int(cur) != 0) if as_int else bool(cur)
	t.toggled.connect(func(on: bool) -> void:
		Settings.set_value(section, key, (1 if on else 0) if as_int else on)
		if on_change.is_valid():
			on_change.call(on))
	return t


func _option(section: StringName, key: String, names: Array, values: Array, on_change: Callable = Callable()) -> OptionButton:
	var o := OptionButton.new()
	o.add_theme_font_size_override("font_size", 15)
	o.custom_minimum_size.x = 240
	o.focus_mode = Control.FOCUS_ALL
	var cur: Variant = Settings.get_value(section, key)
	var sel := -1
	for i in names.size():
		o.add_item(String(names[i]))
		o.set_item_metadata(i, values[i])
		if values[i] == cur:
			sel = i
	if sel < 0:
		o.add_item("Custom (%s)" % str(cur))
		o.set_item_metadata(o.item_count - 1, cur)
		sel = o.item_count - 1
	o.selected = sel
	o.item_selected.connect(func(i: int) -> void:
		var v: Variant = o.get_item_metadata(i)
		Settings.set_value(section, key, v)
		if on_change.is_valid():
			on_change.call(v))
	return o


func _crosshair_color_ctrl() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var cp := ColorPickerButton.new()
	cp.edit_alpha = false
	cp.color = Settings.get_value(&"accessibility", "crosshair_color")
	cp.custom_minimum_size = Vector2(64, 30)
	cp.focus_mode = Control.FOCUS_ALL
	cp.color_changed.connect(func(c: Color) -> void:
		Settings.set_value(&"accessibility", "crosshair_color", c, false)
		_schedule_save())
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = Color(0.07, 0.08, 0.11)
	popup_sb.border_color = UITheme.AMBER
	popup_sb.set_border_width_all(1)
	popup_sb.set_corner_radius_all(4)
	popup_sb.content_margin_left = 10; popup_sb.content_margin_right = 10; popup_sb.content_margin_top = 10; popup_sb.content_margin_bottom = 10
	cp.get_popup().add_theme_stylebox_override("panel", popup_sb)
	var picker := cp.get_picker()
	picker.sampler_visible = false
	picker.color_modes_visible = false
	picker.presets_visible = false
	picker.can_add_swatches = false
	h.add_child(cp)
	var custom_l := UITheme.label("custom", 12, UITheme.TEXT_DIM, true)
	custom_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(custom_l)
	h.add_child(_hgap(10))
	for c: Color in CROSSHAIR_PRESETS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(30, 30)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = "#" + c.to_html(false)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(3)
		sb.border_color = Color(0, 0, 0, 0.5)
		sb.set_border_width_all(1)
		var sbh := sb.duplicate() as StyleBoxFlat
		sbh.border_color = Color.WHITE
		sbh.set_border_width_all(2)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		b.add_theme_stylebox_override("focus", sbh)
		b.pressed.connect(func() -> void:
			cp.color = c
			Settings.set_value(&"accessibility", "crosshair_color", c))
		h.add_child(b)
	return h


func _hgap(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _style_scrollbar(sb: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.04)
	track.set_corner_radius_all(3)
	track.content_margin_left = 4; track.content_margin_right = 4
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(UITheme.TEXT_DIM, 0.45)
	grab.set_corner_radius_all(3)
	var grab_h := grab.duplicate() as StyleBoxFlat
	grab_h.bg_color = UITheme.AMBER
	sb.add_theme_stylebox_override("scroll", track)
	sb.add_theme_stylebox_override("scroll_focus", track)
	sb.add_theme_stylebox_override("grabber", grab)
	sb.add_theme_stylebox_override("grabber_highlight", grab_h)
	sb.add_theme_stylebox_override("grabber_pressed", grab_h)
	var blank := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for icon: String in ["increment", "decrement", "increment_highlight", "decrement_highlight", "increment_pressed", "decrement_pressed"]:
		sb.add_theme_icon_override(icon, blank)


## --- Keybinds ------------------------------------------------------------------------------------

func _refresh_bind_labels() -> void:
	for action: String in bind_buttons.keys():
		var b: Button = bind_buttons[action]
		if not is_instance_valid(b):
			continue
		b.text = Settings.action_display_string(action) if InputMap.has_action(action) else "—"
		b.remove_theme_color_override("font_color")


func _begin_rebind(action: String) -> void:
	if rebinding != "":
		_cancel_rebind()
	rebinding = action
	var b: Button = bind_buttons[action]
	b.text = "PRESS A KEY…"
	b.add_theme_color_override("font_color", UITheme.AMBER)
	var pretty := ""
	for a: Array in ACTIONS:
		if String(a[0]) == action:
			pretty = String(a[1])
	rebind_hint.text = "Listening for %s — press a key, mouse or gamepad button. ESC cancels." % pretty
	rebind_hint.add_theme_color_override("font_color", UITheme.AMBER)


func _cancel_rebind() -> void:
	rebinding = ""
	_refresh_bind_labels()
	if rebind_hint:
		rebind_hint.text = "Click a binding, then press a key, mouse or gamepad button."
		rebind_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)


func _input(event: InputEvent) -> void:
	if rebinding == "":
		return
	var captured: InputEvent = null
	if event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		get_viewport().set_input_as_handled()
		if k.keycode == KEY_ESCAPE or k.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		var nk := InputEventKey.new()
		nk.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		captured = nk
	elif event is InputEventMouseButton:
		var m := event as InputEventMouseButton
		if not m.pressed:
			return
		get_viewport().set_input_as_handled()
		var nm := InputEventMouseButton.new()
		nm.button_index = m.button_index
		captured = nm
	elif event is InputEventJoypadButton:
		var j := event as InputEventJoypadButton
		if not j.pressed:
			return
		get_viewport().set_input_as_handled()
		var nj := InputEventJoypadButton.new()
		nj.button_index = j.button_index
		captured = nj
	if captured == null:
		return
	# Keep bindings from the other device family so a keyboard rebind does not strip the gamepad one.
	var events: Array[InputEvent] = [captured]
	for e: InputEvent in InputMap.action_get_events(rebinding):
		var same_family := (captured is InputEventJoypadButton) == (e is InputEventJoypadButton or e is InputEventJoypadMotion)
		if not same_family:
			events.append(e)
	var action := rebinding
	rebinding = ""
	Settings.rebind(action, events)
	_refresh_bind_labels()
	rebind_hint.text = "%s bound." % Settings.action_display_string(action)
	rebind_hint.add_theme_color_override("font_color", UITheme.GOOD)


func _unhandled_input(event: InputEvent) -> void:
	if rebinding == "" and event.is_action_pressed("pause_menu"):
		_close()
		get_viewport().set_input_as_handled()


## Live preview of the two team colors under the chosen colorblind palette.
class TeamPreview extends Control:
	var mode: int = 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var f := UITheme.font_narrow()
		var x := 0.0
		for team in RF.TEAM_COUNT:
			var col := Palette.team_color(team, mode)
			var sb := StyleBoxFlat.new()
			sb.bg_color = col
			sb.set_corner_radius_all(3)
			sb.draw(get_canvas_item(), Rect2(x, 4, 40, size.y - 8))
			var name := RF.team_name(team).to_upper()
			draw_string(f, Vector2(x + 48, size.y * 0.5 + 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			x += 48 + f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 22
