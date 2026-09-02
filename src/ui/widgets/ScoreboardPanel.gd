class_name ScoreboardPanel
extends VBoxContainer
## Reusable two-team scoreboard: one custom-drawn table per team (hero swatch + role glyph, player,
## K/D/A, damage, healing, mitigated, objective time, ults, ping). Feed it rows with set_rows();
## build rows with rows_from_stats() (match-end stats) or rows_from_live() (roster + live pawns).

const ROW_H := 30.0
const HEAD_H := 24.0
const TEAM_HEAD_H := 36.0
const PAD := 14.0
const MIN_ROWS := 5

## [title, width, alignment]
const COLS := [
	["RUNNER", 196, HORIZONTAL_ALIGNMENT_LEFT],
	["PLAYER", 214, HORIZONTAL_ALIGNMENT_LEFT],
	["K", 46, HORIZONTAL_ALIGNMENT_RIGHT],
	["D", 46, HORIZONTAL_ALIGNMENT_RIGHT],
	["A", 46, HORIZONTAL_ALIGNMENT_RIGHT],
	["DMG", 84, HORIZONTAL_ALIGNMENT_RIGHT],
	["HEAL", 84, HORIZONTAL_ALIGNMENT_RIGHT],
	["MIT", 84, HORIZONTAL_ALIGNMENT_RIGHT],
	["OBJ", 72, HORIZONTAL_ALIGNMENT_RIGHT],
	["ULT", 50, HORIZONTAL_ALIGNMENT_RIGHT],
	["PING", 66, HORIZONTAL_ALIGNMENT_RIGHT],
]

var tables: Array[TeamTable] = []
var local_player_id: int = -1


func _init() -> void:
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for team in RF.TEAM_COUNT:
		var t := TeamTable.new()
		t.team = team
		add_child(t)
		tables.append(t)


static func total_width() -> float:
	var w := PAD * 2.0
	for c: Array in COLS:
		w += float(c[1])
	return w


## rows: Array of Dictionary (see rows_from_stats for the keys). Sorted per team by kills + assists.
func set_rows(rows: Array, local_id: int = -1) -> void:
	local_player_id = local_id
	for t: TeamTable in tables:
		var mine: Array = []
		for r: Variant in rows:
			var d: Dictionary = r
			if int(d.get("team", -1)) == t.team:
				mine.append(d)
		mine.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			var sa := int(a.get("kills", 0)) + int(a.get("assists", 0))
			var sb := int(b.get("kills", 0)) + int(b.get("assists", 0))
			if sa != sb:
				return sa > sb
			return float(a.get("damage", 0.0)) > float(b.get("damage", 0.0)))
		t.set_rows(mine, local_id)


## Normalizes a match-end "stats" array (PlayerStats.to_dict + id/name/team/hero/bot) into rows.
static func rows_from_stats(stats: Array) -> Array:
	var out: Array = []
	for s: Variant in stats:
		var d: Dictionary = s
		out.append({
			"id": int(d.get("id", 0)), "name": String(d.get("name", "?")), "team": int(d.get("team", 0)),
			"hero": StringName(String(d.get("hero", ""))), "bot": bool(d.get("bot", false)),
			"kills": int(d.get("kills", 0)), "deaths": int(d.get("deaths", 0)), "assists": int(d.get("assists", 0)),
			"damage": float(d.get("damage", 0.0)), "healing": float(d.get("healing", 0.0)), "mitigated": float(d.get("mitigated", 0.0)),
			"objective_time": float(d.get("objective_time", 0.0)), "ults_used": int(d.get("ults_used", 0)),
			"best_streak": int(d.get("best_streak", 0)), "ping": int(d.get("ping", -1)),
		})
	return out


## Rows from the live client: roster (names / heroes / pings) merged with each pawn's stats.
static func rows_from_live(client: GameClient) -> Array:
	var out: Array = []
	if client == null:
		return out
	for r: Variant in client.roster:
		var d: Dictionary = r
		var is_bot := bool(d.get("bot", false))
		var row := {
			"id": int(d.get("id", 0)), "name": String(d.get("name", "?")), "team": int(d.get("team", 0)),
			"hero": StringName(String(d.get("hero", ""))), "bot": is_bot,
			"kills": 0, "deaths": 0, "assists": 0, "damage": 0.0, "healing": 0.0, "mitigated": 0.0,
			"objective_time": 0.0, "ults_used": 0, "best_streak": 0,
			"ping": -1 if is_bot else int(d.get("ping", 0)),
		}
		var p: Pawn = client.world.get_pawn(int(d.get("net_id", -1))) if client.world else null
		if p and is_instance_valid(p) and p.stats:
			var st := p.stats
			row["kills"] = st.kills; row["deaths"] = st.deaths; row["assists"] = st.assists
			row["damage"] = st.damage; row["healing"] = st.healing; row["mitigated"] = st.mitigated
			row["objective_time"] = st.objective_time; row["ults_used"] = st.ults_used
			row["best_streak"] = st.best_streak
		out.append(row)
	return out


static func format_time(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


## Small role glyph: Bulwark = shield, Striker = diamond, Conduit = cross.
static func draw_role_glyph(ci: CanvasItem, c: Vector2, role: int, r: float, col: Color) -> void:
	match role:
		RF.Role.BULWARK:
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - r, c.y - r * 0.85), Vector2(c.x + r, c.y - r * 0.85),
				Vector2(c.x + r, c.y + r * 0.15), Vector2(c.x, c.y + r), Vector2(c.x - r, c.y + r * 0.15)]), col)
		RF.Role.STRIKER:
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x, c.y - r), Vector2(c.x + r, c.y), Vector2(c.x, c.y + r), Vector2(c.x - r, c.y)]), col)
			ci.draw_circle(c, r * 0.28, UITheme.BG)
		RF.Role.CONDUIT:
			ci.draw_rect(Rect2(c.x - r * 0.3, c.y - r, r * 0.6, r * 2.0), col)
			ci.draw_rect(Rect2(c.x - r, c.y - r * 0.3, r * 2.0, r * 0.6), col)
		_:
			ci.draw_circle(c, r * 0.6, col)


## A horizontal legend of the three role glyphs.
static func make_legend(font_size: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for role in 3:
		var g := RoleGlyph.new()
		g.role = role
		g.custom_minimum_size = Vector2(18, 18)
		h.add_child(g)
		var l := UITheme.label(RF.role_name(role).to_upper(), font_size, UITheme.TEXT_DIM, true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
	return h


class RoleGlyph extends Control:
	var role: int = 0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		ScoreboardPanel.draw_role_glyph(self, size * 0.5, role, minf(size.x, size.y) * 0.4, UITheme.role_color(role))


class TeamTable extends Control:
	var team: int = 0
	var rows: Array = []
	var local_id: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_update_size()

	func set_rows(r: Array, lid: int) -> void:
		rows = r
		local_id = lid
		_update_size()
		queue_redraw()

	func _update_size() -> void:
		var n := maxi(rows.size(), ScoreboardPanel.MIN_ROWS)
		custom_minimum_size = Vector2(ScoreboardPanel.total_width(), ScoreboardPanel.TEAM_HEAD_H + ScoreboardPanel.HEAD_H + n * ScoreboardPanel.ROW_H + 8.0)

	func _baseline(y: float, h: float, font: Font, sz: int) -> float:
		return y + (h - (font.get_ascent(sz) + font.get_descent(sz))) * 0.5 + font.get_ascent(sz)

	func _draw() -> void:
		var w := size.x
		var col := UITheme.team_color_ui(team)
		var font := UITheme.font()
		var narrow := UITheme.font_narrow()
		var pad := ScoreboardPanel.PAD
		var team_h := ScoreboardPanel.TEAM_HEAD_H
		var head_h := ScoreboardPanel.HEAD_H
		var row_h := ScoreboardPanel.ROW_H
		# Panel ground
		draw_rect(Rect2(0, 0, w, size.y), UITheme.PANEL)
		draw_rect(Rect2(0, 0, w, size.y), UITheme.LINE, false, 1.0)
		# Team header: color bar, name, totals
		draw_rect(Rect2(0, 0, w, team_h), Color(col.r, col.g, col.b, 0.14))
		draw_rect(Rect2(0, 0, 5, team_h), col)
		draw_string(font, Vector2(pad + 4, _baseline(0, team_h, font, 18)), RF.team_name(team).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
		var kills := 0
		var dmg := 0.0
		for r: Variant in rows:
			kills += int((r as Dictionary).get("kills", 0))
			dmg += float((r as Dictionary).get("damage", 0.0))
		var totals := "%d ELIMS   ·   %s DMG   ·   %d RUNNERS" % [kills, _fmt_num(dmg), rows.size()]
		draw_string(narrow, Vector2(pad, _baseline(0, team_h, narrow, 13)), totals, HORIZONTAL_ALIGNMENT_RIGHT, w - pad * 2.0, 13, UITheme.TEXT_DIM)
		# Column headers
		var y := team_h
		var x := pad
		draw_line(Vector2(0, y + head_h), Vector2(w, y + head_h), UITheme.LINE, 1.0)
		for c: Array in ScoreboardPanel.COLS:
			var cw := float(c[1])
			draw_string(narrow, Vector2(x, _baseline(y, head_h, narrow, 12)), String(c[0]), int(c[2]), cw - 8.0, 12, UITheme.TEXT_DIM)
			x += cw
		y += head_h
		# Rows
		var n := maxi(rows.size(), ScoreboardPanel.MIN_ROWS)
		for i in n:
			var ry := y + i * row_h
			if i % 2 == 1:
				draw_rect(Rect2(0, ry, w, row_h), Color(1, 1, 1, 0.025))
			if i >= rows.size():
				draw_string(narrow, Vector2(pad, _baseline(ry, row_h, narrow, 13)), "— open slot —", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(UITheme.TEXT_DIM, 0.45))
				continue
			var r: Dictionary = rows[i]
			var is_local := int(r.get("id", -2)) == local_id and local_id != -1
			var is_bot := bool(r.get("bot", false))
			if is_local:
				draw_rect(Rect2(0, ry, w, row_h), Color(UITheme.AMBER, 0.13))
				draw_rect(Rect2(0, ry, 3, row_h), UITheme.AMBER)
			x = pad
			var hero := Registry.hero(StringName(String(r.get("hero", ""))))
			# Hero column: swatch + role glyph + name
			var hcol: Color = hero.theme_color if hero else Color(UITheme.TEXT_DIM, 0.5)
			draw_rect(Rect2(x, ry + 6, 6, row_h - 12), hcol)
			if hero:
				ScoreboardPanel.draw_role_glyph(self, Vector2(x + 22, ry + row_h * 0.5), hero.role, 6.5, UITheme.role_color(hero.role))
			var hname := hero.display_name.to_upper() if hero else "—"
			draw_string(font, Vector2(x + 36, _baseline(ry, row_h, font, 14)), hname, HORIZONTAL_ALIGNMENT_LEFT, float(ScoreboardPanel.COLS[0][1]) - 44.0, 14, UITheme.TEXT if hero else UITheme.TEXT_DIM)
			x += float(ScoreboardPanel.COLS[0][1])
			# Player column
			var pname := String(r.get("name", "?"))
			var ncol := UITheme.AMBER if is_local else (UITheme.TEXT_DIM if is_bot else UITheme.TEXT)
			var name_w := float(ScoreboardPanel.COLS[1][1]) - 8.0
			draw_string(font, Vector2(x, _baseline(ry, row_h, font, 15)), pname, HORIZONTAL_ALIGNMENT_LEFT, name_w - (34.0 if is_bot else 0.0), 15, ncol)
			if is_bot:
				var tw := minf(font.get_string_size(pname, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, name_w - 34.0)
				var tag := Rect2(x + tw + 8.0, ry + 9, 26, row_h - 18)
				draw_rect(tag, Color(UITheme.TEXT_DIM, 0.18))
				draw_string(narrow, Vector2(tag.position.x, _baseline(tag.position.y, tag.size.y, narrow, 9)), "BOT", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 9, UITheme.TEXT_DIM)
			x += float(ScoreboardPanel.COLS[1][1])
			# Numbers
			var cells := [
				[str(int(r.get("kills", 0))), font, 15, UITheme.TEXT],
				[str(int(r.get("deaths", 0))), font, 15, UITheme.TEXT],
				[str(int(r.get("assists", 0))), font, 15, UITheme.TEXT],
				[_fmt_num(float(r.get("damage", 0.0))), narrow, 14, UITheme.TEXT],
				[_fmt_num(float(r.get("healing", 0.0))), narrow, 14, UITheme.TEXT],
				[_fmt_num(float(r.get("mitigated", 0.0))), narrow, 14, UITheme.TEXT],
				[ScoreboardPanel.format_time(float(r.get("objective_time", 0.0))), narrow, 14, UITheme.TEXT],
				[str(int(r.get("ults_used", 0))), narrow, 14, UITheme.TEXT],
			]
			for ci in cells.size():
				var cell: Array = cells[ci]
				var cw := float(ScoreboardPanel.COLS[2 + ci][1])
				draw_string(cell[1], Vector2(x, _baseline(ry, row_h, cell[1], int(cell[2]))), String(cell[0]), HORIZONTAL_ALIGNMENT_RIGHT, cw - 8.0, int(cell[2]), cell[3])
				x += cw
			# Ping
			var ping := int(r.get("ping", -1))
			var pcol := UITheme.TEXT_DIM
			var ptxt := "—"
			if ping >= 0 and not is_bot:
				ptxt = str(ping)
				pcol = UITheme.GOOD if ping < 60 else (UITheme.AMBER if ping < 120 else UITheme.DANGER)
			draw_string(narrow, Vector2(x, _baseline(ry, row_h, narrow, 14)), ptxt, HORIZONTAL_ALIGNMENT_RIGHT, float(ScoreboardPanel.COLS[10][1]) - 8.0, 14, pcol)
			draw_line(Vector2(pad, ry + row_h), Vector2(w - pad, ry + row_h), UITheme.LINE, 1.0)

	func _fmt_num(v: float) -> String:
		if v >= 10000.0:
			return "%.1fk" % (v / 1000.0)
		return str(int(round(v)))
