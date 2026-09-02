class_name TallowBehavior
extends HeroBehavior
## Tallow's passives. Vigil on Tallow herself is exact: while `tallow_vigil` is active, incoming
## damage is clamped so her total health never drops below 1. (Allies get the ward's Last Light
## approximation instead; see docs/REQUESTS.md for the shared `min_health_one` flag request.)

const VIGIL := &"tallow_vigil"


func modify_incoming_damage(ev: DamageEvent) -> void:
	if ev.type == RF.DamageType.TRUE or not pawn.status.has(VIGIL):
		return
	var total := pawn.health.total()
	ev.amount = minf(ev.amount, maxf(total - 1.0, 0.0))
