class_name ClientWorld
extends Node
## Presentation root on the client: pawn visuals, first-person rig, VFX, audio, HUD feed.
## Consumes server events + predicted events and never touches simulation state.

var client: GameClient
var visuals: Dictionary = {}          # net_id -> PawnVisual
var projectile_visuals: Dictionary = {}   # id -> ProjectileVisual
var deployable_visuals: Dictionary = {}   # id -> Node3D
var fp_rig: FirstPersonRig
var camera: Camera3D
var vfx: VfxLibrary
var audio: AudioLibrary
var env_root: Node3D
var spectator_cam: SpectatorCamera
var local_pawn: Pawn
var kill_feed: Array = []
var scoreboard_rows: Array = []
var hud_state: Dictionary = {}
var match_end_data: Dictionary = {}
var _predicted_beam_end: Dictionary = {}
var replay_player: ReplayPlayer
var pickups: Array[Node3D] = []
var damage_numbers: DamageNumbers
var last_hitscan_seen: Dictionary = {}


func setup(c: GameClient) -> void:
	client = c
	vfx = VfxLibrary.new()
	vfx.name = "VFX"
	add_child(vfx)
	audio = AudioLibrary.new()
	audio.name = "Audio"
	add_child(audio)
	fp_rig = FirstPersonRig.new()
	fp_rig.name = "FirstPerson"
	add_child(fp_rig)
	camera = fp_rig.camera
	spectator_cam = SpectatorCamera.new()
	spectator_cam.name = "Spectator"
	add_child(spectator_cam)
	damage_numbers = DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	add_child(damage_numbers)
	_register_rig_commands()


func world() -> SimWorld:
	return client.world


var _rig_show: Node3D


## Console: rigshow <hero> [x y z] [yaw_deg] — place a static hero rig for visual review.
func _register_rig_commands() -> void:
	Console.register("rigshow", "rigshow <hero> [x y z] [yaw]: show a hero rig for review", func(a: PackedStringArray) -> String:
		if a.size() < 1: return "usage: rigshow <hero> [x y z] [yaw]"
		var h := Registry.hero(StringName(a[0]))
		if h == null: return "unknown hero"
		if _rig_show: _rig_show.queue_free()
		_rig_show = Node3D.new()
		world().add_child(_rig_show)
		var pos := Vector3(float(a[1]), float(a[2]), float(a[3])) if a.size() >= 4 else Vector3(0, 0.02, 0)
		_rig_show.global_position = pos
		_rig_show.rotation.y = deg_to_rad(float(a[4])) if a.size() >= 5 else 0.0
		var rig := HeroRig.new()
		_rig_show.add_child(rig)
		rig.build(h, RF.Team.A)
		rig.animate(0.016, {"speed": 0.0, "max_speed": 5.5, "local_move": Vector2.ZERO, "grounded": true, "crouch": 0.0, "pitch": 0.0,
			"recoil": 0.0, "melee": 0.0, "hit": 0.0, "heal": 0.0, "stunned": false, "rooted": false, "pose": &"", "vy": 0.0, "invisible": false, "revealed": false, "hovering": false})
		return "rig %s at %s" % [h.id, pos])
	Console.register("vmdebug", "Print viewmodel part positions (camera space + screen px)", func(_a: PackedStringArray) -> String:
		return fp_rig.debug_dump())
	Console.register("rigclear", "Remove the review rig", func(_a: PackedStringArray) -> String:
		if _rig_show: _rig_show.queue_free()
		_rig_show = null
		return "cleared")


func on_map_loaded(md: MapData) -> void:
	vfx.set_world(world())
	damage_numbers.set_world(world())
	audio.set_world(world())
	if md:
		audio.play_ambience(md.ambience)
	# Pickups visuals
	for pk: Node3D in pickups:
		pk.queue_free()
	pickups.clear()
	var layout := world().map_root.get_node_or_null("Layout") as MapLayout if world().map_root else null
	if layout:
		for hp: Dictionary in layout.health_packs:
			var v := HealthPackVisual.new()
			v.large = bool(hp["large"])
			world().add_child(v)
			v.global_position = hp["pos"]
			pickups.append(v)
	spectator_cam.set_world(world(), layout)
	if client.local_pawn == null:
		spectator_cam.activate(true)


## --- Pawns ------------------------------------------------------------------------------------

func on_pawn_added(p: Pawn) -> void:
	var v := PawnVisual.new()
	v.name = "Visual"
	p.add_child(v)
	v.setup(p, p.is_local)
	visuals[p.net_id] = v
	if p.is_local:
		local_pawn = p
		fp_rig.attach(p)
		spectator_cam.activate(false)
		audio.play_2d(p.hero.audio.spawn if p.hero.audio else &"spawn_generic", &"Voice")
	elif local_pawn == null and client.local_pawn == null:
		spectator_cam.activate(true)


func on_pawn_removed(p: Pawn) -> void:
	visuals.erase(p.net_id)
	if p == local_pawn:
		local_pawn = null
		fp_rig.detach()
		spectator_cam.activate(true)


func on_pawn_died_visual(p: Pawn) -> void:
	var v: PawnVisual = visuals.get(p.net_id)
	if v:
		v.play_death()
	vfx.spawn(&"death_burst", p.center(), Vector3.UP, RF.team_color(p.team))
	audio.play_3d(p.hero.audio.death if p.hero.audio else &"death_generic", p.center(), &"Voice")
	if p == local_pawn:
		fp_rig.on_local_death()
		spectator_cam.activate(true, p.center())
		EventBus.local_pawn_died.emit(p.last_damage_source.display_name if p.last_damage_source else "")


func on_pawn_spawned_visual(p: Pawn) -> void:
	var v: PawnVisual = visuals.get(p.net_id)
	if v:
		v.play_spawn()
	if p == local_pawn:
		stop_killcam()   # respawning always cuts the killcam short
		fp_rig.on_local_spawn()
		spectator_cam.activate(false)


func on_roster(rows: Array) -> void:
	scoreboard_rows = rows
	EventBus.scoreboard_updated.emit(rows)


func on_hud_state(s: Dictionary) -> void:
	var prev_phase := int(hud_state.get("phase", -1))
	hud_state = s
	var ph := int(s.get("phase", -1))
	if ph != prev_phase:
		EventBus.match_phase_changed.emit(_phase_name(ph))


func _phase_name(ph: int) -> StringName:
	match ph:
		ModeController.Phase.SETUP: return &"setup"
		ModeController.Phase.LIVE: return &"live"
		ModeController.Phase.OVERTIME: return &"overtime"
		ModeController.Phase.ROUND_END: return &"round_end"
		ModeController.Phase.MATCH_END: return &"match_end"
	return &"waiting"


func on_match_end(data: Dictionary) -> void:
	match_end_data = data
	EventBus.potg_ready.emit(data.get("potg", {}))
	UIRouter.show_overlay(&"scoreboard", {"final": true})
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if is_instance_valid(self):
			UIRouter.hide_overlay(&"scoreboard")
			UIRouter.show(&"post_match"))


## --- Per frame ----------------------------------------------------------------------------------

func physics_tick(_tick: int) -> void:
	pass


func render_frame(delta: float, render_tick: float) -> void:
	# Remote pawns: interpolate toward server poses.
	for nid: Variant in visuals.keys():
		var v: PawnVisual = visuals[nid]
		if not is_instance_valid(v):
			continue
		var p := v.pawn
		if p == null or p == local_pawn:
			continue
		var pose := {}
		if client.remote_pose(int(nid), render_tick, pose):
			p.global_position = pose["pos"]
			p.yaw = pose["yaw"]
			p.pitch = pose["pitch"]
			p.velocity = pose["vel"]
		v.update_frame(delta)
	if local_pawn and is_instance_valid(local_pawn):
		var lv: PawnVisual = visuals.get(local_pawn.net_id)
		if lv:
			lv.update_frame(delta)
	fp_rig.update_frame(delta)
	spectator_cam.update_frame(delta)
	vfx.update_frame(delta)
	damage_numbers.update_frame(delta)
	if replay_player:
		replay_player.update_frame(delta)


## --- Events -------------------------------------------------------------------------------------

## Predicted events from the local SimWorld (fire immediately for responsiveness).
func on_predicted_event(kind: StringName, pl: Dictionary) -> void:
	if not pl.get("predicted", false) and kind != &"projectile_spawn" and kind != &"ability" and kind != &"teleport" and kind != &"reload":
		return
	if kind == &"ability" and int(pl.get("pawn", -1)) != (local_pawn.net_id if local_pawn else -2):
		return
	_present(kind, pl, true)


func on_server_event(kind: StringName, pl: Dictionary) -> void:
	# Skip server echoes of things the local client already predicted (tracers/muzzle of own shots).
	if local_pawn and kind == &"hitscan" and int(pl.get("pawn", -1)) == local_pawn.net_id:
		_confirm_local_hits(pl)
		return
	if local_pawn and kind == &"projectile_spawn" and int(pl.get("owner", -1)) == local_pawn.net_id:
		_adopt_predicted_projectile(pl)
		return
	if local_pawn and kind == &"ability" and int(pl.get("pawn", -1)) == local_pawn.net_id and pl.get("phase", &"") != &"end":
		return
	_present(kind, pl, false)


func _present(kind: StringName, pl: Dictionary, predicted: bool) -> void:
	var w := world()
	match kind:
		&"hitscan":
			var shooter := w.get_pawn(int(pl["pawn"]))
			var slot := int(pl.get("slot", 0))
			var ab_data: AbilityData = shooter.hero.slot_ability(slot) if shooter and slot >= 0 and slot < 6 else null
			var pres := ab_data.presentation if ab_data and ab_data.presentation else AbilityPresentation.new()
			var origin: Vector3 = pl["origin"]
			var muzzle := origin
			var v: PawnVisual = visuals.get(int(pl["pawn"]))
			if shooter == local_pawn:
				muzzle = fp_rig.muzzle_position()
			elif v:
				muzzle = v.muzzle_position()
			for h: Dictionary in pl["hits"]:
				vfx.tracer(muzzle, h["end"], pres)
				var hit_pawn := w.get_pawn(int(h.get("pawn", -1)))
				if hit_pawn:
					vfx.spawn(&"impact_flesh", h["end"], h.get("normal", Vector3.UP), Color(1, 0.4, 0.3))
					var hv: PawnVisual = visuals.get(hit_pawn.net_id)
					if hv: hv.flash_hit()
				elif h.get("barrier", false):
					vfx.spawn(&"impact_barrier", h["end"], h.get("normal", Vector3.UP), Color(0.5, 0.8, 1))
				else:
					vfx.impact(h["end"], h.get("normal", Vector3.UP), pres)
			if shooter:
				if shooter == local_pawn:
					fp_rig.on_fire(pres)
				elif v:
					v.on_fire(pres)
				audio.play_weapon(pres, muzzle, shooter == local_pawn)
				vfx.muzzle(muzzle, pres, shooter == local_pawn)
		&"projectile_spawn":
			_spawn_projectile_visual(pl, predicted)
		&"projectile_impact":
			var id := int(pl["id"])
			var pv := _projectile_visual(id)
			var visual: StringName = pl.get("visual", &"bolt")
			var color := pv.color if pv else Color(1, 0.8, 0.4)
			vfx.projectile_impact(visual, pl["pos"], pl["normal"], color, float(pl.get("splash", 0.0)))
			audio.play_3d(&"impact_" + visual, pl["pos"], &"SFX")
			if pv:
				pv.finish()
				projectile_visuals.erase(id)
		&"projectile_bounce":
			var pv := _projectile_visual(int(pl["id"]))
			if pv:
				pv.on_bounce(pl["pos"], pl["vel"])
			audio.play_3d(&"bounce", pl["pos"], &"SFX")
		&"projectile_stuck":
			var pv := _projectile_visual(int(pl["id"]))
			if pv:
				pv.stick(pl["pos"], w.get_pawn(int(pl.get("to", -1))))
		&"projectile_expire":
			var pv := _projectile_visual(int(pl["id"]))
			if pv:
				pv.finish()
				projectile_visuals.erase(int(pl["id"]))
		&"damage":
			var src := int(pl["src"]); var tgt := int(pl["tgt"])
			var amt: float = pl["amt"]
			if local_pawn and src == local_pawn.net_id and tgt != src:
				damage_numbers.show_damage(pl["pos"], amt, pl["hs"], pl.get("crit", false))
				EventBus.local_damage_dealt.emit(amt, pl["hs"], pl["killed"], tgt)
				EventBus.hitmarker.emit(&"kill" if pl["killed"] else (&"headshot" if pl["hs"] else &"hit"))
				audio.play_2d(&"hitmarker_kill" if pl["killed"] else (&"hitmarker_head" if pl["hs"] else &"hitmarker"), &"UI")
				if pl["killed"] and bool(Settings.get_value(&"accessibility", "hitstop")):
					fp_rig.hitstop(w.tuning.hitstop_kill_seconds)
				elif pl["hs"] and bool(Settings.get_value(&"accessibility", "hitstop")):
					fp_rig.hitstop(w.tuning.hitstop_headshot_seconds)
			if local_pawn and tgt == local_pawn.net_id:
				var from_dir: Vector3 = -pl.get("dir", Vector3.ZERO)
				var srcp := w.get_pawn(src)
				if srcp:
					from_dir = (srcp.global_position - local_pawn.global_position).normalized()
				EventBus.local_damage_taken.emit(amt, from_dir, src)
				fp_rig.on_damage_taken(amt, from_dir)
				audio.play_2d(local_pawn.hero.audio.hurt if local_pawn.hero.audio else &"hurt_generic", &"Voice")
		&"heal":
			var tgt := int(pl["tgt"]); var src := int(pl["src"])
			if local_pawn and src == local_pawn.net_id and tgt != src:
				damage_numbers.show_heal(pl["pos"], pl["amt"])
				EventBus.local_heal_dealt.emit(pl["amt"], tgt)
			var hv: PawnVisual = visuals.get(tgt)
			if hv: hv.flash_heal()
		&"kill":
			var victim := w.get_pawn(int(pl["victim"]))
			var killer := w.get_pawn(int(pl["killer"]))
			var kn := killer.display_name if killer else "Environment"
			var vn := victim.display_name if victim else "?"
			EventBus.kill_feed.emit(kn, killer.team if killer else -1, vn, victim.team if victim else -1, StringName(String(pl.get("ability", ""))), bool(pl.get("headshot", false)))
			if local_pawn and killer == local_pawn and victim != local_pawn:
				audio.play_2d(&"kill_confirm", &"UI")
			elif local_pawn and victim and victim.team == local_pawn.team and victim != local_pawn:
				audio.play_2d(&"ally_down", &"UI")
		&"ability":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == null:
				return
			var slot := int(pl["slot"])
			var ab: AbilityData = p.hero.slot_ability(slot) if slot >= 0 and slot < 6 else w.melee_ability
			if ab == null:
				return
			var pres := ab.presentation if ab.presentation else AbilityPresentation.new()
			var phase: StringName = pl["phase"]
			var v: PawnVisual = visuals.get(p.net_id)
			var is_me := p == local_pawn
			match phase:
				&"activate":
					if pres.cast_vfx != &"":
						vfx.spawn(pres.cast_vfx, p.center(), Vector3.UP, p.hero.theme_color, p)
					if pres.sound_cast != &"":
						audio.play_ability_sound(pres.sound_cast, p.center(), is_me)
					if bool(pl.get("ult", false)):
						_on_ult_used(p, pres)
					if v: v.on_ability(ab, phase)
					if is_me: fp_rig.on_ability(ab, phase)
					if pres.loop_vfx != &"":
						vfx.attach_loop(p, pres.loop_vfx, ab.id, p.hero.theme_color)
					if pres.sound_loop != &"":
						audio.attach_loop(p, pres.sound_loop, ab.id)
				&"fire":
					if slot != RF.Slot.PRIMARY and slot != RF.Slot.SECONDARY:
						if pres.sound_fire != &"":
							audio.play_ability_sound(pres.sound_fire, pl.get("pos", p.center()), is_me)
						if pres.muzzle_vfx != &"" and pres.tracer_style == &"":
							vfx.spawn(pres.muzzle_vfx, p.center(), pl.get("dir", Vector3.UP), p.hero.theme_color)
						if v: v.on_ability(ab, phase)
						if is_me: fp_rig.on_ability(ab, phase)
					elif ab.trigger != AbilityData.Trigger.HOLD or not _has_hitscan(ab):
						# Non-hitscan weapons fire sound from here (projectiles/beams have no hitscan event).
						if not _has_hitscan(ab):
							var muzzle := fp_rig.muzzle_position() if is_me else (v.muzzle_position() if v else p.center())
							audio.play_weapon(pres, muzzle, is_me)
							vfx.muzzle(muzzle, pres, is_me)
							if is_me: fp_rig.on_fire(pres)
							elif v: v.on_fire(pres)
				&"end":
					vfx.detach_loop(p, ab.id)
					audio.detach_loop(p, ab.id)
					if pres.end_vfx != &"":
						vfx.spawn(pres.end_vfx, p.center(), Vector3.UP, p.hero.theme_color)
					if pres.sound_end != &"":
						audio.play_ability_sound(pres.sound_end, p.center(), is_me)
					if v: v.on_ability(ab, phase)
					if is_me: fp_rig.on_ability(ab, phase)
					_predicted_beam_end.erase(p.net_id)
					vfx.end_beam(p.net_id)
					for i in 4:
						vfx.end_beam(p.net_id * 16 + i)
		&"beam":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == null: return
			var slot := int(pl.get("slot", 0))
			var ab: AbilityData = p.hero.slot_ability(slot) if slot >= 0 else null
			var pres := ab.presentation if ab and ab.presentation else AbilityPresentation.new()
			var start := fp_rig.muzzle_position() if p == local_pawn else ((visuals[p.net_id] as PawnVisual).muzzle_position() if visuals.has(p.net_id) else p.center())
			vfx.beam(p.net_id, start, pl["end"], pres, p.hero.theme_color)
		&"beam_segments":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == null: return
			var slot := int(pl.get("slot", 0))
			var ab: AbilityData = p.hero.slot_ability(slot) if slot >= 0 else null
			var pres := ab.presentation if ab and ab.presentation else AbilityPresentation.new()
			var pts: Array = pl.get("points", [])
			var start := fp_rig.muzzle_position() if p == local_pawn else ((visuals[p.net_id] as PawnVisual).muzzle_position() if visuals.has(p.net_id) else p.center())
			for i in pts.size():
				var seg_end: Vector3 = pts[i]
				vfx.beam(p.net_id * 16 + i, start, seg_end, pres, p.hero.theme_color)
				start = seg_end
		&"melee":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == local_pawn:
				fp_rig.on_melee()
			elif p and visuals.has(p.net_id):
				(visuals[p.net_id] as PawnVisual).on_melee()
			if int(pl.get("hits", 0)) > 0:
				vfx.spawn(&"melee_hit", pl["pos"], Vector3.UP, Color(1, 0.9, 0.7))
				audio.play_3d(&"melee_hit", pl["pos"], &"SFX")
			elif not predicted or p == local_pawn:
				audio.play_3d(&"melee_swing", pl["pos"], &"SFX")
		&"area":
			var vid: StringName = pl.get("vfx", &"")
			var p := w.get_pawn(int(pl.get("pawn", -1)))
			vfx.area(vid if vid != &"" else &"area_generic", pl["pos"], float(pl["radius"]), p.hero.theme_color if p else Color.WHITE)
		&"deployable_spawn":
			_spawn_deployable_visual(pl)
		&"deployable_hp":
			var dv: Node3D = deployable_visuals.get(int(pl["id"]))
			if dv and dv.has_method("set_health"):
				dv.call("set_health", float(pl["hp"]))
		&"deployable_destroy":
			var dv: Node3D = deployable_visuals.get(int(pl["id"]))
			if dv:
				vfx.spawn(&"deploy_break", pl["pos"], Vector3.UP, Color(0.8, 0.8, 0.8))
				audio.play_3d(&"deploy_break", pl["pos"], &"SFX")
				dv.queue_free()
				deployable_visuals.erase(int(pl["id"]))
		&"status":
			var p := w.get_pawn(int(pl["tgt"]))
			var v: PawnVisual = visuals.get(int(pl["tgt"]))
			var sd := StatusLibrary.get_status(StringName(String(pl["id"])))
			if v and sd:
				v.on_status(sd, bool(pl["on"]))
			if p == local_pawn and sd and bool(pl["on"]) and sd.sound_apply != &"":
				audio.play_2d(sd.sound_apply, &"SFX")
		&"teleport":
			var p := w.get_pawn(int(pl["pawn"]))
			vfx.spawn(&"blink_out", pl["from"], Vector3.UP, p.hero.theme_color if p else Color.WHITE)
			vfx.spawn(&"blink_in", pl["to"] + Vector3(0, 1, 0), Vector3.UP, p.hero.theme_color if p else Color.WHITE)
			audio.play_3d(&"blink", pl["to"], &"SFX")
			if p and p != local_pawn:
				var buf: Array = client.remote_buffer.get(p.net_id, [])
				buf.clear()
		&"footstep":
			var p := w.get_pawn(int(pl["pawn"]))
			if p and p != local_pawn:
				audio.play_footstep(p, pl["pos"])
		&"sound":
			var p := w.get_pawn(int(pl["pawn"]))
			var k: StringName = pl["kind"]
			if p and p != local_pawn:
				match k:
					&"jump": audio.play_3d(p.hero.audio.jump if p.hero.audio else &"jump_generic", pl["pos"], &"SFX", -6.0)
					&"land": audio.play_3d(p.hero.audio.land if p.hero.audio else &"land_generic", pl["pos"], &"SFX", -4.0)
					&"reload": audio.play_3d(&"reload_generic", pl["pos"], &"SFX", -6.0)
		&"reload":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == local_pawn:
				fp_rig.on_reload(float(pl["time"]))
				audio.play_2d(&"reload_generic", &"SFX")
		&"ult_ready":
			var p := w.get_pawn(int(pl["pawn"]))
			if p == local_pawn:
				EventBus.ult_ready.emit(p.hero.id)
				audio.play_2d(p.hero.audio.ult_ready if p.hero.audio else &"ult_ready_generic", &"UI")
		&"mode_announce":
			EventBus.objective_message.emit(String(pl.get("kind", "")), StringName(String(pl.get("kind", ""))))
			audio.on_announce(StringName(String(pl.get("kind", ""))), pl, local_pawn.team if local_pawn else client.team)
		&"pickup_state":
			for pk: Node3D in pickups:
				if pk.global_position.distance_to(pl["pos"]) < 0.5 and pk.has_method("set_available"):
					pk.call("set_available", bool(pl["on"]))
			if not bool(pl["on"]) and local_pawn and int(pl.get("pawn", -1)) == local_pawn.net_id:
				audio.play_2d(&"health_pack", &"SFX")
		&"ping":
			EventBus.callout.emit(int(pl["player"]), "Here", pl["pos"])
			vfx.spawn(&"ping_marker", pl["pos"], Vector3.UP, RF.team_color(int(pl["team"])))
			audio.play_2d(&"ping", &"UI")
		&"notice":
			EventBus.notification.emit(String(pl.get("text", "")), &"info")
		&"chat":
			EventBus.notification.emit("%s: %s" % [pl.get("name", "?"), pl.get("text", "")], &"chat")
		&"killcam":
			_start_killcam(pl)
		&"bot_directive":
			pass
		&"respawn_timer":
			pass


func _has_hitscan(ab: AbilityData) -> bool:
	for e: AbilityEffect in ab.effects:
		if e is HitscanEffect:
			return true
	return false


## Projectile visuals are pooled by id; entries can outlive their node (queue_free on impact),
## so every lookup must drop stale references rather than assigning a freed instance.
func _projectile_visual(id: int) -> ProjectileVisual:
	var v: Variant = projectile_visuals.get(id)
	if v == null or not is_instance_valid(v):
		projectile_visuals.erase(id)
		return null
	return v as ProjectileVisual


func _on_ult_used(p: Pawn, pres: AbilityPresentation) -> void:
	var friendly := local_pawn != null and p.team == local_pawn.team or (local_pawn == null and p.team == client.team)
	var line := pres.voice_line if friendly else pres.voice_line_enemy
	var stinger: StringName = p.hero.audio.ult_stinger if friendly else p.hero.audio.ult_stinger_enemy
	if stinger == &"" and p.hero.audio: stinger = p.hero.audio.ult_stinger
	if stinger != &"":
		audio.play_2d(stinger, &"Voice")
	if line != &"":
		audio.play_2d(line, &"Voice")
	EventBus.objective_message.emit("%s used %s" % [p.display_name, p.hero.ultimate.display_name if p.hero.ultimate else "ultimate"], &"ult_enemy" if not friendly else &"ult_friendly")
	if not friendly:
		fp_rig.shake(0.15)


func _confirm_local_hits(pl: Dictionary) -> void:
	# Server says where our shot really went: if it differs a lot from what we drew, draw a correction impact.
	for h: Dictionary in pl["hits"]:
		var hit_pawn := world().get_pawn(int(h.get("pawn", -1)))
		if hit_pawn:
			var hv: PawnVisual = visuals.get(hit_pawn.net_id)
			if hv: hv.flash_hit()
			vfx.spawn(&"impact_flesh", h["end"], h.get("normal", Vector3.UP), Color(1, 0.4, 0.3))


func _spawn_projectile_visual(pl: Dictionary, predicted: bool) -> void:
	var id := int(pl["id"])
	var pv := ProjectileVisual.new()
	var owner_p := world().get_pawn(int(pl.get("owner", -1)))
	pv.setup(vfx, StringName(String(pl.get("visual", "bolt"))), owner_p.hero.theme_color if owner_p else Color.WHITE, pl["vel"], float(pl.get("gravity", 0.0)), float(pl.get("lifetime", 5.0)), float(pl.get("radius", 0.1)), int(pl.get("team", RF.Team.NONE)))
	world().add_child(pv)
	var pos: Vector3 = pl["pos"]
	if owner_p == local_pawn and local_pawn != null:
		pos = fp_rig.muzzle_position()
		pv.converge_to(pl["pos"], 0.12)
	pv.global_position = pos
	if predicted:
		pv.predicted_key = str(pl["vel"]) + str(pl.get("visual", ""))
		pv.set_meta("predicted", true)
	projectile_visuals[id] = pv
	audio.play_projectile_spawn(StringName(String(pl.get("visual", "bolt"))), pl["pos"], owner_p == local_pawn)


func _adopt_predicted_projectile(pl: Dictionary) -> void:
	# Match the server's projectile id to the visual we spawned on prediction; if none, spawn now.
	var key := str(pl["vel"]) + str(pl.get("visual", ""))
	for id: Variant in projectile_visuals.keys():
		var pv := _projectile_visual(int(id))
		if pv != null and pv.has_meta("predicted") and pv.predicted_key == key:
			projectile_visuals.erase(id)
			projectile_visuals[int(pl["id"])] = pv
			pv.remove_meta("predicted")
			return
	_spawn_projectile_visual(pl, false)


func _spawn_deployable_visual(pl: Dictionary) -> void:
	var id := int(pl["id"])
	if deployable_visuals.has(id):
		return
	var owner_p := world().get_pawn(int(pl.get("owner", -1)))
	var node := DeployableVisuals.create(StringName(String(pl["kind"])), StringName(String(pl.get("visual", ""))), pl.get("data", {}), int(pl.get("team", RF.Team.NONE)), owner_p.hero.theme_color if owner_p else Color.WHITE, float(pl.get("max_hp", 0.0)))
	world().add_child(node)
	node.global_position = pl["pos"]
	var facing: Vector3 = pl.get("facing", Vector3.FORWARD)
	facing.y = 0
	if facing.length_squared() > 0.001:
		node.look_at(node.global_position + facing.normalized(), Vector3.UP)
	deployable_visuals[id] = node
	vfx.spawn(&"deploy_place", pl["pos"], Vector3.UP, owner_p.hero.theme_color if owner_p else Color.WHITE)
	audio.play_3d(&"deploy_place", pl["pos"], &"SFX")


## Killcam: replay the killer's last few seconds on the death screen. Skipped when the setting is
## off, when a replay is already running (post-match POTG wins), or once we are alive again.
func _start_killcam(window: Dictionary) -> void:
	if not bool(Settings.get_value(&"gameplay", "killcam")):
		return
	if replay_player != null or window.get("frames", []).is_empty():
		return
	if local_pawn != null and is_instance_valid(local_pawn) and local_pawn.alive:
		return
	var r := ReplayPlayer.new()
	r.name = "Killcam"
	add_child(r)
	replay_player = r
	r.setup(self, window)
	r.play(_on_killcam_finished, false)
	EventBus.killcam_started.emit(String(window.get("killer_name", "")), String(window.get("killer_hero", "")))


func _on_killcam_finished() -> void:
	stop_killcam()


func stop_killcam() -> void:
	if replay_player == null or not is_instance_valid(replay_player):
		replay_player = null
		return
	var r := replay_player
	replay_player = null
	r.stop()
	EventBus.killcam_ended.emit()
