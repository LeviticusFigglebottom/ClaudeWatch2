extends RefCounted
## Cairn VFX: Landslide dust wave (ult signature), rock impacts, and the rising-slab deployable
## visual (the client animates the rise locally from data.rise_time, mirroring CairnSlab.gd).

static func register() -> void:
	VfxLibrary.register_builder(&"cairn_landslide", func(lib: VfxLibrary) -> GPUParticles3D: return _landslide(lib))
	VfxLibrary.register_builder(&"cairn_rock_impact", func(lib: VfxLibrary) -> GPUParticles3D: return _rock_impact(lib))
	VfxLibrary.register_builder(&"cairn_rock_muzzle", func(lib: VfxLibrary) -> GPUParticles3D: return _rock_muzzle(lib))
	VfxLibrary.register_builder(&"cairn_slab_dust", func(lib: VfxLibrary) -> GPUParticles3D: return _slab_dust(lib))
	var slab := func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := SlabVisual.new()
		v.build(data, team, color, max_hp)
		return v
	DeployableVisuals.register(&"cairn_slab", slab)
	DeployableVisuals.register(&"cairn_wave_slab", slab)


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


## A low, wide wall of dust rolling outward (attached to Cairn on cast; omnidirectional so the
## emitter's orientation does not matter).
static func _landslide(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 110, 1.8, 0.9, VfxLibrary.soft_texture(), false)
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.8
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 1.5
	mat.emission_ring_inner_radius = 0.5
	mat.emission_ring_height = 0.4
	mat.direction = Vector3(0, 0.3, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.radial_velocity_min = 5.0
	mat.radial_velocity_max = 9.0
	mat.gravity = Vector3(0, -1.5, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.6
	return p


static func _rock_impact(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 26, 0.7, 0.2, VfxLibrary.soft_texture(), false)
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 65.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -9, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	return p


static func _rock_muzzle(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 8, 0.25, 0.25, VfxLibrary.soft_texture(), false)
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 40.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	return p


static func _slab_dust(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 30, 0.9, 0.5, VfxLibrary.soft_texture(), false)
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(1.2, 0.1, 1.2)
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 30.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, -3, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.5
	return p


class SlabVisual extends Node3D:
	var pillar: Node3D
	var height: float = 3.0
	var rise_time: float = 0.5
	var t: float = 0.0
	var cap_mat: StandardMaterial3D
	var max_hp: float = 1.0
	var risen: bool = false

	func _mat(c: Color, emissive: float = 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		m.metallic = 0.05; m.roughness = 0.9
		return m

	func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = m; mi.position = pos
		parent.add_child(mi)
		return mi

	func build(data: Dictionary, _team: int, color: Color, hp: float) -> void:
		max_hp = maxf(hp, 1.0)
		height = float(data.get("height", 3.0))
		rise_time = maxf(float(data.get("rise_time", 0.5)), 0.05)
		var w: float = float(data.get("width", 2.4))
		pillar = Node3D.new()
		add_child(pillar)
		pillar.position.y = -height   # buried; slides up in _process
		var stone := _mat(Color(0.46, 0.43, 0.38))
		var dark := _mat(Color(0.34, 0.31, 0.28))
		# Stacked, slightly offset blocks read as dry-stone masonry rather than a box.
		var layers := 4
		for i in layers:
			var lh := height / layers
			var b := BoxMesh.new(); b.size = Vector3(w * (0.94 + 0.06 * (i % 2)), lh - 0.04, w * (0.94 + 0.06 * ((i + 1) % 2)))
			_add(pillar, b, Vector3(0.04 * ((i % 2) * 2 - 1), lh * (i + 0.5), 0), stone if i % 2 == 0 else dark)
		cap_mat = _mat(color.lerp(Color(0.55, 0.75, 0.4), 0.5), 0.9)
		var cap := BoxMesh.new(); cap.size = Vector3(w + 0.12, 0.12, w + 0.12)
		_add(pillar, cap, Vector3(0, height, 0), cap_mat)
		# Moss / lichen accent on the top edge.
		var moss := BoxMesh.new(); moss.size = Vector3(w * 0.6, 0.05, 0.2)
		_add(pillar, moss, Vector3(0, height + 0.07, w * 0.4), _mat(Color(0.35, 0.6, 0.3)))

	func set_health(h: float) -> void:
		var f := clampf(h / max_hp, 0.0, 1.0)
		if cap_mat:
			cap_mat.emission_energy_multiplier = 0.2 + 0.8 * f

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / rise_time, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		pillar.position.y = lerpf(-height, 0.0, e)
		if k >= 1.0 and not risen:
			risen = true
