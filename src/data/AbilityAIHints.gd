class_name AbilityAIHints
extends Resource
## Data a bot needs to use an ability sensibly without hardcoding per hero.

enum Intent { DAMAGE, HEAL, MOBILITY, ESCAPE, ENGAGE, DEFENSIVE, CROWD_CONTROL, UTILITY, BUFF_ALLIES, ZONE, REVEAL }

@export var intent: Intent = Intent.DAMAGE
@export var min_range: float = 0.0
@export var max_range: float = 30.0
@export var ideal_range: float = 10.0
@export var needs_line_of_sight: bool = true
@export var target_ally: bool = false
@export var target_ground: bool = false          # aim at a point on the ground rather than a pawn
@export var needs_enemies_in_radius: int = 0     # e.g. ults: only cast if >= N enemies within max_range
@export var needs_allies_in_radius: int = 0
@export var use_when_health_below: float = 0.0   # 0..1 fraction; escape/defensive abilities
@export var hold_for_combo: bool = false         # coordinator can request a hold
@export var combo_tags: Array[StringName] = []   # e.g. ["pull"] pairs with ["aoe_damage"]
@export var counter_tags: Array[StringName] = [] # e.g. ["cleanse"] counters ["dot"]
@export var cast_priority: float = 0.5           # baseline utility
@export var spam_ok: bool = false                # primary fire style
@export var telegraph_seconds: float = 0.0       # how long enemies can react (for bot dodge logic)
