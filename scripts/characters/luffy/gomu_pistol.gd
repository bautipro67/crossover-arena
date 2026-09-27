class_name GomuPistol
extends Ability
## Slot 0 de Luffy: "GOMU GOMU NO PISTOL". Golpe basico, GRATIS como todos.
##
## El primer golpe que se le ve a Luffy: estira el brazo de goma y la piña llega lejos. Es
## un basico de cuerpo a cuerpo con mas alcance que ninguno, en linea recta: pega en todo
## lo que cruza el brazo.

const DAMAGE: float = 11.0
const LARGO: float = 6.0
const RADIO: float = 0.9
const KNOCKBACK: float = 4.0


func _init() -> void:
	id = &"gomu_pistol"
	display_name = "Gomu Gomu no Pistol"
	description = "Estira el brazo de goma: una piña de %d de daño que llega a %d m. Gratis." % [
		int(DAMAGE), int(LARGO)]
	stamina_cost = 0.0  # <- GRATIS A PROPOSITO. No le pongas costo.
	cooldown = 0.72
	channel_time = 0.0
	icon_color = Color(0.85, 0.15, 0.12)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := dir.normalized()
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_line(caster3d, origin, rumbo, LARGO, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.85, 0.70, 0.95))
	FX.spawn_brazo_goma(caster3d, origin, rumbo, LARGO)
