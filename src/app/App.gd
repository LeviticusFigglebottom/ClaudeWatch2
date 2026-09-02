extends Node
## Application flow: boot -> menu -> lobby -> match -> post-match. Owns the local server (offline/host)
## and the client. Screens are UI scenes swapped under the UI layer; the world lives in Client/Server nodes.

enum Screen { BOOT, MAIN_MENU, PLAY, LOBBY, HERO_SELECT, MATCH, POST_MATCH, SETTINGS, TRAINING }

var screen: Screen = Screen.BOOT
var server: GameServer
var client: GameClient
var ui_root: CanvasLayer
var world_root: Node
var is_headless: bool = false
var is_dedicated: bool = false
var launch_args: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_headless = DisplayServer.get_name() == "headless"
	_parse_args()
	_register_commands()


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var a := args[i]
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			launch_args[kv[0]] = kv[1]
		elif a.begins_with("--"):
			launch_args[a.substr(2)] = true
		i += 1
	is_dedicated = launch_args.has("server")


func _register_commands() -> void:
	Console.register("map", "map <id> [mode] [bots]: start a local match", func(a: PackedStringArray) -> String:
		if a.size() < 1: return "usage: map <id> [mode] [bots]"
		var mode_id: StringName = StringName(a[1]) if a.size() > 1 else &""
		var bots := int(a[2]) if a.size() > 2 else 9
		start_local_match(StringName(a[0]), mode_id, bots)
		return "starting %s" % a[0])
	Console.register("maps", "List maps", func(_a: PackedStringArray) -> String: return ", ".join(Registry.map_ids()))
	Console.register("heroes", "List heroes", func(_a: PackedStringArray) -> String: return ", ".join(Registry.hero_ids()))
	Console.register("modes", "List modes", func(_a: PackedStringArray) -> String: return ", ".join(Registry.mode_ids()))
	Console.register("menu", "Return to main menu", func(_a: PackedStringArray) -> String:
		go_to_menu(); return "menu")
	Console.register("status", "Server status: players, pawns, mode", func(_a: PackedStringArray) -> String:
		if server == null: return "no server"
		var out := "tick %d  mode %s phase %d  score %s  bw %.1f KB/s  tick_ms %.2f\n" % [server.tick, server.config.mode_id, server.mode.phase if server.mode else -1, str(server.mode.score) if server.mode else "", server.bandwidth_kbps, server.perf_tick_ms]
		for ps: PlayerState in server.players.values():
			var p := ps.pawn
			out += "  %-12s T%d %-10s %s hp %.0f pos %s k/d %d/%d ult %.0f%%\n" % [ps.name, ps.team, ps.hero_id, "alive" if p and p.alive else "dead ", p.health.total() if p else 0.0, str(p.global_position.round()) if p else "-", ps.stats.kills, ps.stats.deaths, p.ult_fraction() * 100.0 if p else 0.0]
		return out)
	Console.register("shot", "shot <path.png>: save a screenshot of the main viewport", func(a: PackedStringArray) -> String:
		var path := a[0] if a.size() > 0 else "screenshots/shot.png"
		_take_screenshot(path)
		return "screenshot -> " + path)


func attach_roots(ui: CanvasLayer, world: Node) -> void:
	ui_root = ui
	world_root = world


## Boot decision: dedicated server, automation, or menu.
func boot() -> void:
	if is_dedicated:
		start_dedicated_server()
		return
	if launch_args.has("sim"):
		return   # SimHarness drives everything
	if not Console.has_pending():
		go_to_menu()


func go_to_menu() -> void:
	stop_match()
	screen = Screen.MAIN_MENU
	if ui_root:
		UIRouter.show(&"main_menu")
	EventBus.screen_changed.emit(&"main_menu")


## Local match: in-process server + client on the same code path as online play.
func start_local_match(map_id: StringName, mode_id: StringName = &"", bot_count: int = 9, opts: Dictionary = {}) -> void:
	stop_match()
	var md := Registry.map(map_id)
	if md == null:
		push_error("Unknown map %s" % map_id)
		Console.print_line("Unknown map %s (have: %s)" % [map_id, ", ".join(Registry.map_ids())], Color.RED)
		return
	if mode_id == &"" or Registry.mode(mode_id) == null:
		mode_id = md.supported_modes[0] if not md.supported_modes.is_empty() else &"control"
	server = GameServer.new()
	server.name = "Server"
	world_root.add_child(server)
	var port: int = int(Settings.get_value(&"network", "port"))
	var cfg := MatchConfig.new()
	cfg.map_id = map_id
	cfg.mode_id = mode_id
	cfg.bot_count = bot_count
	cfg.bot_difficulty = int(opts.get("difficulty", Settings.get_value(&"gameplay", "bot_difficulty")))
	cfg.local = true
	for k: String in opts.keys():
		if k in cfg:
			cfg.set(k, opts[k])
	server.host(port, cfg)
	if not is_headless or launch_args.has("client"):
		_start_client("127.0.0.1", port)
	screen = Screen.MATCH


func host_online(port: int, cfg: MatchConfig) -> void:
	stop_match()
	server = GameServer.new()
	server.name = "Server"
	world_root.add_child(server)
	cfg.local = false
	server.host(port, cfg)
	_start_client("127.0.0.1", port)
	screen = Screen.MATCH


func join_online(address: String, port: int) -> void:
	stop_match()
	_start_client(address, port)
	screen = Screen.MATCH


func start_dedicated_server() -> void:
	var cfg := MatchConfig.new()
	cfg.map_id = StringName(String(launch_args.get("map", "saltmarsh")))
	cfg.mode_id = StringName(String(launch_args.get("mode", "")))
	cfg.bot_count = int(launch_args.get("bots", 0))
	cfg.local = false
	cfg.bot_fill = true
	var port := int(launch_args.get("port", Settings.get_value(&"network", "port")))
	server = GameServer.new()
	server.name = "Server"
	world_root.add_child(server)
	server.host(port, cfg)
	print("[server] Dedicated server on port %d, map %s" % [port, cfg.map_id])


func _start_client(address: String, port: int) -> void:
	client = GameClient.new()
	client.name = "Client"
	world_root.add_child(client)
	client.connect_to(address, port)
	if ui_root:
		UIRouter.show(&"connecting")


func stop_match() -> void:
	if client:
		client.shutdown()
		client.queue_free()
		client = null
	if server:
		server.shutdown()
		server.queue_free()
		server = null


func on_client_disconnected(reason: String) -> void:
	if is_dedicated:
		return
	EventBus.notification.emit("Disconnected: %s" % reason, &"error")
	go_to_menu()


func _take_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if path.get_base_dir() != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path.get_base_dir())
	var err := img.save_png(path)
	Console.print_line("saved %s (%s)" % [path, error_string(err)])


func quit() -> void:
	stop_match()
	get_tree().quit()
