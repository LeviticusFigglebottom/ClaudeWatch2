class_name TallowCandle
extends Deployable
## Tallow's Wick: heals allies (owner included) within `radius` for `hps` per second, applied
## every `interval`. An enemy within `burn_radius` is burned (`burn` status, refreshed) and after
## `snuff_time` of continuous contact the candle goes out.

var _accum: float = 0.0
var _contact: float = 0.0
var _burn: StatusData


func on_placed() -> void:
	targetable = false
	if visual_id == &"":
		visual_id = &"tallow_candle"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or not world.is_server:
		return
	var burn_r: float = float(data.get("burn_radius", 1.5))
	var snuff_time: float = float(data.get("snuff_time", 0.75))
	var touching := false
	for e: Pawn in world.pawns_in_radius(global_position + Vector3(0, 0.6, 0), burn_r, RF.enemy_team(team)):
		touching = true
		if _burn == null:
			_burn = StatusLibrary.get_status(StringName(String(data.get("burn", "tallow_candle_burn"))))
		if _burn:
			e.status.apply(_burn, owner_pawn)
	_contact = _contact + dt if touching else maxf(_contact - dt * 2.0, 0.0)
	if _contact >= snuff_time:
		destroy(null)
		return
	_accum += dt
	var interval: float = float(data.get("interval", 0.25))
	if _accum < interval:
		return
	var radius: float = float(data.get("radius", 6.0))
	var hps: float = float(data.get("hps", 18.0))
	for a: Pawn in world.pawns_in_radius(global_position + Vector3(0, 0.6, 0), radius, team):
		if a.health.missing() <= 0.0:
			continue
		if not world.has_line_of_sight(global_position + Vector3(0, 0.9, 0), a.center(), RF.L_WORLD):
			continue
		world.apply_heal(owner_pawn, a, hps * _accum, ability_id)
	_accum = 0.0
