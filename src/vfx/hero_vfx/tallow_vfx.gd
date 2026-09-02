class_name TallowVfx
## Tallow presentation: flame muzzle/impact, the Vigil cast recipe, the candle deployable visual
## (wax post, flickering flame, warm light, faint heal ring) and the Vigil ward (a soft halo of
## drifting embers that follows Tallow).


static func register() -> void:
	VfxLibrary.register_builder(&"tallow_flame_muzzle", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.9; p.amount = 8; p.lifetime = 0.18
		m.direction = Vector3(0, 0, 1); m.spread = 18.0; m.gravity = Vector3(0, 2, 0)
		m.initial_velocity_min = 2.0; m.initial_velocity_max = 4.0
		m.scale_min = 0.5; m.scale_max = 1.0
		m.color_ramp = _ramp(Color(1, 0.8, 0.4, 1), Color(1, 0.3, 0.05, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.18, VfxLibrary.flash_texture())
		return p)
	VfxLibrary.register_builder(&"tallow_flame_hit", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.95; p.amount = 16; p.lifetime = 0.4
		m.direction = Vector3(0, 1, 0); m.spread = 60.0; m.gravity = Vector3(0, 3, 0)
		m.initial_velocity_min = 1.0; m.initial_velocity_max = 3.5
		m.scale_min = 0.3; m.scale_max = 0.7
		m.color_ramp = _ramp(Color(1, 0.7, 0.3, 1), Color(0.6, 0.1, 0.0, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.2, VfxLibrary.soft_texture())
		return p)
	VfxLibrary.register_builder(&"tallow_vigil_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.7; p.amount = 80; p.lifetime = 1.6
		m.direction = Vector3(0, 1, 0); m.spread = 180.0; m.gravity = Vector3(0, 1.2, 0)
		m.initial_velocity_min = 2.0; m.initial_velocity_max = 9.0
		m.scale_min = 0.3; m.scale_max = 0.8
		m.color_ramp = _ramp(Color(1, 0.95, 0.75, 1), Color(1, 0.6, 0.2, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.3, VfxLibrary.spark_texture())
		return p)
	DeployableVisuals.register(&"tallow_candle", func(_kind: StringName, data: Dictionary, _team: int, color: Color, _max_hp: float) -> Node3D:
		return _build_candle(data, color))
	DeployableVisuals.register(&"tallow_vigil_ward", func(_kind: StringName, data: Dictionary, _team: int, color: Color, _max_hp: float) -> Node3D:
		return _build_ward(data, color))


static func _ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _unlit(c: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	if tex:
		m.albedo_texture = tex
	return m


static func _build_candle(data: Dictionary, color: Color) -> Node3D:
	var root := CandleVisual.new()
	var radius: float = float(data.get("radius", 6.0))
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color(0.93, 0.86, 0.72); wax.roughness = 0.6
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.1; pm.bottom_radius = 0.13; pm.height = 0.7; pm.radial_segments = 10
	post.mesh = pm
	post.material_override = wax
	post.position.y = 0.35
	root.add_child(post)
	var drip := MeshInstance3D.new()
	var dm := CylinderMesh.new(); dm.top_radius = 0.16; dm.bottom_radius = 0.2; dm.height = 0.06; dm.radial_segments = 10
	drip.mesh = dm
	drip.material_override = wax
	drip.position.y = 0.03
	root.add_child(drip)
	var flame := MeshInstance3D.new()
	var fm := SphereMesh.new(); fm.radius = 0.11; fm.height = 0.34
	flame.mesh = fm
	flame.material_override = _unlit(Color(color.r, color.g, color.b, 0.9))
	flame.position.y = 0.86
	flame.name = "Flame"
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = color; light.light_energy = 1.6; light.omni_range = radius
	light.position.y = 0.95
	light.name = "Light"
	root.add_child(light)
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(radius * 2.0, radius * 2.0)
	ring.mesh = q
	ring.material_override = _unlit(Color(color.r, color.g, color.b, 0.22), VfxLibrary.ring_texture())
	ring.rotation.x = -PI * 0.5
	ring.position.y = 0.06
	root.add_child(ring)
	root.flame = flame
	root.light = light
	return root


static func _build_ward(data: Dictionary, color: Color) -> Node3D:
	var root := WardVisual.new()
	var radius: float = float(data.get("radius", 12.0))
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(radius * 2.0, radius * 2.0)
	ring.mesh = q
	ring.material_override = _unlit(Color(color.r, color.g, color.b, 0.3), VfxLibrary.ring_texture())
	ring.rotation.x = -PI * 0.5
	ring.position.y = 0.08
	root.add_child(ring)
	root.ring = ring
	var halo := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.9; tm.outer_radius = 1.0; tm.rings = 32; tm.ring_segments = 8
	halo.mesh = tm
	halo.material_override = _unlit(Color(color.r, color.g, color.b, 0.7))
	halo.position.y = 2.3
	root.add_child(halo)
	root.halo = halo
	var light := OmniLight3D.new()
	light.light_color = color; light.light_energy = 1.2; light.omni_range = radius * 0.5
	light.position.y = 1.5
	root.add_child(light)
	return root


class CandleVisual extends Node3D:
	var flame: MeshInstance3D
	var light: OmniLight3D
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		var flicker := 0.85 + 0.15 * sin(t * 11.0) * sin(t * 3.7)
		if flame:
			flame.scale = Vector3(flicker, 1.0 + 0.25 * sin(t * 9.0), flicker)
		if light:
			light.light_energy = 1.4 + 0.5 * flicker
	func set_health(_h: float) -> void:
		pass


class WardVisual extends Node3D:
	var ring: MeshInstance3D
	var halo: MeshInstance3D
	var t: float = 0.0
	func _process(delta: float) -> void:
		t += delta
		if halo:
			halo.rotation.y += delta * 0.8
			halo.position.y = 2.3 + 0.1 * sin(t * 2.0)
		if ring:
			ring.scale = Vector3.ONE * (0.97 + 0.03 * sin(t * 4.0))
