class_name HeroRig
extends Node3D
## Procedural articulated hero body. Parts are primitives shaped by HeroVisualData so each hero has a
## readable silhouette (build, head shape, extras) and a palette. Animation is procedural: walk cycle
## from speed, lean into acceleration, aim pitch on the torso, recoil, hit flash, death tumble.

var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var weapon: Node3D
var muzzle: Node3D
var extras_root: Node3D
var mats: Array[StandardMaterial3D] = []
var accent_mats: Array[StandardMaterial3D] = []
var emissive_mats: Array[StandardMaterial3D] = []
var muzzle_flash: MeshInstance3D
var flash_t: float = 0.0
var visual: HeroVisualData
var team: int = 0
var height: float = 1.85
var cycle: float = 0.0
var lean: Vector2 = Vector2.ZERO
var bob: float = 0.0
var base_hips_y: float = 0.95
var alpha: float = 1.0
var meshes: Array[MeshInstance3D] = []
const TP_WEAPON_SCALE := 0.8
var hidden_in_fp: bool = false
var status_light: OmniLight3D


func build(hero: HeroData, t: int) -> void:
	visual = hero.visual if hero.visual else HeroVisualData.new()
	team = t
	height = visual.height
	var bulk: float = [0.8, 1.0, 1.25, 1.55][visual.build]
	var h := height / 1.85
	# Materials
	var primary := _mat(visual.primary_color, visual.metallic, visual.roughness)
	var secondary := _mat(visual.secondary_color, visual.metallic * 0.6, visual.roughness + 0.15)
	var accent := _mat(visual.accent_color, 0.4, 0.4)
	accent_mats.append(accent)
	var team_col := RF.team_color(team)
	var team_mat := _mat(team_col.lerp(visual.accent_color, 0.35), 0.2, 0.5)
	team_mat.emission_enabled = true
	team_mat.emission = team_col
	team_mat.emission_energy_multiplier = 0.9
	var glow := _mat(visual.emissive_color if visual.emissive_color.a > 0 else team_col, 0.0, 0.3)
	glow.emission_enabled = true
	glow.emission = visual.emissive_color if visual.emissive_color.v > 0.05 else team_col
	glow.emission_energy_multiplier = visual.emissive_strength
	emissive_mats.append(glow)
	var skin := _mat(visual.skin_color, 0.0, 0.8)
	# Hierarchy
	hips = Node3D.new(); hips.name = "Hips"; add_child(hips)
	base_hips_y = 0.95 * h
	hips.position.y = base_hips_y
	torso = Node3D.new(); torso.name = "Torso"; hips.add_child(torso)
	head = Node3D.new(); head.name = "Head"; torso.add_child(head)
	arm_l = Node3D.new(); arm_l.name = "ArmL"; torso.add_child(arm_l)
	arm_r = Node3D.new(); arm_r.name = "ArmR"; torso.add_child(arm_r)
	leg_l = Node3D.new(); leg_l.name = "LegL"; hips.add_child(leg_l)
	leg_r = Node3D.new(); leg_r.name = "LegR"; hips.add_child(leg_r)
	extras_root = Node3D.new(); extras_root.name = "Extras"; torso.add_child(extras_root)
	var sw := visual.shoulder_width * bulk
	# Torso: a capsule + chest plate; heavy builds get a wider box body.
	var torso_h := 0.62 * h
	if visual.build >= HeroVisualData.Build.HEAVY:
		_box(torso, Vector3(sw * 0.95, torso_h, 0.42 * bulk), Vector3(0, torso_h * 0.5, 0), primary)
		_box(torso, Vector3(sw * 0.7, torso_h * 0.35, 0.46 * bulk), Vector3(0, torso_h * 0.75, 0.02), secondary)
	else:
		_capsule(torso, 0.19 * bulk * sw / 0.55, torso_h, Vector3(0, torso_h * 0.5, 0), primary)
		_box(torso, Vector3(sw * 0.62, torso_h * 0.42, 0.26 * bulk), Vector3(0, torso_h * 0.66, 0.04), secondary)
	# Chest emblem (team glow)
	_box(torso, Vector3(0.12, 0.12, 0.03), Vector3(0, torso_h * 0.7, -(0.15 * bulk + 0.08)), team_mat)
	# Belt
	_box(hips, Vector3(sw * 0.62, 0.08, 0.28 * bulk), Vector3(0, 0.02, 0), accent)
	# Shoulders
	var sh_y := torso_h * 0.92
	for side: float in [-1.0, 1.0]:
		var arm := arm_l if side < 0 else arm_r
		arm.position = Vector3(side * sw * 0.5, sh_y, 0)
		var pad_size := 0.14 * bulk
		if visual.extras.has(HeroVisualData.Extra.SHOULDER_PADS) or visual.build >= HeroVisualData.Build.HEAVY:
			_sphere(arm, pad_size * 1.25, Vector3(0, 0.02, 0), secondary)
		else:
			_sphere(arm, pad_size * 0.8, Vector3(0, 0, 0), primary)
		# Upper + lower arm
		var arm_len := 0.34 * h
		_capsule(arm, 0.065 * bulk, arm_len, Vector3(0, -arm_len * 0.5, 0), primary)
		var fore := Node3D.new(); fore.name = "Fore"; arm.add_child(fore)
		fore.position.y = -arm_len
		_capsule(fore, 0.06 * bulk, arm_len * 0.95, Vector3(0, -arm_len * 0.45, 0), visual.arms_color.a > 0 and _mat(visual.arms_color, 0.3, 0.6) or secondary)
		_sphere(fore, 0.07 * bulk, Vector3(0, -arm_len * 0.95, 0), skin if visual.head == HeroVisualData.HeadShape.BARE else secondary)
	# Legs
	var leg_len := 0.92 * h
	for side: float in [-1.0, 1.0]:
		var leg := leg_l if side < 0 else leg_r
		leg.position = Vector3(side * 0.13 * bulk, 0, 0)
		_capsule(leg, 0.085 * bulk, leg_len * 0.5, Vector3(0, -leg_len * 0.25, 0), secondary)
		var shin := Node3D.new(); shin.name = "Shin"; leg.add_child(shin)
		shin.position.y = -leg_len * 0.5
		_capsule(shin, 0.075 * bulk, leg_len * 0.48, Vector3(0, -leg_len * 0.24, 0), primary)
		_box(shin, Vector3(0.14 * bulk, 0.09, 0.26 * bulk), Vector3(0, -leg_len * 0.5 + 0.04, -0.05), accent)   # boot
	# Head
	head.position.y = torso_h + 0.06 * h
	_build_head(head, skin, primary, secondary, accent, glow, team_mat, bulk)
	# Extras (silhouette pieces)
	for e: HeroVisualData.Extra in visual.extras:
		_build_extra(e, primary, secondary, accent, glow, bulk, torso_h, sw)
	# Weapon in the right hand
	weapon = Node3D.new(); weapon.name = "Weapon"
	var fore_r: Node3D = arm_r.get_node("Fore")
	fore_r.add_child(weapon)
	weapon.position = Vector3(0, -0.34 * h, 0.0)
	weapon.rotation.x = -PI * 0.5   # forearm points forward once the arm swings up; align the barrel with it
	WeaponBuilder.build(weapon, visual.weapon_style, visual, team)
	# Third-person weapons read oversized at authored scale (the FP view has its own scale).
	var wscale := visual.weapon_scale * TP_WEAPON_SCALE
	weapon.scale = Vector3.ONE * wscale
	# Slide the model so its grip point sits in the hand (the weapon origin is the hand).
	var grip_local: Vector3 = WeaponBuilder.hand_points(visual.weapon_style)["grip"] * wscale
	weapon.position -= weapon.basis * grip_local
	_collect_meshes(weapon)   # weapon parts follow the body's layer/alpha handling (hidden from the FP camera)
	muzzle = weapon.get_node_or_null("Muzzle") as Node3D
	if muzzle == null:
		muzzle = Node3D.new(); muzzle.name = "Muzzle"; weapon.add_child(muzzle); muzzle.position = Vector3(0, 0, -0.6)
	muzzle_flash = MeshInstance3D.new()
	var fm := QuadMesh.new(); fm.size = Vector2(0.5, 0.5)
	muzzle_flash.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fmat.albedo_color = Color(1, 0.8, 0.4, 0.0)
	fmat.albedo_texture = VfxLibrary.flash_texture()
	muzzle_flash.material_override = fmat
	muzzle_flash.visible = false
	muzzle.add_child(muzzle_flash)
	status_light = OmniLight3D.new()
	status_light.light_energy = 0.0
	status_light.omni_range = 2.5
	status_light.position.y = torso_h * 0.5
	torso.add_child(status_light)
	# Stance
	match visual.stance:
		&"hunched": torso.rotation.x = -0.18
		&"brace": torso.rotation.x = -0.08
	arm_r.rotation.x = 1.35
	arm_l.rotation.x = 1.1
	arm_l.rotation.z = -0.25


func _build_head(node: Node3D, skin: StandardMaterial3D, primary: StandardMaterial3D, secondary: StandardMaterial3D, accent: StandardMaterial3D, glow: StandardMaterial3D, team_mat: StandardMaterial3D, bulk: float) -> void:
	var r := 0.115 * (0.9 + bulk * 0.12)
	match visual.head:
		HeroVisualData.HeadShape.HELMET_ROUND:
			_sphere(node, r * 1.1, Vector3(0, r, 0), primary)
			_box(node, Vector3(r * 1.6, r * 0.5, 0.05), Vector3(0, r * 0.9, -r * 0.95), glow)
		HeroVisualData.HeadShape.HELMET_VISOR:
			_box(node, Vector3(r * 1.9, r * 2.0, r * 2.0), Vector3(0, r, 0), primary)
			_box(node, Vector3(r * 1.7, r * 0.6, 0.06), Vector3(0, r * 1.1, -r * 1.0), glow)
			_box(node, Vector3(r * 0.5, r * 0.9, r * 0.5), Vector3(0, r * 2.2, 0), accent)
		HeroVisualData.HeadShape.HOOD:
			_sphere(node, r * 1.25, Vector3(0, r * 0.9, 0.02), secondary)
			_sphere(node, r * 0.85, Vector3(0, r * 0.75, -r * 0.5), Color(0.05, 0.05, 0.07))
			_box(node, Vector3(r * 0.6, r * 0.15, 0.04), Vector3(0, r * 0.8, -r * 1.15), glow)
		HeroVisualData.HeadShape.BARE:
			_sphere(node, r, Vector3(0, r, 0), skin)
			_sphere(node, r * 1.02, Vector3(0, r * 1.25, 0.03), secondary)   # hair cap
		HeroVisualData.HeadShape.DOME:
			_sphere(node, r * 1.35, Vector3(0, r * 0.9, 0), glow)
			_box(node, Vector3(r * 2.2, r * 0.3, r * 2.2), Vector3(0, r * 0.2, 0), secondary)
		HeroVisualData.HeadShape.LANTERN:
			_box(node, Vector3(r * 1.5, r * 2.4, r * 1.5), Vector3(0, r * 1.2, 0), secondary)
			_box(node, Vector3(r * 1.1, r * 1.6, r * 1.1), Vector3(0, r * 1.2, 0), glow)
			_box(node, Vector3(r * 1.9, r * 0.25, r * 1.9), Vector3(0, r * 2.5, 0), accent)
		HeroVisualData.HeadShape.DIVER:
			_sphere(node, r * 1.4, Vector3(0, r * 1.1, 0), primary)
			_cylinder(node, r * 0.75, 0.06, Vector3(0, r * 1.1, -r * 1.3), glow, Vector3(PI * 0.5, 0, 0))
			for a: float in [0.0, 2.1, 4.2]:
				_cylinder(node, r * 0.35, 0.08, Vector3(sin(a) * r * 1.35, r * 1.1 + cos(a) * r * 0.6, 0), accent, Vector3(0, 0, PI * 0.5))
		HeroVisualData.HeadShape.BEAKED:
			_sphere(node, r * 1.05, Vector3(0, r, 0), primary)
			_box(node, Vector3(r * 0.5, r * 0.5, r * 1.6), Vector3(0, r * 0.8, -r * 1.2), accent)
			_box(node, Vector3(r * 1.6, r * 0.35, 0.04), Vector3(0, r * 1.25, -r * 0.9), glow)
		HeroVisualData.HeadShape.CROWN:
			_sphere(node, r, Vector3(0, r, 0), skin)
			for i in 5:
				var a := float(i) / 5.0 * TAU
				_box(node, Vector3(0.04, r * 0.9, 0.04), Vector3(sin(a) * r * 0.85, r * 1.9, cos(a) * r * 0.85), accent)
			_cylinder(node, r * 0.95, 0.08, Vector3(0, r * 1.55, 0), accent)
		HeroVisualData.HeadShape.ANTENNA:
			_box(node, Vector3(r * 1.6, r * 1.8, r * 1.6), Vector3(0, r, 0), primary)
			_box(node, Vector3(r * 1.3, r * 0.4, 0.05), Vector3(0, r * 1.0, -r * 0.8), glow)
			_cylinder(node, 0.02, r * 2.0, Vector3(r * 0.5, r * 2.5, 0), accent)
			_sphere(node, 0.05, Vector3(r * 0.5, r * 3.5, 0), glow)


func _build_extra(e: HeroVisualData.Extra, primary: StandardMaterial3D, secondary: StandardMaterial3D, accent: StandardMaterial3D, glow: StandardMaterial3D, bulk: float, torso_h: float, sw: float) -> void:
	match e:
		HeroVisualData.Extra.CLOAK:
			var cloak := _box(extras_root, Vector3(sw * 0.9, torso_h * 1.5, 0.05), Vector3(0, torso_h * 0.15, 0.2 * bulk), secondary)
			cloak.name = "Cloak"
		HeroVisualData.Extra.BACKPACK:
			_box(extras_root, Vector3(sw * 0.55, torso_h * 0.7, 0.25), Vector3(0, torso_h * 0.5, 0.26 * bulk), secondary)
			_box(extras_root, Vector3(0.06, 0.06, 0.06), Vector3(sw * 0.2, torso_h * 0.75, 0.4 * bulk), glow)
		HeroVisualData.Extra.JETPACK:
			for side: float in [-1.0, 1.0]:
				_cylinder(extras_root, 0.09, torso_h * 0.8, Vector3(side * sw * 0.22, torso_h * 0.45, 0.24 * bulk), secondary)
				_cylinder(extras_root, 0.07, 0.08, Vector3(side * sw * 0.22, torso_h * 0.02, 0.24 * bulk), glow)
		HeroVisualData.Extra.SHOULDER_PADS:
			pass   # handled at shoulders
		HeroVisualData.Extra.TANK_CANISTERS:
			for side: float in [-1.0, 1.0]:
				_cylinder(extras_root, 0.12, torso_h * 0.9, Vector3(side * sw * 0.25, torso_h * 0.45, 0.3 * bulk), accent)
				_sphere(extras_root, 0.12, Vector3(side * sw * 0.25, torso_h * 0.9, 0.3 * bulk), secondary)
		HeroVisualData.Extra.WINGS:
			for side: float in [-1.0, 1.0]:
				var w := _box(extras_root, Vector3(0.5, 0.04, 0.22), Vector3(side * (sw * 0.5 + 0.25), torso_h * 0.8, 0.2), glow)
				w.rotation.z = side * 0.35
				w.name = "WingL" if side < 0 else "WingR"
		HeroVisualData.Extra.HALO:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new(); tm.inner_radius = 0.22; tm.outer_radius = 0.26
			ring.mesh = tm; ring.material_override = glow
			ring.position = Vector3(0, torso_h + 0.5, 0.05)
			ring.rotation.x = 0.4
			extras_root.add_child(ring)
			meshes.append(ring)
		HeroVisualData.Extra.TAIL:
			_capsule(extras_root, 0.05, 0.7, Vector3(0, 0.05, 0.45), secondary, Vector3(-1.2, 0, 0))
		HeroVisualData.Extra.BANNER:
			_cylinder(extras_root, 0.02, 1.4, Vector3(-sw * 0.35, torso_h * 0.7, 0.2), accent)
			_box(extras_root, Vector3(0.35, 0.5, 0.02), Vector3(-sw * 0.35 + 0.18, torso_h * 1.2, 0.2), glow)
		HeroVisualData.Extra.ANCHOR:
			_box(extras_root, Vector3(0.08, 0.7, 0.08), Vector3(0, torso_h * 0.4, 0.3 * bulk), accent)
			_box(extras_root, Vector3(0.5, 0.08, 0.08), Vector3(0, torso_h * 0.05, 0.3 * bulk), accent)
		HeroVisualData.Extra.VINES:
			for i in 4:
				var a := float(i) / 4.0 * TAU
				_capsule(extras_root, 0.03, 0.5, Vector3(sin(a) * sw * 0.4, torso_h * (0.3 + 0.15 * i), cos(a) * 0.2), accent, Vector3(0.5 * cos(a), 0, 0.5 * sin(a)))
		HeroVisualData.Extra.CANDLES:
			for i in 3:
				var x := (i - 1) * 0.16
				_cylinder(extras_root, 0.035, 0.22, Vector3(x, torso_h + 0.35, 0.22), accent)
				_sphere(extras_root, 0.04, Vector3(x, torso_h + 0.5, 0.22), glow)
		HeroVisualData.Extra.SPEAKERS:
			for side: float in [-1.0, 1.0]:
				_box(extras_root, Vector3(0.22, 0.3, 0.16), Vector3(side * (sw * 0.5 + 0.12), torso_h * 0.5, 0.18), secondary)
				_cylinder(extras_root, 0.08, 0.02, Vector3(side * (sw * 0.5 + 0.12), torso_h * 0.5, 0.09), glow, Vector3(PI * 0.5, 0, 0))
		HeroVisualData.Extra.PRISM:
			var prism := MeshInstance3D.new()
			var pm := PrismMesh.new(); pm.size = Vector3(0.3, 0.4, 0.3)
			prism.mesh = pm; prism.material_override = glow
			prism.position = Vector3(0, torso_h + 0.6, 0.1)
			extras_root.add_child(prism)
			meshes.append(prism)
			prism.name = "Prism"


## --- Mesh helpers ---------------------------------------------------------------------------------

func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = clampf(rough, 0.05, 1.0)
	mats.append(m)
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Variant, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat is StandardMaterial3D:
		mi.material_override = mat
	elif mat is Color:
		mi.material_override = _mat(mat, 0.0, 0.9)
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	meshes.append(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Variant, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _add_mesh(parent, b, pos, mat, rot)


func _sphere(parent: Node3D, r: float, pos: Vector3, mat: Variant) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 16; s.rings = 8
	return _add_mesh(parent, s, pos, mat)


func _capsule(parent: Node3D, r: float, h: float, pos: Vector3, mat: Variant, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CapsuleMesh.new(); c.radius = r; c.height = maxf(h, r * 2.0); c.radial_segments = 12; c.rings = 4
	return _add_mesh(parent, c, pos, mat, rot)


func _cylinder(parent: Node3D, r: float, h: float, pos: Vector3, mat: Variant, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 14
	return _add_mesh(parent, c, pos, mat, rot)


## --- Runtime -------------------------------------------------------------------------------------

func _collect_meshes(root: Node) -> void:
	for c: Node in root.get_children():
		if c is MeshInstance3D and not meshes.has(c):
			meshes.append(c as MeshInstance3D)
		_collect_meshes(c)


func set_layer_mask(mask: int) -> void:
	for m: MeshInstance3D in meshes:
		m.layers = mask


func set_first_person_hidden(hidden: bool) -> void:
	hidden_in_fp = hidden
	# The local body renders only on layer 2 (shadows still cast); the FP camera culls layer 2.
	for m: MeshInstance3D in meshes:
		m.layers = (1 << 1) if hidden else 1
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func set_alpha(a: float) -> void:
	if absf(a - alpha) < 0.01:
		return
	alpha = a
	for m: StandardMaterial3D in mats:
		if a < 0.99:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = 1.0


func set_status_glow(glows: Dictionary) -> void:
	if glows.is_empty():
		status_light.light_energy = lerpf(status_light.light_energy, 0.0, 0.2)
		return
	var c := Color(0, 0, 0)
	for k: Variant in glows.keys():
		c += glows[k] as Color
	c /= glows.size()
	status_light.light_color = c
	status_light.light_energy = lerpf(status_light.light_energy, 1.6, 0.2)


func set_hit_flash(hit: float, heal: float) -> void:
	for m: StandardMaterial3D in mats:
		if hit > 0.01:
			m.emission_enabled = true
			m.emission = Color(1, 0.55, 0.45)
			m.emission_energy_multiplier = hit * 1.4
		elif heal > 0.01:
			m.emission_enabled = true
			m.emission = Color(0.5, 1, 0.6)
			m.emission_energy_multiplier = heal * 0.8
		elif not emissive_mats.has(m) and m.emission_energy_multiplier > 0.0 and m.emission_enabled and (m.emission == Color(1, 0.55, 0.45) or m.emission == Color(0.5, 1, 0.6)):
			m.emission_enabled = false
			m.emission_energy_multiplier = 0.0


func muzzle_global() -> Vector3:
	return muzzle.global_position if muzzle else global_position + Vector3(0, 1.3, 0)


func flash_muzzle() -> void:
	flash_t = 0.06
	muzzle_flash.visible = true
	muzzle_flash.rotation.z = randf() * TAU
	(muzzle_flash.material_override as StandardMaterial3D).albedo_color.a = 0.9


func reset_pose() -> void:
	rotation = Vector3.ZERO
	position = Vector3.ZERO
	hips.position.y = base_hips_y
	hips.rotation = Vector3.ZERO
	torso.rotation = Vector3.ZERO
	set_alpha(1.0)


func animate(dt: float, s: Dictionary) -> void:
	var speed: float = s["speed"]
	var max_speed: float = maxf(s["max_speed"], 0.1)
	var norm := clampf(speed / max_speed, 0.0, 1.5)
	var grounded: bool = s["grounded"]
	var crouch: float = s["crouch"]
	var lm: Vector2 = s["local_move"]
	if grounded:
		cycle += dt * (6.5 + norm * 7.0) * norm
	else:
		cycle = lerpf(cycle, cycle, 0.0)
	# Legs: swing along the movement direction; strafing swings sideways.
	var swing := sin(cycle) * norm * 0.8
	var fwd_amt := clampf(lm.y / max_speed, -1.0, 1.0)
	var side_amt := clampf(lm.x / max_speed, -1.0, 1.0)
	if grounded:
		leg_l.rotation.x = swing * fwd_amt + (0.35 if crouch > 0.5 else 0.0)
		leg_r.rotation.x = -swing * fwd_amt + (0.35 if crouch > 0.5 else 0.0)
		leg_l.rotation.z = swing * side_amt * 0.5
		leg_r.rotation.z = swing * side_amt * 0.5
		var shin_l: Node3D = leg_l.get_node("Shin")
		var shin_r: Node3D = leg_r.get_node("Shin")
		shin_l.rotation.x = -maxf(sin(cycle + 1.0), 0.0) * norm * 0.9 - crouch * 0.6
		shin_r.rotation.x = -maxf(sin(cycle + PI + 1.0), 0.0) * norm * 0.9 - crouch * 0.6
	else:
		var vy: float = s["vy"]
		leg_l.rotation.x = lerpf(leg_l.rotation.x, 0.35 - clampf(vy * 0.05, -0.3, 0.3), 0.15)
		leg_r.rotation.x = lerpf(leg_r.rotation.x, -0.25 + clampf(vy * 0.05, -0.3, 0.3), 0.15)
		leg_l.rotation.z = lerpf(leg_l.rotation.z, 0.0, 0.1)
		leg_r.rotation.z = lerpf(leg_r.rotation.z, 0.0, 0.1)
	# Hips bob + crouch
	bob = absf(sin(cycle)) * norm * 0.05 if grounded else 0.0
	var target_y := base_hips_y - crouch * 0.42 + bob
	hips.position.y = lerpf(hips.position.y, target_y, 0.35)
	# Lean into movement (acceleration feel) and aim pitch on the torso.
	var target_lean := Vector2(side_amt, fwd_amt) * 0.12 * norm
	lean = lean.lerp(target_lean, 0.15)
	var pitch: float = s["pitch"]
	torso.rotation.x = -lean.y + crouch * 0.25 - pitch * 0.35 + (-0.18 if visual.stance == &"hunched" else 0.0)
	torso.rotation.z = lean.x
	head.rotation.x = -pitch * 0.5
	# Arms: weapon arm follows aim; off arm swings when running.
	var recoil: float = s["recoil"]
	var melee: float = s["melee"]
	var pose: StringName = s["pose"]
	var aim_x := 1.35 + pitch * 0.9 - recoil * 0.35
	arm_r.rotation.x = lerpf(arm_r.rotation.x, aim_x, 0.4)
	arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, 0.2)
	if melee > 0.0:
		arm_l.rotation.x = 2.2 - (1.0 - melee) * 1.2
		arm_l.rotation.z = -0.6
	elif pose == &"cast" or pose == &"throw":
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 2.4, 0.3)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.5, 0.3)
	elif pose == &"ult":
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 2.9, 0.3)
		arm_r.rotation.x = lerpf(arm_r.rotation.x, 2.9, 0.3)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.8, 0.3)
		arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.8, 0.3)
	elif grounded and norm > 0.2:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 1.0 + sin(cycle + PI) * norm * 0.5, 0.3)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.25, 0.2)
	else:
		arm_l.rotation.x = lerpf(arm_l.rotation.x, 1.1, 0.2)
		arm_l.rotation.z = lerpf(arm_l.rotation.z, -0.25, 0.2)
	# Stun/root wobble
	if s["stunned"]:
		head.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.2
	else:
		head.rotation.z = lerpf(head.rotation.z, 0.0, 0.2)
	# Hover: wings flap / jets tilt
	var wl := extras_root.get_node_or_null("WingL")
	if wl:
		var flap := sin(Time.get_ticks_msec() * 0.012) * (0.4 if not grounded else 0.08)
		(wl as Node3D).rotation.z = -0.35 - flap
		(extras_root.get_node("WingR") as Node3D).rotation.z = 0.35 + flap
	var cloak := extras_root.get_node_or_null("Cloak")
	if cloak:
		(cloak as Node3D).rotation.x = 0.15 + norm * 0.5 + (0.3 if not grounded else 0.0)
	var prism := extras_root.get_node_or_null("Prism")
	if prism:
		(prism as Node3D).rotation.y += dt * 1.5
		(prism as Node3D).position.y = 0.62 + 0.1 * sin(Time.get_ticks_msec() * 0.003) + 0.7
	# Muzzle flash decay
	if flash_t > 0.0:
		flash_t -= dt
		if flash_t <= 0.0:
			muzzle_flash.visible = false


func animate_death(t: float) -> void:
	# Crumple: tip over, sink a little, fade.
	var k := clampf(t / 0.6, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	rotation.x = e * -1.35
	hips.position.y = lerpf(base_hips_y, 0.25, e)
	position.y = lerpf(0.0, 0.3, e)
	arm_l.rotation.x = lerpf(arm_l.rotation.x, 0.3, 0.1)
	arm_r.rotation.x = lerpf(arm_r.rotation.x, 0.2, 0.1)
	if t > 3.5:
		set_alpha(clampf(1.0 - (t - 3.5) / 2.0, 0.0, 1.0))
