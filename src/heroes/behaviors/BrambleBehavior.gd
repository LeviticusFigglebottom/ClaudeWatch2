class_name BrambleBehavior
extends HeroBehavior
## Bramble's Roots: counts consecutive thorn hits (primary or Thorn Fan) on the same target.
## Hitting a different target, or letting 2 s pass since the last hit, resets the count. The
## third hit applies `bramble_root` (1.2 s) and the count starts over. Server-only (damage hook).

const WINDOW_TICKS := 120
const HITS_TO_ROOT := 3
const THORN_ABILITIES := [&"bramble_thorns", &"bramble_fan"]

var _target_id: int = -1
var _count: int = 0
var _last_tick: int = -100000
var _root: StatusData


func on_damage_dealt(ev: DamageEvent) -> void:
	if ev.target == null or ev.dealt <= 0.0:
		return
	if not THORN_ABILITIES.has(ev.ability_id):
		return
	var now := pawn.world.tick
	if ev.target.net_id != _target_id or now - _last_tick > WINDOW_TICKS:
		_count = 0
		_target_id = ev.target.net_id
	_count += 1
	_last_tick = now
	if _count >= HITS_TO_ROOT:
		_count = 0
		if _root == null:
			_root = StatusLibrary.get_status(&"bramble_root")
		if _root and ev.target.alive:
			ev.target.status.apply(_root, pawn)
			pawn.set_meta("bramble_roots", int(pawn.get_meta("bramble_roots", 0)) + 1)
	pawn.set_meta("bramble_stacks", _count)
	pawn.set_meta("bramble_stack_target", _target_id)


func on_spawn() -> void:
	_count = 0
	_target_id = -1
	_last_tick = -100000
