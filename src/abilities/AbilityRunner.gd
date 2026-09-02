class_name AbilityRunner
extends RefCounted
## Owns the pawn's ability slots and routes input to them each tick.

var pawn: Pawn
var slots: Array[Ability] = []
var global_lock_remaining: float = 0.0
var melee: Ability
var next_seed: int = 1


func setup(p: Pawn, hero: HeroData) -> void:
	pawn = p
	slots.clear()
	slots.resize(RF.SLOT_COUNT)
	for s in range(RF.SLOT_COUNT):
		var d: AbilityData = null
		if s == RF.Slot.MELEE:
			d = pawn.world.melee_ability
		else:
			d = hero.slot_ability(s)
		if d == null:
			slots[s] = null
			continue
		var ab := Ability.new()
		ab.setup(d, s, p, self)
		slots[s] = ab


func get_slot(s: int) -> Ability:
	return slots[s] if s >= 0 and s < slots.size() else null


func primary_blocked() -> bool:
	for ab: Ability in slots:
		if ab and ab.is_active() and ab.data.blocks_primary_while_active:
			return true
	return false


func any_active() -> bool:
	for ab: Ability in slots:
		if ab and ab.is_active():
			return true
	return false


func active_ability() -> Ability:
	for ab: Ability in slots:
		if ab and ab.is_active():
			return ab
	return null


func cancel_all(except: Ability = null) -> void:
	for ab: Ability in slots:
		if ab and ab != except and ab.is_active():
			ab.end(true)


func step(cmd: InputCmd, dt: float, is_server: bool, is_predicted: bool) -> void:
	if global_lock_remaining > 0.0:
		global_lock_remaining -= dt
	var factory := func() -> AbilityContext:
		return make_context(cmd, is_server, is_predicted)
	# Step state machines first so cooldowns finishing this tick can be used this tick.
	for ab: Ability in slots:
		if ab:
			ab.step(cmd, dt, factory)
	if not pawn.alive:
		return
	# Reload
	if cmd.just_pressed(RF.BTN_RELOAD):
		var p := slots[RF.Slot.PRIMARY]
		if p and p.uses_ammo():
			p.reload()
	# Route buttons. Ultimate and abilities are checked before weapons so a press on the same
	# tick prefers the more deliberate action.
	var order := [RF.Slot.ULTIMATE, RF.Slot.ABILITY_1, RF.Slot.ABILITY_2, RF.Slot.ABILITY_3, RF.Slot.MELEE, RF.Slot.SECONDARY, RF.Slot.PRIMARY]
	for s: int in order:
		var ab := slots[s]
		if ab == null:
			continue
		var btn: int = RF.SLOT_BUTTONS[s]
		ab.handle_input(cmd.has(btn), cmd.just_pressed(btn), cmd.just_released(btn), factory)


func make_context(cmd: InputCmd, is_server: bool, is_predicted: bool) -> AbilityContext:
	var ctx := AbilityContext.new()
	ctx.pawn = pawn
	ctx.world = pawn.world
	ctx.tick = pawn.world.tick
	ctx.is_server = is_server
	ctx.is_predicted = is_predicted
	ctx.aim_origin = pawn.eye_position()
	ctx.view_yaw = pawn.yaw
	ctx.view_pitch = pawn.pitch
	ctx.aim_dir = pawn.aim_dir()
	ctx.rewind_tick = cmd.render_tick
	ctx.seed = hash(Vector3i(pawn.net_id, cmd.tick, next_seed))
	next_seed += 1
	return ctx


func reset_for_spawn() -> void:
	global_lock_remaining = 0.0
	for ab: Ability in slots:
		if ab:
			ab.reset_for_spawn()
