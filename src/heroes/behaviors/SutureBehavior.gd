class_name SutureBehavior
extends HeroBehavior
## Suture's passive: the Tether link. Tether marks an ally with `suture_tether`; the two most recently
## tethered allies are linked (or one ally + Suture herself). Whenever Suture heals one end of the link,
## the same amount is copied to the other end. Only Suture's own healing is copied: HeroBehavior only
## sees heals its owner deals (see docs/REQUESTS.md for a world-level heal hook).

const TETHER_ID := &"suture_tether"

var links: Array[Pawn] = []       # most recent last; at most 2 tethered allies
var copied_total: float = 0.0
var _copying: bool = false


func on_spawn() -> void:
	links.clear()
	_copying = false


func on_death(_killer: Pawn) -> void:
	links.clear()


## Register a newly tethered ally. Called by SutureTetherBehavior on both sides (only the server copies).
func link(ally: Pawn) -> void:
	if ally == null or ally == pawn:
		return
	links.erase(ally)
	links.append(ally)
	while links.size() > 2:
		links.pop_front()


func _prune() -> void:
	for i in range(links.size() - 1, -1, -1):
		var q := links[i]
		if q == null or not is_instance_valid(q) or not q.alive or not q.status.has(TETHER_ID):
			links.remove_at(i)


## The other end of the link for `target`, or null when `target` is not on the tether.
func partner_of(target: Pawn) -> Pawn:
	_prune()
	if links.is_empty():
		return null
	if links.size() == 1:
		# One tethered ally: Suture herself is the other end.
		if target == links[0]:
			return pawn
		if target == pawn:
			return links[0]
		return null
	if target == links[0]:
		return links[1]
	if target == links[1]:
		return links[0]
	return null


func on_heal_dealt(amount: float, target: Pawn) -> void:
	if _copying or amount <= 0.0 or pawn.world == null or not pawn.world.is_server:
		return
	var other := partner_of(target)
	if other == null or other == target or not other.alive:
		return
	_copying = true
	var healed := pawn.world.apply_heal(pawn, other, amount, TETHER_ID)
	copied_total += healed
	_copying = false
	if healed > 0.0 and pawn.world.tick % 6 == 0:
		pawn.world.emit_custom(&"suture_tether_pulse", {"pawn": pawn.net_id, "from": target.net_id, "to": other.net_id, "amt": healed, "pos": other.center()})


func linked_ids() -> Array[int]:
	_prune()
	var out: Array[int] = []
	for q: Pawn in links:
		out.append(q.net_id)
	return out
