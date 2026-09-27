class_name GearFifth
extends Ability
## Slot 3 de Luffy: "GEAR FIFTH". Su definitiva.
##
## El despertar de su fruta: Luffy se vuelve blanco, se rie, y todo lo que hace se vuelve
## caricatura y pega mas fuerte. Aca es una transformacion como la de Super Sonic —mas
## rapido, mas fuerte y mas duro— con un estallido al empezar que empuja a todos.

const DURACION: float = 9.0
const VELOCIDAD: float = 1.25
const RESISTENCIA: float = 0.8
const POTENCIA: float = 1.35
const RADIO_ESTALLIDO: float = 6.0
const DAÑO_ESTALLIDO: float = 20.0


func _init() -> void:
	id = &"gear_fifth"
	display_name = "Gear Fifth"
	description = "%.0f s de Gear Fifth: x%.2f de velocidad, %d%% más de daño, y un estallido de %d al empezar." % [
		DURACION, VELOCIDAD, int((POTENCIA - 1.0) * 100.0), int(DAÑO_ESTALLIDO)]
	stamina_cost = 100.0
	cooldown = 0.0
	channel_time = 0.8
	requires_charge = true
	icon_color = Color(0.98, 0.98, 0.95)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var estado := caster.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.impulsar(VELOCIDAD, RESISTENCIA, POTENCIA, DURACION)
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIO_ESTALLIDO):
		CombatUtils.deal_damage(target, DAÑO_ESTALLIDO, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, 11.0, 3.0)
	FX.spawn_gear_fifth(caster3d, DURACION)
