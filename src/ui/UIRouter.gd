class_name UIRouter
## Screen switching. Screens are scenes under res://src/ui/screens; overlays stack on top.

static var layer: CanvasLayer
static var current: Control
static var current_name: StringName = &""
static var overlays: Dictionary = {}
static var persistent: Dictionary = {}     # console, notifications

const SCREENS := {
	&"main_menu": "res://src/ui/screens/MainMenu.tscn",
	&"connecting": "res://src/ui/screens/Connecting.tscn",
	&"hud": "res://src/ui/screens/HUD.tscn",
	&"post_match": "res://src/ui/screens/PostMatch.tscn",
	&"settings": "res://src/ui/screens/SettingsMenu.tscn",
	&"play": "res://src/ui/screens/PlayMenu.tscn",
	&"lobby": "res://src/ui/screens/Lobby.tscn",
	&"training": "res://src/ui/screens/Training.tscn",
}
const OVERLAYS := {
	&"hero_select": "res://src/ui/screens/HeroSelect.tscn",
	&"scoreboard": "res://src/ui/screens/Scoreboard.tscn",
	&"pause": "res://src/ui/screens/PauseMenu.tscn",
	&"settings": "res://src/ui/screens/SettingsMenu.tscn",
}


static func setup(l: CanvasLayer) -> void:
	layer = l
	var console_scene := load("res://src/ui/screens/ConsolePanel.tscn") as PackedScene
	if console_scene:
		var c := console_scene.instantiate()
		layer.add_child(c)
		persistent[&"console"] = c
	var notif := load("res://src/ui/screens/Notifications.tscn") as PackedScene
	if notif:
		var n := notif.instantiate()
		layer.add_child(n)
		persistent[&"notifications"] = n


static func show(name: StringName) -> void:
	if layer == null:
		return
	if current:
		current.queue_free()
		current = null
	for k: StringName in overlays.keys():
		hide_overlay(k)
	var path: String = SCREENS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("UIRouter: no screen %s" % name)
		return
	var scene := load(path) as PackedScene
	current = scene.instantiate() as Control
	current.name = String(name)
	layer.add_child(current)
	layer.move_child(current, 0)
	current_name = name
	EventBus.screen_changed.emit(name)
	_update_mouse()


static func show_overlay(name: StringName, data: Dictionary = {}) -> Control:
	if layer == null:
		return null
	if overlays.has(name):
		return overlays[name]
	var path: String = OVERLAYS.get(name, "")
	if path == "" or not ResourceLoader.exists(path):
		push_warning("UIRouter: no overlay %s" % name)
		return null
	var scene := load(path) as PackedScene
	var o := scene.instantiate() as Control
	o.name = String(name)
	if o.has_method("set_data"):
		o.call("set_data", data)
	layer.add_child(o)
	overlays[name] = o
	_update_mouse()
	return o


static func hide_overlay(name: StringName) -> void:
	if overlays.has(name):
		var o: Control = overlays[name]
		overlays.erase(name)
		if is_instance_valid(o):
			o.queue_free()
	_update_mouse()


static func toggle_overlay(name: StringName) -> void:
	if overlays.has(name):
		hide_overlay(name)
	else:
		show_overlay(name)


static func has_overlay(name: StringName) -> bool:
	return overlays.has(name)


static func any_overlay_open() -> bool:
	for k: StringName in overlays.keys():
		if k != &"scoreboard":
			return true
	return false


static func _update_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var console_open: bool = Console.is_open
	var capture := current_name == &"hud" and not any_overlay_open() and not console_open
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
	if App.client and App.client.input:
		App.client.input.enabled = capture
