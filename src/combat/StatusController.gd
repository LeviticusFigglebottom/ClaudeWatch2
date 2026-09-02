class_name StatusController
extends RefCounted
## Holds active statuses on a pawn and exposes aggregated modifiers.
## Aggregation is recomputed when the set changes; per-tick DoT/HoT batch at 10 Hz for readable numbers.

var pawn: Pawn
var active: Array[StatusInstance] = []
var _dirty: bool = true

# Aggregates
var speed_mult: float = 1.0
var damage_dealt_mult: float = 1.0
var damage_taken_mult: float = 1.0
var healing_received_mult: float = 1.0
var healing_dealt_mult: float = 1.0
var gravity_mult: float = 1.0
var jump_mult: float = 1.0
var cooldown_rate_mult: float = 1.0
var ult_charge_mult: float = 1.0
var fire_rate_mult: float = 1.0
var min_health_one: bool = false
var rooted: bool = false
var stunned: bool = false
var silenced: bool = false
var disarmed: bool = false
var invulnerable: bool = false
var unstoppable: bool = false
var revealed: bool = false
var invisible: bool = false
var anti_heal: bool = false
var suppress_regen: bool = false
var grounded_lock: bool = false
var airborne: bool = false

const DOT_BATCH := 0.1


func setup(p: Pawn) -> void:
	pawn = p


func has(id: StringName) -> bool:
	for s: StatusInstance in active:
		if s.data.id == id:
			return true
	return false


func get_status(id: StringName) -> StatusInstance:
	for s: StatusInstance in active:
		if s.data.id == id:
			return s
	return null


func stacks_of(id: StringName) -> int:
	var s := get_status(id)
	return s.stacks if s else 0


func apply(data: StatusData, source: Pawn = null, duration_override: float = -1.0) -> StatusInstance:
	if data == null:
		return null
	var dur := data.duration if duration_override < 0.0 else duration_override
	# Immunity: unstoppable blocks CC; invulnerable blocks debuff DoTs.
	if data.is_crowd_control and unstoppable and data.is_debuff:
		return null
	# Bulwark role passive: shorter CC.
	if data.is_crowd_control and data.is_debuff and pawn and pawn.hero and pawn.hero.role == RF.Role.BULWARK and pawn.world:
		dur *= (1.0 - pawn.world.tuning.bulwark_cc_reduction)
	var existing := get_status(data.id)
	if existing:
		match data.stacking:
			StatusData.Stacking.REFRESH:
				existing.remaining = maxf(existing.remaining, dur)
				existing.source = source if source else existing.source
			StatusData.Stacking.STACK_DURATION:
				existing.remaining += dur
			StatusData.Stacking.STACK_INTENSITY:
				existing.stacks = mini(existing.stacks + 1, data.max_stacks)
				existing.remaining = maxf(existing.remaining, dur)
			StatusData.Stacking.IGNORE_IF_ACTIVE:
				return existing
		_dirty = true
		return existing
	var inst := StatusInstance.new()
	inst.data = data
	inst.remaining = dur
	inst.source = source
	inst.applied_tick = pawn.world.tick if pawn and pawn.world else 0
	active.append(inst)
	_dirty = true
	if data.overhealth_on_apply > 0.0 and pawn:
		pawn.health.grant_overhealth(data.overhealth_on_apply, maxf(data.overhealth_max, data.overhealth_on_apply))
	if pawn and pawn.world:
		pawn.world.on_status_applied(pawn, inst)
	return inst


func remove(id: StringName) -> void:
	for i in range(active.size() - 1, -1, -1):
		if active[i].data.id == id:
			var inst := active[i]
			active.remove_at(i)
			_dirty = true
			if pawn and pawn.world:
				pawn.world.on_status_removed(pawn, inst)


func cleanse() -> int:
	var n := 0
	for i in range(active.size() - 1, -1, -1):
		var s := active[i]
		if s.data.is_debuff and s.data.cleansable:
			active.remove_at(i)
			n += 1
			if pawn and pawn.world:
				pawn.world.on_status_removed(pawn, s)
	if n > 0:
		_dirty = true
	return n


func clear_all() -> void:
	active.clear()
	_dirty = true


## Ticks durations, damage-over-time and heal-over-time.
## A DoT tick can kill the pawn, and death clears `active` re-entrantly, so this iterates a
## snapshot and re-checks membership after every call that can re-enter rather than trusting
## indices into a list that may have been emptied underneath it.
func step(dt: float) -> void:
	var snapshot := active.duplicate()
	for s: StatusInstance in snapshot:
		if not active.has(s):
			continue
		s.remaining -= dt
		if s.data.dot_dps > 0.0 and pawn and pawn.world and pawn.world.is_server:
			s.accum_dot += s.data.dot_dps * s.stacks * dt
			if s.accum_dot >= s.data.dot_dps * s.stacks * DOT_BATCH or s.remaining <= 0.0:
				var ev := DamageEvent.new()
				ev.source = s.source; ev.target = pawn; ev.amount = s.accum_dot
				ev.type = s.data.dot_type; ev.ability_id = s.data.id
				ev.position = pawn.center(); ev.direction = Vector3.ZERO
				s.accum_dot = 0.0
				pawn.world.apply_damage(ev)
				if not active.has(s):
					continue
		if s.data.hot_hps > 0.0 and pawn and pawn.world and pawn.world.is_server:
			s.accum_hot += s.data.hot_hps * s.stacks * dt
			if s.accum_hot >= s.data.hot_hps * s.stacks * DOT_BATCH or s.remaining <= 0.0:
				pawn.world.apply_heal(s.source, pawn, s.accum_hot, s.data.id)
				s.accum_hot = 0.0
				if not active.has(s):
					continue
		if s.remaining <= 0.0 and s.data.duration > 0.0:
			active.erase(s)
			_dirty = true
			if pawn and pawn.world:
				pawn.world.on_status_removed(pawn, s)
	if _dirty:
		_recompute()


func _recompute() -> void:
	_dirty = false
	speed_mult = 1.0; damage_dealt_mult = 1.0; damage_taken_mult = 1.0
	healing_received_mult = 1.0; healing_dealt_mult = 1.0; gravity_mult = 1.0; jump_mult = 1.0
	cooldown_rate_mult = 1.0; ult_charge_mult = 1.0; fire_rate_mult = 1.0; min_health_one = false
	rooted = false; stunned = false; silenced = false; disarmed = false; invulnerable = false
	unstoppable = false; revealed = false; invisible = false; anti_heal = false; suppress_regen = false
	grounded_lock = false; airborne = false
	var min_speed := 1.0
	var max_speed := 1.0
	for s: StatusInstance in active:
		var d := s.data
		var k := float(s.stacks)
		# Slows stack multiplicatively but the strongest slow dominates within a class; speed buffs take the max.
		if d.speed_mult < 1.0:
			min_speed = minf(min_speed, 1.0 - (1.0 - d.speed_mult) * k)
		elif d.speed_mult > 1.0:
			max_speed = maxf(max_speed, d.speed_mult)
		damage_dealt_mult *= 1.0 + (d.damage_dealt_mult - 1.0) * k
		damage_taken_mult *= 1.0 + (d.damage_taken_mult - 1.0) * k
		healing_received_mult *= d.healing_received_mult
		healing_dealt_mult *= d.healing_dealt_mult
		gravity_mult *= d.gravity_mult
		jump_mult *= d.jump_mult
		cooldown_rate_mult *= d.cooldown_rate_mult
		ult_charge_mult *= d.ult_charge_mult
		fire_rate_mult *= d.fire_rate_mult
		min_health_one = min_health_one or d.min_health_one
		rooted = rooted or d.rooted
		stunned = stunned or d.stunned
		silenced = silenced or d.silenced
		disarmed = disarmed or d.disarmed
		invulnerable = invulnerable or d.invulnerable
		unstoppable = unstoppable or d.unstoppable
		revealed = revealed or d.revealed
		invisible = invisible or d.invisible
		anti_heal = anti_heal or d.anti_heal
		suppress_regen = suppress_regen or d.suppress_regen
		grounded_lock = grounded_lock or d.grounded_lock
		airborne = airborne or d.airborne
	speed_mult = clampf(min_speed * max_speed, 0.0, 3.0)
	if pawn:
		pawn.health.suppress_regen = suppress_regen


func mark_dirty() -> void:
	_dirty = true


func can_move() -> bool:
	return not stunned and not rooted


func can_use_abilities() -> bool:
	return not stunned and not silenced


func can_use_weapons() -> bool:
	return not stunned and not disarmed


func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StatusInstance in active:
		out.append(s.data.id)
	return out
