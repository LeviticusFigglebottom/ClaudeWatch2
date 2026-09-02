class_name AbilityPresentation
extends Resource
## Everything the client needs to *show* an ability. Ids resolve through VfxLibrary / AudioLibrary.

@export_group("Visual")
@export var muzzle_vfx: StringName = &""
@export var tracer_style: StringName = &""        # "", "bullet", "bolt", "beam", "arc", "shell"
@export var tracer_color: Color = Color(1.0, 0.85, 0.5)
@export var tracer_width: float = 0.03
@export var impact_vfx: StringName = &"impact_generic"
@export var impact_decal: StringName = &"bullet_hole"
@export var cast_vfx: StringName = &""            # played at pawn on activation
@export var loop_vfx: StringName = &""            # attached while active
@export var end_vfx: StringName = &""
@export var projectile_vfx: StringName = &""      # visual for spawned projectile
@export var area_vfx: StringName = &""            # ring/telegraph for area effects
@export var self_glow: Color = Color(0, 0, 0, 0)  # emissive pulse on caster while active

@export_group("Audio")
@export var sound_fire: StringName = &""
@export var sound_tail: StringName = &""
@export var sound_cast: StringName = &""
@export var sound_loop: StringName = &""
@export var sound_end: StringName = &""
@export var sound_impact: StringName = &""
@export var sound_ready: StringName = &""         # ult ready cue
@export var voice_line: StringName = &""          # ult callout stinger (friendly)
@export var voice_line_enemy: StringName = &""    # ult callout stinger (enemy hears)

@export_group("Feel")
@export var camera_shake: float = 0.0            # trauma added on fire (0..1)
@export var camera_kick_pitch: float = 0.0        # degrees of recoil kick per shot
@export var camera_kick_yaw_random: float = 0.0
@export var kick_recovery: float = 12.0
@export var viewmodel_kick: float = 0.0           # meters back
@export var viewmodel_kick_rot: float = 0.0       # degrees up
@export var hitstop_on_hit: float = 0.0
@export var anim_tag: StringName = &"fire"        # third-person anim state
@export var crosshair: StringName = &"dot"        # dot, circle, cross, bracket, none
@export var spread_visual_scale: float = 1.0
