class_name InputCollector
extends Node
## Turns raw device input into InputCmds at the simulation rate. Mouse look accumulates between ticks.

var yaw: float = 0.0
var pitch: float = 0.0
var _mouse_delta: Vector2 = Vector2.ZERO
var _prev_buttons: int = 0
var enabled: bool = true
var look_locked: bool = false
var crouch_toggled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and enabled and not look_locked:
		_mouse_delta += (event as InputEventMouseMotion).relative


func set_view(y: float, p: float) -> void:
	yaw = y; pitch = p


func build(tick: int, pawn: Pawn) -> InputCmd:
	var cmd := InputCmd.new()
	cmd.tick = tick
	var sens: float = float(Settings.get_value(&"controls", "mouse_sensitivity"))
	var invert: bool = bool(Settings.get_value(&"controls", "invert_y"))
	if enabled and not look_locked:
		yaw -= deg_to_rad(_mouse_delta.x * sens)
		pitch += deg_to_rad(_mouse_delta.y * sens) * (1.0 if invert else -1.0)
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down") if InputMap.has_action("look_left") else Vector2.ZERO
		var gp_sens: float = float(Settings.get_value(&"controls", "gamepad_sensitivity"))
		yaw -= deg_to_rad(stick.x * gp_sens * RF.TICK_DT)
		pitch -= deg_to_rad(stick.y * gp_sens * RF.TICK_DT) * (-1.0 if invert else 1.0)
	_mouse_delta = Vector2.ZERO
	pitch = clampf(pitch, -PI * 0.49, PI * 0.49)
	yaw = wrapf(yaw, -PI, PI)
	cmd.yaw = yaw
	cmd.pitch = pitch
	if enabled:
		cmd.move = Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
		var b := 0
		if Input.is_action_pressed("jump"): b |= RF.BTN_JUMP
		if bool(Settings.get_value(&"controls", "toggle_crouch")):
			if Input.is_action_just_pressed("crouch"): crouch_toggled = not crouch_toggled
			if crouch_toggled: b |= RF.BTN_CROUCH
		elif Input.is_action_pressed("crouch"): b |= RF.BTN_CROUCH
		if Input.is_action_pressed("primary_fire"): b |= RF.BTN_PRIMARY
		if Input.is_action_pressed("secondary_fire"): b |= RF.BTN_SECONDARY
		if Input.is_action_pressed("ability_1"): b |= RF.BTN_ABILITY_1
		if Input.is_action_pressed("ability_2"): b |= RF.BTN_ABILITY_2
		if Input.is_action_pressed("ability_3"): b |= RF.BTN_ABILITY_3
		if Input.is_action_pressed("ultimate"): b |= RF.BTN_ULTIMATE
		if Input.is_action_pressed("reload"): b |= RF.BTN_RELOAD
		if Input.is_action_pressed("melee"): b |= RF.BTN_MELEE
		if Input.is_action_pressed("interact"): b |= RF.BTN_INTERACT
		if Input.is_action_pressed("ping"): b |= RF.BTN_PING
		cmd.buttons = b
	cmd.pressed = cmd.buttons & ~_prev_buttons
	cmd.released = _prev_buttons & ~cmd.buttons
	_prev_buttons = cmd.buttons
	return cmd


func reset_edges() -> void:
	_prev_buttons = 0
