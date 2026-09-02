class_name MapData
extends Resource
## A map: where it is, what it hosts, and where its baked spatial data lives.

@export var id: StringName = &""
@export var display_name: String = ""
@export var location: String = ""
@export var time_of_day: String = ""
@export_multiline var description: String = ""
@export var scene_path: String = ""
@export var supported_modes: Array[StringName] = []
@export var tactical_data_path: String = ""
@export var thumbnail: Texture2D
@export var color_story: String = ""
@export var music_theme: StringName = &""
@export var ambience: StringName = &"amb_wind"
@export var sort_order: int = 0
@export var recommended_players: int = 10
