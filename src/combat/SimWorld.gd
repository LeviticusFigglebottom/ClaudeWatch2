class_name SimWorld
extends Node3D
## The simulation container: pawns, projectiles, deployables, the loaded map, and all the hooks
## the combat systems call into. One SimWorld lives on the server (authoritative) and one on each
## client (for prediction + presentation). Events flow out through `sim_event` and are turned into
## network messages (server) or presentation (client) by whoever owns the world.

signal sim_event(kind: StringName, payload: Dictionary)

var is_server: bool = false
var tick: int = 0
var tuning: GlobalTuning
var pawns: Dictionary = {}           # net_id -> Pawn
var projectiles: Dictionary = {}     # id -> Projectile
var deployables: Dictionary = {}     # id -> Deployable
var map_root: Node3D
var map_data: MapData
var melee_ability: AbilityData
var _next_entity_id: int = 1
var sound_listeners: Array[Callable] = []   # AI perception hooks: (pawn, kind, loudness, pos)
var objective_positions: Array[Vector3] = []
var barriers: Array[Deployable] = []
var rng := RandomNumberGenerator.new()
var pickups: Array = []              # HealthPack nodes
var mode: Node                       # ModeController (server) or a mirror (client)
var frozen: bool = false             # pre-round: pawns can look but not move/shoot
var _space: PhysicsDirectSpaceState3D


func _ready() -> void:
	tuning = Registry.tuning if Registry.tuning else GlobalTuning.new()
	melee_ability = _build_melee()
	rng.seed = 1337


func _build_melee() -> AbilityData:
	var d := AbilityData.new()
	d.id = &"quick_melee"
	d.display_name = "Quick Melee"
	d.trigger = AbilityData.Trigger.PRESS
	d.cooldown = tuning.melee_cooldown
	d.usable_while_silenced = true
	d.is_weapon = false
	d.interruptible_by_other_abilities = true
	var m := MeleeEffect.new()
	m.damage = tuning.melee_damage
	m.range = tuning.melee_range
	m.knockback = tuning.melee_knockback
	m.delay = 0.08
	d.effects = [m]
	var pres := AbilityPresentation.new()
	pres.sound_fire = &"melee_swing"
	pres.sound_impact = &"melee_hit"
	pres.camera_shake = 0.08
	pres.anim_tag = &"melee"
	pres.viewmodel_kick = 0.05
	d.presentation = pres
	return d


func next_id() -> int:
	_next_entity_id += 1
	return _next_entity_id


func space() -> PhysicsDirectSpaceState3D:
	return get_world_3d().direct_space_state


## --- Map ---------------------------------------------------------------------------------

func load_map(md: MapData) -> void:
	if map_root:
		map_root.queue_free()
		map_root = null
	map_data = md
	var scene := load(md.scene_path) as PackedScene
	if scene == null:
		push_error("SimWorld: cannot load map scene %s" % md.scene_path)
		return
	map_root = scene.instantiate() as Node3D
	map_root.name = "Map"
	add_child(map_root)
	if map_root.has_method("on_world_attached"):
		map_root.call("on_world_attached", self)
	objective_positions.clear()


## --- Pawns -------------------------------------------------------------------------------

func add_pawn(hero: HeroData, team: int, player_id: int, net_id: int = -1) -> Pawn:
	var p := Pawn.new()
	var nid := net_id if net_id >= 0 else next_id()
	p.setup(self, hero, team, nid, player_id, is_server)
	pawns[nid] = p
	add_child(p)
	p.global_position = Vector3(0, -1000, 0)
	return p


## Removes a pawn and severs every reference entities may still hold to it.
## Deployables, projectiles and status instances routinely outlive their owner (a turret placed
## before its owner died keeps ticking), so freeing the pawn without clearing those leaves dangling
## references that blow up the moment a deployable builds a DamageEvent from `owner_pawn`.
func remove_pawn(p: Pawn) -> void:
	if p == null:
		return
	pawns.erase(p.net_id)
	for d: Deployable in deployables.values():
		if d.owner_pawn == p:
			d.owner_pawn = null
	for pr: Projectile in projectiles.values():
		if pr.owner_pawn == p:
			pr.owner_pawn = null
		if pr.homing_target == p:
			pr.homing_target = null
	for other: Pawn in pawns.values():
		for inst: StatusInstance in other.status.active:
			if inst.source == p:
				inst.source = null
		if other.last_damage_source == p:
			other.last_damage_source = null
	p.queue_free()


func get_pawn(net_id: int) -> Pawn:
	return pawns.get(net_id) as Pawn


func pawn_for_player(player_id: int) -> Pawn:
	for p: Pawn in pawns.values():
		if p.player_id == player_id:
			return p
	return null


func alive_pawns(team: int = -1) -> Array[Pawn]:
	var out: Array[Pawn] = []
	for p: Pawn in pawns.values():
		if p.alive and (team < 0 or p.team == team):
			out.append(p)
	return out


func pawns_in_radius(center_pos: Vector3, radius: float, team: int = -1, exclude: Pawn = null, alive_only: bool = true) -> Array[Pawn]:
	var out: Array[Pawn] = []
	for p: Pawn in pawns.values():
		if alive_only and not p.alive:
			continue
		if p == exclude:
			continue
		if team >= 0 and p.team != team:
			continue
		if p.hitboxes.overlaps_sphere(center_pos, radius):
			out.append(p)
	return out


## --- Queries -----------------------------------------------------------------------------

## Ray against static world + deployables + enemy barriers. Returns {} or {distance, point, normal, collider, barrier}.
func raycast_world(from: Vector3, dir: Vector3, max_dist: float, shooter_team: int = -1, include_barriers: bool = true, exclude: Array[RID] = []) -> Dictionary:
	var mask := RF.L_WORLD | RF.L_DEPLOYABLE | RF.L_PAYLOAD | RF.L_PROJECTILE_BLOCKER
	if include_barriers and shooter_team >= 0:
		mask |= RF.barrier_layer(RF.enemy_team(shooter_team))
	elif include_barriers:
		mask |= RF.L_BARRIER_A | RF.L_BARRIER_B
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * max_dist, mask, exclude)
	q.hit_from_inside = false
	var hit := space().intersect_ray(q)
	if hit.is_empty():
		return {}
	var col: Object = hit["collider"]
	var out := {"distance": from.distance_to(hit["position"]), "point": hit["position"], "normal": hit["normal"], "collider": col}
	var node := col as Node
	if node and node.has_meta("deployable"):
		var d: Deployable = node.get_meta("deployable")
		if d and (d.kind.begins_with("barrier") or d.blocks_los):
			out["barrier"] = d
		out["deployable"] = d
	return out


class HitscanResult:
	var hit: bool = false
	var pawn: Pawn
	var part: StringName = &""
	var point: Vector3
	var normal: Vector3
	var distance: float = INF
	var barrier: Deployable
	var deployable: Deployable


## Full hitscan: world + rewound pawn hitboxes. `rewind_tick` is the client's render tick for lag comp.
func hitscan(from: Vector3, dir: Vector3, max_dist: float, shooter: Pawn, rewind_tick: int = -1, hit_allies: bool = false, penetrate: bool = false) -> HitscanResult:
	var res := HitscanResult.new()
	var team := shooter.team if shooter else -1
	var w := raycast_world(from, dir, max_dist, team, true)
	var wdist: float = w.get("distance", INF)
	var best: HitboxSet.HitResult = null
	var rt := rewind_tick
	if rt >= 0 and (tick - rt) > RF.HISTORY_TICKS - 2:
		rt = tick - RF.HISTORY_TICKS + 2
	if rt > tick:
		rt = tick
	for p: Pawn in pawns.values():
		if p == shooter or not p.alive:
			continue
		if not hit_allies and shooter and p.team == shooter.team:
			continue
		if p.status.invisible and shooter and p.team != shooter.team:
			pass  # invisible pawns can still be hit by blind fire
		var r := p.hitboxes.raycast(from, dir, minf(max_dist, wdist), rt)
		if r.hit and (best == null or r.distance < best.distance):
			best = r
	if best != null:
		res.hit = true; res.pawn = best.pawn; res.part = best.part
		res.point = best.point; res.normal = best.normal; res.distance = best.distance
		return res
	if wdist < INF:
		res.hit = true; res.point = w["point"]; res.normal = w["normal"]; res.distance = wdist
		res.barrier = w.get("barrier", null)
		res.deployable = w.get("deployable", null)
		return res
	res.point = from + dir * max_dist
	res.normal = -dir
	res.distance = max_dist
	return res


func has_line_of_sight(from: Vector3, to: Vector3, mask: int = RF.L_WORLD) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return space().intersect_ray(q).is_empty()


## LOS from a pawn's eyes to another pawn's body (any of head/center/feet visible counts).
func pawn_visible_from(eye: Vector3, target: Pawn, mask: int = RF.L_WORLD | RF.L_DEPLOYABLE) -> bool:
	var pts := [target.center(), target.eye_position(), target.global_position + Vector3(0, 0.3, 0)]
	for pt: Vector3 in pts:
		if has_line_of_sight(eye, pt, mask):
			return true
	return false


func ground_point(from: Vector3, max_down: float = 50.0) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from + Vector3(0, 0.1, 0), from + Vector3(0, -max_down, 0), RF.L_WORLD | RF.L_DEPLOYABLE)
	var hit := space().intersect_ray(q)
	return hit["position"] if not hit.is_empty() else from


## --- Damage / heal entry points --------------------------------------------------------------

func apply_damage(ev: DamageEvent) -> void:
	if not is_server:
		return
	ev.tick = tick
	DamagePipeline.resolve_damage(ev, self)
	if not ev.prevented and ev.target and ev.source and ev.source != ev.target:
		ev.target.note_damager(ev.source)


func apply_heal(source: Pawn, target: Pawn, amount: float, ability_id: StringName = &"") -> float:
	if not is_server:
		return 0.0
	return DamagePipeline.resolve_heal(source, target, amount, ability_id, self)


func kill_pawn(victim: Pawn, killer: Pawn, ev: DamageEvent) -> void:
	if not victim.alive:
		return
	victim.die(killer)
	victim.stats.deaths += 1
	# Credit: final blow + assists (anyone who damaged within 5 s), solo kill if no assists.
	var assists: Array[int] = []
	var window := int(5.0 / RF.TICK_DT)
	for nid: int in victim.recent_damagers.keys():
		var t: int = victim.recent_damagers[nid]
		if tick - t <= window:
			var p := get_pawn(nid)
			if p and p != killer and p.team != victim.team:
				assists.append(nid)
				p.stats.assists += 1
				p.stats.kills += 1
	# Healers who healed the killer recently get assists too (handled by conduits' HoT tracking later).
	if killer and killer != victim:
		killer.stats.kills += 1
		killer.stats.final_blows += 1
		killer.kill_streak += 1
		killer.stats.best_streak = maxi(killer.stats.best_streak, killer.kill_streak)
		if assists.is_empty():
			killer.stats.solo_kills += 1
		if victim.on_objective:
			killer.stats.objective_kills += 1
		if killer.hero.role == RF.Role.STRIKER:
			killer.movement.speed_override_mult = 1.0 + tuning.striker_speed_bonus_on_elim
			killer.movement.speed_override_timer = tuning.striker_speed_bonus_time
		if killer.behavior:
			killer.behavior.on_kill(victim)
		killer.add_ult_charge(tuning.ult_charge_kill_bonus)
	sim_event.emit(&"kill", {
		"victim": victim.net_id, "killer": killer.net_id if killer else -1,
		"ability": ev.ability_id if ev else &"", "headshot": ev.headshot if ev else false,
		"assists": assists, "pos": victim.global_position, "critical": ev.critical if ev else false,
	})
	on_pawn_sound(victim, &"death", 14.0)


## --- Projectiles & deployables -----------------------------------------------------------------

func spawn_projectile(pr: Projectile, pos: Vector3, velocity: Vector3) -> Projectile:
	pr.id = next_id()
	pr.world = self
	pr.vel = velocity
	pr.predicted = not is_server
	add_child(pr)
	pr.global_position = pos
	pr.start_pos = pos
	projectiles[pr.id] = pr
	sim_event.emit(&"projectile_spawn", {"id": pr.id, "pos": pos, "vel": velocity, "visual": pr.visual_id,
		"owner": pr.owner_pawn.net_id if pr.owner_pawn else -1, "gravity": pr.gravity, "radius": pr.radius,
		"lifetime": pr.lifetime, "bounces": pr.bounces, "homing": pr.homing_strength > 0.0, "team": pr.team})
	return pr


func unregister_projectile(pr: Projectile) -> void:
	projectiles.erase(pr.id)


func spawn_deployable(d: Deployable, pos: Vector3, facing: Vector3) -> Deployable:
	d.id = next_id()
	d.world = self
	d.predicted = not is_server
	d.facing = facing
	add_child(d)
	d.global_position = pos
	if facing.length_squared() > 0.001:
		var f := Vector3(facing.x, 0, facing.z).normalized()
		if f.length_squared() > 0.001:
			d.look_at(pos + f, Vector3.UP)
	deployables[d.id] = d
	if d.has_method("on_placed"):
		d.call("on_placed")
	sim_event.emit(&"deployable_spawn", {"id": d.id, "kind": d.kind, "pos": pos, "facing": facing,
		"owner": d.owner_pawn.net_id if d.owner_pawn else -1, "team": d.team, "hp": d.health, "max_hp": d.max_health,
		"visual": d.visual_id, "data": d.data})
	return d


func unregister_deployable(d: Deployable) -> void:
	deployables.erase(d.id)


func deployables_of(owner_p: Pawn, kind: StringName = &"") -> Array[Deployable]:
	var out: Array[Deployable] = []
	for d: Deployable in deployables.values():
		if d.owner_pawn == owner_p and (kind == &"" or d.kind == kind):
			out.append(d)
	return out


## --- Simulation step (server) ---------------------------------------------------------------

func step_entities(dt: float) -> void:
	for pr: Projectile in projectiles.values().duplicate():
		if is_instance_valid(pr):
			pr.step(dt)
	for d: Deployable in deployables.values().duplicate():
		if is_instance_valid(d):
			d.step(dt)
	for pk: Variant in pickups:
		if is_instance_valid(pk):
			pk.step(dt)


## --- Hooks (turned into events) ------------------------------------------------------------

func on_damage(ev: DamageEvent) -> void:
	sim_event.emit(&"damage", {"src": ev.source.net_id if ev.source else -1, "tgt": ev.target.net_id,
		"amt": ev.dealt, "hs": ev.headshot, "killed": ev.killed, "pos": ev.position, "type": ev.type,
		"ability": ev.ability_id, "crit": ev.critical, "dir": ev.direction})
	on_pawn_sound(ev.target, &"hurt", 6.0)


func on_damage_prevented(ev: DamageEvent) -> void:
	sim_event.emit(&"damage_prevented", {"src": ev.source.net_id if ev.source else -1, "tgt": ev.target.net_id, "pos": ev.position, "reason": ev.prevented_reason})


func on_heal(source: Pawn, target: Pawn, amount: float, ability_id: StringName) -> void:
	sim_event.emit(&"heal", {"src": source.net_id if source else -1, "tgt": target.net_id, "amt": amount, "ability": ability_id, "pos": target.center()})


func on_heal_prevented(source: Pawn, target: Pawn) -> void:
	sim_event.emit(&"heal_prevented", {"src": source.net_id if source else -1, "tgt": target.net_id})


func on_status_applied(p: Pawn, inst: StatusInstance) -> void:
	sim_event.emit(&"status", {"tgt": p.net_id, "id": inst.data.id, "on": true, "dur": inst.remaining, "src": inst.source.net_id if inst.source else -1})


func on_status_removed(p: Pawn, inst: StatusInstance) -> void:
	sim_event.emit(&"status", {"tgt": p.net_id, "id": inst.data.id, "on": false, "dur": 0.0, "src": -1})


func on_ability_activated(p: Pawn, ab: Ability, ctx: AbilityContext) -> void:
	sim_event.emit(&"ability", {"pawn": p.net_id, "slot": ab.slot, "phase": &"activate", "id": ab.data.id,
		"pos": p.global_position, "dir": ctx.aim_dir, "seed": ctx.seed, "ult": ab.data.is_ultimate()})
	if ab.data.is_ultimate():
		on_pawn_sound(p, &"ultimate", 40.0)


func on_ability_fired(p: Pawn, ab: Ability, ctx: AbilityContext) -> void:
	sim_event.emit(&"ability", {"pawn": p.net_id, "slot": ab.slot, "phase": &"fire", "id": ab.data.id,
		"pos": ctx.aim_origin, "dir": ctx.aim_dir, "seed": ctx.seed, "ult": ab.data.is_ultimate()})
	var loud := 22.0 if ab.data.is_weapon else 16.0
	if ab.data.trigger == AbilityData.Trigger.HOLD:
		loud = 20.0
	on_pawn_sound(p, &"gunfire" if ab.data.is_weapon else &"ability", loud)


func on_ability_ended(p: Pawn, ab: Ability, cancelled: bool) -> void:
	sim_event.emit(&"ability", {"pawn": p.net_id, "slot": ab.slot, "phase": &"end", "id": ab.data.id, "cancelled": cancelled, "pos": p.global_position, "dir": Vector3.ZERO, "seed": 0, "ult": ab.data.is_ultimate()})


func on_reload_started(p: Pawn, ab: Ability) -> void:
	sim_event.emit(&"reload", {"pawn": p.net_id, "slot": ab.slot, "time": ab.data.reload_time})
	on_pawn_sound(p, &"reload", 7.0)


func on_ult_ready(p: Pawn) -> void:
	sim_event.emit(&"ult_ready", {"pawn": p.net_id})


func on_pawn_sound(p: Pawn, kind: StringName, loudness: float) -> void:
	for cb: Callable in sound_listeners:
		cb.call(p, kind, loudness, p.global_position)
	if kind != &"footstep" and kind != &"hurt":
		sim_event.emit(&"sound", {"pawn": p.net_id, "kind": kind, "pos": p.global_position})
	elif kind == &"footstep":
		sim_event.emit(&"footstep", {"pawn": p.net_id, "pos": p.global_position})


func on_projectile_impact(pr: Projectile, point: Vector3, normal: Vector3, target: Pawn) -> void:
	sim_event.emit(&"projectile_impact", {"id": pr.id, "pos": point, "normal": normal, "tgt": target.net_id if target else -1, "visual": pr.visual_id, "splash": pr.splash_radius})


func on_projectile_bounce(pr: Projectile, point: Vector3, normal: Vector3) -> void:
	sim_event.emit(&"projectile_bounce", {"id": pr.id, "pos": point, "normal": normal, "vel": pr.vel})


func on_projectile_stuck(pr: Projectile, point: Vector3, normal: Vector3) -> void:
	sim_event.emit(&"projectile_stuck", {"id": pr.id, "pos": point, "normal": normal, "to": pr.stuck_to.get("net_id") if pr.stuck_to and pr.stuck_to is Pawn else -1})


func on_projectile_expired(pr: Projectile) -> void:
	sim_event.emit(&"projectile_expire", {"id": pr.id, "pos": pr.global_position, "visual": pr.visual_id})


func on_deployable_damaged(d: Deployable, amount: float, source: Pawn) -> void:
	sim_event.emit(&"deployable_hp", {"id": d.id, "hp": d.health, "amt": amount, "src": source.net_id if source else -1})


func on_deployable_destroyed(d: Deployable, by: Pawn) -> void:
	sim_event.emit(&"deployable_destroy", {"id": d.id, "pos": d.global_position, "kind": d.kind, "by": by.net_id if by else -1})


func emit_custom(kind: StringName, payload: Dictionary) -> void:
	sim_event.emit(kind, payload)
