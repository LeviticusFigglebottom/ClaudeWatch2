class_name StatusData
extends Resource
## A status effect definition. Runtime instances (StatusInstance) reference this.
## Statuses compose: a "burn" is dot_dps>0, a "root" is rooted=true, a "nano" is damage/healing mults.

enum Stacking { REFRESH, STACK_DURATION, STACK_INTENSITY, IGNORE_IF_ACTIVE }

@export var id: StringName = &""
@export var display_name: String = ""
@export var duration: float = 2.0
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1
@export var is_debuff: bool = false
@export var is_crowd_control: bool = false    # affected by Bulwark CC reduction / unstoppable
@export var cleansable: bool = true
@export var tags: Array[StringName] = []

@export_group("Modifiers")
@export var speed_mult: float = 1.0
@export var damage_dealt_mult: float = 1.0
@export var damage_taken_mult: float = 1.0
@export var healing_received_mult: float = 1.0
@export var healing_dealt_mult: float = 1.0
@export var gravity_mult: float = 1.0
@export var jump_mult: float = 1.0
@export var cooldown_rate_mult: float = 1.0
@export var ult_charge_mult: float = 1.0
@export var fire_rate_mult: float = 1.0          # scales HOLD weapon fire rate

@export_group("Flags")
@export var rooted: bool = false
@export var stunned: bool = false           # no move, no abilities
@export var silenced: bool = false          # no abilities, can move/shoot
@export var disarmed: bool = false          # no primary/secondary
@export var invulnerable: bool = false
@export var unstoppable: bool = false       # immune to CC and knockback
@export var revealed: bool = false          # visible through walls to the enemy team
@export var invisible: bool = false
@export var anti_heal: bool = false
@export var suppress_regen: bool = false
@export var grounded_lock: bool = false     # cannot leave ground (anti-gravity heroes)
@export var airborne: bool = false          # forced float (Rook's Lift)
@export var min_health_one: bool = false    # cannot drop below 1 hp (Tallow's Vigil)

@export_group("Over time")
@export var dot_dps: float = 0.0
@export var dot_type: RF.DamageType = RF.DamageType.DOT
@export var hot_hps: float = 0.0
@export var overhealth_on_apply: float = 0.0
@export var overhealth_max: float = 0.0

@export_group("Presentation")
@export var icon: Texture2D
@export var vfx_id: StringName = &""
@export var color: Color = Color.WHITE
@export var show_on_hud: bool = true
@export var sound_apply: StringName = &""
