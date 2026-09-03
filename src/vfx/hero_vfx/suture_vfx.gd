extends RefCounted
## Suture VFX: the stapler's mechanical shots, the bandage burst that lands on an ally, the tether
## she runs to a patient, Adrenaline and the Triage ultimate.
## Palette: clinical mint for anything that heals, and her red cross accent for the shots, so a
## teammate can tell at a glance whether a Suture effect is aimed at them or at the enemy.

const MINT := Color(0.55, 0.92, 0.75)
const PALE := Color(0.85, 1.0, 0.92)
const RED := Color(0.9, 0.28, 0.32)
const FADE_MINT := Color(0.5, 1.0, 0.8, 0.0)
const FADE_RED := Color(0.9, 0.3, 0.35, 0.0)


static func register() -> void:
	# Volley: the stapler. Hard, small, mechanical; brass-red rather than mint because it damages.
	VfxLibrary.register_builder(&"suture_volley_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		return _emit(lib, 5, 0.12, Vector3(0, 0, 1), 12.0, Vector3(0, -3.0, 0), 5.0, 9.0,
			0.2, 0.45, 0.11, VfxLibrary.flash_texture(), Color(1.0, 0.85, 0.7), FADE_RED))
	VfxLibrary.register_builder(&"suture_staple_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		# A staple biting in: two or three metal flecks, nothing soft.
		var p := _emit(lib, 6, 0.22, Vector3(0, 0, 1), 45.0, Vector3(0, -9.0, 0), 2.5, 6.0,
			0.1, 0.22, 0.08, VfxLibrary.spark_texture(), Color(1.0, 0.9, 0.8), FADE_RED)
		return p)
	# Bandage: the heal landing on an ally. Reads as a soft mint wrap closing inward.
	VfxLibrary.register_builder(&"suture_bandage_burst", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 20, 0.5, Vector3(0, 1, 0), 180.0, Vector3(0, 0.6, 0), 0.0, 0.8,
			0.3, 0.75, 0.18, VfxLibrary.soft_texture(), PALE, FADE_MINT)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.1
		mat.radial_velocity_min = -3.5
		mat.radial_velocity_max = -1.0
		return p)
	# Tether: struck between her and a patient. A quick pull of motes along the run.
	VfxLibrary.register_builder(&"suture_tether_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 16, 0.4, Vector3(0, 0.2, 1), 20.0, Vector3.ZERO, 6.0, 12.0,
			0.2, 0.5, 0.13, VfxLibrary.spark_texture(), MINT, FADE_MINT)
		return p)
	# Adrenaline: a sharp lift on one ally. Fast upward spikes, brief.
	VfxLibrary.register_builder(&"suture_adrenaline_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 24, 0.45, Vector3(0, 1, 0), 24.0, Vector3(0, 2.0, 0), 4.0, 9.0,
			0.2, 0.55, 0.14, VfxLibrary.spark_texture(), PALE, FADE_MINT)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.6
		return p)
	# Triage ultimate: a wide, calm dome of mint light rather than a blast.
	VfxLibrary.register_builder(&"suture_triage_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 110, 1.3, Vector3(0, 0.5, 0), 180.0, Vector3(0, 0.5, 0), 4.0, 11.0,
			0.5, 1.3, 0.36, VfxLibrary.ring_texture(), PALE, FADE_MINT)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.3
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
