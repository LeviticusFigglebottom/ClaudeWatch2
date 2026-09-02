extends MapBuilder
## Saltmarsh Terminal — Escort, golden hour.
## A drowned Adriatic ferry port of the Adriatic Charter: water at street level between ochre and
## rose plaster buildings, salt-crusted quays, a beached ferry across the dock square, a customs
## hall, a fish-market street with arcades, a drained dry-dock and the lighthouse pad at the end.
## Attackers (Cinder, amber) push west -> east along X. Defenders (Tide, teal) fall back.
##
## Coordinates: y=0 street level, water at WATER_Y (falling in = death via kill_z), dry-dock floor
## at DOCK_Y. North is -Z (warehouses / back streets), south is +Z (quays, canal, open water).

const WATER_Y := -0.6
const DOCK_Y := -2.4

# Palette (filled in _palette)
var m_cobble: Material
var m_cobble_dark: Material
var m_paving: Material
var m_concrete: Material
var m_concrete_dark: Material
var m_stone: Material
var m_bricks: Material
var m_planks: Material
var m_planks_grey: Material
var m_wood: Material
var m_ochre: Material
var m_rose: Material
var m_cream: Material
var m_white: Material
var m_sage: Material
var m_roof: Material
var m_roof_dark: Material
var m_rust: Material
var m_corr: Material
var m_metal: Material
var m_iron: Material
var m_paint_red: Material
var m_paint_white: Material
var m_paint_teal: Material
var m_tiles: Material
var m_terrazzo: Material
var m_marble: Material
var m_water: Material
var m_glass: Material
var m_fab_amber: Material
var m_fab_teal: Material
var m_fab_white: Material
var m_fab_red: Material
var m_fab_green: Material
var m_tarp: Material
var m_cinder: Material
var m_tide: Material
var m_lamp: Material
var m_moss: Material
var m_sand: Material
var m_dark: Material

const CINDER := Color(0.98, 0.45, 0.16)
const TIDE := Color(0.16, 0.66, 0.98)
const LAMP := Color(1.0, 0.82, 0.55)


func _setup_navigation() -> void:
	# SimWorld renames every map root to "Map" before _ready(), so MapBuilder would key the nav cache
	# on data/maps/nav/map.res (the Training Range bake) for every map. Key it on this map's id.
	var saved := name
	name = "saltmarsh"
	super()
	name = saved


func build() -> void:
	setup_environment("venice_dawn_2", Vector3(0.78, -0.30, -0.42), Color(1.0, 0.78, 0.52), 3.0,
		Color(0.55, 0.62, 0.74), Color(0.96, 0.8, 0.62), 0.006, Color(1.0, 0.86, 0.7), 1.05)
	_palette()
	_ground_and_water()
	_boundary_warehouses()
	_terminal_spawn()
	_dock_plaza()
	_ferry()
	_north_quay()
	_customs_hall()
	_annex_spawn()
	_square()
	_market_street()
	_arcade_and_canal()
	_north_street_and_rooms()
	_dry_dock()
	_net_shed_and_harbourmaster()
	_lighthouse_pad()
	_keepers_house()
	_skyline()
	_layout()


## --- Palette -------------------------------------------------------------------------------------

func _palette() -> void:
	m_cobble = mat(&"cobble", Color(0.72, 0.7, 0.68), 2.0)
	m_cobble_dark = mat(&"cobble", Color(0.5, 0.5, 0.5), 2.0)
	m_paving = mat(&"paving", Color(0.88, 0.84, 0.78), 1.6)
	m_concrete = mat(&"concrete", Color(0.78, 0.76, 0.72), 1.0)
	m_concrete_dark = mat(&"concrete_2", Color(0.58, 0.58, 0.56), 1.0)
	m_stone = mat(&"rock", Color(0.78, 0.74, 0.68), 1.5)
	m_bricks = mat(&"bricks", Color(0.85, 0.62, 0.5), 2.0)
	m_planks = mat(&"planks", Color(0.85, 0.72, 0.55), 2.0)
	m_planks_grey = mat(&"planks_2", Color(0.62, 0.6, 0.56), 2.0)
	m_wood = mat(&"wood", Color(0.72, 0.52, 0.32), 2.0)
	m_ochre = mat(&"plaster", Color(0.96, 0.72, 0.4), 1.0)
	m_rose = mat(&"plaster", Color(0.94, 0.6, 0.5), 1.0)
	m_cream = mat(&"plaster", Color(0.96, 0.9, 0.76), 1.0)
	m_white = mat(&"plaster_painted", Color(0.94, 0.93, 0.88), 1.2)
	m_sage = mat(&"plaster", Color(0.72, 0.8, 0.62), 1.0)
	m_roof = mat(&"roof_tiles", Color(0.98, 0.62, 0.45), 2.2)
	m_roof_dark = mat(&"roof_tiles", Color(0.7, 0.42, 0.32), 2.2)
	m_rust = mat(&"rust", Color(0.95, 0.9, 0.85), 1.5)
	m_corr = mat(&"corrugated", Color(0.72, 0.74, 0.7), 2.0)
	m_metal = mat(&"metal", Color(0.62, 0.64, 0.66), 1.0)
	m_iron = mat(&"metal_plates", Color(0.28, 0.28, 0.3), 1.0)
	m_paint_red = mat(&"painted_metal", Color(0.72, 0.24, 0.18), 1.0)
	m_paint_white = mat(&"painted_metal", Color(0.92, 0.9, 0.85), 1.0)
	m_paint_teal = mat(&"painted_metal", Color(0.2, 0.55, 0.6), 1.0)
	m_tiles = mat(&"tiles", Color(0.88, 0.82, 0.7), 2.0)
	m_terrazzo = mat(&"terrazzo", Color(0.9, 0.88, 0.84), 1.5)
	m_marble = mat(&"marble", Color.WHITE, 1.0)
	m_water = mat(&"water", Color(0.22, 0.62, 0.62))
	m_glass = mat(&"glass", Color(0.45, 0.6, 0.72))
	m_fab_amber = mat(&"fabric", Color(1.0, 0.6, 0.22), 1.5)
	m_fab_teal = mat(&"fabric", Color(0.2, 0.72, 0.85), 1.5)
	m_fab_white = mat(&"fabric", Color(0.96, 0.94, 0.86), 1.5)
	m_fab_red = mat(&"fabric", Color(0.88, 0.32, 0.26), 1.5)
	m_fab_green = mat(&"fabric", Color(0.35, 0.62, 0.42), 1.5)
	m_tarp = mat(&"tarp", Color(0.35, 0.55, 0.62), 1.5)
	m_cinder = mat(&"emissive", CINDER)
	m_tide = mat(&"emissive", TIDE)
	m_lamp = mat(&"emissive", LAMP)
	m_moss = mat(&"moss", Color.WHITE, 2.0)
	m_sand = mat(&"sand", Color(0.86, 0.8, 0.66), 2.0)
	m_dark = mat(&"asphalt", Color(0.35, 0.33, 0.3), 1.0)


## --- Generic helpers -----------------------------------------------------------------------------

## Ground plate: top at y=0, stone quay faces down to the water.
func _plate(x0: float, z0: float, x1: float, z1: float, top_y: float = 0.0) -> void:
	block(Vector3((x0 + x1) * 0.5, top_y - 2.0, (z0 + z1) * 0.5), Vector3(x1 - x0, 2.0, z1 - z0), m_stone)


## Non-colliding surface overlay (cobble/paving/planks) sitting on a plate.
func _overlay(x0: float, z0: float, x1: float, z1: float, m: Material, y: float = 0.0, yaw: float = 0.0) -> void:
	block(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector3(x1 - x0, 0.06, z1 - z0), m, yaw, false, false)


## Wall with door/arch gaps. gaps = [Vector2(distance_along, width), ...]. lintel_h > 0 fills above the gap.
func _wall_gaps(a: Vector3, b: Vector3, h: float, t: float, m: Material, gaps: Array, lintel_h: float = 0.0) -> void:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var dir := d / len
	var yaw := rad_to_deg(atan2(-d.x, -d.z))
	var cursor := 0.0
	for g: Vector2 in gaps:
		var s0 := g.x - g.y * 0.5
		var s1 := g.x + g.y * 0.5
		if s0 - cursor > 0.05:
			wall(a + dir * cursor, a + dir * s0, h, t, m)
		if lintel_h > 0.0 and lintel_h < h:
			var c := a + dir * g.x
			block(Vector3(c.x, a.y + lintel_h, c.z), Vector3(t, h - lintel_h, g.y + 0.04), m, yaw)
		cursor = s1
	if len - cursor > 0.05:
		wall(a + dir * cursor, b, h, t, m)


## Rectangular room. doors: [{"side": "n"|"s"|"e"|"w", "at": offset along the side from its min corner, "w": width}]
## Sides run: n/s from x0->x1 at z0/z1; e/w from z0->z1 at x1/x0.
func _room(c: Vector3, sx: float, sz: float, h: float, wall_m: Material, roof_m: Material, doors: Array, t: float = 0.6, lintel: float = 3.0) -> void:
	var x0 := c.x - sx * 0.5
	var x1 := c.x + sx * 0.5
	var z0 := c.z - sz * 0.5
	var z1 := c.z + sz * 0.5
	var sides := {
		"n": [Vector3(x0, c.y, z0), Vector3(x1, c.y, z0)],
		"s": [Vector3(x0, c.y, z1), Vector3(x1, c.y, z1)],
		"w": [Vector3(x0, c.y, z0), Vector3(x0, c.y, z1)],
		"e": [Vector3(x1, c.y, z0), Vector3(x1, c.y, z1)],
	}
	for side: String in sides.keys():
		var gaps: Array = []
		for d: Dictionary in doors:
			if String(d["side"]) == side:
				gaps.append(Vector2(float(d["at"]), float(d["w"])))
		gaps.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var ab: Array = sides[side]
		_wall_gaps(ab[0], ab[1], h, t, wall_m, gaps, lintel)
	block(Vector3(c.x, c.y + h, c.z), Vector3(sx + t, 0.4, sz + t), roof_m)


## Door-frame accent strip (team colour) above an opening. yaw 0 = opening runs along X.
func _accent(pos: Vector3, w: float, yaw: float, m: Material) -> void:
	block(pos, Vector3(w + 0.4, 0.14, 0.22), m, yaw, false, false)


## Hanging team banner on a wall. normal = outward direction of the wall face.
func _banner(pos: Vector3, normal: Vector3, m: Material, h: float = 2.4) -> void:
	var yaw := rad_to_deg(atan2(normal.x, normal.z))
	block(pos + normal * 0.12, Vector3(1.1, h, 0.05), m, yaw, false, false)
	block(pos + normal * 0.12 + Vector3(0, h, 0), Vector3(1.4, 0.08, 0.08), m_iron, yaw, false, false)


## Stairs with a solid stepped underside (visual + collision cannot be walked under).
func _stairs_solid(from: Vector3, w: float, len: float, h: float, m: Material, yaw: float) -> void:
	stairs(from, w, len, h, m, yaw)
	var yr := deg_to_rad(yaw)
	var dir := Vector3(-sin(yr), 0, -cos(yr))
	for i in 3:
		var t0 := float(i) / 3.0
		var t1 := float(i + 1) / 3.0
		var seg_h := h * t0 - 0.05
		if seg_h > 0.1:
			var c := from + dir * (len * (t0 + t1) * 0.5)
			block(Vector3(c.x, from.y, c.z), Vector3(w, seg_h, len / 3.0), m, yaw)


func _ramp_solid(from: Vector3, w: float, len: float, h: float, m: Material, yaw: float) -> void:
	ramp(from, w, len, h, m, yaw)
	var yr := deg_to_rad(yaw)
	var dir := Vector3(-sin(yr), 0, -cos(yr))
	for i in 4:
		var t0 := float(i) / 4.0
		var t1 := float(i + 1) / 4.0
		var seg_h := h * t0 - 0.3
		if seg_h > 0.1:
			var c := from + dir * (len * (t0 + t1) * 0.5)
			block(Vector3(c.x, from.y, c.z), Vector3(w, seg_h, len / 4.0), m, yaw)


func _kerb(a: Vector3, b: Vector3) -> void:
	wall(a, b, 0.45, 0.5, m_stone)


## Railing (collides: bots treat it as a wall, players can hop it). yaw 0 = runs along Z.
func _railing(a: Vector3, b: Vector3, h: float = 1.0) -> void:
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	var yaw := rad_to_deg(atan2(-d.x, -d.z))
	var c := (a + b) * 0.5
	block(Vector3(c.x, a.y, c.z), Vector3(0.08, h, len), m_iron, yaw)
	# posts
	var n := maxi(int(len / 2.0), 1)
	for i in n + 1:
		var p := a + d * (float(i) / n)
		block(Vector3(p.x, a.y, p.z), Vector3(0.12, h + 0.05, 0.12), m_iron, yaw, false, false)


func _window(pos: Vector3, w: float, h: float, yaw: float, shutter_m: Material = null) -> void:
	block(pos, Vector3(w, h, 0.12), m_glass, yaw, false, false)
	block(pos - Vector3(0, 0.08, 0), Vector3(w + 0.3, 0.1, 0.3), m_white, yaw, false, false)
	if shutter_m:
		var yr := deg_to_rad(yaw)
		var along := Vector3(cos(yr), 0, -sin(yr))
		block(pos + along * (w * 0.5 + 0.22), Vector3(0.4, h, 0.06), shutter_m, yaw, false, false)
		block(pos - along * (w * 0.5 + 0.22), Vector3(0.4, h, 0.06), shutter_m, yaw, false, false)


func _iron_balcony(pos: Vector3, w: float, normal: Vector3) -> void:
	var yaw := rad_to_deg(atan2(normal.x, normal.z))
	var c := pos + normal * 0.45
	block(c - Vector3(0, 0.12, 0), Vector3(w, 0.12, 0.9), m_rust, yaw, false, false)
	block(c + normal * 0.42, Vector3(w, 0.95, 0.05), m_iron, yaw, false, false)
	var yr := deg_to_rad(yaw)
	var along := Vector3(cos(yr), 0, -sin(yr))
	block(c + along * (w * 0.5), Vector3(0.05, 0.95, 0.9), m_iron, yaw, false, false)
	block(c - along * (w * 0.5), Vector3(0.05, 0.95, 0.9), m_iron, yaw, false, false)


## Facade dressing on one side of a box building: windows per floor, optional door, balconies.
func _facade(face_c: Vector3, along: Vector3, normal: Vector3, width: float, floors: int, floor_h: float, shutter_m: Material, door: bool, balconies: bool) -> void:
	var yaw := rad_to_deg(atan2(normal.x, normal.z))
	var n := maxi(int(width / 3.2), 1)
	var spacing := width / n
	for f in floors:
		var y := 1.2 + f * floor_h
		for i in n:
			var t := (i + 0.5) * spacing - width * 0.5
			var p := face_c + along * t + normal * 0.07 + Vector3(0, y, 0)
			if f == 0 and door and i == n / 2:
				block(p - Vector3(0, 1.2, 0) + Vector3(0, 1.1, 0), Vector3(1.4, 2.2, 0.12), m_dark, yaw, false, false)
				block(p + Vector3(0, 1.25, 0) + normal * 0.5, Vector3(2.0, 0.06, 1.1), m_fab_white, yaw, false, false)
				continue
			_window(p, 1.1, 1.5, yaw, shutter_m)
			if balconies and f > 0 and (i % 2 == 0):
				_iron_balcony(p - Vector3(0, 0.85, 0) + normal * 0.05, 1.8, normal)


## Box building with facade dressing on all sides and a gable roof (ridge along the long axis).
func _house(c: Vector3, size: Vector3, wall_m: Material, roof_m: Material, shutter_m: Material, floors: int = 2, door_side: String = "s", balconies: bool = true) -> void:
	block(c, size, wall_m)
	var floor_h := (size.y - 1.0) / floors
	var faces := {
		"s": [Vector3(c.x, c.y, c.z + size.z * 0.5), Vector3(1, 0, 0), Vector3(0, 0, 1), size.x],
		"n": [Vector3(c.x, c.y, c.z - size.z * 0.5), Vector3(1, 0, 0), Vector3(0, 0, -1), size.x],
		"e": [Vector3(c.x + size.x * 0.5, c.y, c.z), Vector3(0, 0, 1), Vector3(1, 0, 0), size.z],
		"w": [Vector3(c.x - size.x * 0.5, c.y, c.z), Vector3(0, 0, 1), Vector3(-1, 0, 0), size.z],
	}
	for k: String in faces.keys():
		var f: Array = faces[k]
		_facade(f[0], f[1], f[2], float(f[3]), floors, floor_h, shutter_m, k == door_side, balconies)
	_gable(c + Vector3(0, size.y, 0), size.x, size.z, roof_m)


func _gable(top_c: Vector3, sx: float, sz: float, roof_m: Material, rh: float = -1.0) -> void:
	if rh < 0.0:
		rh = minf(sx, sz) * 0.32
	block(top_c - Vector3(0, 0.05, 0), Vector3(sx + 0.7, 0.3, sz + 0.7), roof_m)
	var pm := PrismMesh.new()
	if sx >= sz:
		pm.size = Vector3(sz + 0.7, rh, sx + 0.7)
		deco(pm, top_c + Vector3(0, 0.25 + rh * 0.5, 0), roof_m, Vector3(0, PI * 0.5, 0))
	else:
		pm.size = Vector3(sx + 0.7, rh, sz + 0.7)
		deco(pm, top_c + Vector3(0, 0.25 + rh * 0.5, 0), roof_m)
	# chimney
	block(top_c + Vector3(sx * 0.3, 0.2, sz * 0.2), Vector3(0.7, rh + 0.9, 0.7), m_bricks, 0, false)


func _awning(pos: Vector3, w: float, d: float, yaw: float, m: Material, tilt: float = 0.28) -> void:
	deco(_box(w, 0.06, d), pos, m, Vector3(tilt, deg_to_rad(yaw), 0))
	var yr := deg_to_rad(yaw)
	var along := Vector3(cos(yr), 0, -sin(yr))
	var fwd := Vector3(-sin(yr), 0, -cos(yr))
	for s: float in [-1.0, 1.0]:
		block(pos + along * (s * w * 0.5) + fwd * (d * 0.5) - Vector3(0, pos.y, 0), Vector3(0.08, pos.y, 0.08), m_iron, yaw, false, false)


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _cyl(r: float, h: float, r2: float = -1.0) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r if r2 < 0.0 else r2
	c.height = h
	return c


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


## Street lamp: iron post + glowing head + warm light.
func _lamp(pos: Vector3, energy: float = 2.4, range_: float = 10.0) -> void:
	block(pos, Vector3(0.18, 3.4, 0.18), m_iron, 0, false)
	block(pos + Vector3(0, 3.4, 0), Vector3(0.5, 0.5, 0.5), m_lamp, 45, false, false)
	block(pos + Vector3(0, 3.9, 0), Vector3(0.7, 0.12, 0.7), m_iron, 0, false, false)
	point_light(pos + Vector3(0, 3.3, 0), LAMP, energy, range_)


## Hanging lantern (no post) with light.
func _lantern(pos: Vector3, energy: float = 1.8, range_: float = 7.0, color: Color = LAMP) -> void:
	block(pos, Vector3(0.32, 0.4, 0.32), mat(&"emissive", color), 0, false, false)
	block(pos + Vector3(0, 0.4, 0), Vector3(0.4, 0.06, 0.4), m_iron, 0, false, false)
	point_light(pos + Vector3(0, 0.1, 0), color, energy, range_)


func _mooring_post(pos: Vector3) -> void:
	block(pos, Vector3(0.5, 0.95, 0.5), m_iron, 0)
	deco(_cyl(0.32, 0.18), pos + Vector3(0, 1.02, 0), m_iron)


func _crates(pos: Vector3, yaw: float, stack: int = 2) -> void:
	prop("pirate_kit/crate.glb", pos, yaw, 1.25)
	prop("pirate_kit/crate.glb", pos + Vector3(1.4, 0, 0.2).rotated(Vector3.UP, deg_to_rad(yaw)), yaw + 12.0, 1.25)
	if stack > 1:
		prop("pirate_kit/crate_bottles.glb", pos + Vector3(0.1, 0.96, 0.05).rotated(Vector3.UP, deg_to_rad(yaw)), yaw - 8.0, 1.2)


func _barrels(pos: Vector3, n: int, yaw: float) -> void:
	for i in n:
		var off := Vector3(i * 1.25, 0, (i % 2) * 0.5).rotated(Vector3.UP, deg_to_rad(yaw))
		prop("pirate_kit/barrel.glb", pos + off, yaw + i * 30.0, 0.85)


func _laundry(a: Vector3, b: Vector3, cols: Array) -> void:
	var d := b - a
	var len := d.length()
	var yaw := rad_to_deg(atan2(-d.x, -d.z))
	block((a + b) * 0.5 - Vector3(0, 0.02, 0), Vector3(0.03, 0.03, len), m_iron, yaw, false, false)
	var n := int(len / 1.3)
	for i in n:
		var p := a + d * ((i + 0.5) / n)
		var m: Material = cols[i % cols.size()]
		block(p - Vector3(0, 0.9, 0), Vector3(0.7, 0.9, 0.03), m, yaw + 90.0, false, false)


func _container(pos: Vector3, yaw: float, variant: String = "a") -> void:
	prop("city_kit_industrial/shipping_container_%s.glb" % variant, pos, yaw, 7.0)


func _crane(base: Vector3, yaw: float, jib: float, h: float) -> void:
	block(base, Vector3(2.4, 2.0, 2.4), m_paint_red, yaw)
	block(base + Vector3(0, 2.0, 0), Vector3(1.0, h, 1.0), m_iron, yaw, false)
	var yr := deg_to_rad(yaw)
	var fwd := Vector3(-sin(yr), 0, -cos(yr))
	deco(_box(0.7, 0.7, jib), base + Vector3(0, h + 2.0, 0) + fwd * (jib * 0.5 - 1.0), m_paint_red, Vector3(0.12, yr, 0))
	deco(_box(0.7, 0.7, 4.0), base + Vector3(0, h + 2.0, 0) - fwd * 2.2, m_iron, Vector3(0, yr, 0))
	block(base + Vector3(0, h + 2.4, 0) - fwd * 3.5, Vector3(1.6, 1.6, 1.6), m_concrete_dark, yaw, false)
	var tip := base + Vector3(0, h + 2.0 + jib * 0.12, 0) + fwd * (jib - 1.5)
	block(tip - Vector3(0, 6.0, 0), Vector3(0.05, 6.0, 0.05), m_iron, 0, false, false)
	deco(_torus(0.12, 0.4), tip - Vector3(0, 6.2, 0), m_iron, Vector3(PI * 0.5, 0, 0))
	block(base + Vector3(0, 3.2, 0), Vector3(1.6, 1.4, 1.6), m_paint_white, yaw, false, false)


func _tree(pos: Vector3, kind: String = "pine", s: float = 4.0) -> void:
	match kind:
		"pine":
			prop("nature_kit/tree_pineTallA.glb", pos, rng.randf_range(0, 360), s)
		"palm":
			prop("nature_kit/tree_palm.glb", pos, rng.randf_range(0, 360), s)
		"oak":
			prop("fantasy_town_kit/tree.glb", pos, rng.randf_range(0, 360), s)
		_:
			prop("nature_kit/tree_detailed.glb", pos, rng.randf_range(0, 360), s)


func _planter(pos: Vector3, yaw: float) -> void:
	block(pos, Vector3(2.0, 0.7, 0.9), m_concrete, yaw)
	prop("nature_kit/plant_bushDetailed.glb", pos + Vector3(0, 0.7, 0), yaw, 2.6, false)
	prop("nature_kit/flower_redA.glb", pos + Vector3(0.6, 0.7, 0.1).rotated(Vector3.UP, deg_to_rad(yaw)), yaw, 2.0, false)


func _bench(pos: Vector3, yaw: float) -> void:
	prop("holiday_kit/bench.glb", pos, yaw, 1.6)


func _puddle(pos: Vector3, w: float, d: float, yaw: float = 0.0) -> void:
	block(pos + Vector3(0, 0.02, 0), Vector3(w, 0.02, d), m_water, yaw, false, false)


func _stall(pos: Vector3, yaw: float, red: bool, goods: bool = true) -> void:
	prop("fantasy_town_kit/stall_%s.glb" % ("red" if red else "green"), pos, yaw, 2.2)
	if goods:
		var yr := deg_to_rad(yaw)
		var fwd := Vector3(-sin(yr), 0, -cos(yr))
		prop("food_kit/styrofoam.glb", pos + fwd * 1.5 + Vector3(0.5, 0, 0).rotated(Vector3.UP, yr), yaw + 20.0, 1.0)
		prop("food_kit/fish.glb", pos + Vector3(0.3, 0.95, 0.1).rotated(Vector3.UP, yr), yaw + 90.0, 1.6, false)
		prop("food_kit/fish.glb", pos + Vector3(-0.4, 0.95, 0.2).rotated(Vector3.UP, yr), yaw + 70.0, 1.6, false)


## --- Ground -------------------------------------------------------------------------------------

func _ground_and_water() -> void:
	# Lagoon: one big non-colliding water plane; sand far below for depth.
	block(Vector3(20, WATER_Y - 0.15, 0), Vector3(320, 0.15, 200), m_water, 0, false, false)
	block(Vector3(20, -5.0, 0), Vector3(320, 0.3, 200), mat(&"sand", Color(0.35, 0.42, 0.42), 3.0), 0, false, false)
	# Ground plates (colliding). Everything walkable is one of these.
	_plate(-72, -24, 8, 12)      # W1: terminal, plaza, customs hall
	_plate(8, -24, 46, 17)       # W2: square, market street, arcade, boardwalk
	_plate(46, -24, 98, 0)       # NE: north rim, sheds, back alley, fuel yard
	_plate(46, 12, 98, 18)       # SE: south rim
	_plate(68, 0, 98, 12)        # E: lighthouse pad, keeper's house
	# Dry-dock basin floor
	block(Vector3(57, DOCK_Y - 1.0, 6), Vector3(22, 1.0, 12), m_concrete_dark)
	# Surface overlays
	_overlay(-72, -24, 8, 12, m_cobble)
	_overlay(8, -24, 46, 17, m_cobble)
	_overlay(46, -24, 98, 0, m_cobble)
	_overlay(46, 12, 98, 18, m_concrete)
	_overlay(68, 0, 98, 12, m_paving)
	# Kerbs along water edges (bots stay on; players may hop into the lagoon at their peril).
	_kerb(Vector3(-72, 0, 12.2), Vector3(8.2, 0, 12.2))
	_kerb(Vector3(-72.2, 0, -24), Vector3(-72.2, 0, 12.4))
	_kerb(Vector3(46, 0, 18.2), Vector3(98.2, 0, 18.2))
	_kerb(Vector3(98.2, 0, -24), Vector3(98.2, 0, 18.4))
	# Boardwalk kerb with two boat-step gaps (risk spots on the water flank)
	_wall_gaps(Vector3(8, 0, 17.2), Vector3(46, 0, 17.2), 0.45, 0.5, m_stone, [Vector2(12, 2.0), Vector2(22, 2.0)])


## North boundary: a row of salvage warehouses that also carries the skyline.
func _boundary_warehouses() -> void:
	var specs := [[-72, -50, 7.0, m_corr], [-50, -32, 5.5, m_ochre], [-32, -10, 8.0, m_corr], [-10, 12, 6.0, m_bricks],
		[12, 34, 7.5, m_corr], [34, 58, 5.5, m_cream], [58, 80, 8.5, m_corr], [80, 98, 6.0, m_rust]]
	for s: Array in specs:
		var x0 := float(s[0]); var x1 := float(s[1]); var h := float(s[2])
		var c := Vector3((x0 + x1) * 0.5, 0, -27.0)
		block(c, Vector3(x1 - x0, h, 9.0), s[3])
		block(c + Vector3(0, h, 0), Vector3(x1 - x0 + 0.4, 0.3, 9.4), m_roof_dark if s[3] != m_corr else m_iron)
		# roof furniture and doors along the south face
		block(Vector3(c.x - (x1 - x0) * 0.25, h + 0.3, -27), Vector3(1.4, 2.4, 1.4), m_bricks, 0, false)
		block(Vector3(c.x + (x1 - x0) * 0.2, 0, -22.55), Vector3(3.0, 3.2, 0.1), m_dark, 0, false, false)
		_window(Vector3(c.x - (x1 - x0) * 0.2, 3.2, -22.5), 2.2, 1.2, 0)
	for x: float in [-60.0, -20.0, 22.0, 66.0]:
		prop("city_kit_industrial/water_tower.glb", Vector3(x, 7.0, -27), 0, 3.2, false)
	for x: float in [-41.0, 46.0, 90.0]:
		prop("city_kit_industrial/chimney_medium.glb", Vector3(x, 7.5, -26), 0, 3.0, false)


## --- Leg 1: dock ---------------------------------------------------------------------------------

## Attacker spawn 0: the ferry terminal waiting room.
func _terminal_spawn() -> void:
	var c := Vector3(-63, 0, 0)
	_room(c, 12, 10, 4.5, m_cream, m_roof, [{"side": "e", "at": 4.0, "w": 3.0}, {"side": "s", "at": 9.0, "w": 2.5}])
	_overlay(-69, -5, -57, 5, m_tiles, 0.0)
	_gable(Vector3(-63, 4.9, 0), 12.6, 10.6, m_roof, 2.6)
	_accent(Vector3(-57, 3.05, -1), 3.0, 90, m_cinder)
	_accent(Vector3(-60, 3.05, 5), 2.5, 0, m_cinder)
	_banner(Vector3(-65, 1.0, -4.7), Vector3(0, 0, 1), m_fab_amber)
	_banner(Vector3(-61, 1.0, -4.7), Vector3(0, 0, 1), m_fab_amber)
	# ticket counter, timetable board, benches, luggage
	block(Vector3(-66.5, 0, -2.5), Vector3(3.6, 1.1, 1.0), m_wood)
	block(Vector3(-68.6, 1.4, -1.0), Vector3(0.12, 1.6, 3.0), m_dark, 0, false, false)
	block(Vector3(-68.55, 1.5, -1.0), Vector3(0.06, 1.2, 2.6), mat(&"emissive", Color(0.9, 0.8, 0.5)), 0, false, false)
	_bench(Vector3(-63, 0, 3.6), 0)
	_bench(Vector3(-60, 0, -3.8), 180)
	prop("survival_kit/box_large.glb", Vector3(-66, 0, 3.4), 20, 2.6)
	prop("survival_kit/box.glb", Vector3(-65.2, 0, 4.2), -15, 2.6)
	prop("furniture_kit/pottedPlant.glb", Vector3(-58.2, 0, -4.2), 0, 2.4, false)
	_lantern(Vector3(-63, 3.3, 0), 2.6, 9.0)
	layout.add_health_pack(Vector3(-63, 0, -2.5), true)
	# Outside: signage + a Cinder pennant line over the doors
	block(Vector3(-57.35, 3.4, -1), Vector3(0.1, 0.7, 3.4), m_paint_teal, 0, false, false)


func _dock_plaza() -> void:
	_overlay(-57, -9, -16, 12, m_paving, 0.01)
	# payload rails: a darker cobble lane along z=0
	_overlay(-44, -1.6, 0, 1.6, m_cobble_dark, 0.02)
	block(Vector3(-22, 0.0, 0), Vector3(44, 0.03, 0.06), m_iron, 0, false, false)
	block(Vector3(-22, 0.0, 0), Vector3(44, 0.03, 0.06), m_iron, 0, false, false)
	# mooring posts and bollards along the south quay
	for x in range(-56, -6, 6):
		_mooring_post(Vector3(x, 0, 11.4))
	# cover (waist-high every 6-10 m along the payload lane)
	_crates(Vector3(-47, 0, 5.5), 10)
	_barrels(Vector3(-40, 0, -5.5), 3, 0)
	_crates(Vector3(-32, 0, 4.5), -25)
	prop("car_kit/delivery.glb", Vector3(-24, 0, 7.5), 105, 1.55)
	block(Vector3(-27, 0, -5), Vector3(3.2, 1.05, 1.0), m_stone)   # stone bench wall
	prop("fantasy_town_kit/cart.glb", Vector3(-36, 0, 9.0), 60, 1.8)
	prop("food_kit/styrofoam.glb", Vector3(-35, 0, 7.4), 15, 1.0)
	# ticket booth with awning, trees in planters, lamps
	block(Vector3(-53, 0, -6), Vector3(3.0, 2.8, 2.4), m_paint_teal)
	_awning(Vector3(-53, 2.5, -4.4), 3.4, 1.4, 0, m_fab_white)
	_window(Vector3(-53, 1.5, -4.78), 2.0, 1.0, 0)
	for p: Vector3 in [Vector3(-55, 0, 9.5), Vector3(-45, 0, -7.5)]:
		block(p, Vector3(1.4, 0.8, 1.4), m_concrete)
		_tree(p + Vector3(0, 0.8, 0), "pine", 4.2)
	_lamp(Vector3(-50, 0, 9.8))
	_lamp(Vector3(-30, 0, 9.8))
	_lamp(Vector3(-20, 0, -7.5))
	_bench(Vector3(-56, 0, 6.5), 90)
	# tide-marks: puddles and moss where the sea comes over the quay
	_puddle(Vector3(-40, 0, 9), 4.0, 2.0, 15)
	_puddle(Vector3(-20, 0, 3), 3.0, 1.6, -30)
	_overlay(-57, 10.5, -16, 12, m_moss, 0.02)
	# boat shrine for the Ferry — a niche with candles, flowers and an upturned canoe
	block(Vector3(-16.5, 0, 10.6), Vector3(1.8, 2.3, 0.9), m_stone)
	block(Vector3(-16.5, 1.0, 10.2), Vector3(1.0, 1.0, 0.2), m_dark, 0, false, false)
	block(Vector3(-16.5, 1.25, 10.15), Vector3(0.3, 0.4, 0.2), m_lamp, 0, false, false)
	point_light(Vector3(-16.5, 1.4, 9.6), Color(1.0, 0.7, 0.4), 1.6, 5.0)
	prop("graveyard_kit/candle_multiple.glb", Vector3(-17.4, 0, 9.8), 0, 1.4, false)
	prop("nature_kit/flower_redA.glb", Vector3(-15.7, 0, 9.9), 0, 2.2, false)
	prop("nature_kit/flower_yellowA.glb", Vector3(-16.9, 0, 9.5), 40, 2.2, false)
	prop("nature_kit/canoe.glb", Vector3(-13.5, 0, 10.5), 5, 3.0)
	prop("fantasy_town_kit/lantern.glb", Vector3(-18.5, 0, 10.8), 0, 2.0)


## The beached ferry: a 22 m hull across the north half of the square. Deck = leg-1 high ground.
func _ferry() -> void:
	var c := Vector3(-38, 0, -13)
	block(c, Vector3(22, 1.7, 7), m_paint_red)
	block(c + Vector3(0, 1.7, 0), Vector3(22, 1.7, 7), m_paint_white)
	_overlay(-49, -16.5, -27, -9.5, m_planks, 3.4)
	block(c + Vector3(0, 1.62, 0), Vector3(22.1, 0.16, 7.1), m_paint_teal, 0, false, false)   # waterline stripe
	# hull name plate
	block(Vector3(-44, 2.2, -9.44), Vector3(4.0, 0.7, 0.05), m_paint_teal, 0, false, false)
	block(Vector3(-44, 2.35, -9.4), Vector3(3.2, 0.35, 0.05), m_white, 0, false, false)
	# gangway (west, attackers) and counter stairs (east, defenders)
	_stairs_solid(Vector3(-55, 0, -13), 3.0, 6.0, 3.4, m_planks_grey, -90)
	_stairs_solid(Vector3(-21, 0, -13), 3.0, 6.0, 3.4, m_planks_grey, 90)
	_railing(Vector3(-52, 0, -14.6), Vector3(-49, 3.4, -14.6), 1.0)
	# deck railings (collide) on north and south edges, leaving the stair ends open
	_railing(Vector3(-49, 3.4, -9.6), Vector3(-27, 3.4, -9.6))
	_railing(Vector3(-49, 3.4, -16.4), Vector3(-27, 3.4, -16.4))
	# wheelhouse, funnel, lifeboat, cargo on deck
	block(Vector3(-31.5, 3.4, -13), Vector3(5, 2.6, 4), m_paint_white)
	block(Vector3(-31.5, 4.5, -10.95), Vector3(4.0, 0.9, 0.1), m_glass, 0, false, false)
	block(Vector3(-33.95, 4.5, -13), Vector3(0.1, 0.9, 3.0), m_glass, 0, false, false)
	block(Vector3(-31.5, 6.0, -13), Vector3(5.4, 0.3, 4.4), m_paint_teal, 0, false)
	deco(_cyl(0.75, 3.2), Vector3(-35.5, 5.3, -13), m_paint_red, Vector3(0, 0, 0.14))
	deco(_cyl(0.8, 0.5), Vector3(-35.3, 6.9, -13), m_iron, Vector3(0, 0, 0.14))
	prop("pirate_kit/boat_row_small.glb", Vector3(-45, 3.4, -13.5), 90, 1.1)
	_crates(Vector3(-40.5, 3.4, -11.5), 0)
	_barrels(Vector3(-40, 3.4, -15.5), 2, 90)
	prop("pirate_kit/chest.glb", Vector3(-28.5, 3.4, -11.2), 30, 0.8)
	for x: float in [-46.0, -38.0, -30.0]:
		deco(_torus(0.08, 0.32), Vector3(x, 2.8, -9.42), mat(&"painted_metal", Color(1.0, 0.45, 0.1)))
		deco(_torus(0.08, 0.32), Vector3(x, 2.8, -16.58), mat(&"painted_metal", Color(1.0, 0.45, 0.1)))
	prop("fantasy_town_kit/lantern.glb", Vector3(-48.4, 3.4, -10.4), 0, 1.8, false)
	prop("fantasy_town_kit/lantern.glb", Vector3(-27.6, 3.4, -15.6), 0, 1.8, false)
	_lantern(Vector3(-31.5, 6.8, -10.8), 1.6, 8.0)
	# radio mast with Cinder pennants (attackers' side)
	block(Vector3(-29.5, 6.3, -13), Vector3(0.15, 4.5, 0.15), m_iron, 0, false, false)
	for i in 4:
		block(Vector3(-29.5 - i * 1.8, 8.9 - i * 0.55, -13), Vector3(0.9, 0.5, 0.03), m_fab_amber if i % 2 == 0 else m_fab_white, 0, false, false)
	# sand pushed up against the hull where it was driven ashore
	_overlay(-50, -9.5, -26, -8.2, m_sand, 0.02)
	prop("nature_kit/rock_largeD.glb", Vector3(-26.2, 0, -10.2), 30, 2.0)


func _north_quay() -> void:
	_overlay(-69, -24, -14, -16.5, m_cobble_dark, 0.01)
	_container(Vector3(-46, 0, -20.5), 0, "a")
	_container(Vector3(-46, 2.5, -20.5), 6, "b")
	_container(Vector3(-30, 0, -21.3), 90, "c")
	_crane(Vector3(-60, 0, -20.5), 30, 16.0, 12.0)
	_crates(Vector3(-22, 0, -18.5), -20)
	_barrels(Vector3(-38, 0, -18), 3, 90)
	prop("survival_kit/resource_planks.glb", Vector3(-52, 0, -17.5), 20, 3.0)
	_lamp(Vector3(-40, 0, -23.2))
	_puddle(Vector3(-34, 0, -18.5), 5.0, 2.4, 10)
	layout.add_health_pack(Vector3(-24, 0, -21.5), false)
	# fishing nets hung from the warehouse wall
	for x: float in [-64.0, -56.0]:
		block(Vector3(x, 1.4, -22.4), Vector3(4.0, 1.9, 0.08), m_tarp, 0, false, false)


## Checkpoint 1: the customs hall (x -16..0), open arches west/east, doors north/south.
func _customs_hall() -> void:
	var h := 7.0
	_wall_gaps(Vector3(-16, 0, -8), Vector3(-16, 0, 8), h, 0.8, m_ochre, [Vector2(8, 7)], 5.0)
	_wall_gaps(Vector3(0, 0, -8), Vector3(0, 0, 8), h, 0.8, m_ochre, [Vector2(8, 7)], 5.0)
	_wall_gaps(Vector3(-16, 0, -8), Vector3(0, 0, -8), h, 0.8, m_ochre, [Vector2(8, 3)], 3.5)
	_wall_gaps(Vector3(-16, 0, 8), Vector3(0, 0, 8), h, 0.8, m_ochre, [Vector2(8, 3)], 3.5)
	block(Vector3(-8, h, 0), Vector3(17, 0.5, 17), m_roof)
	_gable(Vector3(-8, h + 0.3, 0), 16.4, 16.4, m_roof, 3.6)
	_overlay(-16, -8, 0, 8, m_terrazzo, 0.01)
	# pillars, counters, crates
	for x: float in [-11.0, -5.0]:
		for z: float in [-4.5, 4.5]:
			block(Vector3(x, 0, z), Vector3(0.9, h, 0.9), m_cream)
			block(Vector3(x, 0, z), Vector3(1.3, 0.5, 1.3), m_stone)
	block(Vector3(-12, 0, -6.4), Vector3(5, 1.1, 1.0), m_wood)
	block(Vector3(-4, 0, 6.4), Vector3(5, 1.1, 1.0), m_wood)
	_crates(Vector3(-13.5, 0, 3.5), 30, 1)
	_crates(Vector3(-2.5, 0, -3.8), -20)
	prop("survival_kit/box_large.glb", Vector3(-8, 0, 5.5), 40, 2.6)
	prop("furniture_kit/desk.glb", Vector3(-3.5, 0, -6.6), 0, 2.4)
	prop("furniture_kit/chairDesk.glb", Vector3(-3.0, 0, -5.6), 180, 2.2, false)
	prop("furniture_kit/books.glb", Vector3(-12.5, 1.1, -6.4), 20, 2.0, false)
	prop("survival_kit/tool_shovel.glb", Vector3(-15.4, 0, 6.5), 0, 2.4, false)
	# high windows, hanging sign, arch keystones, clock
	for z: float in [-5.5, 0.0, 5.5]:
		_window(Vector3(-8 - 4, 4.6, -8.42), 1.6, 1.8, 0)
		_window(Vector3(-8 + 4, 4.6, -8.42), 1.6, 1.8, 0)
		_window(Vector3(-8 - 4, 4.6, 8.42), 1.6, 1.8, 180)
		_window(Vector3(-8 + 4, 4.6, 8.42), 1.6, 1.8, 180)
		break
	block(Vector3(-16.45, 5.2, 0), Vector3(0.1, 0.9, 6.0), m_paint_teal, 0, false, false)
	block(Vector3(-16.5, 5.35, 0), Vector3(0.1, 0.5, 5.0), m_white, 0, false, false)
	deco(_cyl(0.8, 0.1), Vector3(-0.45, 5.6, 0), m_white, Vector3(0, 0, PI * 0.5))
	deco(_cyl(0.65, 0.12), Vector3(-0.5, 5.6, 0), m_dark, Vector3(0, 0, PI * 0.5))
	# checkpoint stripe
	block(Vector3(-5, 0.02, 0), Vector3(0.3, 0.04, 14), m_paint_white, 0, false, false)
	_lantern(Vector3(-11, 5.6, 0), 2.4, 12.0)
	_lantern(Vector3(-5, 5.6, 0), 2.4, 12.0)
	# outside south: lamp + mooring
	_lamp(Vector3(-8, 0, 10.5))


## Attacker spawn 1: the customs annex north of the hall.
func _annex_spawn() -> void:
	var c := Vector3(-8, 0, -15)
	_room(c, 12, 10, 4.5, m_cream, m_roof_dark, [{"side": "s", "at": 6.0, "w": 3.0}, {"side": "e", "at": 5.0, "w": 3.0}])
	_overlay(-14, -20, -2, -10, m_tiles, 0.0)
	_accent(Vector3(-8, 3.05, -10), 3.0, 0, m_cinder)
	_accent(Vector3(-2, 3.05, -15), 3.0, 90, m_cinder)
	_banner(Vector3(-13.7, 1.0, -13), Vector3(1, 0, 0), m_fab_amber)
	_banner(Vector3(-13.7, 1.0, -17), Vector3(1, 0, 0), m_fab_amber)
	prop("furniture_kit/desk.glb", Vector3(-11, 0, -18.5), 0, 2.4)
	prop("furniture_kit/bookcaseOpen.glb", Vector3(-5, 0, -19.6), 0, 2.4)
	prop("furniture_kit/bookcaseOpen.glb", Vector3(-4, 0, -19.6), 0, 2.4)
	prop("furniture_kit/cardboardBoxOpen.glb", Vector3(-3.2, 0, -12.5), 30, 2.4)
	prop("furniture_kit/rugRectangle.glb", Vector3(-9.5, 0.01, -14), 0, 3.0, false)
	prop("furniture_kit/lampRoundFloor.glb", Vector3(-13.2, 0, -19.2), 0, 2.4, false)
	_lantern(Vector3(-8, 3.3, -15), 2.4, 9.0)
	layout.add_health_pack(Vector3(-11, 0, -13), true)
	# lean-to over the connecting corridor between annex and hall
	block(Vector3(-8, 3.4, -9), Vector3(4.2, 0.2, 2.2), m_corr, 0, false)
	_window(Vector3(-1.93, 2.2, -12), 1.2, 1.2, 90)
	_window(Vector3(-1.93, 2.2, -18), 1.2, 1.2, 90)


## --- Leg 2: fish-market street --------------------------------------------------------------------

func _square() -> void:
	_overlay(0, -8, 10, 12, m_paving, 0.01)
	_overlay(-1, -1.6, 5, 4, m_cobble_dark, 0.02)
	prop("fantasy_town_kit/fountain_round.glb", Vector3(5, 0, -3.5), 0, 2.5)
	_puddle(Vector3(5, 0.7, -3.5), 3.6, 3.6)
	deco(_cyl(0.35, 1.6), Vector3(5, 1.4, -3.5), m_stone)
	prop("nature_kit/statue_head.glb", Vector3(5, 2.1, -3.5), 180, 1.2, false)
	prop("city_kit_commercial/detail_parasol_a.glb", Vector3(2.5, 0, 9), 0, 5.0)
	_crates(Vector3(8.2, 0, 10), 15, 1)
	_bench(Vector3(1.2, 0, -6.5), 90)
	_lamp(Vector3(1.2, 0, 4.5))
	# balcony stairs (west end, attackers' access to the high route)
	_stairs_solid(Vector3(4, 0, 1.2), 2.4, 6.0, 4.0, m_stone, -90)
	_railing(Vector3(4, 0, 2.5), Vector3(10, 4.0, 2.5), 1.0)


func _market_street() -> void:
	_overlay(10, 0, 46, 10, m_cobble, 0.01)
	_overlay(7, 4.4, 46, 7.6, m_cobble_dark, 0.02)
	# north buildings (z -8..0)
	_house(Vector3(15.5, 0, -4), Vector3(11, 9.0, 8), m_ochre, m_roof, m_fab_green, 2, "s")
	_house(Vector3(27.75, 0, -4), Vector3(8.5, 11.0, 8), m_rose, m_roof_dark, m_fab_white, 3, "s")
	_house(Vector3(36, 0, -4), Vector3(8, 8.5, 8), m_cream, m_roof, m_fab_teal, 2, "s")
	# alley between the first two buildings (x 21..23.5) with an arch and laundry
	block(Vector3(22.25, 3.6, -4), Vector3(2.6, 0.5, 1.2), m_ochre, 0, false)
	_laundry(Vector3(21.05, 5.4, -6.5), Vector3(23.45, 5.6, -6.5), [m_fab_white, m_fab_teal, m_fab_red])
	_laundry(Vector3(21.05, 6.6, -2.0), Vector3(23.45, 6.4, -2.0), [m_fab_amber, m_fab_white])
	_lantern(Vector3(22.25, 3.2, -4), 1.6, 6.0)
	# balcony walkway (high route) x 10..38 at y 4 with colliding railing
	block(Vector3(24, 3.7, 1.2), Vector3(28, 0.3, 2.4), m_planks_grey)
	_railing(Vector3(10, 4.0, 2.42), Vector3(38, 4.0, 2.42), 1.0)
	_railing(Vector3(10.0, 4.0, 0.05), Vector3(10.0, 4.0, 2.4), 1.0)
	for x: float in [12.0, 19.0, 26.0, 33.0]:
		block(Vector3(x, 0, 2.05), Vector3(0.5, 4.0, 0.5), m_white)
	for x: float in [16.0, 30.0]:
		_lantern(Vector3(x, 3.3, 1.2), 1.8, 8.0)
	block(Vector3(24, 4.0, 1.2), Vector3(28, 0.06, 2.4), m_planks, 0, false, false)
	_crates(Vector3(20, 4.0, 1.0), 0, 1)
	prop("pirate_kit/barrel.glb", Vector3(31, 4.0, 0.7), 0, 0.85)
	prop("furniture_kit/pottedPlant.glb", Vector3(14, 4.0, 0.4), 0, 2.4, false)
	prop("furniture_kit/pottedPlant.glb", Vector3(36.5, 4.0, 0.4), 0, 2.4, false)
	# counter stairs (east end, defenders' access)
	_stairs_solid(Vector3(44, 0, 1.2), 2.4, 6.0, 4.0, m_stone, 90)
	_railing(Vector3(38, 4.0, 2.5), Vector3(44, 0, 2.5), 1.0)
	_railing(Vector3(38, 4.0, -0.05), Vector3(44, 0, -0.05), 1.0)
	# street cover every 6-10 m
	_stall(Vector3(14, 0, 8.6), 0, true)
	_stall(Vector3(26, 0, 8.6), 0, false)
	_stall(Vector3(38, 0, 8.6), 0, true)
	_crates(Vector3(19, 0, 3.6), 20)
	prop("fantasy_town_kit/cart_high.glb", Vector3(31, 0, 3.4), 35, 1.8)
	prop("food_kit/styrofoam.glb", Vector3(30.2, 0.9, 3.0), 30, 0.9, false)
	_barrels(Vector3(41, 0, 8.0), 2, 0)
	prop("furniture_kit/trashcan.glb", Vector3(23.5, 0, 0.6), 0, 2.2)
	prop("food_kit/bag.glb", Vector3(16.6, 0, 0.7), 20, 2.0)
	prop("food_kit/bag.glb", Vector3(17.2, 0, 1.1), -35, 2.0)
	# awnings over shop fronts and hanging lantern lines across the street
	_awning(Vector3(12.5, 3.0, 0.8), 3.2, 1.6, 0, m_fab_red)
	_awning(Vector3(29, 3.0, 0.8), 3.2, 1.6, 0, m_fab_green)
	_awning(Vector3(36, 3.0, 0.8), 3.2, 1.6, 0, m_fab_amber)
	for x: float in [18.0, 28.0, 38.0]:
		block(Vector3(x, 5.6, 5.5), Vector3(0.03, 0.03, 11.0), m_iron, 0, false, false)
		for z: float in [2.5, 5.5, 8.5]:
			block(Vector3(x, 5.1, z), Vector3(0.3, 0.45, 0.3), m_lamp, 0, false, false)
	point_light(Vector3(18, 5.0, 5.5), LAMP, 1.6, 9.0)
	point_light(Vector3(38, 5.0, 5.5), LAMP, 1.6, 9.0)
	# checkpoint 2 stripe
	block(Vector3(33, 0.02, 5), Vector3(0.3, 0.04, 10), m_paint_white, 0, false, false)
	_puddle(Vector3(24, 0, 6), 5.0, 2.0, 20)
	_puddle(Vector3(40, 0, 4), 3.0, 1.5, -10)


func _arcade_and_canal() -> void:
	# arcade roof and pillars (z 10..14.6), south wall with two openings to the boardwalk
	block(Vector3(28, 3.7, 12.3), Vector3(36, 0.3, 4.6), m_roof)
	_gable(Vector3(28, 4.0, 12.3), 35.4, 3.9, m_roof, 1.2)
	for x in range(12, 46, 4):
		block(Vector3(x, 0, 10.4), Vector3(0.6, 4.0, 0.6), m_white)
	_wall_gaps(Vector3(10, 0, 14.3), Vector3(46, 0, 14.3), 4.0, 0.6, m_cream, [Vector2(6, 2.6), Vector2(26, 2.6)], 3.0)
	_overlay(10, 10, 46, 14, m_terrazzo, 0.01)
	# fish tables, ice, nets — the market itself
	for x: float in [18.0, 22.0, 32.0, 42.0]:
		block(Vector3(x, 0, 12.2), Vector3(2.4, 0.9, 1.1), m_marble)
		block(Vector3(x, 0.9, 12.2), Vector3(2.2, 0.15, 0.9), m_white, 0, false, false)
		prop("food_kit/fish.glb", Vector3(x - 0.5, 1.05, 12.1), 90, 1.5, false)
		prop("food_kit/fish.glb", Vector3(x + 0.5, 1.05, 12.3), 80, 1.5, false)
	prop("food_kit/mussel.glb", Vector3(21.5, 1.05, 12.4), 0, 2.0, false)
	prop("survival_kit/bucket.glb", Vector3(19.6, 0, 11.2), 0, 2.4, false)
	prop("survival_kit/bucket.glb", Vector3(33.4, 0, 13.4), 0, 2.4, false)
	for x: float in [14.0, 28.0, 40.0]:
		block(Vector3(x, 2.0, 13.9), Vector3(3.6, 1.8, 0.06), m_tarp, 0, false, false)
	_lantern(Vector3(20, 3.4, 12.2), 1.8, 8.0)
	_lantern(Vector3(40, 3.4, 12.2), 1.8, 8.0)
	layout.add_health_pack(Vector3(37, 0, 12.5), false)
	# boardwalk (z 14.6..17) along the canal, boats moored below
	_overlay(8, 14.6, 46, 17, m_planks, 0.01)
	for x: float in [10.0, 25.0, 44.0]:
		_mooring_post(Vector3(x, 0, 16.6))
	prop("pirate_kit/boat_row_large.glb", Vector3(20, WATER_Y + 0.05, 19.2), 85, 1.5, false)
	prop("pirate_kit/boat_row_small.glb", Vector3(30, WATER_Y + 0.05, 19.6), 100, 1.4, false)
	prop("nature_kit/canoe.glb", Vector3(38, WATER_Y + 0.05, 18.6), 80, 3.0, false)
	prop("survival_kit/fish_large.glb", Vector3(16, 0, 15.5), 0, 2.4, false)
	prop("pirate_kit/barrel.glb", Vector3(41.5, 0, 15.6), 0, 0.85)
	block(Vector3(12.5, 0, 15.8), Vector3(2.0, 0.9, 1.0), m_wood)  # fish-gutting bench
	prop("fantasy_town_kit/lantern.glb", Vector3(15, 0, 16.6), 0, 2.0)
	prop("fantasy_town_kit/lantern.glb", Vector3(35, 0, 16.6), 0, 2.0)
	point_light(Vector3(15, 2.8, 16.6), LAMP, 1.6, 7.0)
	point_light(Vector3(35, 2.8, 16.6), LAMP, 1.6, 7.0)
	layout.add_health_pack(Vector3(26, 0, 15.8), true)
	# hanging nets and floats along the arcade's canal wall
	for x: float in [24.0, 36.0]:
		block(Vector3(x, 1.2, 14.65), Vector3(3.0, 1.6, 0.05), m_tarp, 0, false, false)
		deco(_sphere(0.16), Vector3(x - 1.0, 2.1, 14.85), mat(&"painted_metal", Color(0.95, 0.5, 0.2)))
		deco(_sphere(0.16), Vector3(x + 0.8, 2.3, 14.85), mat(&"painted_metal", Color(0.95, 0.5, 0.2)))


## The back street north of the market (z -14..-8) with the market back-room (attack 2),
## the cold store (defend 0) and a walled garden between them.
func _north_street_and_rooms() -> void:
	_overlay(0, -14, 42, -8, m_cobble_dark, 0.01)
	# sightline breakers along the 40 m street
	prop("car_kit/truck.glb", Vector3(20, 0, -11), 90, 1.4)
	_planter(Vector3(9, 0, -9.0), 0)
	_planter(Vector3(31, 0, -13.0), 0)
	_crates(Vector3(38, 0, -9.2), 10, 1)
	_lamp(Vector3(6, 0, -13.5))
	_lamp(Vector3(36, 0, -8.6))
	# attack 2: market back-room (x 10..20, z -22..-14)
	var a2 := Vector3(15, 0, -18)
	_room(a2, 10, 8, 4.0, m_sage, m_roof_dark, [{"side": "s", "at": 5.0, "w": 3.0}, {"side": "w", "at": 4.0, "w": 2.5}])
	_overlay(10, -22, 20, -14, m_tiles, 0.0)
	_accent(Vector3(15, 3.05, -14), 3.0, 0, m_cinder)
	_accent(Vector3(10, 3.05, -18), 2.5, 90, m_cinder)
	_banner(Vector3(19.7, 0.8, -18), Vector3(-1, 0, 0), m_fab_amber)
	prop("survival_kit/box_large.glb", Vector3(18, 0, -20.8), 0, 2.6)
	prop("survival_kit/box_large.glb", Vector3(18, 0.65, -20.8), 15, 2.6)
	prop("food_kit/barrel.glb", Vector3(12, 0, -20.6), 0, 1.6)
	prop("food_kit/barrel.glb", Vector3(13.2, 0, -20.9), 20, 1.6)
	prop("furniture_kit/table.glb", Vector3(11.5, 0, -16.0), 0, 2.4)
	prop("furniture_kit/radio.glb", Vector3(11.8, 0.8, -16.4), 10, 2.0, false)
	_lantern(Vector3(15, 2.9, -18), 2.2, 8.0)
	layout.add_health_pack(Vector3(16.5, 0, -16.5), true)
	# yard west of the back-room (x 4..10)
	_crates(Vector3(5.5, 0, -19), -30, 1)
	prop("fantasy_town_kit/cart.glb", Vector3(8, 0, -16), 100, 1.8)
	# walled garden (x 20..28) — fig tree, well, laundry, health on the flank
	wall(Vector3(20, 0, -14), Vector3(23, 0, -14), 1.2, 0.4, m_stone)
	wall(Vector3(25, 0, -14), Vector3(28, 0, -14), 1.2, 0.4, m_stone)
	wall(Vector3(20, 0, -22), Vector3(28, 0, -22), 1.2, 0.4, m_stone)
	_overlay(20, -22, 28, -14, m_moss, 0.01)
	_tree(Vector3(26, 0, -19.5), "oak", 2.6)
	deco(_cyl(0.8, 0.9), Vector3(22, 0.45, -19.5), m_stone)
	block(Vector3(22, 0, -19.5), Vector3(1.4, 0.9, 1.4), m_stone, 45)
	_laundry(Vector3(20.2, 3.2, -16), Vector3(27.8, 3.0, -16), [m_fab_white, m_fab_teal, m_fab_white, m_fab_red])
	prop("nature_kit/flower_purpleA.glb", Vector3(21, 0, -21), 0, 2.4, false)
	prop("nature_kit/plant_bush.glb", Vector3(27, 0, -15.2), 0, 2.4, false)
	layout.add_health_pack(Vector3(24, 0, -18), false)
	point_light(Vector3(24, 2.6, -18), Color(1.0, 0.75, 0.5), 1.4, 7.0)
	# defend 0: cold store (x 28..40, z -22..-14)
	var d0 := Vector3(34, 0, -18)
	_room(d0, 12, 8, 4.5, m_white, m_iron, [{"side": "s", "at": 6.0, "w": 3.0}, {"side": "e", "at": 4.0, "w": 3.0}])
	_overlay(28, -22, 40, -14, m_concrete, 0.0)
	_accent(Vector3(34, 3.05, -14), 3.0, 0, m_tide)
	_accent(Vector3(40, 3.05, -18), 3.0, 90, m_tide)
	_banner(Vector3(28.3, 0.8, -18), Vector3(1, 0, 0), m_fab_teal)
	for i in 3:
		block(Vector3(30 + i * 3.2, 0, -21.0), Vector3(2.2, 2.2, 1.4), m_paint_white)
		prop("food_kit/fish.glb", Vector3(30 + i * 3.2, 2.2, -21.0), 90, 1.6, false)
	prop("survival_kit/box_large_open.glb", Vector3(38.5, 0, -15.5), 30, 2.4)
	_lantern(Vector3(34, 3.3, -18), 2.2, 8.0, Color(0.85, 0.95, 1.0))
	layout.add_health_pack(Vector3(31, 0, -16), true)
	block(Vector3(34, 4.9, -18), Vector3(2.0, 1.2, 2.0), m_metal, 0, false)   # roof chiller unit
	# back alley (z -22.5..-17) behind the sheds: containers narrow it to a 1.8 m slot
	_container(Vector3(60, 0, -20.4), 90, "b")
	_container(Vector3(80, 0, -20.4), 90, "a")
	_crates(Vector3(48, 0, -21), 20)
	_lamp(Vector3(70, 0, -22.6))


## --- Leg 3: dry-dock and lighthouse ---------------------------------------------------------------

func _dry_dock() -> void:
	# basin x 46..68, z 0..12, floor DOCK_Y. Payload ramps in (west) and out (east), z 3..9.
	_ramp_solid(Vector3(54, DOCK_Y, 6), 6.0, 8.0, -DOCK_Y, m_concrete, 90)
	_ramp_solid(Vector3(60, DOCK_Y, 6), 6.0, 8.0, -DOCK_Y, m_concrete, -90)
	_overlay(54, 3, 60, 9, m_cobble_dark, DOCK_Y + 0.0)
	# side stairs into the basin: NW (attackers) and SE (defenders)
	_stairs_solid(Vector3(50, DOCK_Y, 1.5), 3.0, 4.0, -DOCK_Y, m_concrete_dark, 90)
	_stairs_solid(Vector3(64, DOCK_Y, 10.5), 3.0, 4.0, -DOCK_Y, m_concrete_dark, -90)
	# rim railings (collide) except where ramps/stairs meet the edge
	_railing(Vector3(46, 0, 0.05), Vector3(68, 0, 0.05))
	_railing(Vector3(46, 0, 11.95), Vector3(64, 0, 11.95))
	_railing(Vector3(46.05, 0, 9), Vector3(46.05, 0, 12))
	_railing(Vector3(67.95, 0, 0), Vector3(67.95, 0, 3))
	# basin dressing: hull section, keel blocks, pump house, puddles, chains
	block(Vector3(57, DOCK_Y, 1.6), Vector3(6.5, 2.0, 2.2), m_rust, 8)
	block(Vector3(57, DOCK_Y + 2.0, 1.6), Vector3(6.6, 0.15, 2.3), m_paint_red, 8, false, false)
	for x: float in [52.0, 56.5, 61.0]:
		block(Vector3(x, DOCK_Y, 10.6), Vector3(1.2, 0.9, 1.2), m_wood)
	block(Vector3(49, DOCK_Y, 10.6), Vector3(3.0, 2.5, 2.4), m_concrete_dark)
	block(Vector3(49, DOCK_Y + 2.5, 10.6), Vector3(3.4, 0.2, 2.8), m_iron, 0, false)
	deco(_cyl(0.3, 2.0), Vector3(50.9, DOCK_Y + 1.0, 9.0), m_rust, Vector3(0, 0, PI * 0.5))
	_puddle(Vector3(51, DOCK_Y, 2.0), 5.0, 2.6, 15)
	_puddle(Vector3(63, DOCK_Y, 10.0), 4.0, 2.2, -20)
	_puddle(Vector3(57, DOCK_Y, 6), 4.0, 3.0, 5)
	_barrels(Vector3(65, DOCK_Y, 1.5), 2, 0)
	_overlay(46, 0, 68, 12, mat(&"concrete_2", Color(0.5, 0.52, 0.5), 1.0), DOCK_Y + 0.0)
	prop("survival_kit/workbench_anvil.glb", Vector3(63, DOCK_Y, 10.4), 0, 2.4)
	layout.add_health_pack(Vector3(52, DOCK_Y, 10.2), true)
	# painted basin name on the north wall
	block(Vector3(56, DOCK_Y + 1.0, 0.04), Vector3(6.0, 0.8, 0.04), m_paint_white, 0, false, false)
	block(Vector3(56, DOCK_Y + 1.2, 0.02), Vector3(5.0, 0.4, 0.04), m_paint_red, 0, false, false)
	# gantry crane bridge across the basin at y 5 (x 55..58), stairs N-west and S-east
	block(Vector3(56.5, 4.7, 6), Vector3(3.0, 0.3, 26.0), m_iron)
	_overlay(55, -7, 58, 19, m_metal, 5.0)
	_railing(Vector3(55.05, 5.0, -7), Vector3(55.05, 5.0, 19), 1.0)
	_railing(Vector3(57.95, 5.0, -7), Vector3(57.95, 5.0, 19), 1.0)
	for p: Vector3 in [Vector3(55.3, 0, -6.2), Vector3(57.7, 0, -6.2), Vector3(55.3, 0, 18.2), Vector3(57.7, 0, 18.2)]:
		block(p, Vector3(0.7, 4.7, 0.7), m_paint_red)
	block(Vector3(56.5, 5.0, 6), Vector3(1.6, 1.3, 1.6), m_paint_red)   # hoist trolley (cover)
	block(Vector3(56.5, 6.3, 6), Vector3(0.06, 4.0, 0.06), m_iron, 0, false, false)
	deco(_torus(0.15, 0.55), Vector3(56.5, DOCK_Y + 1.6, 6), m_iron, Vector3(PI * 0.5, 0, 0))
	block(Vector3(56.5, DOCK_Y + 1.6, 6), Vector3(0.05, 5.5, 0.05), m_iron, 0, false, false)
	_stairs_solid(Vector3(48, 0, -3), 2.4, 7.0, 5.0, m_iron, -90)
	_stairs_solid(Vector3(65, 0, 15), 2.4, 7.0, 5.0, m_iron, 90)
	_railing(Vector3(48, 0, -1.75), Vector3(55, 5.0, -1.75), 1.0)
	_railing(Vector3(58, 5.0, 16.25), Vector3(65, 0, 16.25), 1.0)
	block(Vector3(52, 0, -5.8), Vector3(2.0, 0.4, 0.4), m_paint_red, 0, false, false)
	# north rim (z -6..0) and south rim (z 12..18) cover
	_crates(Vector3(52, 0, -5.0), 0, 1)
	_crates(Vector3(64, 0, -4.4), 25)
	_barrels(Vector3(50, 0, 15.5), 3, 0)
	block(Vector3(60, 0, 16.5), Vector3(2.6, 1.3, 1.4), m_metal)   # winch
	deco(_cyl(0.5, 1.4), Vector3(60, 0.65, 16.5), m_iron, Vector3(0, 0, PI * 0.5))
	for x in range(48, 70, 8):
		_mooring_post(Vector3(x, 0, 17.4))
	_lamp(Vector3(44, 0, -5.4))
	_lamp(Vector3(62, 0, 13.0))
	layout.add_health_pack(Vector3(66, 0, 16.5), false)
	_puddle(Vector3(50, 0, -3), 3.0, 1.6, 30)


func _net_shed_and_harbourmaster() -> void:
	# net shed (flank interior) x 43..51, z -16..-7
	var ns := Vector3(47, 0, -11.5)
	_room(ns, 8, 9, 4.0, m_planks_grey, m_corr, [{"side": "w", "at": 4.5, "w": 2.5}, {"side": "e", "at": 4.5, "w": 2.5}], 0.5, 2.8)
	_overlay(43, -16, 51, -7, m_planks, 0.0)
	block(Vector3(47, 0, -15.2), Vector3(3.0, 0.9, 1.0), m_wood)
	prop("pirate_kit/boat_row_small.glb", Vector3(48.5, 0.7, -8.6), 90, 1.1)
	block(Vector3(47.2, 0, -8.6), Vector3(0.4, 0.7, 2.6), m_wood)
	block(Vector3(49.8, 0, -8.6), Vector3(0.4, 0.7, 2.6), m_wood)
	for z: float in [-13.5, -10.0]:
		block(Vector3(43.45, 1.3, z), Vector3(0.05, 1.8, 2.4), m_tarp, 0, false, false)
	for i in 5:
		deco(_sphere(0.14), Vector3(44.5 + i * 1.1, 3.2, -14.5), mat(&"painted_metal", Color(0.95, 0.5, 0.2)))
	prop("survival_kit/fish_large.glb", Vector3(46.2, 0.9, -15.2), 0, 2.2, false)
	prop("survival_kit/bucket.glb", Vector3(45, 0, -14.4), 0, 2.4, false)
	_lantern(Vector3(47, 3.0, -11.5), 2.0, 8.0)
	layout.add_health_pack(Vector3(45, 0, -11.5), false)
	# defend 1: harbourmaster's office x 54..66, z -17..-7
	var d1 := Vector3(60, 0, -12)
	_room(d1, 12, 10, 4.5, m_cream, m_roof_dark, [{"side": "s", "at": 4.0, "w": 3.0}, {"side": "w", "at": 5.0, "w": 3.0}])
	_overlay(54, -17, 66, -7, m_tiles, 0.0)
	_gable(Vector3(60, 4.9, -12), 12.6, 10.6, m_roof_dark, 2.6)
	_accent(Vector3(58, 3.05, -7), 3.0, 0, m_tide)
	_accent(Vector3(54, 3.05, -12), 3.0, 90, m_tide)
	_banner(Vector3(65.7, 1.0, -10), Vector3(-1, 0, 0), m_fab_teal)
	_banner(Vector3(65.7, 1.0, -14), Vector3(-1, 0, 0), m_fab_teal)
	prop("furniture_kit/desk.glb", Vector3(63, 0, -15.5), 0, 2.4)
	prop("furniture_kit/chairDesk.glb", Vector3(63, 0, -14.4), 180, 2.2, false)
	prop("furniture_kit/radio.glb", Vector3(62.4, 0.8, -15.8), 0, 2.0, false)
	prop("furniture_kit/bookcaseClosed.glb", Vector3(56, 0, -16.6), 0, 2.4)
	prop("furniture_kit/loungeChair.glb", Vector3(56.5, 0, -9.0), 90, 2.2)
	prop("furniture_kit/rugRound.glb", Vector3(60, 0.01, -11), 0, 3.0, false)
	block(Vector3(65.75, 1.2, -12), Vector3(0.06, 1.6, 2.6), mat(&"emissive", Color(0.6, 0.85, 1.0), 1.0), 0, false, false)  # lit chart board
	_lantern(Vector3(60, 3.3, -12), 2.2, 9.0, Color(0.9, 0.95, 1.0))
	layout.add_health_pack(Vector3(60, 0, -9), true)
	_window(Vector3(60, 2.2, -6.93), 1.4, 1.2, 180, m_fab_teal)
	# fuel yard east of the office (x 66..84, z -24..-6): tanks and a fence
	prop("city_kit_industrial/detail_tank_large.glb", Vector3(74, 0, -18), 0, 2.6)
	prop("city_kit_industrial/detail_tank_large.glb", Vector3(79, 0, -18), 0, 2.6)
	prop("city_kit_industrial/detail_tank.glb", Vector3(70, 0, -12), 90, 3.0)
	_barrels(Vector3(76, 0, -10), 4, 0)
	_crates(Vector3(82, 0, -8), -15)
	wall(Vector3(66.5, 0, -6.8), Vector3(84, 0, -6.8), 1.6, 0.1, m_iron)
	block(Vector3(75, 1.6, -6.8), Vector3(17.5, 0.08, 0.08), m_iron, 0, false, false)
	_lamp(Vector3(72, 0, -8.5))


func _lighthouse_pad() -> void:
	_overlay(68, -6, 84, 18, m_paving, 0.02)
	_overlay(68, 4.4, 76, 7.6, m_cobble_dark, 0.03)
	# lighthouse
	var lh := Vector3(80, 0, 14.5)
	block(lh, Vector3(5.0, 1.4, 5.0), m_stone)
	block(lh + Vector3(0, 1.4, 0), Vector3(3.6, 16.0, 3.6), m_paint_white, 45)
	deco(_cyl(2.0, 16.0, 2.3), lh + Vector3(0, 9.4, 0), m_paint_white)
	for y: float in [5.0, 10.0]:
		deco(_cyl(2.13, 1.5, 2.2), lh + Vector3(0, y, 0), m_paint_red)
	deco(_cyl(2.8, 0.3), lh + Vector3(0, 17.4, 0), m_iron)
	deco(_torus(0.06, 2.85), lh + Vector3(0, 18.4, 0), m_iron, Vector3(PI * 0.5, 0, 0))
	deco(_cyl(1.5, 2.4), lh + Vector3(0, 18.8, 0), m_glass)
	deco(_sphere(0.7), lh + Vector3(0, 18.8, 0), mat(&"emissive", Color(1.0, 0.9, 0.7)))
	deco(_cyl(0.2, 1.4, 1.7), lh + Vector3(0, 20.5, 0), m_paint_red)
	spot_light(lh + Vector3(0, 18.8, 0), lh + Vector3(40, 0, 60), Color(1.0, 0.92, 0.75), 6.0, 90.0, 30.0)
	point_light(lh + Vector3(0, 18.8, 0), Color(1.0, 0.9, 0.7), 2.5, 16.0)
	_window(lh + Vector3(-1.85, 3.5, 0), 0.8, 1.2, -90)
	block(lh + Vector3(-1.9, 1.4, 0), Vector3(0.1, 2.2, 1.2), m_dark, 0, false, false)
	# delivery cradle at the end of the track (x 76, z 6)
	deco(_cyl(3.2, 0.14), Vector3(76, 0.07, 6), m_metal)
	deco(_torus(0.1, 3.3), Vector3(76, 0.16, 6), m_tide, Vector3(PI * 0.5, 0, 0))
	for a: float in [0.0, 90.0, 180.0, 270.0]:
		var d := Vector3(sin(deg_to_rad(a)), 0, cos(deg_to_rad(a)))
		block(Vector3(76, 0, 6) + d * 3.9, Vector3(0.5, 1.1, 0.5), m_iron, a)
		deco(_sphere(0.16), Vector3(76, 1.25, 6) + d * 3.9, m_tide)
	# cover: winch house, fuel drums, upturned boat, crates, capstan
	block(Vector3(72, 0, -2), Vector3(4.0, 3.0, 3.0), m_bricks)
	block(Vector3(72, 3.0, -2), Vector3(4.4, 0.3, 3.4), m_corr, 0, false)
	block(Vector3(72, 0, -0.45), Vector3(1.4, 2.2, 0.1), m_dark, 0, false, false)
	_barrels(Vector3(70, 0, 11), 3, 90)
	prop("pirate_kit/boat_row_large.glb", Vector3(73.5, 0, 14.5), 30, 1.4)
	_crates(Vector3(82, 0, 1.5), -20)
	deco(_cyl(0.7, 1.0, 0.8), Vector3(70.5, 0.5, 2.2), m_iron)
	block(Vector3(70.5, 0, 2.2), Vector3(1.2, 1.0, 1.2), m_iron)
	_mooring_post(Vector3(69, 0, 17.4))
	_mooring_post(Vector3(77, 0, 17.4))
	_lamp(Vector3(76, 0, -4.5))
	_lamp(Vector3(70, 0, 9.5))
	layout.add_health_pack(Vector3(75, 0, -4), false)
	_tree(Vector3(83, 0, 17), "palm", 3.6)
	_puddle(Vector3(74, 0, 10), 4.0, 2.2, 25)


## Defend 2: the keeper's house behind the lighthouse (x 84..96, z 1..11).
func _keepers_house() -> void:
	var c := Vector3(90, 0, 6)
	_room(c, 12, 10, 4.5, m_white, m_roof, [{"side": "w", "at": 5.0, "w": 3.0}, {"side": "n", "at": 4.0, "w": 2.5}])
	_overlay(84, 1, 96, 11, m_tiles, 0.0)
	_gable(Vector3(90, 4.9, 6), 12.6, 10.6, m_roof, 2.6)
	_accent(Vector3(84, 3.05, 6), 3.0, 90, m_tide)
	_accent(Vector3(88, 3.05, 1), 2.5, 0, m_tide)
	_banner(Vector3(88, 1.0, 10.7), Vector3(0, 0, -1), m_fab_teal)
	_banner(Vector3(92, 1.0, 10.7), Vector3(0, 0, -1), m_fab_teal)
	prop("furniture_kit/bedSingle.glb", Vector3(93, 0, 2.4), 0, 2.4)
	prop("furniture_kit/tableRound.glb", Vector3(90, 0, 8.4), 0, 2.4)
	prop("furniture_kit/chair.glb", Vector3(89, 0, 8.6), 90, 2.2, false)
	prop("furniture_kit/kitchenStove.glb", Vector3(94.6, 0, 9.4), -90, 2.4)
	prop("furniture_kit/lampRoundFloor.glb", Vector3(85.2, 0, 1.8), 0, 2.4, false)
	prop("furniture_kit/rugRectangle.glb", Vector3(88, 0.01, 4), 0, 3.0, false)
	_lantern(Vector3(90, 3.3, 6), 2.2, 9.0, Color(0.9, 0.95, 1.0))
	layout.add_health_pack(Vector3(92, 0, 5.5), true)
	_window(Vector3(90, 2.2, 11.32), 1.4, 1.2, 180, m_fab_teal)
	_window(Vector3(96.32, 2.2, 6), 1.4, 1.2, 90, m_fab_teal)
	# garden south, rocks east, breakwater
	_overlay(84, 11.3, 98, 18, m_moss, 0.01)
	_tree(Vector3(88, 0, 15), "palm", 3.4)
	prop("nature_kit/plant_bushLarge.glb", Vector3(93, 0, 14), 0, 3.0)
	prop("pirate_kit/rocks_a.glb", Vector3(97.5, -0.4, -8), 20, 1.4, false)
	prop("pirate_kit/rocks_b.glb", Vector3(98.5, -0.4, 14), 200, 1.2, false)
	block(Vector3(104, WATER_Y - 0.4, 0), Vector3(3.0, 1.2, 60.0), m_stone, 0, false)  # breakwater
	_lamp(Vector3(90, 0, -4.8))


## --- Skyline across the water (non-colliding) ------------------------------------------------------

func _skyline() -> void:
	# houses across the canal / south lagoon
	var tints := [m_ochre, m_rose, m_cream, m_sage, m_white]
	var i := 0
	for x in range(-64, 64, 9):
		var h := 7.0 + (i % 3) * 2.0
		var c := Vector3(x + 4.0, WATER_Y, 30.0 + (i % 2) * 3.0)
		block(c, Vector3(8.0, h, 7.0), tints[i % tints.size()], 0, false)
		block(c + Vector3(0, h, 0), Vector3(8.6, 0.3, 7.6), m_roof if i % 2 == 0 else m_roof_dark, 0, false)
		for wx: float in [-2.4, 0.0, 2.4]:
			block(c + Vector3(wx, 2.0, -3.55), Vector3(1.0, 1.4, 0.1), m_lamp if (i + int(wx)) % 3 == 0 else m_glass, 0, false, false)
			block(c + Vector3(wx, 4.6, -3.55), Vector3(1.0, 1.4, 0.1), m_glass, 0, false, false)
		i += 1
	# campanile
	block(Vector3(30, WATER_Y, 38), Vector3(4.5, 26.0, 4.5), m_bricks, 0, false)
	deco(_cyl(0.1, 6.0, 3.4), Vector3(30, WATER_Y + 29.0, 38), m_paint_teal)
	# distant cranes and masts in the east
	for z: float in [-30.0, 30.0]:
		block(Vector3(118, WATER_Y, z), Vector3(1.2, 22.0, 1.2), m_iron, 0, false)
		deco(_box(0.8, 0.8, 18.0), Vector3(118, WATER_Y + 22.0, z + 7.0), m_paint_red, Vector3(0.1, 0, 0))
	prop("pirate_kit/ship_medium.glb", Vector3(-80, WATER_Y, 35), 60, 1.2, false)
	prop("pirate_kit/mast.glb", Vector3(-30, WATER_Y, 24), 0, 1.2, false)


## --- Layout ---------------------------------------------------------------------------------------

func _layout() -> void:
	# Spawn rooms (zone half-extents cover each interior)
	layout.add_spawn_room(&"attack", 0, Vector3(-63, 0, 0), -90.0, Vector3(5.5, 3, 4.5))
	layout.add_spawn_room(&"attack", 1, Vector3(-8, 0, -15), -90.0, Vector3(5.5, 3, 4.5))
	layout.add_spawn_room(&"attack", 2, Vector3(15, 0, -18), 180.0, Vector3(4.5, 3, 3.5))
	layout.add_spawn_room(&"defend", 0, Vector3(34, 0, -18), 180.0, Vector3(5.5, 3, 3.5))
	layout.add_spawn_room(&"defend", 1, Vector3(60, 0, -12), 180.0, Vector3(5.5, 3, 4.5))
	layout.add_spawn_room(&"defend", 2, Vector3(90, 0, 6), 90.0, Vector3(5.5, 3, 4.5))
	# Payload track: dock -> customs hall -> market street -> down through the dry-dock -> lighthouse pad
	var c := Curve3D.new()
	for p: Vector3 in [Vector3(-40, 0, 0), Vector3(-20, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 0.6), Vector3(3, 0, 3.6),
			Vector3(7, 0, 6), Vector3(20, 0, 6), Vector3(33, 0, 6), Vector3(46, 0, 6), Vector3(54, DOCK_Y, 6),
			Vector3(60, DOCK_Y, 6), Vector3(68, 0, 6), Vector3(76, 0, 6)]:
		c.add_point(p)
	layout.payload_path = c
	layout.payload_checkpoints = [c.get_closest_offset(Vector3(-5, 0, 0)), c.get_closest_offset(Vector3(33, 0, 6))]
	layout.phase_count = 3
	layout.kill_z = -6.0
	layout.overview_camera = Transform3D(Basis.from_euler(Vector3(-0.92, 0, 0)), Vector3(14, 108, 80))
	layout.skybox_camera = Transform3D(Basis.from_euler(Vector3(-0.2, 0.6, 0)), Vector3(-30, 6, 20))
	# Lanes (centerlines) for the AI: main, north back streets, south quay/arcade/boardwalk
	layout.lanes.append(PackedVector3Array([Vector3(-56, 0, -1), Vector3(-40, 0, 0), Vector3(-5, 0, 0), Vector3(7, 0, 6), Vector3(33, 0, 6), Vector3(46, 0, 6), Vector3(57, DOCK_Y, 6), Vector3(76, 0, 6)]))
	layout.lanes.append(PackedVector3Array([Vector3(-56, 0, -20), Vector3(-20, 0, -20), Vector3(-6, 0, -22), Vector3(4, 0, -11), Vector3(40, 0, -11), Vector3(44, 0, -3), Vector3(66, 0, -3), Vector3(74, 0, 0), Vector3(76, 0, 6)]))
	layout.lanes.append(PackedVector3Array([Vector3(-60, 0, 8), Vector3(-30, 0, 9.5), Vector3(-8, 0, 10), Vector3(9, 0, 12), Vector3(26, 0, 15.8), Vector3(46, 0, 15), Vector3(62, 0, 15), Vector3(72, 0, 12), Vector3(76, 0, 6)]))
	# Flank routes (bots pick the end nearest the objective)
	layout.flank_routes.append(PackedVector3Array([Vector3(-60, 0, 8), Vector3(-30, 0, 9.5), Vector3(-8, 0, 10), Vector3(5, 0, 10)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(-56, 0, -20), Vector3(-20, 0, -20), Vector3(-6, 0, -22), Vector3(4, 0, -11)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(10, 0, 12), Vector3(26, 0, 15.8), Vector3(46, 0, 15)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(4, 0, -11), Vector3(22, 0, -9), Vector3(40, 0, -11), Vector3(44, 0, -3)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(42, 0, -11.5), Vector3(51, 0, -11.5), Vector3(53, 0, -6)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(47, DOCK_Y, 1.5), Vector3(57, DOCK_Y, 10), Vector3(66, DOCK_Y, 10.5)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(42, 0, -20), Vector3(70, 0, -18.5), Vector3(88, 0, -3)]))
	# High ground with counter-routes, chokepoints, perches
	layout.high_ground.append(layout.make_zone("ferry_deck", Vector3(-38, 3.4, -13), Vector3(11, 2, 3.5)))
	layout.high_ground.append(layout.make_zone("market_balcony", Vector3(24, 4.0, 1.2), Vector3(14, 2, 1.2)))
	layout.high_ground.append(layout.make_zone("gantry", Vector3(56.5, 5.0, 6), Vector3(1.5, 2, 13)))
	layout.high_ground.append(layout.make_zone("north_rim", Vector3(56, 0, -3), Vector3(12, 2, 3)))
	layout.high_ground.append(layout.make_zone("south_rim", Vector3(58, 0, 15), Vector3(12, 2, 3)))
	layout.chokepoints.append(layout.make_zone("hall_west_arch", Vector3(-16, 0, 0), Vector3(2, 3, 4)))
	layout.chokepoints.append(layout.make_zone("hall_east_arch", Vector3(0, 0, 0), Vector3(2, 3, 4)))
	layout.chokepoints.append(layout.make_zone("alley", Vector3(22.25, 0, -4), Vector3(1.5, 3, 4)))
	layout.chokepoints.append(layout.make_zone("dock_ramp_in", Vector3(48, -0.5, 6), Vector3(3, 3, 4)))
	layout.chokepoints.append(layout.make_zone("dock_ramp_out", Vector3(66, -0.5, 6), Vector3(3, 3, 4)))
	layout.perches.append(Vector3(-28.5, 3.4, -11))
	layout.perches.append(Vector3(-47, 3.4, -15))
	layout.perches.append(Vector3(36, 4.0, 1.2))
	layout.perches.append(Vector3(12, 4.0, 1.2))
	layout.perches.append(Vector3(56.5, 5.0, -4))
	layout.perches.append(Vector3(56.5, 5.0, 16))
	layout.perches.append(Vector3(70, 0, -4.5))
	layout.perches.append(Vector3(49, 0, 15.5))
