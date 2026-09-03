extends RefCounted
## Cadence VFX: sub-bass shots that punch visible pressure rings, the Groove aura that pulses on the
## beat, the Discord debuff cone and the Anthem ultimate bloom.
## Palette: hot magenta with a paler pink highlight, so her effects read as sound made visible.

const MAGENTA := Color(0.95, 0.38, 0.72)
const PALE := Color(1.0, 0.72, 0.9)
const FADE := Color(0.95, 0.35, 0.8, 0.0)


static func register() -> void:
	# Primary: a bass slug. The muzzle is a pair of pressure rings rather than sparks.
	VfxLibrary.register_builder(&"cadence_bass_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 6, 0.22, Vector3(0, 0, 1), 6.0, Vector3.ZERO, 6.0, 11.0,
			0.5, 1.1, 0.3, VfxLibrary.ring_texture(), PALE, FADE)
		return p)
	VfxLibrary.register_builder(&"cadence_bass_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		# The slug lands as a shockwave: one wide ring plus a low spray of dust.
		var p := _emit(lib, 14, 0.4, Vector3(0, 0, 1), 90.0, Vector3(0, -4.0, 0), 3.0, 7.0,
			0.4, 1.0, 0.22, VfxLibrary.ring_texture(), MAGENTA, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.radial_velocity_min = 3.0
		mat.radial_velocity_max = 8.0
		return p)
	# Discord: a debuff thrown forward, tumbling shards of off-key sound.
	VfxLibrary.register_builder(&"cadence_discord_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 20, 0.5, Vector3(0, 0.15, 1), 34.0, Vector3(0, -1.5, 0), 5.0, 10.0,
			0.25, 0.65, 0.19, VfxLibrary.spark_texture(), Color(1.0, 0.5, 0.85), FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.angular_velocity_min = -220.0
		mat.angular_velocity_max = 220.0
		return p)
	# Crescendo: the charged shot. Cast pulls energy in, the loop shows it held.
	VfxLibrary.register_builder(&"cadence_crescendo_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 34, 0.55, Vector3(0, 1, 0), 180.0, Vector3.ZERO, 0.0, 0.4,
			0.3, 0.8, 0.24, VfxLibrary.soft_texture(), PALE, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 2.6
		mat.radial_velocity_min = -9.0
		mat.radial_velocity_max = -4.0
		return p)
	VfxLibrary.register_builder(&"cadence_crescendo", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _loop(lib, 26, 0.7, 0.9, 2.0, 0.15, VfxLibrary.spark_texture(), PALE, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.7
		return p)
	# Groove: the speed aura. Rings ride outward at ankle height on the beat.
	VfxLibrary.register_builder(&"cadence_aura", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _loop(lib, 18, 1.1, 2.4, 4.0, 0.34, VfxLibrary.ring_texture(), MAGENTA, FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.direction = Vector3(0, 0.1, 0)
		mat.spread = 180.0
		mat.gravity = Vector3.ZERO
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.4
		mat.radial_velocity_min = 2.0
		mat.radial_velocity_max = 4.5
		return p)
	# Anthem ultimate: a room-filling bloom of pink light.
	VfxLibrary.register_builder(&"cadence_anthem_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _emit(lib, 120, 1.2, Vector3(0, 0.4, 0), 180.0, Vector3(0, 0.8, 0), 7.0, 16.0,
			0.5, 1.3, 0.4, VfxLibrary.ring_texture(), Color(1.0, 0.8, 0.95), FADE)
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.2
		mat.angular_velocity_min = -120.0
		mat.angular_velocity_max = 120.0
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


## Continuously emitting variant for loop_vfx ids (VfxLibrary.attach_loop clears one_shot itself,
## but building it non-explosive here keeps the emission even rather than pulsing on attach).
static func _loop(lib: VfxLibrary, amount: int, life: float, vmin: float, vmax: float, size: float,
		tex: Texture2D, c0: Color, c1: Color) -> GPUParticles3D:
	var p := _emit(lib, amount, life, Vector3(0, 1, 0), 40.0, Vector3.ZERO, vmin, vmax, 0.3, 0.7, size, tex, c0, c1)
	p.one_shot = false
	p.explosiveness = 0.0
	return p
