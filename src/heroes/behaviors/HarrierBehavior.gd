extends HeroBehavior
## Harrier passive glue: mirrors Flight fuel into the hero resource so the HUD resource bar reads
## "Fuel", and tops the tank up on spawn. Flight itself lives in MovementController (hover_* fields).


func on_spawn() -> void:
	var m := pawn.movement
	m.hover_fuel = m.base_profile.hover_fuel
	pawn.hero_resource = pawn.hero.hero_resource_max


func on_tick(_dt: float) -> void:
	var m := pawn.movement
	pawn.hero_resource = clampf(m.hover_fuel, 0.0, pawn.hero.hero_resource_max)
