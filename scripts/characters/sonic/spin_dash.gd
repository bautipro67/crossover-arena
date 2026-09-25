class_name SpinDash
extends Ability
## Slot 1 de Sonic: "SPIN DASH".
##
## Se enrolla, carga en el lugar y sale disparado atropellando todo lo que cruce.
##
## LA CARGA ES LA HABILIDAD, no un retardo. En los juegos de Sonic el Spin Dash se carga
## quieto y recien despues sale; ese momento parado es lo que lo hace legible y lo que le
## da al rival la unica oportunidad de quitarse. Un dash instantaneo seria mas comodo y
## seria otra habilidad.
##
## ATRAVIESA Y SIGUE, no frena en el primero que toca. Es lo que lo distingue del JARONA
## de Flowery, que rebota: aquel castiga quedarse en el camino una y otra vez, este premia
## alinear a varios en una linea. Los dos son embestidas y no se juegan igual.

const DAMAGE: float = 24.0
const SPEED: float = 27.0
# RUEDA MAS LEJOS Y SALE ANTES.
#
# Con 0.42 de recorrido y 0.34 de carga, el Spin Dash tardaba casi tanto en salir como en
# llegar: once metros por un tercio de segundo parado. Un Spin Dash es una BOLA QUE RUEDA,
# y lo que hace que valga la pena es que cruza medio campo. Ahora son 0.24 de carga y
# 0.58 rodando: quince metros y medio, y se suelta antes de que el rival termine de leerlo.
const DURATION: float = 0.58
const HIT_RADIUS: float = 1.5
const KNOCKBACK: float = 7.0
const KNOCKBACK_LIFT: float = 2.0
## Lo que tarda enrollandose antes de salir. Sale de la carga del original.
const CARGA: float = 0.24
const ESTELA := Color(0.35, 0.62, 1.0, 0.55)


func _init() -> void:
	id = &"spin_dash"
	display_name = "Spin Dash"
	description = "Carga en el lugar y sale disparado. Atropella a todos los que cruce (%d)." % int(DAMAGE)
	stamina_cost = 26.0
	cooldown = 6.0
	channel_time = 0.0
	icon_color = Color(0.35, 0.65, 1.0)


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

	# La carga: quieto, enrollado y sonando. El aviso es a proposito.
	FX.spawn_spin_charge(caster3d, CARGA)
	Sfx.play_3d(caster, &"dash", origin, -3.0)
	await tree.create_timer(CARGA).timeout
	if Ability.interrumpida(caster3d):
		return

	# El rumbo se vuelve a leer DESPUES de cargar. Durante la carga el jugador sigue
	# apuntando, y salir hacia donde miraba hace un tercio de segundo se siente a que la
	# habilidad no obedece.
	var apunta := caster3d.get("aim_override") as Vector3
	if apunta != null and not apunta.is_zero_approx():
		rumbo = Vector3(apunta.x, 0.0, apunta.z).normalized()

	var source_id: int = caster.peer_id
	var golpeados: Dictionary = {}
	# frenar_al_tocar en FALSE: atraviesa y sigue. Es la diferencia con el JARONA.
	var tocados := await FloweryDash.pasada(
		caster3d, rumbo, SPEED, DURATION, HIT_RADIUS, golpeados, false, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	for target: Node3D in tocados:
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.45, 0.75, 1.0, 0.95))
	FX.camera_shake(0.5 if tocados.is_empty() else 1.0)
