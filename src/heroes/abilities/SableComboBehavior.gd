class_name SableComboBehavior
extends AbilityBehavior
## Twin Blades three-hit combo. The AbilityData carries no effects; this behavior owns three
## MeleeEffects (40 narrow / 40 wide sweep / 70 thrust) and fires the one for the current combo
## index on each swing. The index resets after 1.2 s without a swing. All three backstab at 2.5x.

const RESET_TICKS := 72
const DAMAGE := [40.0, 40.0, 70.0]
const ARC := [80.0, 120.0, 55.0]
const TARGETS := [1, 2, 1]
const KNOCKBACK := [1.0, 1.2, 3.5]

var _hits: Array[MeleeEffect] = []
var _index: int = 0
var _last_swing_tick: int = -100000


func setup(_ability: Ability, _pawn: Pawn) -> void:
	super.setup(_ability, _pawn)
	_hits.clear()
	for i in 3:
		var m := MeleeEffect.new()
		m.damage = DAMAGE[i]
		m.arc_deg = ARC[i]
		m.max_targets = TARGETS[i]
		m.knockback = KNOCKBACK[i]
		m.range = 2.6
		m.backstab_multiplier = 2.5
		m.hit_deployables = true
		_hits.append(m)


func on_fire(ctx: AbilityContext) -> void:
	if ctx.tick - _last_swing_tick > RESET_TICKS:
		_index = 0
	var e := _hits[_index]
	if ctx.is_server:
		e.apply(ctx)
	else:
		e.predict(ctx)
	pawn.set_meta("sable_combo", _index)
	_last_swing_tick = ctx.tick
	_index = (_index + 1) % 3


func combo_index() -> int:
	return _index
