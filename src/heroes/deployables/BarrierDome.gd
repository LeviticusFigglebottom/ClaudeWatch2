class_name BarrierDome
extends Deployable
## Spherical team barrier (Sanctuary-style). Blocks enemy shots from outside; allies inside shoot out.
## Implemented as a thin sphere shell on the barrier layer; the ray mask rule handles friendliness.

var body: StaticBody3D


func on_placed() -> void:
	var r: float = float(data.get("radius", 5.0))
	body = StaticBody3D.new()
	body.collision_layer = RF.barrier_layer(team)
	body.collision_mask = 0
	body.set_meta("deployable", self)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = r
	cs.shape = sphere
	body.add_child(cs)
	add_child(body)
	blocks_los = true
	if visual_id == &"":
		visual_id = &"barrier_dome"


## Shots fired from inside the dome must pass: SimWorld's raycast starts inside the sphere, and
## Godot's ray query ignores shapes the ray origin is inside (hit_from_inside = false), so outgoing
## fire naturally passes while incoming fire hits the shell.
