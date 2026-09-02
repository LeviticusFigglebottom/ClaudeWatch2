extends AbilityEffect
## Exchange: runs from the marked needle's on_hit_effects. If the needle struck an enemy, Wisp and
## that enemy trade places (velocities reset). Unstoppable targets refuse the swap. Server-only:
## a projectile hit is never predicted, so the client learns the new positions from the snapshot
## and plays both blink effects from the `teleport` events.

@export var status: StatusData     # optional tag applied to the displaced enemy
@export var min_distance: float = 1.5


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var t := ctx.target
	if p == null or t == null or not p.alive or not t.alive or t.team == p.team:
		return
	if t.status.unstoppable:
		return
	var a := p.global_position
	var b := t.global_position
	if a.distance_to(b) < min_distance:
		return
	p.global_position = b
	t.global_position = a
	p.velocity = Vector3.ZERO
	t.velocity = Vector3.ZERO
	p.movement.external_impulse = Vector3.ZERO
	t.movement.external_impulse = Vector3.ZERO
	p.reset_physics_interpolation()
	t.reset_physics_interpolation()
	if status:
		t.status.apply(status, p)
	ctx.data["swapped"] = t.net_id
	ctx.world.emit_custom(&"teleport", {"pawn": p.net_id, "from": a, "to": b})
	ctx.world.emit_custom(&"teleport", {"pawn": t.net_id, "from": b, "to": a})


func predict(_ctx: AbilityContext) -> void:
	pass
