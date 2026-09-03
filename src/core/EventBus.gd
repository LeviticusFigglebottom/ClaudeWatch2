extends Node
## Global signal hub. Only *presentation-level* and *app-level* events travel here;
## simulation state changes go through the server/client pipeline, never through EventBus.
## Keep this list small and documented: every signal here is a public contract.

# --- App / flow ---
signal screen_changed(screen_name: StringName)
signal settings_changed(section: StringName)
signal console_toggled(open: bool)
signal notification(text: String, kind: StringName)

# --- Local client presentation events (emitted by ClientWorld from net events) ---
signal local_pawn_spawned(pawn: Node)
signal local_pawn_died(killer_name: String)
signal local_damage_dealt(amount: float, headshot: bool, killed: bool, target_id: int)
signal local_damage_taken(amount: float, from_dir: Vector3, source_id: int)
signal local_heal_dealt(amount: float, target_id: int)
signal kill_feed(killer: String, killer_team: int, victim: String, victim_team: int, ability: StringName, headshot: bool)
signal objective_message(text: String, kind: StringName)
signal match_phase_changed(phase: StringName)
signal ult_ready(hero_id: StringName)
signal team_ult_status(player_id: int, percent: float)
signal scoreboard_updated(rows: Array)
signal potg_ready(data: Dictionary)
signal killcam_started(killer_name: String, killer_hero: StringName)
signal killcam_ended()
signal callout(player_id: int, text: String, world_pos: Vector3)
signal hitmarker(kind: StringName)
signal camera_shake_requested(trauma: float)
signal hitstop_requested(seconds: float)
