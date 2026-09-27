class_name TaijutsuNaruto
extends Ability
## Slot 0 de Naruto: "TAIJUTSU". Golpe basico, GRATIS como todos.
##
## Naruto pelea a las piñas y las patadas, sin estilo y con muchas ganas: rapido y de cerca.

const DAMAGE: float = 13.0
const CONE_RANGE: float = 3.0
const CONE_ANGLE: float = 70.0
const KNOCKBACK: float = 3.0


func _init() -> void:
	id = &"taijutsu_naruto"
	display_name = "Taijutsu"
	description = "Piñas y patadas rápidas: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.6
	channel_time = 0.0
	icon_color = Color(1.0, 0.55, 0.12)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.62, 0.20, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
