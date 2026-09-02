class_name AudioLibrary
extends Node
## Sound playback by id. Ids resolve to files under res://assets/audio/<id>.(wav|ogg) with numbered
## variants (<id>_1..n) picked at random. Layered weapon sounds: fire (close/mechanical) + tail
## (distant/reverb) mixed by distance. Missing ids fall back to a synthesized click so nothing is silent.

const BUSES := ["Master", "SFX", "Music", "UI", "Voice", "Ambience"]

var world: SimWorld
var cache: Dictionary = {}          # id -> Array[AudioStream]
var players_3d: Array[AudioStreamPlayer3D] = []
var players_2d: Array[AudioStreamPlayer] = []
var loops: Dictionary = {}          # key -> AudioStreamPlayer3D
var ambience_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var fallback: AudioStream
var _last_footstep: Dictionary = {}
var _missing_reported: Dictionary = {}


func _ready() -> void:
	_ensure_buses()
	for i in 48:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.max_distance = 120.0
		p.unit_size = 6.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		players_3d.append(p)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players_2d.append(p)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.bus = "Ambience"
	add_child(ambience_player)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	fallback = _synth_click()


func _ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")
	Settings.apply_section(&"audio")


func set_world(w: SimWorld) -> void:
	world = w
	for k: Variant in loops.keys():
		var p: AudioStreamPlayer3D = loops[k]
		if is_instance_valid(p):
			p.queue_free()
	loops.clear()


func _synth_click() -> AudioStream:
	var gen := AudioStreamWAV.new()
	gen.format = AudioStreamWAV.FORMAT_16_BITS
	gen.mix_rate = 22050
	var n := 1500
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / 22050.0
		var env := exp(-t * 60.0)
		var v := int(sin(t * 1400.0 * TAU) * env * 12000.0)
		data.encode_s16(i * 2, v)
	gen.data = data
	return gen


func _load(id: StringName) -> AudioStream:
	if cache.has(id):
		var arr: Array = cache[id]
		if arr.is_empty():
			return null
		return arr[randi() % arr.size()]
	var found: Array = []
	for ext: String in ["wav", "ogg"]:
		var base := "res://assets/audio/%s.%s" % [id, ext]
		if ResourceLoader.exists(base):
			found.append(load(base))
		for i in range(1, 7):
			var v := "res://assets/audio/%s_%d.%s" % [id, i, ext]
			if ResourceLoader.exists(v):
				found.append(load(v))
	cache[id] = found
	if found.is_empty():
		if not _missing_reported.has(id):
			_missing_reported[id] = true
			if OS.is_debug_build():
				print("[audio] missing sound id: %s" % id)
		return null
	return found[randi() % found.size()]


func _free_3d() -> AudioStreamPlayer3D:
	for p: AudioStreamPlayer3D in players_3d:
		if not p.playing:
			return p
	return players_3d[randi() % players_3d.size()]


func _free_2d() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in players_2d:
		if not p.playing:
			return p
	return players_2d[randi() % players_2d.size()]


func play_3d(id: StringName, pos: Vector3, bus: StringName = &"SFX", db: float = 0.0, pitch: float = 1.0, max_dist: float = 80.0) -> void:
	if world == null or id == &"":
		return
	var s := _load(id)
	if s == null:
		s = fallback
		db -= 12.0
	var p := _free_3d()
	if p.get_parent() != world:
		p.reparent(world, false)
	p.global_position = pos
	p.stream = s
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.max_distance = max_dist
	p.play()


func play_2d(id: StringName, bus: StringName = &"UI", db: float = 0.0, pitch: float = 1.0) -> void:
	if id == &"":
		return
	var s := _load(id)
	if s == null:
		s = fallback
		db -= 12.0
	var p := _free_2d()
	p.stream = s
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Weapon layering: the shooter hears the close layer; others hear it in 3D plus a tail scaled by distance.
func play_weapon(pres: AbilityPresentation, pos: Vector3, is_local: bool) -> void:
	if pres.sound_fire == &"":
		return
	if is_local:
		play_2d(pres.sound_fire, &"SFX", -2.0, randf_range(0.97, 1.03))
		if pres.sound_tail != &"":
			play_2d(pres.sound_tail, &"SFX", -10.0)
	else:
		play_3d(pres.sound_fire, pos, &"SFX", 0.0, 1.0, 90.0)
		if pres.sound_tail != &"":
			var cam := get_viewport().get_camera_3d()
			var d := cam.global_position.distance_to(pos) if cam else 10.0
			var tail_db := clampf(-14.0 + d * 0.25, -14.0, 0.0)
			play_3d(pres.sound_tail, pos, &"SFX", tail_db, 1.0, 160.0)


func play_ability_sound(id: StringName, pos: Vector3, is_local: bool) -> void:
	if is_local:
		play_2d(id, &"SFX", -1.0)
	else:
		play_3d(id, pos, &"SFX")


func play_projectile_spawn(visual: StringName, pos: Vector3, is_local: bool) -> void:
	var id := StringName("launch_" + String(visual))
	if is_local:
		play_2d(id, &"SFX", -4.0)
	else:
		play_3d(id, pos, &"SFX", -2.0)


func play_footstep(p: Pawn, pos: Vector3) -> void:
	var set_id: StringName = p.hero.audio.footstep_set if p.hero.audio else &"boots_medium"
	var vol: float = (p.hero.audio.footstep_volume if p.hero.audio else 1.0)
	var db := linear_to_db(clampf(vol, 0.05, 2.0)) - 6.0
	if p.movement.crouching:
		db -= 8.0
	play_3d(set_id, pos, &"SFX", db, randf_range(0.92, 1.08), 40.0)


func attach_loop(p: Pawn, id: StringName, ability_id: StringName) -> void:
	var key := "%d:%s" % [p.net_id, ability_id]
	if loops.has(key):
		return
	var s := _load(id)
	if s == null:
		return
	var pl := AudioStreamPlayer3D.new()
	pl.stream = s
	pl.bus = "SFX"
	pl.max_distance = 60.0
	pl.unit_size = 5.0
	p.add_child(pl)
	pl.position = Vector3(0, 1, 0)
	pl.play()
	pl.finished.connect(func() -> void: if is_instance_valid(pl): pl.play())
	loops[key] = pl


func detach_loop(p: Pawn, ability_id: StringName) -> void:
	var key := "%d:%s" % [p.net_id, ability_id]
	var pl: AudioStreamPlayer3D = loops.get(key)
	if pl:
		loops.erase(key)
		pl.queue_free()


func play_ambience(id: StringName) -> void:
	var s := _load(id)
	if s == null:
		return
	ambience_player.stream = s
	ambience_player.volume_db = -8.0
	ambience_player.play()
	if not ambience_player.finished.is_connected(_loop_ambience):
		ambience_player.finished.connect(_loop_ambience)


func _loop_ambience() -> void:
	ambience_player.play()


func play_music(id: StringName, db: float = -6.0) -> void:
	var s := _load(id)
	if s == null:
		music_player.stop()
		return
	music_player.stream = s
	music_player.volume_db = db
	music_player.play()


func stop_music() -> void:
	music_player.stop()


func on_announce(kind: StringName, pl: Dictionary, my_team: int) -> void:
	match kind:
		&"round_start": play_2d(&"announce_round_start", &"Voice")
		&"live": play_2d(&"announce_live", &"Voice")
		&"point_captured":
			play_2d(&"announce_capture_friendly" if int(pl.get("team", -1)) == my_team else &"announce_capture_enemy", &"Voice")
		&"point_unlocked": play_2d(&"announce_unlocked", &"Voice")
		&"checkpoint": play_2d(&"announce_checkpoint", &"Voice")
		&"overtime": play_2d(&"announce_overtime", &"Voice")
		&"round_end": play_2d(&"announce_round_end", &"Voice")
		&"match_end":
			play_2d(&"announce_victory" if int(pl.get("winner", -1)) == my_team else (&"announce_draw" if int(pl.get("winner", -1)) < 0 else &"announce_defeat"), &"Voice")
		_:
			play_2d(&"announce_generic", &"Voice", -6.0)
