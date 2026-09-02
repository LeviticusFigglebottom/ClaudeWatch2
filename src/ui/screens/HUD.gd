extends Control
## In-match HUD: crosshair, health layers, ability bar with cooldowns, ult meter, objective panel,
## kill feed, hitmarkers, damage direction, respawn timer, team ult status, notifications.

var crosshair: Crosshair
var health_bar: HealthLayers
var ability_bar: HBoxContainer
var ability_slots: Array = []
var ult_meter: UltMeter
var objective: ObjectivePanel
var killfeed: VBoxContainer
var hitmarker: Hitmarker
var damage_dir: DamageDirection
var center_msg: Label
var respawn_label: Label
var ammo_label: Label
var hero_label: Label
var resource_bar: ProgressBar
var status_row: HBoxContainer
var team_frames: VBoxContainer
var fps_label: Label
var _msg_timer: float = 0.0
var _scale: float = 1.0
var netstats: Label


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scale = float(Settings.get_value(&"accessibility", "hud_scale"))
	crosshair = Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	damage_dir = DamageDirection.new()
	damage_dir.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_dir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_dir)
	hitmarker = Hitmarker.new()
	hitmarker.set_anchors_preset(Control.PRESET_FULL_RECT)
	hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hitmarker)
	# Bottom-left: hero + health
	var bl := VBoxContainer.new()
	bl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bl.offset_left = 36; bl.offset_bottom = -36; bl.offset_top = -160; bl.offset_right = 420
	bl.alignment = BoxContainer.ALIGNMENT_END
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bl)
	hero_label = UITheme.label("", 20, UITheme.TEXT)
	bl.add_child(hero_label)
	health_bar = HealthLayers.new()
	health_bar.custom_minimum_size = Vector2(340, 22)
	bl.add_child(health_bar)
	resource_bar = ProgressBar.new()
	resource_bar.custom_minimum_size = Vector2(340, 8)
	resource_bar.show_percentage = false
	resource_bar.visible = false
	bl.add_child(resource_bar)
	status_row = HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 6)
	bl.add_child(status_row)
	# Bottom-center: abilities + ult
	var bc := VBoxContainer.new()
	bc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bc.offset_left = -260; bc.offset_right = 260; bc.offset_top = -150; bc.offset_bottom = -30
	bc.alignment = BoxContainer.ALIGNMENT_END
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bc)
	ult_meter = UltMeter.new()
	ult_meter.custom_minimum_size = Vector2(96, 96)
	ult_meter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bc.add_child(ult_meter)
	ability_bar = HBoxContainer.new()
	ability_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ability_bar.add_theme_constant_override("separation", 10)
	bc.add_child(ability_bar)
	# Bottom-right: ammo
	ammo_label = UITheme.label("", 40, UITheme.TEXT)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.offset_left = -300; ammo_label.offset_right = -36; ammo_label.offset_top = -90; ammo_label.offset_bottom = -36
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ammo_label)
	# Top-center: objective
	objective = ObjectivePanel.new()
	objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective.offset_left = -260; objective.offset_right = 260; objective.offset_top = 16; objective.offset_bottom = 96
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective)
	# Top-left: kill feed... actually top-right, under notifications area is used; put feed top-left.
	killfeed = VBoxContainer.new()
	killfeed.set_anchors_preset(Control.PRESET_TOP_LEFT)
	killfeed.offset_left = 24; killfeed.offset_top = 24; killfeed.offset_right = 460; killfeed.offset_bottom = 300
	killfeed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(killfeed)
	# Left: team frames
	team_frames = VBoxContainer.new()
	team_frames.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	team_frames.offset_left = 24; team_frames.offset_top = -120; team_frames.offset_right = 220; team_frames.offset_bottom = 120
	team_frames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(team_frames)
	# Center messages
	center_msg = UITheme.label("", 34, UITheme.AMBER)
	center_msg.set_anchors_preset(Control.PRESET_CENTER)
	center_msg.offset_left = -400; center_msg.offset_right = 400; center_msg.offset_top = -160; center_msg.offset_bottom = -110
	center_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_msg.modulate.a = 0.0
	add_child(center_msg)
	respawn_label = UITheme.label("", 26, UITheme.TEXT)
	respawn_label.set_anchors_preset(Control.PRESET_CENTER)
	respawn_label.offset_left = -300; respawn_label.offset_right = 300; respawn_label.offset_top = 60; respawn_label.offset_bottom = 100
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(respawn_label)
	fps_label = UITheme.label("", 13, UITheme.TEXT_DIM, true)
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.offset_left = -260; fps_label.offset_right = -16; fps_label.offset_top = 8; fps_label.offset_bottom = 28
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(fps_label)
	netstats = UITheme.label("", 12, UITheme.TEXT_DIM, true)
	netstats.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	netstats.offset_left = -360; netstats.offset_right = -16; netstats.offset_top = 30; netstats.offset_bottom = 50
	netstats.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(netstats)
	scale = Vector2.ONE * _scale
	EventBus.kill_feed.connect(_on_kill)
	EventBus.hitmarker.connect(func(kind: StringName) -> void: hitmarker.trigger(kind))
	EventBus.local_damage_taken.connect(func(amount: float, from_dir: Vector3, _src: int) -> void: damage_dir.add(from_dir, amount))
	EventBus.objective_message.connect(_on_objective_message)
	EventBus.local_pawn_spawned.connect(func(_p: Node) -> void: _rebuild_abilities())
	EventBus.ult_ready.connect(func(_h: StringName) -> void: _show_center("ULTIMATE READY", 1.6))
	EventBus.match_phase_changed.connect(_on_phase)
	_rebuild_abilities()


func _client() -> GameClient:
	return App.client


func _pawn() -> Pawn:
	var c := _client()
	return c.local_pawn if c else null


func _rebuild_abilities() -> void:
	for c: Node in ability_bar.get_children():
		c.queue_free()
	ability_slots.clear()
	var p := _pawn()
	if p == null:
		hero_label.text = ""
		return
	hero_label.text = p.hero.display_name.to_upper()
	hero_label.add_theme_color_override("font_color", p.hero.theme_color.lightened(0.2))
	for slot in [RF.Slot.ABILITY_1, RF.Slot.ABILITY_2, RF.Slot.ABILITY_3, RF.Slot.SECONDARY]:
		var ab := p.abilities.get_slot(slot)
		if ab == null or (slot == RF.Slot.SECONDARY and ab.data.is_weapon and ab.data.cooldown <= 0.0 and ab.data.trigger == AbilityData.Trigger.HOLD):
			continue
		var s := AbilitySlot.new()
		s.setup(ab, Settings.action_display_string(RF.SLOT_ACTIONS[slot]))
		ability_bar.add_child(s)
		ability_slots.append(s)
	resource_bar.visible = p.hero.hero_resource_max > 0.0
	crosshair.set_style(p.hero.primary.presentation.crosshair if p.hero.primary and p.hero.primary.presentation else &"dot")


func _process(delta: float) -> void:
	var c := _client()
	var p := _pawn()
	if bool(Settings.get_value(&"video", "show_fps")):
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	else:
		fps_label.text = ""
	if c and Console.cvar("net_hud", 0.0) > 0.0:
		netstats.text = "ping %.0f  in %.1fKB/s  lead %d  rec %d" % [c.ping_ms, c.bandwidth_in_kbps, c.tick - c.server_tick, c.reconciles]
	else:
		netstats.text = ""
	if p == null or not is_instance_valid(p):
		health_bar.visible = false
		ability_bar.visible = false
		ult_meter.visible = false
		ammo_label.text = ""
		crosshair.visible = false
		if c and c.respawn_ticks > 0 and c.local_pawn == null:
			respawn_label.text = ""
		_update_objective()
		return
	crosshair.visible = p.alive and not UIRouter.any_overlay_open()
	health_bar.visible = true
	ability_bar.visible = p.alive
	ult_meter.visible = p.alive
	health_bar.update_from(p.health)
	if p.hero.hero_resource_max > 0.0:
		resource_bar.value = p.hero_resource / p.hero.hero_resource_max * 100.0
	for s: AbilitySlot in ability_slots:
		s.refresh()
	ult_meter.set_fraction(p.ult_fraction(), p.hero.ultimate.display_name if p.hero.ultimate else "")
	var prim := p.abilities.get_slot(RF.Slot.PRIMARY)
	if prim and prim.uses_ammo():
		ammo_label.text = "%d" % prim.ammo + ("  ·  reloading" if prim.reload_remaining > 0.0 else "") 
		ammo_label.add_theme_font_size_override("font_size", 40)
		ammo_label.modulate = UITheme.DANGER if prim.ammo <= prim.data.ammo * 0.2 else UITheme.TEXT
	else:
		ammo_label.text = "∞"
		ammo_label.modulate = UITheme.TEXT_DIM
	crosshair.spread = _spread_for(p)
	crosshair.on_target = _aiming_at_enemy(p)
	if not p.alive:
		var ticks := c.respawn_ticks - (c.world.tick - p.death_tick) if c else 0
		var secs := maxf(ticks * RF.TICK_DT, 0.0)
		respawn_label.text = "Respawning in %d" % int(ceil(secs)) if secs > 0.0 else "Respawning..."
	else:
		respawn_label.text = ""
	_update_status(p)
	_update_team_frames()
	_update_objective()
	if _msg_timer > 0.0:
		_msg_timer -= delta
		center_msg.modulate.a = clampf(_msg_timer * 2.0, 0.0, 1.0)


func _spread_for(p: Pawn) -> float:
	var prim := p.abilities.get_slot(RF.Slot.PRIMARY)
	if prim == null:
		return 0.0
	for e: AbilityEffect in prim.data.effects:
		if e is HitscanEffect:
			var h := e as HitscanEffect
			var s := h.spread_deg + prim.charge
			if Vector2(p.velocity.x, p.velocity.z).length() > 1.0: s += h.spread_moving_deg
			if not p.is_on_floor(): s += h.spread_airborne_deg
			return s * (prim.data.presentation.spread_visual_scale if prim.data.presentation else 1.0)
	return 0.0


func _aiming_at_enemy(p: Pawn) -> bool:
	var w := p.world
	var res := w.hitscan(p.eye_position(), p.aim_dir(), 120.0, p, -1, false)
	return res.pawn != null and res.pawn.team != p.team


func _update_status(p: Pawn) -> void:
	var ids := p.status.ids()
	var existing: Dictionary = {}
	for c: Node in status_row.get_children():
		existing[c.name] = c
	for id: StringName in ids:
		var sd := StatusLibrary.get_status(id)
		if sd == null or not sd.show_on_hud or sd.duration == INF:
			continue
		if existing.has(String(id)):
			existing.erase(String(id))
			continue
		var l := UITheme.label(sd.display_name if sd.display_name != "" else String(id), 12, sd.color if sd.color.a > 0 else UITheme.TEXT, true)
		l.name = String(id)
		var pnl := UITheme.panel(4)
		pnl.name = String(id)
		pnl.add_child(l)
		status_row.add_child(pnl)
	for k: Variant in existing.keys():
		(existing[k] as Node).queue_free()


func _update_team_frames() -> void:
	var c := _client()
	if c == null:
		return
	var rows: Array = []
	for r: Variant in c.roster:
		var row: Dictionary = r
		if int(row["team"]) == c.team and int(row["id"]) != c.player_id:
			rows.append(row)
	while team_frames.get_child_count() > rows.size():
		team_frames.get_child(team_frames.get_child_count() - 1).queue_free()
		await get_tree().process_frame
	while team_frames.get_child_count() < rows.size():
		team_frames.add_child(TeamFrame.new())
	for i in rows.size():
		var f := team_frames.get_child(i) as TeamFrame
		if f:
			f.update(rows[i], c.world)


func _update_objective() -> void:
	var c := _client()
	if c:
		objective.update_state(c.hud_state, c.team)


func _on_kill(killer: String, killer_team: int, victim: String, victim_team: int, ability: StringName, headshot: bool) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := UITheme.label(killer, 15, UITheme.team_color_ui(killer_team) if killer_team >= 0 else UITheme.TEXT_DIM, true)
	row.add_child(k)
	var mid := UITheme.label("  ▸%s  " % (" ◉" if headshot else ""), 15, UITheme.TEXT_DIM, true)
	row.add_child(mid)
	var v := UITheme.label(victim, 15, UITheme.team_color_ui(victim_team) if victim_team >= 0 else UITheme.TEXT_DIM, true)
	row.add_child(v)
	killfeed.add_child(row)
	var tw := create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(row, "modulate:a", 0.0, 0.5)
	tw.tween_callback(row.queue_free)
	while killfeed.get_child_count() > 6:
		killfeed.get_child(0).queue_free()
		await get_tree().process_frame


func _on_objective_message(text: String, kind: StringName) -> void:
	var msg := text
	match kind:
		&"round_start": msg = "PREPARE"
		&"live": msg = "FIGHT"
		&"point_captured": msg = "POINT CAPTURED"
		&"point_unlocked": msg = "OBJECTIVE UNLOCKED"
		&"checkpoint": msg = "CHECKPOINT"
		&"overtime": msg = "OVERTIME"
		&"round_end": msg = "ROUND OVER"
		&"match_end": msg = "MATCH OVER"
		&"ult_enemy": center_msg.add_theme_color_override("font_color", UITheme.DANGER)
		&"ult_friendly": center_msg.add_theme_color_override("font_color", Palette.friendly())
		_: pass
	if kind != &"ult_enemy" and kind != &"ult_friendly":
		center_msg.add_theme_color_override("font_color", UITheme.AMBER)
	_show_center(msg, 2.2)


func _show_center(text: String, seconds: float) -> void:
	center_msg.text = text
	_msg_timer = seconds
	center_msg.modulate.a = 1.0


func _on_phase(phase: StringName) -> void:
	if phase == &"overtime":
		_show_center("OVERTIME", 2.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("scoreboard"):
		UIRouter.show_overlay(&"scoreboard")
	elif event.is_action_released("scoreboard"):
		if not UIRouter.has_overlay(&"scoreboard") or not (UIRouter.overlays[&"scoreboard"] as Control).get_meta("final", false):
			UIRouter.hide_overlay(&"scoreboard")
	elif event.is_action_pressed("hero_select"):
		UIRouter.toggle_overlay(&"hero_select")
	elif event.is_action_pressed("pause_menu"):
		if UIRouter.any_overlay_open():
			for k: StringName in UIRouter.overlays.keys():
				UIRouter.hide_overlay(k)
		else:
			UIRouter.show_overlay(&"pause")


## --- Widgets ------------------------------------------------------------------------------------

class Crosshair extends Control:
	var style: StringName = &"dot"
	var spread: float = 0.0
	var on_target: bool = false
	var hit_t: float = 0.0
	func set_style(s: StringName) -> void:
		style = s
		queue_redraw()
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var col: Color = Settings.get_value(&"accessibility", "crosshair_color")
		if on_target:
			col = Palette.enemy()
		var sz: float = float(Settings.get_value(&"accessibility", "crosshair_size"))
		var gap := 4.0 + spread * 6.0
		var shadow := Color(0, 0, 0, 0.6)
		match style:
			&"dot":
				draw_circle(c, 3.0 * sz, shadow)
				draw_circle(c, 2.0 * sz, col)
			&"circle":
				draw_arc(c, (10.0 + spread * 5.0) * sz, 0, TAU, 32, shadow, 3.0)
				draw_arc(c, (10.0 + spread * 5.0) * sz, 0, TAU, 32, col, 1.5)
				draw_circle(c, 1.5 * sz, col)
			&"cross", &"bracket":
				for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
					draw_line(c + d * gap * sz, c + d * (gap + 8.0) * sz, shadow, 3.5)
					draw_line(c + d * gap * sz, c + d * (gap + 8.0) * sz, col, 1.8)
				if style == &"bracket":
					draw_circle(c, 1.5 * sz, col)
			&"none":
				pass
			_:
				draw_circle(c, 2.0 * sz, col)

class Hitmarker extends Control:
	var t: float = 0.0
	var kind: StringName = &"hit"
	func trigger(k: StringName) -> void:
		kind = k
		t = 0.25 if k == &"hit" else 0.4
	func _process(d: float) -> void:
		if t > 0.0:
			t -= d
			queue_redraw()
	func _draw() -> void:
		if t <= 0.0:
			return
		var c := size * 0.5
		var col := Color(1, 1, 1, clampf(t * 5.0, 0.0, 1.0))
		var len := 7.0
		if kind == &"kill":
			col = Color(1.0, 0.3, 0.25, clampf(t * 3.0, 0.0, 1.0)); len = 11.0
		elif kind == &"headshot":
			col = Color(1.0, 0.85, 0.3, clampf(t * 4.0, 0.0, 1.0)); len = 9.0
		var g := 6.0
		for d: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			draw_line(c + d * g, c + d * (g + len), Color(0, 0, 0, col.a * 0.6), 4.0)
			draw_line(c + d * g, c + d * (g + len), col, 2.0)

class DamageDirection extends Control:
	var indicators: Array = []   # [dir(Vector3), t, strength]
	func add(dir: Vector3, amount: float) -> void:
		indicators.append([dir, 1.2, clampf(amount / 100.0, 0.25, 1.0)])
	func _process(d: float) -> void:
		for i in range(indicators.size() - 1, -1, -1):
			indicators[i][1] = float(indicators[i][1]) - d
			if float(indicators[i][1]) <= 0.0:
				indicators.remove_at(i)
		if not indicators.is_empty():
			queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var fwd := -cam.global_transform.basis.z
		var right := cam.global_transform.basis.x
		for ind: Array in indicators:
			var dir: Vector3 = ind[0]
			var a := atan2(dir.dot(right), dir.dot(fwd))
			var r := 110.0
			var p := c + Vector2(sin(a), -cos(a)) * r
			var alpha := clampf(float(ind[1]), 0.0, 1.0) * 0.85
			var col := Color(1.0, 0.25, 0.2, alpha)
			var tangent := Vector2(cos(a), sin(a))
			var pts := PackedVector2Array([p + Vector2(sin(a), -cos(a)) * 14.0 * float(ind[2]), p - tangent * 18.0, p + tangent * 18.0])
			draw_colored_polygon(pts, col)

class HealthLayers extends Control:
	var hp: float = 1.0; var ar: float = 0.0; var sh: float = 0.0; var oh: float = 0.0; var total: float = 1.0
	var flash: float = 0.0
	var last_total: float = -1.0
	var text: String = ""
	func update_from(h: HealthComponent) -> void:
		hp = h.health; ar = h.armor; sh = h.shield; oh = h.overhealth
		total = h.total_max()
		var cur := h.health + h.armor + h.shield
		if last_total >= 0.0 and cur < last_total - 0.5:
			flash = 1.0
		last_total = cur
		text = "%d" % int(ceil(cur + oh))
		queue_redraw()
	func _process(d: float) -> void:
		if flash > 0.0:
			flash = maxf(flash - d * 4.0, 0.0)
			queue_redraw()
	func _draw() -> void:
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0, 0.55))
		var segs := int(ceil(total / 25.0))
		var seg_w := w / maxf(segs, 1)
		var x := 0.0
		var layers := [[hp, Color(0.95, 0.96, 0.98)], [ar, Color(0.98, 0.72, 0.22)], [sh, Color(0.35, 0.65, 1.0)], [oh, Color(0.45, 0.95, 0.55)]]
		var cap := total + oh
		for l: Array in layers:
			var amt: float = l[0]
			if amt <= 0.0: continue
			var lw := amt / maxf(cap, 1.0) * w
			draw_rect(Rect2(x, 2, lw, h - 4), l[1])
			x += lw
		if flash > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(1, 0.3, 0.25, flash * 0.35))
		for i in range(1, segs):
			draw_line(Vector2(i * seg_w, 2), Vector2(i * seg_w, h - 2), Color(0, 0, 0, 0.6), 1.5)
		draw_string(UITheme.font(), Vector2(w + 10, h - 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UITheme.TEXT)

class UltMeter extends Control:
	var frac: float = 0.0
	var ult_name: String = ""
	var pulse: float = 0.0
	func set_fraction(f: float, n: String) -> void:
		frac = f; ult_name = n
		queue_redraw()
	func _process(d: float) -> void:
		pulse += d
		if frac >= 1.0: queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.42
		draw_arc(c, r, 0, TAU, 48, Color(0, 0, 0, 0.6), 8.0)
		var col := UITheme.AMBER if frac < 1.0 else Color(1.0, 0.9, 0.5).lerp(Color.WHITE, 0.5 + 0.5 * sin(pulse * 6.0))
		if frac > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, col, 6.0, true)
		var txt := "%d" % int(frac * 100.0) if frac < 1.0 else "Q"
		var fs := 22 if frac < 1.0 else 30
		draw_string(UITheme.font(), c + Vector2(-fs * 0.6 * txt.length() * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if frac >= 1.0:
			draw_string(UITheme.font_narrow(), Vector2(c.x - 60, size.y + 14), ult_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 120, 12, col)

class AbilitySlot extends Control:
	var ability: Ability
	var key: String
	var flash: float = 0.0
	var was_ready: bool = true
	func setup(a: Ability, k: String) -> void:
		ability = a; key = k
		custom_minimum_size = Vector2(64, 64)
	func refresh() -> void:
		var ready := ability.is_ready() or ability.is_active()
		if ready and not was_ready:
			flash = 1.0
		was_ready = ready
		queue_redraw()
	func _process(d: float) -> void:
		if flash > 0.0:
			flash = maxf(flash - d * 3.0, 0.0)
			queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var cd := ability.cooldown_fraction()
		var active := ability.is_active()
		var bg := Color(0.05, 0.06, 0.09, 0.85)
		draw_rect(r, bg)
		var col := ability.pawn.hero.theme_color if ability.pawn else UITheme.AMBER
		if active:
			draw_rect(r, col.darkened(0.4))
		elif cd > 0.0:
			draw_rect(Rect2(0, size.y * (1.0 - cd) * 0.0, size.x, size.y * cd), Color(0.2, 0.22, 0.28, 0.9))
		if flash > 0.0:
			draw_rect(r, Color(1, 1, 1, flash * 0.5))
		draw_rect(r, col if (cd <= 0.0 or active) else Color(0.3, 0.32, 0.38), false, 2.0)
		var name := ability.data.display_name
		draw_string(UITheme.font_narrow(), Vector2(4, 16), key, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, 12, UITheme.AMBER)
		if cd > 0.0 and not active:
			draw_string(UITheme.font(), Vector2(0, size.y * 0.62), "%.0f" % ceil(ability.cooldown_remaining), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, UITheme.TEXT)
		elif ability.data.charges > 1:
			draw_string(UITheme.font(), Vector2(0, size.y * 0.62), "%d" % ability.charges_left, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, UITheme.TEXT)
		draw_string(UITheme.font_narrow(), Vector2(0, size.y - 5), name.to_upper().left(12), HORIZONTAL_ALIGNMENT_CENTER, size.x, 10, UITheme.TEXT_DIM)

class TeamFrame extends Control:
	var name_l: Label
	var bar: ProgressBar
	var hero_l: Label
	var ult_l: Label
	func _init() -> void:
		custom_minimum_size = Vector2(190, 34)
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(vb)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(row)
		name_l = UITheme.label("", 13, UITheme.TEXT, true)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		ult_l = UITheme.label("", 12, UITheme.AMBER, true)
		row.add_child(ult_l)
		bar = ProgressBar.new()
		bar.custom_minimum_size = Vector2(160, 6)
		bar.show_percentage = false
		vb.add_child(bar)
		hero_l = UITheme.label("", 10, UITheme.TEXT_DIM, true)
		vb.add_child(hero_l)
	func update(row: Dictionary, world: SimWorld) -> void:
		name_l.text = String(row["name"])
		var h := Registry.hero(StringName(String(row["hero"])))
		hero_l.text = h.display_name.to_upper() if h else ""
		var p := world.get_pawn(int(row.get("net_id", -1)))
		if p and is_instance_valid(p):
			bar.value = p.health.fraction() * 100.0 if p.alive else 0.0
			ult_l.text = "ULT" if p.ult_fraction() >= 1.0 else ""
			modulate.a = 1.0 if p.alive else 0.45
		else:
			bar.value = 0.0
			ult_l.text = ""
			modulate.a = 0.45

class ObjectivePanel extends Control:
	var state: Dictionary = {}
	var my_team: int = 0
	func update_state(s: Dictionary, team: int) -> void:
		state = s; my_team = team
		queue_redraw()
	func _draw() -> void:
		if state.is_empty():
			return
		var w := size.x
		var phase := int(state.get("phase", 0))
		var mode_kind := String(state.get("kind", "control"))
		var col_a := UITheme.team_color_ui(RF.Team.A)
		var col_b := UITheme.team_color_ui(RF.Team.B)
		# Header line: score + timer
		var timer := float(state.get("time", 0.0))
		var setup := float(state.get("setup", 0.0))
		var top := "%d   —   %d" % [int(state.get("score_a", 0)), int(state.get("score_b", 0))]
		draw_string(UITheme.font(), Vector2(0, 26), top, HORIZONTAL_ALIGNMENT_CENTER, w, 26, UITheme.TEXT)
		var sub := ""
		if phase == ModeController.Phase.SETUP:
			sub = "Setup  %d" % int(ceil(setup))
		elif phase == ModeController.Phase.OVERTIME or bool(state.get("overtime", false)):
			sub = "OVERTIME"
		elif state.has("unlock") and float(state["unlock"]) > 0.0:
			sub = "Unlocks in %d" % int(ceil(float(state["unlock"])))
		elif timer > 0.0 and mode_kind != "control":
			sub = "%d:%02d" % [int(timer) / 60, int(timer) % 60]
		if sub != "":
			draw_string(UITheme.font_narrow(), Vector2(0, 46), sub, HORIZONTAL_ALIGNMENT_CENTER, w, 14, UITheme.AMBER if sub == "OVERTIME" else UITheme.TEXT_DIM)
		# Progress bar (mode-specific)
		var bar := Rect2(w * 0.15, 54, w * 0.7, 12)
		draw_rect(bar, Color(0, 0, 0, 0.6))
		if state.has("progress"):
			var owner := int(state.get("owner", -1))
			var prog := float(state.get("progress", 0.0))
			var oc := col_a if owner == RF.Team.A else (col_b if owner == RF.Team.B else UITheme.TEXT_DIM)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * prog, bar.size.y)), oc)
			var cap_a := float(state.get("cap_a", 0.0)); var cap_b := float(state.get("cap_b", 0.0))
			if cap_a > 0.0: draw_rect(Rect2(bar.position + Vector2(0, bar.size.y + 2), Vector2(bar.size.x * cap_a, 4)), col_a)
			if cap_b > 0.0: draw_rect(Rect2(bar.position + Vector2(0, bar.size.y + 2), Vector2(bar.size.x * cap_b, 4)), col_b)
			if bool(state.get("contested", false)):
				draw_string(UITheme.font_narrow(), Vector2(0, 80), "CONTESTED", HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.DANGER)
			var wins_a := int(state.get("wins_a", 0)); var wins_b := int(state.get("wins_b", 0))
			for i in 2:
				draw_circle(Vector2(w * 0.08 + i * 14, 60), 5, col_a if i < wins_a else Color(0, 0, 0, 0.5))
				draw_circle(Vector2(w * 0.92 - i * 14, 60), 5, col_b if i < wins_b else Color(0, 0, 0, 0.5))
		elif state.has("payload_progress"):
			var prog := float(state.get("payload_progress", 0.0))
			var att := int(state.get("attacking", 0))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * prog, bar.size.y)), col_a if att == RF.Team.A else col_b)
			for cp: Variant in state.get("checkpoints", []):
				var x := bar.position.x + bar.size.x * float(cp)
				draw_line(Vector2(x, bar.position.y - 3), Vector2(x, bar.position.y + bar.size.y + 3), UITheme.TEXT, 2.0)
			var pushers := int(state.get("pushers", 0))
			if pushers > 0:
				draw_string(UITheme.font_narrow(), Vector2(0, 80), "×%d pushing" % pushers, HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.TEXT_DIM)
			if bool(state.get("contested", false)):
				draw_string(UITheme.font_narrow(), Vector2(0, 80), "CONTESTED", HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.DANGER)
		elif state.has("push_progress"):
			var pp := float(state.get("push_progress", 0.5))
			var x := bar.position.x + bar.size.x * pp
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * 0.5, bar.size.y)), col_a.darkened(0.6))
			draw_rect(Rect2(bar.position + Vector2(bar.size.x * 0.5, 0), Vector2(bar.size.x * 0.5, bar.size.y)), col_b.darkened(0.6))
			draw_circle(Vector2(x, bar.position.y + 6), 8, UITheme.TEXT)
			var pusher_team := int(state.get("pusher_team", -1))
			if pusher_team >= 0:
				draw_circle(Vector2(x, bar.position.y + 6), 5, col_a if pusher_team == RF.Team.A else col_b)
		elif state.has("capture_progress"):
			var prog := float(state.get("capture_progress", 0.0))
			var att := int(state.get("attacking", 0))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * prog, bar.size.y)), col_a if att == RF.Team.A else col_b)
			var idx := int(state.get("objective", 0))
			draw_string(UITheme.font_narrow(), Vector2(0, 80), "Point %s" % ["A", "B", "C"][clampi(idx, 0, 2)], HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.TEXT_DIM)
		var att := int(state.get("attacking", -1))
		if att >= 0 and mode_kind != "control":
			var role := "ATTACK" if att == my_team else "DEFEND"
			draw_string(UITheme.font_narrow(), Vector2(0, 100), role, HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.AMBER)
