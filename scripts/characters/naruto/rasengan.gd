class_name Rasengan
extends Ability
## Slot 2 de Naruto: "RASENGAN".
##
## La esfera de chakra que gira en la palma: la arma en un instante y sale corriendo a
## estamparsela al primero que tenga adelante. Frena en el que toca, como un golpe, y lo
## manda lejos.

const DAMAGE: float = 26.0
const CARGA: float = 0.3
const SPEED: float = 24.0
const DURATION: float = 0.45
const HIT_RADIUS: float = 1.4
const KNOCKBACK: float = 12.0
const KNOCKBACK_LIFT: float = 3.5
const ESTELA := Color(0.45, 0.75, 1.0, 0.55)


func _init() -> void:
	id = &"rasengan"
	display_name = "Rasengan"
	description = "Arma la esfera en la mano y se la estampa al primero que alcanza: %d de daño y lo manda lejos." % int(DAMAGE)
	stamina_cost = 28.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.40, 0.70, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z
	FX.spawn_esfera_mano(caster3d, Color(0.45, 0.75, 1.0), CARGA + DURATION)
	await tree.create_timer(CARGA).timeout
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	var golpeados: Dictionary = {}
	var tocados := await FloweryDash.pasada(caster3d, rumbo, SPEED, DURATION, HIT_RADIUS, golpeados, true, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	for target: Node3D in tocados:
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_plasma_blast(caster, target.global_position + Vector3.UP, 1.6)
	FX.camera_shake(0.4 if tocados.is_empty() else 1.1)
