class_name GameClient
extends Node
## The client: connects, sends input every tick, predicts the local pawn, reconciles against server
## snapshots, interpolates remote pawns, and forwards events to presentation (ClientWorld).

signal connected
signal disconnected(reason: String)

var net: NetChannel
var peer: ENetMultiplayerPeer
var api: MultiplayerAPI
var world: SimWorld               # client-side world (prediction + presentation)
var presentation: ClientWorld
var player_id: int = 0
var session_token: int = 0
var team: int = RF.Team.A
var my_hero_id: StringName = &""
var local_pawn: Pawn
var local_net_id: int = -1
var connected_ok: bool = false
var ready_sent: bool = false
var server_tick: int = 0          # last known server tick
var tick: int = 0                 # our predicted tick (ahead of server)
var lead_target: int = 3
var last_ack_input_tick: int = 0
var last_snapshot_id: int = 0
var cmd_history: Array[InputCmd] = []       # unacked cmds
var state_history: Dictionary = {}          # tick -> {pos, vel, yaw...} predicted after cmd
var snapshots: Dictionary = {}              # snapshot_id -> decoded state (net_id -> fields)
var snapshot_order: Array[int] = []
var latest_states: Dictionary = {}          # net_id -> fields (from newest snapshot)
var remote_buffer: Dictionary = {}          # net_id -> Array of [server_tick, fields]
var interp_delay_ticks: int = 4
var render_tick_f: float = 0.0
var ping_ms: float = 0.0
var _ping_timer: float = 0.0
var _ping_sent_at: int = 0
var input: InputCollector
var roster: Array = []
var hud_state: Dictionary = {}
var map_id: StringName = &""
var mode_id: StringName = &""
var pending_hero_request: int = -1
var address: String = ""
var port: int = 0
var reconnect_attempts: int = 0
var _connect_timeout: float = 0.0
var stats_in_window: int = 0
var window_time: float = 0.0
var bandwidth_in_kbps: float = 0.0
var reconcile_error: float = 0.0
var reconciles: int = 0
var replay_mode: bool = false
var frozen_by_server: bool = false
var respawn_ticks: int = 0
var spectate_target: int = -1
var lag_sim: LagSimulator


func connect_to(addr: String, p: int) -> void:
	address = addr; port = p
	world = SimWorld.new()
	world.name = "World"
	world.is_server = false
	add_child(world)
	presentation = ClientWorld.new()
	presentation.name = "Presentation"
	add_child(presentation)
	presentation.setup(self)
	world.sim_event.connect(presentation.on_predicted_event)
	input = InputCollector.new()
	input.name = "Input"
	add_child(input)
	net = NetChannel.new()
	add_child(net)
	api = MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(api, get_path())
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(addr, p)
	if err != OK:
		disconnected.emit("cannot create client: %s" % error_string(err))
		App.on_client_disconnected("cannot create client")
		return
	api.multiplayer_peer = peer
	api.connected_to_server.connect(_on_connected)
	api.connection_failed.connect(func() -> void: _fail("connection failed"))
	api.server_disconnected.connect(func() -> void: _fail("server closed"))
	net.snapshot_received.connect(_on_snapshot)
	net.event_received.connect(_on_events)
	net.server_msg_received.connect(_on_server_msg)
	_connect_timeout = 8.0
	lag_sim = LagSimulator.new()
	lag_sim.configure(int(Settings.get_value(&"network", "sim_latency_ms")), float(Settings.get_value(&"network", "sim_packet_loss")), int(Settings.get_value(&"network", "sim_jitter_ms")))
	interp_delay_ticks = maxi(2, int(ceil(float(Settings.get_value(&"network", "interp_delay_ms")) / 1000.0 * RF.TICK_RATE)))
	Console.register("net_stats", "Show network stats", func(_a: PackedStringArray) -> String:
		return "ping %.0f ms | in %.1f KB/s | lead %d | reconciles %d (avg err %.3f m) | interp %d ticks" % [ping_ms, bandwidth_in_kbps, tick - server_tick, reconciles, reconcile_error, interp_delay_ticks])
	Console.register("hero", "hero <id>: select hero", func(a: PackedStringArray) -> String:
		if a.size() < 1: return "usage: hero <id>"
		select_hero(StringName(a[0])); return "requested %s" % a[0])
	Console.register("lag", "lag <ms> [loss 0..1] [jitter ms]: simulate network conditions", func(a: PackedStringArray) -> String:
		var ms := int(a[0]) if a.size() > 0 else 0
		var loss := float(a[1]) if a.size() > 1 else 0.0
		var jit := int(a[2]) if a.size() > 2 else 0
		lag_sim.configure(ms, loss, jit)
		return "lag sim: %d ms, loss %.2f, jitter %d" % [ms, loss, jit])


func shutdown() -> void:
	Console.unregister("net_stats")
	Console.unregister("hero")
	Console.unregister("lag")
	if peer:
		peer.close()
	if api:
		api.multiplayer_peer = null
	connected_ok = false


func _fail(reason: String) -> void:
	connected_ok = false
	disconnected.emit(reason)
	App.on_client_disconnected(reason)


func _on_connected() -> void:
	Console.print_line("Client: connected to %s:%d" % [address, port])
	net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_HELLO, {"name": String(Settings.get_value(&"gameplay", "player_name")), "version": RF.VERSION, "token": session_token}))


func _on_server_msg(bytes: PackedByteArray) -> void:
	var m := NetCodec.decode_msg(bytes)
	var pl: Dictionary = m["payload"]
	match int(m["kind"]):
		NetCodec.MSG_WELCOME:
			player_id = int(pl["player_id"])
			session_token = int(pl["token"])
			team = int(pl["team"])
			map_id = StringName(String(pl["map"]))
			mode_id = StringName(String(pl["mode"]))
			server_tick = int(pl["tick"])
			tick = server_tick + lead_target
			my_hero_id = StringName(String(pl.get("hero", "")))
			var md := Registry.map(map_id)
			if md:
				world.load_map(md)
			presentation.on_map_loaded(md)
			connected_ok = true
			connected.emit()
			net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_READY, {}))
			ready_sent = true
			UIRouter.show(&"hud")
			if my_hero_id == &"":
				UIRouter.show_overlay(&"hero_select")
		NetCodec.MSG_PONG:
			var sent := int(pl.get("t", 0))
			ping_ms = lerpf(ping_ms, float(Time.get_ticks_msec() - sent), 0.3)


func _physics_process(delta: float) -> void:
	if api:
		api.poll()
	if not connected_ok:
		_connect_timeout -= delta
		if _connect_timeout <= 0.0 and _connect_timeout > -100.0:
			_connect_timeout = -1000.0
			_fail("timed out")
		return
	lag_sim.step(delta)
	tick += 1
	world.tick = tick
	_ping_timer += delta
	if _ping_timer >= 1.0:
		_ping_timer = 0.0
		net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_PING, {"t": Time.get_ticks_msec()}))
	window_time += delta
	if window_time >= 1.0:
		bandwidth_in_kbps = (net.bytes_in - stats_in_window) / 1024.0 / window_time
		stats_in_window = net.bytes_in
		window_time = 0.0
	# Build this tick's command.
	var cmd := input.build(tick, local_pawn)
	cmd.ack_snapshot = last_snapshot_id
	cmd.render_tick = maxi(int(floor(render_tick_f)), 0)
	if pending_hero_request >= 0:
		cmd.hero_request = pending_hero_request
		pending_hero_request = -1
	# Predict locally.
	if local_pawn and not replay_mode:
		if frozen_by_server:
			var f := cmd.copy(); f.move = Vector2.ZERO; f.buttons = 0; f.pressed = 0; f.released = 0
			local_pawn.simulate(f, RF.TICK_DT)
		else:
			local_pawn.simulate(cmd, RF.TICK_DT)
		_store_state(tick)
	cmd_history.append(cmd)
	while cmd_history.size() > 128:
		cmd_history.pop_front()
	# Send the last 3 cmds redundantly (packet loss tolerance).
	var to_send: Array[InputCmd] = []
	var start := maxi(cmd_history.size() - 3, 0)
	for i in range(start, cmd_history.size()):
		to_send.append(cmd_history[i])
	var bytes := NetCodec.encode_inputs(to_send)
	lag_sim.send(func() -> void: net.send_input(bytes))
	# Remote interpolation clock.
	render_tick_f = float(server_tick) - interp_delay_ticks
	presentation.physics_tick(tick)


func _process(delta: float) -> void:
	if not connected_ok:
		return
	# Advance the render clock smoothly between snapshots.
	render_tick_f += delta * RF.TICK_RATE
	var target := float(server_tick) - interp_delay_ticks
	if absf(render_tick_f - target) > 6.0:
		render_tick_f = target
	else:
		render_tick_f = lerpf(render_tick_f, target, 0.1)
	presentation.render_frame(delta, render_tick_f)


## --- Prediction state --------------------------------------------------------------------------

func _store_state(t: int) -> void:
	if local_pawn == null:
		return
	state_history[t] = {"pos": local_pawn.global_position, "vel": local_pawn.velocity}
	if state_history.size() > 200:
		var keys := state_history.keys()
		keys.sort()
		for i in range(keys.size() - 128):
			state_history.erase(keys[i])


func _apply_local_authoritative(fields: Dictionary, acked_tick: int) -> void:
	if local_pawn == null or acked_tick <= 0:
		return
	var server_pos := NetCodec.pos_of(fields)
	var server_vel := NetCodec.vel_of(fields)
	var predicted: Dictionary = state_history.get(acked_tick, {})
	var err := 0.0
	if not predicted.is_empty():
		err = (predicted["pos"] as Vector3).distance_to(server_pos)
	_apply_health(local_pawn, fields)
	_apply_flags(local_pawn, fields)
	# Ability state: authoritative cooldowns/ammo from the server, then re-simulate.
	if fields.has("slots"):
		var slots: Array = fields["slots"]
		for s in mini(slots.size(), local_pawn.abilities.slots.size()):
			var ab := local_pawn.abilities.slots[s]
			var sd: Variant = slots[s]
			if ab == null or sd == null:
				continue
			var d: Dictionary = sd
			ab.cooldown_remaining = float(d["cd"])
			ab.charges_left = int(d["charges"])
			ab.ammo = int(d["ammo"])
			ab.reload_remaining = float(d["reload"])
			var st := int(d["state"])
			if st == Ability.State.IDLE and ab.is_active():
				ab.end(true)
			elif st == Ability.State.ACTIVE and ab.state == Ability.State.IDLE and ab.data.trigger != AbilityData.Trigger.HOLD:
				pass  # server started something we didn't predict (rare); visuals follow events
			if ab.state == Ability.State.ACTIVE and float(d["active"]) > 0.0:
				ab.active_remaining = float(d["active"])
		local_pawn.abilities.global_lock_remaining = float(fields.get("global_lock", 0.0))
		local_pawn.movement.move_lock_timer = float(fields.get("move_lock", 0.0))
		local_pawn.movement.jumps_left = int(fields.get("jumps_left", local_pawn.movement.jumps_left))
		local_pawn.movement.hover_fuel = float(fields.get("hover_fuel", local_pawn.movement.hover_fuel))
		local_pawn.movement.speed_override_timer = float(fields.get("speed_override_timer", 0.0))
		local_pawn.movement.speed_override_mult = float(fields.get("speed_override_mult", 1.0))
	if err > 0.02 or predicted.is_empty():
		# Rewind to the server state and replay unacknowledged inputs.
		reconciles += 1
		reconcile_error = lerpf(reconcile_error, err, 0.2)
		local_pawn.global_position = server_pos
		local_pawn.velocity = server_vel
		local_pawn.yaw = NetCodec.yaw_of(fields)
		local_pawn.pitch = NetCodec.pitch_of(fields)
		var saved_tick := world.tick
		for c: InputCmd in cmd_history:
			if c.tick <= acked_tick:
				continue
			world.tick = c.tick
			var replay_cmd := c.copy()
			replay_cmd.pressed = 0     # never re-fire abilities during replay
			replay_cmd.released = 0
			local_pawn.simulate(replay_cmd, RF.TICK_DT)
			_store_state(c.tick)
		world.tick = saved_tick
		if err > 1.5:
			local_pawn.reset_physics_interpolation()
	# Drop acked cmds
	while not cmd_history.is_empty() and cmd_history[0].tick <= acked_tick:
		cmd_history.pop_front()


func _apply_health(p: Pawn, f: Dictionary) -> void:
	if f.has("hp"):
		var h: Vector4i = f["hp"]
		p.health.health = float(h.x); p.health.armor = float(h.y); p.health.shield = float(h.z); p.health.overhealth = float(h.w)
		p.ult_charge = float(f.get("ult", 0)) / 10000.0 * p.ult_cost()
		if p.hero.hero_resource_max > 0.0:
			p.hero_resource = float(f.get("res", 0)) / 10000.0 * p.hero.hero_resource_max


func _apply_flags(p: Pawn, f: Dictionary) -> void:
	if f.has("flags"):
		var fl := int(f["flags"])
		var was_alive := p.alive
		p.alive = (fl & NetCodec.S_ALIVE) != 0
		p.movement.crouching = (fl & NetCodec.S_CROUCH) != 0
		p.on_objective = (fl & NetCodec.S_ON_OBJECTIVE) != 0
		p.movement.hovering = (fl & NetCodec.S_HOVERING) != 0
		p.is_bot = (fl & NetCodec.S_BOT) != 0
		p.set_meta("net_flags", fl)
		if was_alive and not p.alive:
			presentation.on_pawn_died_visual(p)
		elif not was_alive and p.alive:
			presentation.on_pawn_spawned_visual(p)
	if f.has("anim"):
		p.anim_state = int(f["anim"]) & 0xFF
		p.flags_extra = (int(f["anim"]) >> 16) & 0xFF
		p.set_meta("active_slot", ((int(f["anim"]) >> 8) & 0xFF) - 1)


## --- Snapshots ---------------------------------------------------------------------------------

func _on_snapshot(bytes: PackedByteArray) -> void:
	lag_sim.receive(func() -> void: _handle_snapshot(bytes))


func _handle_snapshot(bytes: PackedByteArray) -> void:
	var b := StreamPeerBuffer.new()
	b.data_array = bytes
	if b.get_u8() != NetCodec.MSG_SNAPSHOT:
		return
	var stick := b.get_u32()
	var sid := b.get_u32()
	var baseline_id := b.get_u32()
	var acked_input := b.get_u32()
	var lead := b.get_8()
	var sping := b.get_u16()
	var has_hud := b.get_u8() == 1
	if has_hud:
		hud_state = NetCodec.get_var(b)
		frozen_by_server = int(hud_state.get("phase", 1)) in [ModeController.Phase.ROUND_END, ModeController.Phase.MATCH_END]
		presentation.on_hud_state(hud_state)
	if sid <= last_snapshot_id:
		return   # out of order
	var state: Dictionary = {}
	if baseline_id != 0:
		if not snapshots.has(baseline_id):
			return   # can't decode; wait for a snapshot against a baseline we have (server falls back to full)
		state = (snapshots[baseline_id] as Dictionary).duplicate(true)
	var n := b.get_u8()
	for i in n:
		NetCodec.read_pawn_delta(b, state)
	snapshots[sid] = state
	snapshot_order.append(sid)
	while snapshot_order.size() > 64:
		snapshots.erase(snapshot_order.pop_front())
	last_snapshot_id = sid
	server_tick = maxi(server_tick, stick)
	if sping > 0:
		ping_ms = lerpf(ping_ms, float(sping), 0.2)
	# Clock steering: keep our inputs arriving 2..4 ticks early.
	if lead < 1:
		tick += 2
	elif lead > 6:
		tick -= 1
	# Apply
	for nid: Variant in state.keys():
		var f: Dictionary = state[nid]
		var p := world.get_pawn(int(nid))
		if p == null:
			continue
		if p == local_pawn:
			_apply_local_authoritative(f, acked_input)
		else:
			_apply_health(p, f)
			_apply_flags(p, f)
			var buf: Array = remote_buffer.get(int(nid), [])
			buf.append([stick, f])
			while buf.size() > 30:
				buf.pop_front()
			remote_buffer[int(nid)] = buf
	latest_states = state


## Interpolated transform for a remote pawn at render tick (float). Returns false if no data.
func remote_pose(net_id: int, rt: float, out: Dictionary) -> bool:
	var buf: Array = remote_buffer.get(net_id, [])
	if buf.is_empty():
		return false
	var prev: Array = buf[0]
	var next: Array = buf[buf.size() - 1]
	for i in range(buf.size() - 1):
		var a: Array = buf[i]
		var bb: Array = buf[i + 1]
		if float(a[0]) <= rt and float(bb[0]) >= rt:
			prev = a; next = bb
			break
	var t := 0.0
	var ta := float(prev[0]); var tb := float(next[0])
	if tb > ta:
		t = clampf((rt - ta) / (tb - ta), 0.0, 1.0)
	if rt > tb:
		# Extrapolate briefly using velocity (max 3 ticks).
		var fa: Dictionary = next[1]
		var extra := minf(rt - tb, 3.0) * RF.TICK_DT
		out["pos"] = NetCodec.pos_of(fa) + NetCodec.vel_of(fa) * extra
		out["yaw"] = NetCodec.yaw_of(fa); out["pitch"] = NetCodec.pitch_of(fa)
		out["vel"] = NetCodec.vel_of(fa)
		return true
	var fa: Dictionary = prev[1]; var fb: Dictionary = next[1]
	out["pos"] = NetCodec.pos_of(fa).lerp(NetCodec.pos_of(fb), t)
	out["yaw"] = lerp_angle(NetCodec.yaw_of(fa), NetCodec.yaw_of(fb), t)
	out["pitch"] = lerpf(NetCodec.pitch_of(fa), NetCodec.pitch_of(fb), t)
	out["vel"] = NetCodec.vel_of(fb)
	return true


## --- Events ------------------------------------------------------------------------------------

func _on_events(bytes: PackedByteArray) -> void:
	lag_sim.receive(func() -> void:
		for e: Array in NetCodec.decode_events(bytes):
			_handle_event(e[0], e[1]))


func _handle_event(kind: StringName, pl: Dictionary) -> void:
	match kind:
		&"pawn_spawn":
			_on_pawn_spawn(pl)
		&"pawn_remove":
			var p := world.get_pawn(int(pl["net_id"]))
			if p:
				presentation.on_pawn_removed(p)
				if p == local_pawn:
					local_pawn = null
					local_net_id = -1
				world.remove_pawn(p)
				remote_buffer.erase(int(pl["net_id"]))
		&"roster":
			roster = pl["players"]
			presentation.on_roster(roster)
		&"hero_select":
			UIRouter.show_overlay(&"hero_select")
		&"status":
			var p := world.get_pawn(int(pl["tgt"]))
			if p:
				var sd := StatusLibrary.get_status(StringName(String(pl["id"])))
				if bool(pl["on"]):
					if sd: p.status.apply(sd, world.get_pawn(int(pl.get("src", -1))), float(pl["dur"]))
				else:
					p.status.remove(StringName(String(pl["id"])))
				p.status.step(0.0)
		&"respawn_timer":
			respawn_ticks = int(pl["ticks"])
		&"match_end":
			presentation.on_match_end(pl)
		&"mode_full":
			hud_state = pl
			presentation.on_hud_state(pl)
		_:
			pass
	presentation.on_server_event(kind, pl)


func _on_pawn_spawn(pl: Dictionary) -> void:
	var nid := int(pl["net_id"])
	var hero := Registry.hero(StringName(String(pl["hero"])))
	if hero == null:
		return
	var existing := world.get_pawn(nid)
	if existing:
		presentation.on_pawn_removed(existing)
		world.remove_pawn(existing)
	var p := world.add_pawn(hero, int(pl["team"]), int(pl["player"]), nid)
	p.display_name = String(pl["name"])
	p.is_bot = bool(pl["bot"])
	p.is_local = int(pl["player"]) == player_id
	p.spawn_at(pl["pos"], float(pl["yaw"]))
	if p.is_local:
		local_pawn = p
		local_net_id = nid
		my_hero_id = hero.id
		team = int(pl["team"])
		cmd_history.clear()
		state_history.clear()
		p.collision_mask = RF.L_WORLD | RF.L_DEPLOYABLE | RF.L_PAYLOAD | RF.L_BOUNDARY | RF.barrier_layer(RF.enemy_team(p.team))
		UIRouter.hide_overlay(&"hero_select")
		EventBus.local_pawn_spawned.emit(p)
	else:
		# Remote pawns are driven by interpolation, not physics.
		p.collision_layer = RF.L_PAWN
		p.collision_mask = 0
		p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		remote_buffer.erase(nid)
	presentation.on_pawn_added(p)


func select_hero(id: StringName) -> void:
	net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_CLIENT_CMD, {"cmd": "select_hero", "hero": String(id)}))


func send_chat(text: String, team_only: bool = false) -> void:
	net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_CLIENT_CMD, {"cmd": "chat", "text": text, "team_only": team_only}))


func send_voice_line(line: String) -> void:
	net.send_client_msg(NetCodec.encode_msg(NetCodec.MSG_CLIENT_CMD, {"cmd": "voice_line", "line": line}))
