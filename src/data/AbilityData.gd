class_name AbilityData
extends Resource
## One ability (primary fire, secondary, cooldown ability, ultimate). Composed of effects.
## Runtime state lives in Ability (src/abilities/Ability.gd); this resource is immutable data.

enum Trigger { PRESS, HOLD, CHANNEL, TOGGLE, PASSIVE }
enum Cost { NONE, AMMO, ULTIMATE, HERO_RESOURCE }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var trigger: Trigger = Trigger.PRESS

@export_group("Timing")
@export var cooldown: float = 0.0
@export var charges: int = 1
@export var cast_time: float = 0.0               # windup before effects fire
@export var recovery: float = 0.0                # post-fire lockout of other abilities
@export var active_duration: float = 0.0         # channel/toggle/transform length (0 = instant)
@export var fire_rate: float = 0.0               # HOLD: shots per second (overrides cooldown when > 0)
@export var burst_count: int = 1
@export var burst_interval: float = 0.05
@export var tick_interval: float = 0.0           # CHANNEL: tick_effects cadence (0 = every sim tick)
@export var cooldown_starts_on_end: bool = false

@export_group("Resource")
@export var resource: Cost = Cost.NONE
@export var ammo: int = 0
@export var ammo_per_use: int = 1
@export var reload_time: float = 1.2
@export var shares_ammo_with_primary: bool = false
@export var ult_cost: float = 1500.0
@export var hero_resource_cost: float = 0.0      # e.g. Kiln heat, Harrier fuel

@export_group("Rules")
@export var lock_movement: bool = false
@export var lock_look: bool = false
@export var allow_airborne: bool = true
@export var requires_ground: bool = false
@export var cancel_on_damage: bool = false
@export var cancel_on_cc: bool = true
@export var interruptible_by_other_abilities: bool = false
@export var usable_while_stunned: bool = false
@export var usable_while_silenced: bool = false   # primaries are usable while silenced
@export var blocks_primary_while_active: bool = false
@export var is_weapon: bool = false               # counts as primary/secondary for disarm
@export var movement_override: MovementProfile
@export var self_status_while_active: StatusData

@export_group("Composition")
@export var effects: Array[AbilityEffect] = []        # on fire / activation (after cast_time)
@export var tick_effects: Array[AbilityEffect] = []   # every tick_interval while active
@export var end_effects: Array[AbilityEffect] = []    # when the active window ends or is cancelled
@export var behavior: GDScript                       # AbilityBehavior subclass for hero-unique logic

@export_group("Presentation & AI")
@export var presentation: AbilityPresentation
@export var ai: AbilityAIHints


func effective_cooldown() -> float:
	if trigger == Trigger.HOLD and fire_rate > 0.0:
		return 1.0 / fire_rate
	return cooldown


func is_ultimate() -> bool:
	return resource == Cost.ULTIMATE
