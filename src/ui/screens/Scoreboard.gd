extends Control
## Scoreboard overlay: shown while holding Tab, or pinned at match end (set_data({"final": true})).
## Header: teams / score / mode / map / timer. Body: ScoreboardPanel (two team tables). Footer: role legend.

const REFRESH_SECONDS := 0.5

var final_mode: bool = false
var board: ScoreboardPanel
var score_a_l: Label
var score_b_l: Label
var team_a_l: Label
var team_b_l: Label
var info_l: Label
var phase_l: Label
var title_tag: Label
var _t: float = 0.0


func set_data(d: Dictionary) -> void:
	final_mode = bool(d.get("final", false))
	set_meta("final", final_mode)


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.04, 0.84 if final_mode else 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vb)
	var width := ScoreboardPanel.total_width()
	# --- Header -----------------------------------------------------------------------------
	var head := UITheme.panel(16)
	head.custom_minimum_size.x = width
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	var top := HBoxContainer.new()
	hv.add_child(top)
	var title := UITheme.heading("Scoreboard", 26)
	top.add_child(title)
	title_tag = UITheme.label("  FINAL" if final_mode else "", 14, UITheme.GOOD, true)
	title_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(title_tag)
	info_l = UITheme.label("", 14, UITheme.TEXT_DIM, true)
	info_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_l.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(info_l)
	var score_row := HBoxContainer.new()
	score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	score_row.add_theme_constant_override("separation", 22)
	hv.add_child(score_row)
	team_a_l = UITheme.label(RF.team_name(RF.Team.A).to_upper(), 22, UITheme.team_color_ui(RF.Team.A))
	team_a_l.custom_minimum_size.x = 160
	team_a_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	team_a_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_row.add_child(team_a_l)
	score_a_l = UITheme.label("0", 40, UITheme.TEXT)
	score_a_l.custom_minimum_size.x = 56
	score_a_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_row.add_child(score_a_l)
	phase_l = UITheme.label("", 15, UITheme.AMBER, true)
	phase_l.custom_minimum_size.x = 120
	phase_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_row.add_child(phase_l)
	score_b_l = UITheme.label("0", 40, UITheme.TEXT)
	score_b_l.custom_minimum_size.x = 56
	score_b_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_row.add_child(score_b_l)
	team_b_l = UITheme.label(RF.team_name(RF.Team.B).to_upper(), 22, UITheme.team_color_ui(RF.Team.B))
	team_b_l.custom_minimum_size.x = 160
	team_b_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_row.add_child(team_b_l)
	# --- Tables -----------------------------------------------------------------------------
	board = ScoreboardPanel.new()
	vb.add_child(board)
	# --- Footer -----------------------------------------------------------------------------
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(foot)
	foot.add_child(ScoreboardPanel.make_legend(12))
	var hint := UITheme.label("MATCH COMPLETE" if final_mode else "HOLD  %s  ·  BOTS MARKED  ·  YOUR ROW IN AMBER" % Settings.action_display_string("scoreboard"), 12, UITheme.TEXT_DIM, true)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.add_child(hint)
	EventBus.scoreboard_updated.connect(func(_rows: Array) -> void: _refresh())
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if _t >= REFRESH_SECONDS:
		_t = 0.0
		_refresh()


func _rows() -> Array:
	var c := App.client
	if c == null:
		return []
	var end_data: Dictionary = c.presentation.match_end_data if c.presentation else {}
	if final_mode and end_data.has("stats"):
		var rows := ScoreboardPanel.rows_from_stats(end_data["stats"])
		var pings: Dictionary = {}
		for r: Variant in c.roster:
			var d: Dictionary = r
			pings[int(d.get("id", 0))] = -1 if bool(d.get("bot", false)) else int(d.get("ping", 0))
		for row: Variant in rows:
			(row as Dictionary)["ping"] = pings.get(int((row as Dictionary)["id"]), -1)
		return rows
	return ScoreboardPanel.rows_from_live(c)


func _refresh() -> void:
	var c := App.client
	board.set_rows(_rows(), c.player_id if c else -1)
	team_a_l.add_theme_color_override("font_color", UITheme.team_color_ui(RF.Team.A))
	team_b_l.add_theme_color_override("font_color", UITheme.team_color_ui(RF.Team.B))
	if c == null:
		info_l.text = ""
		phase_l.text = ""
		return
	var hs: Dictionary = c.hud_state
	var end_data: Dictionary = c.presentation.match_end_data if c.presentation else {}
	var sa := int(hs.get("score_a", 0))
	var sb := int(hs.get("score_b", 0))
	if final_mode and end_data.has("score"):
		var sc: Array = end_data["score"]
		if sc.size() >= 2:
			sa = int(sc[0]); sb = int(sc[1])
	score_a_l.text = str(sa)
	score_b_l.text = str(sb)
	var md := Registry.map(c.map_id)
	var mode := Registry.mode(c.mode_id)
	var parts: Array[String] = []
	if mode: parts.append(mode.display_name.to_upper())
	if md: parts.append(md.display_name.to_upper())
	var round_i := int(hs.get("round", 0))
	if round_i > 0: parts.append("ROUND %d" % (round_i + 1))
	info_l.text = "   ·   ".join(parts)
	phase_l.text = _phase_text(hs)


func _phase_text(hs: Dictionary) -> String:
	if final_mode:
		return "FINAL"
	var phase := int(hs.get("phase", -1))
	var t := float(hs.get("time", 0.0))
	match phase:
		ModeController.Phase.SETUP: return "SETUP %d" % int(ceil(float(hs.get("setup", 0.0))))
		ModeController.Phase.OVERTIME: return "OVERTIME"
		ModeController.Phase.ROUND_END: return "ROUND OVER"
		ModeController.Phase.MATCH_END: return "MATCH OVER"
		ModeController.Phase.WAITING: return "WAITING"
	if bool(hs.get("overtime", false)):
		return "OVERTIME"
	if t > 0.0:
		return ScoreboardPanel.format_time(t)
	return "LIVE"
