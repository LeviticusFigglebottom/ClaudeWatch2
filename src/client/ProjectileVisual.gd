class_name ProjectileVisual
extends Node3D
## Client-side projectile twin: same kinematics as the server's Projectile, plus mesh, light, trail.

var vel: Vector3
var gravity: float = 0.0
var life: float = 5.0
var age: float = 0.0
var color: Color = Color.WHITE
var visual_id: StringName = &"bolt"
var predicted_key: String = ""
var mesh: MeshInstance3D
var light: OmniLight3D
var trail: GPUParticles3D
var vfx: VfxLibrary
var converge_target: Vector3
var converge_t: float = 0.0
var converge_total: float = 0.0
var stuck: bool = false
var stuck_to: Node3D
var stuck_offset: Vector3
var team: int = RF.Team.NONE
var spin: float = 0.0


func setup(v: VfxLibrary, vid: StringName, col: Color, velocity: Vector3, grav: float, lifetime: float, radius: float, t: int) -> void:
	vfx = v
	visual_id = vid
	color = col
	vel = velocity
	gravity = grav
	life = lifetime
	team = t
	mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match vid:
		&"bolt", &"needle":
			var c := CapsuleMesh.new(); c.radius = maxf(radius * 0.6, 0.04); c.height = maxf(radius * 4.0, 0.35)
			mesh.mesh = c
			mesh.rotation.x = PI * 0.5
		&"orb", &"plasma", &"flare", &"candle":
			var s := SphereMesh.new(); s.radius = maxf(radius, 0.1); s.height = s.radius * 2.0
			mesh.mesh = s
		&"disc":
			var cyl := CylinderMesh.new(); cyl.top_radius = maxf(radius, 0.18); cyl.bottom_radius = cyl.top_radius; cyl.height = 0.05
			mesh.mesh = cyl
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.metallic = 0.8
		&"shell", &"mortar", &"grenade":
			var s := SphereMesh.new(); s.radius = maxf(radius, 0.12); s.height = s.radius * 2.0
			mesh.mesh = s
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = col.darkened(0.5)
			mat.emission_energy_multiplier = 0.8
		&"harpoon", &"spear", &"thorn":
			var b := BoxMesh.new(); b.size = Vector3(0.06, 0.06, 0.8)
			mesh.mesh = b
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.metallic = 0.6
		_:
			var s := SphereMesh.new(); s.radius = maxf(radius, 0.08); s.height = s.radius * 2.0
			mesh.mesh = s
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.layers = 1 | (1 << 3)
	add_child(mesh)
	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.4
	light.omni_range = 3.5
	light.shadow_enabled = false
	add_child(light)
	trail = v.build_particles(&"projectile_trail")
	(trail.process_material as ParticleProcessMaterial).color = col
	trail.emitting = true
	add_child(trail)


func converge_to(server_pos: Vector3, seconds: float) -> void:
	converge_target = server_pos
	converge_total = seconds
	converge_t = seconds


func _process(delta: float) -> void:
	age += delta
	if stuck:
		if is_instance_valid(stuck_to):
			global_position = stuck_to.global_position + stuck_offset
		return
	vel.y -= gravity * delta
	global_position += vel * delta
	if converge_t > 0.0:
		converge_t -= delta
		converge_target += vel * delta
		global_position = global_position.lerp(converge_target, clampf(1.0 - converge_t / converge_total, 0.0, 1.0) * 0.5)
	if vel.length_squared() > 0.01 and visual_id != &"disc":
		look_at(global_position + vel.normalized(), Vector3.UP if absf(vel.normalized().y) < 0.99 else Vector3.RIGHT)
	elif visual_id == &"disc":
		spin += delta * 25.0
		rotation = Vector3(0, spin, 0)
	if age > life + 0.5:
		finish()


func on_bounce(pos: Vector3, new_vel: Vector3) -> void:
	global_position = pos
	vel = new_vel
	if vfx:
		vfx.spawn(&"impact_generic", pos, -new_vel.normalized(), color)


func stick(pos: Vector3, to: Pawn) -> void:
	stuck = true
	global_position = pos
	if to:
		stuck_to = to
		stuck_offset = pos - to.global_position
	trail.emitting = false


func finish() -> void:
	queue_free()
