extends AbilityBehavior
## Afterburn: the speed buff is a plain ApplyStatusEffect on the ability; this behavior does the
## part no effect expresses — an instant refill of Flight fuel. Runs on both sides (movement state).


func on_fire(_ctx: AbilityContext) -> void:
	var m := pawn.movement
	m.hover_fuel = m.base_profile.hover_fuel
