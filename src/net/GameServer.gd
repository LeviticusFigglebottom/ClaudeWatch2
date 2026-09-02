class_name GameServer
extends Node
## Authoritative match server. Runs the fixed-tick simulation, owns players/bots/mode, and talks to
## clients through NetChannel. Works identically as a dedicated headless process, as the in-process
## host of an offline match, and as the sim-harness driver.

signal match_finished(summary: Dictionary)

var config: MatchConfig
var world: SimWorld
var viewport: SubViewport
var net: NetChannel
var peer: ENetMultiplayerPeer
var api: MultiplayerAPI
var mode: ModeController
var layout: MapLayout
var players: Dictionary = {}          # player id -> PlayerState
var peers: Dictionary = {}            # peer id -> player id
var tick: int = 0
var snapshot_id: int = 0
var running: bool = false
var _next_bot_id: int = -1
var _pending_events: Array = []       # [kind, payload]
var _tick_accum_ms: float = 0.0
var telemetry: MatchTelemetry
var coordinators: Array = [null, null] # TeamCoordinator per team
var bots_dir: Node
var match_summary: Dictionary = {}
var post_match_timer: float = -1.0
var stats_time: float = 0.0
var bytes_out_window: int = 0
var window_time: float = 0.0
var bandwidth_kbps: float = 0.0
var replay: ReplayRecorder
var perf_tick_ms: float = 0.0
var potg: Dictionary = {}
var tactical: TacticalMap


func host(port: int, cfg: MatchConfig) -> void:
	config = cfg
	# Isolated physics/render world for the server so it can share a process with a client.
	viewport = SubViewport.new()
	viewport.name = "ServerViewport"
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(4, 4)
	viewport.physics_object_picking = false
	viewport.gui_disable_input = true
	add_child(viewport)
	world = SimWorld.new()
	world.name = "World"
	world.is_server = true
	viewport.add_child(world)
	world.sim_event.connect(_on_sim_event)
	bots_dir = Node.new()
	bots_dir.name = "Bots"
	add_child(bots_dir)
	# Networking: own MultiplayerAPI for this branch.
	net = NetChannel.new()
	add_child(net)
	api = MultiplayerAPI.create_default_interface()
	get_tree().set_multiplayer(api, get_path())
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, config.max_players + 2)
	if err != OK and not config.sim_mode:
		push_error("GameServer: cannot bind port %d (%s)" % [port, error_string(err)])
		# Try a few alternate ports (local play shouldn't fail because 27015 is busy).
		for p in range(port + 1, port + 20):
			if peer.create_server(p, config.max_players + 2) == OK:
				Console.print_line("Server bound to alternate port %d" % p, Color.YELLOW)
				break
	if config.sim_mode:
		peer = null
	else:
		api.multiplayer_peer = peer
		api.peer_connected.connect(_on_peer_connected)
		api.peer_disconnected.connect(_on_peer_disconnected)
	net.input_received.connect(_on_input)
	net.client_msg_received.connect(_on_client_msg)
	# Map + mode
	var md := Registry.map(config.map_id)
	if md == null:
		push_error("GameServer: unknown map %s" % config.map_id)
		return
	world.load_map(md)
	layout = world.map_root.get_node_or_null("Layout") as MapLayout
	if layout == null:
		push_error("GameServer: map %s has no Layout node" % config.map_id)
		layout = MapLayout.new()
		world.map_root.add_child(layout)
	_spawn_health_packs()
	tactical = TacticalMap.load_or_bake(config.map_id, world, layout)
	var mdata := Registry.mode(config.mode_id)
	if mdata == null:
		mdata = Registry.mode(md.supported_modes[0]) if not md.supported_modes.is_empty() else null
	if mdata == null:
		push_error("GameServer: no mode available")
		return
	config.mode_id = mdata.id
	mode = (mdata.controller_script.new() as ModeController) if mdata.controller_script else ModeController.new()
	mode.name = "Mode"
	add_child(mode)
	mode.setup(self, world, mdata, layout)
	mode.match_ended.connect(_on_match_ended)
	telemetry = MatchTelemetry.new()
	telemetry.setup(self)
	replay = ReplayRecorder.new()
	replay.setup(self)
	for t in RF.TEAM_COUNT:
		var c := TeamCoordinator.new()
		c.name = "Coordinator_%d" % t
		add_child(c)
		c.setup(self, t)
		coordinators[t] = c
	world.sound_listeners.append(_on_world_sound)
	# Bots
	for i in config.bot_count:
		add_bot()
	running = true
	mode.start_match()
	Console.print_line("Server: %s / %s, %d bots" % [config.map_id, config.mode_id, config.bot_count])


func shutdown() -> void:
	running = false
	if peer:
		peer.close()
	if api:
		api.multiplayer_peer = null


func _physics_process(delta: float) -> void:
	if not running:
		return
	var t0 := Time.get_ticks_usec()
	if api and peer:
		api.poll()
	_tick(RF.TICK_DT)
	perf_tick_ms = (Time.get_ticks_usec() - t0) / 1000.0
	window_time += delta
	if window_time >= 1.0:
		bandwidth_kbps = (net.bytes_out - bytes_out_window) / 1024.0 / window_time
		bytes_out_window = net.bytes_out
		window_time = 0.0


## --- Core tick -------------------------------------------------------------------------------

func _tick(dt: float) -> void:
	tick += 1
	world.tick = tick
	# 1. Gather inputs and simulate every pawn.
	for ps: PlayerState in players.values():
		var cmd := _cmd_for(ps)
		ps.last_cmd = cmd
		if ps.pawn:
			if world.frozen:
				var frozen := cmd.copy()
				frozen.move = Vector2.ZERO
				frozen.buttons = 0; frozen.pressed = 0; frozen.released = 0
				ps.pawn.simulate(frozen, dt)
			else:
				ps.pawn.simulate(cmd, dt)
			_check_bounds(ps.pawn)
		_handle_meta_input(ps, cmd)
	# 2. Entities, mode, respawns.
	world.step_entities(dt)
	if mode:
		mode.step(dt)
	_process_respawns()
	for c: Variant in coordinators:
		if c: c.step(dt)
	telemetry.step(dt)
	replay.step(tick)
	if post_match_timer >= 0.0:
		post_match_timer -= dt
		if post_match_timer <= 0.0:
			post_match_timer = -1.0
			_after_match()
	# 3. Network out.
	if tick % RF.SNAPSHOT_EVERY_N_TICKS == 0:
		_send_snapshots()
	_flush_events()
	if config.bot_fill and tick % 120 == 0:
		_backfill()


func _cmd_for(ps: PlayerState) -> InputCmd:
	if ps.is_bot:
		if ps.bot and ps.pawn:
			var c: InputCmd = ps.bot.think(RF.TICK_DT, tick)
			c.tick = tick
			return c
		return InputCmd.empty(tick)
	# Human: exact tick if present, else the newest older cmd with edges cleared.
	if ps.input_queue.has(tick):
		var c: InputCmd = ps.input_queue[tick]
		ps.last_input_tick = tick
		# Drop older
		for k: int in ps.input_queue.keys():
			if k <= tick:
				ps.input_queue.erase(k)
		return c
	ps.missed_inputs += 1
	var c := ps.last_cmd.copy()
	c.pressed = 0; c.released = 0; c.tick = tick
	c.hero_request = -1
	return c


func _handle_meta_input(ps: PlayerState, cmd: InputCmd) -> void:
	if cmd.hero_request >= 0 and not ps.is_bot:
		var h := Registry.hero_from_index(cmd.hero_request)
		if h:
			request_hero(ps, h.id)
	if cmd.just_pressed(RF.BTN_PING) and ps.pawn and ps.pawn.alive:
		var res := world.hitscan(ps.pawn.eye_position(), ps.pawn.aim_dir(), 120.0, ps.pawn, cmd.render_tick)
		broadcast_event(&"ping", {"player": ps.id, "team": ps.team, "pos": res.point, "pawn": res.pawn.net_id if res.pawn else -1}, ps.team)
	if cmd.just_pressed(RF.BTN_INTERACT) and ps.pawn and ps.pawn.alive and mode and mode.in_own_spawn(ps.pawn):
		pass  # hero select is opened client-side; server accepts hero_request


func _check_bounds(p: Pawn) -> void:
	if not p.alive:
		return
	if p.global_position.y < layout.kill_z:
		var ev := DamageEvent.new()
		ev.source = p.last_damage_source if (tick - p.last_damage_source_tick) < 240 else null
		ev.target = p; ev.amount = 99999.0; ev.type = RF.DamageType.ENVIRONMENT
		ev.ability_id = &"environment"; ev.position = p.global_position
		if ev.source == null:
			ev.source = p
		world.apply_damage(ev)


## --- Players ---------------------------------------------------------------------------------

func add_bot(team: int = -1, hero_id: StringName = &"") -> PlayerState:
	var ps := PlayerState.new()
	ps.id = _next_bot_id
	_next_bot_id -= 1
	ps.is_bot = true
	ps.name = BotNames.pick(ps.id)
	ps.team = team if team >= 0 else _least_populated_team()
	ps.connected = true
	ps.ready = true
	players[ps.id] = ps
	var bot := BotController.new()
	bot.name = "Bot_%d" % absi(ps.id)
	bots_dir.add_child(bot)
	bot.setup(self, ps, config.bot_difficulty)
	ps.bot = bot
	var hid := hero_id
	if hid == &"":
		hid = coordinators[ps.team].pick_hero_for(ps) if coordinators[ps.team] else Registry.hero_ids()[0]
	ps.hero_id = hid
	_spawn_player(ps)
	_send_roster()
	return ps


func remove_player(ps: PlayerState) -> void:
	if ps.pawn:
		broadcast_event(&"pawn_remove", {"net_id": ps.pawn.net_id})
		world.remove_pawn(ps.pawn)
		ps.pawn = null
	if ps.bot:
		ps.bot.queue_free()
	players.erase(ps.id)
	if ps.peer != 0:
		peers.erase(ps.peer)
	_send_roster()


func _least_populated_team() -> int:
	var counts := _team_counts()
	if counts[0] == counts[1]:
		return RF.Team.A if _human_count(RF.Team.A) <= _human_count(RF.Team.B) else RF.Team.B
	return RF.Team.A if counts[0] < counts[1] else RF.Team.B


func _team_counts() -> Array[int]:
	var c: Array[int] = [0, 0]
	for ps: PlayerState in players.values():
		if ps.connected:
			c[ps.team] += 1
	return c


func _human_count(team: int) -> int:
	var n := 0
	for ps: PlayerState in players.values():
		if not ps.is_bot and ps.team == team and ps.connected:
			n += 1
	return n


func team_players(team: int) -> Array[PlayerState]:
	var out: Array[PlayerState] = []
	for ps: PlayerState in players.values():
		if ps.team == team and ps.connected:
			out.append(ps)
	return out


func _backfill() -> void:
	var counts := _team_counts()
	for t in RF.TEAM_COUNT:
		while counts[t] < config.team_size:
			add_bot(t)
			counts[t] += 1
	# Remove a bot when a human joined and a team is over-full.
	for t in RF.TEAM_COUNT:
		while counts[t] > config.team_size:
			var victim: PlayerState = null
			for ps: PlayerState in players.values():
				if ps.is_bot and ps.team == t:
					victim = ps
					break
			if victim == null:
				break
			remove_player(victim)
			counts[t] -= 1


func _spawn_player(ps: PlayerState) -> void:
	var hero := Registry.hero(ps.hero_id)
	if hero == null:
		return
	if ps.pawn:
		broadcast_event(&"pawn_remove", {"net_id": ps.pawn.net_id})
		world.remove_pawn(ps.pawn)
	var p := world.add_pawn(hero, ps.team, ps.id)
	p.display_name = ps.name
	p.is_bot = ps.is_bot
	p.stats = ps.stats
	ps.pawn = p
	if ps.bot:
		ps.bot.attach_pawn(p)
	var xf := mode.spawn_transform(ps.team) if mode else Transform3D()
	p.spawn_at(xf.origin, xf.basis.get_euler().y)
	p.ult_charge = ps.ult_charge_carry
	ps.hero_time_start_tick = tick
	broadcast_event(&"pawn_spawn", {"net_id": p.net_id, "player": ps.id, "hero": hero.id, "team": ps.team,
		"name": ps.name, "bot": ps.is_bot, "pos": p.global_position, "yaw": p.yaw})


func request_hero(ps: PlayerState, hero_id: StringName) -> void:
	var hero := Registry.hero(hero_id)
	if hero == null or hero_id == ps.hero_id and ps.pawn and ps.pawn.alive:
		return
	if not config.allow_hero_duplicates and Registry.heroes.size() >= 8:
		for other: PlayerState in team_players(ps.team):
			if other != ps and other.hero_id == hero_id:
				send_event_to(ps, &"notice", {"text": "%s is already on your team" % hero.display_name})
				return
	# Role limits (5v5: 1/2/2) apply only when the team is full-size.
	var role_count := 0
	for other: PlayerState in team_players(ps.team):
		if other != ps:
			var oh := Registry.hero(other.hero_id)
			if oh and oh.role == hero.role:
				role_count += 1
	if role_count >= RF.ROLE_LIMIT[hero.role]:
		send_event_to(ps, &"notice", {"text": "Your team already has enough %ss" % RF.role_name(hero.role)})
		return
	var can_swap_now := ps.pawn == null or not ps.pawn.alive or (mode and mode.in_own_spawn(ps.pawn)) or (mode and mode.phase == ModeController.Phase.SETUP)
	if can_swap_now:
		ps.hero_id = hero_id
		ps.pending_hero_id = &""
		ps.ult_charge_carry = 0.0
		if ps.pawn == null or ps.pawn.alive:
			_spawn_player(ps)
		else:
			# Dead: spawn with the new hero when the timer ends.
			pass
	else:
		ps.pending_hero_id = hero_id
		send_event_to(ps, &"notice", {"text": "Swapping to %s at next respawn" % hero.display_name})
	_send_roster()


func respawn_everyone() -> void:
	for ps: PlayerState in players.values():
		ps.respawn_at_tick = -1
		if ps.hero_id == &"":
			continue
		_spawn_player(ps)


func _process_respawns() -> void:
	for ps: PlayerState in players.values():
		if ps.pawn == null or ps.pawn.alive:
			continue
		if ps.respawn_at_tick < 0:
			var rt := mode.respawn_time(ps.team) if mode else world.tuning.respawn_time
			ps.respawn_at_tick = tick + int(rt / RF.TICK_DT)
			ps.ult_charge_carry = ps.pawn.ult_charge
			# Respawn waves: join a teammate's wave if they're spawning within the window.
			var window := int(world.tuning.respawn_wave_window / RF.TICK_DT)
			for other: PlayerState in team_players(ps.team):
				if other != ps and other.pawn and not other.pawn.alive and other.respawn_at_tick > tick:
					if ps.respawn_at_tick - other.respawn_at_tick <= window and other.respawn_at_tick > tick + 60:
						ps.respawn_at_tick = other.respawn_at_tick
			send_event_to(ps, &"respawn_timer", {"ticks": ps.respawn_at_tick - tick})
		elif tick >= ps.respawn_at_tick and mode and mode.phase != ModeController.Phase.MATCH_END:
			ps.respawn_at_tick = -1
			if ps.pending_hero_id != &"":
				ps.hero_id = ps.pending_hero_id
				ps.pending_hero_id = &""
				ps.ult_charge_carry = 0.0
			_spawn_player(ps)


## --- Networking: connections --------------------------------------------------------------

func _on_peer_connected(id: int) -> void:
	Console.print_line("Server: peer %d connected" % id)


func _on_peer_disconnected(id: int) -> void:
	Console.print_line("Server: peer %d disconnected" % id)
	if peers.has(id):
		var ps: PlayerState = players[peers[id]]
		ps.connected = false
		ps.peer = 0
		peers.erase(id)
		# Keep the record for 60 s so a reconnect resumes; a bot takes the pawn meanwhile.
		if ps.pawn:
			ps.pawn.is_bot = true
			var bot := BotController.new()
			bot.name = "Standin_%d" % ps.id
			bots_dir.add_child(bot)
			bot.setup(self, ps, config.bot_difficulty)
			bot.attach_pawn(ps.pawn)
			ps.bot = bot
			ps.is_bot = true
			ps.name = ps.name + " (bot)"
		_send_roster()
		get_tree().create_timer(60.0).timeout.connect(func() -> void:
			if players.has(ps.id) and not ps.connected:
				remove_player(ps))


func _on_client_msg(peer_id: int, bytes: PackedByteArray) -> void:
	var m := NetCodec.decode_msg(bytes)
	var pl: Dictionary = m["payload"]
	match int(m["kind"]):
		NetCodec.MSG_HELLO:
			_handle_hello(peer_id, pl)
		NetCodec.MSG_READY:
			if peers.has(peer_id):
				var ps: PlayerState = players[peers[peer_id]]
				ps.ready = true
				_send_full_state(ps)
		NetCodec.MSG_PING:
			net.send_server_msg(peer_id, NetCodec.encode_msg(NetCodec.MSG_PONG, {"t": pl.get("t", 0), "tick": tick}))
		NetCodec.MSG_CLIENT_CMD:
			if peers.has(peer_id):
				_handle_client_cmd(players[peers[peer_id]], pl)


func _handle_hello(peer_id: int, pl: Dictionary) -> void:
	var token := int(pl.get("token", 0))
	var ps: PlayerState = null
	if token != 0:
		for cand: PlayerState in players.values():
			if cand.session_token == token and not cand.connected:
				ps = cand
				break
	if ps == null:
		ps = PlayerState.new()
		ps.id = peer_id
		ps.session_token = randi() | 1
		ps.name = String(pl.get("name", "Runner")).left(20)
		ps.team = _least_populated_team()
		if config.human_team >= 0 and _human_count(config.human_team) < config.team_size:
			ps.team = config.human_team
		players[ps.id] = ps
		# A human joining replaces a bot on their team if the team is full.
		var counts := _team_counts()
		if counts[ps.team] > config.team_size:
			for other: PlayerState in players.values():
				if other.is_bot and other.team == ps.team:
					remove_player(other)
					break
	else:
		# Reconnect: hand the pawn back from the stand-in bot.
		if ps.bot:
			ps.bot.queue_free()
			ps.bot = null
		ps.is_bot = false
		ps.name = ps.name.trim_suffix(" (bot)")
		if ps.pawn:
			ps.pawn.is_bot = false
	ps.peer = peer_id
	ps.connected = true
	ps.ready = false
	ps.join_tick = tick
	ps.input_queue.clear()
	peers[peer_id] = ps.id
	net.send_server_msg(peer_id, NetCodec.encode_msg(NetCodec.MSG_WELCOME, {
		"player_id": ps.id, "token": ps.session_token, "team": ps.team, "map": config.map_id, "mode": config.mode_id,
		"tick": tick, "config": config.to_dict(), "hero": ps.hero_id,
	}))
	_send_roster()
	Console.print_line("Server: %s joined team %s" % [ps.name, RF.team_name(ps.team)])


func _handle_client_cmd(ps: PlayerState, pl: Dictionary) -> void:
	match String(pl.get("cmd", "")):
		"select_hero":
			request_hero(ps, StringName(String(pl.get("hero", ""))))
		"chat":
			broadcast_event(&"chat", {"player": ps.id, "name": ps.name, "team": ps.team, "text": String(pl.get("text", "")).left(200)}, ps.team if pl.get("team_only", false) else -1)
		"voice_line":
			broadcast_event(&"voice_line", {"player": ps.id, "pawn": ps.pawn.net_id if ps.pawn else -1, "line": pl.get("line", "")})
		"request_team":
			pass
		"set_name":
			ps.name = String(pl.get("name", ps.name)).left(20)
			if ps.pawn: ps.pawn.display_name = ps.name
			_send_roster()


func _on_input(peer_id: int, bytes: PackedByteArray) -> void:
	if not peers.has(peer_id):
		return
	var ps: PlayerState = players[peers[peer_id]]
	var cmds := NetCodec.decode_inputs(bytes)
	for c: InputCmd in cmds:
		if c.tick <= tick:
			continue     # too late; the tick already ran
		if c.tick > tick + 32:
			continue     # absurdly early; ignore
		if not ps.input_queue.has(c.tick):
			ps.input_queue[c.tick] = c
		ps.acked_snapshot = maxi(ps.acked_snapshot, c.ack_snapshot)
	if not cmds.is_empty():
		var lead := cmds[cmds.size() - 1].tick - tick
		ps.input_lead_accum += lead
		ps.input_lead_count += 1


## --- Networking: outbound --------------------------------------------------------------------

func _send_roster() -> void:
	var rows: Array = []
	for ps: PlayerState in players.values():
		rows.append({"id": ps.id, "name": ps.name, "team": ps.team, "hero": ps.hero_id, "bot": ps.is_bot, "connected": ps.connected,
			"net_id": ps.pawn.net_id if ps.pawn else -1, "ping": int(ps.ping_ms)})
	broadcast_event(&"roster", {"players": rows})


func _send_full_state(ps: PlayerState) -> void:
	for other: PlayerState in players.values():
		if other.pawn:
			send_event_to(ps, &"pawn_spawn", {"net_id": other.pawn.net_id, "player": other.id, "hero": other.hero_id, "team": other.team,
				"name": other.name, "bot": other.is_bot, "pos": other.pawn.global_position, "yaw": other.pawn.yaw})
			for st: StatusInstance in other.pawn.status.active:
				send_event_to(ps, &"status", {"tgt": other.pawn.net_id, "id": st.data.id, "on": true, "dur": st.remaining, "src": -1})
	for d: Deployable in world.deployables.values():
		send_event_to(ps, &"deployable_spawn", {"id": d.id, "kind": d.kind, "pos": d.global_position, "facing": d.facing,
			"owner": d.owner_pawn.net_id if d.owner_pawn else -1, "team": d.team, "hp": d.health, "max_hp": d.max_health, "visual": d.visual_id, "data": d.data})
	send_event_to(ps, &"mode_full", mode.hud_state() if mode else {})
	if ps.hero_id == &"":
		send_event_to(ps, &"hero_select", {"reason": "join"})
	elif ps.pawn == null:
		_spawn_player(ps)
	ps.sent_baselines.clear()
	ps.baseline_order.clear()


func _send_snapshots() -> void:
	if peer == null:
		return
	snapshot_id += 1
	var captured: Dictionary = {}
	for p: Pawn in world.pawns.values():
		captured[p.net_id] = NetCodec.capture_pawn(p, tick)
	var hud: Dictionary = mode.hud_state() if mode else {}
	var send_hud := snapshot_id % 3 == 0
	for ps: PlayerState in players.values():
		if ps.is_bot or ps.peer == 0 or not ps.ready:
			continue
		var b := StreamPeerBuffer.new()
		b.put_u8(NetCodec.MSG_SNAPSHOT)
		b.put_u32(tick)
		b.put_u32(snapshot_id)
		var baseline: Dictionary = ps.sent_baselines.get(ps.acked_snapshot, {})
		var baseline_id := ps.acked_snapshot if not baseline.is_empty() else 0
		b.put_u32(baseline_id)
		b.put_u32(ps.last_input_tick if ps.last_input_tick >= 0 else 0)
		var lead := 0
		if ps.input_lead_count > 0:
			lead = int(round(float(ps.input_lead_accum) / ps.input_lead_count))
			ps.input_lead_accum = 0; ps.input_lead_count = 0
		b.put_8(clampi(lead, -100, 100))
		b.put_u16(int(ps.ping_ms))
		b.put_u8(1 if send_hud else 0)
		if send_hud:
			NetCodec.put_var(b, hud)
		# Pawn deltas with interest tiering: far & unseen pawns update at 1/3 rate.
		var my_pawn := ps.pawn
		var count_pos := b.get_position()
		b.put_u8(0)
		var n := 0
		var sent_fields: Dictionary = {}
		for p: Pawn in world.pawns.values():
			var cur: Dictionary = captured[p.net_id]
			var is_local := p == my_pawn
			var base: Dictionary = baseline.get(p.net_id, {})
			if not is_local and my_pawn and baseline_id != 0 and (snapshot_id + p.net_id) % 3 != 0:
				var far := p.global_position.distance_to(my_pawn.global_position) > 45.0
				if far and not p.alive:
					sent_fields[p.net_id] = base
					continue
				if far and p.team != ps.team and not world.pawn_visible_from(my_pawn.eye_position(), p):
					sent_fields[p.net_id] = base
					continue
			var wrote := NetCodec.write_pawn_delta(b, p.net_id, cur, base, p, is_local)
			if wrote > 0:
				n += 1
			sent_fields[p.net_id] = cur
		var end_pos := b.get_position()
		b.seek(count_pos)
		b.put_u8(n)
		b.seek(end_pos)
		ps.sent_baselines[snapshot_id] = sent_fields
		ps.baseline_order.append(snapshot_id)
		while ps.baseline_order.size() > 40:
			ps.sent_baselines.erase(ps.baseline_order.pop_front())
		net.send_snapshot(ps.peer, b.data_array)
		ps.bytes_sent += b.data_array.size()


func _on_sim_event(kind: StringName, payload: Dictionary) -> void:
	_pending_events.append([kind, payload])
	telemetry.on_event(kind, payload)
	replay.on_event(kind, payload)
	for c: Variant in coordinators:
		if c: c.on_event(kind, payload)
	if kind == &"kill" and mode:
		var v := world.get_pawn(int(payload["victim"]))
		var k := world.get_pawn(int(payload["killer"]))
		mode.on_pawn_killed(v, k)
		for ps: PlayerState in players.values():
			if ps.pawn == v and ps.bot:
				ps.bot.on_died()


func broadcast_event(kind: StringName, payload: Dictionary, team: int = -1) -> void:
	if team >= 0:
		payload["_team"] = team
	_pending_events.append([kind, payload])


func send_event_to(ps: PlayerState, kind: StringName, payload: Dictionary) -> void:
	payload["_to"] = ps.id
	_pending_events.append([kind, payload])


func _relevant(ps: PlayerState, kind: StringName, pl: Dictionary) -> bool:
	if pl.has("_to"):
		return int(pl["_to"]) == ps.id
	if pl.has("_team") and int(pl["_team"]) != ps.team:
		return false
	var my := ps.pawn
	match kind:
		&"damage":
			return my != null and (int(pl["src"]) == my.net_id or int(pl["tgt"]) == my.net_id)
		&"heal":
			return my != null and (int(pl["src"]) == my.net_id or int(pl["tgt"]) == my.net_id)
		&"footstep":
			return my != null and my.global_position.distance_to(pl["pos"]) < 28.0 and int(pl["pawn"]) != my.net_id
		&"hitscan", &"melee", &"beam", &"beam_segments", &"area", &"projectile_impact", &"projectile_bounce", &"projectile_expire", &"projectile_stuck", &"sound", &"teleport", &"chain_arc", &"cadence_beat", &"zipline", &"hero_fx":
			if my == null:
				return true
			var pos: Vector3 = pl.get("pos", pl.get("origin", pl.get("end", my.global_position)))
			var involved := int(pl.get("pawn", -2)) == my.net_id or int(pl.get("tgt", -2)) == my.net_id
			return involved or my.global_position.distance_to(pos) < 90.0
	return true


func _flush_events() -> void:
	if _pending_events.is_empty():
		return
	if peer != null:
		for ps: PlayerState in players.values():
			if ps.is_bot or ps.peer == 0:
				continue
			var mine: Array = []
			for e: Array in _pending_events:
				if _relevant(ps, e[0], e[1]):
					mine.append(e)
			if mine.is_empty():
				continue
			var bytes := NetCodec.encode_events(mine)
			net.send_event(ps.peer, bytes)
			ps.bytes_sent += bytes.size()
	_pending_events.clear()


func _on_world_sound(_p: Pawn, _kind: StringName, _loud: float, _pos: Vector3) -> void:
	pass  # bots subscribe themselves via world.sound_listeners


func on_mode_phase(_p: int) -> void:
	broadcast_event(&"mode_full", mode.hud_state())


func _on_match_ended(winner: int, summary: Dictionary) -> void:
	match_summary = summary
	match_summary["stats"] = _stats_rows()
	match_summary["potg"] = replay.best_play()
	telemetry.finish(match_summary)
	broadcast_event(&"match_end", match_summary)
	post_match_timer = 20.0 if not config.sim_mode else 0.5
	match_finished.emit(match_summary)


func _stats_rows() -> Array:
	var rows: Array = []
	for ps: PlayerState in players.values():
		var d := ps.stats.to_dict()
		d["id"] = ps.id; d["name"] = ps.name; d["team"] = ps.team; d["hero"] = ps.hero_id; d["bot"] = ps.is_bot
		rows.append(d)
	return rows


func _after_match() -> void:
	if config.sim_mode:
		running = false
		return
	# Rotate to another map for the same mode (dedicated) or stay (local: client decides).
	if not config.local:
		var options := Registry.maps_for_mode(config.mode_id)
		if options.size() > 1:
			var next := options[(options.find(Registry.map(config.map_id)) + 1) % options.size()]
			config.map_id = next.id
		# Simplest robust rotation: restart the whole server object.
		var port := peer.host.get_local_port() if peer and peer.host else int(Settings.get_value(&"network", "port"))
		var cfg := config
		var parent := get_parent()
		shutdown()
		queue_free()
		var s := GameServer.new()
		s.name = "Server"
		parent.add_child(s)
		s.host(port, cfg)
		if App.server == self:
			App.server = s


func _spawn_health_packs() -> void:
	for hp: Dictionary in layout.health_packs:
		var pk := HealthPack.new()
		pk.large = bool(hp["large"])
		pk.world = world
		world.add_child(pk)
		pk.global_position = hp["pos"]
		world.pickups.append(pk)


## Called by modes when spawn rooms change (checkpoint / capture): nothing to do now, respawns read the mode.
func respawn_pending_positions_changed() -> void:
	pass


func scoreboard_rows() -> Array:
	return _stats_rows()


func player_for_pawn(p: Pawn) -> PlayerState:
	for ps: PlayerState in players.values():
		if ps.pawn == p:
			return ps
	return null
