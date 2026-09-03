class_name BombardVfx
## Bombard presentation: mortar muzzle plume, airburst flash, Barrage cast/loop recipes, the
## spotter drone visual, and the indirect-fire reticle helper used by BombardBehavior on the
## owning client (a world-space Node3D drawn without depth testing so it reads through walls).

const RETICLE_META := &"bombard_reticle"


static func register() -> void:
	VfxLibrary.register_builder(&"bombard_mortar_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.9; p.amount = 14; p.lifetime = 0.35
		m.direction = Vector3(0, 0, 1); m.spread = 25.0; m.gravity = Vector3(0, 1.5, 0)
		m.initial_velocity_min = 3.0; m.initial_velocity_max = 7.0
		m.scale_min = 0.6; m.scale_max = 1.4
		m.color_ramp = _ramp(Color(1, 0.85, 0.55, 1), Color(0.5, 0.45, 0.4, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.35, VfxLibrary.soft_texture())
		return p)
	VfxLibrary.register_builder(&"bombard_airburst_flash", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 1.0; p.amount = 48; p.lifetime = 0.55
		m.direction = Vector3(0, -1, 0); m.spread = 70.0; m.gravity = Vector3(0, -8, 0)
		m.initial_velocity_min = 6.0; m.initial_velocity_max = 14.0
		m.scale_min = 0.3; m.scale_max = 0.9
		m.color_ramp = _ramp(Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.2, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.3, VfxLibrary.spark_texture())
		return p)
	VfxLibrary.register_builder(&"bombard_barrage_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 1.0; p.amount = 40; p.lifetime = 1.0
		m.direction = Vector3(0, 1, 0); m.spread = 20.0; m.gravity = Vector3(0, -4, 0)
		m.initial_velocity_min = 8.0; m.initial_velocity_max = 16.0
		m.scale_min = 0.4; m.scale_max = 0.8
		m.color_ramp = _ramp(Color(1, 0.8, 0.4, 1), Color(1, 0.4, 0.1, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.3, VfxLibrary.spark_texture())
		return p)
	VfxLibrary.register_builder(&"bombard_barrage_loop", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = false; p.explosiveness = 0.0; p.amount = 30; p.lifetime = 0.8
		m.direction = Vector3(0, 1, 0); m.spread = 60.0; m.gravity = Vector3(0, 2, 0)
		m.initial_velocity_min = 1.0; m.initial_velocity_max = 3.0
		m.scale_min = 0.3; m.scale_max = 0.6
		m.color_ramp = _ramp(Color(1, 0.75, 0.3, 0.9), Color(1, 0.5, 0.2, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.25, VfxLibrary.soft_texture())
		return p)
	DeployableVisuals.register(&"spotter_drone", func(_kind: StringName, data: Dictionary, team: int, color: Color, _max_hp: float) -> Node3D:
		return _build_drone(data, team, color))

	# The barrage's target mark and the spotter drone's search light. Both are read at range, so they
	# are wide and slow rather than bright: a teammate should see where the shells are going.
	VfxLibrary.register_builder(&"bombard_barrage_mark", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.4; p.amount = 44; p.lifetime = 1.6
		m.direction = Vector3(0, 1, 0); m.spread = 12.0; m.gravity = Vector3(0, 0.6, 0)
		m.initial_velocity_min = 0.8; m.initial_velocity_max = 2.6
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 3.0
		m.scale_min = 0.4; m.scale_max = 1.0
		m.color_ramp = _ramp(Color(1.0, 0.62, 0.25, 1), Color(0.7, 0.25, 0.05, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.36, VfxLibrary.ring_texture())
		return p)
	VfxLibrary.register_builder(&"bombard_spotter_light", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.3; p.amount = 26; p.lifetime = 1.2
		m.direction = Vector3(0, -1, 0); m.spread = 18.0; m.gravity = Vector3(0, -0.8, 0)
		m.initial_velocity_min = 1.0; m.initial_velocity_max = 3.0
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 1.6
		m.scale_min = 0.3; m.scale_max = 0.7
		m.color_ramp = _ramp(Color(1.0, 0.85, 0.55, 0.9), Color(0.8, 0.5, 0.15, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.24, VfxLibrary.soft_texture())
		return p)


static func _ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _unlit(c: Color, add: bool = true, no_depth: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = no_depth
	m.disable_receive_shadows = true
	return m


static func _build_drone(data: Dictionary, team: int, color: Color) -> Node3D:
	var root := DroneAnim.new()
	var hover: float = float(data.get("hover", 4.0))
	var radius: float = float(data.get("radius", 10.0))
	var team_col := RF.team_color(team)
	var body := Node3D.new()
	body.name = "Body"
	body.position.y = hover
	root.add_child(body)
	var hull := MeshInstance3D.new()
	var hm := SphereMesh.new(); hm.radius = 0.28; hm.height = 0.56
	hull.mesh = hm
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.32, 0.33, 0.3); hull_mat.metallic = 0.6; hull_mat.roughness = 0.4
	hull.material_override = hull_mat
	body.add_child(hull)
	for i in 4:
		var a := float(i) / 4.0 * TAU
		var rotor := MeshInstance3D.new()
		var rm := CylinderMesh.new(); rm.top_radius = 0.22; rm.bottom_radius = 0.22; rm.height = 0.02
		rotor.mesh = rm
		rotor.material_override = _unlit(Color(0.8, 0.8, 0.8, 0.35), false)
		rotor.position = Vector3(cos(a) * 0.42, 0.12, sin(a) * 0.42)
		body.add_child(rotor)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new(); em.radius = 0.09; em.height = 0.18
	eye.mesh = em
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = color; eye_mat.emission_enabled = true; eye_mat.emission = color; eye_mat.emission_energy_multiplier = 3.0
	eye.material_override = eye_mat
	eye.position = Vector3(0, -0.1, 0.24)
	body.add_child(eye)
	var light := OmniLight3D.new()
	light.light_color = color.lerp(team_col, 0.3); light.light_energy = 1.4; light.omni_range = 7.0
	body.add_child(light)
	# Search cone from the drone to the ground and a faint ring on the floor marking the reveal zone.
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.15; cm.bottom_radius = radius * 0.45; cm.height = hover
	cone.mesh = cm
	cone.material_override = _unlit(Color(color.r, color.g, color.b, 0.07))
	cone.position.y = hover * 0.5
	root.add_child(cone)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(radius * 2.0, radius * 2.0)
	ring.mesh = q
	var rmat := _unlit(Color(color.r, color.g, color.b, 0.35))
	rmat.albedo_texture = VfxLibrary.ring_texture()
	ring.material_override = rmat
	ring.rotation.x = -PI * 0.5
	ring.position.y = 0.08
	root.add_child(ring)
	return root


class DroneAnim extends Node3D:
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		var body := get_node_or_null("Body") as Node3D
		if body:
			body.rotation.y += delta * 1.2
			body.position.y += sin(t * 2.5) * 0.004


## --- Indirect-fire reticle (owning client only) ------------------------------------------------

static func reticle_for(pawn: Pawn) -> Node3D:
	var existing: Variant = pawn.get_meta(RETICLE_META, null)
	if existing is Node3D and is_instance_valid(existing):
		return existing as Node3D
	var root := Node3D.new()
	root.name = "BombardReticle"
	var col := pawn.hero.theme_color if pawn.hero else Color(1, 0.8, 0.4)
	# Inner aim ring (through walls) + outer splash ring (through walls, fainter) + a vertical pin.
	var inner := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.55; tm.outer_radius = 0.7; tm.rings = 24; tm.ring_segments = 8
	inner.mesh = tm
	inner.material_override = _unlit(Color(col.r, col.g, col.b, 0.95), true, true)
	inner.name = "Inner"
	inner.layers = 1 | (1 << 3)
	root.add_child(inner)
	var outer := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(7.0, 7.0)
	outer.mesh = q
	var om := _unlit(Color(col.r, col.g, col.b, 0.4), true, true)
	om.albedo_texture = VfxLibrary.ring_texture()
	outer.material_override = om
	outer.rotation.x = -PI * 0.5
	outer.position.y = 0.05
	outer.name = "Outer"
	outer.layers = 1 | (1 << 3)
	root.add_child(outer)
	var pin := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.02; pm.bottom_radius = 0.02; pm.height = 1.6
	pin.mesh = pm
	pin.material_override = _unlit(Color(col.r, col.g, col.b, 0.6), true, true)
	pin.position.y = 0.8
	pin.name = "Pin"
	pin.layers = 1 | (1 << 3)
	root.add_child(pin)
	pawn.world.add_child(root)
	pawn.set_meta(RETICLE_META, root)
	return root


static func update_reticle(pawn: Pawn, point: Vector3, valid: bool, normal: Vector3) -> void:
	var r := reticle_for(pawn)
	r.visible = true
	r.global_position = point + normal * 0.03
	r.global_transform.basis = Basis()
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
	var inner := r.get_node_or_null("Inner") as MeshInstance3D
	if inner:
		inner.scale = Vector3.ONE * (pulse if valid else 0.6)
		(inner.material_override as StandardMaterial3D).albedo_color.a = 0.95 if valid else 0.35
	var outer := r.get_node_or_null("Outer") as MeshInstance3D
	if outer:
		outer.visible = valid


static func hide_reticle(pawn: Pawn) -> void:
	var existing: Variant = pawn.get_meta(RETICLE_META, null)
	if existing is Node3D and is_instance_valid(existing):
		(existing as Node3D).visible = false
