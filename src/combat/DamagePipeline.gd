class_name DamagePipeline
extends RefCounted
## Authoritative damage/heal resolution. Called only on the server through SimWorld.

static func resolve_damage(ev: DamageEvent, world: SimWorld) -> void:
	var t := ev.target
	if t == null or not t.alive:
		ev.prevented = true; ev.prevented_reason = &"dead"
		return
	var src := ev.source
	# Team rules: no friendly damage; self damage only for environment/true types.
	if src != null and src != t and src.team == t.team:
		ev.prevented = true; ev.prevented_reason = &"friendly"
		return
	if src == t and ev.type != RF.DamageType.ENVIRONMENT and ev.type != RF.DamageType.TRUE:
		ev.prevented = true; ev.prevented_reason = &"self"
		return
	if t.status.invulnerable and ev.type != RF.DamageType.TRUE:
		ev.prevented = true; ev.prevented_reason = &"invulnerable"
		world.on_damage_prevented(ev)
		return
	if t.spawn_protected(world.tick):
		ev.prevented = true; ev.prevented_reason = &"spawn_protection"
		return
	var tuning := world.tuning
	# Modifiers
	if ev.headshot and t.hitboxes.profile.headshot_enabled:
		ev.amount *= tuning.headshot_multiplier
	if src != null:
		ev.amount *= src.status.damage_dealt_mult
		if src.behavior:
			src.behavior.modify_outgoing_damage(ev)
	ev.amount *= t.status.damage_taken_mult
	if t.behavior:
		t.behavior.modify_incoming_damage(ev)
	if ev.amount <= 0.0:
		ev.prevented = true; ev.prevented_reason = &"zero"
		return
	# Vigil-style protection: the hit can't take the last hit point.
	if t.status.min_health_one and ev.type != RF.DamageType.TRUE:
		var cap := t.health.total() - 1.0
		if ev.amount >= cap:
			ev.amount = maxf(cap, 0.0)
			if ev.amount <= 0.0:
				ev.prevented = true; ev.prevented_reason = &"vigil"
				world.on_damage_prevented(ev)
				return
	# Apply to layers
	var dealt := t.health.take(ev, tuning)
	t.health.last_damage_tick = world.tick
	t.last_damage_tick = world.tick
	if src != null and src != t:
		t.last_damage_source = src
		t.last_damage_source_tick = world.tick
	# Ult charge + stats
	if src != null and src != t:
		src.add_ult_charge(dealt * tuning.ult_charge_per_damage * src.status.ult_charge_mult)
		src.stats.damage += dealt
		if src.behavior:
			src.behavior.on_damage_dealt(ev)
	if t.behavior:
		t.behavior.on_damage_taken(ev)
	t.stats.damage_taken += dealt
	world.on_damage(ev)
	# Knockback
	if ev.knockback > 0.0 and not t.status.unstoppable:
		var dir := ev.direction
		if dir.length_squared() < 0.001 and src != null:
			dir = (t.global_position - src.global_position)
		dir = dir.normalized()
		dir.y = maxf(dir.y, 0.25)
		t.apply_knockback(dir.normalized() * ev.knockback)
	# Death
	if ev.killed:
		world.kill_pawn(t, src, ev)


static func resolve_heal(source: Pawn, target: Pawn, amount: float, ability_id: StringName, world: SimWorld) -> float:
	if target == null or not target.alive or amount <= 0.0:
		return 0.0
	if target.status.anti_heal:
		world.on_heal_prevented(source, target)
		return 0.0
	var mult := target.status.healing_received_mult
	if source != null:
		mult *= source.status.healing_dealt_mult
	var healed := target.health.heal(amount * mult)
	if healed <= 0.0:
		return 0.0
	target.health.last_heal_tick = world.tick
	if source != null:
		var charge_mult := world.tuning.ult_charge_per_heal
		if source == target:
			charge_mult *= world.tuning.ult_charge_self_heal_mult
		source.add_ult_charge(healed * charge_mult * source.status.ult_charge_mult)
		source.stats.healing += healed
		if source.behavior:
			source.behavior.on_heal_dealt(healed, target)
	world.on_heal(source, target, healed, ability_id)
	return healed
