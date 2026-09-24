class_name Kamehameha
extends Ability
## Slot 3 de Goku: "KAMEHAMEHA". Su definitiva.
##
## Carga la energia entre las manos al costado del cuerpo y la suelta en un rayo recto.
##
## CANALIZADO, Y A LA VISTA, como en la serie: "ka... me... ha... me..." con las manos
## juntas, y recien en el "¡HA!" sale el rayo. Esa carga es lo que lo hace justo en un
## PvP: es el aviso de que viene, y lo que le da al otro la chance de salirse de la linea
## o de cortarlo. Durante la carga la camara sigue libre: se reapunta hasta el ultimo
## momento, que es lo que hace Goku girando las manos hacia el rival.
##
## UN RAYO QUE ATRAVIESA GENTE PERO NO PAREDES. Pega a todos los que esten en la linea
## —dos rivales alineados comen los dos—, y se corta en la primera pared: las coberturas
## de la arena siguen sirviendo contra el.
##
## ES UNA HABILIDAD DE PUNTERIA, y por eso pega fuerte. Snowgrave barre un cono de veinte
## metros; esto es una linea de un metro de ancho. Si erras, lo perdiste entero.

const DAMAGE: float = 58.0
const ALCANCE: float = 42.0
## Radio del rayo. Un poco mas ancho que un cuerpo: apuntarle al pecho tiene que alcanzar,
## no hace falta clavar el centro exacto.
const RADIO: float = 1.15
const KNOCKBACK: float = 13.0
const KNOCKBACK_LIFT: float = 3.4


func _init() -> void:
	id = &"kamehameha"
	display_name = "Kamehameha"
	description = "Cargás %.1fs y soltás un rayo de %d m que atraviesa a todos los que estén en la línea (%d). Las paredes lo cortan." % [
		1.3, int(ALCANCE), int(DAMAGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.3
	requires_charge = true
	icon_color = Color(0.45, 0.80, 1.0)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		return
	var largo := largo_hasta_pared(caster3d, origin, rumbo)

	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_line(caster3d, origin, rumbo, largo, RADIO):
		# grants_charge = false: un ultimate que pega fuerte no puede recargarse a si mismo.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(0.7, 0.92, 1.0, 1.0))

	FX.spawn_kamehameha(caster, origin, rumbo, largo)
	FX.camera_shake(1.8)
	Sfx.play_3d(caster, &"plasma_blast", origin, 2.0)


## Hasta donde llega el rayo: el alcance entero, o la primera pared.
##
## La usan el servidor —para saber a quien pega— y los clientes —para dibujarlo del largo
## correcto—. Tiene que ser la misma cuenta en los dos, o el rayo se dibuja atravesando
## una pared que en realidad lo corto.
static func largo_hasta_pared(caster: Node3D, origin: Vector3, rumbo: Vector3) -> float:
	var mundo := caster.get_world_3d()
	if mundo == null:
		return ALCANCE
	var espacio := mundo.direct_space_state
	if espacio == null:
		return ALCANCE
	var rayo := PhysicsRayQueryParameters3D.create(origin, origin + rumbo * ALCANCE)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	rayo.exclude = [caster.get_rid()]
	var golpe := espacio.intersect_ray(rayo)
	if golpe.is_empty():
		return ALCANCE
	return origin.distance_to(golpe["position"] as Vector3)
