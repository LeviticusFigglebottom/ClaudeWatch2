extends AimedAllyGate
## Tether: aim at an ally and press. The ally receives the `suture_tether` status (via the ability's
## TARGET effects) and is linked in SutureBehavior. Refusing to fire without an ally under the crosshair
## keeps bots from wasting the cooldown.


func on_fire(ctx: AbilityContext) -> void:
	super.on_fire(ctx)
	if target == null:
		return
	var hb := pawn.behavior as SutureBehavior
	if hb:
		hb.link(target)
	if ctx.is_server:
		ctx.world.emit_custom(&"suture_tether_link", {"pawn": pawn.net_id, "ally": target.net_id, "pos": target.center(), "links": hb.linked_ids() if hb else []})
