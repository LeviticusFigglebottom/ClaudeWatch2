extends Control
## In-match pause overlay (the match keeps running — this is a menu, not a freeze).
## Resume / Change Hero / Settings / Leave Match / Quit. Escape resumes.

var resume_btn: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var accent := Accent.new()
	accent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(accent)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UITheme.panel(32)
	p.custom_minimum_size.x = 440
	center.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	p.add_child(vb)
	vb.add_child(UITheme.heading("Paused", 40))
	var c := App.client
	var md := Registry.map(c.map_id) if c else null
	var mode := Registry.mode(c.mode_id) if c else null
	var sub_parts: Array[String] = []
	if mode: sub_parts.append(mode.display_name)
	if md: sub_parts.append(md.display_name)
	if c: sub_parts.append("Team %s" % RF.team_name(c.team))
	var sub := UITheme.label("  ·  ".join(sub_parts) if not sub_parts.is_empty() else "No match", 14, UITheme.TEXT_DIM, true)
	vb.add_child(sub)
	vb.add_child(UITheme.separator())
	vb.add_child(_spacer(6))
	var items := [
		["Resume", _resume],
		["Change Hero", _change_hero],
		["Settings", _open_settings],
		["Leave Match", _leave],
		["Quit Game", _quit],
	]
	var first: Button = null
	for it: Array in items:
		var b := UITheme.button(it[0], 20, 376)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(it[1])
		vb.add_child(b)
		if first == null:
			first = b
	resume_btn = first
	vb.add_child(_spacer(6))
	var hint := UITheme.label("%s  RESUME     %s  SCOREBOARD" % [Settings.action_display_string("pause_menu"), Settings.action_display_string("scoreboard")], 12, UITheme.TEXT_DIM, true)
	vb.add_child(hint)
	if resume_btn:
		resume_btn.grab_focus()


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s


func _resume() -> void:
	UIRouter.hide_overlay(&"pause")


func _change_hero() -> void:
	UIRouter.hide_overlay(&"pause")
	UIRouter.show_overlay(&"hero_select")


func _open_settings() -> void:
	UIRouter.show_overlay(&"settings")


func _leave() -> void:
	App.go_to_menu()


func _quit() -> void:
	App.quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		_resume()
		get_viewport().set_input_as_handled()


## A quiet amber arc behind the panel so the pause screen reads as RINGFALL, not as a generic dim.
class Accent extends Control:
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		draw_arc(c, 330.0, PI * 1.1, PI * 1.9, 72, Color(UITheme.AMBER, 0.10), 3.0, true)
		draw_arc(c, 372.0, PI * 0.15, PI * 0.85, 72, Color(UITheme.AMBER, 0.06), 6.0, true)
