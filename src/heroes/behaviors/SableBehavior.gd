class_name SableBehavior
extends HeroBehavior
## Sable's Shroud rule: while the Shroud toggle is active she is invisible only when moving below
## 40% of max speed and not striking. Moving faster or landing a blade hit removes the status and
## starts a 1 s lockout before it can settle back. Runs on server and predicting client.

const SPEED_FRACTION := 0.4
const LOCKOUT := 1.0
const STRIKE_LOCK_TICKS := 60

var _lockout: float = 0.0
var _last_strike_tick: int = -100000


func on_tick(dt: float) -> void:
	if not pawn.alive:
		return
	var ab := pawn.abilities.get_slot(RF.Slot.ABILITY_1)
	if ab == null or ab.data.self_status_while_active == null:
		return
	var sd := ab.data.self_status_while_active
	if not ab.is_active():
		_lockout = 0.0
		return
	var hs := Vector2(pawn.velocity.x, pawn.velocity.z).length()
	var limit := pawn.movement.profile.max_speed * SPEED_FRACTION
	var struck_recently := pawn.world.tick - _last_strike_tick < STRIKE_LOCK_TICKS
	if hs > limit or struck_recently or not pawn.is_on_floor():
		if pawn.status.has(sd.id):
			pawn.status.remove(sd.id)
		_lockout = LOCKOUT
		pawn.set_meta("sable_shroud_state", 0)
		return
	_lockout -= dt
	if _lockout <= 0.0 and not pawn.status.has(sd.id):
		pawn.status.apply(sd, pawn)
	pawn.set_meta("sable_shroud_state", 2 if pawn.status.has(sd.id) else 1)


func on_damage_dealt(ev: DamageEvent) -> void:
	if ev.dealt > 0.0 and ev.type == RF.DamageType.MELEE:
		_last_strike_tick = pawn.world.tick


func on_spawn() -> void:
	_lockout = 0.0
	_last_strike_tick = -100000
