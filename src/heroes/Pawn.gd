class_name Pawn
extends CharacterBody3D
## A hero body in the simulation. Owns health, status, abilities, movement and hitboxes.
## Runs the same code on the server (authoritative) and on the owning client (predicted).
## Presentation (meshes, sounds, first-person arms) is attached by the client layer, never here.

var net_id: int = 0
var player_id: int = 0
var team: int = RF.Team.A
var hero: HeroData
var world: SimWorld
var is_server: bool = false
var is_local: bool = false        # owned & predicted by this client
var display_name: String = "Runner"
var is_bot: bool = false

var yaw: float = 0.0
var pitch: float = 0.0
var alive: bool = false
var spawn_tick: int = -100000
var death_tick: int = -100000
var last_damage_tick: int = -100000
var last_damage_source: Pawn
var last_damage_source_tick: int = -100000
var recent_damagers: Dictionary = {}   # net_id -> tick
var kill_streak: int = 0
var ult_charge: float = 0.0
var hero_resource: float = 0.0
var last_cmd: InputCmd = InputCmd.new()
var alive_ticks: int = 0
var on_objective: bool = false
var flags_extra: int = 0              # hero-specific flags for presentation (bit field)
var anim_state: int = 0

var health: HealthComponent = HealthComponent.new()
var status: StatusController = StatusController.new()
var abilities: AbilityRunner = AbilityRunner.new()
var movement: MovementController = MovementController.new()
var hitboxes: HitboxSet = HitboxSet.new()
var behavior: HeroBehavior
var stats: PlayerStats = PlayerStats.new()


func setup(w: SimWorld, h: HeroData, t: int, nid: int, pid: int, server: bool) -> void:
	world = w
	hero = h
	team = t
	net_id = nid
	player_id = pid
	is_server = server
	name = "Pawn_%d" % nid
	collision_layer = RF.L_PAWN
	collision_mask = RF.L_WORLD | RF.L_PAWN | RF.L_DEPLOYABLE | RF.L_PAYLOAD | RF.barrier_layer(RF.enemy_team(t))
	health.setup(h.health, h.armor, h.shield)
	status.setup(self)
	movement.setup(self, h.movement if h.movement else MovementProfile.new())
	hitboxes.setup(self, h.hitbox if h.hitbox else HitboxProfile.new())
	abilities.setup(self, h)
	hero_resource = h.hero_resource_max
	if h.hero_script != null:
		behavior = h.hero_script.new() as HeroBehavior
		if behavior:
			behavior.setup(self)
	for p: StatusData in h.passives:
		status.apply(p, self, INF)
	alive = false


func eye_position() -> Vector3:
	return global_position + Vector3(0, movement.eye_height(), 0)


func center() -> Vector3:
	return global_position + Vector3(0, movement.eye_height() * 0.6, 0)


func aim_dir() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


func spawn_at(pos: Vector3, y: float) -> void:
	global_position = pos
	yaw = y
	pitch = 0.0
	velocity = Vector3.ZERO
	alive = true
	spawn_tick = world.tick
	health.reset_full()
	status.clear_all()
	for p: StatusData in hero.passives:
		status.apply(p, self, INF)
	abilities.reset_for_spawn()
	movement.external_impulse = Vector3.ZERO
	movement.crouching = false
	movement.crouch_amount = 0.0
	movement.move_lock_timer = 0.0
	kill_streak = 0
	recent_damagers.clear()
	hero_resource = hero.hero_resource_max
	alive_ticks = 0
	if behavior:
		behavior.on_spawn()
	reset_physics_interpolation()


func spawn_protected(tick: int) -> bool:
	return alive and (tick - spawn_tick) * RF.TICK_DT < world.tuning.spawn_protection_time and not _has_acted


var _has_acted: bool = false


func simulate(cmd: InputCmd, dt: float) -> void:
	last_cmd = cmd
	if alive:
		if not status.stunned and not (abilities.active_ability() != null and abilities.active_ability().data.lock_look):
			yaw = cmd.yaw
			pitch = clampf(cmd.pitch, -PI * 0.49, PI * 0.49)
		if cmd.move.length_squared() > 0.01 or (cmd.buttons & ~RF.BTN_CROUCH) != 0:
			_has_acted = true
		alive_ticks += 1
		status.step(dt)
		movement.step(cmd, dt)
		abilities.step(cmd, dt, is_server, is_local and not is_server)
		if behavior:
			behavior.on_tick(dt)
		if hero.hero_resource_max > 0.0 and hero.hero_resource_regen != 0.0:
			hero_resource = clampf(hero_resource + hero.hero_resource_regen * dt, 0.0, hero.hero_resource_max)
		if is_server:
			health.tick_regen(world.tick, dt, world.tuning, hero.role)
			add_ult_charge(world.tuning.ult_charge_passive_per_second * dt * status.ult_charge_mult)
			if ult_charge >= ult_cost():
				stats.ult_charge_time += dt
			stats.time_alive += dt
			stats.hero_time[hero.id] = float(stats.hero_time.get(hero.id, 0.0)) + dt
	else:
		# Dead: only cooldowns of nothing; keep abilities idle.
		pass
	hitboxes.record(world.tick)


func ult_cost() -> float:
	return hero.ultimate.ult_cost if hero.ultimate else 1e9


func ult_fraction() -> float:
	var c := ult_cost()
	return 0.0 if c <= 0.0 else clampf(ult_charge / c, 0.0, 1.0)


func add_ult_charge(amount: float) -> void:
	if not alive or amount <= 0.0:
		return
	var ab := abilities.get_slot(RF.Slot.ULTIMATE)
	if ab and ab.is_active():
		return   # no charge while ulting
	var before := ult_charge
	ult_charge = minf(ult_charge + amount, ult_cost())
	if before < ult_cost() and ult_charge >= ult_cost():
		world.on_ult_ready(self)


func apply_knockback(v: Vector3) -> void:
	var mult := 1.0
	if hero.role == RF.Role.BULWARK:
		mult = world.tuning.bulwark_knockback_mult
	movement.apply_impulse(v * mult)


func note_damager(src: Pawn) -> void:
	if src and src != self:
		recent_damagers[src.net_id] = world.tick


func die(killer: Pawn) -> void:
	alive = false
	death_tick = world.tick
	velocity = Vector3.ZERO
	abilities.cancel_all()
	status.clear_all()
	movement.crouching = false
	movement.crouch_amount = 0.0
	if behavior:
		behavior.on_death(killer)


func on_jumped() -> void:
	world.on_pawn_sound(self, &"jump", 8.0)


func on_landed(impact: float) -> void:
	world.on_pawn_sound(self, &"land", 10.0 if impact > 8.0 else 6.0)


func on_footstep() -> void:
	var loud := 12.0 if hero.role == RF.Role.BULWARK else 9.0
	if movement.crouching:
		loud *= 0.4
	world.on_pawn_sound(self, &"footstep", loud)


func is_enemy_of(other: Pawn) -> bool:
	return other != null and other.team != team


func hero_id() -> StringName:
	return hero.id if hero else &""
