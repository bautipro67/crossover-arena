class_name AlmaAzul
extends Ability
## Slot 2 de Sans: "ALMA AZUL".
##
## En su pelea, Sans te vuelve el alma azul y con eso te maneja la gravedad: te estrella
## contra el piso y no te deja saltar como quisieras. Aca, el primer rival de la mira queda
## con el alma azul: pesado y lento un rato, y el golpe contra el piso le saca vida.

const ALCANCE: float = 18.0
const RADIO_MIRA: float = 1.8
const DAMAGE: float = 14.0
const LENTO: float = 0.55
const LENTO_DURA: float = 2.2


func _init() -> void:
	id = &"alma_azul"
	display_name = "Alma Azul"
	description = "Le vuelve el alma azul al primero que apuntás: %d de daño y queda pesado y lento %.1f s." % [
		int(DAMAGE), LENTO_DURA]
	stamina_cost = 24.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.25, 0.45, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var blanco := primero_en_la_mira(caster3d, origin, dir)
	FX.spawn_alma_azul(caster, origin, blanco)
	if blanco == null:
		return
	CombatUtils.deal_damage(blanco, DAMAGE, caster3d.peer_id)
	var estado := blanco.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.apply_slow(LENTO, LENTO_DURA)


## El primer rival sobre la mira, o nadie. La usan el servidor y los clientes.
static func primero_en_la_mira(caster: Node3D, origin: Vector3, dir: Vector3) -> Node3D:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return null
	var mejor: Node3D = null
	var cerca := INF
	for t: Node3D in CombatUtils.get_players_in_line(caster, origin, rumbo, ALCANCE, RADIO_MIRA):
		var d := origin.distance_to(t.global_position)
		if d < cerca and CombatUtils.has_line_of_sight(caster, origin, t):
			cerca = d
			mejor = t
	return mejor
