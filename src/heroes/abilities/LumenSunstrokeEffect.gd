class_name LumenSunstrokeEffect
extends AbilityEffect
## Sunstroke (tick effect): a wide beam of light in front of Lumen. Every visible pawn inside the cone
## is affected each tick: enemies burn for `dps` and are blinded (`enemy_status`), allies are healed
## for `heal_per_second`. Presented as a single wide beam toward the aim point.

@export var dps: float = 120.0
@export var heal_per_second: float = 100.0
@export var range: float = 30.0
@export var half_angle_deg: float = 10.0
@export var enemy_status: StatusData
@export var damage_type: RF.DamageType = RF.DamageType.BEAM


func tick(ctx: AbilityContext, dt: float) -> void:
	var p := ctx.pawn
	var world := ctx.world
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &"lumen_sunstroke"
	var cos_half := cos(deg_to_rad(half_angle_deg))
	var hit_enemies := 0
	for q: Pawn in world.pawns.values():
		if not q.alive or q == p:
			continue
		var to := q.center() - ctx.aim_origin
		var dist := to.length()
		if dist > range or dist < 0.01:
			continue
		# Widen the cone a little at close range so the beam has a visible thickness (~1.5 m) near Lumen.
		var eff_cos := cos_half if dist > 8.0 else cos(deg_to_rad(half_angle_deg + (8.0 - dist) * 2.5))
		if to.normalized().dot(ctx.aim_dir) < eff_cos:
			continue
		if not world.pawn_visible_from(ctx.aim_origin, q):
			continue
		if q.team != p.team:
			var ev := DamageEvent.new()
			ev.source = p; ev.target = q; ev.amount = dps * dt; ev.type = damage_type
			ev.ability_id = ability_id; ev.position = q.center(); ev.direction = ctx.aim_dir
			world.apply_damage(ev)
			if enemy_status and ev.dealt > 0.0:
				q.status.apply(enemy_status, p)
			hit_enemies += 1
		else:
			world.apply_heal(p, q, heal_per_second * dt, ability_id)
	var res := world.hitscan(ctx.aim_origin, ctx.aim_dir, range, p, ctx.rewind_tick, false)
	if res.barrier and dps > 0.0:
		res.barrier.absorb(dps * dt * 0.5, p)
	ctx.data["beam_end"] = res.point
	ctx.data["sunstroke_hits"] = hit_enemies
	if ctx.tick % 3 == 0:
		world.emit_custom(&"beam", {"pawn": p.net_id, "slot": ctx.ability.slot if ctx.ability else -1, "end": res.point, "tgt": res.pawn.net_id if res.pawn else -1, "on": true})


func apply(ctx: AbilityContext) -> void:
	tick(ctx, RF.TICK_DT)


func predict(ctx: AbilityContext) -> void:
	var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, range, ctx.pawn, -1, false)
	ctx.world.emit_custom(&"beam", {"pawn": ctx.pawn.net_id, "slot": ctx.ability.slot if ctx.ability else -1, "end": res.point, "tgt": -1, "on": true, "predicted": true})
