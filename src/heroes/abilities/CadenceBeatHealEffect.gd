class_name CadenceBeatHealEffect
extends AbilityEffect
## On-hit effect for Bassline shells: when the shell was fired on the beat (ctx.data["on_beat"]),
## heal allies within `radius` of the impact point. Cadence herself gets half (she is in the band).

@export var heal: float = 30.0
@export var radius: float = 4.0
@export var vfx_id: StringName = &"cadence_beat_burst"


func apply(ctx: AbilityContext) -> void:
	if not bool(ctx.data.get("on_beat", false)):
		return
	var p := ctx.pawn
	var world := ctx.world
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &"cadence_bass"
	for q: Pawn in world.pawns_in_radius(ctx.point, radius, p.team):
		var closest := q.hitboxes.closest_point(ctx.point)
		if not world.has_line_of_sight(ctx.point, closest):
			continue
		world.apply_heal(p, q, heal * (0.5 if q == p else 1.0), ability_id)
	world.emit_custom(&"area", {"pawn": p.net_id, "pos": ctx.point, "radius": radius, "vfx": vfx_id, "ability": ability_id})


func predict(ctx: AbilityContext) -> void:
	if not bool(ctx.data.get("on_beat", false)):
		return
	ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": ctx.point, "radius": radius, "vfx": vfx_id, "ability": ctx.ability.data.id if ctx.ability else &"cadence_bass", "predicted": true})
