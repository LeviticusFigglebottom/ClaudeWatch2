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
var _vm_base_pos := Vector3(0.28, -0.26, -0.45)


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.cull_mask = 1 | (1 << 2) | (1 << 3)   # world (1), fp viewmodel (3), vfx (4); not layer 2 (own body)
	camera.near = 0.03
	camera.far = 1200.0
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


func _build_viewmodel() -> void:
	for c: Node in arms.get_children():
		c.queue_free()
	var vis := pawn.hero.visual if pawn.hero.visual else HeroVisualData.new()
	weapon_style = vis.weapon_style
	# Right forearm + hand
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = vis.arms_color
	arm_mat.roughness = 0.6
	arm_mat.metallic = 0.25
	var fore := MeshInstance3D.new()
	var cap := CapsuleMesh.new(); cap.radius = 0.05; cap.height = 0.42
	fore.mesh = cap
	fore.material_override = arm_mat
	fore.position = Vector3(0.02, -0.06, 0.22)
	fore.rotation.x = PI * 0.5
	fore.layers = 1 << 2
	arms.add_child(fore)
	var hand := MeshInstance3D.new()
	var hs := SphereMesh.new(); hs.radius = 0.055; hs.height = 0.11
	hand.mesh = hs
	var skin := StandardMaterial3D.new()
	skin.albedo_color = vis.skin_color if vis.head == HeroVisualData.HeadShape.BARE else vis.secondary_color
	hand.material_override = skin
	hand.position = Vector3(0.0, -0.05, 0.02)
	hand.layers = 1 << 2
	arms.add_child(hand)
	# Left hand supporting for two-handed styles
	if weapon_style in [&"rifle", &"cannon", &"launcher", &"staff", &"bow", &"mortar", &"harpoon"]:
		var lhand := MeshInstance3D.new()
		lhand.mesh = hs
		lhand.material_override = skin
		lhand.position = Vector3(-0.08, -0.06, -0.3)
		lhand.layers = 1 << 2
		arms.add_child(lhand)
		var lfore := MeshInstance3D.new()
		lfore.mesh = cap
		lfore.material_override = arm_mat
		lfore.position = Vector3(-0.22, -0.12, -0.12)
		lfore.rotation = Vector3(0.4, -0.6, 0.0)
		lfore.layers = 1 << 2
		arms.add_child(lfore)
	weapon = Node3D.new()
	weapon.name = "Weapon"
	arms.add_child(weapon)
	WeaponBuilder.build(weapon, weapon_style, vis, pawn.team)
	for mi: Node in weapon.get_children():
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).layers = 1 << 2
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle = weapon.get_node_or_null("Muzzle") as Node3D
	muzzle_flash = MeshInstance3D.new()
	var fm := QuadMesh.new(); fm.size = Vector2(0.35, 0.35)
	muzzle_flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fmat.albedo_texture = VfxLibrary.flash_texture()
	fmat.albedo_color = pawn.hero.theme_color.lightened(0.4)
	muzzle_flash.material_override = fmat
	muzzle_flash.layers = 1 << 2
	muzzle_flash.visible = false
	if muzzle:
		muzzle.add_child(muzzle_flash)
	vm_light.light_color = pawn.hero.theme_color.lightened(0.3)


func muzzle_position() -> Vector3:
	if muzzle and attached:
		return muzzle.global_position
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
	if muzzle_flash and (pres.muzzle_vfx != &"" or pres.tracer_style != &""):
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
