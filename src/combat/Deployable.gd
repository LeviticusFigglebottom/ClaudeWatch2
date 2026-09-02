class_name Deployable
extends Node3D
## Base for placed things: barriers, turrets, totems, mirrors, beacons. Server-simulated;
## client mirrors from spawn/despawn/health events. Subclasses override step()/on_destroyed().

var id: int = 0
var owner_pawn: Pawn
var team: int = RF.Team.A
var world: SimWorld
var kind: StringName = &""
var ability_id: StringName = &""
var health: float = 0.0
var max_health: float = 0.0
var lifetime: float = 0.0        # 0 = until destroyed / replaced
var age: float = 0.0
var predicted: bool = false
var destroyed: bool = false
var data: Dictionary = {}
var facing: Vector3 = Vector3.FORWARD
var visual_id: StringName = &""
var blocks_los: bool = false
var targetable: bool = true       # bots/turrets can shoot it


func setup(w: SimWorld, owner_p: Pawn, k: StringName) -> void:
	world = w
	owner_pawn = owner_p
	team = owner_p.team if owner_p else RF.Team.NONE
	kind = k
	name = "Deploy_%s_%d" % [k, id]


func step(dt: float) -> void:
	age += dt
	if lifetime > 0.0 and age >= lifetime:
		destroy(null)


func damage(amount: float, source: Pawn) -> float:
	if destroyed or max_health <= 0.0:
		return 0.0
	if source and source.team == team:
		return 0.0
	var d := minf(amount, health)
	health -= d
	if source:
		source.add_ult_charge(d * 0.25)
		source.stats.damage += d * 0.25
	world.on_deployable_damaged(self, d, source)
	if health <= 0.0:
		destroy(source)
	return d


## Barrier-style absorption: returns damage prevented.
func absorb(amount: float, source: Pawn) -> float:
	var d := damage(amount, source)
	if owner_pawn:
		owner_pawn.stats.mitigated += d
	return d


func destroy(by: Pawn) -> void:
	if destroyed:
		return
	destroyed = true
	on_destroyed(by)
	world.on_deployable_destroyed(self, by)
	world.unregister_deployable(self)
	queue_free()


func on_destroyed(_by: Pawn) -> void:
	pass


func health_fraction() -> float:
	return 0.0 if max_health <= 0.0 else clampf(health / max_health, 0.0, 1.0)
