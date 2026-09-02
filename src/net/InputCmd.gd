class_name InputCmd
extends RefCounted
## One tick of player intent. Serialized compactly for the wire (see NetCodec).

var tick: int = 0
var move: Vector2 = Vector2.ZERO        # x = strafe (-1..1), y = forward (-1..1)
var yaw: float = 0.0                    # radians
var pitch: float = 0.0                  # radians
var buttons: int = 0                    # RF.BTN_* bitmask
var pressed: int = 0                    # buttons that went down this tick (edge)
var released: int = 0                   # buttons that went up this tick
var ack_snapshot: int = 0               # last snapshot id the client applied (delta baseline)
var render_tick: int = 0                # server tick the client was rendering (lag comp)
var hero_request: int = -1              # hero index requested at spawn (-1 = none)
var ping_point: Vector3 = Vector3.ZERO


func has(btn: int) -> bool:
	return (buttons & btn) != 0


func just_pressed(btn: int) -> bool:
	return (pressed & btn) != 0


func just_released(btn: int) -> bool:
	return (released & btn) != 0


func copy() -> InputCmd:
	var c := InputCmd.new()
	c.tick = tick; c.move = move; c.yaw = yaw; c.pitch = pitch; c.buttons = buttons
	c.pressed = pressed; c.released = released; c.ack_snapshot = ack_snapshot
	c.render_tick = render_tick; c.hero_request = hero_request; c.ping_point = ping_point
	return c


func aim_dir() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


static func empty(t: int) -> InputCmd:
	var c := InputCmd.new()
	c.tick = t
	return c
