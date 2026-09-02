class_name BombardBehavior
extends HeroBehavior
## Bombard's signature: indirect fire. Every tick the mortar's arc is simulated against the world
## with the primary's own speed/gravity and the landing point is stored in pawn meta
## ("landing_point", "landing_valid", "landing_time"). On the owning client the point drives a
## world-space reticle (BombardVfx.reticle_for) that is drawn through walls.

const STEP := 0.05
const MAX_TIME := 4.0
const SERVER_EVERY_N_TICKS := 3

var _speed: float = 28.0
var _gravity: float = 14.0
var _lob: bool = true
var _spawn_offset: Vector3 = Vector3(0.3, -0.1, -0.5)
var _resolved: bool = false


func _resolve_primary() -> void:
	_resolved = true
	if pawn.hero == null or pawn.hero.primary == null:
		return
	for e: AbilityEffect in pawn.hero.primary.effects:
		if e is ProjectileEffect:
			var pe := e as ProjectileEffect
			_speed = pe.speed
			_gravity = pe.gravity
			_lob = pe.lob_arc
			_spawn_offset = pe.spawn_offset
			return


func on_tick(_dt: float) -> void:
	if not _resolved:
		_resolve_primary()
	if not pawn.alive:
		if not pawn.is_server and pawn.is_local:
			BombardVfx.hide_reticle(pawn)
		return
	# The server only needs the point for other systems (AI/telemetry); 20 Hz is plenty there.
	if pawn.is_server and pawn.world.tick % SERVER_EVERY_N_TICKS != 0:
		return
	var res := predict_landing(pawn, _speed, _gravity, _lob, _spawn_offset)
	pawn.set_meta("landing_point", res["point"])
	pawn.set_meta("landing_valid", res["hit"])
	pawn.set_meta("landing_time", res["time"])
	if not pawn.is_server and pawn.is_local:
		BombardVfx.update_reticle(pawn, res["point"], bool(res["hit"]), res["normal"])


## Simulates the mortar arc from the pawn's current eye/aim. Returns {point, normal, hit, time}.
static func predict_landing(p: Pawn, speed: float, gravity: float, lob: bool, offset: Vector3) -> Dictionary:
	var dir := p.aim_dir()
	if lob:
		dir = (dir + Vector3(0, 0.08, 0)).normalized()
	var eye := p.eye_position()
	var basis := Basis(Vector3.UP, p.yaw)
	var pos := eye + basis * Vector3(offset.x, offset.y, 0) + dir * absf(offset.z)
	if not p.world.has_line_of_sight(eye, pos):
		pos = eye + dir * 0.1
	var vel := dir * speed
	var t := 0.0
	while t < MAX_TIME:
		vel.y -= gravity * STEP
		var motion := vel * STEP
		var dist := motion.length()
		if dist > 0.0001:
			var res := p.world.raycast_world(pos, motion / dist, dist, p.team, true)
			if not res.is_empty():
				return {"point": res["point"], "normal": res["normal"], "hit": true, "time": t + float(res["distance"]) / maxf(speed, 0.01)}
		pos += motion
		t += STEP
	return {"point": pos, "normal": Vector3.UP, "hit": false, "time": t}


func on_death(_killer: Pawn) -> void:
	if not pawn.is_server and pawn.is_local:
		BombardVfx.hide_reticle(pawn)
