class_name GokuCombo
extends Ability
## Slot 0 de Goku: la combinacion de golpes. Golpe basico, GRATIS como todos.
##
## Es lo que Goku hace antes que cualquier tecnica de ki: pelear a las piñas. Toda la
## serie lo muestra igual —un intercambio rapido de golpes y patadas cuerpo a cuerpo antes
## de separarse—, y un basico a distancia lo volveria un tirador, que no es.
##
## Entre los basicos queda en el medio a proposito: pega un poco mas que el de Sonic y un
## poco menos que el MUDA de Dio, y sale mas seguido que el de Dio. Es el todoterreno
## tambien aca.

const DAMAGE: float = 12.0
const CONE_RANGE: float = 3.0
const CONE_ANGLE: float = 65.0
const KNOCKBACK: float = 2.4


func _init() -> void:
	id = &"goku_combo"
	display_name = "Combo de Golpes"
	description = "Golpes y patadas cuerpo a cuerpo, %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.42
	channel_time = 0.0
	icon_color = Color(1.0, 0.58, 0.18)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.5)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.75, 0.35, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
