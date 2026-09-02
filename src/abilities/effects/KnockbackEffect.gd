class_name KnockbackEffect
extends AbilityEffect
## Pushes enemies in a cone or radius away from (or toward) the caster.

@export var radius: float = 6.0
@export var cone_deg: float = 360.0
@export var force: float = 10.0
@export var upward: float = 0.3
@export var pull: bool = false
@export var requires_los: bool = true
@export var center_on_point: bool = false
@export var damage: float = 0.0


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var c := ctx.point if center_on_point else p.center()
	for q: Pawn in ctx.world.pawns_in_radius(c, radius, RF.enemy_team(p.team)):
		var to := q.center() - c
		if cone_deg < 360.0:
			var ang := rad_to_deg(acos(clampf(to.normalized().dot(ctx.aim_dir), -1.0, 1.0)))
			if ang > cone_deg * 0.5:
				continue
		if requires_los and not ctx.world.has_line_of_sight(c, q.center()):
			continue
		var dir := to.normalized()
		if pull:
			dir = -dir
		dir.y += upward
		if damage > 0.0:
			var ev := DamageEvent.new()
			ev.source = p; ev.target = q; ev.amount = damage; ev.type = RF.DamageType.SPLASH
			ev.ability_id = ctx.ability.data.id if ctx.ability else &""; ev.position = q.center(); ev.direction = dir
			ctx.world.apply_damage(ev)
		q.apply_knockback(dir.normalized() * force)
