class_name FerryBehavior
extends HeroBehavior
## Ferry's passive bookkeeping: knows her team's Waystone and counts crossings. Dead pawns keep their
## position, so Crossing reads `pawn.global_position` of dead allies directly; `death_pos` meta is also
## stamped on death for anything that wants it.

var crossings: int = 0
var waystone_teleports: int = 0


func waystone() -> Deployable:
	var list := pawn.world.deployables_of(pawn, &"waystone")
	return list[0] if not list.is_empty() else null


func on_death(_killer: Pawn) -> void:
	pawn.set_meta("death_pos", pawn.global_position)


## Dead allies Ferry could bring back right now: within `radius`, died less than `max_age` seconds ago.
func resurrect_candidates(radius: float, max_age: float) -> Array[Pawn]:
	var out: Array[Pawn] = []
	var world := pawn.world
	var max_ticks := int(max_age / RF.TICK_DT)
	for q: Pawn in world.pawns.values():
		if q == pawn or q.alive or q.team != pawn.team:
			continue
		if world.tick - q.death_tick > max_ticks:
			continue
		if q.global_position.distance_to(pawn.global_position) > radius:
			continue
		out.append(q)
	out.sort_custom(func(a: Pawn, b: Pawn) -> bool:
		return a.global_position.distance_to(pawn.global_position) < b.global_position.distance_to(pawn.global_position))
	return out
