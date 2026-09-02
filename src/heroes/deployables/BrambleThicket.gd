class_name BrambleThicket
extends Deployable
## Bramble's Thicket: a thorn hedge `width` m wide and `band` m thick (facing is the wall normal).
## It has no physics body — it is a zone you can cross, and crossing hurts: 30 on entry, `dps`
## while inside, and a re-applied slow. Enemies inside also trample it (`trample` hp/s) so a team
## pushing through wears it down before the 8 s lifetime. Deployable.health is that wear budget.

var _inside: Dictionary = {}       # net_id -> true while inside the band
var _entry_cd: Dictionary = {}     # net_id -> seconds until entry damage can trigger again
var _accum: float = 0.0
var _wear: float = 0.0
var _slow: StatusData


func on_placed() -> void:
	targetable = false
	blocks_los = false
	if visual_id == &"":
		visual_id = &"thicket_wall"


func _in_band(p: Pawn) -> bool:
	var half_w: float = float(data.get("width", 6.0)) * 0.5
	var half_b: float = float(data.get("band", 1.2)) * 0.5
	var height: float = float(data.get("height", 2.2))
	var local := to_local(p.global_position)
	# Deployables look along -Z (look_at), so the hedge runs along local X and its normal is local Z.
	return absf(local.x) <= half_w + 0.3 and absf(local.z) <= half_b + 0.35 and local.y > -1.0 and local.y < height + 0.5


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or not world.is_server:
		return
	var dps: float = float(data.get("dps", 20.0))
	var entry: float = float(data.get("entry_damage", 30.0))
	var trample: float = float(data.get("trample", 60.0))
	if _slow == null:
		_slow = StatusLibrary.get_status(StringName(String(data.get("slow", "bramble_thicket_slow"))))
	for k: Variant in _entry_cd.keys():
		_entry_cd[k] = float(_entry_cd[k]) - dt
	_accum += dt
	var tick_now := _accum >= 0.2
	var seen: Dictionary = {}
	for p: Pawn in world.pawns_in_radius(global_position, float(data.get("width", 6.0)) * 0.5 + 2.0, RF.enemy_team(team)):
		if not _in_band(p):
			continue
		seen[p.net_id] = true
		var fresh := not _inside.has(p.net_id)
		_inside[p.net_id] = true
		if fresh and float(_entry_cd.get(p.net_id, 0.0)) <= 0.0:
			_hurt(p, entry, true)
			_entry_cd[p.net_id] = 1.5
		if tick_now:
			_hurt(p, dps * _accum, false)
			if _slow:
				p.status.apply(_slow, owner_pawn)
		_wear += trample * dt
	for k: Variant in _inside.keys():
		if not seen.has(k):
			_inside.erase(k)
	if tick_now:
		_accum = 0.0
		if _wear > 0.0 and max_health > 0.0:
			health -= _wear
			world.on_deployable_damaged(self, _wear, null)
			_wear = 0.0
			if health <= 0.0:
				destroy(null)

func _hurt(p: Pawn, amount: float, burst: bool) -> void:
	var ev := DamageEvent.new()
	ev.source = owner_pawn
	ev.target = p
	ev.amount = amount
	ev.type = RF.DamageType.DOT if not burst else RF.DamageType.SPLASH
	ev.ability_id = ability_id
	ev.position = p.center()
	ev.direction = (p.global_position - global_position).normalized()
	world.apply_damage(ev)
