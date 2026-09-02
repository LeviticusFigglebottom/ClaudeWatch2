extends Deployable
## Wisp's Mark: an indestructible waypoint glyph (health 0 = cannot be shot) that lives 20 s.
## WispMarkBehavior tracks its position and swaps Wisp with it on the second press.


func on_placed() -> void:
	targetable = false
	if visual_id == &"":
		visual_id = &"wisp_marker"
