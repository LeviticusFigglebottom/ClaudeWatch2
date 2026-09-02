extends Node
## UI smoke test: instantiates every screen and overlay, renders it, and screenshots it.
## This is the surface that headless bot matches never touch — a broken UI screen imports clean
## and only fails when a player opens it (which is exactly how the PlayMenu crash reached a user).
##
## Run: xvfb-run -a -s "-screen 0 1600x900x24" tools/godot.sh --rendering-driver vulkan \
##        --resolution 1600x900 res://tools/ui_smoke.tscn

const SCREENS := [&"main_menu", &"play", &"lobby", &"training", &"settings", &"post_match", &"connecting", &"hud"]
const OVERLAYS := [&"hero_select", &"scoreboard", &"pause", &"settings"]

var failures: Array[String] = []


func _ready() -> void:
	var main := (load("res://src/app/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://screenshots/ui")

	for s: StringName in SCREENS:
		await _try("screen", s, func() -> void: UIRouter.show(s))
	# Overlays need a base screen underneath.
	UIRouter.show(&"main_menu")
	await get_tree().process_frame
	for o: StringName in OVERLAYS:
		await _try("overlay", o, func() -> void: UIRouter.show_overlay(o))
		UIRouter.hide_overlay(o)

	print("=== UI SMOKE: %d checks, %d failures ===" % [SCREENS.size() + OVERLAYS.size(), failures.size()])
	for f: String in failures:
		print("  FAIL " + f)
	get_tree().quit(1 if failures.size() > 0 else 0)


func _try(kind: String, name: StringName, action: Callable) -> void:
	print("--- %s: %s" % [kind, name])
	action.call()
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var node: Control = UIRouter.overlays.get(name) if kind == "overlay" else UIRouter.current
	if node == null or not is_instance_valid(node):
		failures.append("%s %s did not instantiate" % [kind, name])
		return
	if node.size.x < 50.0 or node.size.y < 50.0:
		failures.append("%s %s has a collapsed rect %s (anchors bug)" % [kind, name, node.size])
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://screenshots/ui/%s_%s.png" % [kind, name])
