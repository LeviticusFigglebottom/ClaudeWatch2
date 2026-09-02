class_name UITheme
## The game's UI identity: deep navy ground, amber accent, cool team blue, clean geometric type.
## Built in code so every screen shares one source of truth.

const BG := Color(0.055, 0.065, 0.09)
const PANEL := Color(0.09, 0.105, 0.14, 0.92)
const PANEL_LIGHT := Color(0.14, 0.16, 0.21, 0.95)
const AMBER := Color(0.98, 0.72, 0.22)
const AMBER_DIM := Color(0.6, 0.45, 0.16)
const TEXT := Color(0.93, 0.94, 0.96)
const TEXT_DIM := Color(0.62, 0.66, 0.72)
const DANGER := Color(0.95, 0.3, 0.28)
const GOOD := Color(0.35, 0.9, 0.5)
const LINE := Color(1, 1, 1, 0.08)

static var _theme: Theme
static var _font: FontFile
static var _font_narrow: FontFile
static var _font_mono: FontFile


static func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/KenneyFuture.ttf") as FontFile
	return _font


static func font_narrow() -> FontFile:
	if _font_narrow == null:
		_font_narrow = load("res://assets/fonts/KenneyFutureNarrow.ttf") as FontFile
		if _font_narrow == null:
			_font_narrow = font()
	return _font_narrow


static func font_mono() -> FontFile:
	if _font_mono == null:
		_font_mono = load("res://assets/fonts/KenneyMini.ttf") as FontFile
		if _font_mono == null:
			_font_mono = font()
	return _font_mono


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	# Buttons
	var b := StyleBoxFlat.new()
	b.bg_color = PANEL_LIGHT
	b.border_color = LINE
	b.set_border_width_all(1)
	b.set_corner_radius_all(3)
	b.content_margin_left = 18; b.content_margin_right = 18; b.content_margin_top = 8; b.content_margin_bottom = 8
	var bh := b.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.2, 0.22, 0.28)
	bh.border_color = AMBER
	var bp := b.duplicate() as StyleBoxFlat
	bp.bg_color = AMBER
	var bd := b.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.1, 0.11, 0.14, 0.6)
	var bf := bh.duplicate() as StyleBoxFlat
	bf.border_color = AMBER
	bf.set_border_width_all(2)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", bf)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", BG)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	# Panels
	var p := StyleBoxFlat.new()
	p.bg_color = PANEL
	p.border_color = LINE
	p.set_border_width_all(1)
	p.set_corner_radius_all(4)
	p.content_margin_left = 16; p.content_margin_right = 16; p.content_margin_top = 12; p.content_margin_bottom = 12
	t.set_stylebox("panel", "PanelContainer", p)
	t.set_stylebox("panel", "Panel", p)
	# Labels
	t.set_color("font_color", "Label", TEXT)
	# LineEdit
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.03, 0.035, 0.05)
	le.border_color = LINE
	le.set_border_width_all(1)
	le.set_corner_radius_all(3)
	le.content_margin_left = 10; le.content_margin_right = 10; le.content_margin_top = 6; le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	var lef := le.duplicate() as StyleBoxFlat
	lef.border_color = AMBER
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", TEXT)
	# Sliders
	var sl := StyleBoxFlat.new(); sl.bg_color = Color(0.2, 0.22, 0.27); sl.set_corner_radius_all(2)
	sl.content_margin_top = 3; sl.content_margin_bottom = 3
	var slf := StyleBoxFlat.new(); slf.bg_color = AMBER; slf.set_corner_radius_all(2)
	t.set_stylebox("slider", "HSlider", sl)
	t.set_stylebox("grabber_area", "HSlider", slf)
	t.set_stylebox("grabber_area_highlight", "HSlider", slf)
	# Progress bars
	var pb := StyleBoxFlat.new(); pb.bg_color = Color(0.1, 0.11, 0.14); pb.set_corner_radius_all(2)
	var pbf := StyleBoxFlat.new(); pbf.bg_color = AMBER; pbf.set_corner_radius_all(2)
	t.set_stylebox("background", "ProgressBar", pb)
	t.set_stylebox("fill", "ProgressBar", pbf)
	# Tabs / option buttons / checkboxes reuse button styling
	t.set_stylebox("normal", "OptionButton", b)
	t.set_stylebox("hover", "OptionButton", bh)
	t.set_stylebox("pressed", "OptionButton", bp)
	t.set_stylebox("focus", "OptionButton", bf)
	t.set_color("font_color", "OptionButton", TEXT)
	t.set_color("font_color", "CheckBox", TEXT)
	t.set_color("font_color", "CheckButton", TEXT)
	var pm := StyleBoxFlat.new(); pm.bg_color = PANEL_LIGHT; pm.border_color = LINE; pm.set_border_width_all(1)
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", AMBER)
	_theme = t
	return t


static func label(text: String, size: int = 18, color: Color = TEXT, narrow: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if narrow:
		l.add_theme_font_override("font", font_narrow())
	return l


static func heading(text: String, size: int = 42) -> Label:
	var l := label(text.to_upper(), size, AMBER)
	l.add_theme_constant_override("outline_size", 0)
	return l


static func button(text: String, size: int = 20, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.add_theme_font_size_override("font_size", size)
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.focus_mode = Control.FOCUS_ALL
	return b


static func panel(margin: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := (theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.content_margin_left = margin; sb.content_margin_right = margin; sb.content_margin_top = margin; sb.content_margin_bottom = margin
	p.add_theme_stylebox_override("panel", sb)
	return p


static func separator() -> HSeparator:
	var s := HSeparator.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = LINE
	sb.content_margin_top = 1; sb.content_margin_bottom = 1
	s.add_theme_stylebox_override("separator", sb)
	return s


static func role_color(role: int) -> Color:
	match role:
		RF.Role.BULWARK: return Color(0.55, 0.7, 0.98)
		RF.Role.STRIKER: return Color(0.98, 0.5, 0.35)
		RF.Role.CONDUIT: return Color(0.45, 0.92, 0.6)
	return TEXT


static func team_color_ui(team: int) -> Color:
	var mode := int(Settings.get_value(&"accessibility", "colorblind_mode"))
	return Palette.team_color(team, mode)
