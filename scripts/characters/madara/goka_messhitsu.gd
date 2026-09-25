class_name GokaMesshitsu
extends Ability
## Slot 1 de Madara: "KATON: GŌKA MESSHITSU", la gran destruccion de fuego.
##
## Madara toma aire y lo suelta en un muro de fuego que tapa todo lo que tiene adelante: en
## la serie cubre un campo de batalla entero, y hace falta un escuadron de ninjas de agua
## para frenarlo. Aca es un cono ANCHO y medianamente largo. No se esquiva corriendo para
## el costado a ultimo momento, como una bola: se esquiva saliendo del frente mientras toma
## aire, que es lo que dura el canalizado.
##
## LAS PAREDES LO CORTAN (el cono pide linea de vista): las coberturas sirven contra el.

const DAMAGE: float = 21.0
const ALCANCE: float = 10.0
const ANGULO: float = 70.0
const KNOCKBACK: float = 5.0


func _init() -> void:
	id = &"goka_messhitsu"
	display_name = "Katon: Gōka Messhitsu"
	description = "Toma aire y suelta un muro de fuego: %d de daño a todos en un cono de %d m." % [
		int(DAMAGE), int(ALCANCE)]
	stamina_cost = 30.0
	cooldown = 9.0
	channel_time = 0.45
	icon_color = Color(1.0, 0.45, 0.12)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_cone(caster3d, origin, dir, ALCANCE, ANGULO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - origin, KNOCKBACK, 1.0)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.55, 0.15, 0.95))
	FX.spawn_katon(caster, origin, dir, ALCANCE, ANGULO)
