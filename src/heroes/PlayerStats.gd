class_name PlayerStats
extends RefCounted
## Per-player match statistics (persist across deaths and hero swaps within a match).

var kills: int = 0
var final_blows: int = 0
var deaths: int = 0
var assists: int = 0
var damage: float = 0.0
var healing: float = 0.0
var damage_taken: float = 0.0
var mitigated: float = 0.0
var ults_used: int = 0
var objective_time: float = 0.0
var objective_kills: int = 0
var solo_kills: int = 0
var best_streak: int = 0
var time_alive: float = 0.0
var hero_time: Dictionary = {}   # hero id -> seconds
var shots_fired: int = 0
var shots_hit: int = 0
var headshots: int = 0
var ult_charge_time: float = 0.0 # seconds spent with ult ready (uptime telemetry)


func to_dict() -> Dictionary:
	return {
		"kills": kills, "final_blows": final_blows, "deaths": deaths, "assists": assists,
		"damage": damage, "healing": healing, "damage_taken": damage_taken, "mitigated": mitigated,
		"ults_used": ults_used, "objective_time": objective_time, "objective_kills": objective_kills,
		"solo_kills": solo_kills, "best_streak": best_streak, "time_alive": time_alive,
		"hero_time": hero_time, "shots_fired": shots_fired, "shots_hit": shots_hit,
		"headshots": headshots, "ult_charge_time": ult_charge_time,
	}


func accuracy() -> float:
	return 0.0 if shots_fired == 0 else float(shots_hit) / float(shots_fired)
