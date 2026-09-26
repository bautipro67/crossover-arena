class_name AlientoInfierno
extends Ability
## Slot 3 de Scorpion: "ALIENTO DEL INFIERNO". Su definitiva.
##
## La Fatality del primer Mortal Kombat: Scorpion se saca la mascara, abajo hay una
## calavera, y escupe el fuego del Inframundo sobre el que tiene adelante. Aca es un cono
## de fuego corto y ancho despues de la carga, que es cuando se ve la calavera.
##
## SE VE VENIR: la carga es larga y a la vista, y el grito sale al empezar. Congelarlo o
## aturdirlo la corta, como cualquier canalizado. Combina con la lanza: primero lo trae.

const DAMAGE: float = 60.0
const ALCANCE: float = 12.0
const ANGULO: float = 60.0
const KNOCKBACK: float = 7.0
const KNOCKBACK_LIFT: float = 2.0


func _init() -> void:
	id = &"aliento_infierno"
	display_name = "Aliento del Infierno"
	description = "Se saca la máscara y escupe el fuego del Inframundo: %d de daño en un cono de %d m." % [
		int(DAMAGE), int(ALCANCE)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(1.0, 0.30, 0.05)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(caster3d, origin, dir, ALCANCE, ANGULO):
		# El daño del ultimate no paga recursos: ver deal_damage.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, KNOCKBACK_LIFT)
	FX.spawn_aliento_infierno(caster, origin, dir, ALCANCE, ANGULO)
