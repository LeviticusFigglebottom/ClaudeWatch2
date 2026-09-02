class_name BeamEffect
extends AbilityEffect
## Continuous beam (tick effect): damages enemies / heals allies in a thin ray each tick.
## Used inside `tick_effects` of a CHANNEL ability.

@export var dps: float = 60.0
@export var range: float = 15.0
@export var heal_per_second: float = 0.0
@export var width: float = 0.25
@export var hit_allies: bool = true
@export var enemy_status: StatusData
@export var ally_status: StatusData
@export var lock_on_deg: float = 6.0          # generous cone for healing beams
@export var damage_type: RF.DamageType = RF.DamageType.BEAM
@export var ramp_seconds: float = 0.0         # damage ramps up while on target
@export var ramp_max_mult: float = 1.0
@export var lifesteal: float = 0.0
@export var reflect_off_mirrors: bool = false


func tick(ctx: AbilityContext, dt: float) -> void:
	var p := ctx.pawn
	var target: Pawn = null
	var end_point := ctx.aim_origin + ctx.aim_dir * range
	var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, range, p, ctx.rewind_tick, hit_allies)
	end_point = res.point
	if res.pawn:
		target = res.pawn
	elif lock_on_deg > 0.0:
		# Soft lock: nearest pawn within the cone that's visible.
		var cos_c := cos(deg_to_rad(lock_on_deg))
		var best_d := -1.0
		for q: Pawn in ctx.world.pawns.values():
			if not q.alive or q == p:
				continue
			if not hit_allies and q.team == p.team:
				continue
			var to := q.center() - ctx.aim_origin
			if to.length() > range:
				continue
			var d := to.normalized().dot(ctx.aim_dir)
			if d > cos_c and d > best_d and ctx.world.pawn_visible_from(ctx.aim_origin, q):
				best_d = d; target = q
		if target:
			end_point = target.center()
	var ramp_key := "beam_ramp"
	var ramp: float = float(ctx.data.get(ramp_key, 0.0))
	if target and target.team != p.team and dps > 0.0:
		ramp = minf(ramp + dt, ramp_seconds)
		var mult := 1.0 if ramp_seconds <= 0.0 else lerpf(1.0, ramp_max_mult, ramp / ramp_seconds)
		var ev := DamageEvent.new()
		ev.source = p; ev.target = target; ev.amount = dps * dt * mult; ev.type = damage_type
		ev.ability_id = ctx.ability.data.id if ctx.ability else &""
		ev.position = end_point; ev.direction = ctx.aim_dir
		ctx.world.apply_damage(ev)
		if enemy_status and ev.dealt > 0.0:
			target.status.apply(enemy_status, p)
		if lifesteal > 0.0 and ev.dealt > 0.0:
			ctx.world.apply_heal(p, p, ev.dealt * lifesteal, ev.ability_id)
	elif target and target.team == p.team and heal_per_second > 0.0:
		ctx.world.apply_heal(p, target, heal_per_second * dt, ctx.ability.data.id if ctx.ability else &"")
		if ally_status:
			target.status.apply(ally_status, p, 0.3)
		ramp = 0.0
	else:
		ramp = maxf(ramp - dt * 2.0, 0.0)
	if res.barrier and dps > 0.0:
		res.barrier.absorb(dps * dt, p)
	ctx.data[ramp_key] = ramp
	ctx.data["beam_end"] = end_point
	ctx.data["beam_target"] = target.net_id if target else -1
	if ctx.tick % 3 == 0:
		ctx.world.emit_custom(&"beam", {"pawn": p.net_id, "slot": ctx.ability.slot if ctx.ability else -1, "end": end_point, "tgt": target.net_id if target else -1, "on": true})


func apply(ctx: AbilityContext) -> void:
	tick(ctx, RF.TICK_DT)


func predict(ctx: AbilityContext) -> void:
	var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, range, ctx.pawn, -1, hit_allies)
	ctx.world.emit_custom(&"beam", {"pawn": ctx.pawn.net_id, "slot": ctx.ability.slot if ctx.ability else -1, "end": res.point, "tgt": res.pawn.net_id if res.pawn else -1, "on": true, "predicted": true})
