extends RefCounted
## Ferry VFX: the lantern bolt she fires, the waystone she plants, the Undertow pull and the
## Crossing ultimate that walks her team through the water.
## Palette: drowned-harbour cyan with a pale foam highlight; everything reads as lantern light
## seen through water rather than fire.

const CYAN := Color(0.45, 0.88, 0.92)
const FOAM := Color(0.8, 1.0, 0.98)
const FADE := Color(0.4, 0.85, 0.95, 0.0)


static func register() -> void:
	# Primary lantern bolt: a soft muzzle bloom, no crack.
	VfxLibrary.register_builder(&"ferry_bolt_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		return _emit(lib, 7, 0.2, Vector3(0, 0, 1), 16.0, Vector3.ZERO, 3.0, 6.5,
			0.35, 0.8, 0.19, VfxLibrary.soft_texture(), FOAM, FADE))
	VfxLibrary.register_builder(&"ferry_bolt_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		# Lands like a drop hitting water: a small crown of droplets and one ring.
		var p := _emit(lib, 12, 0.35, Vector3(0, 0, 1), 60.0, Vector3(0, -6.0, 0), 2.5, 6.0,
			0.2, 0.5, 0.13, VfxLibrary.spark_texture(), FOAM, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.radial_velocity_min = 1.5
		mat.radial_velocity_max = 4.0
		return p)
	# Waystone light: the healing beacon she plants.
	VfxLibrary.register_builder(&"ferry_light_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		return _emit(lib, 10, 0.3, Vector3(0, 0.2, 1), 24.0, Vector3.ZERO, 2.0, 5.0,
			0.4, 0.9, 0.22, VfxLibrary.ring_texture(), CYAN, FADE))
	VfxLibrary.register_builder(&"ferry_light_burst", func(lib: VfxLibrary) -> GPUParticles3D:
		# A gentle outward wash where the waystone's light reaches an ally.
		var p := _emit(lib, 22, 0.6, Vector3(0, 1, 0), 90.0, Vector3(0, 1.2, 0), 1.0, 3.5,
			0.35, 0.85, 0.2, VfxLibrary.soft_texture(), FOAM, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.8
		return p)
	VfxLibrary.register_builder(&"ferry_waystone_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Planting it: light sinks into the ground, then a ring settles outward.
		var p := _emit(lib, 26, 0.7, Vector3(0, -1, 0), 40.0, Vector3(0, -1.0, 0), 1.5, 4.0,
			0.3, 0.8, 0.24, VfxLibrary.ring_texture(), CYAN, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.0
		return p)
	# Undertow: the pull. Everything rushes inward and down, like a drain opening.
	VfxLibrary.register_builder(&"ferry_undertow_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 46, 0.8, Vector3(0, -0.3, 0), 180.0, Vector3(0, -2.0, 0), 0.0, 0.6,
			0.3, 0.9, 0.26, VfxLibrary.soft_texture(), CYAN, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 5.5
		mat.radial_velocity_min = -12.0
		mat.radial_velocity_max = -6.0
		mat.angular_velocity_min = 90.0
		mat.angular_velocity_max = 220.0
		return p)
	# Emitted by the Crossing area effect rather than a presentation field.
	VfxLibrary.register_builder(&"ferry_crossing_ring", func(lib: VfxLibrary) -> GPUParticles3D:
		return _emit(lib, 36, 0.9, Vector3(0, 0.1, 0), 180.0, Vector3.ZERO, 6.0, 12.0,
			0.5, 1.2, 0.36, VfxLibrary.ring_texture(), FOAM, FADE))
	# Crossing ultimate: the tide comes in. A tall standing column, then a slow bloom.
	VfxLibrary.register_builder(&"ferry_crossing_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 110, 1.4, Vector3(0, 1, 0), 26.0, Vector3(0, 1.4, 0), 5.0, 13.0,
			0.5, 1.4, 0.38, VfxLibrary.ring_texture(), FOAM, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.6
		return p)
	VfxLibrary.register_builder(&"ferry_crossing_loop", func(lib: VfxLibrary) -> GPUParticles3D:
		# Held: water light streaming up off her while the crossing is open.
		var p := _emit(lib, 40, 1.3, Vector3(0, 1, 0), 18.0, Vector3(0, 0.5, 0), 1.2, 3.0,
			0.3, 0.75, 0.16, VfxLibrary.soft_texture(), CYAN, FADE)
		p.one_shot = false
		p.explosiveness = 0.0
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.9
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
