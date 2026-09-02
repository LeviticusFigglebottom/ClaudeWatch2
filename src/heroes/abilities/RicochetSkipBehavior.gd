extends AbilityBehavior
## Skip: the dash itself is a DashEffect on the ability; this behavior leaves a disc behind at the
## spot Ricochet skipped away from. The disc drops, bounces off the floor (arming itself) and keeps
## hopping in place for 4 s — a bouncing mine that punishes anyone who follows.

const DiscScript := preload("res://src/heroes/abilities/RicochetDiscBehavior.gd")
const DROP_SPEED := 9.0


func on_fire(ctx: AbilityContext) -> void:
	var origin := pawn.global_position + Vector3(0, 1.0, 0) - pawn.forward_flat() * 0.3
	var cfg := {"bounces": 8, "damping": 1.0, "radius": 0.35, "lifetime": 4.0, "gravity": 18.0, "table": [40.0, 55.0, 70.0]}
	DiscScript.launch(ctx.world, pawn, ability.data.id, origin, Vector3(0, -DROP_SPEED, 0), cfg, ctx.seed, false)
