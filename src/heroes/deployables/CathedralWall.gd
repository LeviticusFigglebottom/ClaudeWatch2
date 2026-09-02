class_name CathedralWall
extends BarrierWall
## Cathedral ★ Stained-glass Wall: a BarrierWall (blocks enemy shots, 700 hp, 8 s) that also heals
## allies standing BEHIND it. The wall's -Z is its front (SimWorld.spawn_deployable look_at's along
## the caster's facing), so "behind" is local +Z: the caster's side. Heal zone: a rectangle
## heal_radius deep and the wall's width (+1 m each side) wide. 15 hp/s in 0.1 s ticks.
## data: width, height, heal_radius, heal_per_second.

const TICK := 0.1

var _accum: float = 0.0


func on_placed() -> void:
	super.on_placed()
	if visual_id == &"":
		visual_id = &"cathedral_wall"


func step(dt: float) -> void:
	super.step(dt)
	if destroyed or world == null or not world.is_server:
		return
	_accum += dt
	if _accum < TICK:
		return
	_accum -= TICK
	var depth: float = float(data.get("heal_radius", 4.0))
	var hps: float = float(data.get("heal_per_second", 15.0))
	var half_w: float = float(data.get("width", 6.0)) * 0.5 + 1.0
	var probe := global_position + Vector3(0, 1.0, 0)
	for p: Pawn in world.pawns_in_radius(probe, depth + half_w, team):
		var lp := to_local(p.global_position)
		if lp.z <= 0.0 or lp.z > depth:
			continue
		if absf(lp.x) > half_w or absf(lp.y) > 2.5:
			continue
		if p.health.missing() <= 0.0:
			continue
		world.apply_heal(owner_pawn, p, hps * TICK, ability_id)


## Is this pawn in the healed zone behind the wall? (Used by presentation / docs tests.)
func shelters(p: Pawn) -> bool:
	var lp := to_local(p.global_position)
	var depth: float = float(data.get("heal_radius", 4.0))
	var half_w: float = float(data.get("width", 6.0)) * 0.5 + 1.0
	return lp.z > 0.0 and lp.z <= depth and absf(lp.x) <= half_w
