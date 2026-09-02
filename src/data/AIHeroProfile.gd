class_name AIHeroProfile
extends Resource
## How bots play this hero. Numbers shape utility scores; behavior comes from the brain.

@export var preferred_range: float = 12.0
@export var min_range: float = 3.0
@export var max_effective_range: float = 30.0
@export var aggression: float = 0.5           # 0 = play with team, 1 = flank/dive
@export var self_preservation: float = 0.5    # retreat threshold scale
@export var flanker: bool = false
@export var dives: bool = false
@export var prefers_high_ground: float = 0.5
@export var sticks_to_tank: float = 0.5       # conduits/strikers follow the bulwark
@export var poke_style: bool = false          # long-range pokers hold sightlines
@export var melee_brawler: bool = false
@export var heals: bool = false
@export var heal_range: float = 15.0
@export var builds: bool = false              # deployables → set up early
@export var ult_style: StringName = &"engage" # engage, counter, save, zone, combo_enabler, combo_payoff
@export var ult_min_targets: int = 2
@export var strafe_style: StringName = &"weave" # weave, crouch, jump, hover, none
@export var aim_difficulty_scale: float = 1.0 # projectile heroes are harder to aim; scales noise
