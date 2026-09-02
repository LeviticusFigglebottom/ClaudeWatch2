extends RefCounted
## Kiln VFX: Meltdown fire bloom (ult signature), slug muzzle/impact embers, and deployable visuals
## for the Vent grate (continuous updraft embers) and the Slag Cast slab (cooling glow).

static func register() -> void:
	VfxLibrary.register_builder(&"kiln_meltdown", func(lib: VfxLibrary) -> GPUParticles3D: return _meltdown(lib))
	VfxLibrary.register_builder(&"kiln_slug_muzzle", func(lib: VfxLibrary) -> GPUParticles3D: return _slug_muzzle(lib))
	VfxLibrary.register_builder(&"kiln_slug_impact", func(lib: VfxLibrary) -> GPUParticles3D: return _slug_impact(lib))
	VfxLibrary.register_builder(&"kiln_blast_muzzle", func(lib: VfxLibrary) -> GPUParticles3D: return _blast_muzzle(lib))
	DeployableVisuals.register(&"kiln_vent", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := VentVisual.new()
		v.build(data, team, color, max_hp)
		return v)
	DeployableVisuals.register(&"kiln_slag", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := SlagVisual.new()
		v.build(data, team, color, max_hp)
		return v)


static func _base(lib: VfxLibrary, amount: int, life: float, size: float, tex: Texture2D, add: bool = true) -> Array:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	mat.color_ramp = rt
	p.draw_pass_1 = lib.mesh_quad(size, tex, add)
	p.process_material = mat
	p.set_meta("tint", true)
	return [p, mat]


## The furnace door opens: a tall fire bloom with embers thrown outward and up.
static func _meltdown(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 160, 1.6, 0.5, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.85
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.8
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 11.0
	mat.gravity = Vector3(0, 2.5, 0)
	mat.scale_min = 0.8
	mat.scale_max = 2.2
	return p


static func _slug_muzzle(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 10, 0.16, 0.2, VfxLibrary.flash_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 30.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	return p


static func _blast_muzzle(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 40, 0.45, 0.35, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 28.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 16.0
	mat.gravity = Vector3(0, 1.5, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.8
	return p


static func _slug_impact(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 24, 0.6, 0.12, VfxLibrary.spark_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 75.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -7, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.8
	return p


class VentVisual extends Node3D:
	var light: OmniLight3D
	var part: GPUParticles3D
	var t: float = 0.0

	func _mat(c: Color, emissive: float = 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		m.metallic = 0.6; m.roughness = 0.5
		return m

	func build(data: Dictionary, _team: int, color: Color, _hp: float) -> void:
		var r: float = float(data.get("radius", 1.6))
		var grate := CylinderMesh.new(); grate.top_radius = r; grate.bottom_radius = r + 0.1; grate.height = 0.14
		var gm := MeshInstance3D.new(); gm.mesh = grate; gm.material_override = _mat(Color(0.16, 0.13, 0.12)); gm.position.y = 0.07
		add_child(gm)
		var slat := BoxMesh.new(); slat.size = Vector3(r * 1.8, 0.05, 0.12)
		for i in 5:
			var sm := MeshInstance3D.new(); sm.mesh = slat; sm.material_override = _mat(Color(1.0, 0.5, 0.15).lerp(color, 0.2), 2.5)
			sm.position = Vector3(0, 0.15, -r * 0.7 + i * r * 0.35)
			add_child(sm)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.light_energy = 1.6
		light.omni_range = 4.5
		light.position.y = 0.6
		add_child(light)
		part = GPUParticles3D.new()
		part.amount = 60
		part.lifetime = 1.1
		part.one_shot = false
		part.explosiveness = 0.0
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = r * 0.8
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 8.0
		mat.initial_velocity_min = 5.0
		mat.initial_velocity_max = 9.0
		mat.gravity = Vector3(0, 2.0, 0)
		mat.scale_min = 0.3
		mat.scale_max = 0.7
		mat.color = Color(1.0, 0.6, 0.25)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1)); ramp.set_color(1, Color(1, 1, 1, 0))
		var rt := GradientTexture1D.new(); rt.gradient = ramp
		mat.color_ramp = rt
		part.process_material = mat
		var q := QuadMesh.new(); q.size = Vector2(0.18, 0.18)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.albedo_texture = VfxLibrary.spark_texture()
		qm.vertex_color_use_as_albedo = true
		q.material = qm
		part.draw_pass_1 = q
		part.position.y = 0.2
		part.emitting = true
		add_child(part)

	func _process(delta: float) -> void:
		t += delta
		if light:
			light.light_energy = 1.6 + sin(t * 9.0) * 0.4


class SlagVisual extends Node3D:
	var cracks: Array[StandardMaterial3D] = []
	var light: OmniLight3D
	var t: float = 0.0
	var max_hp: float = 1.0

	func _mat(c: Color, emissive: float = 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		m.metallic = 0.15; m.roughness = 0.85
		return m

	func _add(mesh: Mesh, pos: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = m; mi.position = pos
		add_child(mi)
		return mi

	func build(data: Dictionary, _team: int, color: Color, hp: float) -> void:
		max_hp = maxf(hp, 1.0)
		var w: float = float(data.get("width", 4.2))
		var h: float = float(data.get("height", 1.5))
		var rock := _mat(Color(0.17, 0.12, 0.1))
		var main := BoxMesh.new(); main.size = Vector3(w, h, 0.8)
		_add(main, Vector3(0, h * 0.5, 0), rock)
		var stepm := BoxMesh.new(); stepm.size = Vector3(w * 0.7, h * 0.5, 0.7)
		_add(stepm, Vector3(0, h * 0.25, 0.75), rock)
		# Glowing cracks: thin emissive slivers on the front and top.
		var glow_c := Color(1.0, 0.42, 0.1).lerp(color, 0.15)
		for i in 6:
			var cm := _mat(glow_c, 3.0)
			cracks.append(cm)
			var sliver := BoxMesh.new(); sliver.size = Vector3(0.06, h * (0.35 + 0.1 * (i % 3)), 0.86)
			var mi := _add(sliver, Vector3(-w * 0.42 + i * w * 0.17, h * (0.3 + 0.08 * (i % 2)), 0), cm)
			mi.rotation.z = 0.25 * ((i % 2) * 2 - 1)
		var seam := BoxMesh.new(); seam.size = Vector3(w - 0.2, 0.08, 0.2)
		var sm := _mat(glow_c, 2.5)
		cracks.append(sm)
		_add(seam, Vector3(0, h, 0), sm)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.2)
		light.light_energy = 2.0
		light.omni_range = 5.0
		light.position = Vector3(0, h * 0.7, 0.6)
		add_child(light)

	func set_health(h: float) -> void:
		var f := clampf(h / max_hp, 0.0, 1.0)
		for m: StandardMaterial3D in cracks:
			m.albedo_color.a = 0.4 + 0.6 * f

	func _process(delta: float) -> void:
		t += delta
		# Slag cools over its lifetime: the glow fades from furnace-orange to dull red.
		var cool := clampf(t / 6.0, 0.0, 1.0)
		for m: StandardMaterial3D in cracks:
			m.emission_energy_multiplier = lerpf(3.0, 0.4, cool)
		if light:
			light.light_energy = lerpf(2.2, 0.3, cool) + sin(t * 6.0) * 0.1
