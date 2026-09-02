class_name HeroAudioData
extends Resource
## Audio identity of a hero. Values are AudioLibrary ids (see src/audio/AudioLibrary.gd).

@export var footstep_set: StringName = &"boots_medium"
@export var footstep_volume: float = 1.0
@export var hurt: StringName = &"hurt_generic"
@export var death: StringName = &"death_generic"
@export var spawn: StringName = &"spawn_generic"
@export var ult_ready: StringName = &"ult_ready_generic"
@export var ult_stinger: StringName = &""           # unique per hero: heard by all on ult
@export var ult_stinger_enemy: StringName = &""
@export var jump: StringName = &"jump_generic"
@export var land: StringName = &"land_generic"
@export var voice_pitch: float = 1.0
@export var callout_tone: StringName = &"radio_a"   # ping/callout chirp set
