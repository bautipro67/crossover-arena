class_name RuedaDeAgua
extends Ability
## Slot 1 de Tanjiro: "RESPIRACION DEL AGUA, SEGUNDA FORMA: RUEDA DE AGUA".
##
## Da una vuelta en el aire hacia adelante con la katana: un tramo corto a toda velocidad,
## cortando a todos los que cruza (no se frena en el primero) y levantandolos.

const DAMAGE: float = 17.0
const SPEED: float = 25.0
const DURATION: float = 0.30
const HIT_RADIUS: float = 1.5
const KNOCKBACK: float = 6.0
const KNOCKBACK_LIFT: float = 4.5
const ESTELA := Color(0.40, 0.70, 1.0, 0.55)


func _init() -> void:
	id = &"rueda_agua"
	display_name = "Rueda de Agua"
	description = "Una vuelta hacia adelante con la katana: corta a todos los que cruza (%d) y los levanta." % int(DAMAGE)
	stamina_cost = 24.0
	cooldown = 6.5
	channel_time = 0.0
	icon_color = Color(0.40, 0.70, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z
	FX.spawn_rueda_agua(caster3d, rumbo)
	Sfx.play_3d(caster, &"agua", origin, 0.0)
	var golpeados: Dictionary = {}
	var tocados := await FloweryDash.pasada(caster3d, rumbo, SPEED, DURATION, HIT_RADIUS, golpeados, false, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	for target: Node3D in tocados:
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster3d, target.global_position + Vector3.UP, Color(0.55, 0.80, 1.0, 0.95))
