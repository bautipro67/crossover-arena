class_name PunoTitan
extends Ability
## Slot 0 de Thanos: "PUÑO DEL TITAN". Golpe basico, GRATIS como todos.
##
## Thanos pelea a las piñas aunque tenga el Guantelete: en la serie noquea a Hulk con los
## puños antes de usar una sola gema. Es el basico mas pesado del juego —pega mas que
## ninguno y empuja fuerte— y el mas lento: con un titan no se intercambian golpes, se lo
## esquiva.

const DAMAGE: float = 16.0
const CONE_RANGE: float = 3.4
const CONE_ANGLE: float = 70.0
const KNOCKBACK: float = 4.5


func _init() -> void:
	id = &"puno_titan"
	display_name = "Puño del Titán"
	description = "Un golpe de titán, lento y pesado: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.95
	channel_time = 0.0
	icon_color = Color(0.86, 0.68, 0.25)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.95, 0.78, 0.35, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
