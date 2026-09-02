class_name DamageNumbers
extends Node
## Floating damage/heal numbers (Label3D, pooled). Consecutive hits on the same spot accumulate.

var world: SimWorld
var pool: Array[Label3D] = []
var active: Array = []   # [label, t, vel, accum, pos]
var last_label: Label3D
var last_time: float = 0.0
var time: float = 0.0


func set_world(w: SimWorld) -> void:
	world = w
	for l: Label3D in pool:
		l.queue_free()
	pool.clear()
	active.clear()


func _acquire() -> Label3D:
	for l: Label3D in pool:
		if not l.visible:
			return l
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font_size = 44
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.layers = 1 << 3
	world.add_child(l)
	pool.append(l)
	return l


func show_damage(pos: Vector3, amount: float, headshot: bool, crit: bool) -> void:
	if world == null or not bool(Settings.get_value(&"accessibility", "damage_numbers")):
		return
	# Accumulate rapid hits (beams/shotguns) into one rising number.
	if last_label and last_label.visible and time - last_time < 0.25:
		for a: Array in active:
			if a[0] == last_label:
				a[3] = float(a[3]) + amount
				a[1] = 0.0
				last_label.text = str(int(round(float(a[3]))))
				last_label.global_position = pos + Vector3(0, 0.3, 0)
				last_time = time
				if headshot:
					last_label.modulate = Color(1.0, 0.85, 0.3)
				return
	var l := _acquire()
	l.text = str(int(round(amount)))
	l.modulate = Color(1.0, 0.85, 0.3) if headshot else (Color(1.0, 0.5, 0.35) if crit else Color(1, 1, 1))
	l.font_size = 52 if headshot or crit else 44
	l.global_position = pos + Vector3(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	l.visible = true
	active.append([l, 0.0, Vector3(randf_range(-0.3, 0.3), 1.6, 0), amount, pos])
	last_label = l
	last_time = time


func show_heal(pos: Vector3, amount: float) -> void:
	if world == null or not bool(Settings.get_value(&"accessibility", "damage_numbers")):
		return
	var l := _acquire()
	l.text = "+" + str(int(round(amount)))
	l.modulate = Color(0.45, 1.0, 0.55)
	l.font_size = 40
	l.global_position = pos + Vector3(0, 0.4, 0)
	l.visible = true
	active.append([l, 0.0, Vector3(0, 1.2, 0), amount, pos])


func update_frame(delta: float) -> void:
	time += delta
	for i in range(active.size() - 1, -1, -1):
		var a: Array = active[i]
		a[1] = float(a[1]) + delta
		var t: float = a[1]
		var l: Label3D = a[0]
		l.global_position += (a[2] as Vector3) * delta * (1.0 - t * 0.6)
		l.modulate.a = clampf(1.4 - t * 1.4, 0.0, 1.0)
		if t >= 1.0:
			l.visible = false
			active.remove_at(i)
