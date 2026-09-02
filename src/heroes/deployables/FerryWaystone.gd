class_name FerryWaystone
extends Deployable
## Ferry's Waystone: a beacon allies can teleport to from spawn. Any ally who spawned less than
## `spawn_window` seconds ago and presses INTERACT is moved next to the beacon. Bots don't press
## buttons on their own, so they are ferried automatically `bot_delay` seconds after spawning when the
## beacon is far (> `min_distance` m) from where they stand. Has a small body so enemies can shoot it.

const SPAWN_WINDOW_TICKS := 300      # 5 s
const BOT_DELAY_TICKS := 120         # 2 s
const MIN_DISTANCE := 25.0

var body: StaticBody3D
var _served: Dictionary = {}          # net_id -> spawn_tick already teleported for
var _slot: int = 0


func on_placed() -> void:
	body = StaticBody3D.new()
	body.name = "WaystoneBody"
	body.collision_layer = RF.L_DEPLOYABLE
	body.collision_mask = 0
	body.set_meta("deployable", self)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 1.6
	cs.shape = cyl
	cs.position = Vector3(0, 0.8, 0)
	body.add_child(cs)
	add_child(body)
	if visual_id == &"":
		visual_id = &"waystone"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or not world.is_server:
		return
	var tick := world.tick
	for p: Pawn in world.pawns.values():
		if not p.alive or p.team != team:
			continue
		var since := tick - p.spawn_tick
		if since < 0 or since >= SPAWN_WINDOW_TICKS:
			continue
		if int(_served.get(p.net_id, -1)) == p.spawn_tick:
			continue
		var far := p.global_position.distance_to(global_position) > MIN_DISTANCE
		var wants := p.last_cmd.just_pressed(RF.BTN_INTERACT) and p.global_position.distance_to(global_position) > 6.0
		if p.is_bot and since >= BOT_DELAY_TICKS and far:
			wants = true
		if not wants:
			continue
		_served[p.net_id] = p.spawn_tick
		_teleport(p)


func _teleport(p: Pawn) -> void:
	var from := p.global_position
	# Fan arrivals around the stone so a wave doesn't stack on one spot.
	var ang := float(_slot) * 1.7 + 0.6
	_slot += 1
	var offset := Vector3(cos(ang), 0, sin(ang)) * 1.6
	var dest := world.ground_point(global_position + offset + Vector3(0, 0.8, 0))
	if absf(dest.y - global_position.y) > 2.0:
		dest = global_position + offset
	p.global_position = dest + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	p.movement.external_impulse = Vector3.ZERO
	p.reset_physics_interpolation()
	p.hitboxes.record(world.tick)
	var hb := owner_pawn.behavior as FerryBehavior if owner_pawn else null
	if hb:
		hb.waystone_teleports += 1
	world.emit_custom(&"teleport", {"pawn": p.net_id, "from": from, "to": dest})
	world.emit_custom(&"ferry_waystone", {"pawn": p.net_id, "owner": owner_pawn.net_id if owner_pawn else -1, "pos": dest, "id": id})
