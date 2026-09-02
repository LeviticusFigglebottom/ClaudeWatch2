extends AbilityEffect
## Ricochet's ★ rule, run on every wall bounce of a disc (Projectile.on_bounce_effects).
## A fresh disc ignores enemies (its hits_done is pre-filled with every enemy id by
## RicochetDiscBehavior.launch); each bounce arms it: clears that ignore list, counts the bounce and
## sets the projectile's damage from the table (45 / 70 / 95 by default, capped at the last entry).
## Bank Shot: a primed disc locks homing (strength 6) onto the nearest enemy visible from the bounce.

@export var table: Array[float] = [45.0, 70.0, 95.0]
@export var bank_homing_strength: float = 6.0
@export var bank_search_radius: float = 30.0


func apply(ctx: AbilityContext) -> void:
	_bounce(ctx, true)


func predict(ctx: AbilityContext) -> void:
	_bounce(ctx, false)


func _bounce(ctx: AbilityContext, authoritative: bool) -> void:
	var pr := ctx.data.get("projectile") as Projectile
	if pr == null or not is_instance_valid(pr):
		return
	var n := int(ctx.data.get("bounces", 0)) + 1
	ctx.data["bounces"] = n
	var tbl: Array = ctx.data.get("table", table)
	if tbl.is_empty():
		tbl = table
	pr.damage = float(tbl[mini(n, tbl.size()) - 1])
	pr.hits_done.clear()
	pr.pierce = false
	if not authoritative:
		return
	if bool(ctx.data.get("bank", false)):
		var origin := ctx.point + ctx.normal * 0.25
		var best: Pawn = null
		var best_d := INF
		for q: Pawn in ctx.world.pawns_in_radius(origin, bank_search_radius, RF.enemy_team(pr.team)):
			var d := q.center().distance_to(origin)
			if d < best_d and ctx.world.has_line_of_sight(origin, q.center()):
				best_d = d
				best = q
		if best:
			pr.homing_target = best
			pr.homing_strength = bank_homing_strength
			ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": ctx.point, "radius": 0.8, "vfx": &"ricochet_bank_lock", "ability": pr.ability_id})
