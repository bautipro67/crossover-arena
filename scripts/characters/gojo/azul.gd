class_name Azul
extends Ability
## Slot 1 de Gojo: "AZUL" (Lapse: Blue).
##
## La tecnica que atrae: un punto de energia azul que chupa todo lo que tiene alrededor
## hacia el centro. Cae sobre el primer rival de la mira —o nueve metros adelante si no
## hay nadie— y arrastra a todos los que esten cerca hasta juntarlos ahi.

const ALCANCE: float = 16.0
const RADIO_MIRA: float = 2.0
const SIN_BLANCO: float = 9.0
const RADIO: float = 6.0
const DAMAGE: float = 18.0
const TIRON_SPEED: float = 18.0
## Donde los deja: a esto del centro.
const QUEDA: float = 0.8


func _init() -> void:
	id = &"azul"
	display_name = "Azul"
	description = "Un punto azul que atrae a todos los que estén a %d m hacia el centro: %d de daño a cada uno." % [
		int(RADIO), int(DAMAGE)]
	stamina_cost = 26.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.30, 0.55, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var punto := donde(caster3d, origin, dir)
	FX.spawn_azul(caster, punto, RADIO)
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, punto, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null and estado.es_invencible():
			continue
		var hacia := punto - target.global_position
		var plano := Vector3(hacia.x, 0.0, hacia.z)
		var dist := plano.length()
		if dist > QUEDA + 0.2 and target.has_method("launch_charge"):
			target.call("launch_charge", plano / dist, TIRON_SPEED, (dist - QUEDA) / TIRON_SPEED)


## Donde se abre: el primer rival sobre la mira, o SIN_BLANCO metros adelante. La usan el
## servidor y los clientes.
static func donde(caster: Node3D, origin: Vector3, dir: Vector3) -> Vector3:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster.global_transform.basis.z
	var punto := origin + Vector3(rumbo.x, 0.0, rumbo.z).normalized() * SIN_BLANCO
	var cerca := INF
	for t: Node3D in CombatUtils.get_players_in_line(caster, origin, rumbo, ALCANCE, RADIO_MIRA):
		var d := origin.distance_to(t.global_position)
		if d < cerca:
			cerca = d
			punto = t.global_position + Vector3.UP
	return punto
