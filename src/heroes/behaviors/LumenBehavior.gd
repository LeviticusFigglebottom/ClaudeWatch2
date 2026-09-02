class_name LumenBehavior
extends HeroBehavior
## Lumen's passive bookkeeping: remembers the last beam trace (segment count / bounces) for HUD and
## telemetry. `flags_extra` bits 0-1 = bounces in the last beam tick, bit 2 = Prism active.

var last_bounces: int = 0
var last_targets: int = 0
var total_bounces: int = 0
var _last_beam_tick: int = -100


func on_spawn() -> void:
	last_bounces = 0
	last_targets = 0
	_last_beam_tick = -100


func on_tick(_dt: float) -> void:
	var t := pawn.world.tick
	if t - _last_beam_tick > 6:
		last_bounces = 0
		last_targets = 0
	var prism := 4 if pawn.status.has(&"lumen_prism") else 0
	pawn.flags_extra = (pawn.flags_extra & ~7) | (mini(last_bounces, 3) | prism)


## Called by LumenBeamEffect after each trace.
func note_beam(bounces: int, targets: int, tick: int) -> void:
	if bounces > last_bounces or tick != _last_beam_tick:
		total_bounces += maxi(bounces - (last_bounces if tick == _last_beam_tick else 0), 0)
	last_bounces = bounces
	last_targets = targets
	_last_beam_tick = tick
