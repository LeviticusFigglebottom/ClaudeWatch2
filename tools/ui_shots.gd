extends Node
## TEMPORARY tool: boots Main, walks through every UI screen / overlay and saves screenshots to
## screenshots/ui_*.png. Run: xvfb-run -a -s "-screen 0 1600x900x24" tools/godot.sh --rendering-driver vulkan
##   --resolution 1600x900 res://tools/ui_shots.tscn

const OUT := "screenshots"


func _ready() -> void:
	var main := (load("res://src/app/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await App._take_screenshot(OUT.path_join(name))


func _wait_screen(name: StringName, max_frames: int) -> void:
	var f := 0
	while UIRouter.current_name != name and f < max_frames:
		await get_tree().process_frame
		f += 1


func _run() -> void:
	await _frames(40)
	await _shot("ui_main_menu.png")
	UIRouter.show(&"settings")
	await _frames(20)
	await _shot("ui_settings_controls.png")
	for tab: String in ["Video", "Audio", "Accessibility", "Gameplay"]:
		UIRouter.current.call("select_tab", tab)
		await _frames(10)
		await _shot("ui_settings_%s.png" % tab.to_lower())
	UIRouter.show(&"lobby")
	await _frames(20)
	await _shot("ui_lobby.png")
	UIRouter.show(&"training")
	await _frames(20)
	await _shot("ui_training.png")
	# In-match overlays
	App.start_local_match(&"test_range", &"control", 4, {"difficulty": 1})
	await _wait_screen(&"hud", 900)
	await _frames(30)
	Console.execute("hero vesper")
	await _frames(300)
	UIRouter.show_overlay(&"scoreboard")
	await _frames(20)
	await _shot("ui_scoreboard.png")
	UIRouter.hide_overlay(&"scoreboard")
	await _frames(5)
	UIRouter.show_overlay(&"pause")
	await _frames(20)
	await _shot("ui_pause.png")
	UIRouter.show_overlay(&"settings")
	await _frames(20)
	await _shot("ui_settings_overlay.png")
	UIRouter.hide_overlay(&"settings")
	UIRouter.hide_overlay(&"pause")
	await _frames(5)
	# Post match with synthesized end data (plus the recorder's real best play when there is one)
	var potg: Dictionary = App.server.replay.best_play() if App.server and App.server.replay else {}
	print("[ui_shots] potg frames: %d" % (potg.get("frames", []) as Array).size())
	App.client.presentation.match_end_data = _fake_end(potg)
	UIRouter.show(&"post_match")
	await _frames(40)
	await _shot("ui_post_match_banner.png")
	await _frames(170)
	if not potg.is_empty():
		await _frames(60)
		await _shot("ui_post_match_potg.png")
		var f := 0
		while UIRouter.current and UIRouter.current.get("phase") != &"stats" and f < 1200:
			await get_tree().process_frame
			f += 1
	await _frames(20)
	await _shot("ui_post_match_stats.png")
	UIRouter.show_overlay(&"scoreboard", {"final": true})
	await _frames(20)
	await _shot("ui_scoreboard_final.png")
	get_tree().quit()


func _fake_end(potg: Dictionary) -> Dictionary:
	var stats: Array = App.server.scoreboard_rows() if App.server else []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for s: Variant in stats:
		var d: Dictionary = s
		d["kills"] = rng.randi_range(0, 14); d["deaths"] = rng.randi_range(0, 9); d["assists"] = rng.randi_range(0, 10)
		d["damage"] = rng.randf_range(800, 12000); d["healing"] = rng.randf_range(0, 6000) if rng.randf() < 0.5 else 0.0
		d["mitigated"] = rng.randf_range(0, 4000); d["objective_time"] = rng.randf_range(0, 200)
		d["ults_used"] = rng.randi_range(0, 4); d["best_streak"] = rng.randi_range(0, 6)
	return {"mode": App.client.mode_id, "score": [2, 1], "winner": App.client.team, "elapsed": 512.0, "stats": stats, "potg": potg}
