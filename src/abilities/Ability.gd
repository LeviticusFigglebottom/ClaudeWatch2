class_name Ability
extends RefCounted
## Runtime state of one ability slot on a pawn. Drives the cast -> fire -> active -> recover lifecycle
## and executes the composed AbilityEffects. Same code runs on the server and the predicting client.

enum State { IDLE, CASTING, ACTIVE, RECOVERING }

var data: AbilityData
var slot: int
var pawn: Pawn
var runner: AbilityRunner
var behavior: AbilityBehavior

var state: State = State.IDLE
var cooldown_remaining: float = 0.0
var charges_left: int = 1
var ammo: int = 0
var reload_remaining: float = 0.0
var cast_remaining: float = 0.0
var active_remaining: float = 0.0
var recovery_remaining: float = 0.0
var fire_interval_remaining: float = 0.0
var burst_left: int = 0
var burst_timer: float = 0.0
var tick_accum: float = 0.0
var held: bool = false
var activation_seed: int = 0
var uses: int = 0
var delayed: Array = []          # [remaining_time, effect, ctx]
var active_ctx: AbilityContext
var toggled_on: bool = false
var charge: float = 0.0          # for hold-to-charge behaviors
var last_fire_tick: int = -1000
var self_status: StatusInstance


func setup(d: AbilityData, s: int, p: Pawn, r: AbilityRunner) -> void:
	data = d; slot = s; pawn = p; runner = r
	charges_left = maxi(d.charges, 1)
	ammo = d.ammo
	if d.behavior != null:
		behavior = d.behavior.new() as AbilityBehavior
		if behavior:
			behavior.setup(self, p)


func is_active() -> bool:
	return state == State.ACTIVE or state == State.CASTING


func is_ready() -> bool:
	if state != State.IDLE:
		return false
	if data.resource == AbilityData.Cost.ULTIMATE:
		return pawn.ult_charge >= data.ult_cost
	if data.resource == AbilityData.Cost.AMMO and reload_remaining > 0.0:
		return false
	if data.charges > 1:
		return charges_left > 0
	return cooldown_remaining <= 0.0


func cooldown_fraction() -> float:
	var cd := data.effective_cooldown()
	if data.charges > 1 and charges_left > 0:
		return 0.0
	return 0.0 if cd <= 0.0 else clampf(cooldown_remaining / cd, 0.0, 1.0)


func uses_ammo() -> bool:
	return data.resource == AbilityData.Cost.AMMO and data.ammo > 0


func ammo_pool() -> Ability:
	if data.shares_ammo_with_primary and slot != RF.Slot.PRIMARY:
		return runner.slots[RF.Slot.PRIMARY]
	return self


func can_activate(ctx: AbilityContext) -> bool:
	if not pawn.alive:
		return false
	if not is_ready():
		return false
	var st := pawn.status
	if st.stunned and not data.usable_while_stunned:
		return false
	if st.silenced and not data.usable_while_silenced and not data.is_weapon:
		return false
	if st.disarmed and data.is_weapon:
		return false
	if data.requires_ground and not pawn.is_on_floor():
		return false
	if not data.allow_airborne and not pawn.is_on_floor():
		return false
	if runner.global_lock_remaining > 0.0 and not data.interruptible_by_other_abilities:
		return false
	if runner.primary_blocked() and data.is_weapon:
		return false
	if uses_ammo():
		var pool := ammo_pool()
		if pool.ammo < data.ammo_per_use:
			return false
	if data.resource == AbilityData.Cost.HERO_RESOURCE and pawn.hero_resource < data.hero_resource_cost:
		return false
	if behavior and not behavior.can_activate(ctx):
		return false
	return true


func activate(ctx: AbilityContext) -> bool:
	if not can_activate(ctx):
		return false
	activation_seed = ctx.seed
	uses += 1
	active_ctx = ctx
	# Pay costs up front (ult/hero resource); ammo is paid per shot in fire().
	if data.resource == AbilityData.Cost.ULTIMATE and ctx.is_server:
		pawn.ult_charge = 0.0
		pawn.stats.ults_used += 1
	elif data.resource == AbilityData.Cost.ULTIMATE:
		pawn.ult_charge = 0.0
	if data.resource == AbilityData.Cost.HERO_RESOURCE:
		pawn.hero_resource -= data.hero_resource_cost
	if data.charges > 1:
		charges_left -= 1
	if data.lock_movement:
		pawn.movement.move_lock_timer = maxf(data.cast_time + data.active_duration, 0.05)
	if data.movement_override:
		pawn.movement.set_profile_override(data.movement_override)
	if data.self_status_while_active:
		self_status = pawn.status.apply(data.self_status_while_active, pawn, maxf(data.active_duration + data.cast_time, 0.1))
	if behavior:
		behavior.on_activate(ctx)
	pawn.world.on_ability_activated(pawn, self, ctx)
	if data.trigger == AbilityData.Trigger.TOGGLE:
		toggled_on = true
	if data.cast_time > 0.0:
		state = State.CASTING
		cast_remaining = data.cast_time
	else:
		_fire(ctx)
	return true


func _fire(ctx: AbilityContext) -> void:
	last_fire_tick = ctx.tick
	if uses_ammo():
		var pool := ammo_pool()
		pool.ammo = maxi(pool.ammo - data.ammo_per_use, 0)
	if behavior:
		behavior.on_fire(ctx)
	burst_left = maxi(data.burst_count, 1)
	burst_timer = 0.0
	_fire_burst_shot(ctx)
	if data.active_duration > 0.0 or data.trigger == AbilityData.Trigger.CHANNEL or data.trigger == AbilityData.Trigger.TOGGLE:
		state = State.ACTIVE
		active_remaining = data.active_duration if data.active_duration > 0.0 else INF
		tick_accum = 0.0
		if not data.cooldown_starts_on_end:
			_start_cooldown()
	else:
		_start_cooldown()
		if data.recovery > 0.0:
			state = State.RECOVERING
			recovery_remaining = data.recovery
			runner.global_lock_remaining = maxf(runner.global_lock_remaining, data.recovery)
		else:
			state = State.IDLE
	pawn.world.on_ability_fired(pawn, self, ctx)


func _fire_burst_shot(ctx: AbilityContext) -> void:
	ctx.shot_index = maxi(data.burst_count, 1) - burst_left
	for e: AbilityEffect in data.effects:
		if e == null or not e.enabled:
			continue
		if e.delay > 0.0:
			delayed.append([e.delay, e, ctx])
		else:
			_run_effect(e, ctx)
	burst_left -= 1


func _run_effect(e: AbilityEffect, ctx: AbilityContext) -> void:
	if ctx.is_server:
		e.apply(ctx)
	else:
		e.predict(ctx)


func _start_cooldown() -> void:
	var cd := data.effective_cooldown()
	if data.charges > 1:
		if cooldown_remaining <= 0.0:
			cooldown_remaining = cd
	elif data.trigger == AbilityData.Trigger.HOLD and data.fire_rate > 0.0:
		fire_interval_remaining = cd
	else:
		cooldown_remaining = cd


func end(cancelled: bool = false) -> void:
	if state != State.ACTIVE and state != State.CASTING:
		return
	var was_casting := state == State.CASTING
	state = State.IDLE
	toggled_on = false
	if data.movement_override:
		pawn.movement.set_profile_override(null)
	if data.self_status_while_active:
		pawn.status.remove(data.self_status_while_active.id)
	if not was_casting:
		for e: AbilityEffect in data.end_effects:
			if e and e.enabled and active_ctx:
				_run_effect(e, active_ctx)
	if behavior and active_ctx:
		behavior.on_end(active_ctx, cancelled)
	if data.cooldown_starts_on_end or was_casting and cancelled:
		if not (was_casting and cancelled and data.charges <= 1):
			_start_cooldown()
		if was_casting and cancelled:
			cooldown_remaining = minf(cooldown_remaining, 0.5)
	if data.recovery > 0.0 and not cancelled:
		state = State.RECOVERING
		recovery_remaining = data.recovery
		runner.global_lock_remaining = maxf(runner.global_lock_remaining, data.recovery)
	pawn.world.on_ability_ended(pawn, self, cancelled)


func reload() -> void:
	if not uses_ammo() or reload_remaining > 0.0 or ammo >= data.ammo:
		return
	if state == State.ACTIVE and data.trigger == AbilityData.Trigger.CHANNEL:
		end(true)
	reload_remaining = data.reload_time
	pawn.world.on_reload_started(pawn, self)


func step(cmd: InputCmd, dt: float, ctx_factory: Callable) -> void:
	var st := pawn.status
	var rate := st.cooldown_rate_mult
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - dt * rate, 0.0)
		if data.charges > 1 and cooldown_remaining <= 0.0 and charges_left < data.charges:
			charges_left += 1
			if charges_left < data.charges:
				cooldown_remaining = data.effective_cooldown()
	if fire_interval_remaining > 0.0:
		fire_interval_remaining -= dt
	if reload_remaining > 0.0:
		reload_remaining -= dt
		if reload_remaining <= 0.0:
			reload_remaining = 0.0
			ammo = data.ammo
	# Delayed effects
	for i in range(delayed.size() - 1, -1, -1):
		var d: Array = delayed[i]
		d[0] = float(d[0]) - dt
		if float(d[0]) <= 0.0:
			_run_effect(d[1] as AbilityEffect, d[2] as AbilityContext)
			delayed.remove_at(i)
	# Burst continuation
	if burst_left > 0 and active_ctx:
		burst_timer -= dt
		if burst_timer <= 0.0:
			burst_timer = data.burst_interval
			_fire_burst_shot(active_ctx)

	match state:
		State.CASTING:
			if data.cancel_on_cc and (st.stunned or (st.silenced and not data.is_weapon)):
				end(true)
				return
			cast_remaining -= dt
			if cast_remaining <= 0.0:
				var ctx: AbilityContext = ctx_factory.call()
				ctx.seed = activation_seed
				active_ctx = ctx
				_fire(ctx)
		State.ACTIVE:
			if data.cancel_on_cc and st.stunned:
				end(true)
				return
			if data.cancel_on_damage and pawn.last_damage_tick == pawn.world.tick:
				end(true)
				return
			var ctx: AbilityContext = ctx_factory.call()
			ctx.seed = activation_seed
			active_ctx = ctx
			if behavior:
				behavior.on_tick(ctx, dt)
			if not data.tick_effects.is_empty():
				tick_accum += dt
				var interval := maxf(data.tick_interval, 0.0)
				if interval <= 0.0 or tick_accum >= interval:
					tick_accum = 0.0 if interval > 0.0 else tick_accum
					for e: AbilityEffect in data.tick_effects:
						if e and e.enabled:
							if ctx.is_server:
								e.tick(ctx, dt if interval <= 0.0 else interval)
							else:
								e.predict(ctx)
			if data.trigger == AbilityData.Trigger.CHANNEL and not held:
				end(false)
				return
			if data.trigger == AbilityData.Trigger.TOGGLE and not toggled_on:
				end(false)
				return
			active_remaining -= dt
			if active_remaining <= 0.0:
				end(false)
		State.RECOVERING:
			recovery_remaining -= dt
			if recovery_remaining <= 0.0:
				state = State.IDLE


## Called each tick with the button state for this slot.
func handle_input(down: bool, just_pressed: bool, just_released: bool, ctx_factory: Callable) -> void:
	held = down
	match data.trigger:
		AbilityData.Trigger.PRESS:
			if just_pressed:
				var ctx: AbilityContext = ctx_factory.call()
				activate(ctx)
		AbilityData.Trigger.HOLD:
			if down and fire_interval_remaining <= 0.0 and state == State.IDLE:
				var ctx: AbilityContext = ctx_factory.call()
				if activate(ctx):
					pass
				elif uses_ammo() and ammo_pool().ammo < data.ammo_per_use and just_pressed:
					ammo_pool().reload()
			elif down and uses_ammo() and ammo_pool().ammo < data.ammo_per_use and reload_remaining <= 0.0 and ammo_pool().reload_remaining <= 0.0:
				ammo_pool().reload()
		AbilityData.Trigger.CHANNEL:
			if just_pressed and state == State.IDLE:
				var ctx: AbilityContext = ctx_factory.call()
				activate(ctx)
			elif just_released and is_active():
				if behavior:
					behavior.on_button_released(active_ctx)
				end(false)
		AbilityData.Trigger.TOGGLE:
			if just_pressed:
				if is_active():
					toggled_on = false
				else:
					var ctx: AbilityContext = ctx_factory.call()
					activate(ctx)
		AbilityData.Trigger.PASSIVE:
			pass


func reset_for_spawn() -> void:
	state = State.IDLE
	cooldown_remaining = 0.0
	charges_left = maxi(data.charges, 1)
	ammo = data.ammo
	reload_remaining = 0.0
	delayed.clear()
	burst_left = 0
	toggled_on = false
	held = false
	if data.movement_override:
		pawn.movement.set_profile_override(null)
