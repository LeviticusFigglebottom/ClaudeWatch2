class_name DamageEvent
extends RefCounted
## A single damage (or heal, when amount < 0 and is_heal) application.

var source: Pawn                 # may be null (environment)
var target: Pawn
var amount: float = 0.0          # requested amount before mitigation
var type: RF.DamageType = RF.DamageType.HITSCAN
var ability_id: StringName = &""
var headshot: bool = false
var is_heal: bool = false
var is_self: bool = false
var position: Vector3           # impact position (for numbers/vfx)
var direction: Vector3          # travel direction of the hit
var knockback: float = 0.0
var ignore_armor: bool = false
var ignore_barriers: bool = false
var critical: bool = false      # e.g. backstab
var tick: int = 0

# Filled by the pipeline:
var dealt: float = 0.0           # final amount applied to layers (or healed)
var overkill: float = 0.0
var absorbed_by_shield: float = 0.0
var absorbed_by_armor: float = 0.0
var absorbed_by_overhealth: float = 0.0
var killed: bool = false
var prevented: bool = false      # invulnerable / immune
var prevented_reason: StringName = &""
