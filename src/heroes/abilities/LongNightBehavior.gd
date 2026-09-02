extends AbilityBehavior
## Long Night: infinite ammo + no falloff + reveal on hit while active.

var _orig_falloff: Array = []
var _hs: HitscanEffect
var _reveal: StatusData


func on_activate(_ctx: AbilityContext) -> void:
	var prim := pawn.abilities.get_slot(RF.Slot.PRIMARY)
	if prim:
		prim.ammo = prim.data.ammo
		prim.reload_remaining = 0.0
	_reveal = StatusLibrary.get_status(&"revealed_lantern")


func on_tick(ctx: AbilityContext, _dt: float) -> void:
	var prim := pawn.abilities.get_slot(RF.Slot.PRIMARY)
	if prim:
		prim.ammo = prim.data.ammo
		prim.reload_remaining = 0.0
	if not ctx.is_server or _reveal == null:
		return
	# Reveal anything damaged by Vesper in the last tick.
	for p: Pawn in ctx.world.pawns.values():
		if p.team != pawn.team and p.alive and p.last_damage_source == pawn and p.last_damage_source_tick == ctx.world.tick:
			p.status.apply(_reveal, pawn, 4.0)
