extends Control
## Post-match flow: result banner → Play of the Game replay (only a caption is drawn so the 3D world
## shows through) → final scoreboard with medals and next actions.

const BANNER_SECONDS := 3.0
## [title, stats key, formatter kind]
const MEDALS := [
	["Most damage", "damage", "num"],
	["Most healing", "healing", "num"],
	["Most eliminations", "kills", "int"],
	["Most objective time", "objective_time", "time"],
	["Best streak", "best_streak", "int"],
]

var data: Dictionary = {}
var my_team: int = RF.Team.A
var result: StringName = &"draw"
var phase: StringName = &"banner"
var bg: ColorRect
var banner: Control
var potg_caption: Control
var stats_root: Control
var replay: ReplayPlayer
var _replay_done: bool = false


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := App.client
	if c and is_instance_valid(c.presentation):
		data = c.presentation.match_end_data
		my_team = c.team
	var winner := int(data.get("winner", -1))
	if winner == RF.Team.A or winner == RF.Team.B:
		result = &"victory" if winner == my_team else &"defeat"
	else:
		result = &"draw"
	bg = ColorRect.new()
	bg.color = Color(0.02, 0.025, 0.04, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build_banner()
	_build_caption()
	var tw := create_tween()
	tw.tween_interval(BANNER_SECONDS)
	tw.tween_callback(_after_banner)


func _exit_tree() -> void:
	if not _replay_done and is_instance_valid(replay):
		_replay_done = true
		var pres := replay.presentation
		replay.stop()
		if is_instance_valid(pres):
			pres.replay_player = null


## --- Result helpers ---------------------------------------------------------------------------

func _result_text() -> String:
	match result:
		&"victory": return "VICTORY"
		&"defeat": return "DEFEAT"
	return "DRAW"


func _result_color() -> Color:
	match result:
		&"victory": return UITheme.AMBER
		&"defeat": return UITheme.DANGER
	return UITheme.TEXT_DIM


func _score() -> Array:
	var sc: Variant = data.get("score", [0, 0])
	if sc is Array and (sc as Array).size() >= 2:
		return [int((sc as Array)[0]), int((sc as Array)[1])]
	return [0, 0]


func _context_line() -> String:
	var parts: Array[String] = []
	var c := App.client
	var mode := Registry.mode(c.mode_id) if c else Registry.mode(StringName(String(data.get("mode", ""))))
	var md := Registry.map(c.map_id) if c else null
	if mode: parts.append(mode.display_name.to_upper())
	if md: parts.append(md.display_name.to_upper())
	var elapsed := float(data.get("elapsed", 0.0))
	if elapsed > 0.0: parts.append(ScoreboardPanel.format_time(elapsed))
	return "   ·   ".join(parts)


func _score_row(size_team: int, size_score: int) -> HBoxContainer:
	var sc := _score()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var a := UITheme.label(RF.team_name(RF.Team.A).to_upper(), size_team, UITheme.team_color_ui(RF.Team.A))
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(a)
	var s := UITheme.label("%d  —  %d" % [sc[0], sc[1]], size_score, UITheme.TEXT)
	row.add_child(s)
	var b := UITheme.label(RF.team_name(RF.Team.B).to_upper(), size_team, UITheme.team_color_ui(RF.Team.B))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	return row


## --- Banner ------------------------------------------------------------------------------------

func _build_banner() -> void:
	banner = CenterContainer.new()
	banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	banner.add_child(vb)
	var ctx := UITheme.label("MATCH COMPLETE" + ("   ·   " + _context_line() if _context_line() != "" else ""), 14, UITheme.TEXT_DIM, true)
	ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ctx)
	var title := UITheme.heading(_result_text(), 56)
	title.add_theme_color_override("font_color", _result_color())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var rule := UITheme.separator()
	rule.custom_minimum_size.x = 420
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(rule)
	vb.add_child(_score_row(22, 40))
	var potg: Dictionary = data.get("potg", {})
	if not potg.is_empty():
		var up := UITheme.label("PLAY OF THE GAME UP NEXT", 12, UITheme.AMBER_DIM, true)
		up.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(up)
	vb.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(vb, "modulate:a", 1.0, 0.4)


## --- Play of the Game --------------------------------------------------------------------------

func _build_caption() -> void:
	potg_caption = Control.new()
	potg_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	potg_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potg_caption.visible = false
	add_child(potg_caption)
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.offset_left = -340; holder.offset_right = 340; holder.offset_top = 26; holder.offset_bottom = 140
	holder.alignment = BoxContainer.ALIGNMENT_BEGIN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potg_caption.add_child(holder)
	var panel := UITheme.panel(14)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var potg: Dictionary = data.get("potg", {})
	var hero := Registry.hero(StringName(String(potg.get("hero", ""))))
	var team := int(potg.get("team", 0))
	var k := UITheme.label("PLAY OF THE GAME", 13, UITheme.AMBER, true)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(k)
	var who := HBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.add_theme_constant_override("separation", 10)
	vb.add_child(who)
	var name_l := UITheme.label(String(potg.get("name", "?")).to_upper(), 26, UITheme.team_color_ui(team))
	who.add_child(name_l)
	var as_l := UITheme.label("as", 14, UITheme.TEXT_DIM, true)
	as_l.size_flags_vertical = Control.SIZE_SHRINK_END
	who.add_child(as_l)
	var hero_l := UITheme.label((hero.display_name if hero else "?").to_upper(), 26, hero.theme_color.lightened(0.2) if hero else UITheme.TEXT)
	who.add_child(hero_l)
	var skip := UITheme.button("Skip", 12)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(_on_replay_finished)
	vb.add_child(skip)


func _after_banner() -> void:
	var potg: Dictionary = data.get("potg", {})
	var c := App.client
	var frames: Array = potg.get("frames", [])
	if not potg.is_empty() and frames.size() > 1 and c and is_instance_valid(c.presentation):
		_start_replay(potg)
	else:
		_show_stats()


func _start_replay(potg: Dictionary) -> void:
	phase = &"potg"
	banner.visible = false
	bg.visible = false           # the 3D world must stay visible during the replay
	potg_caption.visible = true
	var pres := App.client.presentation
	replay = ReplayPlayer.new()
	replay.name = "PotgReplay"
	pres.add_child(replay)
	pres.replay_player = replay
	replay.setup(pres, potg)
	replay.play(_on_replay_finished)


func _on_replay_finished() -> void:
	if _replay_done:
		return
	_replay_done = true
	if is_instance_valid(replay):
		var pres := replay.presentation
		replay.stop()
		if is_instance_valid(pres):
			pres.replay_player = null
	replay = null
	_show_stats()


## --- Stats ---------------------------------------------------------------------------------------

func _show_stats() -> void:
	phase = &"stats"
	if is_instance_valid(banner): banner.visible = false
	if is_instance_valid(potg_caption): potg_caption.visible = false
	bg.visible = true
	bg.color = Color(0.02, 0.025, 0.04, 0.82)
	if stats_root:
		stats_root.visible = true
		return
	stats_root = MarginContainer.new()
	stats_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_root.add_theme_constant_override("margin_left", 48)
	stats_root.add_theme_constant_override("margin_right", 48)
	stats_root.add_theme_constant_override("margin_top", 28)
	stats_root.add_theme_constant_override("margin_bottom", 28)
	add_child(stats_root)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	stats_root.add_child(vb)
	# Header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	vb.add_child(head)
	var hl := VBoxContainer.new()
	hl.add_theme_constant_override("separation", 0)
	head.add_child(hl)
	var title := UITheme.heading(_result_text(), 40)
	title.add_theme_color_override("font_color", _result_color())
	hl.add_child(title)
	hl.add_child(UITheme.label(_context_line(), 13, UITheme.TEXT_DIM, true))
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(mid)
	mid.add_child(_score_row(18, 34))
	var hr := VBoxContainer.new()
	hr.alignment = BoxContainer.ALIGNMENT_CENTER
	hr.add_theme_constant_override("separation", 0)
	head.add_child(hr)
	var potg: Dictionary = data.get("potg", {})
	if not potg.is_empty():
		var pl := UITheme.label("PLAY OF THE GAME", 12, UITheme.AMBER, true)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hr.add_child(pl)
		var hero := Registry.hero(StringName(String(potg.get("hero", ""))))
		var pn := UITheme.label("%s as %s" % [String(potg.get("name", "?")), hero.display_name if hero else "?"], 16, UITheme.TEXT)
		pn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hr.add_child(pn)
	# Medals
	var rows := ScoreboardPanel.rows_from_stats(data.get("stats", []))
	var c := App.client
	if c:
		var pings: Dictionary = {}
		for r: Variant in c.roster:
			var d: Dictionary = r
			pings[int(d.get("id", 0))] = -1 if bool(d.get("bot", false)) else int(d.get("ping", 0))
		for row: Variant in rows:
			(row as Dictionary)["ping"] = pings.get(int((row as Dictionary)["id"]), -1)
	var medals := HBoxContainer.new()
	medals.add_theme_constant_override("separation", 10)
	vb.add_child(medals)
	for m: Array in MEDALS:
		medals.add_child(_medal_card(String(m[0]), String(m[1]), String(m[2]), rows))
	# Board
	var board_center := CenterContainer.new()
	board_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(board_center)
	var board := ScoreboardPanel.new()
	board.set_rows(rows, c.player_id if c else -1)
	board_center.add_child(board)
	# Actions
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	vb.add_child(foot)
	foot.add_child(ScoreboardPanel.make_legend(12))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	var menu := UITheme.button("Main Menu", 16, 160)
	menu.pressed.connect(func() -> void: App.go_to_menu())
	foot.add_child(menu)
	var change := UITheme.button("Change Map", 16, 160)
	change.pressed.connect(func() -> void:
		App.stop_match()
		UIRouter.show(&"play"))
	foot.add_child(change)
	var again := UITheme.button("Play Again", 18, 200)
	again.pressed.connect(_play_again)
	foot.add_child(again)
	if rows.is_empty():
		var none := UITheme.label("No match data — the server did not report final statistics.", 14, UITheme.TEXT_DIM, true)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(none)
		vb.move_child(none, 2)
	again.grab_focus()


func _medal_card(title: String, key: String, kind: String, rows: Array) -> PanelContainer:
	var best: Dictionary = {}
	var best_v := 0.0
	for r: Variant in rows:
		var d: Dictionary = r
		var v := float(d.get(key, 0.0))
		if v > best_v:
			best_v = v
			best = d
	var p := UITheme.panel(12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	p.add_child(vb)
	vb.add_child(UITheme.label(title.to_upper(), 11, UITheme.AMBER, true))
	if best.is_empty():
		vb.add_child(UITheme.label("—", 18, UITheme.TEXT_DIM))
		vb.add_child(UITheme.label("nobody qualified", 12, UITheme.TEXT_DIM, true))
		return p
	var hero := Registry.hero(StringName(String(best.get("hero", ""))))
	var name_l := UITheme.label(String(best.get("name", "?")), 18, UITheme.team_color_ui(int(best.get("team", 0))))
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(name_l)
	var value := ""
	match kind:
		"time": value = ScoreboardPanel.format_time(best_v)
		"int": value = str(int(best_v))
		_: value = str(int(round(best_v)))
	vb.add_child(UITheme.label("%s   ·   %s" % [hero.display_name if hero else "?", value], 12, UITheme.TEXT_DIM, true))
	return p


func _play_again() -> void:
	var c := App.client
	if c == null:
		App.go_to_menu()
		return
	var map_id := c.map_id
	var mode_id := c.mode_id
	App.start_local_match(map_id, mode_id, 9, {"difficulty": int(Settings.get_value(&"gameplay", "bot_difficulty"))})


func _unhandled_input(event: InputEvent) -> void:
	if phase == &"potg" and (event.is_action_pressed("pause_menu") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")):
		_on_replay_finished()
		get_viewport().set_input_as_handled()
