class_name HealthComponent
extends RefCounted
## Layered health: overhealth -> shield -> armor -> health. Pure logic, no nodes.

var max_health: float = 200.0
var max_armor: float = 0.0
var max_shield: float = 0.0
var health: float = 200.0
var armor: float = 0.0
var shield: float = 0.0
var overhealth: float = 0.0
var overhealth_max: float = 0.0
var last_damage_tick: int = -100000
var last_heal_tick: int = -100000
var suppress_regen: bool = false

# Extra armor/shield granted temporarily (e.g. Ballast's Surge) stack on top of base maxima.
var bonus_armor: float = 0.0
var bonus_shield: float = 0.0


func setup(hp: float, ar: float, sh: float) -> void:
	max_health = hp; max_armor = ar; max_shield = sh
	health = hp; armor = ar; shield = sh
	overhealth = 0.0; overhealth_max = 0.0
	bonus_armor = 0.0; bonus_shield = 0.0


func total() -> float:
	return health + armor + shield + overhealth


func total_max() -> float:
	return max_health + max_armor + bonus_armor + max_shield + bonus_shield


func fraction() -> float:
	var m := total_max()
	return 0.0 if m <= 0.0 else clampf((health + armor + shield) / m, 0.0, 1.0)


func is_dead() -> bool:
	return health <= 0.0


func missing() -> float:
	return total_max() - (health + armor + shield)


## Applies damage across layers. Returns actual damage dealt; fills ev absorption fields.
func take(ev: DamageEvent, tuning: GlobalTuning) -> float:
	var remaining := ev.amount
	var dealt := 0.0
	# Overhealth
	if overhealth > 0.0 and remaining > 0.0:
		var d := minf(overhealth, remaining)
		overhealth -= d; remaining -= d; dealt += d
		ev.absorbed_by_overhealth = d
	# Shield
	if shield > 0.0 and remaining > 0.0:
		var d := minf(shield, remaining)
		shield -= d; remaining -= d; dealt += d
		ev.absorbed_by_shield = d
	# Armor (flat reduction on the armored portion)
	if armor > 0.0 and remaining > 0.0:
		var reduced := remaining
		if not ev.ignore_armor:
			var cut := minf(tuning.armor_flat_reduction, remaining * (1.0 - tuning.armor_min_fraction))
			reduced = remaining - cut
		var d := minf(armor, reduced)
		armor -= d
		# Whatever armor absorbed counts as "reduced" damage consumed proportionally from the request.
		var consumed := remaining if d >= reduced else remaining * (d / maxf(reduced, 0.0001))
		remaining -= consumed
		dealt += d
		ev.absorbed_by_armor = d
	# Health
	if remaining > 0.0:
		var d := minf(health, remaining)
		health -= d; remaining -= d; dealt += d
		ev.overkill = remaining
	ev.dealt = dealt
	ev.killed = health <= 0.0
	return dealt


## Heals health first, then armor, then shield (shields normally regen on their own).
func heal(amount: float) -> float:
	var healed := 0.0
	var room := max_health - health
	var d := minf(room, amount)
	health += d; healed += d; amount -= d
	if amount > 0.0:
		room = (max_armor + bonus_armor) - armor
		d = minf(maxf(room, 0.0), amount)
		armor += d; healed += d; amount -= d
	if amount > 0.0:
		room = (max_shield + bonus_shield) - shield
		d = minf(maxf(room, 0.0), amount)
		shield += d; healed += d; amount -= d
	return healed


func grant_overhealth(amount: float, cap: float) -> void:
	overhealth_max = maxf(overhealth_max, cap)
	overhealth = minf(overhealth + amount, overhealth_max)


func grant_bonus_armor(amount: float) -> void:
	bonus_armor += amount
	armor += amount


func remove_bonus_armor(amount: float) -> void:
	bonus_armor = maxf(bonus_armor - amount, 0.0)
	armor = minf(armor, max_armor + bonus_armor)


func tick_regen(tick: int, dt: float, tuning: GlobalTuning, role: int) -> void:
	var since_damage := (tick - last_damage_tick) * RF.TICK_DT
	# Shields regen after not taking damage.
	if (max_shield + bonus_shield) > 0.0 and shield < (max_shield + bonus_shield) and since_damage >= tuning.shield_regen_delay:
		shield = minf(shield + tuning.shield_regen_rate * dt, max_shield + bonus_shield)
	# Overhealth decays.
	if overhealth > 0.0 and since_damage >= tuning.overhealth_decay_delay:
		overhealth = maxf(overhealth - tuning.overhealth_decay_rate * dt, 0.0)
		if overhealth <= 0.0:
			overhealth_max = 0.0
	# Role passive regen (everyone regens a little out of combat; conduits faster).
	if suppress_regen:
		return
	var delay := tuning.role_passive_regen_delay
	var rate := tuning.role_passive_regen_rate
	if role == RF.Role.CONDUIT:
		delay = tuning.conduit_regen_delay
		rate = tuning.conduit_regen_rate
	if since_damage >= delay and health < max_health:
		health = minf(health + rate * dt, max_health)


func reset_full() -> void:
	health = max_health; armor = max_armor + bonus_armor; shield = max_shield + bonus_shield
	overhealth = 0.0; overhealth_max = 0.0
