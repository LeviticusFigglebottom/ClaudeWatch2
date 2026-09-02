class_name BrambleVfx
## Bramble presentation: vine bursts for Snare/Thicket, the Overgrowth eruption, and the thorn
## hedge deployable visual (a tangle of angled thorn stalks with a glowing sap band).


static func register() -> void:
	VfxLibrary.register_builder(&"bramble_vine_burst", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 1.0; p.amount = 26; p.lifetime = 0.6
		m.direction = Vector3(0, 1, 0); m.spread = 70.0; m.gravity = Vector3(0, -7, 0)
		m.initial_velocity_min = 3.0; m.initial_velocity_max = 8.0
		m.scale_min = 0.25; m.scale_max = 0.6
		m.color_ramp = _ramp(Color(0.6, 1.0, 0.4, 1), Color(0.2, 0.4, 0.1, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.22, VfxLibrary.spark_texture())
		return p)
	VfxLibrary.register_builder(&"bramble_overgrowth_cast", func(lib: VfxLibrary) -> GPUParticles3D:
		var p := GPUParticles3D.new()
		var m := ParticleProcessMaterial.new()
		p.one_shot = true; p.explosiveness = 0.85; p.amount = 90; p.lifetime = 1.4
		m.direction = Vector3(0, 1, 0); m.spread = 180.0; m.gravity = Vector3(0, 1.5, 0)
		m.initial_velocity_min = 5.0; m.initial_velocity_max = 13.0
		m.scale_min = 0.5; m.scale_max = 1.2
		m.color_ramp = _ramp(Color(0.5, 1.0, 0.35, 1), Color(0.1, 0.35, 0.05, 0))
		p.process_material = m
		p.draw_pass_1 = lib.mesh_quad(0.4, VfxLibrary.soft_texture())
		return p)
	DeployableVisuals.register(&"thicket_wall", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		return _build_hedge(data, team, color, max_hp))


static func _ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _build_hedge(data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
	var root := HedgeVisual.new()
	root.max_hp = max_hp
	var w: float = float(data.get("width", 6.0))
	var h: float = float(data.get("height", 2.2))
	var band: float = float(data.get("band", 1.2))
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.22, 0.16, 0.1); bark.roughness = 0.9
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.42, 0.16); leaf.roughness = 0.85
	var sap := StandardMaterial3D.new()
	sap.albedo_color = color; sap.emission_enabled = true; sap.emission = color; sap.emission_energy_multiplier = 1.6
	sap.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; sap.albedo_color.a = 0.55
	root.sap = sap
	var rng := RandomNumberGenerator.new()
	rng.seed = int(w * 100.0) + team
	var stalks := int(w * 2.5)
	for i in stalks:
		var x := -w * 0.5 + (float(i) + 0.5) * (w / float(stalks))
		var z := rng.randf_range(-band * 0.35, band * 0.35)
		var sh := h * rng.randf_range(0.7, 1.05)
		var stalk := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 0.03; cm.bottom_radius = 0.07; cm.height = sh; cm.radial_segments = 6
		stalk.mesh = cm
		stalk.material_override = bark
		stalk.position = Vector3(x, sh * 0.5, z)
		stalk.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0.0, rng.randf_range(-0.3, 0.3))
		root.add_child(stalk)
		for j in 3:
			var thorn := MeshInstance3D.new()
			var tm := CylinderMesh.new(); tm.top_radius = 0.0; tm.bottom_radius = 0.035; tm.height = 0.28; tm.radial_segments = 5
			thorn.mesh = tm
			thorn.material_override = leaf
			var ty := sh * (0.25 + 0.25 * j)
			thorn.position = Vector3(x, ty, z)
			thorn.rotation = Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.0, TAU), rng.randf_range(0.9, 1.6))
			root.add_child(thorn)
	var band_mesh := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(w, 0.12, band)
	band_mesh.mesh = bm
	band_mesh.material_override = sap
	band_mesh.position = Vector3(0, 0.06, 0)
	root.add_child(band_mesh)
	var light := OmniLight3D.new()
	light.light_color = color; light.light_energy = 0.8; light.omni_range = w * 0.6
	light.position = Vector3(0, 0.6, 0)
	root.add_child(light)
	return root


class HedgeVisual extends Node3D:
	var max_hp: float = 0.0
	var sap: StandardMaterial3D
	var t: float = 0.0
	func set_health(h: float) -> void:
		if sap and max_hp > 0.0:
			sap.albedo_color.a = 0.2 + 0.4 * clampf(h / max_hp, 0.0, 1.0)
	func _process(delta: float) -> void:
		t += delta
		if sap:
			sap.emission_energy_multiplier = 1.4 + 0.5 * sin(t * 3.0)
