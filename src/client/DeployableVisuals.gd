class_name DeployableVisuals
## Builds client-side visuals for deployables by kind/visual id.

static var custom: Dictionary = {}   # visual id -> Callable(kind, data, team, color, max_hp) -> Node3D


static func register(visual: StringName, builder: Callable) -> void:
	custom[visual] = builder


static func create(kind: StringName, visual: StringName, data: Dictionary, team: int, color: Color, max_hp: float) -> Node3D:
	VfxLibrary.load_extensions()
	var key := visual if visual != &"" else kind
	if custom.has(key):
		var n: Node3D = (custom[key] as Callable).call(kind, data, team, color, max_hp)
		if n:
			return n
	var root := DeployableVisual.new()
	root.kind = kind
	root.team = team
	root.color = color
	root.max_hp = max_hp
	root.hp = max_hp
	root.build(visual if visual != &"" else kind, data)
	return root


class DeployableVisual extends Node3D:
	var kind: StringName
	var team: int
	var color: Color
	var max_hp: float
	var hp: float
	var mats: Array[StandardMaterial3D] = []
	var spin_node: Node3D
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
		m.metallic = 0.4; m.roughness = 0.4
		mats.append(m)
		return m

	func _add(mesh: Mesh, pos: Vector3, m: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh; mi.material_override = m; mi.position = pos; mi.rotation = rot
		add_child(mi)
		return mi

	func build(visual: StringName, data: Dictionary) -> void:
		var team_col := RF.team_color(team)
		match visual:
			&"barrier_wall", &"barrier":
				var w: float = float(data.get("width", 5.0)); var h: float = float(data.get("height", 3.0))
				var box := BoxMesh.new(); box.size = Vector3(w, h, 0.12)
				_add(box, Vector3(0, h * 0.5, 0), _mat(team_col.lerp(color, 0.5), 1.2, 0.35))
				var frame := BoxMesh.new(); frame.size = Vector3(w + 0.2, 0.15, 0.25)
				_add(frame, Vector3(0, 0.07, 0), _mat(Color(0.2, 0.2, 0.22)))
				_add(frame, Vector3(0, h, 0), _mat(Color(0.2, 0.2, 0.22)))
			&"barrier_dome", &"dome":
				var r: float = float(data.get("radius", 5.0))
				var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0
				_add(s, Vector3(0, 0, 0), _mat(team_col.lerp(color, 0.5), 0.9, 0.22))
			&"glass_wall":
				var w: float = float(data.get("width", 6.0)); var h: float = float(data.get("height", 3.5))
				var box := BoxMesh.new(); box.size = Vector3(w, h, 0.15)
				_add(box, Vector3(0, h * 0.5, 0), _mat(color, 1.6, 0.5))
				for i in 4:
					var pane := BoxMesh.new(); pane.size = Vector3(w / 4.0 - 0.1, h - 0.3, 0.17)
					_add(pane, Vector3(-w * 0.5 + w / 8.0 + i * w / 4.0, h * 0.5, 0), _mat([Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.95), Color(0.95, 0.8, 0.3), Color(0.4, 0.85, 0.5)][i], 0.6, 0.35))
				var frame := BoxMesh.new(); frame.size = Vector3(w + 0.3, 0.2, 0.3)
				_add(frame, Vector3(0, h, 0), _mat(Color(0.5, 0.4, 0.2)))
			&"turret", &"tesla_node":
				var base := CylinderMesh.new(); base.top_radius = 0.35; base.bottom_radius = 0.45; base.height = 0.3
				_add(base, Vector3(0, 0.15, 0), _mat(Color(0.25, 0.25, 0.28)))
				spin_node = Node3D.new(); add_child(spin_node); spin_node.position.y = 0.5
				var head := SphereMesh.new(); head.radius = 0.28; head.height = 0.56
				var hm := MeshInstance3D.new(); hm.mesh = head; hm.material_override = _mat(color, 1.5)
				spin_node.add_child(hm)
				var coil := TorusMesh.new(); coil.inner_radius = 0.3; coil.outer_radius = 0.38
				var cm := MeshInstance3D.new(); cm.mesh = coil; cm.material_override = _mat(Color(0.7, 0.7, 0.75), 0.0)
				cm.position.y = 0.2
				spin_node.add_child(cm)
			&"totem", &"candle", &"wick":
				var post := CylinderMesh.new(); post.top_radius = 0.08; post.bottom_radius = 0.12; post.height = 0.9
				_add(post, Vector3(0, 0.45, 0), _mat(Color(0.35, 0.25, 0.15)))
				var flame := SphereMesh.new(); flame.radius = 0.16; flame.height = 0.4
				spin_node = Node3D.new(); add_child(spin_node); spin_node.position.y = 1.05
				var fm := MeshInstance3D.new(); fm.mesh = flame; fm.material_override = _mat(color, 3.0)
				spin_node.add_child(fm)
				var light := OmniLight3D.new(); light.light_color = color; light.light_energy = 1.5; light.omni_range = 6.0
				spin_node.add_child(light)
			&"mirror", &"prism_mirror":
				var pane := BoxMesh.new(); pane.size = Vector3(1.2, 1.6, 0.06)
				_add(pane, Vector3(0, 1.0, 0), _mat(Color(0.85, 0.9, 1.0), 0.5))
				var stand := CylinderMesh.new(); stand.top_radius = 0.05; stand.bottom_radius = 0.2; stand.height = 0.4
				_add(stand, Vector3(0, 0.2, 0), _mat(Color(0.3, 0.3, 0.35)))
			&"beacon", &"waystone", &"pad":
				var pad := CylinderMesh.new(); pad.top_radius = 1.1; pad.bottom_radius = 1.2; pad.height = 0.12
				_add(pad, Vector3(0, 0.06, 0), _mat(Color(0.2, 0.2, 0.24)))
				var ring := TorusMesh.new(); ring.inner_radius = 0.9; ring.outer_radius = 1.05
				spin_node = Node3D.new(); add_child(spin_node); spin_node.position.y = 0.3
				var rm := MeshInstance3D.new(); rm.mesh = ring; rm.material_override = _mat(color, 2.0)
				spin_node.add_child(rm)
				var light := OmniLight3D.new(); light.light_color = color; light.light_energy = 1.2; light.omni_range = 5.0
				spin_node.add_child(light)
			&"slab", &"pillar":
				var h: float = float(data.get("height", 2.5)); var w: float = float(data.get("width", 2.0))
				var box := BoxMesh.new(); box.size = Vector3(w, h, w * 0.6)
				_add(box, Vector3(0, h * 0.5, 0), _mat(Color(0.45, 0.42, 0.38)))
				var cap := BoxMesh.new(); cap.size = Vector3(w + 0.1, 0.12, w * 0.6 + 0.1)
				_add(cap, Vector3(0, h, 0), _mat(color, 0.8))
			&"slag", &"vent":
				var box := BoxMesh.new(); box.size = Vector3(float(data.get("width", 4.0)), float(data.get("height", 1.4)), 0.8)
				_add(box, Vector3(0, float(data.get("height", 1.4)) * 0.5, 0), _mat(Color(0.2, 0.12, 0.08)))
				var glow := BoxMesh.new(); glow.size = Vector3(float(data.get("width", 4.0)) - 0.2, 0.2, 0.9)
				_add(glow, Vector3(0, 0.3, 0), _mat(Color(1.0, 0.45, 0.1), 2.5))
			&"zipline", &"anchor_line":
				var box := BoxMesh.new(); box.size = Vector3(0.2, 0.2, 0.2)
				_add(box, Vector3(0, 0.1, 0), _mat(color, 1.0))
			&"speaker", &"amp":
				var box := BoxMesh.new(); box.size = Vector3(0.6, 0.9, 0.5)
				_add(box, Vector3(0, 0.45, 0), _mat(Color(0.12, 0.12, 0.14)))
				var cone := CylinderMesh.new(); cone.top_radius = 0.22; cone.bottom_radius = 0.22; cone.height = 0.05
				_add(cone, Vector3(0, 0.55, 0.26), _mat(color, 1.5), Vector3(PI * 0.5, 0, 0))
			&"spotter", &"drone":
				spin_node = Node3D.new(); add_child(spin_node); spin_node.position.y = 2.2
				var body := SphereMesh.new(); body.radius = 0.25; body.height = 0.5
				var bm := MeshInstance3D.new(); bm.mesh = body; bm.material_override = _mat(Color(0.3, 0.3, 0.35))
				spin_node.add_child(bm)
				var eye := SphereMesh.new(); eye.radius = 0.1; eye.height = 0.2
				var em := MeshInstance3D.new(); em.mesh = eye; em.material_override = _mat(color, 2.0); em.position = Vector3(0, 0, 0.22)
				spin_node.add_child(em)
			_:
				var box := BoxMesh.new(); box.size = Vector3(0.6, 0.6, 0.6)
				_add(box, Vector3(0, 0.3, 0), _mat(color, 1.0))

	func set_health(h: float) -> void:
		hp = h
		if max_hp > 0.0:
			var f := clampf(h / max_hp, 0.0, 1.0)
			for m: StandardMaterial3D in mats:
				if m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					m.albedo_color.a = 0.15 + 0.3 * f

	func _process(delta: float) -> void:
		t += delta
		if spin_node:
			spin_node.rotation.y += delta * 1.5
			spin_node.position.y += sin(t * 3.0) * 0.002
