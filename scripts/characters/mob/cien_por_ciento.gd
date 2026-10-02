class_name CienPorCiento
extends Ability
## Slot 3 de Mob: "100%". Su definitiva.
##
## Mob guarda todo lo que siente, y el medidor de la serie cuenta cuanto: cuando llega al
## 100%, lo que venia aguantando sale de una vez. Se carga a la vista —el pelo flota, sube
## el numero— y revienta en una onda psiquica enorme.
##
## Y LO QUE HACE EN LA SERIE CON ESA FUERZA: LEVANTA TODO. Antes, despues de la onda, Mob
## quedaba "potenciado" unos segundos (mas rapido, mas duro, pegando mas): la misma
## transformacion que Super Sonic y el Gear Fifth, y se pidio que las definitivas genericas
## fueran distintas (2026-10-01). Ahora la onda alza en el aire a todos los que agarra, los
## deja colgando sin poder hacer nada, y los estrella contra el piso.
##
## El daño de la definitiva no paga recursos: no recarga el medidor ni devuelve stamina.

const RADIO: float = 10.0
const DAMAGE: float = 50.0
## Lo que los levanta, y cuanto quedan colgando sin poder moverse ni atacar.
const LEVANTA: float = 11.0
const COLGADOS: float = 2.0
## Cuando caen, el golpe contra el piso.
const AL_PISO: float = 0.95
const DAÑO_PISO: float = 40.0
## Lo que dura el aura del 100% (el pelo flotando, la luz): lo que dura levantarlos.
const DURACION: float = 2.4


func _init() -> void:
	id = &"cien_por_ciento"
	display_name = "100%"
	description = "Llega al 100%%: una onda psíquica de %d m (%d de daño) que levanta a todos en el aire, los deja colgando %.1f s y los estrella contra el piso (%d más)." % [
		int(RADIO), int(DAMAGE), COLGADOS, int(DAÑO_PISO)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.2
	requires_charge = true
	icon_color = Color(0.85, 0.92, 1.0)


func execute(caster: Node, _origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var source_id: int = caster.peer_id
	var centro := caster3d.global_position + Vector3.UP
	var alzados: Array[Node3D] = []
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, centro, RADIO):
		# grants_charge = false: un ultimate que pega fuerte no puede recargarse a si mismo.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		var estado := target.get_node_or_null("StatusEffects") as StatusEffects
		if estado != null:
			estado.stun_for(COLGADOS)
		# Casi derecho para arriba: un poco hacia afuera para que no caigan encima de Mob.
		CombatUtils.apply_knockback(target, target.global_position - caster3d.global_position,
			2.5, LEVANTA)
		alzados.append(target)
	FX.spawn_cien_por_ciento(caster3d, RADIO, DURACION)
	for target: Node3D in alzados:
		FX.spawn_impact_burst(target, target.global_position + Vector3.UP, Color(0.80, 0.90, 1.0))

	var tree := caster3d.get_tree()
	if tree == null or alzados.is_empty():
		return
	await tree.create_timer(AL_PISO).timeout
	if not is_instance_valid(caster3d):
		return
	for target: Node3D in alzados:
		if not is_instance_valid(target):
			continue
		var vida := target.get_node_or_null("Health") as Health
		if vida == null or vida.is_dead:
			continue
		CombatUtils.deal_damage(target, DAÑO_PISO, source_id, false)
		FX.spawn_pisoton(caster3d, target.global_position, 1.8)
	FX.camera_shake(1.2)
