class_name MarioCombo
extends Ability
## Slot 0 de Mario: "PUÑO Y PATADA". Golpe basico, GRATIS como todos.
##
## El combo de siempre de Mario cuando no tiene nada en la mano: un puño, otro, y una
## patada. Cuerpo a cuerpo y parejo, igual que el resto de su kit: Mario no es el mas
## fuerte ni el mas rapido en nada, es el que hace todo bien.

const DAMAGE: float = 12.0
const CONE_RANGE: float = 3.0
const CONE_ANGLE: float = 65.0
const KNOCKBACK: float = 2.5


func _init() -> void:
	id = &"mario_combo"
	display_name = "Puño y Patada"
	description = "Un puño, otro y una patada, cuerpo a cuerpo. %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.45
	channel_time = 0.0
	icon_color = Color(0.95, 0.22, 0.20)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.6)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.85, 0.35, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
