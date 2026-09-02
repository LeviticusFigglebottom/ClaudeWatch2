extends Node
## Content registry. Everything data-driven (heroes, maps, modes, tuning) is discovered from
## res://data at boot and exposed by id. Adding content = dropping a .tres in the right folder.

const HERO_DIR := "res://data/heroes"
const MAP_DIR := "res://data/maps"
const MODE_DIR := "res://data/modes"
const TUNING_PATH := "res://data/tuning/global_tuning.tres"

var heroes: Dictionary = {}   # StringName -> HeroData
var maps: Dictionary = {}     # StringName -> MapData
var modes: Dictionary = {}    # StringName -> ModeData
var tuning: GlobalTuning

var _hero_order: Array[StringName] = []
var _map_order: Array[StringName] = []
var _mode_order: Array[StringName] = []


func _ready() -> void:
	reload()


func reload() -> void:
	heroes.clear(); maps.clear(); modes.clear()
	_hero_order.clear(); _map_order.clear(); _mode_order.clear()
	tuning = load(TUNING_PATH) as GlobalTuning
	if tuning == null:
		tuning = GlobalTuning.new()
	for res: Resource in _load_all(HERO_DIR, "HeroData"):
		var h := res as HeroData
		heroes[h.id] = h
		_hero_order.append(h.id)
	for res: Resource in _load_all(MAP_DIR, "MapData"):
		var m := res as MapData
		maps[m.id] = m
		_map_order.append(m.id)
	for res: Resource in _load_all(MODE_DIR, "ModeData"):
		var md := res as ModeData
		modes[md.id] = md
		_mode_order.append(md.id)
	_hero_order.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ha: HeroData = heroes[a]; var hb: HeroData = heroes[b]
		if ha.role != hb.role: return ha.role < hb.role
		return ha.sort_order < hb.sort_order)


func _load_all(dir_path: String, klass: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and (f.ends_with(".tres") or f.ends_with(".res")):
			var r := load(dir_path.path_join(f))
			if r != null and r.is_class("Resource") and (r.get_script() != null and (r.get_script() as Script).get_global_name() == klass or ClassDB.is_parent_class(r.get_class(), klass)):
				out.append(r)
			elif r != null and r.get_script() != null:
				# Subclasses of the requested class are fine too.
				var s: Script = r.get_script()
				while s != null:
					if s.get_global_name() == klass:
						out.append(r); break
					s = s.get_base_script()
		f = dir.get_next()
	dir.list_dir_end()
	return out


func hero(id: StringName) -> HeroData:
	return heroes.get(id) as HeroData


func map(id: StringName) -> MapData:
	return maps.get(id) as MapData


func mode(id: StringName) -> ModeData:
	return modes.get(id) as ModeData


func hero_ids() -> Array[StringName]:
	return _hero_order.duplicate()


func map_ids() -> Array[StringName]:
	return _map_order.duplicate()


func mode_ids() -> Array[StringName]:
	return _mode_order.duplicate()


func heroes_by_role(role: int) -> Array[HeroData]:
	var out: Array[HeroData] = []
	for id: StringName in _hero_order:
		var h: HeroData = heroes[id]
		if h.role == role:
			out.append(h)
	return out


func hero_index(id: StringName) -> int:
	return _hero_order.find(id)


func hero_from_index(i: int) -> HeroData:
	if i < 0 or i >= _hero_order.size():
		return null
	return heroes[_hero_order[i]]


func maps_for_mode(mode_id: StringName) -> Array[MapData]:
	var out: Array[MapData] = []
	for id: StringName in _map_order:
		var m: MapData = maps[id]
		if m.supported_modes.has(mode_id):
			out.append(m)
	return out
