extends Deployable
## Tesla Node: a 150 hp pylon (12 s) that zaps the nearest enemy within 7 m every 0.8 s for 20
## damage. It has a small physical body on the deployable layer so enemies can shoot it. Coil's
## Chain treats friendly nodes as relays (see CoilChainEffect).

const ZAP_INTERVAL := 0.8
const ZAP_DAMAGE := 20.0
const ZAP_RADIUS := 7.0

var body: StaticBody3D
var _accum: float = 0.0


func on_placed() -> void:
	body = StaticBody3D.new()
	body.collision_layer = RF.L_DEPLOYABLE
	body.collision_mask = 0
	body.set_meta("deployable", self)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.28
	cyl.height = 1.0
	cs.shape = cyl
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	add_child(body)
	if visual_id == &"":
		visual_id = &"coil_tesla_node"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or world == null or not world.is_server:
		return
	_accum += dt
	if _accum < float(data.get("interval", ZAP_INTERVAL)):
		return
	_accum = 0.0
	var origin := global_position + Vector3(0, 0.9, 0)
	var radius: float = float(data.get("radius", ZAP_RADIUS))
	var best: Pawn = null
	var best_d := INF
	for q: Pawn in world.pawns_in_radius(global_position, radius, RF.enemy_team(team)):
		var d := q.center().distance_to(origin)
		if d < best_d and world.has_line_of_sight(origin, q.center()):
			best_d = d
			best = q
	if best == null:
		return
	var ev := DamageEvent.new()
	ev.source = owner_pawn
	ev.target = best
	ev.amount = float(data.get("damage", ZAP_DAMAGE))
	ev.type = RF.DamageType.BEAM
	ev.ability_id = ability_id
	ev.position = best.center()
	ev.direction = (best.center() - origin).normalized()
	world.apply_damage(ev)
	var owner_id := owner_pawn.net_id if owner_pawn else -1
	world.emit_custom(&"chain_arc", {"pawn": owner_id, "from": origin, "to": best.center(), "pos": origin, "relay": false})
	world.emit_custom(&"area", {"pawn": owner_id, "pos": best.global_position, "radius": 0.8, "vfx": &"coil_chain_explosion", "ability": ability_id})
