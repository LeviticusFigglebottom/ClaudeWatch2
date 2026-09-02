class_name AimedAllyGate
extends AbilityBehavior
## Generic guard for ally-targeted PRESS abilities: the ability only activates when an ally is under the
## crosshair (HealEffect.aimed_ally rules), so a press aimed at nothing does not burn the cooldown, and
## `ctx.target` is set for TARGET-mode effects (HealEffect / ApplyStatusEffect with who = TARGET).
## Lives under Suture's prefix because she is the main user; Lumen's Glint reuses it.

var range: float = 25.0
var cone_deg: float = 14.0
var min_distance: float = 0.0
var target: Pawn


func find_target(ctx: AbilityContext) -> Pawn:
	var t := HealEffect.aimed_ally(ctx, range, cone_deg)
	if t and min_distance > 0.0 and t.global_position.distance_to(pawn.global_position) < min_distance:
		return null
	return t


func can_activate(ctx: AbilityContext) -> bool:
	return find_target(ctx) != null


func on_fire(ctx: AbilityContext) -> void:
	target = find_target(ctx)
	ctx.target = target
	ctx.point = target.center() if target else ctx.aim_origin + ctx.aim_dir * 3.0
