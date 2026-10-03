class_name Partir
extends Ability
## Slot 0 de Sukuna: "PARTIR" (Hachi). Golpe basico, GRATIS como todos.
##
## Un zarpazo con las uñas que deja dos cortes cruzados en el aire. Corto, rapido y un
## poco mas abierto que una piña: Sukuna pelea de cerca riendose.

const DAMAGE: float = 13.0
const CONE_RANGE: float = 3.4
const CONE_ANGLE: float = 82.0
const KNOCKBACK: float = 3.0
const ROJO := Color(0.95, 0.18, 0.20)


func _init() -> void:
	id = &"partir"
	display_name = "Partir"
	description = "Un zarpazo que deja dos cortes cruzados: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.6
	channel_time = 0.0
	icon_color = ROJO


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.8)
		FX.spawn_cortes(caster, target.global_position + Vector3.UP * 1.1, 2)
	FX.spawn_slash_arc(caster, origin, dir, ROJO)
