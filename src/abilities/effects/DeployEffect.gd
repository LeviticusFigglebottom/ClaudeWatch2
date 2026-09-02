class_name DeployEffect
extends AbilityEffect
## Places a deployable (barrier, turret, totem, mirror...) at the aimed point or in front of the caster.

enum Placement { AIMED_SURFACE, IN_FRONT, AT_FEET, AIMED_GROUND }

@export var deployable_script: GDScript
@export var placement: Placement = Placement.IN_FRONT
@export var distance: float = 3.0
@export var max_range: float = 20.0
@export var health: float = 0.0
@export var lifetime: float = 0.0
@export var max_instances: int = 1        # older ones are removed
@export var kind: StringName = &"deployable"
@export var visual_id: StringName = &""
@export var params: Dictionary = {}
@export var face_caster: bool = false


func apply(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	var pos := p.global_position
	var facing := p.forward_flat()
	match placement:
		Placement.IN_FRONT:
			var res := ctx.world.raycast_world(p.center(), facing, distance, p.team, false)
			var d: float = minf(distance, float(res.get("distance", INF)) - 0.3)
			pos = ctx.world.ground_point(p.global_position + facing * maxf(d, 0.5) + Vector3(0, 0.5, 0))
		Placement.AT_FEET:
			pos = p.global_position
		Placement.AIMED_SURFACE, Placement.AIMED_GROUND:
			var res := ctx.world.hitscan(ctx.aim_origin, ctx.aim_dir, max_range, p, ctx.rewind_tick)
			pos = res.point + res.normal * 0.05
			if placement == Placement.AIMED_GROUND:
				pos = ctx.world.ground_point(res.point + Vector3(0, 0.3, 0))
			ctx.normal = res.normal
	if face_caster:
		facing = (p.global_position - pos)
	# Replace oldest if over the limit.
	var existing := ctx.world.deployables_of(p, kind)
	while existing.size() >= max_instances and max_instances > 0:
		var oldest: Deployable = existing.pop_front()
		oldest.destroy(null)
	var d := deployable_script.new() as Deployable if deployable_script else Deployable.new()
	d.setup(ctx.world, p, kind)
	d.ability_id = ctx.ability.data.id if ctx.ability else &""
	d.health = health; d.max_health = health; d.lifetime = lifetime
	d.visual_id = visual_id
	d.data = params.duplicate()
	d.data["normal"] = ctx.normal
	ctx.point = pos
	ctx.world.spawn_deployable(d, pos, facing)
	ctx.data["deployable"] = d
