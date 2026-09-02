extends HeroBehavior
## Ballast passive "Reel Them In": for 2 s after Anchor hooks an enemy, Ballast's Wave Cannon deals
## +25% to that enemy. Rewards the signature loop: hook -> point blank -> shotgun.

const BONUS_WINDOW := 2.0
const BONUS_MULT := 1.25

var hooked: Pawn
var hooked_until_tick: int = -1


func note_hook(target: Pawn) -> void:
	hooked = target
	hooked_until_tick = pawn.world.tick + int(BONUS_WINDOW / RF.TICK_DT)


func modify_outgoing_damage(ev: DamageEvent) -> void:
	if hooked == null or ev.target != hooked:
		return
	if pawn.world.tick > hooked_until_tick:
		hooked = null
		return
	if ev.ability_id == &"ballast_wave" or ev.ability_id == &"ballast_slug":
		ev.amount *= BONUS_MULT


func on_death(_killer: Pawn) -> void:
	hooked = null
