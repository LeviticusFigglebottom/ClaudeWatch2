extends RefCounted
## Ricochet VFX: launcher muzzle/impact, Bank Shot prime, Skip cast and the Pinball signature burst
## (a spinning magenta fan of disc-sparks thrown out horizontally).


static func register() -> void:
	VfxLibrary.register_builder(&"ricochet_disc_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 8, 0.14, Vector3(0, 0, 1), 12.0, Vector3.ZERO, 3.0, 6.0, 0.4, 0.8, 0.16, VfxLibrary.ring_texture(), Color(1.0, 0.6, 0.9), Color(0.9, 0.3, 0.7, 0.0))
		return p)
	VfxLibrary.register_builder(&"ricochet_lob_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 10, 0.2, Vector3(0, 0.4, 1), 20.0, Vector3.ZERO, 2.0, 4.0, 0.5, 1.0, 0.2, VfxLibrary.ring_texture(), Color(1.0, 0.5, 0.85), Color(0.8, 0.2, 0.6, 0.0))
		return p)
	VfxLibrary.register_builder(&"ricochet_disc_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 12, 0.3, Vector3(0, 0, 1), 60.0, Vector3(0, -6, 0), 2.5, 6.0, 0.15, 0.35, 0.11, VfxLibrary.spark_texture(), Color(1.0, 0.8, 0.95), Color(1.0, 0.4, 0.8, 0.0))
		return p)
	VfxLibrary.register_builder(&"ricochet_bank_shot_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 18, 0.5, Vector3(0, 1, 0), 30.0, Vector3(0, 1, 0), 0.5, 1.5, 0.5, 0.9, 0.3, VfxLibrary.ring_texture(), Color(1.0, 0.5, 0.85), Color(1.0, 0.3, 0.7, 0.0))
		return p)
	VfxLibrary.register_builder(&"ricochet_skip_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 20, 0.45, Vector3(0, 1, 0), 70.0, Vector3(0, -3, 0), 2.0, 5.0, 0.3, 0.7, 0.25, VfxLibrary.soft_texture(), Color(1.0, 0.6, 0.9), Color(0.6, 0.6, 0.65, 0.0))
		return p)
	VfxLibrary.register_builder(&"ricochet_pinball_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Signature: a horizontal fan of spinning ring-sparks, like a hundred discs leaving at once.
		var p := _burst(lib, 110, 1.1, Vector3(0, 0.05, 1), 180.0, Vector3(0, -1.5, 0), 5.0, 12.0, 0.35, 0.8, 0.3, VfxLibrary.ring_texture(), Color(1.0, 0.55, 0.9), Color(1.0, 0.3, 0.75, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.5
		mat.angular_velocity_min = -360.0
		mat.angular_velocity_max = 360.0
		mat.damping_min = 2.0
		mat.damping_max = 5.0
		return p)
	VfxLibrary.register_builder(&"ricochet_pinball_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 26, 0.6, Vector3(0, 1, 0), 90.0, Vector3(0, -2, 0), 1.0, 3.0, 0.3, 0.6, 0.22, VfxLibrary.ring_texture(), Color(1.0, 0.5, 0.85), Color(1.0, 0.3, 0.7, 0.0))
		return p)


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
