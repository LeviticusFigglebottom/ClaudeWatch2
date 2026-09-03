extends RefCounted
## Lumen VFX: the sustained beam's origin and burn point, the Glint blind, the Prism mirror she
## plants, the Refract reposition and the Sunstroke ultimate.
## Palette: hard white-gold. Lumen is the brightest hero in the game and her effects are small and
## intense rather than large and soft, so they never wash out the beam itself.

const GOLD := Color(1.0, 0.9, 0.5)
const WHITE := Color(1.0, 0.98, 0.88)
const FADE := Color(1.0, 0.85, 0.4, 0.0)


static func register() -> void:
	# Beam origin: a tight, near-static bloom at the staff head. Deliberately small: the beam mesh
	# carries the read, and a big muzzle here would smear the aim point.
	VfxLibrary.register_builder(&"lumen_beam_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		return _emit(lib, 5, 0.14, Vector3(0, 0, 1), 10.0, Vector3.ZERO, 1.0, 3.0,
			0.3, 0.6, 0.15, VfxLibrary.flash_texture(), WHITE, FADE))
	VfxLibrary.register_builder(&"lumen_beam_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		# Where the beam lands: sparks shedding off a heated point, thrown back along the surface.
		var p := _emit(lib, 9, 0.28, Vector3(0, 0, 1), 55.0, Vector3(0, -7.0, 0), 3.0, 7.0,
			0.12, 0.3, 0.09, VfxLibrary.spark_texture(), WHITE, FADE)
		return p)
	# Glint: the blind. One hard flash, almost no travel.
	VfxLibrary.register_builder(&"lumen_glint_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 18, 0.3, Vector3(0, 0.1, 1), 70.0, Vector3.ZERO, 8.0, 16.0,
			0.5, 1.2, 0.3, VfxLibrary.flash_texture(), WHITE, FADE)
		return p)
	# Prism: planting the mirror. Facets scatter, then settle.
	VfxLibrary.register_builder(&"lumen_prism_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 22, 0.55, Vector3(0, 0.5, 1), 45.0, Vector3(0, -3.0, 0), 3.0, 7.0,
			0.2, 0.5, 0.16, VfxLibrary.spark_texture(), GOLD, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.angular_velocity_min = -260.0
		mat.angular_velocity_max = 260.0
		return p)
	# Refract: she steps through her own light. Collapse in, no outward spray.
	VfxLibrary.register_builder(&"lumen_refract_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 30, 0.4, Vector3(0, 1, 0), 180.0, Vector3.ZERO, 0.0, 0.5,
			0.25, 0.7, 0.2, VfxLibrary.soft_texture(), WHITE, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.8
		mat.radial_velocity_min = -11.0
		mat.radial_velocity_max = -5.0
		return p)
	# Sunstroke ultimate: overhead light. The cast throws a wide flat ring, the loop keeps her lit,
	# the end drops it away cleanly so the arena reads as "over".
	VfxLibrary.register_builder(&"lumen_sunstroke_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 130, 1.1, Vector3(0, 0.15, 0), 180.0, Vector3(0, 0.4, 0), 9.0, 20.0,
			0.6, 1.5, 0.42, VfxLibrary.ring_texture(), WHITE, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.0
		return p)
	VfxLibrary.register_builder(&"lumen_sunstroke_loop", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 36, 1.0, Vector3(0, -1, 0), 22.0, Vector3(0, -1.5, 0), 2.0, 5.0,
			0.25, 0.6, 0.14, VfxLibrary.soft_texture(), GOLD, FADE)
		p.one_shot = false
		p.explosiveness = 0.0
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.4
		return p)
	VfxLibrary.register_builder(&"lumen_sunstroke_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 26, 0.6, Vector3(0, -1, 0), 60.0, Vector3(0, -4.0, 0), 1.0, 4.0,
			0.3, 0.8, 0.2, VfxLibrary.soft_texture(), GOLD, FADE)
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
