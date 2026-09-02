extends AbilityEffect
## Helper effect for Ballast's Anchor: sits in the harpoon projectile's on_hit_effects and hands the
## hit (world point or enemy pawn) back to the AnchorBehavior that spawned the projectile. Never
## authored in data; BallastAnchorBehavior instantiates it in code.

var behavior: AbilityBehavior


func apply(ctx: AbilityContext) -> void:
	_report(ctx)


func predict(ctx: AbilityContext) -> void:
	_report(ctx)


func _report(ctx: AbilityContext) -> void:
	if behavior and behavior.has_method("on_anchor_hit"):
		# Authority comes from the world, not ctx: the client's harpoon runs unpredicted so it can
		# sweep pawns (see BallastAnchorBehavior.on_fire), which flips ctx.is_server on the client.
		behavior.call("on_anchor_hit", ctx, ctx.world.is_server)
