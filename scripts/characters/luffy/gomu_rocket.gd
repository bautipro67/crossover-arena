class_name GomuRocket
extends Ability
## Slot 2 de Luffy: "GOMU GOMU NO ROCKET".
##
## Se agarra de algo lejos, se estira y sale disparado como una goma. Aca sale volando hacia
## adelante, atropella lo que cruza y al llegar cae con todo encima de los que estan ahi.

const DAMAGE: float = 18.0
const SPEED: float = 30.0
const DURATION: float = 0.42
const HIT_RADIUS: float = 1.3
const RADIO_LLEGADA: float = 2.8
const KNOCKBACK: float = 8.0
const KNOCKBACK_LIFT: float = 3.0
const ESTELA := Color(1.0, 0.45, 0.35, 0.5)


func _init() -> void:
	id = &"gomu_rocket"
	display_name = "Gomu Gomu no Rocket"
	description = "Sale disparado como una goma: %d de daño a lo que cruza y a los que estan donde cae." % int(DAMAGE)
	stamina_cost = 24.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.50, 0.30)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z
	FX.spawn_brazo_goma(caster3d, origin, rumbo, 9.0)
	Sfx.play_3d(caster, &"goma", origin, 0.0)
	var golpeados: Dictionary = {}
	var tocados := await FloweryDash.pasada(caster3d, rumbo, SPEED, DURATION, HIT_RADIUS, golpeados, false, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	var source_id: int = caster3d.peer_id
	var llegada := caster3d.global_position
	# En Gear Fifth cae como un dibujo animado: el golpe de la llegada es mucho mas ancho.
	var radio := RADIO_LLEGADA * GearFifth.por(caster3d, 1.7)
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, llegada + Vector3.UP, radio):
		if not tocados.has(target):
			tocados.append(target)
	for target: Node3D in tocados:
		CombatUtils.deal_damage(target, DAMAGE * GearFifth.por(caster3d, GearFifth.DAÑO), source_id)
		CombatUtils.apply_knockback(target, target.global_position - llegada,
			KNOCKBACK * GearFifth.por(caster3d, GearFifth.EMPUJE), KNOCKBACK_LIFT)
	FX.spawn_pisoton(caster3d, llegada, radio)
