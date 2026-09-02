class_name HitscanEffect
extends AbilityEffect
## Instant ray weapon. Supports spread, pellets (shotgun), falloff, headshots, pierce and on-hit status.

@export var damage: float = 20.0
@export var range: float = 120.0
@export var pellets: int = 1
@export var spread_deg: float = 0.0            # base cone (full angle)
@export var spread_moving_deg: float = 0.0     # added when moving
@export var spread_airborne_deg: float = 0.0
@export var spread_crouch_mult: float = 0.7
@export var bloom_per_shot_deg: float = 0.0    # grows while holding, decays via bloom_recovery
@export var bloom_max_deg: float = 0.0
@export var bloom_recovery_per_sec: float = 8.0
@export var falloff_start: float = 20.0
@export var falloff_end: float = 40.0
@export var falloff_min: float = 0.3
@export var headshot: bool = true
@export var pierce: bool = false
@export var hit_allies: bool = false           # e.g. healing beams that also damage
@export var ally_heal: float = 0.0             # if > 0 heals allies hit
@export var knockback: float = 0.0
@export var hit_status: StatusData
@export var self_status_on_hit: StatusData
@export var damage_type: RF.DamageType = RF.DamageType.HITSCAN
@export var lifesteal: float = 0.0
@export var tracer_from_muzzle: bool = true
@export var deployable_damage_mult: float = 1.0


func _spread_for(ctx: AbilityContext) -> float:
	var p := ctx.pawn
	var s := spread_deg
	var hs := Vector2(p.velocity.x, p.velocity.z).length()
	if hs > 1.0:
		s += spread_moving_deg * clampf(hs / maxf(p.movement.profile.max_speed, 1.0), 0.0, 1.0)
	if not p.is_on_floor():
		s += spread_airborne_deg
	if p.movement.crouching:
		s *= spread_crouch_mult
	var bloom: float = ctx.ability.charge if ctx.ability else 0.0
	s += bloom
	return s


func _fire_dir(ctx: AbilityContext, r: RandomNumberGenerator, index: int, spread: float) -> Vector3:
	var dir := ctx.aim_dir
	if spread <= 0.0:
		return dir
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
	var ang := deg_to_rad(spread * 0.5)
	var a := r.randf() * TAU
	var rr := sqrt(r.randf()) * ang
	if pellets > 1:
		# Fixed-ish shotgun pattern with jitter so shells feel consistent.
		var golden := index * 2.399963
		a = golden + r.randf_range(-0.3, 0.3)
		rr = ang * (0.35 + 0.65 * fmod(index * 0.618, 1.0))
	var local := Vector3(sin(rr) * cos(a), sin(rr) * sin(a), -cos(rr))
	return (basis * local).normalized()


func apply(ctx: AbilityContext) -> void:
	_do(ctx, true)


func predict(ctx: AbilityContext) -> void:
	_do(ctx, false)


func _do(ctx: AbilityContext, authoritative: bool) -> void:
	var r := ctx.rng()
	var spread := _spread_for(ctx)
	var hits: Array = []
	var p := ctx.pawn
	if bloom_per_shot_deg > 0.0 and ctx.ability:
		ctx.ability.charge = minf(ctx.ability.charge + bloom_per_shot_deg, bloom_max_deg)
	if authoritative:
		p.stats.shots_fired += 1
	for i in maxi(pellets, 1):
		var dir := _fire_dir(ctx, r, i, spread)
		var res := ctx.world.hitscan(ctx.aim_origin, dir, range, p, ctx.rewind_tick, hit_allies)
		var end_point := res.point
		var hit_pawn := res.pawn
		hits.append({"end": end_point, "normal": res.normal, "pawn": hit_pawn.net_id if hit_pawn else -1, "part": res.part, "dir": dir, "barrier": res.barrier != null, "deployable": res.deployable != null})
		if not authoritative:
			continue
		if hit_pawn != null:
			if hit_pawn.team != p.team:
				var ev := DamageEvent.new()
				ev.source = p; ev.target = hit_pawn
				var dist := res.distance
				var fall := 1.0
				if falloff_end > falloff_start:
					fall = lerpf(1.0, falloff_min, clampf((dist - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))
				ev.amount = damage * fall
				ev.type = damage_type
				ev.headshot = headshot and res.part == &"head"
				ev.ability_id = ctx.ability.data.id if ctx.ability else &""
				ev.position = res.point; ev.direction = dir; ev.knockback = knockback
				ctx.world.apply_damage(ev)
				if ev.dealt > 0.0:
					p.stats.shots_hit += 1
					if ev.headshot:
						p.stats.headshots += 1
					if hit_status:
						hit_pawn.status.apply(hit_status, p)
					if self_status_on_hit:
						p.status.apply(self_status_on_hit, p)
					if lifesteal > 0.0:
						ctx.world.apply_heal(p, p, ev.dealt * lifesteal, ev.ability_id)
			elif ally_heal > 0.0:
				ctx.world.apply_heal(p, hit_pawn, ally_heal, ctx.ability.data.id if ctx.ability else &"")
		elif res.barrier != null:
			res.barrier.absorb(damage, p)
		elif res.deployable != null:
			res.deployable.damage(damage * deployable_damage_mult, p)
	ctx.data["hits"] = hits
	# Presentation event (server broadcasts, client predicts): tracers + impacts.
	ctx.world.emit_custom(&"hitscan", {"pawn": p.net_id, "slot": ctx.ability.slot if ctx.ability else -1, "hits": hits, "origin": ctx.aim_origin, "predicted": not authoritative})
