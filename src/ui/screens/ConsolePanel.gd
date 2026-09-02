extends Control
## Drop-down developer console (tilde).

var output: RichTextLabel
var input: LineEdit
var panel: PanelContainer
var history_index: int = -1


func _ready() -> void:
	theme = UITheme.theme()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	offset_bottom = 320
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.04, 0.94)
	sb.border_color = UITheme.AMBER
	sb.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	output = RichTextLabel.new()
	output.scroll_following = true
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_override("normal_font", UITheme.font_mono())
	output.add_theme_font_size_override("normal_font_size", 15)
	vb.add_child(output)
	input = LineEdit.new()
	input.placeholder_text = "command (help for list)"
	input.add_theme_font_override("font", UITheme.font_mono())
	input.text_submitted.connect(_on_submit)
	vb.add_child(input)
	Console.line_printed.connect(_on_line)
	for l: String in Console.lines:
		output.append_text(l + "\n")
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_line(text: String, color: Color) -> void:
	output.push_color(color)
	output.append_text(text)
	output.pop()
	output.append_text("\n")


func _on_submit(text: String) -> void:
	input.text = ""
	Console.execute(text)
	history_index = -1


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("console"):
		visible = not visible
		Console.is_open = visible
		EventBus.console_toggled.emit(visible)
		UIRouter._update_mouse()
		if visible:
			input.grab_focus()
			input.text = ""
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and (event as InputEventKey).pressed:
		var k := event as InputEventKey
		if k.keycode == KEY_UP and not Console.history.is_empty():
			history_index = clampi(history_index + 1, 0, Console.history.size() - 1)
			input.text = Console.history[Console.history.size() - 1 - history_index]
			input.caret_column = input.text.length()
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_DOWN:
			history_index = maxi(history_index - 1, -1)
			input.text = "" if history_index < 0 else Console.history[Console.history.size() - 1 - history_index]
			get_viewport().set_input_as_handled()
		elif k.keycode == KEY_ESCAPE:
			visible = false
			Console.is_open = false
			UIRouter._update_mouse()
			get_viewport().set_input_as_handled()
