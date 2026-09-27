class_name Balanceo
extends Ability
## Slot 2 de Spider-Man: "BALANCEO".
##
## Tira una tela hacia arriba y se balancea: la forma en que se mueve por la ciudad. Aca sale
## volando hacia adelante colgado de la tela y patea al que se cruza en el camino.

const DAMAGE: float = 18.0
const SPEED: float = 26.0
const DURATION: float = 0.5
const HIT_RADIUS: float = 1.3
const KNOCKBACK: float = 6.0
const KNOCKBACK_LIFT: float = 2.0
const ESTELA := Color(0.90, 0.20, 0.25, 0.5)


func _init() -> void:
	id = &"balanceo"
	display_name = "Balanceo"
	description = "Se cuelga de una tela y sale volando hacia adelante: %d de daño al que patea en el camino." % int(DAMAGE)
	stamina_cost = 22.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(0.25, 0.40, 0.95)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z
	FX.spawn_hilo_balanceo(caster3d, rumbo, DURATION)
	Sfx.play_3d(caster, &"telarana", origin, 0.0)
	var golpeados: Dictionary = {}
	var tocados := await FloweryDash.pasada(caster3d, rumbo, SPEED, DURATION, HIT_RADIUS, golpeados, false, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	for target: Node3D in tocados:
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.35, 0.30, 0.95))
