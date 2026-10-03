class_name SaltosSerios
extends Ability
## Slot 2 de Saitama: "SALTOS LATERALES SERIOS".
##
## De la pelea con Sonic el Supersonico: salta de un costado al otro tan rapido que deja
## imagenes suyas por todos lados. Aca son tres saltos en zigzag hacia donde apunta, y
## mientras salta NO LO TOCA NADA (StatusEffects.estrella): es su forma de esquivar una
## definitiva o de meterse encima de alguien. Al caer, una piña a los que quedaron cerca.

const SALTOS: int = 3
const SPEED: float = 30.0
const DURACION_SALTO: float = 0.14
## Cuanto se abre cada salto de la linea de avance, en grados.
const ABERTURA: float = 48.0
const DAMAGE: float = 16.0
const RADIO_LLEGADA: float = 3.0
const KNOCKBACK: float = 6.0
const ESTELA := Color(1.0, 0.92, 0.35, 0.45)


func _init() -> void:
	id = &"saltos_serios"
	display_name = "Saltos laterales serios"
	description = "Tres saltos en zigzag tan rápidos que nada lo toca mientras salta. Al caer, %d de daño a los que están cerca." % int(DAMAGE)
	stamina_cost = 22.0
	cooldown = 6.5
	channel_time = 0.0
	icon_color = Color(1.0, 0.95, 0.55)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z
	var estado := caster3d.get_node_or_null("StatusEffects") as StatusEffects
	if estado != null:
		estado.estrella(float(SALTOS) * DURACION_SALTO + 0.12)
	Sfx.play_3d(caster, &"dash", origin, 0.0)
	var golpeados: Dictionary = {}
	for k: int in range(SALTOS):
		var lado := 1.0 if k % 2 == 0 else -1.0
		# El ultimo va derecho: termina donde apuntaba, no a un costado.
		var giro := 0.0 if k == SALTOS - 1 else deg_to_rad(ABERTURA) * lado
		FX.spawn_imagen_residual(caster3d, Color(1.0, 0.85, 0.20))
		await FloweryDash.pasada(caster3d, rumbo.rotated(Vector3.UP, giro), SPEED, DURACION_SALTO,
			0.0, golpeados, false, ESTELA)
		if Ability.interrumpida(caster3d):
			return
	var source_id: int = caster3d.peer_id
	var llegada := caster3d.global_position
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, llegada + Vector3.UP, RADIO_LLEGADA):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - llegada, KNOCKBACK, 2.0)
		FX.spawn_impact_burst(caster3d, target.global_position + Vector3.UP, Color(1.0, 0.95, 0.80, 0.95))
