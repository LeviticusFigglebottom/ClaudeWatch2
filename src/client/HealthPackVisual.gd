class_name HealthPackVisual
extends Node3D
## Rotating health pack pickup visual with availability state.

var large: bool = false
var available: bool = true
var mesh: MeshInstance3D
var light: OmniLight3D
var t: float = 0.0
var base: MeshInstance3D


func _ready() -> void:
	var size := 0.42 if large else 0.28
	mesh = MeshInstance3D.new()
	var box := BoxMesh.new(); box.size = Vector3(size, size * 0.5, size)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.95, 0.98)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.95, 0.5)
	mat.emission_energy_multiplier = 1.5
	mat.metallic = 0.4
	mat.roughness = 0.3
	mesh.material_override = mat
	mesh.position.y = 0.45
	add_child(mesh)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new(); cb.size = Vector3(size * 0.6, size * 0.55, size * 0.18)
	cross.mesh = cb
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.3, 0.95, 0.45)
	cm.emission_enabled = true; cm.emission = Color(0.3, 0.95, 0.45); cm.emission_energy_multiplier = 2.0
	cross.material_override = cm
	mesh.add_child(cross)
	var cross2 := MeshInstance3D.new()
	var cb2 := BoxMesh.new(); cb2.size = Vector3(size * 0.18, size * 0.55, size * 0.6)
	cross2.mesh = cb2
	cross2.material_override = cm
	mesh.add_child(cross2)
	base = MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = size * 0.9; cyl.bottom_radius = size * 1.0; cyl.height = 0.06
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.22, 0.25)
	bm.metallic = 0.6; bm.roughness = 0.4
	bm.emission_enabled = true; bm.emission = Color(0.35, 0.95, 0.5); bm.emission_energy_multiplier = 0.6
	base.material_override = bm
	base.position.y = 0.03
	add_child(base)
	light = OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.55)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.5
	add_child(light)


func set_available(on: bool) -> void:
	available = on
	mesh.visible = on
	light.light_energy = 0.8 if on else 0.05


func _process(delta: float) -> void:
	t += delta
	mesh.rotation.y += delta * 1.2
	mesh.position.y = 0.45 + sin(t * 2.0) * 0.05
