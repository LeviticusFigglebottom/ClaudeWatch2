class_name KilnSlag
extends Deployable
## Kiln Slag Cast: a cooling slab of slag you can stand on. A StaticBody3D on RF.L_DEPLOYABLE, so it
## blocks movement and shots for BOTH teams (it is terrain, not a team barrier). Profile: a tall
## main slab plus a half-height step on the caster's side (+Z) so a single jump (0.97 m) reaches the
## step and a second reaches the top. data: width, height. 600 hp, 6 s.

var body: StaticBody3D


func on_placed() -> void:
	var w: float = float(data.get("width", 4.2))
	var h: float = float(data.get("height", 1.5))
	body = StaticBody3D.new()
	body.collision_layer = RF.L_DEPLOYABLE
	body.collision_mask = 0
	body.set_meta("deployable", self)
	var main := CollisionShape3D.new()
	var mb := BoxShape3D.new()
	mb.size = Vector3(w, h, 0.8)
	main.shape = mb
	main.position = Vector3(0, h * 0.5, 0)
	body.add_child(main)
	var stepc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(w * 0.7, h * 0.5, 0.7)
	stepc.shape = sb
	stepc.position = Vector3(0, h * 0.25, 0.75)
	body.add_child(stepc)
	add_child(body)
	blocks_los = true
	if visual_id == &"":
		visual_id = &"kiln_slag"


## Standing on the top face? (Cairn-style helper kept for parity / tests.)
func is_on_top(p: Pawn) -> bool:
	var lp := to_local(p.global_position)
	var w: float = float(data.get("width", 4.2))
	var h: float = float(data.get("height", 1.5))
	return absf(lp.x) <= w * 0.5 + 0.3 and absf(lp.z) <= 0.7 and absf(lp.y - h) < 0.35
