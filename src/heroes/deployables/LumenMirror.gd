class_name LumenMirror
extends Deployable
## Lumen's Refract mirror: a thin pane on the deployable layer. LumenBeamEffect reflects off its plane
## (the node's local Z axis is the pane normal; DeployEffect.face_caster points it at Lumen).
## Enemies can shoot it down (120 hp). It does not block line of sight for AI queries beyond being a
## small physical pane; it is not a barrier (no team layer), so it never absorbs shots.

var body: StaticBody3D


func on_placed() -> void:
	var w: float = float(data.get("width", 1.4))
	var h: float = float(data.get("height", 1.8))
	body = StaticBody3D.new()
	body.name = "MirrorBody"
	body.collision_layer = RF.L_DEPLOYABLE
	body.collision_mask = 0
	body.set_meta("deployable", self)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, h, 0.12)
	cs.shape = box
	cs.position = Vector3(0, h * 0.5 + 0.1, 0)
	body.add_child(cs)
	add_child(body)
	blocks_los = false
	if visual_id == &"":
		visual_id = &"mirror"


## Plane normal in world space (either sign is fine for reflection).
func plane_normal() -> Vector3:
	return global_transform.basis.z.normalized()
