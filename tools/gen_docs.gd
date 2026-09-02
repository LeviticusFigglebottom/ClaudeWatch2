extends Node
## Generates docs/HEROES.md and docs/MAPS.md from the loaded data plus the per-hero/map notes.
## Run: tools/godot.sh --headless res://tools/gen_docs.tscn

func _ready() -> void:
	_heroes()
	_maps()
	get_tree().quit()


func _slot_row(h: HeroData, slot: int, key: String) -> String:
	var a := h.slot_ability(slot)
	if a == null:
		return ""
	var cd := ""
	if a.is_ultimate():
		cd = "ult %d" % int(a.ult_cost)
	elif a.trigger == AbilityData.Trigger.HOLD and a.fire_rate > 0.0:
		cd = "%.1f/s" % a.fire_rate + (", %d ammo" % a.ammo if a.ammo > 0 else "")
	elif a.cooldown > 0.0:
		cd = "%.0f s" % a.cooldown + (" ×%d" % a.charges if a.charges > 1 else "")
	var nums := _numbers(a)
	return "| %s | **%s** | %s | %s | %s |\n" % [key, a.display_name, cd, nums, a.description.replace("\n", " ")]


func _numbers(a: AbilityData) -> String:
	var parts: Array[String] = []
	for e: AbilityEffect in a.effects + a.tick_effects:
		if e is HitscanEffect:
			var h := e as HitscanEffect
			parts.append("%d dmg hitscan%s%s" % [int(h.damage), (" ×%d" % h.pellets) if h.pellets > 1 else "", (", falloff %d–%d m" % [int(h.falloff_start), int(h.falloff_end)]) if h.falloff_end > h.falloff_start else ""])
		elif e is ProjectileEffect:
			var p := e as ProjectileEffect
			parts.append("%d dmg proj %d m/s%s" % [int(p.damage), int(p.speed), (", splash %d/%dm" % [int(p.splash_damage), int(p.splash_radius)]) if p.splash_radius > 0 else ""])
		elif e is BeamEffect:
			var b := e as BeamEffect
			parts.append("beam %d dps%s" % [int(b.dps), (", heal %d/s" % int(b.heal_per_second)) if b.heal_per_second > 0 else ""])
		elif e is MeleeEffect:
			parts.append("%d melee" % int((e as MeleeEffect).damage))
		elif e is AreaEffect:
			var ar := e as AreaEffect
			parts.append("area r%d%s%s" % [int(ar.radius), (" %d dmg" % int(ar.damage)) if ar.damage > 0 else "", (" %d heal" % int(ar.heal)) if ar.heal > 0 else ""])
		elif e is HealEffect:
			parts.append("heal %d" % int((e as HealEffect).amount))
		elif e is DashEffect:
			parts.append("dash %d m/s" % int((e as DashEffect).speed))
		elif e is DeployEffect:
			parts.append("deploy %s" % (e as DeployEffect).kind)
		elif e is ApplyStatusEffect and (e as ApplyStatusEffect).status:
			parts.append("status %s" % (e as ApplyStatusEffect).status.display_name)
	return ", ".join(parts)


func _heroes() -> void:
	var out := "# Heroes\n\nGenerated from `data/heroes/*.tres` by `tools/gen_docs.tscn`; design notes per hero live in `docs/heroes/<id>.md`.\n\n"
	out += "| Hero | Role | HP / Armor / Shield | Speed | Signature | Counters | Countered by |\n|---|---|---|---|---|---|---|\n"
	for id: StringName in Registry.hero_ids():
		var h := Registry.hero(id)
		out += "| **%s** | %s | %d / %d / %d | %.1f | %s | %s | %s |\n" % [h.display_name, RF.role_name(h.role), int(h.health), int(h.armor), int(h.shield), h.movement.max_speed if h.movement else 5.5, h.unique_mechanic.replace("|", "/"), ", ".join(_names(h.counters)), ", ".join(_names(h.countered_by))]
	out += "\n"
	for id: StringName in Registry.hero_ids():
		var h := Registry.hero(id)
		out += "## %s — %s\n\n*%s*  \n%s\n\n" % [h.display_name, RF.role_name(h.role), h.tagline, h.playstyle]
		out += "| Key | Ability | Cooldown / rate | Numbers | Description |\n|---|---|---|---|---|\n"
		out += _slot_row(h, RF.Slot.PRIMARY, "LMB")
		out += _slot_row(h, RF.Slot.SECONDARY, "RMB")
		out += _slot_row(h, RF.Slot.ABILITY_1, "Shift")
		out += _slot_row(h, RF.Slot.ABILITY_2, "E")
		out += _slot_row(h, RF.Slot.ABILITY_3, "F")
		out += _slot_row(h, RF.Slot.ULTIMATE, "Q")
		out += "\nSynergies: %s  \n" % ", ".join(_names(h.synergies))
		var notes := "res://docs/heroes/%s.md" % id
		if FileAccess.file_exists(notes):
			out += "Design notes: [docs/heroes/%s.md](heroes/%s.md)\n" % [id, id]
		out += "\n"
	var f := FileAccess.open("res://docs/HEROES.md", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("wrote docs/HEROES.md (%d heroes)" % Registry.heroes.size())


func _names(ids: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in ids:
		var h := Registry.hero(id)
		out.append(h.display_name if h else String(id))
	return out


func _maps() -> void:
	var out := "# Maps\n\nGenerated from `data/maps/*.tres`; level design notes per map live in `docs/maps/<id>.md`.\n\n"
	out += "| Map | Modes | Place | Time | Color story |\n|---|---|---|---|---|\n"
	for id: StringName in Registry.map_ids():
		var m := Registry.map(id)
		out += "| **%s** | %s | %s | %s | %s |\n" % [m.display_name, ", ".join(m.supported_modes), m.location, m.time_of_day, m.color_story]
	out += "\n"
	for id: StringName in Registry.map_ids():
		var m := Registry.map(id)
		out += "## %s\n\n%s\n\n" % [m.display_name, m.description]
		if FileAccess.file_exists("res://docs/maps/%s.md" % id):
			out += "Level design notes: [docs/maps/%s.md](maps/%s.md)\n\n" % [id, id]
	var f := FileAccess.open("res://docs/MAPS.md", FileAccess.WRITE)
	f.store_string(out)
	f.close()
	print("wrote docs/MAPS.md (%d maps)" % Registry.maps.size())
