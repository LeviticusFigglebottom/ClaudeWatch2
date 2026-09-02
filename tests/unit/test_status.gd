extends GutTest
## Status stacking, cleanse, and aggregate modifiers (no pawn/world needed for aggregates).


func _make(id: String, dur: float) -> StatusData:
	var s := StatusData.new()
	s.id = StringName(id)
	s.duration = dur
	return s


func test_slows_take_strongest_and_speed_buffs_max() -> void:
	var c := StatusController.new()
	var slow1 := _make("slow1", 2.0); slow1.speed_mult = 0.7; slow1.is_debuff = true
	var slow2 := _make("slow2", 2.0); slow2.speed_mult = 0.5; slow2.is_debuff = true
	var fast := _make("fast", 2.0); fast.speed_mult = 1.3
	c.apply(slow1); c.apply(slow2); c.apply(fast)
	c.step(0.0)
	assert_almost_eq(c.speed_mult, 0.5 * 1.3, 0.001)


func test_cleanse_removes_only_cleansable_debuffs() -> void:
	var c := StatusController.new()
	var d := _make("burn", 3.0); d.is_debuff = true; d.cleansable = true
	var perm := _make("mark", 3.0); perm.is_debuff = true; perm.cleansable = false
	var buff := _make("buff", 3.0); buff.is_debuff = false
	c.apply(d); c.apply(perm); c.apply(buff)
	var n := c.cleanse()
	assert_eq(n, 1)
	assert_false(c.has(&"burn"))
	assert_true(c.has(&"mark"))
	assert_true(c.has(&"buff"))


func test_refresh_and_duration_stacking() -> void:
	var c := StatusController.new()
	var r := _make("r", 2.0)
	c.apply(r)
	c.step(1.5)
	c.apply(r)
	assert_almost_eq(c.get_status(&"r").remaining, 2.0, 0.001, "refresh resets to full")
	var s := _make("s", 2.0); s.stacking = StatusData.Stacking.STACK_DURATION
	c.apply(s); c.apply(s)
	assert_almost_eq(c.get_status(&"s").remaining, 4.0, 0.001)


func test_intensity_stacks_multiply_damage_amp() -> void:
	var c := StatusController.new()
	var amp := _make("amp", 2.0); amp.stacking = StatusData.Stacking.STACK_INTENSITY; amp.max_stacks = 3; amp.damage_taken_mult = 1.1
	c.apply(amp); c.apply(amp); c.apply(amp); c.apply(amp)
	c.step(0.0)
	assert_eq(c.stacks_of(&"amp"), 3)
	assert_almost_eq(c.damage_taken_mult, 1.3, 0.001)


func test_expiry() -> void:
	var c := StatusController.new()
	var s := _make("t", 1.0)
	c.apply(s)
	c.step(0.5)
	assert_true(c.has(&"t"))
	c.step(0.6)
	assert_false(c.has(&"t"))


func test_step_survives_reentrant_clear_all() -> void:
	# A DoT tick that kills the pawn clears the status list from inside step(); the loop must not
	# index into the emptied array (this used to throw "Out of bounds get index").
	var c := StatusController.new()
	var burn := _make("burn", 3.0); burn.dot_dps = 10.0
	var other := _make("other", 3.0)
	c.apply(burn); c.apply(other)
	c.step(0.1)
	assert_eq(c.active.size(), 2, "both statuses survive a normal tick")
	# Simulate the re-entrant clear that death performs mid-iteration.
	c.clear_all()
	c.step(0.1)
	assert_eq(c.active.size(), 0, "stepping an emptied controller is safe")


func test_expiry_removes_correct_instance() -> void:
	var c := StatusController.new()
	var short_s := _make("short", 0.5)
	var long_s := _make("long", 5.0)
	c.apply(short_s); c.apply(long_s)
	c.step(1.0)
	assert_false(c.has(&"short"), "expired status is gone")
	assert_true(c.has(&"long"), "the other status is untouched")
