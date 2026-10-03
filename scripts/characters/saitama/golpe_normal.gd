class_name GolpeNormal
extends Ability
## Slot 0 de Saitama: "GOLPE NORMAL". Golpe basico, GRATIS como todos.
##
## Una piña comun y corriente, sin cara de nada. Pega un poco mas que el basico de los
## demas, pero es mas lento: Saitama no tira golpes de mas.

const DAMAGE: float = 15.0
const CONE_RANGE: float = 3.3
const CONE_ANGLE: float = 70.0
## Empuja poco: un basico que aleja al rival obliga a un kit de cuerpo a cuerpo a
## perseguirlo despues de cada piña.
const KNOCKBACK: float = 2.5


func _init() -> void:
	id = &"golpe_normal"
	display_name = "Golpe normal"
	description = "Una piña normal. Nada especial: %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.72
	channel_time = 0.0
	icon_color = Color(1.0, 0.86, 0.20)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.2)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.95, 0.80, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
