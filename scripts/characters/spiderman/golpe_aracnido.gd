class_name GolpeAracnido
extends Ability
## Slot 0 de Spider-Man: "GOLPE ARACNIDO". Golpe basico, GRATIS como todos.
##
## Piñas y patadas acrobaticas, rapidisimas: el basico mas rapido despues del de Sonic, y
## de los que menos pegan.

const DAMAGE: float = 14.0
const CONE_RANGE: float = 3.2
const CONE_ANGLE: float = 80.0
const KNOCKBACK: float = 3.0


func _init() -> void:
	id = &"golpe_aracnido"
	display_name = "Golpe Arácnido"
	description = "Piñas y patadas acrobáticas, muy rápidas: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.5
	channel_time = 0.0
	icon_color = Color(0.85, 0.12, 0.14)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.35, 0.30, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
