class_name HereICome
extends Ability
## Slot 2 de Flowery: "Here I Come, San Francisco".
##
## Su embestida contra el Roaring Knight: se tira contra algo mucho mas grande que el.
##
## DIFERENCIA CON JARONA, que tambien es una embestida:
##
##   JARONA      -> muchas pasadas cortas. Si conecta rebota y vuelve. Es persistencia.
##   HERE I COME -> UNA pasada. Si conecta, se le prende encima y le mete una CADENA de
##                  golpes seguidos. Es compromiso.
##
## O sea: Jarona te pasa por encima varias veces, esta te agarra una vez y no te suelta.
##
## NO TIENE CASTIGO POR FALLAR. Le habia puesto un "queda expuesto un segundo" que no
## estaba en el pedido; era una idea mia sobre lo que la habilidad deberia costar, no lo
## que se me pidio que hiciera. Lo que se pidio es una embestida que, si conecta, encadena
## golpes. Eso, y nada mas.
##
## Va en naranja: la pelea de Flowery es donde Deltarune introduce el dash del ALMA
## NARANJA, y esta habilidad es ese dash.

const SPEED: float = 27.0
const DASH_TIME: float = 0.42
const HIT_RADIUS: float = 2.3
## El golpe de la embestida, antes de la cadena.
const IMPACT_DAMAGE: float = 14.0
## La cadena: golpes rapidos al que engancho.
const CHAIN_HITS: int = 5
const CHAIN_DAMAGE: float = 11.0
const CHAIN_INTERVAL: float = 0.12
## Alcance de la cadena. Si el rival se escapa de este radio, la cadena se corta: no es
## un agarre garantizado, es una presion que se puede romper.
const CHAIN_RANGE: float = 3.4
## El ultimo golpe de la cadena manda lejos.
const FINISH_KNOCKBACK: float = 11.0
const FINISH_LIFT: float = 3.0
## Naranja, como el ALMA NARANJA que su pelea introduce y de donde sale este dash.
const ESTELA: Color = Color(1.0, 0.58, 0.18)


func _init() -> void:
	id = &"here_i_come"
	display_name = "Here I Come, San Francisco"
	description = "Embiste. Si engancha, se le prende encima y le mete %d golpes seguidos (%d + %dx%d)." % [
		CHAIN_HITS, int(IMPACT_DAMAGE), CHAIN_HITS, int(CHAIN_DAMAGE)]
	stamina_cost = 30.0
	cooldown = 8.0
	channel_time = 0.0
	icon_color = Color(1.0, 0.58, 0.18)


## CORRE EN EL SERVIDOR. Corrutina: la embestida y despues la cadena.
func execute(caster: Node, _origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var source_id: int = caster.peer_id

	var rumbo := Vector3(dir.x, 0.0, dir.z).normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster3d.global_transform.basis.z

	FX.spawn_charge_burst(caster, caster3d.global_position, rumbo)

	var golpeados: Dictionary = {}
	# FRENA AL CONTACTO: esta habilidad se PRENDE del rival, no lo atraviesa. Sin
	# frenar, la embestida terminaba cinco metros pasado el objetivo y la cadena no
	# llegaba a nadie.
	var tocados := await FloweryDash.pasada(
		caster3d, rumbo, SPEED, DASH_TIME, HIT_RADIUS, golpeados, true, ESTELA)
	if Ability.interrumpida(caster3d):
		return
	FloweryDash.frenar(caster3d)

	if tocados.is_empty():
		FX.spawn_charge_landing(caster, caster3d.global_position)
		return

	# --- Enganchado: la cadena ---
	var victima := tocados[0]
	CombatUtils.deal_damage(victima, IMPACT_DAMAGE, source_id)
	FX.spawn_hit_impact(caster, victima.global_position + Vector3.UP, IMPACT_DAMAGE,
		Color(1.0, 0.62, 0.24))

	for i: int in range(CHAIN_HITS):
		await tree.create_timer(CHAIN_INTERVAL).timeout
		if Ability.interrumpida(caster3d) or not is_instance_valid(victima):
			break
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			break
		var estado := caster.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null and not estado.can_act():
			break
		# Se le escapo: la cadena se corta. Es la contra de la habilidad.
		if caster3d.global_position.distance_to(victima.global_position) > CHAIN_RANGE:
			break

		var es_ultimo := i == CHAIN_HITS - 1
		CombatUtils.deal_damage(victima, CHAIN_DAMAGE, source_id)
		FX.spawn_hit_impact(caster, victima.global_position + Vector3.UP, CHAIN_DAMAGE,
			Color(1.0, 0.62, 0.24))
		if es_ultimo:
			var lejos := victima.global_position - caster3d.global_position
			CombatUtils.apply_knockback(victima, lejos, FINISH_KNOCKBACK, FINISH_LIFT)
			FX.spawn_jarona_blast(caster3d, victima.global_position)

