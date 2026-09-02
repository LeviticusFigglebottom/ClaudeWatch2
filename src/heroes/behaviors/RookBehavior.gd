extends HeroBehavior
## Rook passive "Mass": landing while Density is active (he is 2.5x heavier) slams the ground:
## enemies within SLAM_RADIUS take damage and a shove. Turns Density into a dive tool, not just a
## damage-reduction button.

const SLAM_RADIUS := 3.5
const SLAM_DAMAGE := 45.0
const SLAM_KNOCKBACK := 6.0
const MIN_IMPACT := 6.0

var _was_grounded: bool = true


func on_spawn() -> void:
	_was_grounded = true


func on_tick(_dt: float) -> void:
	var grounded := pawn.is_on_floor()
	var landed := grounded and not _was_grounded
	_was_grounded = grounded
	if not landed or not pawn.status.has(&"rook_density"):
		return
	if pawn.movement.last_land_impact < MIN_IMPACT:
		return
	if not pawn.world.is_server:
		return
	var c := pawn.global_position + Vector3(0, 0.4, 0)
	var hits := 0
	for q: Pawn in pawn.world.pawns_in_radius(c, SLAM_RADIUS, RF.enemy_team(pawn.team)):
		var closest := q.hitboxes.closest_point(c)
		if not pawn.world.has_line_of_sight(c, closest):
			continue
		var frac := lerpf(1.0, 0.6, clampf(closest.distance_to(c) / SLAM_RADIUS, 0.0, 1.0))
		var ev := DamageEvent.new()
		ev.source = pawn; ev.target = q; ev.amount = SLAM_DAMAGE * frac
		ev.type = RF.DamageType.SPLASH; ev.ability_id = &"rook_mass"
		ev.position = closest; ev.direction = (closest - c).normalized(); ev.knockback = SLAM_KNOCKBACK * frac
		pawn.world.apply_damage(ev)
		hits += 1
	pawn.world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": pawn.global_position, "radius": SLAM_RADIUS, "vfx": &"rook_mass_explosion", "ability": &"rook_mass"})
