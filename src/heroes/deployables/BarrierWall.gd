class_name BarrierWall
extends Deployable
## Generic team barrier: a StaticBody3D slab on the team's barrier layer that absorbs enemy shots.
## data: width, height, curved(bool). Used by Cathedral's wall and reusable by any hero.
## Enemy hitscan/projectiles collide with it (SimWorld.raycast_world includes enemy barrier layers);
## friendly fire passes through because friendly barriers are not in the shooter's ray mask.

var body: StaticBody3D
var shape: CollisionShape3D


func on_placed() -> void:
	var w: float = float(data.get("width", 5.0))
	var h: float = float(data.get("height", 3.0))
	body = StaticBody3D.new()
	body.collision_layer = RF.barrier_layer(team)
	body.collision_mask = 0
	body.set_meta("deployable", self)
	shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.25)
	shape.shape = box
	shape.position = Vector3(0, h * 0.5, 0)
	body.add_child(shape)
	add_child(body)
	blocks_los = true
	if visual_id == &"":
		visual_id = &"barrier_wall"


## Barriers take full damage from enemy hits (no armor rules) and block projectiles.
func absorb(amount: float, source: Pawn) -> float:
	return super.absorb(amount, source)
