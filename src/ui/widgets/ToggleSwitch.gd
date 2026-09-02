class_name ToggleSwitch
extends Button
## An on/off pill switch in the game's identity (amber when on). Use `button_pressed` / `toggled`.

const PILL_W := 52.0
const PILL_H := 24.0


func _init() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(PILL_W + 56.0, 30.0)
	var empty := StyleBoxEmpty.new()
	for s: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(s, empty)
	text = ""
	toggled.connect(func(_on: bool) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var on := button_pressed
	var hovered := is_hovered()
	var y := (size.y - PILL_H) * 0.5
	var pill := Rect2(0, y, PILL_W, PILL_H)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(PILL_H * 0.5))
	if disabled:
		sb.bg_color = Color(0.12, 0.13, 0.17)
	elif on:
		sb.bg_color = UITheme.AMBER.lightened(0.08) if hovered else UITheme.AMBER
	else:
		sb.bg_color = Color(0.24, 0.26, 0.32) if hovered else Color(0.2, 0.22, 0.28)
	if has_focus():
		sb.border_color = UITheme.AMBER if not on else Color.WHITE
		sb.set_border_width_all(2)
	sb.draw(get_canvas_item(), pill)
	var kx := pill.position.x + (PILL_W - PILL_H * 0.5 - 3.0) if on else pill.position.x + PILL_H * 0.5 + 3.0
	draw_circle(Vector2(kx, pill.position.y + PILL_H * 0.5), PILL_H * 0.5 - 5.0, UITheme.BG if on else UITheme.TEXT_DIM)
	var f := UITheme.font_narrow()
	var label := "ON" if on else "OFF"
	var sz := 13
	var base := y + (PILL_H - (f.get_ascent(sz) + f.get_descent(sz))) * 0.5 + f.get_ascent(sz)
	draw_string(f, Vector2(PILL_W + 12.0, base), label, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, UITheme.AMBER if on else UITheme.TEXT_DIM)
