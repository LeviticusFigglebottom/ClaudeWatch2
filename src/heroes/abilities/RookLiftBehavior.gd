extends AbilityBehavior
## Rook ★ Lift: every enemy in a CONE_DEG cone within RANGE (with line of sight) gets `rook_lifted`
## for its duration: airborne + rooted + speed 0. StatusController.airborne makes MovementController
## float them (gravity pulls vertical speed to zero instead of down); rooted zeroes their input so
## they cannot steer or jump, but aiming, shooting and abilities all still work. A small upward
## impulse makes the float visible. Unstoppable enemies are immune (counter-play by design).

const RANGE := 12.0
const CONE_DEG := 35.0
const LIFT_IMPULSE := 4.5
const LIFT_STATUS := &"rook_lifted"


func on_fire(ctx: AbilityContext) -> void:
	if not ctx.is_server:
		return
	var sd := _lift_status()
	if sd == null:
		return
	var cos_half := cos(deg_to_rad(CONE_DEG * 0.5))
	var lifted := 0
	for q: Pawn in ctx.world.pawns_in_radius(ctx.aim_origin, RANGE + 0.5, RF.enemy_team(pawn.team)):
		var to := q.center() - ctx.aim_origin
		if to.length() > RANGE + q.hitboxes.profile.body_radius:
			continue
		if to.normalized().dot(ctx.aim_dir) < cos_half:
			continue
		if not ctx.world.pawn_visible_from(ctx.aim_origin, q):
			continue
		if q.status.unstoppable:
			continue
		q.status.apply(sd, pawn)
		q.velocity = Vector3(q.velocity.x * 0.2, maxf(q.velocity.y, 0.0), q.velocity.z * 0.2)
		q.movement.apply_impulse(Vector3.UP * LIFT_IMPULSE)
		q.movement.grounded = false
		lifted += 1
	ctx.data["lifted"] = lifted
	ctx.world.emit_custom(&"lift", {"pawn": pawn.net_id, "count": lifted, "pos": ctx.aim_origin, "dir": ctx.aim_dir})


func _lift_status() -> StatusData:
	for e: AbilityEffect in ability.data.effects:
		if e is ApplyStatusEffect and (e as ApplyStatusEffect).status:
			return (e as ApplyStatusEffect).status
	return StatusLibrary.get_status(LIFT_STATUS)
