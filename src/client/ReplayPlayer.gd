class_name ReplayPlayer
extends Node
## Plays a recorded highlight (frames + events from ReplayRecorder) through the presentation layer:
## spawns ghost visuals for every recorded pawn, drives their poses at 20 Hz interpolated, and fires
## recorded events (tracers, impacts, kills) at the right times. Camera = the featured player's POV.

var presentation: ClientWorld
var data: Dictionary = {}
var frames: Array = []
var events: Array = []
var start_tick: int = 0
var end_tick: int = 0
var t: float = 0.0
var playing: bool = false
var ghosts: Dictionary = {}          # net_id -> {node: Node3D, rig: HeroRig, hero: HeroData}
var featured_id: int = -1
var camera: Camera3D
var event_index: int = 0
var speed: float = 1.0
var finished_callback: Callable
var frame_index: int = 0


func setup(p: ClientWorld, d: Dictionary) -> void:
	presentation = p
	data = d
	frames = d.get("frames", [])
	events = d.get("events", [])
	start_tick = int(d.get("start", 0))
	end_tick = int(d.get("end", 0))
	featured_id = int(d.get("net_id", -1))
	camera = Camera3D.new()
	camera.name = "ReplayCam"
	camera.cull_mask = 1 | (1 << 1) | (1 << 3)
	camera.far = 1200.0
	add_child(camera)
	# Hide the live pawns during the replay.
	for v: PawnVisual in presentation.visuals.values():
		if is_instance_valid(v):
			v.visible = false
	if presentation.fp_rig:
		presentation.fp_rig.arms.visible = false
	_build_ghosts()


func _build_ghosts() -> void:
	if frames.is_empty():
		return
	var first: Dictionary = frames[0][1]
	for nid: Variant in first.keys():
		_ensure_ghost(int(nid), first[nid])


func _ensure_ghost(nid: int, pose: Dictionary) -> Dictionary:
	if ghosts.has(nid):
		return ghosts[nid]
	var hero := Registry.hero(StringName(String(pose.get("hero", ""))))
	if hero == null:
		return {}
	var node := Node3D.new()
	node.name = "Ghost_%d" % nid
	presentation.world().add_child(node)
	var rig := HeroRig.new()
	node.add_child(rig)
	rig.build(hero, int(pose.get("team", 0)))
	var label := Label3D.new()
	label.text = String(pose.get("name", ""))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40; label.pixel_size = 0.004; label.outline_size = 8
	label.modulate = RF.team_color(int(pose.get("team", 0)))
	label.position.y = hero.visual.height + 0.35 if hero.visual else 2.2
	node.add_child(label)
	var g := {"node": node, "rig": rig, "hero": hero, "label": label, "last_pos": Vector3.ZERO}
	ghosts[nid] = g
	return g


func play(on_finished: Callable, with_music: bool = true) -> void:
	playing = true
	t = 0.0
	event_index = 0
	finished_callback = on_finished
	camera.current = true
	if with_music and presentation.audio:
		presentation.audio.play_music(&"music_potg", -4.0)


func stop() -> void:
	playing = false
	for g: Variant in ghosts.values():
		(g["node"] as Node).queue_free()
	ghosts.clear()
	for v: PawnVisual in presentation.visuals.values():
		if is_instance_valid(v):
			v.visible = true
	if presentation.fp_rig and presentation.fp_rig.attached:
		presentation.fp_rig.arms.visible = true
		presentation.fp_rig.camera.current = true
	else:
		presentation.spectator_cam.activate(true)
	if presentation.audio:
		presentation.audio.stop_music()
	queue_free()


func update_frame(delta: float) -> void:
	if not playing or frames.is_empty():
		return
	t += delta * speed
	var cur_tick := start_tick + t * RF.TICK_RATE
	if cur_tick > end_tick:
		playing = false
		if finished_callback.is_valid():
			finished_callback.call()
		return
	# Find bracketing frames
	while frame_index < frames.size() - 2 and float(frames[frame_index + 1][0]) <= cur_tick:
		frame_index += 1
	var fa: Array = frames[frame_index]
	var fb: Array = frames[mini(frame_index + 1, frames.size() - 1)]
	var ta := float(fa[0]); var tb := float(fb[0])
	var k := 0.0 if tb <= ta else clampf((cur_tick - ta) / (tb - ta), 0.0, 1.0)
	var pa: Dictionary = fa[1]; var pb: Dictionary = fb[1]
	for nid: Variant in pb.keys():
		var b: Dictionary = pb[nid]
		var a: Dictionary = pa.get(nid, b)
		var g := _ensure_ghost(int(nid), b)
		if g.is_empty():
			continue
		var node: Node3D = g["node"]
		var pos: Vector3 = (a["pos"] as Vector3).lerp(b["pos"], k)
		var yaw := lerp_angle(float(a["yaw"]), float(b["yaw"]), k)
		var pitch := lerpf(float(a["pitch"]), float(b["pitch"]), k)
		var alive: bool = b["alive"]
		var vel: Vector3 = (pos - (g["last_pos"] as Vector3)) / maxf(delta, 0.001)
		g["last_pos"] = pos
		node.global_position = pos
		node.rotation.y = yaw
		node.visible = alive
		var rig: HeroRig = g["rig"]
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(-fwd.z, 0, fwd.x)
		rig.animate(delta, {"speed": Vector2(vel.x, vel.z).length(), "max_speed": g["hero"].movement.max_speed if g["hero"].movement else 5.5,
			"local_move": Vector2(Vector2(vel.x, vel.z).dot(Vector2(right.x, right.z)), Vector2(vel.x, vel.z).dot(Vector2(fwd.x, fwd.z))),
			"grounded": true, "crouch": float(b.get("crouch", 0.0)), "pitch": pitch, "recoil": 0.0, "melee": 0.0, "hit": 0.0, "heal": 0.0,
			"stunned": false, "rooted": false, "pose": &"", "vy": vel.y, "invisible": false, "revealed": false, "hovering": false})
		if int(nid) == featured_id:
			# POV camera slightly behind the shoulder so the featured hero is readable.
			var eye := pos + Vector3(0, (g["hero"].movement.eye_height if g["hero"].movement else 1.6), 0)
			var back := -Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))
			var cam_pos := eye + back * 1.6 + right * 0.55 + Vector3(0, 0.25, 0)
			var res := presentation.world().raycast_world(eye, (cam_pos - eye).normalized(), 1.9, -1, false)
			if not res.is_empty():
				cam_pos = eye + (cam_pos - eye).normalized() * maxf(float(res["distance"]) - 0.2, 0.3)
			camera.global_position = camera.global_position.lerp(cam_pos, clampf(delta * 12.0, 0.0, 1.0))
			camera.rotation = Vector3(pitch, yaw, 0)
			camera.fov = 90.0
	# Fire events whose time has come
	while event_index < events.size() and float(events[event_index][0]) <= cur_tick:
		var e: Array = events[event_index]
		event_index += 1
		_present_event(StringName(String(e[1])), e[2])


func _present_event(kind: StringName, pl: Dictionary) -> void:
	var w := presentation.world()
	var vfx := presentation.vfx
	var audio := presentation.audio
	match kind:
		&"hitscan":
			var g: Dictionary = ghosts.get(int(pl.get("pawn", -1)), {})
			var origin: Vector3 = (g["rig"] as HeroRig).muzzle_global() if not g.is_empty() else pl["origin"]
			var hero: HeroData = g.get("hero") if not g.is_empty() else null
			var slot := int(pl.get("slot", 0))
			var ab: AbilityData = hero.slot_ability(slot) if hero and slot >= 0 and slot < 6 else null
			var pres := ab.presentation if ab and ab.presentation else AbilityPresentation.new()
			for h: Dictionary in pl["hits"]:
				vfx.tracer(origin, h["end"], pres)
				vfx.impact(h["end"], h.get("normal", Vector3.UP), pres)
			if not g.is_empty():
				(g["rig"] as HeroRig).flash_muzzle()
			audio.play_weapon(pres, origin, false)
		&"kill":
			var g: Dictionary = ghosts.get(int(pl.get("victim", -1)), {})
			if not g.is_empty():
				vfx.spawn(&"death_burst", (g["node"] as Node3D).global_position + Vector3(0, 1, 0), Vector3.UP, RF.team_color(int(g["hero"].role) % 2))
			audio.play_2d(&"kill_confirm", &"UI")
		&"projectile_impact":
			vfx.projectile_impact(StringName(String(pl.get("visual", "bolt"))), pl["pos"], pl["normal"], Color(1, 0.8, 0.4), float(pl.get("splash", 0.0)))
		&"area":
			vfx.area(StringName(String(pl.get("vfx", "area_generic"))), pl["pos"], float(pl["radius"]), Color.WHITE)
		&"ability":
			if pl.get("phase", &"") == &"activate" and pl.get("ult", false):
				vfx.spawn(&"ult_burst", pl["pos"] + Vector3(0, 1, 0), Vector3.UP, Color(1, 0.9, 0.6))
		&"melee":
			if int(pl.get("hits", 0)) > 0:
				vfx.spawn(&"melee_hit", pl["pos"], Vector3.UP, Color(1, 0.9, 0.7))
		&"teleport":
			vfx.spawn(&"blink_in", pl["to"] + Vector3(0, 1, 0), Vector3.UP, Color.WHITE)
