extends MapBuilder
## Nightmarket Vertical — Push. Night, rain. Pearl River Charter.
## A canyon street between stacked hab-towers. The hauler bot starts under the market deck in the
## central plaza and gets pushed along the street spine toward the enemy's metro entrance.
## Mirror-symmetric across z = 0: team A (Cinder) home is -z, team B (Tide) home is +z.
##
## Layers: street (y 0) / sidewalks, alleys, plaza paving (y 0.12) / elevated walkways + market
## deck (y 4) / tower facades. Stairs to the walkways at |z| = 25 and 50, deck ramps at |z| 5..15,
## parking ramps inside the forward spawns. Alleys under the walkways are the ground flanks.

const CINDER := Color(0.98, 0.45, 0.16)
const TIDE := Color(0.16, 0.66, 0.98)
const MAGENTA := Color(1.0, 0.2, 0.6)
const CYAN := Color(0.2, 0.9, 1.0)
const AMBER := Color(1.0, 0.72, 0.25)
const LIME := Color(0.55, 1.0, 0.35)
const SODIUM := Color(1.0, 0.68, 0.32)
const FLUORO := Color(0.82, 0.95, 1.0)

const Z_END := 63.0       # street ends at the metro doors
const WALK_Y := 4.0       # walkway / market deck top surface
const SIDE_Y := 0.12      # sidewalk / alley / plaza paving top

var m_street: Material
var m_walk: Material
var m_alley: Material
var m_plaza: Material
var m_walkway: Material
var m_deck: Material
var m_stair: Material
var m_rail: Material
var m_conc: Material
var m_conc_dark: Material
var m_terrazzo: Material
var m_tiles: Material
var m_wood: Material
var m_glass: Material
var m_water: Material
var m_line: Material
var m_facades: Array[Material] = []
var m_windows: Array[Material] = []
var m_shutters: Array[Material] = []
var light_count := 0


func _ready() -> void:
	# SimWorld renames every map root to "Map" and MapBuilder keys its nav cache on that name, so
	# every map would load data/maps/nav/map.res. Bake under our own id instead.
	var outer := name
	name = "nightmarket"
	super._ready()
	name = outer


func build() -> void:
	setup_environment("rooftop_night", Vector3(0.35, -0.75, 0.25), Color(0.62, 0.72, 1.0), 0.15,
		Color(0.24, 0.3, 0.45), Color(0.3, 0.36, 0.5), 0.02, Color(0.3, 0.35, 0.5), 1.15)
	_materials()
	_ground()
	_towers()
	_walkways()
	_plaza()
	_street_half(-1.0)
	_street_half(1.0)
	_metro(-1.0)
	_metro(1.0)
	_parking(-1.0)   # hosts Tide's forward spawn (z -41..-16)
	_parking(1.0)    # hosts Cinder's forward spawn (z 16..41)
	_pit()
	_rain()
	_layout()


## --- helpers --------------------------------------------------------------------------------------

func _materials() -> void:
	m_street = mat(&"asphalt", Color(0.6, 0.6, 0.65), 1.0)
	m_walk = mat(&"tiles", Color(0.42, 0.48, 0.55), 1.3)
	m_alley = mat(&"cobble", Color(0.42, 0.44, 0.5), 1.0)
	m_plaza = mat(&"tiles", Color(0.55, 0.48, 0.55), 1.6)
	m_walkway = mat(&"metal_plates", Color(0.55, 0.6, 0.7), 1.0)
	m_deck = mat(&"planks_2", Color(0.6, 0.52, 0.48), 1.0)
	m_stair = mat(&"metal_plates", Color(0.45, 0.5, 0.58), 1.4)
	m_rail = mat(&"painted_metal", Color(0.18, 0.2, 0.24), 1.0)
	m_conc = mat(&"concrete_2", Color(0.55, 0.55, 0.6), 1.0)
	m_conc_dark = mat(&"concrete", Color(0.32, 0.32, 0.36), 1.0)
	m_terrazzo = mat(&"terrazzo", Color(0.45, 0.47, 0.52), 1.2)
	m_tiles = mat(&"tiles", Color(0.78, 0.9, 0.85), 0.7)
	m_wood = mat(&"wood", Color(0.7, 0.55, 0.42), 1.0)
	m_glass = mat(&"glass", Color(0.7, 0.85, 1.0))
	m_water = mat(&"water", Color(0.15, 0.25, 0.35))
	m_line = mat(&"emissive", Color(0.75, 0.75, 0.6))
	for t: Color in [Color(0.62, 0.6, 0.66), Color(0.5, 0.55, 0.62), Color(0.68, 0.62, 0.58), Color(0.55, 0.6, 0.6)]:
		m_facades.append(mat(&"facade", t, 0.75))
	for c: Color in [Color(0.9, 0.72, 0.45), Color(0.55, 0.65, 0.85), Color(0.75, 0.6, 0.45), Color(0.45, 0.6, 0.7), Color(0.95, 0.8, 0.6)]:
		m_windows.append(mat(&"emissive", c * 0.45))
	for c: Color in [Color(0.75, 0.3, 0.3), Color(0.3, 0.5, 0.75), Color(0.35, 0.65, 0.5), Color(0.8, 0.65, 0.3), Color(0.5, 0.5, 0.55)]:
		m_shutters.append(mat(&"corrugated", c, 1.5))


## Slab by corner coordinates (any order); y = top surface.
func slab(x0: float, z0: float, x1: float, z1: float, y: float, m: Material, thick: float = 0.5) -> void:
	floor_slab(Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), Vector2(absf(x1 - x0), absf(z1 - z0)), m, thick)


## Solid box by corner coordinates (any order) from y0 to y1.
func box(x0: float, z0: float, x1: float, z1: float, y0: float, y1: float, m: Material) -> void:
	block(Vector3((x0 + x1) * 0.5, y0, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), y1 - y0, absf(z1 - z0)), m)


func deco_box(center: Vector3, size: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return deco(bm, center, m, rot)


## Wall along x at fixed z with door gaps [[x0, x1], ...]; lintels above the gaps.
func wall_x(z: float, x0: float, x1: float, y0: float, h: float, t: float, m: Material, gaps: Array = [], lintel: float = 2.8) -> void:
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	var cur := lo
	for g: Array in gaps:
		var g0 := minf(float(g[0]), float(g[1]))
		var g1 := maxf(float(g[0]), float(g[1]))
		if g0 > cur:
			box(cur, z - t * 0.5, g0, z + t * 0.5, y0, y0 + h, m)
		if h > lintel:
			box(g0, z - t * 0.5, g1, z + t * 0.5, y0 + lintel, y0 + h, m)
		cur = g1
	if hi > cur:
		box(cur, z - t * 0.5, hi, z + t * 0.5, y0, y0 + h, m)


## Wall along z at fixed x with door gaps [[z0, z1], ...].
func wall_z(x: float, z0: float, z1: float, y0: float, h: float, t: float, m: Material, gaps: Array = [], lintel: float = 2.8) -> void:
	var lo := minf(z0, z1)
	var hi := maxf(z0, z1)
	var cur := lo
	for g: Array in gaps:
		var g0 := minf(float(g[0]), float(g[1]))
		var g1 := maxf(float(g[0]), float(g[1]))
		if g0 > cur:
			box(x - t * 0.5, cur, x + t * 0.5, g0, y0, y0 + h, m)
		if h > lintel:
			box(x - t * 0.5, g0, x + t * 0.5, g1, y0 + lintel, y0 + h, m)
		cur = g1
	if hi > cur:
		box(x - t * 0.5, cur, x + t * 0.5, hi, y0, y0 + h, m)


## 1.1 m railing along z at x, with gaps (list of [z0, z1]).
func rail_z(x: float, z0: float, z1: float, y: float, gaps: Array = []) -> void:
	var lo := minf(z0, z1)
	var hi := maxf(z0, z1)
	var cur := lo
	var segs: Array = []
	for g: Array in gaps:
		var g0 := minf(float(g[0]), float(g[1]))
		var g1 := maxf(float(g[0]), float(g[1]))
		if g0 > cur:
			segs.append([cur, g0])
		cur = g1
	if hi > cur:
		segs.append([cur, hi])
	for s: Array in segs:
		box(x - 0.04, float(s[0]), x + 0.04, float(s[1]), y, y + 1.1, m_rail)
		deco_box(Vector3(x, y + 1.08, (float(s[0]) + float(s[1])) * 0.5), Vector3(0.14, 0.12, float(s[1]) - float(s[0])), m_rail)


func rail_x(z: float, x0: float, x1: float, y: float) -> void:
	var lo := minf(x0, x1)
	var hi := maxf(x0, x1)
	box(lo, z - 0.04, hi, z + 0.04, y, y + 1.1, m_rail)
	deco_box(Vector3((lo + hi) * 0.5, y + 1.08, z), Vector3(hi - lo, 0.12, 0.14), m_rail)


## Prop placed by its footprint: `pos` is the center of the model's base regardless of the kit's origin.
func place(path: String, pos: Vector3, yaw_deg: float = 0.0, scale_f: float = 1.0, collide: bool = true) -> Node3D:
	var node := PropLibrary.instance(path)
	if node == null:
		return null
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


func lamp(pos: Vector3, color: Color, energy: float = 2.5, range_: float = 10.0) -> void:
	light_count += 1
	point_light(pos, color, energy, range_)


## Neon sign: emissive slab (non-colliding) with an optional light.
func neon(center: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO, with_light: bool = false, range_: float = 9.0) -> void:
	deco_box(center, size, mat(&"emissive", color), rot)
	if with_light:
		lamp(center, color, 2.6, range_)


## Tower block with dim lit windows on one x-face (face = +1 → +x face, -1 → -x face).
func tower(x0: float, z0: float, x1: float, z1: float, y0: float, top: float, m: Material, face: float, lit: float = 0.5) -> void:
	box(x0, z0, x1, z1, y0, top, m)
	var fx := maxf(x0, x1) if face > 0.0 else minf(x0, x1)
	var xo := fx + face * 0.06
	var y := maxf(y0 + 5.0, 5.0)
	while y < top - 2.5:
		var z := minf(z0, z1) + 2.0
		while z < maxf(z0, z1) - 1.5:
			if rng.randf() < lit:
				deco_box(Vector3(xo, y + 0.7, z + 0.6), Vector3(0.08, 1.4, 1.2), m_windows[rng.randi() % m_windows.size()])
			z += 3.0
		y += 3.2
	# Rooftop silhouette
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	place("city_kit_industrial/detail_tank_large", Vector3(cx + rng.randf_range(-2, 2), top, cz + rng.randf_range(-3, 3)), rng.randf_range(0, 360), 2.5, false)
	place("modular_buildings/detail_ac_a", Vector3(cx - 3, top, cz - 4), 0, 4.0, false)
	place("modular_buildings/detail_ac_a", Vector3(cx + 3, top, cz + 4), 30, 4.0, false)
	box(cx - 0.6, cz - 0.6, cx + 0.6, cz + 0.6, top, top + 1.0, m_conc)   # lift-motor room stub


func shutter(x: float, z: float, y0: float, idx: int, sign_color: Color = Color.TRANSPARENT, with_light: bool = false) -> void:
	var m: Material = m_shutters[idx % m_shutters.size()]
	block(Vector3(x, y0, z), Vector3(0.16, 3.0, 3.2), m)
	deco_box(Vector3(x, y0 + 3.1, z), Vector3(0.3, 0.2, 3.4), m_rust)
	if sign_color.a > 0.0:
		neon(Vector3(x + (0.35 if x < 0 else -0.35), y0 + 3.6, z), Vector3(0.12, 0.55, 2.6), sign_color, Vector3.ZERO, with_light)


var m_rust: Material:
	get:
		return mat(&"rust", Color(0.6, 0.45, 0.35), 1.5)


## --- ground ---------------------------------------------------------------------------------------

func _ground() -> void:
	slab(-32, -82, 32, 82, -0.05, m_conc_dark, 1.0)
	slab(-8, -Z_END, 8, Z_END, 0.0, m_street, 0.6)
	# Lane dashes (deco) outside the plaza
	var i := -58
	while i <= 58:
		if absi(i) > 18:
			deco_box(Vector3(0, 0.01, i), Vector3(0.15, 0.02, 2.4), m_line)
		i += 6
	for s: float in [-1.0, 1.0]:
		slab(s * 8, -Z_END, s * 11, Z_END, SIDE_Y, m_walk, 0.6)
		slab(s * 11, -Z_END, s * 15, Z_END, SIDE_Y, m_alley, 0.6)
		# kerb edge strip (deco)
		deco_box(Vector3(s * 8.0, 0.13, 0), Vector3(0.12, 0.02, Z_END * 2), mat(&"paving", Color(0.6, 0.6, 0.62)))
	slab(-20, -16, -15, 16, SIDE_Y, m_plaza, 0.6)
	slab(15, -16, 20, 16, SIDE_Y, m_plaza, 0.6)
	# Drain grates along the kerbs (deco)
	for z: float in [-52, -38, -24, 24, 38, 52]:
		for s: float in [-1.0, 1.0]:
			deco_box(Vector3(s * 7.6, 0.005, z), Vector3(0.5, 0.01, 1.2), m_rail)


## --- towers ---------------------------------------------------------------------------------------

func _towers() -> void:
	# West side (facade at x = -15; setback to -20 at the plaza; parking bases at |z| 16..41)
	tower(-30, -80, -15, -63, 0, 16, m_facades[3], 1.0)
	tower(-30, -63, -15, -41, 0, 26, m_facades[0], 1.0)
	tower(-30, -41, -15, -16, 7.5, 28, m_facades[1], 1.0)
	tower(-30, -16, -20, 16, 0, 32, m_facades[2], 1.0, 0.6)
	tower(-30, 16, -15, 41, 7.5, 28, m_facades[1], 1.0)
	tower(-30, 41, -15, 63, 0, 24, m_facades[0], 1.0)
	tower(-30, 63, -15, 80, 0, 16, m_facades[3], 1.0)
	# East side (facade at x = 15; pit x 20..26 at the plaza; shop recesses at |z| 36..44)
	tower(15, -80, 30, -63, 0, 16, m_facades[2], -1.0)
	tower(15, -63, 30, -44, 0, 22, m_facades[1], -1.0)
	tower(15, -44, 30, -36, 4.5, 26, m_facades[0], -1.0)
	tower(15, -36, 30, -16, 0, 28, m_facades[3], -1.0)
	tower(26, -16, 30, 16, -8, 32, m_facades[0], -1.0, 0.6)
	tower(15, 16, 30, 36, 0, 28, m_facades[3], -1.0)
	tower(15, 36, 30, 44, 4.5, 26, m_facades[0], -1.0)
	tower(15, 44, 30, 63, 0, 22, m_facades[1], -1.0)
	tower(15, 63, 30, 80, 0, 16, m_facades[2], -1.0)
	# Back walls (behind the metro rooms) and closed loading docks
	box(-32, -82, 32, -80, -1, 14, m_conc_dark)
	box(-32, 80, 32, 82, -1, 14, m_conc_dark)
	for s: float in [-1.0, 1.0]:
		box(-15, s * 63.5, -8, s * 78, 0, 8, m_shutters[4])
		neon(Vector3(-11.5, 6.5, s * 63.35), Vector3(5.0, 0.6, 0.12), Color(0.9, 0.75, 0.5) * 0.5)
		# hab-tower cross-bridges high above the street (silhouette, non-colliding)
		deco_box(Vector3(0, 21.0, s * 52), Vector3(30, 1.6, 3.0), m_conc)
		deco_box(Vector3(0, 27.0, s * 30), Vector3(30, 1.2, 2.2), m_conc)
	# Cables across the canyon
	for z: float in [-45, -20, 8, 36, 58]:
		deco_box(Vector3(0, 9.5 + fmod(absf(z), 3.0), z), Vector3(30, 0.05, 0.05), m_rail)


## --- walkways -------------------------------------------------------------------------------------

func _walkways() -> void:
	for s: float in [-1.0, 1.0]:
		slab(s * 11, -60, s * 15, 60, WALK_Y, m_walkway, 0.4)
		for z: float in [-54, -42, -30, -18, -6, 6, 18, 30, 42, 54]:
			block(Vector3(s * 11.3, SIDE_Y, z), Vector3(0.5, WALK_Y - SIDE_Y, 0.5), m_conc)
		rail_z(s * 11, -60, 60, WALK_Y, [[-53, -50], [-25, -22], [-5, 5], [22, 25], [50, 53]])
		rail_z(s * 15, -16, -5, WALK_Y)
		rail_z(s * 15, 5, 16, WALK_Y)
		rail_x(-60, s * 11, s * 15, WALK_Y)
		rail_x(60, s * 11, s * 15, WALK_Y)
		# Stairs: [top_z, from_z, yaw, landing_z0, landing_z1]
		for cfg: Array in [[-50.0, -42.0, 0.0, -53.0, -50.0], [-25.0, -33.0, 180.0, -25.0, -22.0], [25.0, 33.0, 0.0, 22.0, 25.0], [50.0, 42.0, 180.0, 50.0, 53.0]]:
			stairs(Vector3(s * 9.75, SIDE_Y, float(cfg[1])), 2.5, 8.0, WALK_Y - SIDE_Y, m_stair, float(cfg[2]))
			slab(s * 8, float(cfg[3]), s * 11, float(cfg[4]), WALK_Y, m_walkway, 0.4)
			rail_z(s * 8, float(cfg[3]), float(cfg[4]), WALK_Y)
			var far_z := float(cfg[3]) if absf(float(cfg[3]) - float(cfg[0])) > 0.1 else float(cfg[4])
			rail_x(far_z, s * 8, s * 11, WALK_Y)
		# Kiosks on the walkway (leave 2 m of passage on the inner side)
		for z: float in [-40, -12, 12, 40]:
			var kc: Color = Color(0.35, 0.4, 0.5) if absf(z) > 20 else Color(0.5, 0.32, 0.4)
			block(Vector3(s * 14, WALK_Y, z), Vector3(2.0, 2.6, 2.4), mat(&"painted_metal", kc, 1.0))
			neon(Vector3(s * 12.95, WALK_Y + 2.3, z), Vector3(0.1, 0.4, 2.2), MAGENTA if absf(z) > 20 else CYAN, Vector3.ZERO, absf(z) > 20, 8.0)
			place("furniture_kit/kitchenFridge", Vector3(s * 14.3, WALK_Y, z + 2.2), -90 * s, 2.2)
		# Team banners on the inner rails near each home
		var col: Color = CINDER if s < 0 else TIDE
		for zb: float in [-56, -44]:
			deco_box(Vector3(s * 11.0, WALK_Y + 0.55, zb), Vector3(0.05, 0.9, 2.5), mat(&"emissive", CINDER * 0.7))
			deco_box(Vector3(s * 11.0, WALK_Y + 0.55, -zb), Vector3(0.05, 0.9, 2.5), mat(&"emissive", TIDE * 0.7))
		# Neon hung from the facades above the walkway
		var signs: Array = [[-58, MAGENTA, 7.0], [-47, CYAN, 8.5], [-37, AMBER, 6.5], [-28, LIME, 8.0], [-19, MAGENTA, 7.2],
			[19, CYAN, 7.2], [28, AMBER, 8.0], [37, MAGENTA, 6.5], [47, LIME, 8.5], [58, CYAN, 7.0]]
		for sg: Array in signs:
			var zz := float(sg[0])
			var cc: Color = sg[1]
			var yy := float(sg[2])
			var xf := s * 15.0 if absf(zz) > 16 else s * 20.0
			neon(Vector3(xf - s * 1.3, yy, zz), Vector3(2.4, 3.2, 0.25), cc, Vector3.ZERO, absi(int(zz)) != 37 and absi(int(zz)) != 28, 10.0)
			deco_box(Vector3(xf - s * 1.3, yy + 1.8, zz), Vector3(2.4, 0.1, 0.1), m_rail)


## --- plaza ----------------------------------------------------------------------------------------

func _plaza() -> void:
	# Market deck bridging the two walkways over the street
	slab(-11, -5, 11, 5, WALK_Y, m_deck, 0.4)
	for p: Vector3 in [Vector3(-6, 0, -4.3), Vector3(6, 0, -4.3), Vector3(-6, 0, 4.3), Vector3(6, 0, 4.3)]:
		block(p, Vector3(0.6, WALK_Y - 0.4, 0.6), m_conc)
	for z: float in [-5.0, 5.0]:
		rail_x(z, -11, -10, WALK_Y)
		rail_x(z, -6, 11, WALK_Y)
	ramp(Vector3(-8, SIDE_Y, -15), 4.0, 10.0, WALK_Y - SIDE_Y, m_stair, 180.0)
	ramp(Vector3(-8, SIDE_Y, 15), 4.0, 10.0, WALK_Y - SIDE_Y, m_stair, 0.0)
	for s: float in [-1.0, 1.0]:
		ramp(Vector3(-10.04, SIDE_Y + 0.55, s * 15), 0.08, 10.0, WALK_Y - SIDE_Y, m_rail, 180.0 if s < 0 else 0.0, 1.1)
		ramp(Vector3(-5.96, SIDE_Y + 0.55, s * 15), 0.08, 10.0, WALK_Y - SIDE_Y, m_rail, 180.0 if s < 0 else 0.0, 1.1)
	# Deck dressing: central kiosk (full cover on the high ground), tables, lantern strings
	block(Vector3(0, WALK_Y, 0), Vector3(2.6, 2.4, 2.0), mat(&"painted_metal", Color(0.55, 0.2, 0.35), 1.0))
	deco_box(Vector3(0, WALK_Y + 2.45, 0), Vector3(3.2, 0.1, 2.6), mat(&"tarp", Color(0.8, 0.25, 0.3), 1.0))
	neon(Vector3(0, WALK_Y + 2.9, 0), Vector3(2.2, 0.5, 0.12), MAGENTA, Vector3.ZERO, true, 9.0)
	for p: Vector3 in [Vector3(-5, 0, -2.5), Vector3(5, 0, 2.5), Vector3(-5, 0, 2.5), Vector3(5, 0, -2.5)]:
		place("furniture_kit/table", Vector3(p.x, WALK_Y, p.z), 90, 2.2)
		place("furniture_kit/stoolBar", Vector3(p.x - 1.3, WALK_Y, p.z), 0, 2.2, false)
		place("furniture_kit/stoolBar", Vector3(p.x + 1.3, WALK_Y, p.z), 0, 2.2, false)
		place("food_kit/bowl_soup", Vector3(p.x, WALK_Y + 0.73, p.z), 20, 0.7, false)
	for z: float in [-4.6, 4.6]:
		var x := -10.0
		while x <= 10.0:
			var sm := SphereMesh.new()
			sm.radius = 0.18
			sm.height = 0.36
			deco(sm, Vector3(x, WALK_Y + 2.6, z), mat(&"emissive", Color(1.0, 0.55, 0.3)))
			x += 2.0
		deco_box(Vector3(0, WALK_Y + 2.8, z), Vector3(22, 0.03, 0.03), m_rail)
	_koi(Vector3(0, 11.5, 0))
	# Ground: noodle stalls in the plaza wings, planters + dumpsters as street-edge cover
	_stall(Vector3(-17, SIDE_Y, -9), 1.0, AMBER, "SOUP")
	_stall(Vector3(-17, SIDE_Y, 9), 1.0, MAGENTA, "NOODLE")
	_stall(Vector3(17, SIDE_Y, -9), -1.0, CYAN, "BAO")
	_stall(Vector3(17, SIDE_Y, 9), -1.0, LIME, "TEA")
	for z: float in [-13.0, 13.0]:
		place("city_kit_roads/dumpster", Vector3(6.2, 0, z), 90, 5.0)
		block(Vector3(-5.6, 0, z), Vector3(2.4, 0.7, 1.0), m_conc)
		deco_box(Vector3(-5.6, 0.7, z), Vector3(2.2, 0.12, 0.8), mat(&"moss", Color.WHITE, 2.0))
		place("nature_kit/plant_bushLarge", Vector3(-5.6, 0.74, z), 0, 2.6, false)
	# Billboards on the setback facades
	neon(Vector3(-19.85, 12.0, 0), Vector3(0.12, 6.0, 12.0), MAGENTA * 0.85, Vector3.ZERO, true, 16.0)
	deco_box(Vector3(-19.7, 12.0, 0), Vector3(0.1, 5.0, 3.0), mat(&"emissive", Color(0.95, 0.95, 1.0)))
	neon(Vector3(25.85, 12.0, 0), Vector3(0.12, 6.0, 12.0), CYAN * 0.85, Vector3.ZERO, true, 16.0)
	deco_box(Vector3(25.7, 12.0, 0), Vector3(0.1, 5.0, 3.0), mat(&"emissive", Color(1.0, 0.5, 0.2)))
	# Lantern posts at the plaza corners
	for p: Vector3 in [Vector3(-18.5, SIDE_Y, -15), Vector3(-18.5, SIDE_Y, 15), Vector3(18.5, SIDE_Y, -15), Vector3(18.5, SIDE_Y, 15)]:
		place("fantasy_town_kit/lantern", p, 0, 2.0)


func _stall(pos: Vector3, face: float, col: Color, _label: String) -> void:
	# Counter faces the street (toward -face * x... face = +1 means the street is at +x).
	var cx := pos.x
	block(Vector3(cx - face * 1.0, pos.y, pos.z), Vector3(1.0, 1.0, 3.2), m_wood)               # counter
	block(Vector3(cx + face * 1.4, pos.y, pos.z), Vector3(0.5, 2.3, 3.2), m_shutters[3])        # back shelf
	deco_box(Vector3(cx, pos.y + 2.45, pos.z), Vector3(3.8, 0.08, 3.8), mat(&"tarp", col * 0.8 + Color(0.2, 0.2, 0.2), 1.0))
	for zz: float in [-1.6, 1.6]:
		block(Vector3(cx - face * 1.7, pos.y, pos.z + zz), Vector3(0.12, 2.45, 0.12), m_rail)
	place("food_kit/pot_stew", Vector3(cx - face * 1.0, pos.y + 1.0, pos.z - 0.9), 0, 0.8, false)
	place("food_kit/steamer", Vector3(cx - face * 1.0, pos.y + 1.0, pos.z + 0.6), 0, 0.8, false)
	place("food_kit/styrofoam", Vector3(cx + face * 1.4, pos.y + 2.3, pos.z), 0, 0.5, false)
	place("food_kit/bag", Vector3(cx + face * 0.9, pos.y, pos.z + 1.2), 30, 1.2, false)
	place("food_kit/barrel", Vector3(cx + face * 0.4, pos.y, pos.z - 1.3), 0, 1.3)
	neon(Vector3(cx, pos.y + 2.9, pos.z), Vector3(3.0, 0.6, 0.12), col, Vector3.ZERO, true, 9.0)
	place("furniture_kit/stoolBar", Vector3(cx - face * 2.2, pos.y, pos.z - 0.8), 0, 2.2, false)
	place("furniture_kit/stoolBar", Vector3(cx - face * 2.2, pos.y, pos.z + 0.8), 0, 2.2, false)


func _koi(center: Vector3) -> void:
	var root := Node3D.new()
	root.position = center
	root.rotation = Vector3(0.12, 0.35, 0.08)
	props_root.add_child(root)
	var body := mat(&"emissive", Color(0.7, 0.95, 1.0))
	var fin := mat(&"emissive", Color(1.0, 0.4, 0.7))
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 0.12, 1.6)
	var parts: Array = [
		[sm, Vector3(0, 0, 0), body, Vector3.ZERO, Vector3(7.0, 2.2, 2.4)],
		[sm, Vector3(3.3, 0.1, 0), body, Vector3.ZERO, Vector3(2.6, 2.0, 2.0)],
		[bm, Vector3(-4.4, 0.6, 0), fin, Vector3(0, 0, 0.7), Vector3.ONE],
		[bm, Vector3(-4.4, -0.6, 0), fin, Vector3(0, 0, -0.7), Vector3.ONE],
		[bm, Vector3(0.6, -0.5, 1.3), fin, Vector3(0.5, 0.4, 0), Vector3(0.7, 1, 0.8)],
		[bm, Vector3(0.6, -0.5, -1.3), fin, Vector3(-0.5, -0.4, 0), Vector3(0.7, 1, 0.8)],
		[bm, Vector3(-0.8, 1.05, 0), fin, Vector3(1.5708, 0, 0), Vector3(0.8, 1, 0.6)],
		[sm, Vector3(3.9, 0.55, 0.8), fin, Vector3.ZERO, Vector3(0.5, 0.5, 0.5)],
		[sm, Vector3(3.9, 0.55, -0.8), fin, Vector3.ZERO, Vector3(0.5, 0.5, 0.5)]]
	for p: Array in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.position = p[1]
		mi.material_override = p[2]
		mi.rotation = p[3]
		mi.scale = p[4]
		root.add_child(mi)
	lamp(center + Vector3(0, -2.0, 0), CYAN, 3.5, 20.0)


## --- street halves --------------------------------------------------------------------------------

func _street_half(s: float) -> void:
	var col: Color = CINDER if s < 0 else TIDE
	# Vehicles: sightline breakers and hard cover along the street
	place("car_kit/delivery", Vector3(-2.4, 0, 34 * s), 25 * s, 1.8)
	place("car_kit/taxi", Vector3(5.9, 0, 46 * s), 0, 1.7)
	place("car_kit/van", Vector3(-6.0, 0, 55 * s), 180, 1.7)
	place("car_kit/hatchback_sports", Vector3(6.1, 0, 27 * s), 0, 1.7)
	# Construction pocket
	for i in 3:
		place("city_kit_roads/construction_barrier", Vector3(3.4 + i * 1.1, 0, (40 + (i % 2) * 0.6) * s), 90, 5.0)
	place("city_kit_roads/construction_light", Vector3(2.6, 0, 41.8 * s), 0, 5.0)
	place("city_kit_roads/construction_cone", Vector3(5.2, 0, 42.6 * s), 0, 5.0)
	place("city_kit_roads/construction_cone", Vector3(2.2, 0, 38.4 * s), 0, 5.0)
	# Street lamps (sodium)
	place("city_kit_roads/light_curved", Vector3(9.3, SIDE_Y, 22 * s), -90, 8.0)
	lamp(Vector3(8.0, 5.2, 22 * s), SODIUM, 3.2, 17.0)
	place("city_kit_roads/light_curved", Vector3(-9.3, SIDE_Y, 44 * s), 90, 8.0)
	lamp(Vector3(-8.0, 5.2, 44 * s), SODIUM, 3.2, 17.0)
	place("city_kit_roads/traffic_light", Vector3(8.6, SIDE_Y, 17.5 * s), 180 if s > 0 else 0, 8.0)
	place("city_kit_roads/road_sign_street", Vector3(-8.6, SIDE_Y, 59 * s), 0, 8.0)
	# Shutters on both facades (skip the parking door / bridge and the shop recess)
	var idx := 0
	for z: float in [22, 27, 32, 42, 47, 52, 57]:
		if z != 22 and z != 32:
			shutter(-14.92, z * s, SIDE_Y, idx, MAGENTA if idx % 3 == 0 else Color.TRANSPARENT, idx == 0)
		idx += 1
	for z: float in [22, 27, 32, 47, 52, 57]:
		shutter(14.92, z * s, SIDE_Y, idx + 1, CYAN if idx % 3 == 1 else Color.TRANSPARENT, idx == 4)
		idx += 1
	# Alley clutter (kept against the facade so ≥ 2 m stays clear)
	place("city_kit_roads/dumpster", Vector3(14.2, SIDE_Y, 24 * s), 0, 5.0)
	place("city_kit_roads/dumpster", Vector3(-14.2, SIDE_Y, 50 * s), 0, 5.0)
	for i in 2:
		place("platformer_kit/crate", Vector3(14.4, SIDE_Y + i * 1.0, 30 * s), i * 20, 2.0, i == 0)
	place("platformer_kit/crate", Vector3(-14.4, SIDE_Y, 45 * s), 15, 2.0)
	place("furniture_kit/kitchenFridge", Vector3(14.55, SIDE_Y, 50 * s), -90, 2.2)
	place("furniture_kit/kitchenFridge", Vector3(-14.55, SIDE_Y, 27 * s), 90, 2.2)
	place("furniture_kit/cardboardBoxClosed", Vector3(-14.3, SIDE_Y, 56 * s), 10, 3.0)
	place("furniture_kit/cardboardBoxClosed", Vector3(-13.6, SIDE_Y, 56.9 * s), 40, 3.0, false)
	place("furniture_kit/trashcan", Vector3(8.6, SIDE_Y, 30 * s), 0, 2.2)
	place("furniture_kit/trashcan", Vector3(-8.6, SIDE_Y, 36 * s), 0, 2.2)
	place("furniture_kit/pottedPlant", Vector3(8.7, SIDE_Y, 52 * s), 0, 2.2, false)
	place("city_kit_industrial/detail_tank", Vector3(-13.9, SIDE_Y, 38 * s), 90, 3.0)   # transformer box
	deco_box(Vector3(-13.9, SIDE_Y + 1.4, 38 * s), Vector3(1.0, 0.25, 0.25), mat(&"emissive", AMBER))
	# Street-level gate: overhead sign truss across the street marks the chokepoint
	for x: float in [-7.5, 7.5]:
		block(Vector3(x, 0, 34 * s), Vector3(0.4, 6.0, 0.4), m_rail)
	deco_box(Vector3(0, 6.0, 34 * s), Vector3(15.4, 0.5, 0.5), m_rail)
	neon(Vector3(0, 6.9, 34 * s), Vector3(6.0, 1.1, 0.15), col, Vector3.ZERO, false)
	# Shop recess on the east facade: welding shop (Tide half) / tea house (Cinder half)
	_recess(40 * s, s > 0)
	# Tarps over the sidewalks (deco)
	for z: float in [24, 48]:
		deco_box(Vector3(9.5, 3.4, z * s), Vector3(3.0, 0.06, 2.8), mat(&"tarp", Color(0.3, 0.45, 0.6), 1.0), Vector3(0, 0, 0.12))
		deco_box(Vector3(-9.5, 3.4, (z + 8) * s), Vector3(3.0, 0.06, 2.8), mat(&"tarp", Color(0.65, 0.3, 0.3), 1.0), Vector3(0, 0, -0.12))
	# Puddle sheen (deco, slightly reflective dark quads)
	for z: float in [20, 31, 45, 57]:
		deco_box(Vector3(rng.randf_range(-6, 6), 0.012, z * s), Vector3(rng.randf_range(2, 4), 0.01, rng.randf_range(1.5, 3)), m_water)


func _recess(zc: float, welding: bool) -> void:
	var z0 := zc - 4.0
	var z1 := zc + 4.0
	slab(15, z0, 21, z1, SIDE_Y, mat(&"concrete", Color(0.5, 0.5, 0.52), 1.0), 0.6)
	box(15, z0, 21, z1, 4.0, 4.5, m_conc_dark)
	box(21, z0, 21.5, z1, 0, 4.5, m_conc)
	if welding:
		place("survival_kit/workbench", Vector3(19.5, SIDE_Y, zc - 2.4), 0, 4.0)
		place("survival_kit/workbench", Vector3(19.5, SIDE_Y, zc + 2.4), 0, 4.0)
		block(Vector3(16.8, SIDE_Y, zc + 3.2), Vector3(1.2, 1.6, 0.9), mat(&"painted_metal", Color(0.5, 0.52, 0.5), 1.0))
		deco_box(Vector3(16.8, SIDE_Y + 1.62, zc + 3.2), Vector3(1.1, 0.06, 0.8), mat(&"emissive", AMBER))
		block(Vector3(20.3, SIDE_Y, zc), Vector3(0.6, 2.2, 0.6), mat(&"painted_metal", Color(0.25, 0.25, 0.28), 1.0))
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		deco(sm, Vector3(20.3, SIDE_Y + 2.7, zc), mat(&"emissive", CYAN))       # tesla coil
		for i in 5:
			var sp := SphereMesh.new()
			sp.radius = 0.06
			sp.height = 0.12
			deco(sp, Vector3(19.5 + rng.randf_range(-0.5, 0.5), SIDE_Y + 1.3 + rng.randf_range(0, 0.6), zc - 2.4 + rng.randf_range(-0.4, 0.4)), mat(&"emissive", Color(1, 1, 1)))
		place("survival_kit/barrel", Vector3(16.3, SIDE_Y, zc - 2.8), 0, 3.0)
		place("survival_kit/barrel", Vector3(17.1, SIDE_Y, zc - 3.2), 0, 3.0, false)
		deco_box(Vector3(18, SIDE_Y + 0.02, zc), Vector3(0.06, 0.03, 6.0), m_rail)
		neon(Vector3(15.3, 3.5, zc), Vector3(0.12, 0.6, 5.0), CYAN, Vector3.ZERO, true, 10.0)
		lamp(Vector3(19.5, SIDE_Y + 1.6, zc - 2.4), Color(0.75, 0.9, 1.0), 2.5, 7.0)
	else:
		for zz: float in [zc - 2.2, zc + 2.2]:
			place("furniture_kit/tableRound", Vector3(18.5, SIDE_Y, zz), 0, 2.2)
			place("furniture_kit/chair", Vector3(17.2, SIDE_Y, zz), 90, 2.2, false)
			place("furniture_kit/chair", Vector3(19.8, SIDE_Y, zz), -90, 2.2, false)
			place("food_kit/steamer", Vector3(18.5, SIDE_Y + 0.8, zz), 0, 0.7, false)
		block(Vector3(20.4, SIDE_Y, zc), Vector3(0.9, 1.1, 3.0), m_wood)
		place("furniture_kit/bookcaseOpen", Vector3(20.9, SIDE_Y, zc - 3.3), 90, 2.2, false)
		place("fantasy_town_kit/lantern", Vector3(16.0, SIDE_Y, zc - 3.3), 0, 1.6, false)
		place("fantasy_town_kit/lantern", Vector3(16.0, SIDE_Y, zc + 3.3), 0, 1.6, false)
		neon(Vector3(15.3, 3.5, zc), Vector3(0.12, 0.6, 5.0), Color(1.0, 0.25, 0.2), Vector3.ZERO, true, 10.0)
		lamp(Vector3(18.5, SIDE_Y + 3.3, zc), Color(1.0, 0.55, 0.35), 2.2, 7.0)


## --- metro (back spawns) --------------------------------------------------------------------------

func _metro(s: float) -> void:
	var col: Color = CINDER if s < 0 else TIDE
	var role: StringName = &"a" if s < 0 else &"b"
	var zn := 64.0 * s      # front (street) end of the interior
	var zf := 76.0 * s      # back end
	slab(-8, zn, 8, zf, 0.0, m_terrazzo, 0.6)
	box(-8.5, zn - 0.5 * s, 8.5, zf + 0.5 * s, 4.0, 4.6, m_conc_dark)
	wall_x(zn - 0.25 * s, -8.5, 8.5, 0, 4.0, 0.5, m_tiles, [[-6, -3.6], [3.6, 6]])
	wall_x(zf + 0.25 * s, -8.5, 8.5, 0, 4.0, 0.5, m_tiles)
	wall_z(-8.25, zn - 0.5 * s, zf + 0.5 * s, 0, 4.0, 0.5, m_tiles)
	wall_z(8.25, zn - 0.5 * s, zf + 0.5 * s, 0, 4.0, 0.5, m_tiles, [[67 * s, 69.6 * s]])
	# Dressing: turnstiles along the side walls, ticket booth, vending, benches, route map
	for x: float in [-7.4, -6.2, 6.2, 7.4]:
		block(Vector3(x, 0, 70 * s), Vector3(0.35, 1.0, 1.0), mat(&"painted_metal", Color(0.6, 0.62, 0.65), 1.0))
	block(Vector3(-6.0, 0, 74.2 * s), Vector3(2.6, 2.4, 1.8), m_tiles)
	deco_box(Vector3(-6.0, 1.5, (74.2 - 0.95) * s), Vector3(2.0, 0.9, 0.05), m_glass)
	place("furniture_kit/kitchenFridge", Vector3(6.6, 0, 75.3 * s), 180 if s > 0 else 0, 2.2)
	place("furniture_kit/kitchenFridge", Vector3(5.4, 0, 75.3 * s), 180 if s > 0 else 0, 2.2)
	place("furniture_kit/bench", Vector3(0, 0, 75.2 * s), 90, 2.2)
	place("furniture_kit/trashcan", Vector3(-7.4, 0, 65.5 * s), 0, 2.2, false)
	deco_box(Vector3(0, 2.2, 75.85 * s), Vector3(4.0, 2.0, 0.08), mat(&"emissive", Color(0.35, 0.55, 0.65)))
	deco_box(Vector3(0, 2.2, 75.8 * s), Vector3(0.12, 1.6, 0.1), mat(&"emissive", col))
	deco_box(Vector3(0, 3.92, 70 * s), Vector3(15.6, 0.08, 0.12), mat(&"emissive", col))
	deco_box(Vector3(-7.9, 3.0, 70 * s), Vector3(0.1, 0.5, 11.0), mat(&"emissive", col * 0.8))
	# Exterior: roundel and sign over the doors, yard to the east with a service van
	var cm := CylinderMesh.new()
	cm.top_radius = 1.2
	cm.bottom_radius = 1.2
	cm.height = 0.12
	deco(cm, Vector3(0, 5.2, (zn - 0.62) * 1.0 if s > 0 else zn + 0.62), mat(&"emissive", col), Vector3(1.5708, 0, 0))
	neon(Vector3(0, 3.4, zn - 0.6 * s), Vector3(7.0, 0.7, 0.12), col, Vector3.ZERO, true, 12.0)
	slab(8, zn - 1.0 * s, 15, zf + 2.0 * s, SIDE_Y, m_street, 0.6)
	box(8, zf + 2.0 * s, 15, zf + 2.5 * s, 0, 8, m_conc_dark)
	place("car_kit/delivery", Vector3(11.8, SIDE_Y, 72 * s), 0, 1.7)
	place("city_kit_roads/dumpster", Vector3(13.8, SIDE_Y, 66 * s), 90, 5.0)
	place("survival_kit/box_large", Vector3(9.5, SIDE_Y, 76.5 * s), 0, 4.0)
	lamp(Vector3(-4, 3.6, 70 * s), FLUORO, 2.4, 10.0)
	lamp(Vector3(4, 3.6, 70 * s), col, 2.2, 10.0)
	# Layout
	layout.add_spawn_room(role, 0, Vector3(0, 0, 70 * s), 180.0 if s < 0 else 0.0, Vector3(8, 2.5, 6))
	layout.add_health_pack(Vector3(6.6, 0, 66 * s), false)


## --- parking structures (forward spawns) ----------------------------------------------------------

func _parking(s: float) -> void:
	# The structure on the +z half is used by team A (Cinder) once it has pushed past 66 %, and
	# vice versa, so the forward spawn always sits on the enemy's half of the street.
	var col: Color = CINDER if s > 0 else TIDE
	var role: StringName = &"a" if s > 0 else &"b"
	var z0 := 16.0 * s
	var z1 := 41.0 * s
	var m_floor := mat(&"concrete", Color(0.45, 0.45, 0.48), 1.2)
	var m_wallp := mat(&"plaster_painted", Color(0.7, 0.7, 0.72), 1.0)
	slab(-29.5, z0, -15, z1, SIDE_Y, m_floor, 0.6)
	box(-29.5, z0 - 0.5 * s, -15, z1 + 0.5 * s, 7.0, 7.5, m_conc_dark)
	box(-29.5, z0 - 0.5 * s, -29, z1 + 0.5 * s, 0, 7.0, m_wallp)
	box(-29.5, z0 - 0.5 * s, -15, z0, 0, 7.0, m_wallp)
	box(-29.5, z1, -15, z1 + 0.5 * s, 0, 7.0, m_wallp)
	# Inner wall (alley facade): ground door at z 18..20.6, open bridge bay at z 38..41 above y 4
	wall_z(-15.25, z0, 38 * s, SIDE_Y, 6.88, 0.5, m_wallp, [[18 * s, 20.6 * s]])
	box(-15.5, 38 * s, -15, z1, SIDE_Y, WALK_Y, m_wallp)
	# Ramp up to the bridge deck, deck at y 4 across the north end, railing on its inner edge
	ramp(Vector3(-27, SIDE_Y, 28 * s), 4.0, 10.0, WALK_Y - SIDE_Y, m_floor, 180.0 if s > 0 else 0.0)
	ramp(Vector3(-25.04, SIDE_Y + 0.5, 28 * s), 0.08, 10.0, WALK_Y - SIDE_Y, m_rail, 180.0 if s > 0 else 0.0, 1.0)
	slab(-29, 38 * s, -15.5, z1, WALK_Y, m_floor, 0.4)
	rail_x(38 * s, -25, -15.5, WALK_Y)
	for zz: float in [22, 28, 34]:
		block(Vector3(-22, SIDE_Y, zz * s), Vector3(0.6, 7.0 - SIDE_Y, 0.6), m_conc)
	# Parked cars in the ramp bay, bays painted on the floor
	place("car_kit/sedan", Vector3(-19.5, SIDE_Y, 31 * s), 90, 1.7)
	place("car_kit/hatchback_sports", Vector3(-19.5, SIDE_Y, 35.5 * s), 90, 1.7)
	for i in 4:
		deco_box(Vector3(-19.5, SIDE_Y + 0.01, (29 + i * 2.6) * s), Vector3(4.6, 0.01, 0.12), m_line)
	place("city_kit_industrial/detail_tank", Vector3(-28.2, SIDE_Y, 24 * s), 0, 3.0)
	place("furniture_kit/cardboardBoxClosed", Vector3(-28.0, SIDE_Y, 26.5 * s), 20, 3.0)
	# Signage: team colour strips inside, "P" lightbox on the alley facade beside the door
	deco_box(Vector3(-22, 6.9, 28.5 * s), Vector3(13, 0.1, 0.12), mat(&"emissive", col))
	deco_box(Vector3(-28.9, 3.0, 22 * s), Vector3(0.1, 0.6, 8.0), mat(&"emissive", col * 0.8))
	neon(Vector3(-14.7, 3.4, 22.5 * s), Vector3(0.14, 1.4, 1.4), col, Vector3.ZERO, true, 8.0)
	deco_box(Vector3(-15.55, 3.2, 39.5 * s), Vector3(0.1, 0.6, 2.4), mat(&"emissive", col))
	lamp(Vector3(-22, 6.5, 21 * s), FLUORO, 2.6, 12.0)
	lamp(Vector3(-22, 6.5, 35 * s), col, 2.4, 12.0)
	# Layout: custom spawn points in the room half, health pack in the far corner
	var r := layout.add_spawn_room(role, 1, Vector3(-22.25, SIDE_Y, 28.5 * s), -90.0, Vector3(6.75, 3, 12.5))
	r.points.clear()
	for x: float in [-26.0, -22.0, -18.0]:
		for zz: float in [20.0, 25.0]:
			r.points.append(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(x, SIDE_Y, zz * s)))
	layout.add_health_pack(Vector3(-27.5, SIDE_Y, 18 * s), false)


## --- pit (east plaza edge) ------------------------------------------------------------------------

func _pit() -> void:
	slab(20, -16, 26, 16, -8.0, m_conc_dark, 1.0)
	box(19.5, -16, 20, 16, -8.0, -0.5, m_conc)
	box(20, 16, 26, 16.5, -8.0, SIDE_Y, m_conc)
	box(20, -16.5, 26, -16, -8.0, SIDE_Y, m_conc)
	block(Vector3(23, -7.6, 0), Vector3(6, 0.1, 32), m_water, 0, false, false)
	rail_z(20, -16, 16, SIDE_Y, [[-13, -11], [11, 13]])
	place("space_kit/craft_speederA", Vector3(23, -7.6, 3), 35, 1.6, false)
	for z: float in [-12, -4, 4, 12]:
		place("space_kit/pipe_straight", Vector3(25, -8, z), 0, 3.0, false)
	for z: float in [-14, -6, 2, 10]:
		block(Vector3(20.6, -8, z), Vector3(0.15, 8.0, 0.15), m_rust)
	deco_box(Vector3(23, -1.2, 0), Vector3(6, 0.15, 0.15), m_rust)
	place("city_kit_roads/construction_fence", Vector3(21.0, SIDE_Y, -12), 0, 5.0, false)
	place("city_kit_roads/construction_fence", Vector3(21.0, SIDE_Y, 12), 0, 5.0, false)
	neon(Vector3(22.5, 0.6, -14.5), Vector3(1.6, 0.4, 0.1), AMBER, Vector3.ZERO, false)
	lamp(Vector3(23, -3.5, 0), Color(0.35, 0.9, 0.55), 2.0, 14.0)


## --- rain -----------------------------------------------------------------------------------------

func _rain() -> void:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = 2600
	p.lifetime = 2.4
	p.preprocess = 2.4
	p.visibility_aabb = AABB(Vector3(-40, -45, -95), Vector3(80, 60, 190))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 0.5, 84)
	pm.direction = Vector3(0.05, -1, 0)
	pm.spread = 1.5
	pm.initial_velocity_min = 13.0
	pm.initial_velocity_max = 17.0
	pm.gravity = Vector3(0, -5.0, 0)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.025, 0.45)
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.72, 0.8, 1.0, 0.3)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mm
	p.draw_pass_1 = qm
	p.position = Vector3(0, 34, 0)
	props_root.add_child(p)


## --- layout ---------------------------------------------------------------------------------------

func _layout() -> void:
	var track := Curve3D.new()
	for p: Vector3 in [Vector3(0, 0, -62), Vector3(0, 0, -40), Vector3(0, 0, -22), Vector3(1.5, 0, -10), Vector3(1.5, 0, 10), Vector3(0, 0, 22), Vector3(0, 0, 40), Vector3(0, 0, 62)]:
		track.add_point(p)
	layout.push_track = track
	layout.push_start_offset = track.get_baked_length() * 0.5
	layout.push_barrier_offsets = [track.get_baked_length() * 0.4, track.get_baked_length() * 0.6]
	layout.phase_count = 2
	# Health packs: flanks only (alleys, walkways, shop recesses) — never on the street.
	layout.add_health_pack(Vector3(18.5, SIDE_Y, -40), true)
	layout.add_health_pack(Vector3(18.5, SIDE_Y, 40), true)
	layout.add_health_pack(Vector3(-13, SIDE_Y, -30), false)
	layout.add_health_pack(Vector3(-13, SIDE_Y, 30), false)
	layout.add_health_pack(Vector3(12.5, WALK_Y, -46), false)
	layout.add_health_pack(Vector3(12.5, WALK_Y, 46), false)
	layout.kill_z = -3.0
	layout.bounds_min = Vector3(-40, -12, -90)
	layout.bounds_max = Vector3(40, 60, 90)
	var cam_pos := Vector3(-62, 66, -108)
	layout.overview_camera = Transform3D(Basis.looking_at((Vector3(0, 2, 0) - cam_pos).normalized(), Vector3.UP), cam_pos)
	layout.skybox_camera = Transform3D(Basis.looking_at(Vector3(0.3, 0.25, -1).normalized(), Vector3.UP), Vector3(0, 6, 8))
	layout.lanes.append(PackedVector3Array([Vector3(0, 0, -62), Vector3(0, 0, -34), Vector3(1.5, 0, 0), Vector3(0, 0, 34), Vector3(0, 0, 62)]))
	layout.lanes.append(PackedVector3Array([Vector3(-9.5, SIDE_Y, -55), Vector3(-9.75, WALK_Y, -50), Vector3(-13, WALK_Y, -25), Vector3(-13, WALK_Y, 0), Vector3(-13, WALK_Y, 25), Vector3(-9.75, WALK_Y, 50), Vector3(-9.5, SIDE_Y, 55)]))
	layout.lanes.append(PackedVector3Array([Vector3(9.5, SIDE_Y, -55), Vector3(9.75, WALK_Y, -50), Vector3(13, WALK_Y, -25), Vector3(13, WALK_Y, 0), Vector3(13, WALK_Y, 25), Vector3(9.75, WALK_Y, 50), Vector3(9.5, SIDE_Y, 55)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(-13, SIDE_Y, -58), Vector3(-13, SIDE_Y, -30), Vector3(-17, SIDE_Y, 0), Vector3(-13, SIDE_Y, 30), Vector3(-13, SIDE_Y, 58)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(13, SIDE_Y, -58), Vector3(13, SIDE_Y, -30), Vector3(17.5, SIDE_Y, 0), Vector3(13, SIDE_Y, 30), Vector3(13, SIDE_Y, 58)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(-13, WALK_Y, -45), Vector3(-13, WALK_Y, 0), Vector3(-13, WALK_Y, 45)]))
	layout.flank_routes.append(PackedVector3Array([Vector3(13, WALK_Y, -45), Vector3(13, WALK_Y, 0), Vector3(13, WALK_Y, 45)]))
	layout.high_ground.append(layout.make_zone("market_deck", Vector3(0, WALK_Y, 0), Vector3(11, 1.5, 5)))
	for s: float in [-1.0, 1.0]:
		layout.high_ground.append(layout.make_zone("west_walkway_%s" % ("a" if s < 0 else "b"), Vector3(-13, WALK_Y, 30 * s), Vector3(2, 1.5, 28)))
		layout.high_ground.append(layout.make_zone("east_walkway_%s" % ("a" if s < 0 else "b"), Vector3(13, WALK_Y, 30 * s), Vector3(2, 1.5, 28)))
		layout.high_ground.append(layout.make_zone("parking_bridge_%s" % ("a" if s < 0 else "b"), Vector3(-22, WALK_Y, 39.5 * s), Vector3(7, 1.5, 1.5)))
		layout.chokepoints.append(layout.make_zone("street_gate_%s" % ("a" if s < 0 else "b"), Vector3(0, 0, 34 * s), Vector3(8, 2, 3)))
		layout.chokepoints.append(layout.make_zone("deck_ramp_%s" % ("a" if s < 0 else "b"), Vector3(-8, 2, 10 * s), Vector3(2.5, 2.5, 5)))
		layout.chokepoints.append(layout.make_zone("metro_doors_%s" % ("a" if s < 0 else "b"), Vector3(0, 0, 62 * s), Vector3(8, 2, 2)))
		for x: float in [-1.0, 1.0]:
			layout.perches.append(Vector3(x * 13, WALK_Y, 12 * s))
			layout.perches.append(Vector3(x * 9.5, WALK_Y, 51.5 * s))
			layout.perches.append(Vector3(x * 9.5, WALK_Y, 23.5 * s))
		layout.perches.append(Vector3(-9.5, WALK_Y, 4.3 * s))
		layout.perches.append(Vector3(9.5, WALK_Y, 4.3 * s))
	layout.perches.append(Vector3(-22, WALK_Y, 39.5))
	layout.perches.append(Vector3(-22, WALK_Y, -39.5))
	if light_count > 45:
		push_warning("Nightmarket: %d point lights (budget 45)" % light_count)
