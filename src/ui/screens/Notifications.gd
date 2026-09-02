extends Control
## Toast notifications (top-right) and chat lines.

var box: VBoxContainer


func _ready() -> void:
	theme = UITheme.theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -420; offset_top = 90; offset_right = -24; offset_bottom = 400
	box = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	EventBus.notification.connect(_on_notification)


func _on_notification(text: String, kind: StringName) -> void:
	var p := UITheme.panel(8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UITheme.label(text, 16, UITheme.TEXT if kind != &"error" else UITheme.DANGER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	box.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(3.5 if kind != &"chat" else 6.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)
	while box.get_child_count() > 6:
		box.get_child(0).queue_free()
		await get_tree().process_frame
