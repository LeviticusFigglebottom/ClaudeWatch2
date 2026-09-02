extends GutTest
## Health layer math: order of consumption, armor rule, regen.

var tuning: GlobalTuning


func before_each() -> void:
	tuning = GlobalTuning.new()


func _ev(amount: float) -> DamageEvent:
	var ev := DamageEvent.new()
	ev.amount = amount
	return ev


func test_layers_consumed_in_order() -> void:
	var h := HealthComponent.new()
	h.setup(200, 50, 50)
	h.grant_overhealth(30, 30)
	var ev := _ev(60)
	h.take(ev, tuning)
	assert_eq(h.overhealth, 0.0, "overhealth first")
	assert_eq(h.shield, 20.0, "then shield")
	assert_eq(h.armor, 50.0, "armor untouched")
	assert_eq(h.health, 200.0, "health untouched")


func test_armor_flat_reduction() -> void:
	var h := HealthComponent.new()
	h.setup(200, 100, 0)
	var ev := _ev(20)
	h.take(ev, tuning)
	assert_almost_eq(h.armor, 85.0, 0.01, "20 dmg into armor loses 5")
	var h2 := HealthComponent.new()
	h2.setup(200, 100, 0)
	h2.take(_ev(6), tuning)
	assert_almost_eq(h2.armor, 97.0, 0.01, "small hits are halved")


func test_overkill_and_kill_flag() -> void:
	var h := HealthComponent.new()
	h.setup(100, 0, 0)
	var ev := _ev(150)
	h.take(ev, tuning)
	assert_true(ev.killed)
	assert_almost_eq(ev.overkill, 50.0, 0.01)
	assert_almost_eq(ev.dealt, 100.0, 0.01)


func test_shield_regen_after_delay() -> void:
	var h := HealthComponent.new()
	h.setup(100, 0, 100)
	h.take(_ev(40), tuning)
	h.last_damage_tick = 0
	h.tick_regen(int(1.0 / RF.TICK_DT), 1.0, tuning, RF.Role.STRIKER)
	assert_eq(h.shield, 60.0, "no regen before delay")
	h.tick_regen(int(4.0 / RF.TICK_DT), 1.0, tuning, RF.Role.STRIKER)
	assert_almost_eq(h.shield, 90.0, 0.01, "regen 30/s after 3 s")


func test_heal_fills_health_then_armor() -> void:
	var h := HealthComponent.new()
	h.setup(100, 50, 0)
	h.take(_ev(120), tuning)
	var healed := h.heal(80)
	assert_almost_eq(healed, 80.0, 0.01)
	assert_true(h.health > 0.0)
