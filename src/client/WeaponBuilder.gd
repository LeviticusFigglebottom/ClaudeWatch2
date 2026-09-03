class_name WeaponBuilder
## Procedural weapon models by archetype. Used for both third-person hands and the first-person view.
## Every archetype defines a "Muzzle" child so tracers/flashes originate from the right place.

static func build(parent: Node3D, style: StringName, visual: HeroVisualData, team: int) -> void:
	var body := _mat(visual.secondary_color.darkened(0.2), 0.75, 0.35)
	var accent := _mat(visual.accent_color, 0.5, 0.4)
	var glow := _mat(visual.emissive_color if visual.emissive_color.v > 0.05 else RF.team_color(team), 0.0, 0.3)
	glow.emission_enabled = true
	glow.emission = glow.albedo_color
	glow.emission_energy_multiplier = 2.0
	var grip := _mat(Color(0.15, 0.13, 0.12), 0.1, 0.8)
	var muzzle := Node3D.new()
	muzzle.name = "Muzzle"
	var dark := _mat(visual.secondary_color.darkened(0.45), 0.6, 0.5)
	match style:
		&"rifle":
			# Receiver, handguard, barrel, angled magazine, stock, pistol grip, glowing sight rail.
			_box(parent, Vector3(0.05, 0.075, 0.46), Vector3(0, 0, -0.14), body)
			_box(parent, Vector3(0.046, 0.058, 0.3), Vector3(0, -0.004, -0.5), dark)
			_cyl(parent, 0.014, 0.28, Vector3(0, 0.012, -0.78), accent, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.03, 0.15, 0.07), Vector3(0, -0.1, -0.2), dark, Vector3(0.25, 0, 0))
			_box(parent, Vector3(0.04, 0.07, 0.22), Vector3(0, -0.01, 0.2), body)
			_box(parent, Vector3(0.05, 0.05, 0.06), Vector3(0, -0.035, 0.31), grip)
			_box(parent, Vector3(0.036, 0.11, 0.05), Vector3(0, -0.11, 0.0), grip, Vector3(-0.3, 0, 0))
			_box(parent, Vector3(0.024, 0.02, 0.3), Vector3(0, 0.048, -0.18), glow)
			_box(parent, Vector3(0.012, 0.03, 0.02), Vector3(0, 0.055, -0.62), accent)
			muzzle.position = Vector3(0, 0.012, -0.93)
		&"cannon":
			_cyl(parent, 0.07, 0.62, Vector3(0, 0, -0.32), body, Vector3(PI * 0.5, 0, 0))
			for i in 3:
				_cyl(parent, 0.085, 0.03, Vector3(0, 0, -0.42 - i * 0.09), dark, Vector3(PI * 0.5, 0, 0))
			_cyl(parent, 0.095, 0.14, Vector3(0, 0, -0.62), accent, Vector3(PI * 0.5, 0, 0))
			_cyl(parent, 0.05, 0.1, Vector3(0, 0, -0.72), glow, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.1, 0.12, 0.26), Vector3(0, -0.06, 0.06), dark)
			_box(parent, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.14, 0.06), grip, Vector3(-0.25, 0, 0))
			_box(parent, Vector3(0.14, 0.05, 0.16), Vector3(0, 0.07, -0.1), accent)
			muzzle.position = Vector3(0, 0, -0.8)
		&"staff":
			_cyl(parent, 0.02, 1.4, Vector3(0, 0.1, -0.2), body, Vector3(PI * 0.5, 0, 0))
			_cyl(parent, 0.026, 0.28, Vector3(0, 0.1, 0.3), grip, Vector3(PI * 0.5, 0, 0))
			_sphere(parent, 0.08, Vector3(0, 0.1, -0.95), glow)
			_box(parent, Vector3(0.12, 0.12, 0.03), Vector3(0, 0.1, -0.85), accent, Vector3(0, 0, PI * 0.25))
			_cyl(parent, 0.04, 0.05, Vector3(0, 0.1, 0.5), accent, Vector3(PI * 0.5, 0, 0))
			muzzle.position = Vector3(0, 0.1, -1.0)
		&"blades":
			_box(parent, Vector3(0.022, 0.07, 0.68), Vector3(0, 0, -0.42), accent)
			_box(parent, Vector3(0.008, 0.075, 0.6), Vector3(0, 0.005, -0.42), glow)
			_cyl(parent, 0.018, 0.16, Vector3(0, 0, 0.04), grip, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.14, 0.02, 0.03), Vector3(0, 0, -0.06), body)
			_sphere(parent, 0.022, Vector3(0, 0, 0.13), body)
			muzzle.position = Vector3(0, 0, -0.75)
		&"launcher":
			_cyl(parent, 0.055, 0.6, Vector3(0, 0.02, -0.25), body, Vector3(PI * 0.5, 0, 0))
			_cyl(parent, 0.075, 0.12, Vector3(0, 0.02, -0.55), accent, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.05, 0.11, 0.05), Vector3(0, -0.1, 0.0), grip, Vector3(-0.3, 0, 0))
			_cyl(parent, 0.095, 0.14, Vector3(0, 0.02, 0.12), dark, Vector3(PI * 0.5, 0, 0))   # drum
			_box(parent, Vector3(0.04, 0.06, 0.18), Vector3(0, 0.0, 0.26), body)
			_box(parent, Vector3(0.02, 0.015, 0.24), Vector3(0.05, 0.06, -0.24), glow)
			_box(parent, Vector3(0.04, 0.045, 0.2), Vector3(0, -0.05, -0.42), dark)   # foregrip rail
			muzzle.position = Vector3(0, 0.02, -0.65)
		&"pistols":
			_box(parent, Vector3(0.04, 0.06, 0.3), Vector3(0, 0, -0.12), body)
			_box(parent, Vector3(0.034, 0.11, 0.045), Vector3(0, -0.085, 0.02), grip, Vector3(-0.25, 0, 0))
			_cyl(parent, 0.012, 0.1, Vector3(0, 0.012, -0.31), accent, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.016, 0.016, 0.12), Vector3(0, 0.038, -0.15), glow)
			_box(parent, Vector3(0.03, 0.04, 0.04), Vector3(0, -0.02, -0.02), dark)   # trigger guard
			muzzle.position = Vector3(0, 0.012, -0.42)
		&"bow":
			_box(parent, Vector3(0.028, 0.5, 0.045), Vector3(0, 0.36, -0.14), body, Vector3(0.22, 0, 0))
			_box(parent, Vector3(0.028, 0.5, 0.045), Vector3(0, -0.36, -0.14), body, Vector3(-0.22, 0, 0))
			_cyl(parent, 0.004, 1.12, Vector3(0, 0, 0.03), accent)
			_box(parent, Vector3(0.036, 0.18, 0.055), Vector3(0, 0, -0.1), grip)
			_sphere(parent, 0.035, Vector3(0, 0.6, -0.08), glow)
			_sphere(parent, 0.035, Vector3(0, -0.6, -0.08), glow)
			_cyl(parent, 0.008, 0.7, Vector3(0, 0.0, -0.2), accent, Vector3(PI * 0.5, 0, 0))   # nocked arrow
			muzzle.position = Vector3(0, 0, -0.55)
		&"gauntlet":
			_box(parent, Vector3(0.15, 0.13, 0.22), Vector3(0, 0, -0.05), body)
			_box(parent, Vector3(0.13, 0.11, 0.1), Vector3(0, 0, 0.1), dark)
			for i in 3:
				_box(parent, Vector3(0.032, 0.032, 0.14), Vector3((i - 1) * 0.048, 0.015, -0.2), accent)
			_box(parent, Vector3(0.09, 0.035, 0.035), Vector3(0, 0.075, -0.06), glow)
			_cyl(parent, 0.03, 0.02, Vector3(0, 0, -0.16), glow, Vector3(PI * 0.5, 0, 0))
			muzzle.position = Vector3(0, 0.02, -0.3)
		&"orb":
			_sphere(parent, 0.11, Vector3(0, 0.05, -0.1), glow)
			_cyl(parent, 0.14, 0.015, Vector3(0, 0.05, -0.1), accent)
			_cyl(parent, 0.05, 0.03, Vector3(0, -0.08, -0.1), dark)
			muzzle.position = Vector3(0, 0.05, -0.25)
		&"mortar":
			_cyl(parent, 0.09, 0.55, Vector3(0, 0.1, -0.2), body, Vector3(PI * 0.35, 0, 0))
			_cyl(parent, 0.105, 0.04, Vector3(0, 0.27, -0.4), dark, Vector3(PI * 0.35, 0, 0))
			_box(parent, Vector3(0.22, 0.05, 0.22), Vector3(0, -0.05, 0.05), accent)
			_box(parent, Vector3(0.05, 0.12, 0.05), Vector3(0, -0.12, 0.1), grip, Vector3(-0.25, 0, 0))
			_cyl(parent, 0.11, 0.04, Vector3(0, 0.3, -0.42), glow, Vector3(PI * 0.35, 0, 0))
			_box(parent, Vector3(0.05, 0.06, 0.12), Vector3(0.09, 0.0, -0.3), dark)   # side hopper
			muzzle.position = Vector3(0, 0.32, -0.45)
		&"shield_mace":
			_cyl(parent, 0.024, 0.55, Vector3(0, 0, -0.2), grip, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.14, 0.18, 0.14), Vector3(0, 0, -0.5), body)
			for i in 4:
				_box(parent, Vector3(0.04, 0.2, 0.04), Vector3(0, 0, -0.5), dark, Vector3(0, 0, i * PI * 0.25))
			_box(parent, Vector3(0.2, 0.04, 0.04), Vector3(0, 0, -0.5), glow)
			_sphere(parent, 0.03, Vector3(0, 0, 0.09), accent)
			muzzle.position = Vector3(0, 0, -0.6)
		&"lantern":
			_box(parent, Vector3(0.14, 0.2, 0.14), Vector3(0, -0.02, -0.15), body)
			_box(parent, Vector3(0.1, 0.15, 0.1), Vector3(0, -0.02, -0.15), glow)
			_box(parent, Vector3(0.16, 0.03, 0.16), Vector3(0, 0.1, -0.15), dark)
			_box(parent, Vector3(0.16, 0.03, 0.16), Vector3(0, -0.14, -0.15), dark)
			_cyl(parent, 0.008, 0.18, Vector3(0, 0.2, -0.15), accent)
			_cyl(parent, 0.028, 0.06, Vector3(0, 0.29, -0.15), accent, Vector3(0, 0, PI * 0.5))   # handle bar
			muzzle.position = Vector3(0, 0, -0.3)
		&"harpoon":
			_cyl(parent, 0.032, 0.8, Vector3(0, 0, -0.3), body, Vector3(PI * 0.5, 0, 0))
			_box(parent, Vector3(0.03, 0.18, 0.18), Vector3(0, 0, -0.66), accent, Vector3(0, 0, PI * 0.25))
			_box(parent, Vector3(0.08, 0.14, 0.14), Vector3(0, -0.07, 0.05), grip)
			_box(parent, Vector3(0.05, 0.1, 0.05), Vector3(0, -0.14, 0.08), grip, Vector3(-0.25, 0, 0))
			_box(parent, Vector3(0.024, 0.024, 0.4), Vector3(0.045, 0.04, -0.3), glow)
			_cyl(parent, 0.06, 0.08, Vector3(0, 0.05, 0.1), dark, Vector3(0, 0, PI * 0.5))   # cable spool
			muzzle.position = Vector3(0, 0, -0.85)
		_:
			_box(parent, Vector3(0.06, 0.08, 0.5), Vector3(0, 0, -0.2), body)
			_box(parent, Vector3(0.05, 0.12, 0.06), Vector3(0, -0.1, 0.0), grip)
			muzzle.position = Vector3(0, 0, -0.5)
	parent.add_child(muzzle)
	var hp := hand_points(style)
	var grip_n := Node3D.new(); grip_n.name = "Grip"; grip_n.position = hp["grip"]; parent.add_child(grip_n)
	if hp.has("foregrip"):
		var fg := Node3D.new(); fg.name = "Foregrip"; fg.position = hp["foregrip"]; parent.add_child(fg)
	parent.scale = Vector3.ONE * visual.weapon_scale


## Where the hands sit on each archetype (weapon-local, unscaled). "grip" is the trigger/main hand,
## "foregrip" the support hand (absent for one-handed weapons). Used by both HeroRig and FirstPersonRig.
static func hand_points(style: StringName) -> Dictionary:
	match style:
		&"rifle":      return {"grip": Vector3(0, -0.12, 0.0), "foregrip": Vector3(0, -0.05, -0.5)}
		&"cannon":     return {"grip": Vector3(0, -0.15, 0.06), "foregrip": Vector3(0, -0.08, -0.3)}
		&"staff":      return {"grip": Vector3(0, 0.1, 0.3), "foregrip": Vector3(0, 0.1, -0.35)}
		&"blades":     return {"grip": Vector3(0, 0, 0.02)}
		&"launcher":   return {"grip": Vector3(0, -0.12, 0.0), "foregrip": Vector3(0, -0.06, -0.42)}
		&"pistols":    return {"grip": Vector3(0, -0.11, 0.03)}
		&"bow":        return {"grip": Vector3(0, 0, 0.22), "foregrip": Vector3(0, 0, -0.1)}
		&"gauntlet":   return {"grip": Vector3(0, -0.01, 0.06)}
		&"orb":        return {"grip": Vector3(0, -0.1, -0.1)}
		&"mortar":     return {"grip": Vector3(0, -0.16, 0.1), "foregrip": Vector3(0, 0.02, -0.38)}
		&"shield_mace": return {"grip": Vector3(0, 0, 0.05)}
		&"lantern":    return {"grip": Vector3(0, 0.27, -0.15)}
		&"harpoon":    return {"grip": Vector3(0, -0.15, 0.08), "foregrip": Vector3(0, -0.04, -0.4)}
		_:             return {"grip": Vector3(0, -0.13, 0.0)}


static func is_two_handed(style: StringName) -> bool:
	return hand_points(style).has("foregrip")


static func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.metallic = metallic; m.roughness = rough
	return m


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D, rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh; mi.material_override = mat; mi.position = pos; mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new(); b.size = size
	return _add(parent, b, pos, mat, rot)


static func _cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: StandardMaterial3D, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = 16
	return _add(parent, c, pos, mat, rot)


static func _sphere(parent: Node3D, r: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2.0; s.radial_segments = 12; s.rings = 6
	return _add(parent, s, pos, mat, Vector3.ZERO)
