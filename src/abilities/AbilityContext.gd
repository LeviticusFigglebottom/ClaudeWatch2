class_name AbilityContext
extends RefCounted
## Per-activation scratch state handed to every AbilityEffect in the chain.

var pawn: Pawn                 # caster
var world: SimWorld
var ability: Ability
var tick: int = 0
var is_server: bool = false
var is_predicted: bool = false # client-side prediction pass: visuals only, no authoritative state
var aim_origin: Vector3
var aim_dir: Vector3
var view_yaw: float = 0.0
var view_pitch: float = 0.0
var target: Pawn               # optional resolved target (aim assist / ally target)
var point: Vector3             # optional resolved ground/impact point
var normal: Vector3 = Vector3.UP
var seed: int = 0              # deterministic per-activation random seed (shared server/client)
var data: Dictionary = {}      # hand-off between effects: "hits", "projectile", "deployable"...
var shot_index: int = 0        # burst/shotgun index
var charge: float = 0.0        # 0..1 for charged abilities
var rewind_tick: int = -1      # lag comp: client's rendered tick for this command


func rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(seed * 7919 + shot_index * 104729 + tick)
	return r
