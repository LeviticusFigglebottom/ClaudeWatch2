extends HeroBehavior
## Coil passive glue: hosts the Capacitor absorption window. While `capacitor_active`, incoming
## damage (except TRUE) is zeroed and banked; CoilCapacitorBehavior reads the bank on release.
## Attackers see a "damage prevented" flash instead of a hitmarker while she is charging.

var capacitor_active: bool = false
var stored: float = 0.0


func begin_capacitor() -> void:
	capacitor_active = true
	stored = 0.0


func end_capacitor() -> float:
	capacitor_active = false
	var s := stored
	stored = 0.0
	return s


func modify_incoming_damage(ev: DamageEvent) -> void:
	if not capacitor_active or ev.type == RF.DamageType.TRUE or ev.amount <= 0.0:
		return
	stored += ev.amount
	ev.amount = 0.0
	ev.prevented_reason = &"capacitor"
	if pawn.world:
		pawn.world.on_damage_prevented(ev)


func on_death(_killer: Pawn) -> void:
	capacitor_active = false
	stored = 0.0


func on_spawn() -> void:
	capacitor_active = false
	stored = 0.0
