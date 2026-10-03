class_name GolpeSerio
extends Ability
## Slot 3 de Saitama: "GOLPE SERIO" (Serie seria: golpe serio). Su definitiva.
##
## La unica vez que Saitama pega en serio. Echa el puño atras, la cara se le pone seria, y
## la piña sale como una onda que barre todo lo que tiene adelante: en la serie partio las
## nubes del planeta. Aca es una onda de choque recta, ancha y LARGA, que sale de una vez
## —no viaja como el Purpura— y manda a volar a todos los que estan en la linea.
##
## SE VE VENIR: la carga es larga y a la vista (el puño atras, el polvo que se levanta,
## el viento que se arremolina) y la onda la cortan las paredes, como al Kamehameha.
## Se esquiva saliendo de la linea o poniendo una cobertura en el medio.

const DAMAGE: float = 60.0
const ALCANCE: float = 34.0
## Medio ancho de la onda al salir; se abre con la distancia (ABRE por metro).
const ANCHO: float = 1.5
const ABRE: float = 0.06
const KNOCKBACK: float = 18.0
const KNOCKBACK_LIFT: float = 6.0


func _init() -> void:
	id = &"golpe_serio"
	display_name = "Golpe serio"
	description = "Cargás %.1fs con el puño atrás y soltás una onda de %d m que se lleva puesto a todo el que esté en la línea (%d). Las paredes la cortan." % [
		1.3, int(ALCANCE), int(DAMAGE)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 1.3
	requires_charge = true
	icon_color = Color(1.0, 0.82, 0.10)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var rumbo := rumbo_de(dir)
	if rumbo.is_zero_approx():
		return
	var largo := largo_hasta_pared(caster3d, origin, rumbo)
	var source_id: int = caster.peer_id
	for target: Node3D in alcanzados(caster3d, origin, rumbo, largo):
		# grants_charge = false: un ultimate no se paga el siguiente.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, rumbo, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.96, 0.85, 1.0))
	FX.spawn_golpe_serio(caster, origin, rumbo, largo)


static func spawn_cosmetic(caster: Node, origin: Vector3, dir: Vector3) -> void:
	if not (caster is Node3D):
		return
	var rumbo := rumbo_de(dir)
	if rumbo.is_zero_approx():
		return
	FX.spawn_golpe_serio(caster, origin, rumbo, largo_hasta_pared(caster as Node3D, origin, rumbo))


## Casi horizontal: apuntar al cielo no la manda a las nubes, apenas la levanta.
static func rumbo_de(dir: Vector3) -> Vector3:
	return Vector3(dir.x, dir.y * 0.35, dir.z).normalized()


## Los que estan adentro de la onda: un tronco de cono acostado sobre la linea.
static func alcanzados(caster: Node3D, origin: Vector3, rumbo: Vector3, largo: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for t: Node3D in CombatUtils._living_targets(caster):
		var hacia := (t.global_position + Vector3.UP) - origin
		var a_lo_largo := hacia.dot(rumbo)
		if a_lo_largo < -0.5 or a_lo_largo > largo:
			continue
		var de_costado := (hacia - rumbo * a_lo_largo).length()
		if de_costado <= ANCHO + ABRE * maxf(0.0, a_lo_largo) + 0.4:
			out.append(t)
	return out


## Hasta donde llega: el alcance entero o la primera pared. Lo usan el servidor y los
## clientes, con la misma cuenta, para que la onda se dibuje del largo con el que pego.
static func largo_hasta_pared(caster: Node3D, origin: Vector3, rumbo: Vector3) -> float:
	var mundo := caster.get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return ALCANCE
	var rayo := PhysicsRayQueryParameters3D.create(origin, origin + rumbo * ALCANCE)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	rayo.exclude = [caster.get_rid()]
	var golpe := mundo.direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return ALCANCE
	return origin.distance_to(golpe["position"] as Vector3)
