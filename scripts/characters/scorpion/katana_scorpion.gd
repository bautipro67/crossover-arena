class_name KatanaScorpion
extends Ability
## Slot 0 de Scorpion: "KATANA". Golpe basico, GRATIS como todos.
##
## Scorpion pelea con la espada del Shirai Ryu —la que lleva a la espalda desde Mortal
## Kombat 9— ademas de la lanza. Un tajo rapido y ancho de cerca: el que se trajo con la
## cadena queda justo donde llega.

const DAMAGE: float = 16.0
const CONE_RANGE: float = 3.3
const CONE_ANGLE: float = 80.0
const KNOCKBACK: float = 3.0


func _init() -> void:
	id = &"katana_scorpion"
	display_name = "Katana"
	description = "Un tajo de espada, rápido y ancho: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.66
	channel_time = 0.0
	icon_color = Color(0.95, 0.74, 0.18)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.72, 0.25, 0.95))
	FX.spawn_slash_arc(caster, origin, dir, Color(1.0, 0.80, 0.35))
