extends Node
## Verifies the killcam end to end: joins a match, forces the local pawn to die to a bot, and
## checks that the server sent a killcam window and the client started playing it.
## Run: tools/godot.sh --headless res://tools/killcam_smoke.tscn -- --client

func _ready() -> void:
	var main := (load("res://src/app/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame
	App.start_local_match(&"nightmarket", &"push", 8)
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var c := App.client
		if c and c.connected_ok and c.player_id != 0:
			c.select_hero(&"vesper")
			break
	var c := App.client
	if c == null:
		print("FAIL: no client"); get_tree().quit(1); return
	while Time.get_ticks_msec() < deadline and (c.local_pawn == null or not is_instance_valid(c.local_pawn)):
		await get_tree().process_frame
	if c.local_pawn == null:
		print("FAIL: never spawned"); get_tree().quit(1); return
	print("spawned; waiting for the live phase (setup grants spawn protection)")
	var server0: GameServer = App.server
	var live_by := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < live_by and server0.mode and server0.mode.phase != ModeController.Phase.LIVE:
		await get_tree().process_frame
	if server0.mode == null or server0.mode.phase != ModeController.Phase.LIVE:
		print("FAIL: match never went live"); get_tree().quit(1); return
	# Leave the spawn room: protection applies inside it.
	print("live; forcing a death")

	var started := {"ok": false, "killer": ""}
	EventBus.killcam_started.connect(func(name: String, _hero: StringName) -> void:
		started["ok"] = true
		started["killer"] = name)

	# Kill the local pawn on the server with a bot credited, which is what a real death looks like.
	var server: GameServer = App.server
	var victim: Pawn = c.local_pawn
	var killer: Pawn = null
	for ps: PlayerState in server.players.values():
		if ps.is_bot and ps.pawn and ps.pawn.alive and victim and ps.pawn.team != victim.team:
			killer = ps.pawn
			break
	if victim == null or killer == null:
		print("FAIL: could not find a victim/killer pair (victim=%s killer=%s)" % [victim, killer])
		get_tree().quit(1); return
	var ev := DamageEvent.new()
	ev.source = killer
	ev.target = victim
	ev.amount = 10000.0
	ev.ability_id = &"test_kill"
	ev.position = victim.center()
	ev.direction = Vector3.FORWARD
	ev.tick = server.tick
	server.world.apply_damage(ev)
	# Spawn protection or a mitigation window can eat one application; keep hitting until it lands.
	var tries := 0
	while victim.alive and tries < 240:
		tries += 1
		await get_tree().physics_frame
		var e2 := DamageEvent.new()
		e2.source = killer
		e2.target = victim
		e2.amount = 10000.0
		e2.ability_id = &"test_kill"
		e2.position = victim.center()
		e2.direction = Vector3.FORWARD
		e2.tick = server.tick
		server.world.apply_damage(e2)
	print("victim alive after %d applications: %s" % [tries, victim.alive])

	var wait := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < wait and not started["ok"]:
		await get_tree().process_frame
	if not started["ok"]:
		print("FAIL: no killcam started after death (pawn alive=%s)" % [c.local_pawn.alive if c.local_pawn else "gone"])
		get_tree().quit(1); return
	print("killcam started, killer=%s, replay_player=%s" % [started["killer"], c.presentation.replay_player != null])

	# It must end on its own, and never outlive the respawn.
	var ended := {"ok": false}
	EventBus.killcam_ended.connect(func() -> void: ended["ok"] = true)
	var stop_by := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < stop_by and not ended["ok"]:
		await get_tree().process_frame
	if not ended["ok"]:
		print("FAIL: killcam never ended")
		get_tree().quit(1); return
	print("=== KILLCAM SMOKE OK ===")
	get_tree().quit(0)
