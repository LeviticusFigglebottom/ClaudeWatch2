class_name SableVfx
## Sable presentation: shadow-step puffs for Lunge/Vault, the Requiem cast burst and the dark
## afterimage loop that rides on her while the ultimate runs.


static func register() -> void:
	VfxLibrary.register_builder(&"sable_shadow_step", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 1.0; p.amount = 18; p.lifetime = 0.45
		m.direction = Vector3(0, 1, 0); m.spread = 180.0; m.gravity = Vector3(0, 0.5, 0)
		m.initial_velocity_min = 0.5; m.initial_velocity_max = 2.0
		m.scale_min = 0.5; m.scale_max = 1.1
		m.color_ramp = _ramp(Color(0.35, 0.15, 0.55, 0.8), Color(0.1, 0.05, 0.2, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.4, VfxLibrary.soft_texture(), false)
		return p)
	VfxLibrary.register_builder(&"sable_requiem_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 1.0; p.amount = 64; p.lifetime = 0.9
		m.direction = Vector3(0, 1, 0); m.spread = 180.0; m.gravity = Vector3(0, -1, 0)
		m.initial_velocity_min = 4.0; m.initial_velocity_max = 12.0
		m.scale_min = 0.2; m.scale_max = 0.6
		m.color_ramp = _ramp(Color(0.9, 0.6, 1.0, 1), Color(0.4, 0.1, 0.6, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.22, VfxLibrary.spark_texture())
		return p)
	VfxLibrary.register_builder(&"sable_requiem_loop", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = false; p.explosiveness = 0.0; p.amount = 40; p.lifetime = 0.5
		m.direction = Vector3(0, 0, 1); m.spread = 180.0; m.gravity = Vector3.ZERO
		m.initial_velocity_min = 0.0; m.initial_velocity_max = 0.6
		m.scale_min = 0.8; m.scale_max = 1.6
		m.color_ramp = _ramp(Color(0.5, 0.2, 0.8, 0.7), Color(0.1, 0.0, 0.2, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.5, VfxLibrary.soft_texture(), false)
		return p)

	# Requiem marks a victim: a tight violet brand that hangs on them rather than a burst.
	VfxLibrary.register_builder(&"sable_requiem_mark", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.9; p.amount = 22; p.lifetime = 0.8
		m.direction = Vector3(0, 1, 0); m.spread = 180.0; m.gravity = Vector3.ZERO
		m.initial_velocity_min = 0.0; m.initial_velocity_max = 0.6
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		m.emission_sphere_radius = 1.0
		m.radial_velocity_min = -2.5; m.radial_velocity_max = -0.8
		m.scale_min = 0.3; m.scale_max = 0.7
		m.color_ramp = _ramp(Color(0.75, 0.45, 1.0, 1), Color(0.3, 0.1, 0.5, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.26, VfxLibrary.ring_texture())
		return p)


static func _ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
