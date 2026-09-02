class_name ResourceEffect
extends AbilityEffect
## Adjusts ult charge, hero resource, ammo, or cooldowns.

@export var ult_charge_delta: float = 0.0
@export var hero_resource_delta: float = 0.0
@export var refill_ammo: bool = false
@export var reset_cooldown_slot: int = -1
@export var reduce_cooldowns_by: float = 0.0


func apply(ctx: AbilityContext) -> void:
	_do(ctx)


func predict(ctx: AbilityContext) -> void:
	_do(ctx)


func _do(ctx: AbilityContext) -> void:
	var p := ctx.pawn
	if ult_charge_delta != 0.0 and ctx.is_server:
		p.add_ult_charge(ult_charge_delta)
	if hero_resource_delta != 0.0:
		p.hero_resource = clampf(p.hero_resource + hero_resource_delta, 0.0, p.hero.hero_resource_max)
	if refill_ammo:
		for ab: Ability in p.abilities.slots:
			if ab and ab.uses_ammo():
				ab.ammo = ab.data.ammo
				ab.reload_remaining = 0.0
	if reset_cooldown_slot >= 0:
		var ab := p.abilities.get_slot(reset_cooldown_slot)
		if ab:
			ab.cooldown_remaining = 0.0
			ab.charges_left = maxi(ab.data.charges, 1)
	if reduce_cooldowns_by > 0.0:
		for ab: Ability in p.abilities.slots:
			if ab and ab.slot != RF.Slot.ULTIMATE:
				ab.cooldown_remaining = maxf(ab.cooldown_remaining - reduce_cooldowns_by, 0.0)
