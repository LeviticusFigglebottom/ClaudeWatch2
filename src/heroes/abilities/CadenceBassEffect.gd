class_name CadenceBassEffect
extends ProjectileEffect
## Bassline shell. A normal splash projectile, except that a shot fired inside the beat window
## (see CadenceBehavior.on_beat) deals `beat_mult` damage and flags the shell as on-beat so its
## on-hit CadenceBeatHealEffect heals around the impact. Same logic on the server and the predicting
## client because the beat is derived from the shared tick.

@export var beat_mult: float = 1.5


func apply(ctx: AbilityContext) -> void:
	super.apply(ctx)
	_mark_beat(ctx)


func predict(ctx: AbilityContext) -> void:
	super.predict(ctx)
	_mark_beat(ctx)


func _mark_beat(ctx: AbilityContext) -> void:
	var on_beat := CadenceBehavior.on_beat(ctx.tick)
	ctx.data["on_beat"] = on_beat
	ctx.data["beat_offset"] = CadenceBehavior.beat_offset_ticks(ctx.tick)
	if not on_beat:
		return
	var pr := ctx.data.get("projectile") as Projectile
	if pr:
		pr.damage *= beat_mult
		pr.splash_damage *= beat_mult
	var hb := ctx.pawn.behavior as CadenceBehavior
	if hb:
		hb.on_beat_shot(ctx.tick)
