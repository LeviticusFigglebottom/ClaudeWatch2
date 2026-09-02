extends Control

var label: Label
var t: float = 0.0


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(vb)
	vb.add_child(UITheme.heading("RINGFALL", 56))
	label = UITheme.label("Connecting", 22, UITheme.TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(label)
	var cancel := UITheme.button("Cancel", 18)
	cancel.pressed.connect(func() -> void: App.go_to_menu())
	vb.add_child(cancel)


func _process(delta: float) -> void:
	t += delta
	label.text = "Connecting" + ".".repeat(int(t * 2.0) % 4)
