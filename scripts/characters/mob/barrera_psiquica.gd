class_name BarreraPsiquica
extends Ability
## Slot 2 de Mob: "BARRERA". La burbuja de telequinesis con la que Mob se protege.
##
## En la serie la levanta sin pensar cada vez que algo le va a pegar, y el que estaba
## encima sale despedido. Las dos cosas: un escudo por unos segundos (el mismo de la
## Defensa de Hielo, Health.add_shield) y un empujon a todos los que tiene pegados.

const ESCUDO: float = 25.0
const DURACION: float = 4.0
const RADIO: float = 4.5
const DAMAGE: float = 12.0
const KNOCKBACK: float = 12.0
const KNOCKBACK_LIFT: float = 3.0


func _init() -> void:
	id = &"barrera_psiquica"
	display_name = "Barrera"
	description = "Una burbuja psíquica: escudo de %d por %d s, y empuja a todos a %.1f m (%d de daño)." % [
		int(ESCUDO), int(DURACION), RADIO, int(DAMAGE)]
	stamina_cost = 30.0
	cooldown = 13.5
	channel_time = 0.0
	icon_color = Color(0.55, 0.72, 1.0)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var health := caster.get_node_or_null("Health") as Health
	if health != null:
		health.add_shield(ESCUDO, DURACION)
	var source_id: int = caster.peer_id
	var centro := caster3d.global_position + Vector3.UP
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - caster3d.global_position,
			KNOCKBACK, KNOCKBACK_LIFT)
	FX.spawn_barrera(caster3d, DURACION, RADIO)
