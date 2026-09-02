extends RefCounted
## Coil VFX: the `chain_arc` spawner (a jagged violet line between two points that fades in 0.15 s),
## gauntlet muzzle/impact, Capacitor charge/discharge, Tesla Node deployable visual and the
## Blackout signature burst (dark implosion + violet shockwave).
## chain_arc convention: spawn(&"chain_arc", from, to - from, color) — the "normal" argument carries
## the un-normalized vector to the far end.

const ARC_COLOR := Color(0.75, 0.6, 1.0)


class ArcLine extends MeshInstance3D:
	var t: float = 0.0
	var life: float = 0.15
	var light: OmniLight3D

	func _process(delta: float) -> void:
		t += delta
		var k := t / life
		if k >= 1.0:
			queue_free()
			return
		var m := material_override as StandardMaterial3D
		if m:
			m.albedo_color.a = 1.0 - k
		if light:
			light.light_energy = 3.0 * (1.0 - k)


class TeslaNodeVisual extends Node3D:
	var mats: Array[StandardMaterial3D] = []
	var rings: Node3D
	var orb: MeshInstance3D
	var t: float = 0.0
	var max_hp: float = 150.0
	var hp: float = 150.0
	var light: OmniLight3D

	func build(team: int, color: Color, mhp: float) -> void:
		max_hp = maxf(mhp, 1.0)
		hp = max_hp
		var team_col := RF.team_color(team)
		var base := CylinderMesh.new(); base.top_radius = 0.3; base.bottom_radius = 0.42; base.height = 0.25
		_add(base, Vector3(0, 0.125, 0), _mat(Color(0.22, 0.2, 0.26), 0.0))
		var post := CylinderMesh.new(); post.top_radius = 0.07; post.bottom_radius = 0.1; post.height = 0.7
		_add(post, Vector3(0, 0.55, 0), _mat(Color(0.85, 0.55, 0.2), 0.0))
		var band := TorusMesh.new(); band.inner_radius = 0.1; band.outer_radius = 0.16
		_add(band, Vector3(0, 0.35, 0), _mat(team_col, 1.0))
		rings = Node3D.new(); rings.position.y = 0.9; add_child(rings)
		for i in 2:
			var ring := TorusMesh.new(); ring.inner_radius = 0.22 + i * 0.1; ring.outer_radius = 0.26 + i * 0.1
			var mi := MeshInstance3D.new(); mi.mesh = ring; mi.material_override = _mat(color, 2.0)
			mi.rotation = Vector3(0.5 * (i + 1), 0.0, 0.3 * i)
			rings.add_child(mi)
		var s := SphereMesh.new(); s.radius = 0.14; s.height = 0.28
		orb = MeshInstance3D.new(); orb.mesh = s; orb.material_override = _mat(Color(0.9, 0.85, 1.0), 3.5)
		orb.position.y = 0.9
		add_child(orb)
		light = OmniLight3D.new(); light.light_color = color; light.light_energy = 1.4; light.omni_range = 5.0
		light.position.y = 1.0
		add_child(light)

	func _mat(c: Color, emissive: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = 0.5
		m.roughness = 0.4
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		mats.append(m)
		return m

	func _add(mesh: Mesh, pos: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = m; mi.position = pos
		add_child(mi)
		return mi

	func set_health(h: float) -> void:
		hp = h
		var f := clampf(hp / max_hp, 0.0, 1.0)
		if light:
			light.light_energy = 0.4 + 1.2 * f

	func _process(delta: float) -> void:
		t += delta
		if rings:
			rings.rotation.y += delta * 2.2
			rings.rotation.x = sin(t * 1.7) * 0.4
		if orb:
			orb.position.y = 0.9 + sin(t * 4.0) * 0.04
			orb.scale = Vector3.ONE * (0.9 + 0.15 * sin(t * 9.0))


static func register() -> void:
	VfxLibrary.register_spawner(&"chain_arc", func(lib: VfxLibrary, pos: Vector3, normal: Vector3, color: Color, _attach: Node3D) -> void:
		_spawn_arc(lib, pos, pos + normal, color))
	DeployableVisuals.register(&"coil_tesla_node", func(_kind: StringName, _data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var n := TeslaNodeVisual.new()
		n.build(team, color, max_hp)
		return n)
	VfxLibrary.register_builder(&"coil_chain_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 8, 0.12, Vector3(0, 0, 1), 35.0, Vector3.ZERO, 2.0, 5.0, 0.3, 0.7, 0.14, VfxLibrary.spark_texture(), Color(0.9, 0.85, 1.0), Color(0.6, 0.4, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"coil_lance_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 18, 0.2, Vector3(0, 0, 1), 25.0, Vector3.ZERO, 3.0, 7.0, 0.5, 1.0, 0.2, VfxLibrary.flash_texture(), Color(1.0, 0.95, 1.0), Color(0.6, 0.4, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"coil_chain_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 14, 0.3, Vector3(0, 0, 1), 80.0, Vector3(0, -3, 0), 2.0, 6.0, 0.15, 0.35, 0.1, VfxLibrary.spark_texture(), Color(0.9, 0.85, 1.0), Color(0.55, 0.35, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"coil_tesla_node_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 12, 0.4, Vector3(0, 1, 0), 40.0, Vector3.ZERO, 1.0, 3.0, 0.3, 0.6, 0.18, VfxLibrary.spark_texture(), Color(0.85, 0.7, 1.0), Color(0.6, 0.4, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"coil_capacitor_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Charge-up: sparks fall inward toward the body.
		var p := _burst(lib, 30, 0.6, Vector3(0, 1, 0), 180.0, Vector3.ZERO, 0.0, 0.5, 0.3, 0.6, 0.16, VfxLibrary.spark_texture(), Color(0.8, 0.65, 1.0), Color(0.6, 0.4, 1.0, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.4
		mat.radial_velocity_min = -4.0
		mat.radial_velocity_max = -2.0
		return p)
	VfxLibrary.register_builder(&"coil_capacitor_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 40, 0.5, Vector3(0, 1, 0), 180.0, Vector3(0, -4, 0), 5.0, 11.0, 0.3, 0.7, 0.2, VfxLibrary.spark_texture(), Color(1.0, 0.95, 1.0), Color(0.6, 0.4, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"coil_blackout_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Signature: a dark implosion that snaps into a wide violet shockwave.
		var p := _burst(lib, 120, 1.2, Vector3(0, 0.1, 1), 180.0, Vector3(0, -1, 0), 6.0, 14.0, 0.7, 1.6, 0.45, VfxLibrary.soft_texture(), Color(0.2, 0.05, 0.35), Color(0.65, 0.45, 1.0, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.8
		mat.damping_min = 3.0
		mat.damping_max = 7.0
		return p)
	VfxLibrary.register_builder(&"coil_blackout_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 20, 0.6, Vector3(0, 1, 0), 60.0, Vector3(0, 1, 0), 0.5, 2.0, 0.6, 1.2, 0.35, VfxLibrary.soft_texture(), Color(0.4, 0.2, 0.7), Color(0.3, 0.1, 0.5, 0.0))
		return p)


static func _spawn_arc(lib: VfxLibrary, from: Vector3, to: Vector3, color: Color) -> void:
	if lib.world == null:
		return
	var d := to - from
	var len := d.length()
	if len < 0.05:
		return
	var dir := d / len
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var mesh := ImmediateMesh.new()
	var segs := clampi(int(len * 2.5) + 3, 4, 18)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(from) ^ hash(to)
	# Three strands: a bright core and two jittered outer strands for bulk.
	for strand in 3:
		var amp := 0.18 if strand == 0 else 0.32
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in segs + 1:
			var k := float(i) / float(segs)
			var pt := from.lerp(to, k)
			if i > 0 and i < segs:
				pt += side * rng.randf_range(-amp, amp) + up * rng.randf_range(-amp, amp)
			mesh.surface_add_vertex(pt)
		mesh.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = ARC_COLOR if color == Color.WHITE else color.lerp(ARC_COLOR, 0.5)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.5
	mat.disable_receive_shadows = true
	var mi := ArcLine.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.layers = 1 << 3
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = mat.albedo_color
	light.light_energy = 3.0
	light.omni_range = 3.5
	light.shadow_enabled = false
	mi.light = light
	lib.world.add_child(mi)
	mi.add_child(light)
	light.global_position = (from + to) * 0.5
	lib.spawn(&"coil_chain_impact", to, -dir, mat.albedo_color)


static func _burst(lib: VfxLibrary, amount: int, life: float, dir: Vector3, spread: float, grav: Vector3, vmin: float, vmax: float, smin: float, smax: float, size: float, tex: Texture2D, c0: Color, c1: Color, add: bool = true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.direction = dir
	mat.spread = spread
	mat.gravity = grav
	mat.initial_velocity_min = vmin
	mat.initial_velocity_max = vmax
	mat.scale_min = smin
	mat.scale_max = smax
	var ramp := Gradient.new()
	ramp.set_color(0, c0)
	ramp.set_color(1, c1)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	p.process_material = mat
	p.draw_pass_1 = lib.mesh_quad(size, tex, add)
	p.set_meta("tint", false)
	return p
