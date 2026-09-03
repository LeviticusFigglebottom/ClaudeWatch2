class_name MatchTelemetry
extends RefCounted
## Collects balance telemetry during a match and writes JSON at the end (sim harness + dev).

var server: GameServer
var kills: Array = []            # {tick, killer_hero, victim_hero, ability, headshot}
var ult_uses: Array = []         # {tick, hero, team}
var ttk_samples: Array = []      # seconds from first damage instance to death per victim life
var first_damage_tick: Dictionary = {}   # net_id -> tick
var elapsed: float = 0.0
var damage_by_hero: Dictionary = {}
var healing_by_hero: Dictionary = {}
var ult_uptime_by_hero: Dictionary = {}
var objective_time_by_hero: Dictionary = {}
var objective_track: Array = []   # {t, contest_a, contest_b, ...mode progress} sampled every SAMPLE_S
var _uptime_accum: float = 0.0
var _track_accum: float = 0.0

const TRACK_SAMPLE_S := 5.0
## hud_state() keys worth keeping: how far the objective has actually travelled.
const TRACK_KEYS: Array[String] = ["push_progress", "barrier_a", "barrier_b", "payload_progress",
	"checkpoint", "capture_a", "capture_b", "point_owner", "pusher_team", "contested", "phase"]


func setup(s: GameServer) -> void:
	server = s


func step(dt: float) -> void:
	elapsed += dt
	_uptime_accum += dt
	if _uptime_accum >= 1.0:
		_uptime_accum = 0.0
		for ps: PlayerState in server.players.values():
			if ps.pawn and ps.pawn.alive:
				var h := ps.hero_id
				if ps.pawn.ult_fraction() >= 1.0:
					ult_uptime_by_hero[h] = float(ult_uptime_by_hero.get(h, 0.0)) + 1.0
				if ps.pawn.on_objective:
					objective_time_by_hero[h] = float(objective_time_by_hero.get(h, 0.0)) + 1.0
					ps.stats.objective_time += 1.0
	_track_accum += dt
	if _track_accum >= TRACK_SAMPLE_S and server.mode:
		_track_accum = 0.0
		var row := {"t": roundf(elapsed)}
		if server.mode.contest_count.size() >= 2:
			row["contest_a"] = server.mode.contest_count[0]
			row["contest_b"] = server.mode.contest_count[1]
		var hs := server.mode.hud_state()
		for k: String in TRACK_KEYS:
			if hs.has(k):
				var v: Variant = hs[k]
				row[k] = snappedf(float(v), 0.001) if v is float else v
		objective_track.append(row)


func on_event(kind: StringName, pl: Dictionary) -> void:
	match kind:
		&"damage":
			var tgt := int(pl["tgt"])
			if not first_damage_tick.has(tgt):
				first_damage_tick[tgt] = server.tick
			var src := server.world.get_pawn(int(pl["src"]))
			if src:
				damage_by_hero[src.hero_id()] = float(damage_by_hero.get(src.hero_id(), 0.0)) + float(pl["amt"])
		&"heal":
			var src := server.world.get_pawn(int(pl["src"]))
			if src:
				healing_by_hero[src.hero_id()] = float(healing_by_hero.get(src.hero_id(), 0.0)) + float(pl["amt"])
		&"kill":
			var v := server.world.get_pawn(int(pl["victim"]))
			var k := server.world.get_pawn(int(pl["killer"]))
			var vid := int(pl["victim"])
			if first_damage_tick.has(vid):
				ttk_samples.append((server.tick - int(first_damage_tick[vid])) * RF.TICK_DT)
				first_damage_tick.erase(vid)
			kills.append({"t": server.tick, "killer": k.hero_id() if k else &"", "victim": v.hero_id() if v else &"",
				"killer_team": k.team if k else -1, "ability": String(pl.get("ability", "")), "hs": pl.get("headshot", false)})
		&"ability":
			if pl.get("phase", &"") == &"activate" and pl.get("ult", false):
				var p := server.world.get_pawn(int(pl["pawn"]))
				if p:
					ult_uses.append({"t": server.tick, "hero": p.hero_id(), "team": p.team})
		&"heal_prevented", &"damage_prevented":
			pass


func finish(summary: Dictionary) -> void:
	var out := {
		"map": server.config.map_id, "mode": server.config.mode_id, "winner": summary.get("winner", -1),
		"score": summary.get("score", []), "elapsed": elapsed, "difficulty": server.config.bot_difficulty,
		"seed": server.config.seed, "teams": _team_comps(), "players": summary.get("stats", []),
		"kills": kills, "ult_uses": ult_uses, "ttk": ttk_samples,
		"damage_by_hero": damage_by_hero, "healing_by_hero": healing_by_hero,
		"ult_uptime_by_hero": ult_uptime_by_hero, "objective_time_by_hero": objective_time_by_hero,
		"objective_track": objective_track,
		"rounds": summary.get("rounds", []),
	}
	var path := server.config.telemetry_path
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(out))
			f.close()
	server.set_meta("telemetry", out)


func _team_comps() -> Array:
	var comps: Array = [[], []]
	for ps: PlayerState in server.players.values():
		(comps[ps.team] as Array).append(String(ps.hero_id))
	return comps
