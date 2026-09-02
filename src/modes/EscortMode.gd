class_name EscortMode
extends ModeController
## Escort: attackers push a payload along a Curve3D through checkpoints to the end within the time
## limit. Defenders stop it. Payload moves when attackers are within 3 m (up to 3 pushers speed
## bonus), is contested when a defender is also near, and rolls back after 10 s untouched.
## Reaching a checkpoint adds time. Round 2 swaps sides; the team that pushed farther (or faster) wins.

var payload: Payload
var progress: float = 0.0            # meters along the path
var path_length: float = 0.0
var reverse_timer: float = 0.0
var checkpoint_index: int = 0
var distance_results: Array[float] = [0.0, 0.0]
var time_results: Array[float] = [0.0, 0.0]
var completed: Array[bool] = [false, false]
var pushers: int = 0
var contested: bool = false
var target_progress_to_beat: float = -1.0


func on_setup() -> void:
	data.symmetric = false


func on_round_begin() -> void:
	if payload == null:
		payload = Payload.new()
		payload.name = "Payload"
		world.add_child(payload)
		payload.setup(world, layout.payload_path)
	path_length = layout.payload_path.get_baked_length() if layout.payload_path else 0.0
	progress = 0.0
	checkpoint_index = 0
	reverse_timer = 0.0
	payload.team = attacking_team
	payload.set_progress(0.0)
	time_remaining = data.round_time
	if round_index == 1 and not completed[RF.enemy_team(attacking_team)]:
		target_progress_to_beat = distance_results[RF.enemy_team(attacking_team)]
	else:
		target_progress_to_beat = -1.0


func objective_position() -> Vector3:
	return payload.global_position if payload else Vector3.ZERO


func spawn_phase_for(team: int) -> int:
	# Attackers spawn forward after checkpoints; defenders fall back.
	return checkpoint_index


func update_contest() -> void:
	contest_count = [0, 0]
	if payload == null:
		return
	for p: Pawn in world.pawns.values():
		p.on_objective = false
		if not p.alive:
			continue
		if p.global_position.distance_to(payload.global_position) <= 3.2 and absf(p.global_position.y - payload.global_position.y) < 3.0:
			contest_count[p.team] += 1
			p.on_objective = true


func step_objective(dt: float) -> void:
	pushers = mini(contest_count[attacking_team], 3)
	var defenders := contest_count[defending_team()]
	contested = pushers > 0 and defenders > 0
	if phase == Phase.LIVE:
		time_remaining -= dt
	if pushers > 0 and defenders == 0:
		var speed: float = [0.0, data.payload_speed, data.payload_speed_2, data.payload_speed_3][pushers]
		# Healing aura for attackers near the payload is applied by Payload node itself.
		progress = minf(progress + speed * dt, path_length)
		reverse_timer = 0.0
		# Checkpoint
		if checkpoint_index < layout.payload_checkpoints.size() and progress >= layout.payload_checkpoints[checkpoint_index]:
			checkpoint_index += 1
			time_remaining += data.time_per_checkpoint
			announce(&"checkpoint", {"index": checkpoint_index})
		if progress >= path_length - 0.05:
			completed[attacking_team] = true
			distance_results[attacking_team] = path_length
			time_results[attacking_team] = time_remaining
			score[attacking_team] = checkpoint_index + 1
			end_round(attacking_team, &"payload_delivered")
			return
		# Round 2: beat the distance
		if target_progress_to_beat >= 0.0 and progress > target_progress_to_beat + 0.01:
			distance_results[attacking_team] = progress
			end_round(attacking_team, &"distance_beaten")
			return
	elif pushers == 0:
		# Rollback after delay, but never behind the last checkpoint.
		reverse_timer += dt
		if reverse_timer >= data.payload_reverse_delay:
			var floor_p := layout.payload_checkpoints[checkpoint_index - 1] if checkpoint_index > 0 else 0.0
			progress = maxf(progress - data.payload_reverse_speed * dt, floor_p)
	payload.set_progress(progress)
	# Overtime: time is up but attackers touch the payload.
	if time_remaining <= 0.0:
		if pushers > 0:
			overtime_active = true
		if handle_overtime(dt, pushers > 0):
			pass
		elif not overtime_active:
			distance_results[attacking_team] = progress
			end_round(defending_team(), &"time_expired")
			return
	distance_results[attacking_team] = maxf(distance_results[attacking_team], progress)


func on_round_end(_w: int) -> void:
	pass


func decided() -> bool:
	return false


func compute_winner() -> int:
	if completed[0] and completed[1]:
		return RF.Team.A if time_results[0] > time_results[1] else (RF.Team.B if time_results[1] > time_results[0] else -1)
	if completed[0]: return RF.Team.A
	if completed[1]: return RF.Team.B
	if absf(distance_results[0] - distance_results[1]) < 0.5:
		return -1
	return RF.Team.A if distance_results[0] > distance_results[1] else RF.Team.B


func respawn_time(team: int) -> float:
	var base := data.respawn_time_attack if is_attacker(team) else data.respawn_time_defend
	# Defenders near the end of the map spawn a touch slower to reward pushes (spawn advantage balance).
	if not is_attacker(team) and progress > path_length * 0.85:
		base += 2.0
	return base * server.config.respawn_scale


func hud_state() -> Dictionary:
	var d := super.hud_state()
	d["kind"] = "escort"
	d["payload_progress"] = 0.0 if path_length <= 0.0 else progress / path_length
	var cps: Array = []
	for c: float in layout.payload_checkpoints:
		cps.append(c / maxf(path_length, 1.0))
	d["checkpoints"] = cps
	d["pushers"] = pushers
	d["contested"] = contested
	d["to_beat"] = -1.0 if target_progress_to_beat < 0.0 else target_progress_to_beat / maxf(path_length, 1.0)
	return d


class Payload extends Node3D:
	var world: SimWorld
	var path: Curve3D
	var team: int = 0
	var body: StaticBody3D
	var heal_accum: float = 0.0
	var speed_visual: float = 0.0
	func setup(w: SimWorld, curve: Curve3D) -> void:
		world = w
		path = curve
		body = StaticBody3D.new()
		body.collision_layer = RF.L_PAYLOAD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.2, 1.6, 3.2)
		cs.shape = bs
		cs.position.y = 0.8
		body.add_child(cs)
		add_child(body)
		if w.is_server:
			set_meta("payload", true)
		else:
			_build_visual()
	func set_progress(meters: float) -> void:
		if path == null:
			return
		var pos := path.sample_baked(meters, true)
		var ahead := path.sample_baked(minf(meters + 1.0, path.get_baked_length()), true)
		global_position = pos
		var d := ahead - pos
		d.y = 0
		if d.length_squared() > 0.001:
			look_at(global_position + d.normalized(), Vector3.UP)
		if world and world.is_server:
			_heal_attackers()
	func _heal_attackers() -> void:
		# 10 hp/s to attackers within 3.5 m, once per tick chunked at 10 Hz.
		heal_accum += RF.TICK_DT
		if heal_accum < 0.1:
			return
		heal_accum = 0.0
		for p: Pawn in world.pawns_in_radius(global_position + Vector3(0, 1, 0), 3.5, team):
			if p.health.missing() > 0.0:
				world.apply_heal(null, p, 1.0, &"payload")
	func _build_visual() -> void:
		var v := PayloadVisual.new()
		add_child(v)
		v.build(team)


class PayloadVisual extends Node3D:
	var lights: Array[OmniLight3D] = []
	var t: float = 0.0
	var core: MeshInstance3D
	func build(team: int) -> void:
		var col := RF.team_color(team)
		var chassis := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(2.0, 0.6, 3.0)
		chassis.mesh = bm
		var cm := StandardMaterial3D.new(); cm.albedo_color = Color(0.22, 0.24, 0.27); cm.metallic = 0.7; cm.roughness = 0.35
		chassis.material_override = cm
		chassis.position.y = 0.5
		add_child(chassis)
		for x: float in [-0.85, 0.85]:
			for z: float in [-1.0, 1.0]:
				var wheel := MeshInstance3D.new()
				var cyl := CylinderMesh.new(); cyl.top_radius = 0.32; cyl.bottom_radius = 0.32; cyl.height = 0.25
				wheel.mesh = cyl
				var wm := StandardMaterial3D.new(); wm.albedo_color = Color(0.08, 0.08, 0.09); wm.roughness = 0.9
				wheel.material_override = wm
				wheel.position = Vector3(x, 0.32, z)
				wheel.rotation.z = PI * 0.5
				add_child(wheel)
		var cage := MeshInstance3D.new()
		var cb := BoxMesh.new(); cb.size = Vector3(1.6, 1.0, 1.6)
		cage.mesh = cb
		var cgm := StandardMaterial3D.new(); cgm.albedo_color = Color(0.5, 0.5, 0.55, 0.35); cgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; cgm.metallic = 0.8; cgm.roughness = 0.2
		cage.material_override = cgm
		cage.position.y = 1.3
		add_child(cage)
		core = MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.38; sm.height = 0.76
		core.mesh = sm
		var em := StandardMaterial3D.new(); em.albedo_color = col; em.emission_enabled = true; em.emission = col; em.emission_energy_multiplier = 3.0
		core.material_override = em
		core.position.y = 1.3
		add_child(core)
		var l := OmniLight3D.new(); l.light_color = col; l.light_energy = 2.5; l.omni_range = 7.0; l.position.y = 1.5
		add_child(l)
		lights.append(l)
		for s: float in [-1.0, 1.0]:
			var strip := MeshInstance3D.new()
			var sb := BoxMesh.new(); sb.size = Vector3(0.05, 0.08, 2.6)
			strip.mesh = sb
			strip.material_override = em
			strip.position = Vector3(s * 1.02, 0.7, 0)
			add_child(strip)
	func _process(delta: float) -> void:
		t += delta
		if core:
			core.rotation.y += delta * 0.8
			core.position.y = 1.3 + sin(t * 2.0) * 0.06
		for l: OmniLight3D in lights:
			l.light_energy = 2.2 + sin(t * 3.0) * 0.5
