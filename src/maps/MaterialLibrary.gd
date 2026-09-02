class_name MaterialLibrary
## PBR materials from res://assets/textures/<id>/ (albedo/normal/roughness/ao jpg from ambientCG),
## with tinted procedural fallbacks so a missing texture is a visible-but-plausible flat material.

static var _cache: Dictionary = {}
static var _tex_cache: Dictionary = {}

const FALLBACK_COLORS := {
	&"concrete": Color(0.62, 0.6, 0.57), &"plaster": Color(0.85, 0.8, 0.72), &"bricks": Color(0.55, 0.3, 0.24),
	&"metal": Color(0.5, 0.52, 0.55), &"metal_plates": Color(0.42, 0.44, 0.46), &"painted_metal": Color(0.3, 0.42, 0.5),
	&"corrugated": Color(0.55, 0.55, 0.5), &"wood": Color(0.5, 0.36, 0.22), &"planks": Color(0.45, 0.32, 0.2),
	&"roof_tiles": Color(0.5, 0.25, 0.18), &"cobble": Color(0.45, 0.43, 0.4), &"paving": Color(0.55, 0.53, 0.5),
	&"sand": Color(0.8, 0.7, 0.5), &"snow": Color(0.93, 0.95, 0.98), &"rock": Color(0.45, 0.42, 0.4),
	&"moss": Color(0.3, 0.45, 0.2), &"grass": Color(0.35, 0.5, 0.2), &"tiles": Color(0.75, 0.75, 0.72),
	&"marble": Color(0.85, 0.84, 0.8), &"fabric": Color(0.5, 0.2, 0.2), &"asphalt": Color(0.25, 0.25, 0.26),
	&"gravel": Color(0.5, 0.48, 0.45), &"ice": Color(0.75, 0.85, 0.95), &"ground": Color(0.4, 0.33, 0.25),
	&"rust": Color(0.45, 0.25, 0.15), &"terrazzo": Color(0.7, 0.68, 0.65), &"bark": Color(0.35, 0.25, 0.18),
	&"water": Color(0.1, 0.3, 0.4), &"glass": Color(0.6, 0.75, 0.85), &"emissive": Color(1, 1, 1),
}


static func get_material(id: StringName, tint: Color = Color.WHITE, uv_scale: float = 1.0) -> Material:
	var key := "%s|%s|%.2f" % [id, tint, uv_scale]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var dir := "res://assets/textures/%s" % id
	var albedo := _tex(dir + "/albedo.jpg")
	if albedo:
		m.albedo_texture = albedo
		m.albedo_color = tint
		var normal := _tex(dir + "/normal.jpg")
		if normal:
			m.normal_enabled = true
			m.normal_texture = normal
			m.normal_scale = 1.0
		var rough := _tex(dir + "/roughness.jpg")
		if rough:
			m.roughness_texture = rough
			m.roughness = 1.0
		else:
			m.roughness = 0.85
		var ao := _tex(dir + "/ao.jpg")
		if ao:
			m.ao_enabled = true
			m.ao_texture = ao
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * (0.25 * uv_scale)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		var base: Color = FALLBACK_COLORS.get(id, Color(0.6, 0.6, 0.6))
		m.albedo_color = base * tint
		m.roughness = 0.85
	match id:
		&"metal", &"metal_plates", &"painted_metal", &"corrugated", &"rust":
			m.metallic = 0.75 if id != &"painted_metal" else 0.3
			m.roughness = m.roughness * 0.6 if m.roughness_texture == null else m.roughness
		&"marble", &"tiles", &"terrazzo":
			m.metallic = 0.05
			m.roughness = 0.35 if m.roughness_texture == null else m.roughness
		&"ice":
			m.metallic = 0.1; m.roughness = 0.2
		&"water":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.75
			m.metallic = 0.6; m.roughness = 0.08
		&"glass":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(tint.r * 0.6, tint.g * 0.75, tint.b * 0.85, 0.35)
			m.metallic = 0.4; m.roughness = 0.05
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		&"emissive":
			m.emission_enabled = true
			m.emission = tint
			m.emission_energy_multiplier = 2.5
			m.albedo_color = tint
	_cache[key] = m
	return m


static func _tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex_cache[path] = t
	return t


static func emissive(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
