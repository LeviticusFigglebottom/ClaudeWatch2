class_name FirstPersonRig
extends Node3D
## First-person camera + viewmodel with sway, bob, recoil kick, landing dip, hitstop, trauma shake,
## damage flinch, ability poses and FOV kick. This is where "feel" lives on the client side.

var camera: Camera3D
var arms: Node3D
var weapon: Node3D
var pawn: Pawn
var trauma: float = 0.0
var kick_pitch: float = 0.0
var kick_yaw: float = 0.0
var vm_kick: Vector3 = Vector3.ZERO
var vm_kick_rot: float = 0.0
var sway: Vector2 = Vector2.ZERO
var bob_t: float = 0.0
var land_dip: float = 0.0
var hitstop_left: float = 0.0
var flinch: Vector2 = Vector2.ZERO
var fov_extra: float = 0.0
var base_fov: float = 103.0
var reload_t: float = 0.0
var reload_total: float = 0.0
var ability_pose_t: float = 0.0
var melee_t: float = 0.0
var noise := FastNoiseLite.new()
var _last_yaw: float = 0.0
var _last_pitch: float = 0.0
var dead_cam_t: float = -1.0
var attached: bool = false
var weapon_style: StringName = &"rifle"
var muzzle: Node3D
var muzzle_flash: MeshInstance3D
var flash_t: float = 0.0
var _hitstop_scale_backup: float = 1.0
var vm_light: OmniLight3D
var _vm_base_pos := Vector3.ZERO   # the pose is authored in camera space; this is the animation offset


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.cull_mask = 1 | (1 << 2) | (1 << 3)   # world (1), fp viewmodel (3), vfx (4); not layer 2 (own body)
	camera.near = 0.03
	camera.far = 1200.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH   # the FOV setting is horizontal (shooter convention)
	add_child(camera)
	arms = Node3D.new()
	arms.name = "Arms"
	camera.add_child(arms)
	arms.position = _vm_base_pos
	noise.seed = 7
	noise.frequency = 1.2
	vm_light = OmniLight3D.new()
	vm_light.light_energy = 0.0
	vm_light.omni_range = 3.0
	vm_light.light_cull_mask = 1 | (1 << 2)
	camera.add_child(vm_light)
	vm_light.position = Vector3(0.3, -0.2, -0.8)
	base_fov = float(Settings.get_value(&"controls", "fov"))
	EventBus.settings_changed.connect(func(section: StringName) -> void:
		if section == &"controls":
			base_fov = float(Settings.get_value(&"controls", "fov")))


func attach(p: Pawn) -> void:
	pawn = p
	attached = true
	dead_cam_t = -1.0
	_build_viewmodel()
	camera.current = true
	_last_yaw = p.yaw
	_last_pitch = p.pitch
	if App.client and App.client.input:
		App.client.input.set_view(p.yaw, p.pitch)


func detach() -> void:
	pawn = null
	attached = false


## Viewmodel layout (camera space, metres; forward is -Z). Positions are where things are DRAWN: the
## viewmodel shader projects them with VM_FOV instead of the world FOV and compresses depth so nothing clips.
const VM_FOV := 60.0
const VM_DEPTH_SCALE := 0.3
const VM_WEAPON_SCALE := 0.5
const AIM_CONVERGE := Vector3(-0.05, 0.04, -1.0)   # weapon axis drifts toward the crosshair
var _vm_mats: Dictionary = {}
var _viewmodel_shader: Shader = preload("res://src/client/shaders/viewmodel.gdshader")


func _build_viewmodel() -> void:
	for c: Node in arms.get_children():
		c.queue_free()
	_vm_mats.clear()
	var vis := pawn.hero.visual if pawn.hero.visual else HeroVisualData.new()
	weapon_style = vis.weapon_style
	var sleeve := _vm_mat(vis.primary_color, vis.metallic * 0.5, clampf(vis.roughness + 0.1, 0.0, 1.0))
	var glove := _vm_mat(vis.arms_color, 0.15, 0.7)
	var bare := vis.head == HeroVisualData.HeadShape.BARE
	var hand_mat := _vm_mat(vis.skin_color, 0.0, 0.75) if bare else glove
	var two_handed := WeaponBuilder.is_two_handed(weapon_style)
	var dual := weapon_style == &"pistols"
	# --- Pose per archetype: right-hand grip point, support-hand point, weapon aim direction.
	var grip_r := Vector3(0.2, -0.3, -0.58)
	var aim_dir := AIM_CONVERGE.normalized()
	match weapon_style:
		&"cannon", &"mortar", &"harpoon":
			grip_r = Vector3(0.25, -0.36, -0.54)          # heavy, held low at the hip
			aim_dir = Vector3(-0.02, 0.03, -1.0).normalized()
		&"staff":
			grip_r = Vector3(0.26, -0.3, -0.42)
			aim_dir = Vector3(-0.16, 0.1, -1.0).normalized()
		&"bow":
			grip_r = Vector3(0.16, -0.17, -0.4)         # string hand, drawn back near the cheek
			aim_dir = Vector3(-0.05, 0.02, -1.0).normalized()
		&"blades":
			grip_r = Vector3(0.26, -0.26, -0.48)
			aim_dir = Vector3(-0.28, 0.14, -1.0).normalized()
		&"gauntlet":
			grip_r = Vector3(0.22, -0.24, -0.6)
			aim_dir = Vector3(-0.12, 0.08, -1.0).normalized()
		&"orb":
			grip_r = Vector3(0.24, -0.3, -0.52)
			aim_dir = Vector3(-0.08, 0.0, -1.0).normalized()
		&"lantern":
			grip_r = Vector3(0.28, -0.02, -0.6)          # held up by the handle so the lantern body hangs in view
			aim_dir = Vector3(-0.08, 0.0, -1.0).normalized()
		&"shield_mace":
			grip_r = Vector3(0.28, -0.28, -0.46)
			aim_dir = Vector3(-0.3, 0.22, -1.0).normalized()
		&"launcher":
			grip_r = Vector3(0.21, -0.31, -0.56)
	# --- Weapon: orient along aim_dir, then slide so its Grip node lands on grip_r.
	weapon = Node3D.new()
	weapon.name = "Weapon"
	arms.add_child(weapon)
	WeaponBuilder.build(weapon, weapon_style, vis, pawn.team)
	var wscale := VM_WEAPON_SCALE * lerpf(1.0, vis.weapon_scale, 0.5)
	weapon.scale = Vector3.ONE * wscale
	weapon.basis = Basis.looking_at(aim_dir, Vector3.UP).scaled(Vector3.ONE * wscale)
	var grip_local: Vector3 = (weapon.get_node("Grip") as Node3D).position
	weapon.position = grip_r - weapon.basis * grip_local
	_apply_vm_materials(weapon)
	muzzle = weapon.get_node_or_null("Muzzle") as Node3D
	# --- Right arm: shoulder (off-screen, lower right) -> elbow -> fist on the grip.
	var shoulder_r := Vector3(0.4, -0.55, 0.1)
	var elbow_r := _elbow(shoulder_r, grip_r, Vector3(0.12, -0.1, 0.0))
	_limb(shoulder_r, elbow_r, 0.058, sleeve)
	_limb(elbow_r, grip_r, 0.046, glove)
	_fist(grip_r, aim_dir, hand_mat, glove, true)
	# --- Support hand / second weapon.
	if dual:
		var grip_l := Vector3(-grip_r.x, grip_r.y, grip_r.z)
		var aim_l := Vector3(-aim_dir.x, aim_dir.y, aim_dir.z)
		var w2 := Node3D.new(); w2.name = "WeaponL"
		arms.add_child(w2)
		WeaponBuilder.build(w2, weapon_style, vis, pawn.team)
		w2.basis = Basis.looking_at(aim_l, Vector3.UP).scaled(Vector3.ONE * wscale)
		w2.position = grip_l - w2.basis * grip_local
		_apply_vm_materials(w2)
		var shoulder_l := Vector3(-0.38, -0.5, 0.12)
		var elbow_l := _elbow(shoulder_l, grip_l, Vector3(-0.12, -0.1, 0.0))
		_limb(shoulder_l, elbow_l, 0.058, sleeve)
		_limb(elbow_l, grip_l, 0.046, glove)
		_fist(grip_l, aim_l, hand_mat, glove, false)
	elif two_handed:
		var fg_local: Vector3 = (weapon.get_node("Foregrip") as Node3D).position
		var grip_l := weapon.position + weapon.basis * fg_local
		var shoulder_l := Vector3(-0.34, -0.55, 0.05)
		var elbow_l := _elbow(shoulder_l, grip_l, Vector3(-0.14, -0.12, 0.05))
		_limb(shoulder_l, elbow_l, 0.058, sleeve)
		_limb(elbow_l, grip_l, 0.046, glove)
		_fist(grip_l, aim_dir, hand_mat, glove, false)
	elif weapon_style == &"shield_mace":
		# Shield strapped to the left forearm, held up beside the view.
		var shoulder_l := Vector3(-0.36, -0.52, 0.08)
		var hand_l := Vector3(-0.36, -0.26, -0.6)
		var elbow_l := _elbow(shoulder_l, hand_l, Vector3(-0.1, -0.12, 0.0))
		_limb(shoulder_l, elbow_l, 0.058, sleeve)
		_limb(elbow_l, hand_l, 0.046, glove)
		_fist(hand_l, Vector3.FORWARD, hand_mat, glove, false)
		var shield := MeshInstance3D.new()
		var sm := BoxMesh.new(); sm.size = Vector3(0.26, 0.36, 0.035)
		shield.mesh = sm
		shield.material_override = _vm_mat(vis.secondary_color, 0.6, 0.45)
		shield.position = hand_l + Vector3(-0.03, 0.08, -0.07)
		shield.rotation = Vector3(0.05, 0.45, 0.0)
		shield.layers = 1 << 2
		arms.add_child(shield)
		var boss := MeshInstance3D.new()
		var bm := CylinderMesh.new(); bm.top_radius = 0.06; bm.bottom_radius = 0.08; bm.height = 0.03
		boss.mesh = bm
		boss.material_override = _vm_mat(vis.emissive_color if vis.emissive_color.v > 0.05 else vis.accent_color, 0.4, 0.4, true)
		boss.position = shield.position + shield.basis * Vector3(0, 0, -0.03)
		boss.rotation = shield.rotation + Vector3(PI * 0.5, 0, 0)
		boss.layers = 1 << 2
		arms.add_child(boss)
	# --- Muzzle flash lives under the camera at the *drawn* muzzle position (see vm_to_world).
	if muzzle_flash and is_instance_valid(muzzle_flash):
		muzzle_flash.queue_free()
	muzzle_flash = MeshInstance3D.new()
	var fm := QuadMesh.new(); fm.size = Vector2(0.22, 0.22)
	muzzle_flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fmat.no_depth_test = true
	fmat.albedo_texture = VfxLibrary.flash_texture()
	fmat.albedo_color = pawn.hero.theme_color.lightened(0.4)
	muzzle_flash.material_override = fmat
	muzzle_flash.layers = 1 << 2
	muzzle_flash.visible = false
	camera.add_child(muzzle_flash)
	vm_light.light_color = pawn.hero.theme_color.lightened(0.3)


## Elbow between shoulder and hand: bent outward/downward so the arm reads as an arm, not a stick.
func _elbow(shoulder: Vector3, hand: Vector3, bend: Vector3) -> Vector3:
	return shoulder.lerp(hand, 0.48) + bend


func _limb(a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = radius
	cap.height = maxf(a.distance_to(b) + radius * 2.0, radius * 2.0)
	cap.radial_segments = 14
	mi.mesh = cap
	mi.material_override = mat
	var dir := (b - a).normalized()
	var up := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var x := up.cross(dir).normalized()
	var z := x.cross(dir).normalized()   # right-handed: x × y = z
	mi.transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)
	mi.layers = 1 << 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arms.add_child(mi)
	return mi


## A closed hand around a grip: palm block + four fingers wrapped over the front + thumb.
func _fist(at: Vector3, aim: Vector3, skin: Material, glove: Material, right: bool) -> void:
	var root := Node3D.new()
	root.name = "FistR" if right else "FistL"
	root.transform = Transform3D(Basis.looking_at(aim, Vector3.UP), at)
	arms.add_child(root)
	var side := 1.0 if right else -1.0
	_part(root, BoxMesh.new(), Vector3(0.07, 0.085, 0.075), Vector3(0.0, 0.0, 0.0), glove)
	for i in 4:
		var f := CapsuleMesh.new()
		f.radius = 0.011
		f.height = 0.06
		var fp := Vector3(-side * 0.032, 0.03 - i * 0.02, -0.04)
		var mi := _part(root, f, Vector3.ONE, fp, skin)
		mi.rotation = Vector3(0.0, 0.0, side * PI * 0.5)
	var th := CapsuleMesh.new(); th.radius = 0.012; th.height = 0.055
	var thumb := _part(root, th, Vector3.ONE, Vector3(side * 0.035, 0.03, -0.01), skin)
	thumb.rotation = Vector3(-0.6, 0.0, side * 0.5)


func _part(parent: Node3D, mesh: Mesh, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.layers = 1 << 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _vm_mat(color: Color, metallic: float, rough: float, emissive: bool = false, energy: float = 2.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(), metallic, rough, emissive]
	if _vm_mats.has(key):
		return _vm_mats[key]
	var m := ShaderMaterial.new()
	m.shader = _viewmodel_shader
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"metallic", metallic)
	m.set_shader_parameter(&"roughness", rough)
	m.set_shader_parameter(&"emission", color if emissive else Color.BLACK)
	m.set_shader_parameter(&"emission_energy", energy if emissive else 0.0)
	m.set_shader_parameter(&"vm_fov", VM_FOV)
	m.set_shader_parameter(&"depth_scale", VM_DEPTH_SCALE)
	_vm_mats[key] = m
	return m


## Convert a WeaponBuilder subtree (StandardMaterial3D) to viewmodel shader materials on the FP layer.
func _apply_vm_materials(root: Node3D) -> void:
	for n: Node in root.get_children():
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			mi.layers = 1 << 2
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var std := mi.material_override as StandardMaterial3D
			if std:
				mi.material_override = _vm_mat(std.albedo_color, std.metallic, std.roughness, std.emission_enabled, std.emission_energy_multiplier)
		if n is Node3D:
			_apply_vm_materials(n as Node3D)


## Map a camera-local viewmodel point to the world point that projects to the same pixel under the world
## camera (the shader draws the viewmodel with VM_FOV). Used for muzzle flashes, tracers and the VM light.
func vm_to_camera(local: Vector3) -> Vector3:
	var f_vm := 1.0 / tan(deg_to_rad(VM_FOV) * 0.5)
	var vfov := camera.fov if camera.keep_aspect == Camera3D.KEEP_HEIGHT else _vertical_fov()
	var f_main := 1.0 / tan(deg_to_rad(vfov) * 0.5)
	var k := f_vm / f_main
	return Vector3(local.x * k, local.y * k, local.z)


func _vertical_fov() -> float:
	var vp := get_viewport()
	var aspect := 16.0 / 9.0
	if vp:
		var sz := vp.get_visible_rect().size
		if sz.y > 0.0:
			aspect = sz.x / sz.y
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(camera.fov) * 0.5) / aspect))


func debug_dump() -> String:
	var out := ""
	var stack: Array[Node] = [arms]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			var local := camera.to_local(mi.global_position)
			var scr := camera.unproject_position(camera.to_global(vm_to_camera(local)))
			var sz := mi.get_aabb().size * mi.global_transform.basis.get_scale()
			out += "%s/%s local=(%.2f %.2f %.2f) screen=(%d %d) size=(%.3f %.3f %.3f)\n" % [n.get_parent().name, n.name, local.x, local.y, local.z, int(scr.x), int(scr.y), sz.x, sz.y, sz.z]
		for c: Node in n.get_children():
			stack.append(c)
	return out


func muzzle_position() -> Vector3:
	if muzzle and attached and is_instance_valid(muzzle):
		var local := camera.to_local(muzzle.global_position)
		return camera.to_global(vm_to_camera(local))
	return camera.global_position + camera.global_transform.basis * Vector3(0.25, -0.2, -0.6)


func shake(t: float) -> void:
	trauma = clampf(trauma + t * float(Settings.get_value(&"accessibility", "screen_shake")), 0.0, 1.0)


func hitstop(seconds: float) -> void:
	hitstop_left = maxf(hitstop_left, seconds)


func on_fire(pres: AbilityPresentation) -> void:
	kick_pitch += pres.camera_kick_pitch
	kick_yaw += randf_range(-pres.camera_kick_yaw_random, pres.camera_kick_yaw_random)
	vm_kick += Vector3(0, pres.viewmodel_kick * 0.3, pres.viewmodel_kick)
	vm_kick_rot += deg_to_rad(pres.viewmodel_kick_rot)
	shake(pres.camera_shake)
	fov_extra += pres.camera_kick_pitch * 0.4
	if muzzle_flash and muzzle and (pres.muzzle_vfx != &"" or pres.tracer_style != &""):
		muzzle_flash.position = vm_to_camera(camera.to_local(muzzle.global_position))
		vm_light.position = muzzle_flash.position + Vector3(0, 0, -0.15)
		muzzle_flash.visible = true
		muzzle_flash.rotation.z = randf() * TAU
		muzzle_flash.scale = Vector3.ONE * randf_range(0.8, 1.3)
		flash_t = 0.05
		vm_light.light_energy = 2.5


func on_melee() -> void:
	melee_t = 0.35
	shake(0.08)


func on_reload(t: float) -> void:
	reload_t = t
	reload_total = t


func on_ability(ab: AbilityData, phase: StringName) -> void:
	if phase == &"activate" or phase == &"fire":
		ability_pose_t = maxf(ab.cast_time + 0.4, 0.4)
		if ab.presentation:
			shake(ab.presentation.camera_shake * 0.6)
			fov_extra += 2.0 if ab.is_ultimate() else 0.6
	elif phase == &"end":
		ability_pose_t = 0.0


func on_damage_taken(amount: float, from_dir: Vector3) -> void:
	var s := clampf(amount / 120.0, 0.08, 0.5)
	shake(s * 0.8)
	# Flinch away from the hit direction
	var right := camera.global_transform.basis.x
	var fwd := -camera.global_transform.basis.z
	flinch += Vector2(from_dir.dot(right), from_dir.dot(fwd)) * s * 3.0


func on_local_death() -> void:
	dead_cam_t = 0.0


func on_local_spawn() -> void:
	dead_cam_t = -1.0
	trauma = 0.0
	kick_pitch = 0.0; kick_yaw = 0.0
	flinch = Vector2.ZERO
	if App.client and App.client.input and pawn:
		App.client.input.set_view(pawn.yaw, 0.0)


func update_frame(delta: float) -> void:
	if not attached or pawn == null or not is_instance_valid(pawn):
		return
	# Hitstop: freeze the viewmodel/camera-relative motion briefly (does not touch simulation).
	var dt := delta
	if hitstop_left > 0.0:
		hitstop_left -= delta
		dt = delta * 0.15
	var eye := pawn.eye_position()
	# Camera follows the (interpolated) pawn transform.
	var interp_pos := pawn.get_global_transform_interpolated().origin if pawn.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF else pawn.global_position
	var target := interp_pos + Vector3(0, pawn.movement.eye_height(), 0)
	# View angles come straight from input for zero latency (server reconciles yaw anyway).
	var yaw := App.client.input.yaw if App.client and App.client.input else pawn.yaw
	var pitch := App.client.input.pitch if App.client and App.client.input else pawn.pitch
	if pawn.status.stunned or not pawn.alive:
		yaw = pawn.yaw; pitch = pawn.pitch
	# Recoil recovery
	kick_pitch = lerpf(kick_pitch, 0.0, clampf(dt * 12.0, 0.0, 1.0))
	kick_yaw = lerpf(kick_yaw, 0.0, clampf(dt * 12.0, 0.0, 1.0))
	flinch = flinch.lerp(Vector2.ZERO, clampf(dt * 9.0, 0.0, 1.0))
	# Bob
	var hs := Vector2(pawn.velocity.x, pawn.velocity.z).length()
	var norm := clampf(hs / maxf(pawn.movement.profile.max_speed, 0.1), 0.0, 1.3)
	var bob_scale: float = float(Settings.get_value(&"accessibility", "camera_bob")) * pawn.movement.profile.camera_bob_scale
	if pawn.is_on_floor() and hs > 0.5:
		bob_t += dt * (7.0 + norm * 6.0)
	var bob_y := sin(bob_t * 2.0) * 0.018 * norm * bob_scale
	var bob_x := cos(bob_t) * 0.012 * norm * bob_scale
	# Landing dip
	if pawn.movement.last_land_impact > 0.0:
		land_dip = clampf(pawn.movement.last_land_impact / 14.0, 0.0, 1.0) * 0.16
		pawn.movement.last_land_impact = 0.0
	land_dip = lerpf(land_dip, 0.0, clampf(dt * 8.0, 0.0, 1.0))
	# Shake
	trauma = maxf(trauma - dt * 1.6, 0.0)
	var sh := trauma * trauma
	var t := Time.get_ticks_msec() * 0.001
	var shake_pitch := noise.get_noise_2d(t * 40.0, 0.0) * sh * 0.06
	var shake_yaw := noise.get_noise_2d(0.0, t * 40.0) * sh * 0.06
	var shake_roll := noise.get_noise_2d(t * 40.0, 100.0) * sh * 0.05
	if bool(Settings.get_value(&"accessibility", "reduce_flashing")):
		shake_pitch *= 0.4; shake_yaw *= 0.4; shake_roll *= 0.2
	# Death cam: fall to the ground and look up slightly
	var roll := 0.0
	if dead_cam_t >= 0.0:
		dead_cam_t += delta
		var k := clampf(dead_cam_t / 0.8, 0.0, 1.0)
		target.y = lerpf(target.y, interp_pos.y + 0.35, k)
		roll = lerpf(0.0, 0.55, k)
		pitch = lerpf(pitch, -0.2, k)
	camera.global_position = target + Vector3(0, bob_y - land_dip, 0) + camera.global_transform.basis.x * bob_x
	var basis := Basis()
	basis = basis.rotated(Vector3.UP, yaw + deg_to_rad(kick_yaw) + shake_yaw + flinch.x * 0.02)
	basis = basis.rotated(basis.x, pitch + deg_to_rad(kick_pitch) + shake_pitch + flinch.y * 0.02)
	basis = basis.rotated(basis.z, shake_roll + roll + (-flinch.x * 0.02))
	camera.global_transform.basis = basis
	# FOV
	fov_extra = lerpf(fov_extra, 0.0, clampf(dt * 10.0, 0.0, 1.0))
	var speed_fov := clampf((hs - pawn.movement.profile.max_speed) * 0.35, 0.0, 6.0)
	camera.fov = base_fov + fov_extra + speed_fov
	# Viewmodel sway from look delta + strafe, kick, reload/ability poses
	var dyaw := wrapf(yaw - _last_yaw, -PI, PI)
	var dpitch := pitch - _last_pitch
	_last_yaw = yaw; _last_pitch = pitch
	sway = sway.lerp(Vector2(clampf(dyaw * 2.5, -0.08, 0.08), clampf(dpitch * 2.0, -0.06, 0.06)), clampf(dt * 10.0, 0.0, 1.0))
	vm_kick = vm_kick.lerp(Vector3.ZERO, clampf(dt * 14.0, 0.0, 1.0))
	vm_kick_rot = lerpf(vm_kick_rot, 0.0, clampf(dt * 12.0, 0.0, 1.0))
	var strafe := clampf(pawn.velocity.dot(camera.global_transform.basis.x) / 6.0, -1.0, 1.0)
	var vm_pos := _vm_base_pos + Vector3(-sway.x * 0.8 - strafe * 0.02, sway.y * 0.6 + bob_y * 0.6 - land_dip * 0.4, 0.0) + vm_kick
	var vm_rot := Vector3(-vm_kick_rot + sway.y * 0.5, sway.x * 1.2, -strafe * 0.05 + sway.x * 0.3)
	if reload_t > 0.0:
		reload_t -= dt
		var k := 1.0 - reload_t / maxf(reload_total, 0.01)
		var dip := sin(k * PI)
		vm_pos += Vector3(0.05 * dip, -0.22 * dip, 0.08 * dip)
		vm_rot += Vector3(-0.5 * dip, 0.35 * dip, 0.6 * dip)
	if ability_pose_t > 0.0:
		ability_pose_t -= dt
		var k := clampf(ability_pose_t / 0.4, 0.0, 1.0)
		vm_pos += Vector3(-0.06 * k, 0.04 * k, 0.05 * k)
		vm_rot += Vector3(0.25 * k, -0.15 * k, -0.2 * k)
	if melee_t > 0.0:
		melee_t -= dt
		var k := melee_t / 0.35
		var swing := sin(k * PI)
		vm_pos += Vector3(-0.25 * swing, -0.05 * swing, -0.25 * swing)
		vm_rot += Vector3(0.0, 0.9 * swing, -0.4 * swing)
	if pawn.movement.crouch_amount > 0.0:
		vm_pos.y -= 0.03 * pawn.movement.crouch_amount
	if pawn.movement.hovering:
		vm_pos.y += sin(t * 9.0) * 0.01
	arms.position = arms.position.lerp(vm_pos, clampf(dt * 18.0, 0.0, 1.0))
	arms.rotation = arms.rotation.lerp(vm_rot, clampf(dt * 18.0, 0.0, 1.0))
	arms.visible = pawn.alive and dead_cam_t < 0.0 and not pawn.status.invisible
	if flash_t > 0.0:
		flash_t -= delta
		if flash_t <= 0.0 and muzzle_flash:
			muzzle_flash.visible = false
	vm_light.light_energy = lerpf(vm_light.light_energy, 0.0, clampf(delta * 20.0, 0.0, 1.0))
