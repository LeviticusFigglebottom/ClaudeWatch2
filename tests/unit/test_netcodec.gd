extends GutTest
## Wire format round trips.


func test_input_roundtrip() -> void:
	var c := InputCmd.new()
	c.tick = 12345
	c.move = Vector2(0.5, -1.0)
	c.yaw = 1.234
	c.pitch = -0.4
	c.buttons = RF.BTN_JUMP | RF.BTN_PRIMARY
	c.pressed = RF.BTN_PRIMARY
	c.released = RF.BTN_CROUCH
	c.ack_snapshot = 77
	c.render_tick = 12300
	c.hero_request = 3
	var bytes := NetCodec.encode_inputs([c])
	var out := NetCodec.decode_inputs(bytes)
	assert_eq(out.size(), 1)
	var d := out[0]
	assert_eq(d.tick, 12345)
	assert_almost_eq(d.move.x, 0.5, 0.01)
	assert_almost_eq(d.move.y, -1.0, 0.01)
	assert_almost_eq(d.yaw, 1.234, 0.001)
	assert_almost_eq(d.pitch, -0.4, 0.001)
	assert_eq(d.buttons, RF.BTN_JUMP | RF.BTN_PRIMARY)
	assert_eq(d.pressed, RF.BTN_PRIMARY)
	assert_eq(d.ack_snapshot, 77)
	assert_eq(d.render_tick, 12300)
	assert_eq(d.hero_request, 3)
	assert_lt(bytes.size(), 40, "input cmd stays compact")


func test_events_roundtrip_compact_kinds() -> void:
	var events := [
		[&"damage", {"src": 3, "tgt": 5, "amt": 55.0, "hs": true, "killed": false, "crit": false, "pos": Vector3(1, 2, 3), "type": 0, "dir": Vector3(0, 0, -1)}],
		[&"footstep", {"pawn": 4, "pos": Vector3(10, 0, -5)}],
		[&"kill", {"victim": 5, "killer": 3, "ability": &"x", "headshot": true, "assists": [], "pos": Vector3.ZERO, "critical": false}],
	]
	var bytes := NetCodec.encode_events(events)
	var out := NetCodec.decode_events(bytes)
	assert_eq(out.size(), 3)
	assert_eq(out[0][0], &"damage")
	assert_eq(int(out[0][1]["tgt"]), 5)
	assert_almost_eq(float(out[0][1]["amt"]), 55.0, 0.5)
	assert_true(bool(out[0][1]["hs"]))
	assert_almost_eq((out[0][1]["pos"] as Vector3).x, 1.0, 0.01)
	assert_eq(out[1][0], &"footstep")
	assert_eq(out[2][0], &"kill")
	assert_eq(int(out[2][1]["killer"]), 3)


func test_position_quantization_precision() -> void:
	var b := StreamPeerBuffer.new()
	NetCodec.put_pos(b, Vector3(123.456, -7.891, 0.001))
	b.seek(0)
	var v := NetCodec.get_pos(b)
	assert_almost_eq(v.x, 123.456, 0.005)
	assert_almost_eq(v.y, -7.891, 0.005)
