class_name RF
## Project-wide constants and small enums. No state.

const GAME_NAME := "RINGFALL"
const VERSION := "0.1.0"

enum Role { BULWARK = 0, STRIKER = 1, CONDUIT = 2 }
const ROLE_NAMES := ["Bulwark", "Striker", "Conduit"]
const ROLE_DESCRIPTIONS := [
	"Frontline. Makes space, absorbs attention, dictates where the fight happens.",
	"Damage. Wins duels, converts space into kills, punishes mistakes.",
	"Sustain. Keeps the team alive, enables plays, decides who gets to keep fighting.",
]
const ROLE_LIMIT: Array[int] = [1, 2, 2]   # 5v5: 1 bulwark, 2 strikers, 2 conduits

enum Team { A = 0, B = 1, NONE = 2 }
const TEAM_COUNT := 2
const TEAM_SIZE := 5

enum DamageType { HITSCAN, PROJECTILE, MELEE, BEAM, SPLASH, DOT, ENVIRONMENT, TRUE }

enum Slot { PRIMARY = 0, SECONDARY = 1, ABILITY_1 = 2, ABILITY_2 = 3, ABILITY_3 = 4, ULTIMATE = 5, MELEE = 6, PASSIVE = 7 }
const SLOT_COUNT := 7
const SLOT_ACTIONS := ["primary_fire", "secondary_fire", "ability_1", "ability_2", "ability_3", "ultimate", "melee"]

# Input button bits (InputCmd.buttons)
const BTN_JUMP := 1 << 0
const BTN_CROUCH := 1 << 1
const BTN_PRIMARY := 1 << 2
const BTN_SECONDARY := 1 << 3
const BTN_ABILITY_1 := 1 << 4
const BTN_ABILITY_2 := 1 << 5
const BTN_ABILITY_3 := 1 << 6
const BTN_ULTIMATE := 1 << 7
const BTN_RELOAD := 1 << 8
const BTN_MELEE := 1 << 9
const BTN_INTERACT := 1 << 10
const BTN_PING := 1 << 11
const SLOT_BUTTONS := [BTN_PRIMARY, BTN_SECONDARY, BTN_ABILITY_1, BTN_ABILITY_2, BTN_ABILITY_3, BTN_ULTIMATE, BTN_MELEE]

# Physics layers (bit values)
const L_WORLD := 1 << 0
const L_PAWN := 1 << 1
const L_BARRIER_A := 1 << 2
const L_BARRIER_B := 1 << 3
const L_DEPLOYABLE := 1 << 4
const L_TRIGGER := 1 << 5
const L_PICKUP := 1 << 6
const L_PAYLOAD := 1 << 7
const L_PROJECTILE_BLOCKER := 1 << 8
const L_NAV_ONLY := 1 << 9

# Simulation
const TICK_RATE := 60
const TICK_DT := 1.0 / 60.0
const SNAPSHOT_EVERY_N_TICKS := 2   # 30 Hz
const MAX_PLAYERS := 12
const HISTORY_TICKS := 64           # 1.07 s of lag-comp history


static func barrier_layer(team: int) -> int:
	return L_BARRIER_A if team == Team.A else L_BARRIER_B


static func enemy_team(team: int) -> int:
	return Team.B if team == Team.A else Team.A


static func team_name(team: int) -> String:
	match team:
		Team.A: return "Cinder"
		Team.B: return "Tide"
	return "None"


## Team colors: warm amber-red for A ("Cinder"), cool teal-blue for B ("Tide").
## Accessibility palettes are handled in Palette.gd; this is the default identity.
static func team_color(team: int) -> Color:
	return Color(0.98, 0.45, 0.16) if team == Team.A else Color(0.16, 0.66, 0.98)


static func role_name(role: int) -> String:
	return ROLE_NAMES[clampi(role, 0, 2)]
