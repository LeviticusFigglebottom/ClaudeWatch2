class_name GlobalTuning
extends Resource
## Global combat/economy rules shared by every hero. One instance lives at data/tuning/global_tuning.tres.

@export_group("Health layers")
@export var headshot_multiplier: float = 2.0
@export var armor_flat_reduction: float = 5.0          # per-hit damage reduced by this, up to half the hit
@export var armor_min_fraction: float = 0.5
@export var shield_regen_delay: float = 3.0
@export var shield_regen_rate: float = 30.0            # per second
@export var overhealth_decay_delay: float = 2.0
@export var overhealth_decay_rate: float = 10.0        # per second
@export var role_passive_regen_delay: float = 5.0      # all heroes regen a little out of combat (role-scaled)
@export var role_passive_regen_rate: float = 12.0

@export_group("Ultimate economy")
@export var ult_charge_per_damage: float = 1.0
@export var ult_charge_per_heal: float = 1.0
@export var ult_charge_self_heal_mult: float = 0.5
@export var ult_charge_passive_per_second: float = 2.25
@export var ult_charge_kill_bonus: float = 0.0

@export_group("Respawn")
@export var respawn_time: float = 10.0
@export var respawn_wave_window: float = 3.0
@export var spawn_protection_time: float = 1.5
@export var death_camera_time: float = 2.5

@export_group("Melee")
@export var melee_damage: float = 40.0
@export var melee_range: float = 2.4
@export var melee_cooldown: float = 0.9
@export var melee_knockback: float = 1.5

@export_group("Movement")
@export var gravity: float = 21.0
@export var terminal_velocity: float = 40.0
@export var knockback_resistance_bulwark: float = 0.6   # bulwarks take 60% knockback

@export_group("Pickups")
@export var health_pack_small: float = 75.0
@export var health_pack_large: float = 250.0
@export var health_pack_small_respawn: float = 10.0
@export var health_pack_large_respawn: float = 15.0

@export_group("Role passives")
@export var bulwark_cc_reduction: float = 0.3           # 30% shorter CC on bulwarks
@export var bulwark_knockback_mult: float = 0.6
@export var striker_speed_bonus_on_elim: float = 0.20   # 20% speed for 2.5s after an elim
@export var striker_speed_bonus_time: float = 2.5
@export var conduit_regen_delay: float = 1.5            # conduits regen sooner
@export var conduit_regen_rate: float = 20.0

@export_group("Damage feedback")
@export var hitstop_kill_seconds: float = 0.05
@export var hitstop_headshot_seconds: float = 0.02
