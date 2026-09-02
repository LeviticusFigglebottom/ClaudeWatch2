extends AbilityBehavior
## Mark (press-toggle). First press: drop a marker at Wisp's feet. Second press: Exchange with it —
## Wisp teleports to the marker and the marker moves to where she stood, so she can bounce between
## the two spots until the marker expires (20 s from the first placement) or she dies.
## The teleport runs on server and predicting client; the marker deployable exists on the server
## only, so the client mirrors the marker's position/expiry locally. If enemies never see the
## marker die early (it is indestructible) both sides stay in sync.

const LIFETIME := 20.0
const KIND := &"wisp_marker"

var has_marker: bool = false
var marker_pos: Vector3 = Vector3.ZERO
var placed_tick: int = -1
var _teleport: TeleportEffect
var _deploy: DeployEffect


func setup(a: Ability, p: Pawn) -> void:
	super.setup(a, p)
	_teleport = TeleportEffect.new()
	_teleport.to_point = true
	_teleport.keep_velocity = false
	_deploy = DeployEffect.new()
	_deploy.kind = KIND
	_deploy.visual_id = &"wisp_marker"
	_deploy.placement = DeployEffect.Placement.AT_FEET
	_deploy.lifetime = LIFETIME
	_deploy.health = 0.0
	_deploy.max_instances = 1
	_deploy.deployable_script = load("res://src/heroes/deployables/WispMarker.gd")


func _sync(ctx: AbilityContext) -> void:
	if not has_marker:
		return
	var expired := (ctx.tick - placed_tick) * RF.TICK_DT >= LIFETIME
	var respawned := pawn.spawn_tick > placed_tick
	if expired or respawned:
		has_marker = false
		if ctx.is_server:
			for d: Deployable in ctx.world.deployables_of(pawn, KIND):
				d.destroy(null)
		return
	if ctx.is_server and ctx.world.deployables_of(pawn, KIND).is_empty():
		has_marker = false


func on_fire(ctx: AbilityContext) -> void:
	_sync(ctx)
	if has_marker:
		var dest := marker_pos
		var old := pawn.global_position
		var elapsed := (ctx.tick - placed_tick) * RF.TICK_DT
		if ctx.is_server:
			# Re-place the marker where she stands now (max_instances=1 retires the old one), keeping
			# the original expiry, then move her to where the old marker was.
			_deploy.apply(ctx)
			var d := ctx.data.get("deployable") as Deployable
			if d:
				d.lifetime = maxf(LIFETIME - elapsed, 0.5)
		marker_pos = old
		ctx.point = dest
		if ctx.is_server:
			_teleport.apply(ctx)
		else:
			_teleport.predict(ctx)
		ctx.data["wisp_exchanged"] = true
	else:
		marker_pos = pawn.global_position
		has_marker = true
		placed_tick = ctx.tick
		if ctx.is_server:
			_deploy.apply(ctx)
		ctx.data["wisp_marked"] = true
