extends RefCounted
## Cathedral VFX: Sanctuary bloom (ult signature), mace sparks, censer smoke, and the deployable
## visuals for the Stained-glass Wall and the Sanctuary dome.

static func register() -> void:
	VfxLibrary.register_builder(&"cathedral_sanctuary", func(lib: VfxLibrary) -> GPUParticles3D: return _sanctuary(lib))
	VfxLibrary.register_builder(&"cathedral_mace_impact", func(lib: VfxLibrary) -> GPUParticles3D: return _mace_impact(lib))
	VfxLibrary.register_builder(&"cathedral_censer", func(lib: VfxLibrary) -> GPUParticles3D: return _censer(lib))
	DeployableVisuals.register(&"cathedral_wall", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := WallVisual.new()
		v.build(data, team, color, max_hp)
		return v)
	DeployableVisuals.register(&"cathedral_sanctuary", func(_kind: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
		var v := DomeVisual.new()
		v.build(data, team, color, max_hp)
		return v)


static func _base(lib: VfxLibrary, amount: int, life: float, size: float, tex: Texture2D, add: bool = true) -> Array:
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = life
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	mat.color_ramp = rt
	p.draw_pass_1 = lib.mesh_quad(size, tex, add)
	p.process_material = mat
	p.set_meta("tint", true)
	return [p, mat]


## Golden motes rising from a 6 m ring (the dome's rim) — attached to Cathedral on cast.
static func _sanctuary(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 120, 2.2, 0.28, VfxLibrary.spark_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.5
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_axis = Vector3.UP
	mat.emission_ring_radius = 6.0
	mat.emission_ring_inner_radius = 5.4
	mat.emission_ring_height = 0.3
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 8.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.5
	mat.gravity = Vector3(0, 0.6, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	return p


static func _mace_impact(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 16, 0.3, 0.16, VfxLibrary.spark_texture())
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 80.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.3
	mat.scale_max = 0.6
	return p


static func _censer(lib: VfxLibrary) -> GPUParticles3D:
	var pair := _base(lib, 28, 1.0, 0.5, VfxLibrary.soft_texture(), false)
	var p: GPUParticles3D = pair[0]
	var mat: ParticleProcessMaterial = pair[1]
	p.explosiveness = 0.6
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.8
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.8
	mat.scale_max = 1.8
	return p


class WallVisual extends Node3D:
	var mats: Array[StandardMaterial3D] = []
	var max_hp: float = 1.0
	var light: OmniLight3D
	var t: float = 0.0

	func _mat(c: Color, emissive: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		m.metallic = 0.2; m.roughness = 0.35
		mats.append(m)
		return m

	func _add(mesh: Mesh, pos: Vector3, m: StandardMaterial3D) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = m; mi.position = pos
		add_child(mi)
		return mi

	func build(data: Dictionary, team: int, color: Color, hp: float) -> void:
		max_hp = maxf(hp, 1.0)
		var w: float = float(data.get("width", 6.0))
		var h: float = float(data.get("height", 3.2))
		var team_col := RF.team_color(team)
		var lead := _mat(Color(0.22, 0.2, 0.19), 0.0)
		# Lead frame: bottom sill, top rail, uprights.
		var rail := BoxMesh.new(); rail.size = Vector3(w + 0.3, 0.18, 0.32)
		_add(rail, Vector3(0, 0.09, 0), lead)
		_add(rail, Vector3(0, h, 0), lead)
		var post := BoxMesh.new(); post.size = Vector3(0.14, h, 0.3)
		var panes := 5
		for i in panes + 1:
			_add(post, Vector3(-w * 0.5 + i * w / panes, h * 0.5, 0), lead)
		var bar := BoxMesh.new(); bar.size = Vector3(w, 0.1, 0.28)
		_add(bar, Vector3(0, h * 0.62, 0), lead)
		# Glass panes: warm and cool glass tinted by team + accent, gently emissive.
		var palette := [Color(0.95, 0.35, 0.3), Color(0.35, 0.55, 0.98), Color(0.98, 0.82, 0.3), Color(0.45, 0.85, 0.5), Color(0.8, 0.45, 0.9)]
		for i in panes:
			var pane := BoxMesh.new(); pane.size = Vector3(w / panes - 0.16, h - 0.3, 0.1)
			var c: Color = (palette[i] as Color).lerp(team_col, 0.25).lerp(color, 0.15)
			_add(pane, Vector3(-w * 0.5 + w / panes * (i + 0.5), h * 0.5 + 0.06, 0), _mat(c, 1.1, 0.55))
		# Rose window in the middle pane.
		var rose := CylinderMesh.new(); rose.top_radius = 0.42; rose.bottom_radius = 0.42; rose.height = 0.14
		var rm := _add(rose, Vector3(0, h * 0.62, 0), _mat(Color(1.0, 0.9, 0.6), 2.4, 0.9))
		rm.rotation.x = PI * 0.5
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.55)
		light.light_energy = 1.4
		light.omni_range = 6.0
		light.position = Vector3(0, h * 0.6, 0.8)
		add_child(light)

	func set_health(h: float) -> void:
		var f := clampf(h / max_hp, 0.0, 1.0)
		for m: StandardMaterial3D in mats:
			if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				m.albedo_color.a = 0.2 + 0.4 * f
		if light:
			light.light_energy = 0.4 + 1.0 * f

	func _process(delta: float) -> void:
		t += delta
		if light:
			light.light_energy += sin(t * 4.0) * 0.02


class DomeVisual extends Node3D:
	var mats: Array[StandardMaterial3D] = []
	var max_hp: float = 1.0
	var shell: MeshInstance3D
	var ring: MeshInstance3D
	var light: OmniLight3D
	var t: float = 0.0
	var radius: float = 6.0

	func _mat(c: Color, emissive: float, alpha: float) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(c.r, c.g, c.b, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
		m.metallic = 0.1; m.roughness = 0.2
		mats.append(m)
		return m

	func build(data: Dictionary, team: int, color: Color, hp: float) -> void:
		max_hp = maxf(hp, 1.0)
		radius = float(data.get("radius", 6.0))
		var team_col := RF.team_color(team)
		var c := Color(1.0, 0.9, 0.62).lerp(team_col, 0.3).lerp(color, 0.2)
		shell = MeshInstance3D.new()
		var s := SphereMesh.new(); s.radius = radius; s.height = radius * 2.0; s.radial_segments = 32; s.rings = 16
		shell.mesh = s
		shell.material_override = _mat(c, 0.8, 0.18)
		shell.scale = Vector3(0.1, 0.1, 0.1)
		add_child(shell)
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = radius - 0.25; tm.outer_radius = radius + 0.05; tm.rings = 48
		ring.mesh = tm
		ring.material_override = _mat(Color(1.0, 0.85, 0.5), 2.5, 0.9)
		ring.position.y = 0.06
		add_child(ring)
		light = OmniLight3D.new()
		light.light_color = c
		light.light_energy = 2.5
		light.omni_range = radius * 1.6
		light.position.y = 2.0
		add_child(light)

	func set_health(h: float) -> void:
		var f := clampf(h / max_hp, 0.0, 1.0)
		if shell:
			(shell.material_override as StandardMaterial3D).albedo_color.a = 0.08 + 0.18 * f

	func _process(delta: float) -> void:
		t += delta
		if shell:
			var k := clampf(t / 0.35, 0.0, 1.0)
			var e := 1.0 - pow(1.0 - k, 3.0)
			shell.scale = Vector3.ONE * lerpf(0.1, 1.0, e)
		if ring:
			ring.rotation.y += delta * 0.6
		if light:
			light.light_energy = 2.2 + sin(t * 3.0) * 0.4
