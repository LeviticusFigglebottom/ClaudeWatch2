extends GutTest
## Analytic ray tests used for hit registration.


func test_ray_sphere_hit_and_miss() -> void:
	var t := HitboxSet._ray_sphere(Vector3(0, 0, 5), Vector3(0, 0, -1), Vector3.ZERO, 1.0)
	assert_almost_eq(t, 4.0, 0.001)
	var m := HitboxSet._ray_sphere(Vector3(0, 3, 5), Vector3(0, 0, -1), Vector3.ZERO, 1.0)
	assert_lt(m, 0.0)


func test_ray_capsule() -> void:
	var t := HitboxSet._ray_capsule(Vector3(0, 1, 5), Vector3(0, 0, -1), Vector3(0, 0, 0), Vector3(0, 2, 0), 0.5)
	assert_almost_eq(t, 4.5, 0.001)
	var cap := HitboxSet._ray_capsule(Vector3(0, 2.4, 5), Vector3(0, 0, -1), Vector3(0, 0, 0), Vector3(0, 2, 0), 0.5)
	assert_gt(cap, 0.0, "hits the top cap")
	var miss := HitboxSet._ray_capsule(Vector3(0, 3.0, 5), Vector3(0, 0, -1), Vector3(0, 0, 0), Vector3(0, 2, 0), 0.5)
	assert_lt(miss, 0.0)


func test_ray_starting_inside_sphere_hits_at_zero() -> void:
	var t := HitboxSet._ray_sphere(Vector3.ZERO, Vector3(0, 0, -1), Vector3.ZERO, 1.0)
	assert_almost_eq(t, 0.0, 0.001)
