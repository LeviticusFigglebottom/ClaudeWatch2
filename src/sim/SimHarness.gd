class_name SimHarness
extends Node
## Headless bot-vs-bot match runner for balance telemetry and soak testing.
## godot --headless --fixed-fps 60 --path . -- --sim --map=kestrel --mode=control --matches=20 \
##     --difficulty=2 --seed=1 --out=sim_out --teamA=ballast,vesper,coil,tallow,cadence --teamB=random
## Writes one JSON per match into --out and a summary line to stdout per match.

var matches: int = 1
var done: int = 0
var map_id: StringName = &"test_range"
var mode_id: StringName = &""
var difficulty: int = 2
var seed_base: int = 1
var out_dir: String = "sim_out"
var team_lock: Dictionary = {}
var time_limit: float = 600.0
var server: GameServer
var started_ms: int = 0
var match_started_ms: int = 0
var random_comps: bool = true
var log_every: int = 0
var soak: bool = false


func _ready() -> void:
	var a := App.launch_args
	matches = int(a.get("matches", 1))
	map_id = StringName(String(a.get("map", "test_range")))
	mode_id = StringName(String(a.get("mode", "")))
	difficulty = int(a.get("difficulty", 2))
	seed_base = int(a.get("seed", 1))
	out_dir = String(a.get("out", "sim_out"))
	time_limit = float(a.get("limit", 600.0))
	soak = a.has("soak")
	for t: Array in [["teamA", 0], ["teamB", 1]]:
		var v := String(a.get(t[0], "random"))
		if v != "random" and v != "":
			var arr: Array = []
			for h: String in v.split(","):
				arr.append(StringName(h.strip_edges()))
			team_lock[int(t[1])] = arr
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + out_dir) if not out_dir.is_absolute_path() else out_dir)
	started_ms = Time.get_ticks_msec()
	print("[sim] %d matches on %s/%s, difficulty %d, seed %d" % [matches, map_id, mode_id, difficulty, seed_base])
	_start_next()


func _start_next() -> void:
	if done >= matches:
		var total := (Time.get_ticks_msec() - started_ms) / 1000.0
		print("[sim] finished %d matches in %.1f s" % [done, total])
		get_tree().quit()
		return
	var cfg := MatchConfig.new()
	cfg.map_id = map_id
	cfg.mode_id = mode_id
	cfg.bot_count = 10
	cfg.bot_fill = true
	cfg.bot_difficulty = difficulty
	cfg.local = true
	cfg.sim_mode = true
	cfg.skip_setup = true
	cfg.seed = seed_base + done
	cfg.match_time_limit = time_limit
	cfg.bot_hero_lock = team_lock.duplicate()
	var out_path := out_dir.path_join("match_%s_%s_%d.json" % [map_id, mode_id if mode_id != &"" else "auto", cfg.seed])
	cfg.telemetry_path = out_path if out_dir.is_absolute_path() else ProjectSettings.globalize_path("res://" + out_path)
	server = GameServer.new()
	server.name = "Server"
	App.world_root.add_child(server)
	server.match_finished.connect(_on_finished)
	match_started_ms = Time.get_ticks_msec()
	server.host(27100 + (done % 50), cfg)
	if server.mode == null:
		push_error("[sim] server failed to start")
		get_tree().quit(1)


func _process(_delta: float) -> void:
	if server == null or not server.running:
		return
	var elapsed := server.tick * RF.TICK_DT
	if elapsed > time_limit and server.mode and server.mode.phase != ModeController.Phase.MATCH_END:
		server.mode.finish_match()
	if log_every > 0 and server.tick % log_every == 0:
		print("[sim] tick %d" % server.tick)


func _on_finished(summary: Dictionary) -> void:
	done += 1
	var real := (Time.get_ticks_msec() - match_started_ms) / 1000.0
	var sim_s := server.tick * RF.TICK_DT
	var comps: Array = server.telemetry._team_comps()
	print("[sim] match %d/%d: winner %s score %s  sim %.0fs in %.1fs real (%.1fx)  A=%s B=%s" % [done, matches, str(summary.get("winner", -1)), str(summary.get("score", [])), sim_s, real, sim_s / maxf(real, 0.001), ",".join(comps[0]), ",".join(comps[1])])
	var s := server
	server = null
	s.shutdown()
	s.queue_free()
	call_deferred("_start_next")
