class_name BombardAirburstShell
extends Projectile
## Airburst: a mortar shell with a proximity fuse. Detonates when it passes within `proximity_radius`
## (horizontal) and above an enemy it can see, or at the end of its fuse (explode_on_expire).

var proximity_radius: float = 3.2


func step(dt: float) -> void:
	if not predicted and not stuck and age > 0.12 and splash_radius > 0.0:
		var gp := global_position
		for p: Pawn in world.pawns.values():
			if not p.alive or p == owner_pawn or p.team == team:
				continue
			var c := p.center()
			var dx := Vector2(c.x - gp.x, c.z - gp.z).length()
			var dy := gp.y - c.y
			if dx <= proximity_radius and dy >= -0.6 and dy <= 6.0 and world.has_line_of_sight(gp, c, RF.L_WORLD):
				detonate()
				return
	super.step(dt)


func detonate() -> void:
	_splash(global_position)
	for e: AbilityEffect in on_expire_effects:
		_run(e, global_position, Vector3.UP, null)
	world.on_projectile_impact(self, global_position, Vector3.UP, null)
	queue_free_safe()


func _expire() -> void:
	if explode_on_expire and splash_radius > 0.0:
		detonate()
		return
	super._expire()
