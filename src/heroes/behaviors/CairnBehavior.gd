extends HeroBehavior
## Cairn passive "High Ground": while standing on top of one of his own slabs Cairn takes 15% less
## damage. The bulwark of height is rewarded for actually using it.

const ON_SLAB_DAMAGE_MULT := 0.85


func modify_incoming_damage(ev: DamageEvent) -> void:
	if ev.type == RF.DamageType.TRUE:
		return
	if _on_own_slab():
		ev.amount *= ON_SLAB_DAMAGE_MULT


func _on_own_slab() -> bool:
	if pawn.world == null or not pawn.is_on_floor():
		return false
	for d: Deployable in pawn.world.deployables_of(pawn):
		if d.destroyed or not d.has_method("is_on_top"):
			continue
		if bool(d.call("is_on_top", pawn)):
			return true
	return false
