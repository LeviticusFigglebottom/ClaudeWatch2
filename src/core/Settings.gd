extends Node
## User settings: persisted to user://settings.cfg. Sections are dictionaries with defaults;
## anything missing in the file falls back to the default so new keys never break old configs.

const PATH := "user://settings.cfg"

var data: Dictionary = {}

const DEFAULTS := {
	&"controls": {
		"mouse_sensitivity": 0.22,      # degrees per mouse-dot at 1.0
		"gamepad_sensitivity": 180.0,   # degrees per second at full stick
		"invert_y": false,
		"toggle_crouch": false,
		"hold_ultimate": false,
		"ads_hold": true,
		"fov": 103.0,
	},
	&"video": {
		"window_mode": 0,               # 0 windowed, 1 fullscreen, 2 borderless
		"vsync": 1,
		"max_fps": 240,
		"render_scale": 1.0,
		"msaa": 2,
		"fxaa": true,
		"shadow_quality": 2,            # 0 off, 1 low, 2 medium, 3 high
		"ssao": true,
		"glow": true,
		"volumetric_fog": true,
		"motion_blur": false,
		"detail_distance": 1.0,          # multiplier on the distance at which small props fade out
		"show_fps": false,
	},
	&"audio": {
		"master": 0.8,
		"sfx": 1.0,
		"music": 0.6,
		"ui": 0.8,
		"voice": 1.0,
	},
	&"accessibility": {
		"colorblind_mode": 0,           # 0 off, 1 deuteranopia, 2 protanopia, 3 tritanopia
		"screen_shake": 1.0,
		"hitstop": true,
		"camera_bob": 1.0,
		"hud_scale": 1.0,
		"damage_numbers": true,
		"subtitles": true,
		"crosshair_color": Color(0.95, 0.95, 0.95),
		"crosshair_size": 1.0,
		"reduce_flashing": false,
		"high_contrast_enemies": false,
	},
	&"gameplay": {
		"player_name": "Runner",
		"auto_hero_swap_hint": true,
		"show_ally_outlines": true,
		"bot_difficulty": 2,            # 0 recruit, 1 regular, 2 veteran, 3 elite
		"preferred_role": -1,
	},
	&"network": {
		"last_address": "127.0.0.1",
		"port": 27015,
		"interp_delay_ms": 66,
		"sim_latency_ms": 0,
		"sim_packet_loss": 0.0,
		"sim_jitter_ms": 0,
	},
}

var keybinds: Dictionary = {}   # action -> Array of serialized events


func _ready() -> void:
	for section: StringName in DEFAULTS.keys():
		data[section] = (DEFAULTS[section] as Dictionary).duplicate(true)
	load_settings()
	apply_all()


func get_value(section: StringName, key: String) -> Variant:
	return (data.get(section, {}) as Dictionary).get(key, (DEFAULTS.get(section, {}) as Dictionary).get(key))


func set_value(section: StringName, key: String, value: Variant, save: bool = true) -> void:
	(data[section] as Dictionary)[key] = value
	if save:
		save_settings()
	apply_section(section)
	EventBus.settings_changed.emit(section)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for section: StringName in DEFAULTS.keys():
		for key: String in (DEFAULTS[section] as Dictionary).keys():
			if cfg.has_section_key(section, key):
				(data[section] as Dictionary)[key] = cfg.get_value(section, key)
	if cfg.has_section("keybinds"):
		for action: String in cfg.get_section_keys("keybinds"):
			keybinds[action] = cfg.get_value("keybinds", action)
		_apply_keybinds()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section: StringName in data.keys():
		for key: String in (data[section] as Dictionary).keys():
			cfg.set_value(section, key, (data[section] as Dictionary)[key])
	for action: String in keybinds.keys():
		cfg.set_value("keybinds", action, keybinds[action])
	cfg.save(PATH)


func apply_all() -> void:
	for section: StringName in data.keys():
		apply_section(section)


func apply_section(section: StringName) -> void:
	match section:
		&"video":
			_apply_video()
		&"audio":
			_apply_audio()


func _apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var v: Dictionary = data[&"video"]
	var mode: int = v["window_mode"]
	match mode:
		0: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		2: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] == 1 else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(v["max_fps"])
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = float(v["render_scale"])
		vp.msaa_3d = int(v["msaa"]) as Viewport.MSAA
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if v["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
		vp.positional_shadow_atlas_size = [0, 1024, 2048, 4096][clampi(int(v["shadow_quality"]), 0, 3)]
	match int(v["shadow_quality"]):
		0: RenderingServer.directional_shadow_atlas_set_size(1024, true)
		1: RenderingServer.directional_shadow_atlas_set_size(2048, true)
		2: RenderingServer.directional_shadow_atlas_set_size(4096, true)
		3: RenderingServer.directional_shadow_atlas_set_size(8192, true)


func _apply_audio() -> void:
	var a: Dictionary = data[&"audio"]
	for bus_name: String in ["Master", "SFX", "Music", "UI", "Voice"]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var key := bus_name.to_lower()
		var vol: float = float(a.get(key, 1.0))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(vol, 0.0001)))
		AudioServer.set_bus_mute(idx, vol <= 0.0001)


## Keybinds -------------------------------------------------------------------

func rebind(action: String, events: Array[InputEvent]) -> void:
	InputMap.action_erase_events(action)
	for e: InputEvent in events:
		InputMap.action_add_event(action, e)
	keybinds[action] = _serialize_events(events)
	save_settings()
	EventBus.settings_changed.emit(&"controls")


func reset_keybinds() -> void:
	keybinds.clear()
	InputMap.load_from_project_settings()
	save_settings()
	EventBus.settings_changed.emit(&"controls")


func _apply_keybinds() -> void:
	for action: String in keybinds.keys():
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for ev: Variant in keybinds[action]:
			var e := _deserialize_event(ev as Dictionary)
			if e:
				InputMap.action_add_event(action, e)


func _serialize_events(events: Array[InputEvent]) -> Array:
	var out: Array = []
	for e: InputEvent in events:
		if e is InputEventKey:
			out.append({"t": "key", "k": (e as InputEventKey).physical_keycode})
		elif e is InputEventMouseButton:
			out.append({"t": "mb", "b": (e as InputEventMouseButton).button_index})
		elif e is InputEventJoypadButton:
			out.append({"t": "jb", "b": (e as InputEventJoypadButton).button_index})
		elif e is InputEventJoypadMotion:
			out.append({"t": "jm", "a": (e as InputEventJoypadMotion).axis, "v": (e as InputEventJoypadMotion).axis_value})
	return out


func _deserialize_event(d: Dictionary) -> InputEvent:
	match String(d.get("t", "")):
		"key":
			var k := InputEventKey.new(); k.physical_keycode = int(d["k"]) as Key; return k
		"mb":
			var m := InputEventMouseButton.new(); m.button_index = int(d["b"]) as MouseButton; return m
		"jb":
			var j := InputEventJoypadButton.new(); j.button_index = int(d["b"]) as JoyButton; return j
		"jm":
			var jm := InputEventJoypadMotion.new(); jm.axis = int(d["a"]) as JoyAxis; jm.axis_value = float(d["v"]); return jm
	return null


func action_display_string(action: String) -> String:
	var events := InputMap.action_get_events(action)
	for e: InputEvent in events:
		if e is InputEventKey:
			var k := e as InputEventKey
			if DisplayServer.get_name() == "headless":
				return OS.get_keycode_string(k.physical_keycode).to_upper()
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(k.physical_keycode)).to_upper()
		if e is InputEventMouseButton:
			match (e as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				_: return "M%d" % (e as InputEventMouseButton).button_index
	return "?"
