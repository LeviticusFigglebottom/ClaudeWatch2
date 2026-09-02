class_name PawnVisual
extends Node3D
## Third-person hero body: procedural silhouette built from HeroVisualData + procedural animation
## (walk cycle, lean, aim, recoil, hit flash, status glow). Attached under the Pawn on clients.

var pawn: Pawn
var is_local: bool = false
var rig: HeroRig
var hit_flash: float = 0.0
var heal_flash: float = 0.0
var recoil: float = 0.0
var melee_swing: float = 0.0
var dead: bool = false
var death_t: float = 0.0
var status_glows: Dictionary = {}     # status id -> color
var nameplate: Label3D
var visible_to_local: bool = true
var _outline_mat: ShaderMaterial
var team_ring: MeshInstance3D
var ability_pose: StringName = &""
var ability_pose_t: float = 0.0


func setup(p: Pawn, local: bool) -> void:
	pawn = p
	is_local = local
	rig = HeroRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(p.hero, p.team)
	# Local player: hide the body from the first-person camera (layer 2 = first-person only, layer 1 = world).
	if is_local:
		rig.set_layer_mask(1 << 1 | 1 << 0)
		rig.set_first_person_hidden(true)
	nameplate = Label3D.new()
	nameplate.text = p.display_name
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = true
	nameplate.font_size = 40
	nameplate.pixel_size = 0.004
	nameplate.outline_size = 8
	nameplate.modulate = RF.team_color(p.team)
	nameplate.outline_modulate = Color(0, 0, 0, 0.8)
	nameplate.position = Vector3(0, p.hero.visual.height + 0.35 if p.hero.visual else 2.2, 0)
	nameplate.visible = not is_local
	add_child(nameplate)
	team_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42; ring.outer_radius = 0.5
	team_ring.mesh = ring
	var rm := StandardMaterial3D.new()
	rm.albedo_color = RF.team_color(p.team)
	rm.emission_enabled = true
	rm.emission = RF.team_color(p.team)
	rm.emission_energy_multiplier = 1.2
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	team_ring.material_override = rm
	team_ring.position.y = 0.04
	team_ring.scale = Vector3(1, 0.3, 1)
	team_ring.visible = not is_local
	add_child(team_ring)
	top_level = false


func muzzle_position() -> Vector3:
	return rig.muzzle_global() if rig else pawn.center()


func update_frame(delta: float) -> void:
	if pawn == null:
		return
	var alive := pawn.alive
	if dead:
		death_t += delta
		rig.animate_death(death_t)
		if death_t > 6.0:
			visible = false
		return
	visible = true
	hit_flash = maxf(hit_flash - delta * 6.0, 0.0)
	heal_flash = maxf(heal_flash - delta * 3.0, 0.0)
	recoil = maxf(recoil - delta * 8.0, 0.0)
	melee_swing = maxf(melee_swing - delta * 4.0, 0.0)
	ability_pose_t = maxf(ability_pose_t - delta, 0.0)
	var hs := Vector2(pawn.velocity.x, pawn.velocity.z)
	var speed := hs.length()
	var forward := pawn.forward_flat()
	var right := Vector3(-forward.z, 0, forward.x)
	var local_move := Vector2(hs.dot(Vector2(right.x, right.z)), hs.dot(Vector2(forward.x, forward.z)))
	rig.animate(delta, {
		"speed": speed, "max_speed": pawn.movement.profile.max_speed, "local_move": local_move,
		"grounded": pawn.is_on_floor() if pawn.is_local else (int(pawn.get_meta("net_flags", 0)) & NetCodec.S_GROUNDED) != 0,
		"crouch": pawn.movement.crouch_amount if pawn.is_local else (1.0 if pawn.movement.crouching else 0.0),
		"pitch": pawn.pitch, "recoil": recoil, "melee": melee_swing, "hit": hit_flash, "heal": heal_flash,
		"stunned": pawn.status.stunned, "rooted": pawn.status.rooted, "pose": ability_pose if ability_pose_t > 0.0 else &"",
		"vy": pawn.velocity.y, "invisible": pawn.status.invisible, "revealed": pawn.status.revealed,
		"hovering": pawn.movement.hovering,
	})
	rotation.y = pawn.yaw
	# Enemy invisibility: hide unless revealed or very close.
	var lp := App.client.local_pawn if App.client else null
	if pawn.status.invisible and lp and lp.team != pawn.team and not pawn.status.revealed:
		var d := pawn.global_position.distance_to(lp.global_position)
		rig.set_alpha(clampf(1.0 - d / 4.0, 0.0, 0.25))
		nameplate.visible = false
	else:
		rig.set_alpha(1.0)
		nameplate.visible = not is_local and (lp == null or lp.team == pawn.team or _nameplate_visible(lp))
	rig.set_status_glow(status_glows)
	rig.set_hit_flash(hit_flash, heal_flash)


func _nameplate_visible(lp: Pawn) -> bool:
	# Enemy names show only when looked at and near (like most shooters); allies always.
	var to := pawn.center() - lp.eye_position()
	return to.length() < 30.0 and to.normalized().dot(lp.aim_dir()) > 0.985


func flash_hit() -> void:
	hit_flash = 1.0


func flash_heal() -> void:
	heal_flash = 1.0


func on_fire(pres: AbilityPresentation) -> void:
	recoil = 1.0 * clampf(pres.viewmodel_kick * 10.0 + 0.3, 0.3, 1.0)
	rig.flash_muzzle()


func on_melee() -> void:
	melee_swing = 1.0


func on_ability(ab: AbilityData, phase: StringName) -> void:
	if phase == &"activate" or phase == &"fire":
		ability_pose = ab.presentation.anim_tag if ab.presentation else &"cast"
		ability_pose_t = maxf(ab.cast_time + 0.35, 0.35)
	elif phase == &"end":
		ability_pose_t = 0.0


func on_status(sd: StatusData, on: bool) -> void:
	if on:
		if sd.color.a > 0.0 and sd.show_on_hud:
			status_glows[sd.id] = sd.color
	else:
		status_glows.erase(sd.id)


func play_death() -> void:
	dead = true
	death_t = 0.0
	nameplate.visible = false
	team_ring.visible = false


func play_spawn() -> void:
	dead = false
	death_t = 0.0
	visible = true
	nameplate.visible = not is_local
	team_ring.visible = not is_local
	rig.reset_pose()
