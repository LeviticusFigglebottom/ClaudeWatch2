class_name ApplyStatusEffect
extends AbilityEffect
## Applies a status to self, the resolved target, or everyone in a radius.

enum Who { SELF, TARGET, ALLIES_IN_RADIUS, ENEMIES_IN_RADIUS, ALL_IN_RADIUS, ALLIES_IN_RADIUS_INCLUDING_SELF }

@export var status: StatusData
@export var who: Who = Who.SELF
@export var radius: float = 6.0
@export var duration_override: float = -1.0
@export var requires_los: bool = true
@export var center_on_point: bool = false   # use ctx.point instead of pawn position


func apply(ctx: AbilityContext) -> void:
	if status == null:
		return
	var p := ctx.pawn
	var center := ctx.point if center_on_point else p.center()
	match who:
		Who.SELF:
			p.status.apply(status, p, duration_override)
		Who.TARGET:
			if ctx.target:
				ctx.target.status.apply(status, p, duration_override)
		_:
			for q: Pawn in ctx.world.pawns_in_radius(center, radius):
				var ally := q.team == p.team
				if who == Who.ALLIES_IN_RADIUS and (not ally or q == p):
					continue
				if who == Who.ALLIES_IN_RADIUS_INCLUDING_SELF and not ally:
					continue
				if who == Who.ENEMIES_IN_RADIUS and ally:
					continue
				if requires_los and q != p and not ctx.world.has_line_of_sight(center, q.center()):
					continue
				q.status.apply(status, p, duration_override)
