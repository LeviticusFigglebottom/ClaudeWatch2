extends RefCounted
## Wisp VFX: needle muzzle/impact, Mark and Fold casts, the Mark deployable visual (a floating
## survey glyph) and the Displacement signature burst (space folding inward, then a mint ring).


class MarkerVisual extends Node3D:
	var spin: Node3D
	var glyph: MeshInstance3D
	var light: OmniLight3D
	var t: float = 0.0

	func build(team: int, color: Color) -> void:
		var team_col := RF.team_color(team)
		var pad := CylinderMesh.new(); pad.top_radius = 0.55; pad.bottom_radius = 0.6; pad.height = 0.04
		var pm := MeshInstance3D.new(); pm.mesh = pad; pm.material_override = _mat(team_col.lerp(color, 0.4), 1.2, 0.6)
		pm.position.y = 0.02
		add_child(pm)
		spin = Node3D.new(); spin.position.y = 1.1; add_child(spin)
		var ring := TorusMesh.new(); ring.inner_radius = 0.32; ring.outer_radius = 0.38
		var rm := MeshInstance3D.new(); rm.mesh = ring; rm.material_override = _mat(color, 2.2, 1.0)
		rm.rotation.x = PI * 0.5
		spin.add_child(rm)
		var ring2 := TorusMesh.new(); ring2.inner_radius = 0.22; ring2.outer_radius = 0.26
		var rm2 := MeshInstance3D.new(); rm2.mesh = ring2; rm2.material_override = _mat(color, 2.2, 1.0)
		rm2.rotation.z = PI * 0.5
		spin.add_child(rm2)
		var pr := PrismMesh.new(); pr.size = Vector3(0.22, 0.34, 0.22)
		glyph = MeshInstance3D.new(); glyph.mesh = pr; glyph.material_override = _mat(Color(0.95, 1.0, 0.98), 3.0, 1.0)
		spin.add_child(glyph)
		light = OmniLight3D.new(); light.light_color = color; light.light_energy = 1.3; light.omni_range = 4.5
		light.position.y = 1.1
		add_child(light)

	func _mat(c: Color, emissive: float, alpha: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
		m.metallic = 0.2
		m.roughness = 0.5
		return m

	func set_health(_h: float) -> void:
		pass

	func _process(delta: float) -> void:
		t += delta
		if spin:
			spin.rotation.y += delta * 1.6
			spin.position.y = 1.1 + sin(t * 2.0) * 0.08
		if glyph:
			glyph.rotation.y -= delta * 3.0


static func register() -> void:
	DeployableVisuals.register(&"wisp_marker", func(_kind: StringName, _data: Dictionary, team: int, color: Color, _max_hp: float) -> Node3D:
		var n := MarkerVisual.new()
		n.build(team, color)
		return n)
	VfxLibrary.register_builder(&"wisp_needle_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 4, 0.1, Vector3(0, 0, 1), 8.0, Vector3.ZERO, 3.0, 6.0, 0.35, 0.6, 0.1, VfxLibrary.flash_texture(), Color(0.9, 1.0, 0.95), Color(0.5, 1.0, 0.85, 0.0))
		return p)
	VfxLibrary.register_builder(&"wisp_exchange_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 12, 0.25, Vector3(0, 0, 1), 20.0, Vector3.ZERO, 1.0, 3.0, 0.4, 0.8, 0.2, VfxLibrary.ring_texture(), Color(0.8, 1.0, 0.92), Color(0.5, 1.0, 0.85, 0.0))
		return p)
	VfxLibrary.register_builder(&"wisp_needle_impact", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 8, 0.25, Vector3(0, 0, 1), 40.0, Vector3(0, -5, 0), 2.0, 5.0, 0.1, 0.25, 0.09, VfxLibrary.spark_texture(), Color(0.9, 1.0, 0.95), Color(0.5, 1.0, 0.85, 0.0))
		return p)
	VfxLibrary.register_builder(&"wisp_mark_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 16, 0.6, Vector3(0, 1, 0), 20.0, Vector3(0, 1.5, 0), 0.5, 2.0, 0.3, 0.6, 0.22, VfxLibrary.ring_texture(), Color(0.7, 1.0, 0.9), Color(0.5, 1.0, 0.85, 0.0))
		return p)
	VfxLibrary.register_builder(&"wisp_fold_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 22, 0.45, Vector3(0, 1, 0), 180.0, Vector3.ZERO, 0.0, 0.5, 0.3, 0.7, 0.24, VfxLibrary.soft_texture(), Color(0.8, 1.0, 0.95), Color(0.5, 1.0, 0.85, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 1.2
		mat.radial_velocity_min = -5.0
		mat.radial_velocity_max = -2.0
		return p)
	VfxLibrary.register_builder(&"wisp_displacement_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		# Signature: a 10 m shell of glyph-sparks collapsing into Wisp over 1.3 s.
		var p := _burst(lib, 140, 1.3, Vector3(0, 1, 0), 180.0, Vector3.ZERO, 0.0, 0.3, 0.4, 0.9, 0.35, VfxLibrary.ring_texture(), Color(0.75, 1.0, 0.92), Color(0.4, 1.0, 0.85, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 9.0
		mat.radial_velocity_min = -14.0
		mat.radial_velocity_max = -7.0
		mat.angular_velocity_min = -180.0
		mat.angular_velocity_max = 180.0
		return p)
	VfxLibrary.register_builder(&"wisp_displacement_end", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := _burst(lib, 30, 0.7, Vector3(0, 0.1, 1), 180.0, Vector3.ZERO, 6.0, 12.0, 0.5, 1.0, 0.4, VfxLibrary.soft_texture(), Color(0.8, 1.0, 0.95), Color(0.4, 1.0, 0.85, 0.0))
		return p)
	VfxLibrary.register_builder(&"wisp_displacement_explosion", func(lib: VfxLibrary) -> GPUParticles3D:
		# Where the fold closes: space snapping back, thrown outward rather than collapsing in.
		var p := _burst(lib, 70, 0.6, Vector3(0, 0.2, 0), 180.0, Vector3(0, -3.0, 0), 8.0, 18.0,
			0.3, 0.8, 0.26, VfxLibrary.ring_texture(), Color(0.85, 1.0, 0.95), Color(0.4, 1.0, 0.85, 0.0))
		var mat := p.process_material as ParticleProcessMaterial
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		mat.emission_sphere_radius = 0.9
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
