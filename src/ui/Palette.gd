class_name Palette
## Team color palettes including colorblind-safe alternatives.

static func team_color(team: int, mode: int = 0) -> Color:
	match mode:
		1, 2:   # deuteranopia / protanopia: orange vs blue stays distinguishable; push blue toward cyan
			return Color(0.98, 0.6, 0.15) if team == RF.Team.A else Color(0.25, 0.75, 1.0)
		3:      # tritanopia: red vs teal
			return Color(0.95, 0.3, 0.35) if team == RF.Team.A else Color(0.2, 0.85, 0.8)
	return RF.team_color(team)


static func friendly(mode: int = 0) -> Color:
	return Color(0.35, 0.75, 1.0) if mode != 3 else Color(0.2, 0.85, 0.8)


static func enemy(mode: int = 0) -> Color:
	return Color(0.95, 0.35, 0.3) if mode != 3 else Color(0.95, 0.5, 0.2)
