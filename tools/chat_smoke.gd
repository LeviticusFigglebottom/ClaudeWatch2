extends Node
## Verifies the HUD chat line: the actions exist, the input opens, a submitted message reaches the
## server and comes back to every client as a chat event.
## Run: tools/godot.sh --headless res://tools/chat_smoke.tscn -- --client

func _ready() -> void:
	for a: String in ["chat", "team_chat"]:
		if not InputMap.has_action(a):
			print("FAIL: missing input action '%s'" % a)
			get_tree().quit(1); return
	var main := (load("res://src/app/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	App.start_local_match(&"nightmarket", &"push", 4)
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cc := App.client
		if cc and cc.connected_ok and cc.player_id != 0:
			cc.select_hero(&"vesper")
			break
	var c := App.client
	while Time.get_ticks_msec() < deadline and (c == null or c.local_pawn == null):
		await get_tree().process_frame
		c = App.client
	if c == null or c.local_pawn == null:
		print("FAIL: never reached a live pawn"); get_tree().quit(1); return

	var hud: Control = UIRouter.overlays.get(&"hud") if UIRouter.overlays.has(&"hud") else UIRouter.current
	if hud == null or not (hud.get("chat_input") != null):
		print("FAIL: HUD has no chat_input (current=%s)" % [UIRouter.current_name])
		get_tree().quit(1); return
	var line: LineEdit = hud.get("chat_input")
	if line.visible:
		print("FAIL: chat line starts visible"); get_tree().quit(1); return

	var got := {"text": ""}
	EventBus.notification.connect(func(text: String, kind: StringName) -> void:
		if kind == &"chat":
			got["text"] = text)

	hud.call("_open_chat", false)
	if not line.visible:
		print("FAIL: chat line did not open"); get_tree().quit(1); return
	print("chat line opened, mouse_mode=%d" % Input.mouse_mode)
	hud.call("_on_chat_submitted", "hello from the smoke test")
	if line.visible:
		print("FAIL: chat line stayed open after submit"); get_tree().quit(1); return

	var wait := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < wait and got["text"] == "":
		await get_tree().process_frame
	if got["text"] == "":
		print("FAIL: chat message never came back from the server")
		get_tree().quit(1); return
	print("round-tripped: %s" % got["text"])
	print("=== CHAT SMOKE OK ===")
	get_tree().quit(0)
