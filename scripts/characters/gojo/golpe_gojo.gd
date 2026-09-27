class_name GolpeGojo
extends Ability
## Slot 0 de Gojo: "GOLPE". Golpe basico, GRATIS como todos.
##
## Gojo pelea a las piñas con las manos en los bolsillos hasta que se aburre: rapido y
## sin esfuerzo.

const DAMAGE: float = 14.0
const CONE_RANGE: float = 3.2
const CONE_ANGLE: float = 72.0
const KNOCKBACK: float = 3.5


func _init() -> void:
	id = &"golpe_gojo"
	display_name = "Golpe"
	description = "Un golpe rápido, sin esfuerzo: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.62
	channel_time = 0.0
	icon_color = Color(0.55, 0.75, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.60, 0.80, 1.0, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
