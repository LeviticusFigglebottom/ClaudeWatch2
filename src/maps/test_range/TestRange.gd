extends MapBuilder
## Training range: a compact walled yard with lanes, a high-ground platform, a small point, and
## target dummies. Used for tuning feel, screenshots and the "Training" menu item.


func build() -> void:
	setup_environment("kloofendal_48d_partly_cloudy_puresky", Vector3(-0.5, -0.8, -0.3), Color(1.0, 0.95, 0.88), 2.6, Color(0.6, 0.65, 0.75), Color(0.75, 0.8, 0.88), 0.004)
	var ground := mat(&"concrete", Color(0.9, 0.9, 0.92), 1.0)
	var wall_m := mat(&"painted_metal", Color(0.75, 0.8, 0.85), 1.0)
	var crate := mat(&"planks", Color.WHITE, 1.5)
	var accent := mat(&"emissive", Color(0.98, 0.72, 0.22))
	var paving := mat(&"paving", Color.WHITE, 1.0)
	# Ground and perimeter
	floor_slab(Vector3(0, 0, 0), Vector2(80, 80), ground, 1.0)
	floor_slab(Vector3(0, 0.02, 0), Vector2(14, 14), paving, 0.04)
	for w: Array in [[Vector3(-40, 0, -40), Vector3(40, 0, -40)], [Vector3(40, 0, -40), Vector3(40, 0, 40)], [Vector3(40, 0, 40), Vector3(-40, 0, 40)], [Vector3(-40, 0, 40), Vector3(-40, 0, -40)]]:
		wall(w[0], w[1], 6.0, 1.0, wall_m)
	# Central point + cover crates
	for p: Vector3 in [Vector3(-5, 0, -4), Vector3(5, 0, 4), Vector3(6, 0, -6), Vector3(-6, 0, 6)]:
		block(p, Vector3(2.0, 1.6, 2.0), crate, 15.0)
	block(Vector3(0, 0, -9), Vector3(6, 1.0, 1.0), wall_m)
	block(Vector3(0, 0, 9), Vector3(6, 1.0, 1.0), wall_m)
	# High ground platforms with ramps
	block(Vector3(-16, 0, 0), Vector3(8, 3.0, 8), mat(&"concrete", Color(0.8, 0.8, 0.82)))
	ramp(Vector3(-12, 0, -8), 4.0, 8.0, 3.0, ground, 180.0)
	block(Vector3(16, 0, 0), Vector3(8, 3.0, 8), mat(&"concrete", Color(0.8, 0.8, 0.82)))
	stairs(Vector3(12, 0, 8), 4.0, 8.0, 3.0, ground, 0.0)
	# Lanes: two side corridors with pillars for sightline breaks
	for i in 5:
		block(Vector3(-28, 0, -20 + i * 10), Vector3(1.2, 4.0, 1.2), wall_m)
		block(Vector3(28, 0, -20 + i * 10), Vector3(1.2, 4.0, 1.2), wall_m)
	block(Vector3(0, 0, -24), Vector3(16, 2.2, 1.0), mat(&"bricks"))
	block(Vector3(0, 0, 24), Vector3(16, 2.2, 1.0), mat(&"bricks"))
	# Accent strips
	block(Vector3(0, 0.05, 0), Vector3(14.2, 0.05, 0.2), accent, 0, false, false)
	block(Vector3(0, 0.05, 0), Vector3(0.2, 0.05, 14.2), accent, 0, false, false)
	for a: float in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
		point_light(d * 30.0 + Vector3(0, 5.0, 0), Color(1.0, 0.85, 0.6), 3.0, 18.0)
	# Target dummies (static props for shooting practice)
	for i in 6:
		var x := -10.0 + i * 4.0
		block(Vector3(x, 0, -30), Vector3(0.6, 1.9, 0.4), mat(&"fabric", Color(0.9, 0.3, 0.3)))
		block(Vector3(x, 1.9, -30), Vector3(0.4, 0.4, 0.4), mat(&"fabric", Color(1.0, 0.8, 0.3)))
	_outskirts()
	_bounds()
	# Layout
	layout.add_spawn_room(&"a", 0, Vector3(0, 0, 34), 0.0, Vector3(6, 3, 3))
	layout.add_spawn_room(&"b", 0, Vector3(0, 0, -34), 180.0, Vector3(6, 3, 3))
	layout.control_points.append(layout.make_zone("Range", Vector3(0, 0, 0), Vector3(7, 3, 7)))
	layout.add_health_pack(Vector3(-16, 3.0, 0), true)
	layout.add_health_pack(Vector3(16, 3.0, 0), false)
	layout.add_health_pack(Vector3(-28, 0, 0), false)
	layout.add_health_pack(Vector3(28, 0, 0), false)
	layout.kill_z = -20.0
	layout.overview_camera = Transform3D(Basis.from_euler(Vector3(-0.7, 0.6, 0)), Vector3(-30, 28, 36))
	layout.high_ground.append(layout.make_zone("west_platform", Vector3(-16, 3, 0), Vector3(4, 2, 4)))
	layout.high_ground.append(layout.make_zone("east_platform", Vector3(16, 3, 0), Vector3(4, 2, 4)))


## --- Outskirts ------------------------------------------------------------------------------------
## The yard is 80 m square inside a 6 m wall, and beyond that wall there was nothing: the ground slab
## ended at the wall's foot and the horizon was bare sky, so the range read as a box floating in the
## air rather than one compound on a site. This lays an apron out to the horizon, rings the yard with
## the rest of the facility, and puts a ridge behind that. None of it collides or casts shadows.
func _outskirts() -> void:
	var apron := mat(&"asphalt", Color(0.62, 0.63, 0.66), 6.0)
	var dirt := mat(&"ground", Color(0.68, 0.64, 0.55), 12.0)
	var shed := mat(&"corrugated", Color(0.78, 0.79, 0.8), 2.0)
	var shed_warm := mat(&"corrugated", Color(0.8, 0.72, 0.6), 2.0)
	var conc := mat(&"concrete", Color(0.82, 0.82, 0.84), 2.0)
	var ridge := mat(&"rock", Color(0.55, 0.57, 0.6), 8.0)
	# Ground out to the horizon: apron close in, scrub beyond, both well below eye level from inside.
	block(Vector3(0, -0.55, 0), Vector3(240, 0.5, 240), dirt, 0, false, false)
	block(Vector3(0, -0.5, 0), Vector3(132, 0.5, 132), apron, 0, false, false)
	# The rest of the facility: hangars and stores ringing the yard, gable roofs, roller doors.
	# Heights are set by sight lines, not taste. The perimeter wall is 6 m and the yard is 80 m across,
	# so from the centre the wall hides everything below a 0.1 slope: a shed 58 m out has to top 8 m
	# to be seen at all and about 14 m to read as a building rather than a strip above a parapet. A
	# first pass at 5-9 m was invisible from everywhere in the yard.
	var specs := [[0.0, -58.0, 44.0, 16.0, 17.0], [-46.0, -56.0, 26.0, 14.0, 14.0], [46.0, -56.0, 26.0, 14.0, 14.5],
		[0.0, 58.0, 38.0, 16.0, 15.5], [-48.0, 56.0, 24.0, 14.0, 13.5], [48.0, 56.0, 24.0, 14.0, 14.0],
		[-58.0, 0.0, 16.0, 40.0, 18.0], [58.0, 0.0, 16.0, 40.0, 18.0],
		[-58.0, -26.0, 14.0, 12.0, 12.5], [58.0, 26.0, 14.0, 12.0, 12.5]]
	var i := 0
	for sp: Array in specs:
		var c := Vector3(float(sp[0]), 0, float(sp[1]))
		var w := float(sp[2]); var d := float(sp[3]); var h := float(sp[4])
		block(c, Vector3(w, h, d), shed if i % 2 == 0 else shed_warm, 0, false, false)
		block(c + Vector3(0, h, 0), Vector3(w + 0.8, 0.4, d + 0.8), conc, 0, false, false)
		# Roller doors face the yard, so the ring reads as buildings rather than a fence.
		var to_yard := (Vector3.ZERO - c)
		var n: Vector3 = Vector3(signf(to_yard.x), 0, 0) if absf(c.x) > absf(c.z) else Vector3(0, 0, signf(to_yard.z))
		var door: Vector3 = Vector3(0.15, 4.0, 5.0) if n.x != 0.0 else Vector3(5.0, 4.0, 0.15)
		block(c + n * Vector3(w * 0.5 + 0.08, 0, d * 0.5 + 0.08), door, mat(&"painted_metal", Color(0.45, 0.48, 0.52)), 0, false, false)
		i += 1
	# Silos and a water tower, for a silhouette that is not all boxes.
	for sp: Array in [[-74.0, 34.0, 5.0, 26.0], [-66.0, 40.0, 4.0, 21.0], [72.0, -40.0, 5.5, 28.0]]:
		deco(_silo(float(sp[2]), float(sp[3])), Vector3(float(sp[0]), float(sp[3]) * 0.5, float(sp[1])), conc)
	# Outer blocks: taller, plainer, further back.
	for sp: Array in [[-96.0, -70.0, 30.0, 22.0, 26.0], [-100.0, 20.0, 24.0, 40.0, 31.0], [96.0, -20.0, 26.0, 44.0, 29.0],
			[88.0, 74.0, 34.0, 20.0, 23.0], [-20.0, -104.0, 52.0, 24.0, 27.0], [30.0, 100.0, 46.0, 22.0, 24.0]]:
		block(Vector3(float(sp[0]), 0, float(sp[1])), Vector3(float(sp[2]), float(sp[4]), float(sp[3])), conc, 0, false, false)
	# A low ridge closing the horizon on all four sides.
	for sp: Array in [[0.0, -150.0, 320.0, 40.0, 52.0], [0.0, 150.0, 320.0, 40.0, 46.0],
			[-150.0, 0.0, 40.0, 300.0, 48.0], [150.0, 0.0, 40.0, 300.0, 42.0]]:
		block(Vector3(float(sp[0]), -6.0, float(sp[1])), Vector3(float(sp[2]), float(sp[4]), float(sp[3])), ridge, 0, false, false)


func _silo(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c


## The cage, just inside the perimeter wall. The wall is only 6 m and every launch, dash and
## knockback in the game can clear it; past it the facility is scenery with no collision, so a player
## who got over would fall through a hangar roof and die to kill_z looking at the back of a box.
func _bounds() -> void:
	boundary_rect(-39.2, -39.2, 39.2, 39.2, 40.0, -2.0)
