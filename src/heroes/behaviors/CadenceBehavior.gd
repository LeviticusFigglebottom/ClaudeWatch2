class_name CadenceBehavior
extends HeroBehavior
## Cadence's passive: the beat clock. 120 bpm = one beat every 0.5 s = every 30 sim ticks, derived from
## the world tick so the server and every predicting client agree without any extra sync.
## The Groove aura (secondary toggle) pulses on every beat; Bassline shots fired inside the beat window
## hit harder and heal around their impact, and make the NEXT aura pulse heal double ("doubled when
## she fires on-beat"). Exposes `flags_extra` bit 0 = inside the beat window (for HUD metronome use).

const BEAT_TICKS := 30                 # 0.5 s at 60 Hz
const BEAT_WINDOW_TICKS := 4           # +-66 ms: the last tick that still counts as "on the beat"
const BEAT_HEAL := 8.0                 # aura heal per beat per ally (16 hp/s at 120 bpm)
const AURA_RADIUS := 9.0

var _bonus_until_tick: int = -1        # next aura pulse at or before this tick heals double
var on_beat_shots: int = 0             # telemetry
var beats_pulsed: int = 0


## Signed distance (in ticks) from `tick` to the nearest beat: -14..15.
static func beat_offset_ticks(tick: int) -> int:
	var m := posmod(tick, BEAT_TICKS)
	return m if m <= BEAT_TICKS / 2 else m - BEAT_TICKS


static func on_beat(tick: int) -> bool:
	return absi(beat_offset_ticks(tick)) <= BEAT_WINDOW_TICKS


static func is_beat_tick(tick: int) -> bool:
	return posmod(tick, BEAT_TICKS) == 0


## 0..1 phase within the current beat (0 = on the beat).
static func beat_phase(tick: int) -> float:
	return float(posmod(tick, BEAT_TICKS)) / float(BEAT_TICKS)


func on_spawn() -> void:
	_bonus_until_tick = -1


func on_tick(_dt: float) -> void:
	var flag := 1 if on_beat(pawn.world.tick) else 0
	pawn.flags_extra = (pawn.flags_extra & ~1) | flag


## Called by CadenceBassEffect when a Bassline shot leaves the cannon inside the beat window.
func on_beat_shot(tick: int) -> void:
	on_beat_shots += 1
	_bonus_until_tick = tick + BEAT_TICKS


## Called by the Groove aura on each beat tick. Returns true (and clears the bonus) when the pulse
## should heal double because Cadence fired on the previous beat.
func consume_beat_bonus(tick: int) -> bool:
	beats_pulsed += 1
	if _bonus_until_tick >= tick:
		_bonus_until_tick = -1
		return true
	return false
