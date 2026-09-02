class_name HitboxProfile
extends Resource
## Analytic hitboxes used for hit registration and lag compensation. Local space, y-up, feet at origin.

@export var head_radius: float = 0.20
@export var head_height: float = 1.60          # center of head sphere (standing)
@export var head_crouch_height: float = 1.05
@export var body_radius: float = 0.36
@export var body_bottom: float = 0.25          # capsule segment bottom y
@export var body_top: float = 1.35             # capsule segment top y (standing)
@export var body_crouch_top: float = 0.85
@export var legs_multiplier: float = 1.0       # OW-style: no leg reduction by default
@export var headshot_enabled: bool = true
