class_name MapBuilder
extends Node3D
## Base for code-authored maps. Provides geometry helpers (textured blocks, ramps, props, lights)
## with physics collision and a MaterialLibrary lookup. Each map subclass overrides build().
## Maps are authored as code so layout intent (lanes, cover, sightlines) stays reviewable.

var layout: MapLayout
var world: SimWorld
var static_root: StaticBody3D
var props_root: Node3D
var nav_region: NavigationRegion3D
var _mat_cache: Dictionary = {}
var lights_root: Node3D
var built: bool = false
var env: WorldEnvironment
var sun: DirectionalLight3D
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	if built:
		return
	built = true
	layout = MapLayout.new()
	layout.name = "Layout"
	add_child(layout)
	static_root = StaticBody3D.new()
	static_root.name = "Static"
	static_root.collision_layer = RF.L_WORLD
	static_root.collision_mask = 0
	add_child(static_root)
	props_root = Node3D.new()
	props_root.name = "Props"
	add_child(props_root)
	lights_root = Node3D.new()
	lights_root.name = "Lights"
	add_child(lights_root)
	rng.seed = hash(name)
	build()
	_setup_navigation()


func build() -> void:
	pass


func on_world_attached(w: SimWorld) -> void:
	world = w


## --- Materials ------------------------------------------------------------------------------------

func mat(id: StringName, tint: Color = Color.WHITE, uv_scale: float = 1.0) -> Material:
	var key := "%s|%s|%.2f" % [id, tint, uv_scale]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := MaterialLibrary.get_material(id, tint, uv_scale)
	_mat_cache[key] = m
	return m


## --- Geometry -------------------------------------------------------------------------------------

## Axis-aligned textured block with collision. `pos` is the center of the base (feet), size = full extents.
func block(pos: Vector3, size: Vector3, material: Material, yaw_deg: float = 0.0, collide: bool = true, shadow: bool = true) -> MeshInstanceWrap:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos + Vector3(0, size.y * 0.5, 0)
	mi.rotation.y = deg_to_rad(yaw_deg)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_root.add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = mi.position
		cs.rotation = mi.rotation
		static_root.add_child(cs)
	return MeshInstanceWrap.new(mi)


## Floor slab (center pos at top surface, thickness downwards).
func floor_slab(center: Vector3, size: Vector2, material: Material, thickness: float = 0.5, yaw_deg: float = 0.0) -> MeshInstanceWrap:
	return block(center - Vector3(0, thickness, 0), Vector3(size.x, thickness, size.y), material, yaw_deg)


## Ramp from `from` (low edge center) rising to height `h` over length `len` along yaw direction.
func ramp(from: Vector3, width: float, length: float, height: float, material: Material, yaw_deg: float = 0.0, thickness: float = 0.4) -> void:
	var angle := atan2(height, length)
	var slope_len := sqrt(length * length + height * height)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, thickness, slope_len)
	mi.mesh = bm
	mi.material_override = material
	var yaw := deg_to_rad(yaw_deg)
	var dir := Vector3(-sin(yaw), 0, -cos(yaw))
	var center := from + dir * (length * 0.5) + Vector3(0, height * 0.5 - thickness * 0.5 * cos(angle), 0)
	mi.position = center
	mi.rotation = Vector3(angle, yaw, 0)
	static_root.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	cs.position = mi.position
	cs.rotation = mi.rotation
	static_root.add_child(cs)


## Stairs approximated as a ramp collider with visual steps.
func stairs(from: Vector3, width: float, length: float, height: float, material: Material, yaw_deg: float = 0.0, steps: int = 0) -> void:
	if steps <= 0:
		steps = maxi(int(height / 0.22), 2)
	var yaw := deg_to_rad(yaw_deg)
	var dir := Vector3(-sin(yaw), 0, -cos(yaw))
	var step_len := length / steps
	var step_h := height / steps
	for i in steps:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, step_h * (i + 1), step_len)
		mi.mesh = bm
		mi.material_override = material
		mi.position = from + dir * (step_len * (i + 0.5)) + Vector3(0, step_h * (i + 1) * 0.5, 0)
		mi.rotation.y = yaw
		static_root.add_child(mi)
	# Smooth collider
	var angle := atan2(height, length)
	var slope_len := sqrt(length * length + height * height)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.3, slope_len)
	cs.shape = bs
	cs.position = from + dir * (length * 0.5) + Vector3(0, height * 0.5 - 0.15 * cos(angle), 0)
	cs.rotation = Vector3(angle, yaw, 0)
	static_root.add_child(cs)


## Simple wall: from a to b, height h, thickness t.
func wall(a: Vector3, b: Vector3, h: float, t: float, material: Material) -> MeshInstanceWrap:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var yaw := atan2(-d.x, -d.z)
	var center := (a + b) * 0.5
	return block(Vector3(center.x, minf(a.y, b.y), center.z), Vector3(t, h, len), material, rad_to_deg(yaw))


## Non-colliding decorative mesh (for thin details) — still occludes nothing.
func deco(mesh: Mesh, pos: Vector3, material: Material, rot: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scale_v
	props_root.add_child(mi)
	return mi


## Kenney glTF prop with generated collision (box from AABB) — path relative to res://assets/models/.
func prop(path: String, pos: Vector3, yaw_deg: float = 0.0, scale_f: float = 1.0, collide: bool = true) -> Node3D:
	var node := PropLibrary.instance(path)
	if node == null:
		return null
	# Placed by footprint: `pos` is the centre of the model's base, whatever the kit's origin convention.
	var ab := PropLibrary._aabb(node)
	var foot := Vector3(ab.position.x + ab.size.x * 0.5, ab.position.y, ab.position.z + ab.size.z * 0.5)
	var yaw := deg_to_rad(yaw_deg)
	node.position = pos - foot.rotated(Vector3.UP, yaw) * scale_f
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale_f
	props_root.add_child(node)
	if collide:
		PropLibrary.add_box_collision(node, static_root, node.position, yaw, scale_f)
	return node


func point_light(pos: Vector3, color: Color, energy: float = 2.0, range_: float = 8.0, shadows: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = range_
	l.shadow_enabled = shadows
	lights_root.add_child(l)
	return l


func spot_light(pos: Vector3, target: Vector3, color: Color, energy: float = 4.0, range_: float = 12.0, angle: float = 40.0) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.spot_range = range_
	l.spot_angle = angle
	lights_root.add_child(l)
	l.look_at_from_position(pos, target, Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.RIGHT)
	return l


## Sky + sun + fog + tonemap. HDRI is loaded from assets/hdri/<name>.hdr if present.
func setup_environment(hdri: String, sun_dir: Vector3, sun_color: Color, sun_energy: float, ambient: Color, fog_color: Color, fog_density: float, sky_tint: Color = Color.WHITE, exposure: float = 1.0) -> void:
	env = WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var path := "res://assets/hdri/%s.hdr" % hdri
	if hdri != "" and ResourceLoader.exists(path):
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(path)
		pm.energy_multiplier = float(Console.cvar("env_sky_mult", 0.85))
		sky.sky_material = pm
	else:
		var psm := ProceduralSkyMaterial.new()
		psm.sky_top_color = sky_tint.darkened(0.3)
		psm.sky_horizon_color = sky_tint
		psm.ground_bottom_color = fog_color.darkened(0.5)
		psm.ground_horizon_color = fog_color
		psm.sun_angle_max = 20.0
		sky.sky_material = psm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 0.55
	e.ambient_light_color = ambient
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = exposure * float(Console.cvar("env_exposure_mult", 0.7))
	e.tonemap_white = 6.0
	e.ssao_enabled = bool(Settings.get_value(&"video", "ssao"))
	e.ssao_radius = 1.5
	e.ssao_intensity = 1.5
	e.glow_enabled = bool(Settings.get_value(&"video", "glow"))
	e.glow_intensity = 0.55
	e.glow_bloom = 0.08
	e.glow_hdr_threshold = 1.1
	e.fog_enabled = fog_density > 0.0
	e.fog_light_color = fog_color
	e.fog_density = fog_density
	e.fog_sky_affect = 0.25
	e.fog_aerial_perspective = 0.5
	e.volumetric_fog_enabled = bool(Settings.get_value(&"video", "volumetric_fog")) and fog_density > 0.0
	e.volumetric_fog_density = fog_density * 3.0
	e.volumetric_fog_albedo = fog_color
	e.volumetric_fog_length = 96.0
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.05
	e.adjustment_saturation = 1.08
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy * float(Console.cvar("env_sun_mult", 0.45))
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 160.0
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.45
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	sun.light_angular_distance = 0.8
	sun.look_at_from_position(Vector3.ZERO, sun_dir.normalized(), Vector3.UP if absf(sun_dir.normalized().y) < 0.99 else Vector3.RIGHT)
	add_child(sun)


## --- Navigation -----------------------------------------------------------------------------------

func _setup_navigation() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	add_child(nav_region)
	var cache_path := "res://data/maps/nav/%s.res" % name.to_lower()
	if ResourceLoader.exists(cache_path):
		nav_region.navigation_mesh = load(cache_path)
		return
	var nm := NavigationMesh.new()
	nm.agent_radius = 0.45
	nm.agent_height = 1.9
	nm.agent_max_climb = 0.45
	nm.agent_max_slope = 50.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.region_min_size = 2.0
	nm.edge_max_error = 1.5
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = RF.L_WORLD
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "navsource"
	static_root.add_to_group("navsource")
	nav_region.navigation_mesh = nm
	nav_region.bake_navigation_mesh(false)
	if OS.has_feature("editor") or OS.get_cmdline_user_args().has("--save-nav"):
		DirAccess.make_dir_recursive_absolute("res://data/maps/nav")
		ResourceSaver.save(nav_region.navigation_mesh, cache_path)


class MeshInstanceWrap:
	var mesh: MeshInstance3D
	func _init(m: MeshInstance3D) -> void:
		mesh = m
