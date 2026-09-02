extends AbilityBehavior
## Ballast Surge: while active the pressure suit over-pressurizes: +150 bonus armor (removed on end)
## and 60% move speed (the slow comes from self_status_while_active in data). Armor is authoritative
## health state, so only the server grants/removes it.

const BONUS_ARMOR := 150.0

var granted: bool = false


func on_activate(ctx: AbilityContext) -> void:
	if ctx.is_server and not granted:
		pawn.health.grant_bonus_armor(BONUS_ARMOR)
		granted = true


func on_end(_ctx: AbilityContext, _cancelled: bool) -> void:
	if granted:
		pawn.health.remove_bonus_armor(BONUS_ARMOR)
		granted = false
