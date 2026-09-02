extends AbilityBehavior
## Capacitor: for 1.5 s every hit Coil takes is absorbed into a charge counter (CoilBehavior's
## modify_incoming_damage does the absorbing on the server). When the window ends — by timer, by
## CC cancel or by re-press — the stored damage (capped at 250) is released as a 5 m burst.
## Nothing stored, nothing released: only the discharge ring plays.

const MAX_RELEASE := 250.0
const RADIUS := 5.0

var _burst: AreaEffect


func setup(a: Ability, p: Pawn) -> void:
	super.setup(a, p)
	_burst = AreaEffect.new()
	_burst.radius = RADIUS
	_burst.damage = 0.0
	_burst.min_fraction = 0.6
	_burst.knockback = 5.0
	_burst.requires_los = true
	_burst.damage_type = RF.DamageType.SPLASH
	_burst.vfx_id = &"coil_capacitor_explosion"


func on_activate(_ctx: AbilityContext) -> void:
	var hb := pawn.behavior
	if hb and hb.has_method("begin_capacitor"):
		hb.call("begin_capacitor")


func on_end(ctx: AbilityContext, _cancelled: bool) -> void:
	var stored := 0.0
	var hb := pawn.behavior
	if hb and hb.has_method("end_capacitor"):
		stored = float(hb.call("end_capacitor"))
	if not pawn.alive:
		return
	_burst.damage = minf(stored, MAX_RELEASE)
	ctx.point = pawn.center()
	if ctx.is_server:
		_burst.apply(ctx)
	else:
		_burst.predict(ctx)
