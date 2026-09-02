class_name MatchConfig
extends RefCounted
## What a server needs to run a match.

var map_id: StringName = &"saltmarsh"
var mode_id: StringName = &""
var bot_count: int = 9            # bots to add at start (fills both teams around humans)
var bot_fill: bool = true         # backfill leavers / keep teams full
var bot_difficulty: int = 2       # 0..3
var local: bool = true            # offline single-process match
var max_players: int = 10
var team_size: int = 5
var skip_setup: bool = false
var time_scale: float = 1.0
var seed: int = 0
var sim_mode: bool = false        # no humans expected; run to completion and report
var match_time_limit: float = 0.0 # sim: hard cap in seconds (0 = mode decides)
var bot_hero_lock: Dictionary = {} # team -> Array[StringName] forced heroes (sim)
var telemetry_path: String = ""
var human_team: int = -1          # -1 = auto (team A)
var respawn_scale: float = 1.0
var allow_hero_duplicates: bool = false


func to_dict() -> Dictionary:
	return {"map": map_id, "mode": mode_id, "bots": bot_count, "fill": bot_fill, "difficulty": bot_difficulty,
		"local": local, "max_players": max_players, "team_size": team_size, "seed": seed, "sim": sim_mode}
