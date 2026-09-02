class_name CairnSlab
extends Deployable
## Cairn ★ Raise Slab / Landslide cover: a stone pillar that rises out of the ground. Its
## StaticBody3D (RF.L_DEPLOYABLE: blocks movement and shots for everyone) starts fully buried and
## its collision box slides up so the top goes from 0 to `height` over `rise_time`. Every pawn whose
## feet are inside the pillar's footprint and below the rising top is carried up with it: an ally
## gets an elevator, an enemy gets displaced (and can be shot from below). data: height, width,
## rise_time. The client visual animates the same rise locally (see cairn_vfx.gd).

var body: StaticBody3D
var shape: CollisionShape3D
var height: float = 3.0
var width: float = 2.4
var rise_time: float = 0.5


func on_placed() -> void:
	height = float(data.get("height", 3.0))
	width = float(data.get("width", 2.4))
	rise_time = maxf(float(data.get("rise_time", 0.5)), 0.05)
	body = StaticBody3D.new()
	body.collision_layer = RF.L_DEPLOYABLE
	body.collision_mask = 0
	body.set_meta("deployable", self)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, width)
	shape.shape = box
	shape.position = Vector3(0, -height * 0.5, 0)   # buried: top flush with the ground
	body.add_child(shape)
	add_child(body)
	blocks_los = true
	if visual_id == &"":
		visual_id = &"cairn_slab"


func top_height() -> float:
	return clampf(age / rise_time, 0.0, 1.0) * height


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or world == null:
		return
	var top := top_height()
	shape.position.y = top - height * 0.5
	if not world.is_server:
		return
	# Carry pawns while rising (plus a few ticks after, so the last step settles cleanly).
	if age > rise_time + 0.12:
		return
	var half := width * 0.5
	for p: Pawn in world.pawns.values():
		if not p.alive:
			continue
		var r: float = p.movement.profile.capsule_radius
		var lp := to_local(p.global_position)
		if absf(lp.x) > half + r * 0.6 or absf(lp.z) > half + r * 0.6:
			continue
		if lp.y < -0.5 or lp.y > top + 0.05:
			continue
		var gp := p.global_position
		gp.y = global_position.y + top + 0.03
		p.global_position = gp
		if p.velocity.y < 0.0:
			p.velocity.y = 0.0
		p.movement.grounded = true


## Is this pawn standing on the top face of the pillar?
func is_on_top(p: Pawn) -> bool:
	var lp := to_local(p.global_position)
	var half := width * 0.5 + 0.3
	return absf(lp.x) <= half and absf(lp.z) <= half and absf(lp.y - top_height()) < 0.35
