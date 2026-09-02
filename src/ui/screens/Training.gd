extends Control
## Training range launcher: pick a Runner and sparring bots, then drop into test_range.
## The right-hand card is the "how to play" primer with the player's actual keybinds.

const BOT_OPTIONS := [["No bots", 0], ["2 bots", 2], ["4 bots", 4], ["6 bots", 6], ["8 bots", 8]]

var selected: StringName = &""
var cards: Dictionary = {}       # hero id -> HeroCard
var bots_opt: OptionButton
var diff_opt: OptionButton
var hero_line: Label
var start_btn: Button


func _ready() -> void:
	theme = UITheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 120)
	margin.add_theme_constant_override("margin_right", 120)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 56)
	add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	margin.add_child(vb)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 20)
	vb.add_child(head)
	head.add_child(UITheme.heading("Training Range", 40))
	var sub := UITheme.label("No timer, no stakes. Learn a kit, feel the map, warm up.", 14, UITheme.TEXT_DIM, true)
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(sub)
	var back := UITheme.button("Back", 16, 130)
	back.pressed.connect(func() -> void: UIRouter.show(&"main_menu"))
	head.add_child(back)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.5
	body.add_child(left)
	left.add_child(_build_hero_panel())
	left.add_child(_build_bots_panel())
	body.add_child(_build_howto_panel())
	var ids := Registry.hero_ids()
	var pref := int(Settings.get_value(&"gameplay", "preferred_role"))
	var first: StringName = ids[0] if not ids.is_empty() else &""
	for id: StringName in ids:
		var h := Registry.hero(id)
		if h and pref >= 0 and int(h.role) == pref:
			first = id
			break
	if first != &"":
		_select(first)


## --- Hero grid --------------------------------------------------------------------------------------

func _build_hero_panel() -> Control:
	var p := UITheme.panel(20)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.label("CHOOSE YOUR RUNNER", 13, UITheme.AMBER, true))
	for role in 3:
		var heroes := Registry.heroes_by_role(role)
		if heroes.is_empty():
			continue
		var rl := HBoxContainer.new()
		rl.add_theme_constant_override("separation", 8)
		var g := ScoreboardPanel.RoleGlyph.new()
		g.role = role
		g.custom_minimum_size = Vector2(16, 16)
		rl.add_child(g)
		rl.add_child(UITheme.label(RF.role_name(role).to_upper() + "  ·  " + RF.ROLE_DESCRIPTIONS[role], 13, UITheme.role_color(role), true))
		v.add_child(rl)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		v.add_child(flow)
		for h: HeroData in heroes:
			var card := HeroCard.new()
			card.setup(h)
			card.pressed.connect(func() -> void: _select(h.id))
			flow.add_child(card)
			cards[h.id] = card
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	hero_line = UITheme.label("", 14, UITheme.TEXT_DIM, true)
	hero_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hero_line)
	return p


func _select(id: StringName) -> void:
	selected = id
	for k: Variant in cards.keys():
		(cards[k] as HeroCard).set_selected(k == id)
	var h := Registry.hero(id)
	if h:
		hero_line.text = "%s — %s  %s" % [h.display_name.to_upper(), h.tagline, ("· " + h.unique_mechanic) if h.unique_mechanic != "" else ""]
	if start_btn:
		start_btn.text = ("ENTER AS %s" % h.display_name.to_upper()) if h else "ENTER THE RANGE"


## --- Bots ---------------------------------------------------------------------------------------------

func _build_bots_panel() -> Control:
	var p := UITheme.panel(20)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.label("SPARRING PARTNERS", 13, UITheme.AMBER, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	v.add_child(row)
	bots_opt = OptionButton.new()
	for o: Array in BOT_OPTIONS:
		bots_opt.add_item(String(o[0]))
		bots_opt.set_item_metadata(bots_opt.item_count - 1, int(o[1]))
	bots_opt.selected = 2
	row.add_child(_field("Bots on the range", bots_opt))
	diff_opt = OptionButton.new()
	for n: String in ["Recruit", "Regular", "Veteran", "Elite"]:
		diff_opt.add_item(n)
	diff_opt.selected = clampi(int(Settings.get_value(&"gameplay", "bot_difficulty")), 0, 3)
	row.add_child(_field("Bot skill", diff_opt))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	start_btn = UITheme.button("Enter the Range", 20, 260)
	start_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	start_btn.pressed.connect(_start)
	row.add_child(start_btn)
	return p


func _field(label: String, ctrl: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.add_child(UITheme.label(label, 13, UITheme.TEXT_DIM, true))
	ctrl.custom_minimum_size.x = 200
	v.add_child(ctrl)
	return v


func _start() -> void:
	var bots := int(bots_opt.get_item_metadata(bots_opt.selected))
	var d := diff_opt.selected
	var hero_id := selected
	# The launcher outlives this screen (it is freed when the Connecting screen replaces it).
	var launcher := Launcher.new()
	launcher.hero_id = hero_id
	get_tree().root.call_deferred("add_child", launcher)
	App.start_local_match(&"test_range", &"control", bots, {"difficulty": d})


## --- How to play ----------------------------------------------------------------------------------------

func _build_howto_panel() -> Control:
	var p := UITheme.panel(20)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size.x = 460
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UITheme.label("HOW TO PLAY", 13, UITheme.AMBER, true))
	var k := func(a: String) -> String: return Settings.action_display_string(a)
	var lines := [
		[[k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")], "Move. Runners are fast — there is no sprint key."],
		[[k.call("jump"), k.call("crouch")], "Jump and crouch. Some Runners double-jump, hover or climb."],
		[[k.call("primary_fire"), k.call("secondary_fire")], "Primary and secondary fire. Headshots deal bonus damage."],
		[[k.call("ability_1"), k.call("ability_2"), k.call("ability_3")], "Abilities. Cooldowns show on the bar at the bottom of the screen."],
		[[k.call("ultimate")], "Ultimate. It charges from damage, healing and time on the objective."],
		[[k.call("reload"), k.call("melee"), k.call("interact")], "Reload, quick melee, interact."],
		[[k.call("scoreboard"), k.call("hero_select"), k.call("ping")], "Scoreboard, swap Runner, ping a spot for your team."],
		[["◎"], "Objective: stand on the point to capture it. Health regenerates out of combat; stay near your Conduit."],
	]
	for ln: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		chips.custom_minimum_size.x = 150
		chips.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		for key: String in ln[0]:
			chips.add_child(_chip(key))
		row.add_child(chips)
		var t := UITheme.label(String(ln[1]), 14, UITheme.TEXT, true)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
		v.add_child(row)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	v.add_child(UITheme.separator())
	var tip := UITheme.label("Rebind anything under Settings → Controls. %s opens the pause menu in a match." % Settings.action_display_string("pause_menu"), 12, UITheme.TEXT_DIM, true)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	return p


func _chip(text: String) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.AMBER, 0.12)
	sb.border_color = Color(UITheme.AMBER, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 7; sb.content_margin_right = 7; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = 30
	var l := UITheme.label(text, 12, UITheme.AMBER, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Waits for the match HUD, then picks the chosen Runner on the client. Self-frees.
class Launcher extends Node:
	var hero_id: StringName = &""
	var timeout: float = 20.0
	func _ready() -> void:
		EventBus.screen_changed.connect(_on_screen)
	func _on_screen(n: StringName) -> void:
		if n != &"hud":
			return
		await get_tree().create_timer(0.3).timeout
		if App.client and hero_id != &"":
			App.client.select_hero(hero_id)
		queue_free()
	func _process(delta: float) -> void:
		timeout -= delta
		if timeout <= 0.0:
			queue_free()


class HeroCard extends Button:
	var hero: HeroData
	func setup(h: HeroData) -> void:
		hero = h
		custom_minimum_size = Vector2(176, 58)
		focus_mode = Control.FOCUS_ALL
		text = ""
		var hb := HBoxContainer.new()
		hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hb.offset_left = 8; hb.offset_top = 8; hb.offset_right = -8; hb.offset_bottom = -8
		hb.add_theme_constant_override("separation", 10)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(hb)
		var swatch := ColorRect.new()
		swatch.color = h.theme_color
		swatch.custom_minimum_size = Vector2(8, 0)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(swatch)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(vb)
		var n := UITheme.label(h.display_name.to_upper(), 15, UITheme.TEXT)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(n)
		var r := UITheme.label(RF.role_name(h.role).to_upper(), 11, UITheme.role_color(h.role), true)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(r)
	func set_selected(s: bool) -> void:
		modulate = Color(1, 1, 1) if s else Color(0.84, 0.84, 0.87)
		if s:
			var sb := (UITheme.theme().get_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
			sb.border_color = UITheme.AMBER
			sb.set_border_width_all(2)
			add_theme_stylebox_override("normal", sb)
		else:
			remove_theme_stylebox_override("normal")
