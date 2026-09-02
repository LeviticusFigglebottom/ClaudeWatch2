extends AbilityBehavior
## Groove (Cadence secondary, TOGGLE): while on, the aura heals every ally within 9 m for 12 hp on
## every beat (24 hp when Cadence fired on-beat since the last pulse). Cadence herself gets half.
## Runs on the server and the predicting client; healing and events are server-gated.
## Bots never switch the groove off once it is on (a human can).

var _last_pulse_tick: int = -1


func on_activate(_ctx: AbilityContext) -> void:
	_last_pulse_tick = -1


func on_tick(ctx: AbilityContext, _dt: float) -> void:
	if pawn.is_bot and not ability.toggled_on:
		ability.toggled_on = true
	# Keep the HUD status alive for as long as the toggle is on (self_status_while_active only lasts
	# 0.1 s for abilities without an active_duration).
	if ability.data.self_status_while_active:
		pawn.status.apply(ability.data.self_status_while_active, pawn, 0.6)
	var tick := ctx.tick
	if not CadenceBehavior.is_beat_tick(tick) or tick == _last_pulse_tick:
		return
	_last_pulse_tick = tick
	var hb := pawn.behavior as CadenceBehavior
	var doubled := hb != null and hb.consume_beat_bonus(tick)
	var amount := CadenceBehavior.BEAT_HEAL * (2.0 if doubled else 1.0)
	if not ctx.is_server:
		return
	var world := ctx.world
	var center := pawn.center()
	var healed_any := false
	for q: Pawn in world.pawns_in_radius(center, CadenceBehavior.AURA_RADIUS, pawn.team):
		if q == pawn:
			world.apply_heal(pawn, pawn, amount * 0.5, ability.data.id)
		else:
			if world.apply_heal(pawn, q, amount, ability.data.id) > 0.0:
				healed_any = true
	world.emit_custom(&"cadence_beat", {"pawn": pawn.net_id, "pos": center, "amount": amount, "doubled": doubled, "healed": healed_any})
	world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": pawn.global_position, "radius": CadenceBehavior.AURA_RADIUS, "vfx": &"cadence_beat_heal_double" if doubled else &"cadence_beat_heal", "ability": ability.data.id})


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	if ability.data.self_status_while_active:
		pawn.status.remove(ability.data.self_status_while_active.id)
