class_name VfxLibrary
extends Node
## Pooled visual effects: tracers, impacts, decals, muzzle flashes, area rings, beams, loops.
## Effects are built procedurally from small textures so every hero can have a distinct palette.

static var _flash_tex: Texture2D
static var _soft_tex: Texture2D
static var _ring_tex: Texture2D
static var _spark_tex: Texture2D
static var _decal_tex: Texture2D

var world: SimWorld
var tracers: Array[MeshInstance3D] = []
var tracer_free: Array[MeshInstance3D] = []
var tracer_data: Dictionary = {}       # mesh -> {t, life, a, b}
var particles_free: Dictionary = {}    # kind -> Array[GPUParticles3D]
var decals: Array[Decal] = []
var decal_index: int = 0
var beams: Dictionary = {}             # net_id -> MeshInstance3D
var loops: Dictionary = {}             # "net_id:ability" -> Node3D
var rings: Array = []                  # [mesh, t, life]
var MAX_DECALS := 96
var _tracer_mat_cache: Dictionary = {}
static var custom_builders: Dictionary = {}     # vfx id -> Callable(lib: VfxLibrary) -> GPUParticles3D
static var custom_spawners: Dictionary = {}     # vfx id -> Callable(lib, pos, normal, color, attach) -> void
static var _extensions_loaded: bool = false


## Hero-specific VFX live in src/vfx/hero_vfx/<hero>_vfx.gd with a static register(lib) that fills
## custom_builders (particle recipes) and/or custom_spawners (arbitrary node effects).
static func load_extensions() -> void:
	if _extensions_loaded:
		return
	_extensions_loaded = true
	var dir := DirAccess.open("res://src/vfx/hero_vfx")
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			var s := load("res://src/vfx/hero_vfx/" + f) as GDScript
			if s and s.has_method("register"):
				s.call("register")
		f = dir.get_next()


static func register_builder(id: StringName, builder: Callable) -> void:
	custom_builders[id] = builder


static func register_spawner(id: StringName, spawner: Callable) -> void:
	custom_spawners[id] = spawner


static func flash_texture() -> Texture2D:
	if _flash_tex == null:
		_flash_tex = _make_radial(64, 0.15, 1.0, true)
	return _flash_tex


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		_soft_tex = _make_radial(64, 0.0, 1.0, false)
	return _soft_tex


static func ring_texture() -> Texture2D:
	if _ring_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 63.5
				var a := clampf(1.0 - absf(d - 0.85) / 0.12, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


static func spark_texture() -> Texture2D:
	if _spark_tex == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				a = pow(a, 0.6)
				img.set_pixel(x, y, Color(1, 1, 1, a))
		_spark_tex = ImageTexture.create_from_image(img)
	return _spark_tex


static func decal_texture() -> Texture2D:
	if _decal_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		var rng := RandomNumberGenerator.new(); rng.seed = 3
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				var n := rng.randf() * 0.25
				var a := clampf(1.0 - d * 1.15 + n * 0.3, 0.0, 1.0)
				var v := 0.06 + n * 0.3 * (1.0 - d)
				img.set_pixel(x, y, Color(v, v, v, a * 0.9))
		_decal_tex = ImageTexture.create_from_image(img)
	return _decal_tex


static func _make_radial(size: int, inner: float, outer: float, star: bool) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in size:
		for x in size:
			var v := Vector2(x - half, y - half) / half
			var d := v.length()
			var a := clampf(1.0 - (d - inner) / maxf(outer - inner, 0.001), 0.0, 1.0)
			a = a * a
			if star:
				var ang := atan2(v.y, v.x)
				a *= 0.55 + 0.45 * absf(cos(ang * 2.0))
				a += clampf(1.0 - d * 4.0, 0.0, 1.0) * 0.8
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func set_world(w: SimWorld) -> void:
	load_extensions()
	world = w
	for t: MeshInstance3D in tracers:
		t.queue_free()
	tracers.clear(); tracer_free.clear(); tracer_data.clear()
	for k: Variant in particles_free.keys():
		for p: GPUParticles3D in particles_free[k]:
			p.queue_free()
	particles_free.clear()
	for d: Decal in decals:
		d.queue_free()
	decals.clear()
	for b: Variant in beams.values():
		(b as Node).queue_free()
	beams.clear()
	loops.clear()


func _root() -> Node3D:
	return world


## --- Tracers ------------------------------------------------------------------------------------

func tracer(from: Vector3, to: Vector3, pres: AbilityPresentation) -> void:
	if pres.tracer_style == &"" or world == null:
		return
	var m: MeshInstance3D
	if tracer_free.is_empty():
		m = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1, 1, 1)
		m.mesh = box
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.layers = 1 << 3
		_root().add_child(m)
		tracers.append(m)
	else:
		m = tracer_free.pop_back()
	var key := str(pres.tracer_color) + str(pres.tracer_style)
	var mat: StandardMaterial3D = _tracer_mat_cache.get(key)
	if mat == null:
		mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = pres.tracer_color
		mat.emission_enabled = true
		mat.emission = pres.tracer_color
		mat.emission_energy_multiplier = 2.0
		_tracer_mat_cache[key] = mat
	m.material_override = mat
	m.visible = true
	var life := 0.09
	var width := pres.tracer_width
	var seg_len := 1.0
	match pres.tracer_style:
		&"bullet": life = 0.07; seg_len = 0.6
		&"bolt": life = 0.12; width *= 1.5; seg_len = 1.0
		&"beam": life = 0.1; seg_len = 1.0
		&"arc": life = 0.15; width *= 1.2; seg_len = 1.0
		&"shell": life = 0.06; seg_len = 0.4
	tracer_data[m] = {"t": 0.0, "life": life, "a": from, "b": to, "w": width, "seg": seg_len}
	_place_tracer(m, from, to, width, seg_len, 0.0)


func _place_tracer(m: MeshInstance3D, a: Vector3, b: Vector3, w: float, seg: float, k: float) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.05:
		m.visible = false
		return
	# A short bright segment that flies from a to b over the tracer's life (seg < 1) or the whole ray.
	var start := a
	var end := b
	if seg < 1.0:
		var head := clampf(k * 1.4, 0.0, 1.0)
		var tail := clampf(head - seg * 0.6, 0.0, 1.0)
		start = a.lerp(b, tail)
		end = a.lerp(b, head)
	var mid := (start + end) * 0.5
	var l := start.distance_to(end)
	if l < 0.01:
		m.visible = false
		return
	m.global_position = mid
	m.look_at(end, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	m.scale = Vector3(w, w, l)


func muzzle(pos: Vector3, pres: AbilityPresentation, is_local: bool) -> void:
	if pres.muzzle_vfx == &"" and pres.tracer_style == &"":
		return
	spawn(pres.muzzle_vfx if pres.muzzle_vfx != &"" else &"muzzle_generic", pos, Vector3.UP, pres.tracer_color)
	if not is_local:
		return


func impact(pos: Vector3, normal: Vector3, pres: AbilityPresentation) -> void:
	spawn(pres.impact_vfx if pres.impact_vfx != &"" else &"impact_generic", pos, normal, pres.tracer_color)
	if pres.impact_decal != &"":
		decal(pos, normal, pres.impact_decal)


## --- Particles ----------------------------------------------------------------------------------

func spawn(kind: StringName, pos: Vector3, normal: Vector3, color: Color, attach_to: Node3D = null) -> GPUParticles3D:
	if world == null or kind == &"":
		return null
	if custom_spawners.has(kind):
		(custom_spawners[kind] as Callable).call(self, pos, normal, color, attach_to)
		return null
	var p: GPUParticles3D
	var pool: Array = particles_free.get(kind, [])
	if pool.is_empty():
		p = build_particles(kind)
		if p == null:
			return null
		_root().add_child(p)
	else:
		p = pool.pop_back()
		particles_free[kind] = pool
	if attach_to:
		p.reparent(attach_to, false)
		p.position = Vector3(0, 1.0, 0)
	else:
		if p.get_parent() != _root():
			p.reparent(_root(), false)
		p.global_position = pos
		if normal.length_squared() > 0.001 and absf(normal.dot(Vector3.UP)) < 0.999:
			p.look_at(pos + normal, Vector3.UP)
		else:
			p.rotation = Vector3(-PI * 0.5 if normal.y > 0 else PI * 0.5, 0, 0)
	var mat := p.process_material as ParticleProcessMaterial
	if mat and p.has_meta("tint"):
		mat.color = color * Color(1, 1, 1, 1.0)
		(p.draw_pass_1.surface_get_material(0) as StandardMaterial3D).albedo_color = color if p.draw_pass_1.surface_get_material(0) is StandardMaterial3D else Color.WHITE
	p.emitting = true
	p.restart()
	var life := p.lifetime + 0.2
	get_tree().create_timer(life).timeout.connect(func() -> void:
		if is_instance_valid(p):
			p.emitting = false
			if p.get_parent() != _root():
				p.reparent(_root(), false)
			var pl: Array = particles_free.get(kind, [])
			pl.append(p)
			particles_free[kind] = pl)
	return p


func mesh_quad(size: float, tex: Texture2D, add: bool = true) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	q.material = m
	return q


## Ids build_particles() has an explicit recipe for. Anything else falls back to a generic puff, so
## tools/vfx_audit.gd uses this to tell a real recipe from a silent fallback.
const BUILTIN_PARTICLES: Array[StringName] = [&"impact_generic", &"impact_bullet", &"impact_flesh",
	&"impact_barrier", &"muzzle_generic", &"death_burst", &"melee_hit", &"blink_out", &"blink_in",
	&"deploy_place", &"deploy_break", &"ping_marker", &"explosion", &"heal_burst", &"cast_generic",
	&"ult_burst", &"smoke_puff", &"projectile_trail"]


func has_builtin(kind: StringName) -> bool:
	return BUILTIN_PARTICLES.has(kind)


func build_particles(kind: StringName) -> GPUParticles3D:
	if custom_builders.has(kind):
		var built: GPUParticles3D = (custom_builders[kind] as Callable).call(self)
		if built:
			built.set_meta("tint", built.get_meta("tint", false))
			built.layers = 1 << 3
			return built
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.layers = 1 << 3
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mat.direction = Vector3(0, 0, 1)
	mat.spread = 45.0
	mat.gravity = Vector3(0, -6, 0)
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.scale_min = 0.5
	mat.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	mat.color_ramp = ramp_tex
	p.set_meta("tint", true)
	match kind:
		&"impact_generic", &"impact_bullet":
			p.amount = 14; p.lifetime = 0.35
			mat.initial_velocity_min = 3.0; mat.initial_velocity_max = 7.0
			mat.scale_min = 0.15; mat.scale_max = 0.35
			mat.spread = 55.0
			p.draw_pass_1 = mesh_quad(0.12, spark_texture())
		&"impact_flesh":
			p.amount = 10; p.lifetime = 0.3
			mat.initial_velocity_min = 1.5; mat.initial_velocity_max = 4.0
			mat.scale_min = 0.3; mat.scale_max = 0.6; mat.spread = 80.0
			mat.gravity = Vector3(0, -9, 0)
			p.draw_pass_1 = mesh_quad(0.14, soft_texture(), false)
		&"impact_barrier":
			p.amount = 12; p.lifetime = 0.3
			mat.spread = 90.0; mat.initial_velocity_min = 1.0; mat.initial_velocity_max = 2.5; mat.gravity = Vector3.ZERO
			mat.scale_min = 0.3; mat.scale_max = 0.5
			p.draw_pass_1 = mesh_quad(0.2, ring_texture())
		&"muzzle_generic":
			p.amount = 6; p.lifetime = 0.12
			mat.spread = 20.0; mat.initial_velocity_min = 2.0; mat.initial_velocity_max = 4.0; mat.gravity = Vector3.ZERO
			mat.scale_min = 0.6; mat.scale_max = 1.2
			p.draw_pass_1 = mesh_quad(0.15, flash_texture())
		&"death_burst":
			p.amount = 40; p.lifetime = 0.9
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 2.0; mat.initial_velocity_max = 6.0
			mat.scale_min = 0.4; mat.scale_max = 0.9
			p.draw_pass_1 = mesh_quad(0.25, soft_texture())
		&"melee_hit":
			p.amount = 8; p.lifetime = 0.25
			mat.spread = 90.0; mat.initial_velocity_min = 2.0; mat.initial_velocity_max = 4.0
			p.draw_pass_1 = mesh_quad(0.18, spark_texture())
		&"blink_out", &"blink_in":
			p.amount = 24; p.lifetime = 0.5
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0); mat.gravity = Vector3(0, 2, 0)
			mat.initial_velocity_min = 0.5; mat.initial_velocity_max = 2.5
			mat.scale_min = 0.3; mat.scale_max = 0.7
			p.draw_pass_1 = mesh_quad(0.25, soft_texture())
		&"deploy_place", &"deploy_break":
			p.amount = 20; p.lifetime = 0.6
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 1.0; mat.initial_velocity_max = 4.0
			mat.scale_min = 0.2; mat.scale_max = 0.5
			p.draw_pass_1 = mesh_quad(0.2, spark_texture())
		&"ping_marker":
			p.amount = 1; p.lifetime = 2.5; p.explosiveness = 1.0
			mat.initial_velocity_min = 0.0; mat.initial_velocity_max = 0.0; mat.gravity = Vector3.ZERO
			mat.scale_min = 1.0; mat.scale_max = 1.0
			p.draw_pass_1 = mesh_quad(1.2, ring_texture())
		&"explosion":
			p.amount = 36; p.lifetime = 0.7
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 3.0; mat.initial_velocity_max = 9.0
			mat.scale_min = 0.8; mat.scale_max = 1.8
			mat.gravity = Vector3(0, -3, 0)
			p.draw_pass_1 = mesh_quad(0.5, soft_texture())
		&"heal_burst":
			p.amount = 16; p.lifetime = 0.8
			mat.spread = 30.0; mat.direction = Vector3(0, 1, 0); mat.gravity = Vector3(0, 1.5, 0)
			mat.initial_velocity_min = 0.5; mat.initial_velocity_max = 1.5
			mat.scale_min = 0.2; mat.scale_max = 0.4
			p.draw_pass_1 = mesh_quad(0.2, spark_texture())
		&"cast_generic":
			p.amount = 18; p.lifetime = 0.5
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0); mat.gravity = Vector3.ZERO
			mat.initial_velocity_min = 1.0; mat.initial_velocity_max = 3.0
			mat.scale_min = 0.3; mat.scale_max = 0.6
			p.draw_pass_1 = mesh_quad(0.22, soft_texture())
		&"ult_burst":
			p.amount = 60; p.lifetime = 1.2
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 3.0; mat.initial_velocity_max = 10.0
			mat.scale_min = 0.6; mat.scale_max = 1.4
			mat.gravity = Vector3(0, -2, 0)
			p.draw_pass_1 = mesh_quad(0.45, soft_texture())
		&"smoke_puff":
			p.amount = 10; p.lifetime = 1.1
			mat.spread = 60.0; mat.initial_velocity_min = 0.5; mat.initial_velocity_max = 1.5; mat.gravity = Vector3(0, 0.8, 0)
			mat.scale_min = 0.8; mat.scale_max = 1.6
			p.draw_pass_1 = mesh_quad(0.6, soft_texture(), false)
		&"projectile_trail":
			p.one_shot = false; p.explosiveness = 0.0
			p.amount = 24; p.lifetime = 0.35
			mat.spread = 5.0; mat.initial_velocity_min = 0.0; mat.initial_velocity_max = 0.2; mat.gravity = Vector3.ZERO
			mat.scale_min = 0.4; mat.scale_max = 0.7
			p.draw_pass_1 = mesh_quad(0.2, soft_texture())
		_:
			# Unknown id: generic soft burst so nothing is ever invisible.
			p.amount = 16; p.lifetime = 0.5
			mat.spread = 180.0; mat.direction = Vector3(0, 1, 0)
			mat.initial_velocity_min = 1.0; mat.initial_velocity_max = 3.0
			p.draw_pass_1 = mesh_quad(0.25, soft_texture())
	p.process_material = mat
	return p


## --- Decals -------------------------------------------------------------------------------------

func decal(pos: Vector3, normal: Vector3, kind: StringName) -> void:
	if world == null:
		return
	var d: Decal
	if decals.size() < MAX_DECALS:
		d = Decal.new()
		d.texture_albedo = decal_texture()
		d.size = Vector3(0.22, 0.4, 0.22)
		d.cull_mask = 1
		d.albedo_mix = 0.9
		d.upper_fade = 1.0; d.lower_fade = 1.0
		_root().add_child(d)
		decals.append(d)
	else:
		d = decals[decal_index]
		decal_index = (decal_index + 1) % MAX_DECALS
	match kind:
		&"scorch": d.size = Vector3(1.2, 0.5, 1.2); d.modulate = Color(0.1, 0.08, 0.06)
		&"bullet_hole": d.size = Vector3(0.22, 0.4, 0.22); d.modulate = Color(0.15, 0.15, 0.15)
		_: d.size = Vector3(0.3, 0.4, 0.3); d.modulate = Color(0.3, 0.3, 0.3)
	d.global_position = pos + normal * 0.01
	var up := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	d.look_at(pos + normal, up)
	d.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	d.rotate_object_local(Vector3.UP, randf() * TAU)
	d.visible = true


## --- Area rings / beams / loops -------------------------------------------------------------

func area(kind: StringName, pos: Vector3, radius: float, color: Color) -> void:
	if world == null:
		return
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_texture = ring_texture()
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	m.layers = 1 << 3
	_root().add_child(m)
	m.global_position = pos + Vector3(0, 0.08, 0)
	m.rotation.x = -PI * 0.5
	rings.append([m, 0.0, 0.6 if kind != &"ult" else 1.4])
	# Hero modules register area recipes under the area's own id (kiln_meltdown_ground, and so on).
	# Use one when it exists instead of guessing a generic burst from how the id is spelled.
	if custom_builders.has(kind):
		spawn(kind, pos, Vector3.UP, color)
	else:
		spawn(&"explosion" if kind.contains("explo") else (&"heal_burst" if kind.contains("heal") else &"cast_generic"), pos, Vector3.UP, color)


func beam(net_id: int, from: Vector3, to: Vector3, pres: AbilityPresentation, color: Color) -> void:
	if world == null:
		return
	var m: MeshInstance3D = beams.get(net_id)
	if m == null:
		m = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.0; cyl.bottom_radius = 1.0; cyl.height = 1.0; cyl.radial_segments = 8
		m.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = pres.tracer_color if pres.tracer_color != Color(1.0, 0.85, 0.5) else color
		mat.albedo_color.a = 0.75
		m.material_override = mat
		m.layers = 1 << 3
		_root().add_child(m)
		beams[net_id] = m
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = 1.2
		light.omni_range = 3.0
		m.add_child(light)
	m.visible = true
	m.set_meta("t", 0.25)
	var d := to - from
	var l := d.length()
	if l < 0.05:
		return
	m.global_position = (from + to) * 0.5
	m.look_at(to, Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT)
	m.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var w := pres.tracer_width * 2.5 + 0.04
	m.scale = Vector3(w, l, w)
	if randf() < 0.3:
		spawn(&"impact_generic", to, -d.normalized(), color)


func end_beam(net_id: int) -> void:
	var m: MeshInstance3D = beams.get(net_id)
	if m:
		m.visible = false


func attach_loop(p: Pawn, kind: StringName, ability_id: StringName, color: Color) -> void:
	var key := "%d:%s" % [p.net_id, ability_id]
	if loops.has(key):
		return
	var node := Node3D.new()
	node.name = "Loop_" + String(ability_id)
	p.add_child(node)
	node.position = Vector3(0, 1.0, 0)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.8
	light.omni_range = 4.0
	node.add_child(light)
	# Use the hero's own loop recipe when one is registered; heroes author loop_vfx ids like
	# "sable_requiem_loop", and this used to ignore them and always emit the generic cast puff.
	var custom := custom_builders.has(kind)
	var part := build_particles(kind if custom else &"cast_generic")
	part.one_shot = false
	part.explosiveness = 0.0
	if not custom:
		part.amount = 24
		part.lifetime = 0.8
		(part.process_material as ParticleProcessMaterial).color = color
	node.add_child(part)
	part.emitting = true
	loops[key] = node


func detach_loop(p: Pawn, ability_id: StringName) -> void:
	var key := "%d:%s" % [p.net_id, ability_id]
	var node: Node3D = loops.get(key)
	if node:
		loops.erase(key)
		node.queue_free()


func projectile_impact(visual: StringName, pos: Vector3, normal: Vector3, color: Color, splash: float) -> void:
	if splash > 0.0:
		spawn(&"explosion", pos, normal, color)
		area(&"explosion", pos, splash, color)
		decal(pos, normal, &"scorch")
	else:
		spawn(&"impact_generic", pos, normal, color)
		decal(pos, normal, &"bullet_hole")


func update_frame(delta: float) -> void:
	for m: MeshInstance3D in tracers:
		if not tracer_data.has(m):
			continue
		var d: Dictionary = tracer_data[m]
		d["t"] = float(d["t"]) + delta
		var k := float(d["t"]) / float(d["life"])
		if k >= 1.0:
			m.visible = false
			tracer_data.erase(m)
			tracer_free.append(m)
			continue
		_place_tracer(m, d["a"], d["b"], float(d["w"]) * (1.0 - k * 0.6), float(d["seg"]), k)
	for i in range(rings.size() - 1, -1, -1):
		var r: Array = rings[i]
		r[1] = float(r[1]) + delta
		var k := float(r[1]) / float(r[2])
		var m: MeshInstance3D = r[0]
		if k >= 1.0:
			m.queue_free()
			rings.remove_at(i)
			continue
		m.scale = Vector3.ONE * (0.3 + 0.7 * (1.0 - pow(1.0 - k, 2.0)))
		(m.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k
	for nid: Variant in beams.keys():
		var m: MeshInstance3D = beams[nid]
		var t := float(m.get_meta("t", 0.0)) - delta
		m.set_meta("t", t)
		if t <= 0.0:
			m.visible = false
