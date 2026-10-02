class_name GearFifth
extends Ability
## Slot 3 de Luffy: "GEAR FIFTH". Su definitiva.
##
## El despertar de su fruta: Luffy se vuelve blanco, se rie, y todo lo que hace se vuelve
## caricatura. Era una transformacion como la de Super Sonic —mas rapido, mas fuerte y mas
## duro— y se pidio que las definitivas genericas fueran distintas (2026-10-01).
##
## AHORA ES LO QUE HACE EN LA SERIE: LOS PUÑOS GIGANTES. En Gear 5 Luffy agranda las manos
## a lo bestia (el Bajrang Gun es un puño del tamaño de una isla), asi que mientras dura
## todo lo suyo llega mas lejos, pega en mas ancho y manda a volar como en un dibujo
## animado. No es mas rapido ni aguanta mas: pega distinto.

const DURACION: float = 9.0
## Cuanto mas lejos llegan los brazos, cuanto mas anchos son y cuanto mas empujan.
const ALCANCE: float = 1.7
const ANCHO: float = 2.3
const EMPUJE: float = 1.9
## Y un puño del tamaño de una casa pega mas fuerte que uno de persona.
const DAÑO: float = 1.35
const RADIO_ESTALLIDO: float = 6.0
const DAÑO_ESTALLIDO: float = 20.0


func _init() -> void:
	id = &"gear_fifth"
	display_name = "Gear Fifth"
	description = "%.0f s de Gear Fifth: los puños se vuelven gigantes, todo llega x%.1f más lejos, pega más ancho, %d%% más fuerte y manda a volar. Un estallido de %d al empezar." % [
		DURACION, ALCANCE, int(round((DAÑO - 1.0) * 100.0)), int(DAÑO_ESTALLIDO)]
	stamina_cost = 100.0
	cooldown = 0.0
	channel_time = 0.8
	requires_charge = true
	icon_color = Color(0.98, 0.98, 0.95)


func execute(caster: Node, origin: Vector3, _dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	activar(caster3d)
	var source_id: int = caster3d.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, origin, RADIO_ESTALLIDO):
		CombatUtils.deal_damage(target, DAÑO_ESTALLIDO, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - origin, 11.0 * EMPUJE, 4.0)
	FX.spawn_gear_fifth(caster3d, DURACION)


## Prende los puños gigantes: la marca que leen sus golpes y el dibujo de las manos. Lo
## llaman el servidor (execute) y los clientes (el cosmetico), asi los dos ven lo mismo.
static func activar(caster: Node3D) -> void:
	caster.set_meta(&"gear_fifth_hasta", Time.get_ticks_msec() / 1000.0 + DURACION)
	var visual: Variant = caster.get("visual")
	if visual != null and is_instance_valid(visual) and visual.has_method("punos_gigantes"):
		visual.punos_gigantes(DURACION)


## Esta en Gear Fifth? Lo preguntan el Pistol, el Gatling y el Rocket.
static func gigante(caster: Node) -> bool:
	return is_instance_valid(caster) \
		and float(caster.get_meta(&"gear_fifth_hasta", -1.0)) > Time.get_ticks_msec() / 1000.0


## Por cuanto se multiplica el alcance, el ancho o el empuje de un golpe de Luffy ahora.
static func por(caster: Node, cuanto: float) -> float:
	return cuanto if gigante(caster) else 1.0
