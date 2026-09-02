extends RefCounted
## Harrier VFX: jet-rig muzzle/impact recipes, Dive landing dust, Afterburn plume and the
## Strafing Run signature burst (an exhaust ring + a column of rising sparks).


static func register() -> void:
	VfxLibrary.register_builder(&"harrier_smg_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 5, 0.1, Vector3(0, 0, 1), 18.0, Vector3.ZERO, 2.0, 4.5, 0.5, 0.9, 0.13, VfxLibrary.flash_texture(), Color(0.85, 0.95, 1.0), Color(0.4, 0.7, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"harrier_smg_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 10, 0.3, Vector3(0, 0, 1), 50.0, Vector3(0, -7, 0), 3.0, 7.0, 0.12, 0.3, 0.1, VfxLibrary.spark_texture(), Color(0.9, 0.97, 1.0), Color(0.4, 0.75, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"harrier_rockets_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 14, 0.35, Vector3(0, 0, 1), 30.0, Vector3(0, 1, 0), 1.0, 3.0, 0.6, 1.3, 0.35, VfxLibrary.soft_texture(), Color(1.0, 0.75, 0.4), Color(0.4, 0.4, 0.45, 0.0), false)
		return p)
	VfxLibrary.register_builder(&"harrier_dive_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 16, 0.4, Vector3(0, 1, 0), 25.0, Vector3.ZERO, 3.0, 6.0, 0.3, 0.6, 0.2, VfxLibrary.soft_texture(), Color(0.5, 0.85, 1.0), Color(0.3, 0.6, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"harrier_dive_end", func(lib: VfxLibrary) -> GPUParticles3D:
		# Landing dust: a low, wide ring of grey puffs plus blue sparks.
		var p := _burst(lib, 28, 0.7, Vector3(0, 1, 0), 85.0, Vector3(0, -2, 0), 4.0, 9.0, 0.8, 1.6, 0.4, VfxLibrary.soft_texture(), Color(0.75, 0.75, 0.72), Color(0.6, 0.6, 0.6, 0.0), false)
		return p)
	VfxLibrary.register_builder(&"harrier_afterburn_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 30, 0.5, Vector3(0, -1, 0), 15.0, Vector3(0, 3, 0), 4.0, 8.0, 0.4, 0.9, 0.22, VfxLibrary.flash_texture(), Color(0.6, 0.9, 1.0), Color(0.2, 0.5, 1.0, 0.0))
		return p)
	VfxLibrary.register_builder(&"harrier_strafing_run_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Signature: a big orange-white exhaust bloom that keeps rising for 1.4 s.
		var p := _burst(lib, 90, 1.4, Vector3(0, 1, 0), 40.0, Vector3(0, 2.5, 0), 3.0, 11.0, 0.6, 1.5, 0.45, VfxLibrary.soft_texture(), Color(1.0, 0.72, 0.35), Color(0.4, 0.8, 1.0, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.9
		mat.angular_velocity_min = -90.0
		mat.angular_velocity_max = 90.0
		return p)
	VfxLibrary.register_builder(&"harrier_strafing_run_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 24, 0.6, Vector3(0, 1, 0), 60.0, Vector3(0, 1, 0), 1.0, 3.0, 0.8, 1.4, 0.5, VfxLibrary.soft_texture(), Color(0.5, 0.5, 0.55), Color(0.4, 0.4, 0.45, 0.0), false)
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
