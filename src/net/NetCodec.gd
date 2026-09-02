class_name NetCodec
extends RefCounted
## Wire format. Everything is little-endian via StreamPeerBuffer. Quantization:
##   position  int32 @ 1/256 m   rotation u16 (yaw 0..2pi) / i16 (pitch)   velocity i16 @ 1/64 m/s
##   health    u16               cooldowns u16 @ 1/100 s                    percent u16 @ 1/10000

const MSG_INPUT := 1
const MSG_HELLO := 2
const MSG_READY := 3
const MSG_SNAPSHOT := 10
const MSG_EVENT := 11
const MSG_WELCOME := 12
const MSG_PING := 13
const MSG_PONG := 14
const MSG_CLIENT_CMD := 15   # hero select, team request, chat, ping
const MSG_PLAYERS := 16      # roster update

const POS_SCALE := 256.0
const VEL_SCALE := 64.0
const CD_SCALE := 100.0
const F_POS := 1 << 0
const F_ROT := 1 << 1
const F_VEL := 1 << 2
const F_HEALTH := 1 << 3
const F_STATE := 1 << 4
const F_ANIM := 1 << 5
const F_LOCAL := 1 << 6
const F_ALL := F_POS | F_ROT | F_VEL | F_HEALTH | F_STATE | F_ANIM

# Pawn state flags
const S_ALIVE := 1 << 0
const S_CROUCH := 1 << 1
const S_GROUNDED := 1 << 2
const S_ULT_READY := 1 << 3
const S_STUNNED := 1 << 4
const S_ROOTED := 1 << 5
const S_INVISIBLE := 1 << 6
const S_REVEALED := 1 << 7
const S_PROTECTED := 1 << 8
const S_ON_OBJECTIVE := 1 << 9
const S_HOVERING := 1 << 10
const S_BOT := 1 << 11
const S_INVULN := 1 << 12
const S_MOVE_LOCK := 1 << 13


static func put_pos(b: StreamPeerBuffer, v: Vector3) -> void:
	b.put_32(int(round(v.x * POS_SCALE)))
	b.put_32(int(round(v.y * POS_SCALE)))
	b.put_32(int(round(v.z * POS_SCALE)))


static func get_pos(b: StreamPeerBuffer) -> Vector3:
	return Vector3(b.get_32() / POS_SCALE, b.get_32() / POS_SCALE, b.get_32() / POS_SCALE)


static func put_vel(b: StreamPeerBuffer, v: Vector3) -> void:
	b.put_16(clampi(int(round(v.x * VEL_SCALE)), -32767, 32767))
	b.put_16(clampi(int(round(v.y * VEL_SCALE)), -32767, 32767))
	b.put_16(clampi(int(round(v.z * VEL_SCALE)), -32767, 32767))


static func get_vel(b: StreamPeerBuffer) -> Vector3:
	return Vector3(b.get_16() / VEL_SCALE, b.get_16() / VEL_SCALE, b.get_16() / VEL_SCALE)


static func put_yaw(b: StreamPeerBuffer, yaw: float) -> void:
	b.put_u16(int(fposmod(yaw, TAU) / TAU * 65535.0))


static func get_yaw(b: StreamPeerBuffer) -> float:
	return b.get_u16() / 65535.0 * TAU


static func put_pitch(b: StreamPeerBuffer, pitch: float) -> void:
	b.put_16(int(clampf(pitch / (PI * 0.5), -1.0, 1.0) * 32767.0))


static func get_pitch(b: StreamPeerBuffer) -> float:
	return b.get_16() / 32767.0 * PI * 0.5


static func put_str(b: StreamPeerBuffer, s: String) -> void:
	var bytes := s.to_utf8_buffer()
	b.put_u16(bytes.size())
	b.put_data(bytes)


static func get_str(b: StreamPeerBuffer) -> String:
	var n := b.get_u16()
	var r := b.get_data(n)
	return (r[1] as PackedByteArray).get_string_from_utf8()


static func put_var(b: StreamPeerBuffer, v: Variant) -> void:
	var bytes := var_to_bytes(v)
	b.put_u32(bytes.size())
	b.put_data(bytes)


static func get_var(b: StreamPeerBuffer) -> Variant:
	var n := b.get_u32()
	var r := b.get_data(n)
	return bytes_to_var(r[1] as PackedByteArray)


## --- Input --------------------------------------------------------------------------------

static func encode_inputs(cmds: Array[InputCmd]) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(MSG_INPUT)
	b.put_u8(cmds.size())
	for c: InputCmd in cmds:
		b.put_u32(c.tick)
		b.put_8(int(clampf(c.move.x, -1.0, 1.0) * 127.0))
		b.put_8(int(clampf(c.move.y, -1.0, 1.0) * 127.0))
		put_yaw(b, c.yaw)
		put_pitch(b, c.pitch)
		b.put_u16(c.buttons)
		b.put_u16(c.pressed)
		b.put_u16(c.released)
		b.put_u32(c.ack_snapshot)
		b.put_u32(c.render_tick)
		b.put_8(c.hero_request)
		if c.has(RF.BTN_PING) and c.just_pressed(RF.BTN_PING):
			put_pos(b, c.ping_point)
	return b.data_array


static func decode_inputs(bytes: PackedByteArray) -> Array[InputCmd]:
	var out: Array[InputCmd] = []
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	if b.get_u8() != MSG_INPUT:
		return out
	var n := b.get_u8()
	for i in n:
		var c := InputCmd.new()
		c.tick = b.get_u32()
		c.move = Vector2(b.get_8() / 127.0, b.get_8() / 127.0)
		c.yaw = get_yaw(b)
		c.pitch = get_pitch(b)
		c.buttons = b.get_u16()
		c.pressed = b.get_u16()
		c.released = b.get_u16()
		c.ack_snapshot = b.get_u32()
		c.render_tick = b.get_u32()
		c.hero_request = b.get_8()
		if c.has(RF.BTN_PING) and c.just_pressed(RF.BTN_PING):
			c.ping_point = get_pos(b)
		out.append(c)
	return out


## --- Pawn snapshot fields --------------------------------------------------------------------

## Captures the sendable state of a pawn into a compact Dictionary (used for baselines & diffs).
static func capture_pawn(p: Pawn, tick: int) -> Dictionary:
	var flags := 0
	if p.alive: flags |= S_ALIVE
	if p.movement.crouching: flags |= S_CROUCH
	if p.is_on_floor(): flags |= S_GROUNDED
	if p.ult_fraction() >= 1.0: flags |= S_ULT_READY
	if p.status.stunned: flags |= S_STUNNED
	if p.status.rooted: flags |= S_ROOTED
	if p.status.invisible: flags |= S_INVISIBLE
	if p.status.revealed: flags |= S_REVEALED
	if p.spawn_protected(tick): flags |= S_PROTECTED
	if p.on_objective: flags |= S_ON_OBJECTIVE
	if p.movement.hovering: flags |= S_HOVERING
	if p.is_bot: flags |= S_BOT
	if p.status.invulnerable: flags |= S_INVULN
	if p.movement.move_lock_timer > 0.0: flags |= S_MOVE_LOCK
	var active := p.abilities.active_ability()
	var anim := p.anim_state & 0xFF
	var act_slot := active.slot + 1 if active else 0
	return {
		"pos": Vector3i(int(round(p.global_position.x * POS_SCALE)), int(round(p.global_position.y * POS_SCALE)), int(round(p.global_position.z * POS_SCALE))),
		"yaw": int(fposmod(p.yaw, TAU) / TAU * 65535.0),
		"pitch": int(clampf(p.pitch / (PI * 0.5), -1.0, 1.0) * 32767.0),
		"vel": Vector3i(clampi(int(round(p.velocity.x * VEL_SCALE)), -32767, 32767), clampi(int(round(p.velocity.y * VEL_SCALE)), -32767, 32767), clampi(int(round(p.velocity.z * VEL_SCALE)), -32767, 32767)),
		"hp": Vector4i(int(ceil(p.health.health)), int(ceil(p.health.armor)), int(ceil(p.health.shield)), int(ceil(p.health.overhealth))),
		"flags": flags,
		"anim": anim | (act_slot << 8) | (int(p.flags_extra & 0xFF) << 16),
		"ult": int(p.ult_fraction() * 10000.0),
		"res": int(clampf(p.hero_resource / maxf(p.hero.hero_resource_max, 1.0), 0.0, 1.0) * 10000.0) if p.hero.hero_resource_max > 0.0 else 0,
	}


static func write_pawn_delta(b: StreamPeerBuffer, net_id: int, cur: Dictionary, base: Dictionary, p: Pawn, include_local: bool) -> int:
	var mask := 0
	if base.is_empty():
		mask = F_ALL
	else:
		if cur["pos"] != base["pos"]: mask |= F_POS
		if cur["yaw"] != base["yaw"] or cur["pitch"] != base["pitch"]: mask |= F_ROT
		if cur["vel"] != base["vel"]: mask |= F_VEL
		if cur["hp"] != base["hp"] or cur["ult"] != base["ult"] or cur["res"] != base["res"]: mask |= F_HEALTH
		if cur["flags"] != base["flags"]: mask |= F_STATE
		if cur["anim"] != base["anim"]: mask |= F_ANIM
	if include_local:
		mask |= F_LOCAL
	if mask == 0:
		return 0
	b.put_u16(net_id)
	b.put_u8(mask)
	if mask & F_POS:
		var v: Vector3i = cur["pos"]
		b.put_32(v.x); b.put_32(v.y); b.put_32(v.z)
	if mask & F_ROT:
		b.put_u16(cur["yaw"]); b.put_16(cur["pitch"])
	if mask & F_VEL:
		var v: Vector3i = cur["vel"]
		b.put_16(v.x); b.put_16(v.y); b.put_16(v.z)
	if mask & F_HEALTH:
		var h: Vector4i = cur["hp"]
		b.put_u16(h.x); b.put_u16(h.y); b.put_u16(h.z); b.put_u16(h.w)
		b.put_u16(cur["ult"]); b.put_u16(cur["res"])
	if mask & F_STATE:
		b.put_u16(cur["flags"])
	if mask & F_ANIM:
		b.put_u32(cur["anim"])
	if mask & F_LOCAL:
		# Full ability state for the owning client (not delta'd; ~40 bytes).
		b.put_u8(RF.SLOT_COUNT)
		for s in RF.SLOT_COUNT:
			var ab := p.abilities.get_slot(s)
			if ab == null:
				b.put_u8(255)
				continue
			b.put_u8(ab.state)
			b.put_u16(int(clampf(ab.cooldown_remaining, 0.0, 600.0) * CD_SCALE))
			b.put_u8(ab.charges_left)
			b.put_u16(ab.ammo)
			b.put_u16(int(clampf(ab.reload_remaining, 0.0, 60.0) * CD_SCALE))
			b.put_u16(int(clampf(ab.active_remaining if ab.active_remaining != INF else 0.0, 0.0, 600.0) * CD_SCALE))
		b.put_u16(int(clampf(p.abilities.global_lock_remaining, 0.0, 60.0) * CD_SCALE))
		b.put_u16(int(clampf(p.movement.move_lock_timer, 0.0, 60.0) * CD_SCALE))
		b.put_u8(p.movement.jumps_left)
		b.put_u16(int(clampf(p.movement.hover_fuel, 0.0, 600.0) * CD_SCALE))
		b.put_u16(int(clampf(p.movement.speed_override_timer, 0.0, 60.0) * CD_SCALE))
		b.put_u16(int(clampf(p.movement.speed_override_mult, 0.0, 6.0) * 10000.0))
	return 1


## Reads one pawn delta; merges into `state` (a dict of the decoded field values) and returns net_id.
static func read_pawn_delta(b: StreamPeerBuffer, state: Dictionary) -> int:
	var net_id := b.get_u16()
	var mask := b.get_u8()
	var s: Dictionary = state.get(net_id, {})
	if mask & F_POS:
		s["pos"] = Vector3i(b.get_32(), b.get_32(), b.get_32())
	if mask & F_ROT:
		s["yaw"] = b.get_u16(); s["pitch"] = b.get_16()
	if mask & F_VEL:
		s["vel"] = Vector3i(b.get_16(), b.get_16(), b.get_16())
	if mask & F_HEALTH:
		s["hp"] = Vector4i(b.get_u16(), b.get_u16(), b.get_u16(), b.get_u16())
		s["ult"] = b.get_u16(); s["res"] = b.get_u16()
	if mask & F_STATE:
		s["flags"] = b.get_u16()
	if mask & F_ANIM:
		s["anim"] = b.get_u32()
	if mask & F_LOCAL:
		var n := b.get_u8()
		var slots: Array = []
		for i in n:
			var st := b.get_u8()
			if st == 255:
				slots.append(null)
				continue
			slots.append({"state": st, "cd": b.get_u16() / CD_SCALE, "charges": b.get_u8(), "ammo": b.get_u16(),
				"reload": b.get_u16() / CD_SCALE, "active": b.get_u16() / CD_SCALE})
		s["slots"] = slots
		s["global_lock"] = b.get_u16() / CD_SCALE
		s["move_lock"] = b.get_u16() / CD_SCALE
		s["jumps_left"] = b.get_u8()
		s["hover_fuel"] = b.get_u16() / CD_SCALE
		s["speed_override_timer"] = b.get_u16() / CD_SCALE
		s["speed_override_mult"] = b.get_u16() / 10000.0
	state[net_id] = s
	return net_id


static func pos_of(s: Dictionary) -> Vector3:
	var v: Vector3i = s.get("pos", Vector3i.ZERO)
	return Vector3(v.x / POS_SCALE, v.y / POS_SCALE, v.z / POS_SCALE)


static func vel_of(s: Dictionary) -> Vector3:
	var v: Vector3i = s.get("vel", Vector3i.ZERO)
	return Vector3(v.x / VEL_SCALE, v.y / VEL_SCALE, v.z / VEL_SCALE)


static func yaw_of(s: Dictionary) -> float:
	return int(s.get("yaw", 0)) / 65535.0 * TAU


static func pitch_of(s: Dictionary) -> float:
	return int(s.get("pitch", 0)) / 32767.0 * PI * 0.5


## --- Generic messages ------------------------------------------------------------------------

static func encode_msg(kind: int, payload: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(kind)
	put_var(b, payload)
	return b.data_array


static func decode_msg(bytes: PackedByteArray) -> Dictionary:
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	var kind := b.get_u8()
	var payload: Variant = get_var(b)
	return {"kind": kind, "payload": payload if payload is Dictionary else {}}


## Events: batch of (kind:StringName, payload:Dictionary), compact for the hot kinds.
static func encode_events(events: Array) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(MSG_EVENT)
	b.put_u16(events.size())
	for e: Array in events:
		var kind: StringName = e[0]
		var pl: Dictionary = e[1]
		match kind:
			&"hitscan":
				b.put_u8(1)
				b.put_u16(pl["pawn"]); b.put_8(pl["slot"])
				put_pos(b, pl["origin"])
				var hits: Array = pl["hits"]
				b.put_u8(hits.size())
				for h: Dictionary in hits:
					put_pos(b, h["end"])
					b.put_16(h["pawn"])
					b.put_u8(1 if h["part"] == &"head" else (2 if h["part"] == &"body" else 0))
					b.put_u8((1 if h.get("barrier", false) else 0) | (2 if h.get("deployable", false) else 0))
					var n: Vector3 = h["normal"]
					b.put_8(int(clampf(n.x, -1, 1) * 127)); b.put_8(int(clampf(n.y, -1, 1) * 127)); b.put_8(int(clampf(n.z, -1, 1) * 127))
			&"damage":
				b.put_u8(2)
				b.put_16(pl["src"]); b.put_u16(pl["tgt"]); b.put_u16(int(ceil(float(pl["amt"]))))
				b.put_u8((1 if pl["hs"] else 0) | (2 if pl["killed"] else 0) | (4 if pl.get("crit", false) else 0))
				put_pos(b, pl["pos"])
				b.put_u8(int(pl["type"]))
				var d: Vector3 = pl.get("dir", Vector3.ZERO)
				b.put_8(int(clampf(d.x, -1, 1) * 127)); b.put_8(int(clampf(d.y, -1, 1) * 127)); b.put_8(int(clampf(d.z, -1, 1) * 127))
			&"footstep":
				b.put_u8(3)
				b.put_u16(pl["pawn"]); put_pos(b, pl["pos"])
			&"heal":
				b.put_u8(4)
				b.put_16(pl["src"]); b.put_u16(pl["tgt"]); b.put_u16(int(ceil(float(pl["amt"])))); put_pos(b, pl["pos"])
			_:
				b.put_u8(0)
				put_str(b, String(kind))
				put_var(b, pl)
	return b.data_array


static func decode_events(bytes: PackedByteArray) -> Array:
	var out: Array = []
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	if b.get_u8() != MSG_EVENT:
		return out
	var n := b.get_u16()
	for i in n:
		var code := b.get_u8()
		match code:
			1:
				var pawn := b.get_u16(); var slot := b.get_8()
				var origin := get_pos(b)
				var hn := b.get_u8()
				var hits: Array = []
				for j in hn:
					var endp := get_pos(b)
					var hp := b.get_16()
					var part_code := b.get_u8()
					var bits := b.get_u8()
					var nrm := Vector3(b.get_8() / 127.0, b.get_8() / 127.0, b.get_8() / 127.0)
					hits.append({"end": endp, "pawn": hp, "part": &"head" if part_code == 1 else (&"body" if part_code == 2 else &""), "barrier": (bits & 1) != 0, "deployable": (bits & 2) != 0, "normal": nrm, "dir": (endp - origin).normalized()})
				out.append([&"hitscan", {"pawn": pawn, "slot": slot, "origin": origin, "hits": hits}])
			2:
				var src := b.get_16(); var tgt := b.get_u16(); var amt := b.get_u16()
				var bits := b.get_u8()
				var pos := get_pos(b)
				var type := b.get_u8()
				var dir := Vector3(b.get_8() / 127.0, b.get_8() / 127.0, b.get_8() / 127.0)
				out.append([&"damage", {"src": src, "tgt": tgt, "amt": float(amt), "hs": (bits & 1) != 0, "killed": (bits & 2) != 0, "crit": (bits & 4) != 0, "pos": pos, "type": type, "dir": dir}])
			3:
				out.append([&"footstep", {"pawn": b.get_u16(), "pos": get_pos(b)}])
			4:
				out.append([&"heal", {"src": b.get_16(), "tgt": b.get_u16(), "amt": float(b.get_u16()), "pos": get_pos(b)}])
			_:
				var kind := StringName(get_str(b))
				var pl: Variant = get_var(b)
				out.append([kind, pl if pl is Dictionary else {}])
	return out
