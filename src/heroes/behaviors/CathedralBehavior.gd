extends HeroBehavior
## Cathedral passive "Vestment": every enemy struck by the Reliquary Mace heals her for a little.
## A small sustain that makes standing in the front line with a melee weapon viable.

const HEAL_PER_HIT := 8.0


func on_damage_dealt(ev: DamageEvent) -> void:
	if ev.ability_id != &"cathedral_mace" or ev.dealt <= 0.0:
		return
	if pawn.world and pawn.world.is_server:
		pawn.world.apply_heal(pawn, pawn, HEAL_PER_HIT, &"cathedral_vestment")
