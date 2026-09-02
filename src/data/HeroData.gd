class_name HeroData
extends Resource
## The full definition of a hero. Adding a hero = a new .tres in data/heroes plus its ability resources.

@export var id: StringName = &""
@export var display_name: String = ""
@export var codename: String = ""
@export var role: RF.Role = RF.Role.STRIKER
@export var sort_order: int = 0
@export var tagline: String = ""
@export_multiline var lore: String = ""
@export_multiline var playstyle: String = ""

@export_group("Health")
@export var health: float = 200.0
@export var armor: float = 0.0
@export var shield: float = 0.0

@export_group("Body")
@export var movement: MovementProfile
@export var hitbox: HitboxProfile

@export_group("Kit")
@export var primary: AbilityData
@export var secondary: AbilityData
@export var ability_1: AbilityData
@export var ability_2: AbilityData
@export var ability_3: AbilityData
@export var ultimate: AbilityData
@export var passives: Array[StatusData] = []       # always-on statuses
@export var hero_script: GDScript                   # HeroBehavior subclass for unique passives/resources
@export var hero_resource_name: String = ""        # e.g. "Heat", "Fuel" (0 = none)
@export var hero_resource_max: float = 0.0
@export var hero_resource_regen: float = 0.0

@export_group("Presentation")
@export var visual: HeroVisualData
@export var audio: HeroAudioData
@export var theme_color: Color = Color(1, 1, 1)

@export_group("Design")
@export var ai: AIHeroProfile
@export var counters: Array[StringName] = []        # heroes this one is good against
@export var countered_by: Array[StringName] = []
@export var synergies: Array[StringName] = []
@export var unique_mechanic: String = ""
@export var difficulty: int = 1                    # 1..3


func slot_ability(slot: int) -> AbilityData:
	match slot:
		RF.Slot.PRIMARY: return primary
		RF.Slot.SECONDARY: return secondary
		RF.Slot.ABILITY_1: return ability_1
		RF.Slot.ABILITY_2: return ability_2
		RF.Slot.ABILITY_3: return ability_3
		RF.Slot.ULTIMATE: return ultimate
	return null


func total_health() -> float:
	return health + armor + shield
