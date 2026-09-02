extends RefCounted
## Rook VFX: Ground Zero implosion (ult signature), Lift shimmer, mortar muzzle/impact, and the
## gravity-well deployable visual (a dark core that swells over the charge time).

static func register() -> void:
	VfxLibrary.register_builder(&"rook_ground_zero", func(lib: VfxLibrary) -> GPUParticles3D: return _ground_zero(lib))
	VfxLibrary.register_builder(&"rook_lift", func(lib: VfxLibrary) -> GPUParticles3D: return _lift(lib))
	VfxLibrary.register_builder(&"rook_mortar_muzzle", func(lib: VfxLibrary) -> GPUParticles3D: return _mortar_muzzle(lib))
	VfxLibrary.register_builder(&"rook_mortar_impact", func(lib: VfxLibrary) -> GPUParticles3D: return _mortar_impact(lib))
	VfxLibrary.register_builder(&"rook_density_cast", func(lib: VfxLibrary) -> GPUParticles3D: return _density(lib))
	DeployableVisuals.register(&"rook_well", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := WellVisual.new()
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


## Everything falls inward: a wide ring of motes collapsing toward the caster (cast at Rook).
static func _ground_zero(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 150, 2.4, 0.3, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.3
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 8.0
	mat.emission_ring_inner_radius = 2.0
	mat.emission_ring_height = 2.5
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 10.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.0
	mat.radial_velocity_min = -9.0
	mat.radial_velocity_max = -4.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	return p


static func _lift(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 40, 0.8, 0.22, VfxLibrary.ring_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, 3.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	return p


static func _mortar_muzzle(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 12, 0.3, 0.3, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 35.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 4.0
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.3
	return p


static func _mortar_impact(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 40, 0.8, 0.45, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 90.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 5.0
	mat.radial_velocity_min = -3.0
	mat.radial_velocity_max = -1.0
	mat.gravity = Vector3(0, -2, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.6
	return p


static func _density(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 26, 0.6, 0.3, VfxLibrary.ring_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.5
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -6, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.1
	return p


class WellVisual extends Node3D:
	var core: MeshInstance3D
	var rings: Array[MeshInstance3D] = []
	var ground_ring: MeshInstance3D
	var light: OmniLight3D
	var t: float = 0.0
	var charge: float = 2.5
	var radius: float = 8.0

	func _mat(c: Color, emissive: float, alpha: float = 1.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		m.metallic = 0.0; m.roughness = 0.3
		return m

	func build(data: Dictionary, team: int, color: Color, _hp: float) -> void:
		charge = maxf(float(data.get("charge_time", 2.5)), 0.1)
		radius = float(data.get("radius", 8.0))
		var team_col := RF.team_color(team)
		var glow_c := Color(0.55, 0.35, 1.0).lerp(team_col, 0.25).lerp(color, 0.2)
		core = MeshInstance3D.new()
		var s := SphereMesh.new(); s.radius = 0.9; s.height = 1.8
		core.mesh = s
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(0.02, 0.01, 0.05)
		cm.metallic = 0.0; cm.roughness = 0.1
		core.material_override = cm
		core.position.y = 1.4
		add_child(core)
		for i in 3:
			var r := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 1.1 + i * 0.35; tm.outer_radius = 1.2 + i * 0.35; tm.rings = 40
			r.mesh = tm
			r.material_override = _mat(glow_c, 2.5 - i * 0.5, 0.85)
			r.position.y = 1.4
			r.rotation = Vector3(0.5 * i, 0.0, 0.3 * i)
			add_child(r)
			rings.append(r)
		ground_ring = MeshInstance3D.new()
		var gq := QuadMesh.new(); gq.size = Vector2(radius * 2.0, radius * 2.0)
		ground_ring.mesh = gq
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_texture = VfxLibrary.ring_texture()
		gm.albedo_color = Color(glow_c.r, glow_c.g, glow_c.b, 0.7)
		gm.cull_mode = BaseMaterial3D.CULL_DISABLED
		ground_ring.material_override = gm
		ground_ring.position.y = 0.08
		ground_ring.rotation.x = -PI * 0.5
		add_child(ground_ring)
		light = OmniLight3D.new()
		light.light_color = glow_c
		light.light_energy = 2.0
		light.omni_range = radius
		light.position.y = 1.6
		light.negative = false
		add_child(light)

	func _process(delta: float) -> void:
		t += delta
		var k := clampf(t / charge, 0.0, 1.0)
		if core:
			core.scale = Vector3.ONE * (0.6 + 1.2 * k) * (1.0 + 0.05 * sin(t * 18.0))
		for i in rings.size():
			var r := rings[i]
			r.rotation.y += delta * (1.5 + i * 0.8)
			r.rotation.x += delta * (0.4 + i * 0.3)
			r.scale = Vector3.ONE * (1.0 - 0.45 * k)
		if ground_ring:
			var s := 1.0 - 0.3 * k + 0.03 * sin(t * 12.0)
			ground_ring.scale = Vector3(s, s, 1.0)
		if light:
			light.light_energy = 2.0 + 3.0 * k + sin(t * 20.0) * 0.3 * k
