extends AbilityBehavior
## Crossing (Ferry ultimate): a 3 s cast (movement locked, invulnerable via the ability's self status),
## then every dead ally who fell within `radius` in the last `max_age` seconds (up to `max_targets`)
## is brought back at the spot they died. Resurrection is server-only: it asks GameServer to respawn
## the player normally, then moves the fresh pawn to the death position and emits a teleport event.
## Living allies inside the radius are also healed a little each second of the cast (the light).
## Bots may only start the cast when there is someone to bring back; humans decide for themselves.

const RADIUS := 10.0
const MAX_AGE := 15.0
const MAX_TARGETS := 2
const CAST_HEAL_PER_SECOND := 30.0

var _accum: float = 0.0


func _candidates(world: SimWorld) -> Array[Pawn]:
	var hb := pawn.behavior as FerryBehavior
	if hb:
		return hb.resurrect_candidates(RADIUS, MAX_AGE)
	var out: Array[Pawn] = []
	var max_ticks := int(MAX_AGE / RF.TICK_DT)
	for q: Pawn in world.pawns.values():
		if q != pawn and not q.alive and q.team == pawn.team and world.tick - q.death_tick <= max_ticks and q.global_position.distance_to(pawn.global_position) <= RADIUS:
			out.append(q)
	return out


func can_activate(ctx: AbilityContext) -> bool:
	if pawn.is_bot and ctx.is_server:
		return not _candidates(ctx.world).is_empty()
	return true


func on_activate(_ctx: AbilityContext) -> void:
	_accum = 0.0


func on_tick(ctx: AbilityContext, dt: float) -> void:
	# During the cast: a soft heal on living allies nearby (server only).
	if not ctx.is_server:
		return
	_accum += dt
	if _accum < 0.5:
		return
	_accum -= 0.5
	for q: Pawn in ctx.world.pawns_in_radius(pawn.center(), RADIUS, pawn.team, pawn):
		ctx.world.apply_heal(pawn, q, CAST_HEAL_PER_SECOND * 0.5, ability.data.id)


func on_fire(ctx: AbilityContext) -> void:
	if not ctx.is_server:
		return
	var world := ctx.world
	var mode := world.mode
	if mode == null or not ("server" in mode):
		push_warning("FerryCrossing: no server reachable through world.mode")
		return
	var server: GameServer = mode.get("server")
	if server == null:
		return
	var revived: Array = []
	for dead: Pawn in _candidates(world):
		if revived.size() >= MAX_TARGETS:
			break
		var ps := server.player_for_pawn(dead)
		if ps == null or ps.pawn != dead or (ps.pawn and ps.pawn.alive):
			continue
		var death_pos := dead.global_position
		if dead.has_meta("death_pos"):
			death_pos = dead.get_meta("death_pos")
		var spawn_from := death_pos
		ps.respawn_at_tick = -1
		if ps.pending_hero_id != &"":
			ps.hero_id = ps.pending_hero_id
			ps.pending_hero_id = &""
			ps.ult_charge_carry = 0.0
		server._spawn_player(ps)
		var fresh := ps.pawn
		if fresh == null or not fresh.alive:
			continue
		spawn_from = fresh.global_position
		var dest := world.ground_point(death_pos + Vector3(0, 0.6, 0))
		if dest.distance_to(death_pos) > 3.0:
			dest = death_pos
		fresh.global_position = dest + Vector3(0, 0.05, 0)
		fresh.velocity = Vector3.ZERO
		fresh.reset_physics_interpolation()
		fresh.hitboxes.record(world.tick)
		revived.append(fresh.net_id)
		world.emit_custom(&"teleport", {"pawn": fresh.net_id, "from": spawn_from, "to": dest})
		world.emit_custom(&"area", {"pawn": pawn.net_id, "pos": dest, "radius": 2.5, "vfx": &"ferry_crossing_heal", "ability": ability.data.id})
		var hb := pawn.behavior as FerryBehavior
		if hb:
			hb.crossings += 1
	ctx.data["revived"] = revived
	world.emit_custom(&"ferry_crossing", {"pawn": pawn.net_id, "pos": pawn.global_position, "revived": revived})
