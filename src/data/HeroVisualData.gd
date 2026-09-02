class_name HeroVisualData
extends Resource
## Parameters for the procedural HeroBuilder plus references to authored models.
## Silhouette comes from build params; identity from the palette.

enum Build { LIGHT, MEDIUM, HEAVY, MASSIVE }
enum HeadShape { HELMET_ROUND, HELMET_VISOR, HOOD, BARE, DOME, LANTERN, DIVER, BEAKED, CROWN, ANTENNA }
enum Extra { NONE, CLOAK, BACKPACK, JETPACK, SHOULDER_PADS, TANK_CANISTERS, WINGS, HALO, TAIL, BANNER, ANCHOR, VINES, CANDLES, SPEAKERS, PRISM }

@export var build: Build = Build.MEDIUM
@export var height: float = 1.85
@export var shoulder_width: float = 0.55
@export var head: HeadShape = HeadShape.HELMET_ROUND
@export var extras: Array[Extra] = []
@export var primary_color: Color = Color(0.6, 0.6, 0.65)
@export var secondary_color: Color = Color(0.25, 0.25, 0.3)
@export var accent_color: Color = Color(1.0, 0.7, 0.2)
@export var emissive_color: Color = Color(0, 0, 0)
@export var emissive_strength: float = 1.5
@export var metallic: float = 0.3
@export var roughness: float = 0.6
@export var skin_color: Color = Color(0.85, 0.65, 0.5)
@export var weapon_model: String = ""             # res:// path to a .glb, or "" for generated
@export var weapon_scale: float = 1.0
@export var weapon_offset: Vector3 = Vector3(0.3, -0.25, -0.5)
@export var weapon_style: StringName = &"rifle"    # generated weapon archetype: rifle, cannon, staff, blades, launcher, pistols, bow, gauntlet
@export var arms_color: Color = Color(0.3, 0.3, 0.35)
@export var idle_anim: StringName = &"idle"
@export var run_anim: StringName = &"run"
@export var stance: StringName = &"upright"        # upright, hunched, hover, brace
@export var portrait_tint: Color = Color(1, 1, 1)
@export var silhouette_notes: String = ""
@export var portrait: Texture2D
