class_name PlayerState
extends RefCounted
## Server-side record of a participant (human or bot).

var id: int = 0                 # player id (peer id for humans, negative for bots)
var peer: int = 0               # network peer (0 for bots)
var name: String = "Runner"
var team: int = RF.Team.A
var hero_id: StringName = &""
var pending_hero_id: StringName = &""   # swap applied at next spawn
var pawn: Pawn
var is_bot: bool = false
var bot: Node                   # BotController
var connected: bool = true
var ready: bool = false
var respawn_at_tick: int = -1
var stats: PlayerStats = PlayerStats.new()
var ult_charge_carry: float = 0.0
var last_input_tick: int = -1
var input_queue: Dictionary = {}       # tick -> InputCmd
var last_cmd: InputCmd = InputCmd.new()
var acked_snapshot: int = 0
var sent_baselines: Dictionary = {}    # snapshot_id -> Dictionary(net_id -> captured fields)
var baseline_order: Array[int] = []
var last_ack_time: float = 0.0
var ping_ms: float = 0.0
var input_lead_accum: int = 0
var input_lead_count: int = 0
var session_token: int = 0
var join_tick: int = 0
var missed_inputs: int = 0
var bytes_sent: int = 0
var events_pending: Array = []
var wants_spawn: bool = true
var spectating: bool = false
var hero_time_start_tick: int = 0
var highlight_score: float = 0.0


func display() -> String:
	return "%s%s" % [name, " [bot]" if is_bot else ""]
