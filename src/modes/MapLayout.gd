class_name MapLayout
extends Node3D
## Placed in every map scene as "Layout". Holds objective geometry and spawn data the modes read.
## Maps fill this in their builder script; nothing here is mode logic.

class Zone:
	var name: String = ""
	var center: Vector3
	var half_extents: Vector3 = Vector3(5, 3, 5)
	var yaw: float = 0.0
	func contains(p: Vector3) -> bool:
		var local := (p - center).rotated(Vector3.UP, -yaw)
		return absf(local.x) <= half_extents.x and absf(local.y) <= half_extents.y and absf(local.z) <= half_extents.z
	func random_point(rng: RandomNumberGenerator) -> Vector3:
		var local := Vector3(rng.randf_range(-half_extents.x, half_extents.x), 0, rng.randf_range(-half_extents.z, half_extents.z))
		return center + local.rotated(Vector3.UP, yaw)

class SpawnRoom:
	var team_role: StringName = &"attack"     # "attack" / "defend" / "a" / "b"
	var phase: int = 0                        # objective index this room is used for
	var points: Array[Transform3D] = []
	var zone: Zone                            # safe area (enemy can't enter; healing aura)
	var door_positions: Array[Vector3] = []

var spawn_rooms: Array[SpawnRoom] = []
var control_points: Array[Zone] = []         # control mode: one zone (or several for rotating)
var capture_points: Array[Zone] = []         # hybrid/assault: capture zones in order
var payload_path: Curve3D                    # escort/hybrid: payload track
var payload_checkpoints: Array[float] = []   # offsets along the path (meters)
var push_track: Curve3D                      # push: robot path (center = start)
var push_start_offset: float = 0.0           # meters along push track for the robot's start
var push_barrier_offsets: Array[float] = []  # forward/back spawn points for barriers
var clash_points: Array[Zone] = []           # clash: 5 zones in line
var health_packs: Array[Dictionary] = []     # {pos: Vector3, large: bool}
var kill_z: float = -30.0
var bounds_min: Vector3 = Vector3(-200, -50, -200)
var bounds_max: Vector3 = Vector3(200, 100, 200)
var overview_camera: Transform3D = Transform3D()
var skybox_camera: Transform3D = Transform3D()
var lanes: Array[PackedVector3Array] = []    # authored lane centerlines for AI
var flank_routes: Array[PackedVector3Array] = []
var high_ground: Array[Zone] = []
var chokepoints: Array[Zone] = []
var perches: Array[Vector3] = []             # sniper/off-angle spots
var phase_count: int = 1


func add_spawn_room(team_role: StringName, phase: int, center: Vector3, yaw_deg: float, size: Vector3 = Vector3(6, 3, 6), count: int = 6) -> SpawnRoom:
	var r := SpawnRoom.new()
	r.team_role = team_role
	r.phase = phase
	r.zone = Zone.new()
	r.zone.center = center
	r.zone.half_extents = size
	r.zone.yaw = deg_to_rad(yaw_deg)
	r.zone.name = "%s_%d" % [team_role, phase]
	var cols := 3
	for i in count:
		var col := i % cols
		var row := i / cols
		var local := Vector3((col - 1) * size.x * 0.55, 0, (row - 0.5) * size.z * 0.5)
		var pos := center + local.rotated(Vector3.UP, deg_to_rad(yaw_deg))
		r.points.append(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))
	spawn_rooms.append(r)
	return r


func make_zone(name_: String, center: Vector3, half: Vector3, yaw_deg: float = 0.0) -> Zone:
	var z := Zone.new()
	z.name = name_; z.center = center; z.half_extents = half; z.yaw = deg_to_rad(yaw_deg)
	return z


func rooms_for(team_role: StringName, phase: int) -> Array[SpawnRoom]:
	var out: Array[SpawnRoom] = []
	for r: SpawnRoom in spawn_rooms:
		if r.team_role == team_role and r.phase == phase:
			out.append(r)
	if out.is_empty():
		# Fall back to the latest phase defined for the role.
		var best: SpawnRoom = null
		for r: SpawnRoom in spawn_rooms:
			if r.team_role == team_role and r.phase <= phase and (best == null or r.phase > best.phase):
				best = r
		if best:
			out.append(best)
	return out


func add_health_pack(pos: Vector3, large: bool) -> void:
	health_packs.append({"pos": pos, "large": large})
