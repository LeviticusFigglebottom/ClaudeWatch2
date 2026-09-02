extends HeroBehavior
## Kiln ★ Heat: a hero resource (0..100) that decays 4/s (HeroData.hero_resource_regen = -4).
## Built by dealing damage (0.3 heat per point) and taking damage (0.15 per point). Vent costs 30,
## Slag Cast costs 40. Starts at zero on every spawn.

const HEAT_PER_DAMAGE_DEALT := 0.3
const HEAT_PER_DAMAGE_TAKEN := 0.15


func on_spawn() -> void:
	pawn.hero_resource = 0.0


func on_damage_dealt(ev: DamageEvent) -> void:
	if ev.dealt > 0.0:
		_add_heat(ev.dealt * HEAT_PER_DAMAGE_DEALT)


func on_damage_taken(ev: DamageEvent) -> void:
	if ev.dealt > 0.0:
		_add_heat(ev.dealt * HEAT_PER_DAMAGE_TAKEN)


func _add_heat(amount: float) -> void:
	pawn.hero_resource = clampf(pawn.hero_resource + amount, 0.0, pawn.hero.hero_resource_max)
