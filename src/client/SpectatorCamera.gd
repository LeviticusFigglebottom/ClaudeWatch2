class_name SpectatorCamera
extends Node3D
## Free/orbit camera used before spawn, while dead, in the hero-select background and by the
## screenshot harness (`cam` console command).

var camera: Camera3D
var active: bool = false
var world: SimWorld
var layout: MapLayout
var target_pos: Vector3
var orbit_yaw: float = 0.0
var orbit_pitch: float = -0.35
var orbit_dist: float = 4.5
var mode: StringName = &"orbit"        # orbit, free, follow, fixed
var follow_id: int = -1
var free_pos: Vector3
var free_yaw: float = 0.0
var free_pitch: float = 0.0
var death_anchor: Vector3


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "SpecCam"
	camera.cull_mask = 1 | (1 << 1) | (1 << 3)
	camera.far = 1200.0
	add_child(camera)
	camera.current = false
	Console.register("cam", "cam <x> <y> <z> <yaw> <pitch> [fov]: fixed camera", func(a: PackedStringArray) -> String:
		if a.size() < 5: return "usage: cam x y z yaw pitch [fov]"
		mode = &"fixed"
		free_pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
		free_yaw = deg_to_rad(float(a[3])); free_pitch = deg_to_rad(float(a[4]))
		if a.size() > 5: camera.fov = float(a[5])
		activate(true)
		return "camera fixed")
	Console.register("cam_follow", "cam_follow <net_id|local> [dist]: orbit a pawn", func(a: PackedStringArray) -> String:
		mode = &"orbit"
		follow_id = -1
		if a.size() > 0 and a[0] != "local":
			follow_id = int(a[0])
		if a.size() > 1: orbit_dist = float(a[1])
		activate(true)
		return "following")
	Console.register("cam_overview", "cam_overview: map overview camera", func(_a: PackedStringArray) -> String:
		if layout and layout.overview_camera != Transform3D():
			mode = &"fixed"
			free_pos = layout.overview_camera.origin
			var e := layout.overview_camera.basis.get_euler()
			free_yaw = e.y; free_pitch = e.x
			activate(true)
			return "overview"
		return "no overview camera on this map")
	Console.register("cam_off", "Return to first person", func(_a: PackedStringArray) -> String:
		activate(false); return "fp")


func set_world(w: SimWorld, l: MapLayout) -> void:
	world = w
	layout = l
	if l and l.overview_camera != Transform3D():
		free_pos = l.overview_camera.origin
		var e := l.overview_camera.basis.get_euler()
		free_yaw = e.y; free_pitch = e.x
	elif l and not l.spawn_rooms.is_empty():
		free_pos = l.spawn_rooms[0].zone.center + Vector3(0, 12, 0)


func activate(on: bool, anchor: Vector3 = Vector3.ZERO) -> void:
	active = on
	if on:
		camera.current = true
		if anchor != Vector3.ZERO:
			death_anchor = anchor
			mode = &"death"
	else:
		if App.client and App.client.presentation and App.client.presentation.fp_rig:
			App.client.presentation.fp_rig.camera.current = true


func update_frame(delta: float) -> void:
	if not active or world == null:
		return
	match mode:
		&"death":
			var cl := App.client
			var lp: Pawn = cl.local_pawn if cl else null
			var anchor := lp.global_position + Vector3(0, 0.8, 0) if lp and is_instance_valid(lp) else death_anchor
			orbit_yaw += delta * 0.25
			var off := Vector3(sin(orbit_yaw), 0.0, cos(orbit_yaw)) * 4.0 + Vector3(0, 2.2, 0)
			var pos := anchor + off
			var res := world.raycast_world(anchor, (pos - anchor).normalized(), 4.6, -1, false)
			if not res.is_empty():
				pos = anchor + (pos - anchor).normalized() * maxf(float(res["distance"]) - 0.3, 0.5)
			camera.global_position = camera.global_position.lerp(pos, clampf(delta * 4.0, 0, 1))
			camera.look_at(anchor, Vector3.UP)
		&"orbit":
			var p: Pawn = world.get_pawn(follow_id) if follow_id >= 0 else (App.client.local_pawn if App.client else null)
			if p == null:
				for q: Pawn in world.pawns.values():
					p = q; break
			if p == null:
				return
			var anchor := p.global_position + Vector3(0, 1.2, 0)
			var dir := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(-orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
			camera.global_position = anchor + dir * orbit_dist
			camera.look_at(anchor, Vector3.UP)
		&"fixed", &"free":
			camera.global_position = free_pos
			camera.rotation = Vector3(free_pitch, free_yaw, 0)
		_:
			pass


func _unhandled_input(event: InputEvent) -> void:
	if not active or mode != &"orbit":
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		orbit_yaw -= m.relative.x * 0.005
		orbit_pitch = clampf(orbit_pitch - m.relative.y * 0.005, -1.2, 0.4)
	if event.is_action_pressed("spectate_next"):
		var ids := world.pawns.keys()
		if ids.is_empty():
			return
		var i := ids.find(follow_id)
		follow_id = int(ids[(i + 1) % ids.size()])
