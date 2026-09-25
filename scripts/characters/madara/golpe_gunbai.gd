class_name GolpeGunbai
extends Ability
## Slot 0 de Madara: golpes con el GUNBAI, su abanico de guerra. Golpe basico, GRATIS.
##
## El gunbai es con lo que Madara pelea cuerpo a cuerpo en la guerra: lo usa de maza y de
## escudo, y lo tiene en la mano en casi todas sus peleas. Por ser grande pega un poco mas
## lejos y mas abierto que un puño, y sale un poco mas lento.

const DAMAGE: float = 12.0
const CONE_RANGE: float = 3.2
const CONE_ANGLE: float = 80.0
const KNOCKBACK: float = 3.0


func _init() -> void:
	id = &"gunbai"
	display_name = "Gunbai"
	description = "Golpes con el abanico de guerra, %d de daño. Gratis." % int(DAMAGE)
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.72
	channel_time = 0.0
	icon_color = Color(0.62, 0.55, 0.72)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(
			caster as Node3D, origin, dir, CONE_RANGE, CONE_ANGLE):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 0.5)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.85, 0.76, 0.98, 0.95))
	FX.spawn_melee_arc(caster, origin, dir)
