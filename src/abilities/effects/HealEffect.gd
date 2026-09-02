class_name HealEffect
extends AbilityEffect
## Heals self or the ally under the crosshair (with a generous cone for feel).

enum Who { SELF, AIMED_ALLY, LOWEST_ALLY_IN_RADIUS, ALLIES_IN_RADIUS, TARGET }

@export var amount: float = 50.0
@export var who: Who = Who.AIMED_ALLY
@export var range: float = 25.0
@export var cone_deg: float = 12.0
@export var radius: float = 8.0
@export var include_self: bool = false
@export var overhealth: float = 0.0
@export var overhealth_cap: float = 0.0
@export var fallback_to_self: bool = false


static func aimed_ally(ctx: AbilityContext, range_: float, cone: float) -> Pawn:
	var best: Pawn = null
	var best_score := -1.0
	var cos_cone := cos(deg_to_rad(cone))
	for q: Pawn in ctx.world.pawns.values():
		if not q.alive or q == ctx.pawn or q.team != ctx.pawn.team:
			continue
		var to := q.center() - ctx.aim_origin
		var dist := to.length()
		if dist > range_:
			continue
		var d := to.normalized().dot(ctx.aim_dir)
		if d < cos_cone:
			continue
		if not ctx.world.pawn_visible_from(ctx.aim_origin, q):
			continue
		var score := d - dist / range_ * 0.2
		if score > best_score:
			best_score = score; best = q
	return best


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &""
	var targets: Array[Pawn] = []
	match who:
		Who.SELF:
			targets.append(p)
		Who.TARGET:
			if ctx.target: targets.append(ctx.target)
		Who.AIMED_ALLY:
			var t := aimed_ally(ctx, range, cone_deg)
			if t: targets.append(t)
			elif fallback_to_self: targets.append(p)
		Who.LOWEST_ALLY_IN_RADIUS:
			var best: Pawn = null
			for q: Pawn in ctx.world.pawns_in_radius(p.center(), radius, p.team, null if include_self else p):
				if best == null or q.health.fraction() < best.health.fraction():
					best = q
			if best: targets.append(best)
		Who.ALLIES_IN_RADIUS:
			for q: Pawn in ctx.world.pawns_in_radius(p.center(), radius, p.team, null if include_self else p):
				targets.append(q)
	for t: Pawn in targets:
		ctx.world.apply_heal(p, t, amount, ability_id)
		if overhealth > 0.0:
			t.health.grant_overhealth(overhealth, maxf(overhealth_cap, overhealth))
	ctx.data["heal_targets"] = targets
