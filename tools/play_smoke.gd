extends Node
## End-to-end play test: drives the real menu path a player takes.
## Main menu -> Play vs Bots -> Start Match -> in match with a hero and a live HUD.
## The console `map` command bypasses all of this, which is why a broken PlayMenu reached a player.

func _ready() -> void:
	var main := (load("res://src/app/Main.tscn") as PackedScene).instantiate()
	add_child(main)
	for i in 3:
		await get_tree().process_frame

	UIRouter.show(&"play")
	await get_tree().process_frame
	var menu := UIRouter.current
	print("play menu: %s (maps listed: %d)" % [menu.name, menu.map_opt.item_count])
	if menu.map_opt.item_count == 0:
		print("FAIL: no maps listed in the play menu")
		get_tree().quit(1)
		return

	# This is exactly what the Start Match button calls.
	menu._start()
	print("start_local_match issued")

	# Wait for the connection, then do what a player does: pick a hero from hero select.
	var deadline := Time.get_ticks_msec() + 45000
	var picked := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		var cc := App.client
		if cc == null:
			continue
		if not picked and cc.connected_ok and cc.player_id != 0:
			print("connected as player %d; hero select open=%s" % [cc.player_id, UIRouter.has_overlay(&"hero_select")])
			cc.select_hero(&"vesper")
			picked = true
		if cc.local_pawn != null and is_instance_valid(cc.local_pawn):
			break

	var c := App.client
	if c == null:
		print("FAIL: no client after start")
		get_tree().quit(1); return
	if c.local_pawn == null or not is_instance_valid(c.local_pawn):
		print("FAIL: picked a hero but never got a pawn; screen=%s" % UIRouter.current_name)
		get_tree().quit(1); return

	var p := c.local_pawn
	print("IN MATCH on %s/%s: hero=%s team=%d hp=%.0f screen=%s pawns=%d" % [
		c.map_id, c.mode_id, p.hero.id, p.team, p.health.total(), UIRouter.current_name, c.world.pawns.size()])

	# Let it actually play. The local pawn is replaced on every respawn (and at round start), so
	# re-read it each time rather than holding a reference across frames.
	var play_until := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < play_until:
		await get_tree().process_frame
	var cur := c.local_pawn
	if cur == null or not is_instance_valid(cur):
		print("FAIL: lost the local pawn while playing")
		get_tree().quit(1); return
	print("AFTER 8s: hero=%s alive=%s hp=%.0f pos=%s pawns=%d ping=%.0f" % [
		cur.hero.id, cur.alive, cur.health.total(), str(cur.global_position.round()), c.world.pawns.size(), c.ping_ms])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://screenshots/ui")
	get_viewport().get_texture().get_image().save_png("res://screenshots/ui/play_end_to_end.png")
	print("=== PLAY SMOKE OK ===")
	get_tree().quit(0)
