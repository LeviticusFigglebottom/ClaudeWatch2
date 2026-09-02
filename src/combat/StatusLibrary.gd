class_name StatusLibrary
## Registry of StatusData by id, discovered from data/status/*.tres and from hero ability resources.
## Client needs it to mirror server status events by id.

static var _cache: Dictionary = {}
static var _scanned: bool = false


static func get_status(id: StringName) -> StatusData:
	if not _scanned:
		_scan()
	return _cache.get(id) as StatusData


static func register(sd: StatusData) -> void:
	if sd and sd.id != &"":
		_cache[sd.id] = sd


static func _scan() -> void:
	_scanned = true
	var dir := DirAccess.open("res://data/status")
	if dir:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				var r := load("res://data/status/" + f) as StatusData
				if r: register(r)
			f = dir.get_next()
	# Also pull statuses referenced by hero kits.
	for h: HeroData in Registry.heroes.values():
		for s: StatusData in h.passives:
			register(s)
		for slot in RF.SLOT_COUNT:
			var ab := h.slot_ability(slot)
			if ab == null: continue
			if ab.self_status_while_active: register(ab.self_status_while_active)
			for e: AbilityEffect in ab.effects + ab.tick_effects + ab.end_effects:
				_register_from_effect(e)


static func _register_from_effect(e: AbilityEffect) -> void:
	if e == null:
		return
	for prop: Dictionary in e.get_property_list():
		if prop["type"] == TYPE_OBJECT:
			var v: Variant = e.get(prop["name"])
			if v is StatusData:
				register(v)
			elif v is AbilityEffect:
				_register_from_effect(v)
		elif prop["type"] == TYPE_ARRAY:
			var arr: Variant = e.get(prop["name"])
			if arr is Array:
				for item: Variant in arr:
					if item is AbilityEffect:
						_register_from_effect(item)
					elif item is StatusData:
						register(item)
