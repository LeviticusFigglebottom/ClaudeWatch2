class_name MovementProfile
extends Resource
## How a hero moves. Every hero gets its own instance; values are meant to be *felt*, not just set.

@export var max_speed: float = 5.5
@export var backpedal_mult: float = 0.9
@export var strafe_mult: float = 0.95
@export var ground_accel: float = 60.0
@export var ground_friction: float = 45.0
@export var air_accel: float = 12.0
@export var air_control: float = 0.35        # 0..1 how much input steers airborne velocity
@export var air_friction: float = 0.5
@export var jump_velocity: float = 6.4
@export var jump_count: int = 1              # 2 = double jump
@export var gravity_mult: float = 1.0
@export var coyote_time: float = 0.1
@export var jump_buffer: float = 0.12
@export var crouch_speed_mult: float = 0.55
@export var crouch_transition: float = 0.12
@export var capsule_radius: float = 0.42
@export var capsule_height: float = 1.9      # standing
@export var crouch_height: float = 1.25
@export var eye_height: float = 1.62
@export var crouch_eye_height: float = 1.0
@export var step_height: float = 0.35
@export var mass: float = 1.0                # knockback divisor
@export var landing_recovery: float = 0.0    # seconds of slowed move after a big fall (heavy heroes)
@export var camera_bob_scale: float = 1.0
@export var footstep_interval: float = 0.42  # seconds at max speed
@export var can_wall_slide: bool = false
@export var hover_enabled: bool = false      # e.g. Harrier holding jump
@export var hover_thrust: float = 0.0
@export var hover_fuel: float = 0.0
@export var hover_fuel_regen: float = 0.0
@export var slow_fall: bool = false
@export var slow_fall_terminal: float = 4.0
