class_name ModeData
extends Resource
## A game mode's rules. The ModeController subclass reads these; maps provide the geometry/markers.

enum Kind { ESCORT, CONTROL, HYBRID, PUSH, CLASH }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.ESCORT
@export var controller_script: GDScript
@export var icon: Texture2D

@export_group("Timing")
@export var round_time: float = 240.0             # base attack time (escort/hybrid) or unused
@export var time_per_checkpoint: float = 90.0
@export var setup_time: float = 30.0
@export var overtime_grace: float = 3.0            # seconds the overtime fuse burns without contest
@export var max_rounds: int = 2
@export var control_rounds_to_win: int = 2
@export var control_capture_time: float = 8.0      # seconds solo to go 0->100
@export var control_unlock_delay: float = 30.0
@export var point_capture_time: float = 8.0
@export var payload_speed: float = 1.15            # m/s with 1 pusher
@export var payload_speed_2: float = 1.3
@export var payload_speed_3: float = 1.45
@export var payload_reverse_speed: float = 0.55
@export var payload_reverse_delay: float = 10.0
@export var push_robot_speed: float = 1.3
@export var push_barrier_speed_mult: float = 1.25
@export var push_time: float = 480.0
@export var clash_points: int = 5
@export var clash_score_to_win: int = 5
@export var respawn_time_attack: float = 10.0
@export var respawn_time_defend: float = 10.0
@export var symmetric: bool = false
@export var team_a_attacks_first: bool = true
