class_name HeroBehavior
extends RefCounted
## Hero-unique passive logic (resources like Heat/Fuel, special reactions). Optional per hero.

var pawn: Pawn


func setup(_pawn: Pawn) -> void:
	pawn = _pawn


func on_tick(_dt: float) -> void:
	pass


func on_damage_dealt(_ev: DamageEvent) -> void:
	pass


func on_damage_taken(_ev: DamageEvent) -> void:
	pass


func on_kill(_victim: Pawn) -> void:
	pass


func on_death(_killer: Pawn) -> void:
	pass


func on_spawn() -> void:
	pass


func on_heal_dealt(_amount: float, _target: Pawn) -> void:
	pass


## Modify outgoing damage (e.g. Sable backstab bonus).
func modify_outgoing_damage(ev: DamageEvent) -> void:
	pass


## Modify incoming damage before layers (e.g. Ballast anchor armor).
func modify_incoming_damage(ev: DamageEvent) -> void:
	pass
