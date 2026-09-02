class_name AbilityBehavior
extends RefCounted
## Hero-unique ability logic that doesn't fit a generic effect. One instance per Ability runtime.
## All hooks are optional. Runs on both server and predicting client; check ctx.is_server
## before touching authoritative state.

var ability: Ability
var pawn: Pawn


func setup(_ability: Ability, _pawn: Pawn) -> void:
	ability = _ability
	pawn = _pawn


func can_activate(_ctx: AbilityContext) -> bool:
	return true


func on_activate(_ctx: AbilityContext) -> void:
	pass


func on_fire(_ctx: AbilityContext) -> void:
	pass


func on_tick(_ctx: AbilityContext, _dt: float) -> void:
	pass


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	pass


func on_button_released(_ctx: AbilityContext) -> void:
	pass


## Movement hook: lets an ability drive velocity while active (dashes, flight, grapples).
func modify_velocity(_velocity: Vector3, _dt: float) -> Vector3:
	return _velocity


func wants_movement_control() -> bool:
	return false
