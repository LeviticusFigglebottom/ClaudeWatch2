class_name TallowSnuffEffect
extends AbilityEffect
## Snuff: the aimed ally (generous cone) or, failing that, Tallow herself is cleansed, healed a
## little and given `status` (1 s invulnerability). Emits an `area` event for the pinch-out puff.

@export var status: StatusData
@export var heal: float = 30.0
@export var range: float = 25.0
@export var cone_deg: float = 14.0


func _pick(ctx: AbilityContext) -> Pawn:
	var t := HealEffect.aimed_ally(ctx, range, cone_deg)
	return t if t else ctx.pawn


func apply(ctx: AbilityContext) -> void:
	var t := _pick(ctx)
	ctx.target = t
	t.status.cleanse()
	if status:
		t.status.apply(status, ctx.pawn)
	if heal > 0.0:
		ctx.world.apply_heal(ctx.pawn, t, heal, ctx.ability.data.id if ctx.ability else &"")
	ctx.data["heal_targets"] = [t]
	ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": t.global_position, "radius": 1.6, "vfx": &"tallow_snuff", "ability": ctx.ability.data.id if ctx.ability else &""})


func predict(ctx: AbilityContext) -> void:
	var t := _pick(ctx)
	ctx.target = t
	ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": t.global_position, "radius": 1.6, "vfx": &"tallow_snuff", "ability": ctx.ability.data.id if ctx.ability else &"", "predicted": true})
