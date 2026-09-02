class_name BotController
extends Node
## Server-side bot. Produces an InputCmd every tick exactly like a remote client would.
## The full brain (perception, aim model, utility, coordinator hooks) lives in src/ai/brain/.

var server: GameServer
var player: PlayerState
var pawn: Pawn
var difficulty: int = 2
var brain: BotBrain
var _cmd: InputCmd = InputCmd.new()


func setup(s: GameServer, ps: PlayerState, diff: int) -> void:
	server = s
	player = ps
	difficulty = diff
	brain = BotBrain.new()
	brain.setup(self)


func attach_pawn(p: Pawn) -> void:
	pawn = p
	if brain:
		brain.on_pawn_attached(p)


func think(dt: float, tick: int) -> InputCmd:
	if pawn == null or not pawn.alive:
		var c := InputCmd.empty(tick)
		c.yaw = pawn.yaw if pawn else 0.0
		return c
	return brain.think(dt, tick)


func on_died() -> void:
	if brain:
		brain.on_died()


func team() -> int:
	return player.team


func coordinator() -> TeamCoordinator:
	return server.coordinators[player.team]
