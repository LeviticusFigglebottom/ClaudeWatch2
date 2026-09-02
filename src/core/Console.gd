extends Node
## Developer console + command layer. Commands are registered by systems (App, ClientWorld, tools).
## Also serves as the automation entry point: `--cmd "map test_range; hero vesper; shot foo.png"`.

signal line_printed(text: String, color: Color)

class Command:
	var name: String
	var help: String
	var callable: Callable
	func _init(n: String, h: String, c: Callable) -> void:
		name = n; help = h; callable = c

var commands: Dictionary = {}       # name -> Command
var history: Array[String] = []
var lines: Array[String] = []
var is_open: bool = false
var _queued: Array[String] = []
var _queue_delay_ticks: int = 0
var cvars: Dictionary = {}          # name -> Variant (debug tunables)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	register("help", "List commands", func(_a: PackedStringArray) -> String:
		var names := commands.keys(); names.sort()
		var out := ""
		for n: String in names:
			out += "%s - %s\n" % [n, (commands[n] as Command).help]
		return out)
	register("echo", "Print text", func(a: PackedStringArray) -> String: return " ".join(a))
	register("quit", "Exit the game", func(_a: PackedStringArray) -> String:
		get_tree().quit(); return "bye")
	register("wait", "wait <ticks>: delay queued commands", func(a: PackedStringArray) -> String:
		_queue_delay_ticks = int(a[0]) if a.size() > 0 else 60
		return "waiting %d ticks" % _queue_delay_ticks)
	register("set", "set <cvar> <value>", func(a: PackedStringArray) -> String:
		if a.size() < 2: return "usage: set <cvar> <value>"
		cvars[a[0]] = str_to_var(a[1]) if a[1].begins_with("Vector") or a[1].is_valid_float() else a[1]
		if a[1].is_valid_float(): cvars[a[0]] = float(a[1])
		return "%s = %s" % [a[0], str(cvars[a[0]])])
	register("get", "get <cvar>", func(a: PackedStringArray) -> String:
		return str(cvars.get(a[0], "<unset>")) if a.size() > 0 else "usage: get <cvar>")
	register("timescale", "timescale <f>", func(a: PackedStringArray) -> String:
		Engine.time_scale = float(a[0]) if a.size() > 0 else 1.0
		return "time_scale = %f" % Engine.time_scale)
	_parse_cmdline()


func _parse_cmdline() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		if args[i] == "--cmd" and i + 1 < args.size():
			for part: String in args[i + 1].split(";"):
				var t := part.strip_edges()
				if t != "":
					_queued.append(t)
			i += 2
		else:
			i += 1


func register(name: String, help: String, callable: Callable) -> void:
	commands[name] = Command.new(name, help, callable)


func unregister(name: String) -> void:
	commands.erase(name)


func cvar(name: String, default: Variant) -> Variant:
	return cvars.get(name, default)


func execute(line: String) -> String:
	line = line.strip_edges()
	if line == "":
		return ""
	history.append(line)
	print_line("> " + line, Color(0.7, 0.8, 0.9))
	var parts := line.split(" ", false)
	var name := parts[0]
	var args := parts.slice(1)
	if not commands.has(name):
		var msg := "unknown command: %s" % name
		print_line(msg, Color(1, 0.4, 0.4))
		return msg
	var result: Variant = (commands[name] as Command).callable.call(args)
	var text := str(result) if result != null else ""
	if text != "":
		print_line(text, Color(0.9, 0.9, 0.9))
	return text


func queue(line: String) -> void:
	_queued.append(line)


func print_line(text: String, color: Color = Color.WHITE) -> void:
	lines.append(text)
	if lines.size() > 400:
		lines.pop_front()
	line_printed.emit(text, color)
	if OS.has_feature("headless") or Console.cvars.get("stdout_console", true):
		print("[console] " + text)


func _physics_process(_delta: float) -> void:
	if _queue_delay_ticks > 0:
		_queue_delay_ticks -= 1
		return
	if _queued.is_empty():
		return
	# Execute one queued command per tick so `wait` can interleave.
	var line: String = _queued.pop_front()
	execute(line)


func has_pending() -> bool:
	return not _queued.is_empty() or _queue_delay_ticks > 0
