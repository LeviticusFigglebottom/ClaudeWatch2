class_name ReplayRecorder
extends RefCounted
## Records pawn poses + events into a ring buffer (last ~90 s) and scores highlight windows for
## Play of the Game. The best 9-second window is shipped to clients at match end and replayed
## through the same interpolation path used for live remote pawns.

const KEEP_SECONDS := 90.0
const WINDOW := 9.0
const KILLCAM_LEAD := 3.2      # seconds of the killer's view before the fatal blow
const KILLCAM_TRAIL := 0.8     # and just after, so the kill itself is on screen

var server: GameServer
var frames: Array = []          # [tick, {net_id: {pos, yaw, pitch, flags, anim, hero, team}}]
var events: Array = []          # [tick, kind, payload]
var scores: Dictionary = {}     # player id -> Array of [tick, points]
var _accum: int = 0
var best: Dictionary = {}


func setup(s: GameServer) -> void:
	server = s


func step(tick: int) -> void:
	if tick % 3 != 0:
		return   # 20 Hz is plenty for a replay
	var poses: Dictionary = {}
	for p: Pawn in server.world.pawns.values():
		poses[p.net_id] = {"pos": p.global_position, "yaw": p.yaw, "pitch": p.pitch, "alive": p.alive,
			"crouch": p.movement.crouch_amount, "hero": p.hero_id(), "team": p.team, "name": p.display_name, "player": p.player_id}
	frames.append([tick, poses])
	var keep := int(KEEP_SECONDS * RF.TICK_RATE)
	while not frames.is_empty() and tick - int(frames[0][0]) > keep:
		frames.pop_front()
	while not events.is_empty() and tick - int(events[0][0]) > keep:
		events.pop_front()


func on_event(kind: StringName, pl: Dictionary) -> void:
	var t := server.tick
	match kind:
		&"kill", &"ability", &"hitscan", &"projectile_spawn", &"projectile_impact", &"damage", &"heal", &"area", &"beam", &"melee", &"deployable_spawn", &"deployable_destroy", &"status", &"teleport":
			events.append([t, kind, pl.duplicate()])
	# Highlight scoring
	if kind == &"kill":
		var k := server.world.get_pawn(int(pl["killer"]))
		var v := server.world.get_pawn(int(pl["victim"]))
		if k and v and k != v:
			var pts := 100.0
			if k.hero.role == RF.Role.CONDUIT: pts += 40.0    # supports get less killing chances
			if pl.get("headshot", false): pts += 20.0
			if v.hero.role == RF.Role.BULWARK: pts += 10.0
			_add_score(k.player_id, t, pts)
			for a: Variant in pl.get("assists", []):
				var ap := server.world.get_pawn(int(a))
				if ap: _add_score(ap.player_id, t, 35.0)
	elif kind == &"heal":
		var src := server.world.get_pawn(int(pl["src"]))
		var tgt := server.world.get_pawn(int(pl["tgt"]))
		if src and tgt and src != tgt and tgt.health.fraction() < 0.3:
			_add_score(src.player_id, t, float(pl["amt"]) * 0.4)   # clutch heals
	elif kind == &"ability" and pl.get("ult", false) and pl.get("phase", &"") == &"activate":
		var p := server.world.get_pawn(int(pl["pawn"]))
		if p: _add_score(p.player_id, t, 30.0)


func _add_score(player_id: int, t: int, pts: float) -> void:
	var arr: Array = scores.get(player_id, [])
	arr.append([t, pts])
	scores[player_id] = arr


## The last few seconds from the killer's point of view, for the victim's death screen. Short on
## purpose: a killcam that outstays the respawn timer reads as a punishment rather than an
## explanation.
func killcam_window(killer_net_id: int, at_tick: int) -> Dictionary:
	var start := at_tick - int(KILLCAM_LEAD * RF.TICK_RATE)
	var end := at_tick + int(KILLCAM_TRAIL * RF.TICK_RATE)
	var fr: Array = []
	for f: Array in frames:
		if int(f[0]) >= start and int(f[0]) <= end:
			fr.append(f)
	if fr.is_empty():
		return {}
	var ev: Array = []
	for e: Array in events:
		if int(e[0]) >= start and int(e[0]) <= end:
			ev.append(e)
	return {"net_id": killer_net_id, "start": start, "end": end, "frames": fr, "events": ev, "killcam": true}


## Finds the best window: highest sum of points within WINDOW seconds for one player.
func best_play() -> Dictionary:
	var win := int(WINDOW * RF.TICK_RATE)
	var best_pts := 0.0
	var best_pid := 0
	var best_start := 0
	for pid: Variant in scores.keys():
		var arr: Array = scores[pid]
		for i in arr.size():
			var t0 := int(arr[i][0])
			var sum := 0.0
			for j in range(i, arr.size()):
				if int(arr[j][0]) - t0 <= win:
					sum += float(arr[j][1])
			if sum > best_pts:
				best_pts = sum; best_pid = int(pid); best_start = t0
	if best_pts <= 0.0:
		return {}
	var start := best_start - int(3.0 * RF.TICK_RATE)
	var end := start + win
	var fr: Array = []
	for f: Array in frames:
		if int(f[0]) >= start and int(f[0]) <= end:
			fr.append(f)
	var ev: Array = []
	for e: Array in events:
		if int(e[0]) >= start and int(e[0]) <= end:
			ev.append(e)
	var ps: PlayerState = server.players.get(best_pid)
	best = {"player": best_pid, "name": ps.name if ps else "?", "hero": ps.hero_id if ps else &"", "team": ps.team if ps else 0,
		"points": best_pts, "start": start, "end": end, "frames": fr, "events": ev, "net_id": ps.pawn.net_id if ps and ps.pawn else -1}
	return best
