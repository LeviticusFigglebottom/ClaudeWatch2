class_name CleanseEffect
extends AbilityEffect
## Removes debuffs from self / aimed ally / allies in radius.

enum Who { SELF, AIMED_ALLY, ALLIES_IN_RADIUS }
@export var who: Who = Who.ALLIES_IN_RADIUS
@export var radius: float = 8.0
@export var range: float = 25.0
@export var include_self: bool = true


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	match who:
		Who.SELF:
			p.status.cleanse()
		Who.AIMED_ALLY:
			var t := HealEffect.aimed_ally(ctx, range, 14.0)
			if t: t.status.cleanse()
		Who.ALLIES_IN_RADIUS:
			for q: Pawn in ctx.world.pawns_in_radius(p.center(), radius, p.team, null if include_self else p):
				q.status.cleanse()
