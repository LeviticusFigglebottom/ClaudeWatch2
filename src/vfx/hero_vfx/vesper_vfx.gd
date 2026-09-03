extends RefCounted
## Vesper VFX: the thrown lantern's pooled light (an area effect that lingers where it lands) and
## the Long Night ultimate glow that hangs on her while the lantern network is lit.
## Palette: her amber lamplight, warm at the core and dropping to a dim ember at the edges.

const AMBER := Color(0.98, 0.78, 0.35)
const EMBER := Color(1.0, 0.55, 0.2)


static func register() -> void:
	VfxLibrary.register_builder(&"lantern_light", func(lib: VfxLibrary) -> GPUParticles3D:
		# Motes drifting up out of the lantern pool: slow, sparse, no gravity fight.
		var p := _emit(lib, 26, 2.4, Vector3(0, 1, 0), 32.0, Vector3(0, 0.25, 0), 0.35, 1.1,
			0.3, 0.7, 0.16, VfxLibrary.soft_texture(), AMBER, Color(EMBER.r, EMBER.g, EMBER.b, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 2.4
		mat.angular_velocity_min = -30.0
		mat.angular_velocity_max = 30.0
		return p)
	VfxLibrary.register_builder(&"long_night_glow", func(lib: VfxLibrary) -> GPUParticles3D:
		# Ultimate: a steady updraught of sparks around Vesper, brighter and faster than the pool.
		var p := _emit(lib, 44, 1.5, Vector3(0, 1, 0), 20.0, Vector3(0, 0.6, 0), 0.8, 2.2,
			0.25, 0.6, 0.13, VfxLibrary.spark_texture(), Color(1.0, 0.9, 0.6), Color(AMBER.r, AMBER.g, AMBER.b, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.85
		mat.radial_velocity_min = 0.4
		mat.radial_velocity_max = 1.6
		return p)


static func _emit(lib: VfxLibrary, amount: int, life: float, dir: Vector3, spread: float, grav: Vector3,
		vmin: float, vmax: float, smin: float, smax: float, size: float, tex: Texture2D,
		c0: Color, c1: Color, add: bool = true) -> GPUParticles3D:
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
