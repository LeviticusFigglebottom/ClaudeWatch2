extends Node
## Root scene. Holds the UI layer and the world root; hands them to App and boots.

@onready var ui_layer: CanvasLayer = $UI
@onready var world_root: Node = $World


func _ready() -> void:
	App.attach_roots(ui_layer, world_root)
	UIRouter.setup(ui_layer)
	App.boot()
