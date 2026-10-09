class_name CorteTanjiro
extends Ability
## Slot 0 de Tanjiro: "CORTE". Golpe basico, GRATIS como todos.
##
## Un tajo de la katana negra, con el arco de agua de la Respiracion del Agua detras.

const DAMAGE: float = 13.0
const CONE_RANGE: float = 3.5
const CONE_ANGLE: float = 76.0
const KNOCKBACK: float = 3.0
const AGUA := Color(0.35, 0.65, 1.0)


func _init() -> void:
	id = &"corte_tanjiro"
	display_name = "Corte"
	description = "Un tajo de la katana, con el agua detrás: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.62
	channel_time = 0.0
	icon_color = AGUA


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.8)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.55, 0.80, 1.0, 0.95))
	FX.spawn_slash_arc(caster, origin, dir, AGUA)
