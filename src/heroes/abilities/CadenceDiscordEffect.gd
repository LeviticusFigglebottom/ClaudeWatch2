class_name CadenceDiscordEffect
extends AbilityEffect
## Discord: every visible enemy inside a cone in front of Cadence takes the `status` (a
## damage-taken amplifier). Cone abilities have no generic effect yet, hence this hero-local one.

@export var status: StatusData
@export var range: float = 15.0
@export var cone_deg: float = 60.0
@export var vfx_id: StringName = &"cadence_discord"


func _center(ctx: AbilityContext) -> Vector3:
	return ctx.aim_origin + ctx.aim_dir * minf(range * 0.4, 6.0)


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var world := ctx.world
	var cos_half := cos(deg_to_rad(cone_deg * 0.5))
	var hits := 0
	if status:
		for q: Pawn in world.pawns_in_radius(ctx.aim_origin, range, RF.enemy_team(p.team)):
			var to := q.center() - ctx.aim_origin
			if to.length() < 0.01:
				continue
			if to.normalized().dot(ctx.aim_dir) < cos_half:
				continue
			if not world.pawn_visible_from(ctx.aim_origin, q):
				continue
			q.status.apply(status, p)
			hits += 1
	ctx.data["discord_hits"] = hits
	world.emit_custom(&"area", {"pawn": p.net_id, "pos": _center(ctx), "radius": range * 0.35, "vfx": vfx_id, "ability": ctx.ability.data.id if ctx.ability else &"cadence_discord"})


func predict(ctx: AbilityContext) -> void:
	ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": _center(ctx), "radius": range * 0.35, "vfx": vfx_id, "ability": ctx.ability.data.id if ctx.ability else &"cadence_discord", "predicted": true})
