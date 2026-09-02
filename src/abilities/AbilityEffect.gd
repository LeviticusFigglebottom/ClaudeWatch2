class_name AbilityEffect
extends Resource
## Base class for composable ability effects. Subclasses override apply()/predict().
## apply() runs on the server (authoritative). predict() runs on the owning client for
## instant feedback; it must never change authoritative state.

@export var delay: float = 0.0     # seconds after activation before this effect fires
@export var enabled: bool = true


func apply(_ctx: AbilityContext) -> void:
	pass


func predict(_ctx: AbilityContext) -> void:
	pass


## Called each tick while the ability is active (only for effects in tick_effects).
func tick(_ctx: AbilityContext, _dt: float) -> void:
	apply(_ctx)


func describe() -> String:
	return get_script().get_global_name()
