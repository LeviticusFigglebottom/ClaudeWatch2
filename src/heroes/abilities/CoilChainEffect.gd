extends AbilityEffect
## Coil's ★ Chain. Placed after a HitscanEffect in an ability's effect list: reads ctx.data["hits"]
## and, for every enemy that was hit, arcs to the nearest un-hit enemy within `radius` (LOS), then
## from that one to the next, up to `max_jumps` extra targets with decaying damage (70% / 50%).
## Friendly Tesla Nodes relay the arc: if no enemy is in reach, the chain hops through a node and
## continues from it without spending a jump. Emits `chain_arc` {from, to} for the VFX spawner and a
## small `area` spark on each secondary target as a fallback presentation.

@export var radius: float = 6.0
@export var max_jumps: int = 2
@export var multipliers: Array[float] = [0.7, 0.5]
@export var base_damage: float = 30.0
@export var damage_type: RF.DamageType = RF.DamageType.BEAM
@export var relay_kind: StringName = &"tesla_node"
@export var max_relays: int = 2
@export var spark_vfx: StringName = &"coil_chain_explosion"


func apply(ctx: AbilityContext) -> void:
	var hits: Array = ctx.data.get("hits", [])
	var p := ctx.pawn
	var visited: Dictionary = {}
	for h: Dictionary in hits:
		var nid := int(h.get("pawn", -1))
		if nid < 0:
			continue
		var first := ctx.world.get_pawn(nid)
		if first == null or not first.alive or first.team == p.team:
			continue
		if visited.has(first.net_id):
			continue
		visited[first.net_id] = true
		_chain_from(ctx, first.center(), visited)


func predict(_ctx: AbilityContext) -> void:
	pass


func _chain_from(ctx: AbilityContext, start: Vector3, visited: Dictionary) -> void:
	var p := ctx.pawn
	var cur := start
	var jumps := 0
	var relays := 0
	var used_relays: Dictionary = {}
	var ability_id: StringName = ctx.ability.data.id if ctx.ability else &""
	while jumps < max_jumps:
		var next := _nearest_enemy(ctx, cur, visited)
		if next == null:
			if relays >= max_relays:
				break
			var node := _nearest_relay(ctx, cur, used_relays)
			if node == null:
				break
			used_relays[node.id] = true
			relays += 1
			var top := node.global_position + Vector3(0, 0.9, 0)
			ctx.world.emit_custom(&"chain_arc", {"pawn": p.net_id, "from": cur, "to": top, "pos": cur, "relay": true})
			cur = top
			continue
		visited[next.net_id] = true
		var mult: float = multipliers[mini(jumps, multipliers.size() - 1)] if not multipliers.is_empty() else 0.5
		var ev := DamageEvent.new()
		ev.source = p
		ev.target = next
		ev.amount = base_damage * mult
		ev.type = damage_type
		ev.ability_id = ability_id
		ev.position = next.center()
		ev.direction = (next.center() - cur).normalized()
		ctx.world.apply_damage(ev)
		ctx.world.emit_custom(&"chain_arc", {"pawn": p.net_id, "from": cur, "to": next.center(), "pos": cur, "relay": false})
		ctx.world.emit_custom(&"area", {"pawn": p.net_id, "pos": next.global_position, "radius": 0.9, "vfx": spark_vfx, "ability": ability_id})
		cur = next.center()
		jumps += 1


func _nearest_enemy(ctx: AbilityContext, from: Vector3, visited: Dictionary) -> Pawn:
	var best: Pawn = null
	var best_d := INF
	for q: Pawn in ctx.world.pawns_in_radius(from, radius, RF.enemy_team(ctx.pawn.team)):
		if visited.has(q.net_id):
			continue
		var d := q.center().distance_to(from)
		if d < best_d and ctx.world.has_line_of_sight(from, q.center()):
			best_d = d
			best = q
	return best


func _nearest_relay(ctx: AbilityContext, from: Vector3, used: Dictionary) -> Deployable:
	var best: Deployable = null
	var best_d := INF
	for d: Deployable in ctx.world.deployables.values():
		if not is_instance_valid(d) or d.destroyed or d.kind != relay_kind or d.team != ctx.pawn.team:
			continue
		if used.has(d.id):
			continue
		var top := d.global_position + Vector3(0, 0.9, 0)
		var dist := top.distance_to(from)
		if dist <= radius and dist < best_d and ctx.world.has_line_of_sight(from, top):
			best_d = dist
			best = d
	return best
