class_name AreaEffect
extends AbilityEffect
## Sphere of damage and/or healing around the caster or the resolved point.

@export var radius: float = 5.0
@export var damage: float = 0.0
@export var heal: float = 0.0
@export var heal_self: bool = true
@export var min_fraction: float = 0.5        # damage at the edge
@export var knockback: float = 0.0
@export var pull: float = 0.0                # >0 pulls enemies toward the center
@export var requires_los: bool = true
@export var center_on_point: bool = false
@export var center_on_aim_hit: bool = false  # raycast from eye to find the point
@export var max_aim_distance: float = 30.0
@export var damage_type: RF.DamageType = RF.DamageType.SPLASH
@export var enemy_status: StatusData
@export var ally_status: StatusData
@export var vfx_id: StringName = &""


func resolve_center(ctx: AbilityContext) -> Vector3:
	if center_on_aim_hit:
		var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, max_aim_distance, ctx.pawn, ctx.rewind_tick)
		ctx.point = res.point
		ctx.normal = res.normal
		return res.point
	if center_on_point:
		return ctx.point
	return ctx.pawn.center()


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var c := resolve_center(ctx)
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &""
	for q: Pawn in ctx.world.pawns_in_radius(c, radius):
		var closest := q.hitboxes.closest_point(c)
		if requires_los and not ctx.world.has_line_of_sight(c, closest):
			continue
		var d := closest.distance_to(c)
		var frac := lerpf(1.0, min_fraction, clampf(d / maxf(radius, 0.01), 0.0, 1.0))
		if q.team != p.team:
			if damage > 0.0:
				var ev := DamageEvent.new()
				ev.source = p; ev.target = q; ev.amount = damage * frac; ev.type = damage_type
				ev.ability_id = ability_id; ev.position = closest
				ev.direction = (closest - c).normalized(); ev.knockback = knockback * frac
				ctx.world.apply_damage(ev)
			if pull > 0.0 and not q.status.unstoppable:
				var dir := (c - q.center())
				dir.y = maxf(dir.y, 0.0) + 0.2
				q.apply_knockback(dir.normalized() * pull)
			if enemy_status:
				q.status.apply(enemy_status, p)
		else:
			if q == p and not heal_self:
				continue
			if heal > 0.0:
				ctx.world.apply_heal(p, q, heal * frac, ability_id)
			if ally_status:
				q.status.apply(ally_status, p)
	ctx.world.emit_custom(&"area", {"pawn": p.net_id, "pos": c, "radius": radius, "vfx": _vfx(ctx), "ability": ability_id})


func predict(ctx: AbilityContext) -> void:
	var c := resolve_center(ctx)
	ctx.world.emit_custom(&"area", {"pawn": ctx.pawn.net_id, "pos": c, "radius": radius, "vfx": _vfx(ctx), "ability": ctx.ability.data.id if ctx.ability else &"", "predicted": true})


## The effect's own id wins; otherwise fall back to the ability's authored area_vfx, which had no
## path to the client before and so was silently ignored on every ability that set it.
func _vfx(ctx: AbilityContext) -> StringName:
	if vfx_id != &"":
		return vfx_id
	if ctx.ability and ctx.ability.data and ctx.ability.data.presentation:
		return ctx.ability.data.presentation.area_vfx
	return &""
