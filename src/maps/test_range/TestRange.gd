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
	# Layout
	layout.add_spawn_room(&"a", 0, Vector3(0, 0, 34), 180.0, Vector3(6, 3, 3))
	layout.add_spawn_room(&"b", 0, Vector3(0, 0, -34), 0.0, Vector3(6, 3, 3))
	layout.control_points.append(layout.make_zone("Range", Vector3(0, 0, 0), Vector3(7, 3, 7)))
	layout.add_health_pack(Vector3(-16, 3.0, 0), true)
	layout.add_health_pack(Vector3(16, 3.0, 0), false)
	layout.add_health_pack(Vector3(-28, 0, 0), false)
	layout.add_health_pack(Vector3(28, 0, 0), false)
	layout.kill_z = -20.0
	layout.overview_camera = Transform3D(Basis.from_euler(Vector3(-0.7, 0.6, 0)), Vector3(-30, 28, 36))
	layout.high_ground.append(layout.make_zone("west_platform", Vector3(-16, 3, 0), Vector3(4, 2, 4)))
	layout.high_ground.append(layout.make_zone("east_platform", Vector3(16, 3, 0), Vector3(4, 2, 4)))
