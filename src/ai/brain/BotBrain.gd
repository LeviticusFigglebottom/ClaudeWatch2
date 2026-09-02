class_name BotBrain
extends RefCounted
## The per-bot mind: perception -> beliefs -> utility decision -> movement + aim -> InputCmd.
## Implemented in full in src/ai/brain/*.gd; this file is the composition root.

var controller: BotController
var pawn: Pawn
var server: GameServer
var world: SimWorld
var perception: BotPerception
var aim: AimModel
var nav: BotNavigator
var decision: BotDecision
var skill: BotSkillProfile
var rng := RandomNumberGenerator.new()
var cmd := InputCmd.new()
var target: Pawn
var desired_yaw: float = 0.0
var desired_pitch: float = 0.0
var move_target: Vector3
var strafe_phase: float = 0.0
var tick_count: int = 0
var last_think_ms: float = 0.0
var yaw: float = 0.0
var pitch: float = 0.0


func setup(c: BotController) -> void:
	controller = c
	server = c.server
	world = server.world
	rng.seed = hash(str(server.config.seed, c.player.id))
	skill = BotSkillProfile.for_tier(c.difficulty, rng)
	perception = BotPerception.new()
	perception.setup(self)
	aim = AimModel.new()
	aim.setup(self)
	nav = BotNavigator.new()
	nav.setup(self)
	decision = BotDecision.new()
	decision.setup(self)


func on_pawn_attached(p: Pawn) -> void:
	pawn = p
	yaw = p.yaw
	pitch = 0.0
	perception.reset()
	aim.reset()
	nav.reset()
	decision.reset()


func on_died() -> void:
	decision.on_died()


func think(dt: float, tick: int) -> InputCmd:
	tick_count += 1
	cmd = InputCmd.new()
	cmd.tick = tick
	if pawn == null or not pawn.alive:
		cmd.yaw = yaw; cmd.pitch = pitch
		return cmd
	perception.update(dt)
	decision.update(dt)
	nav.update(dt)
	aim.update(dt)
	# Finalize buttons/edges from the decision + aim layers.
	cmd.yaw = yaw
	cmd.pitch = pitch
	cmd.pressed = cmd.buttons & ~pawn.last_cmd.buttons
	cmd.released = pawn.last_cmd.buttons & ~cmd.buttons
	cmd.render_tick = tick   # bots see the present; no lag comp needed
	return cmd
