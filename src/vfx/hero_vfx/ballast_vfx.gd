extends RefCounted
## Ballast VFX: Riptide vortex (ult signature), wave-cannon spray muzzle, anchor impact spray.
## Loaded by VfxLibrary.load_extensions(); all recipes are tinted by the caller's color.

static func register() -> void:
	VfxLibrary.register_builder(&"ballast_riptide", func(lib: VfxLibrary) -> GPUParticles3D: return _riptide(lib))
	VfxLibrary.register_builder(&"ballast_riptide_end", func(lib: VfxLibrary) -> GPUParticles3D: return _riptide_end(lib))
	VfxLibrary.register_builder(&"ballast_wave_muzzle", func(lib: VfxLibrary) -> GPUParticles3D: return _wave_muzzle(lib))
	VfxLibrary.register_builder(&"ballast_anchor_impact", func(lib: VfxLibrary) -> GPUParticles3D: return _anchor_impact(lib))
	VfxLibrary.register_builder(&"ballast_surge_cast", func(lib: VfxLibrary) -> GPUParticles3D: return _surge(lib))


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


## A ring of water motes spiralling inward toward the caster's feet (attached to the pawn on cast).
static func _riptide(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 140, 2.6, 0.35, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.2
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 9.0
	mat.emission_ring_inner_radius = 3.0
	mat.emission_ring_height = 0.6
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.8
	mat.radial_velocity_min = -7.0
	mat.radial_velocity_max = -3.5
	mat.gravity = Vector3(0, -0.4, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	return p


## Closing burst: a column of spray thrown upward.
static func _riptide_end(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 90, 1.3, 0.45, VfxLibrary.soft_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 1.2
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -9, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.6
	return p


static func _wave_muzzle(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 14, 0.18, 0.16, VfxLibrary.flash_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 24.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.5
	mat.scale_max = 1.3
	return p


static func _anchor_impact(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 22, 0.45, 0.14, VfxLibrary.spark_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 70.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -8, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.7
	return p


static func _surge(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 30, 0.7, 0.3, VfxLibrary.ring_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.3
	mat.initial_velocity_max = 1.2
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	return p
