class_name SuperSalto
extends Ability
## Slot 2 de Mario: "SUPER SALTO". Salta alto y cae con un pisoton que aplasta alrededor.
##
## El salto es lo primero que se sabe de Mario —se llamo Jumpman antes de llamarse Mario—
## y el pisoton es como les gana a casi todos sus enemigos: cayendoles encima. Aca el
## pisoton pega en redondo al aterrizar, asi que sirve para meterse en el medio de varios
## y para zafar de uno que lo tenia encerrado: mientras sube no lo alcanza nadie a pie.
##
## CAE ENCIMA DEL QUE APUNTA. Con un rival a tiro adelante, el salto lo lleva hasta el; si
## no hay nadie, cae DISTANCIA_LIBRE mas adelante. Antes el avance era un empujon que el
## freno del movimiento mataba en un cuarto de segundo: Mario saltaba casi en el lugar, y
## el pisoton solo le pegaba al que ya tenia encima.
##
## EL SALTO LO HACEN EL EMPUJON Y LA CARGA DE LOS PERSONAJES (Player.apply_knockback para
## subir, Player.launch_charge para avanzar), que ya viajan por la red al dueño del cuerpo.
## La carga ignora el input mientras dura, como un salto de Mario: una vez en el aire, va
## a donde apunto. No pasa por CombatUtils.apply_knockback, y a proposito: ese camino lo
## frena la Superestrella, y con la estrella puesta Mario tiene que poder seguir saltando.

const IMPULSO_ARRIBA: float = 11.0
## Hasta donde busca a quien caerle encima, y que tan abierto.
const ALCANCE: float = 12.0
const ANGULO: float = 50.0
## Sin nadie a tiro, cae esto mas adelante.
const DISTANCIA_LIBRE: float = 7.0
## Cae un poco antes del centro del rival: los cuerpos chocan, y apuntando al centro
## quedaba parado arriba de su cabeza.
const ANTES_DEL_BLANCO: float = 0.8
## EN EL AIRE CORRIGE HACIA EL RIVAL, cada tanto: en el segundo largo que dura el salto,
## uno que camina se corria siete metros y el pisoton caia en el vacio. Con dos limites
## para que se pueda esquivar: no vuela mas rapido que VELOCIDAD_MAXIMA, y el ultimo
## tramo (SIN_CORREGIR) ya no corrige, asi que un dash a tiempo lo deja pisando el piso.
const CORREGIR_CADA: float = 0.2
const SIN_CORREGIR: float = 0.3
const VELOCIDAD_MAXIMA: float = 10.0
const RADIO: float = 4.5
const DAMAGE: float = 34.0
const KNOCKBACK: float = 8.0
const KNOCKBACK_LIFT: float = 3.5
## Lo minimo en el aire antes de contar el aterrizaje (recien salido, todavia esta en el
## piso), y lo maximo que se lo espera: con la gravedad del juego el salto dura 1.2 s.
const MINIMO_EN_EL_AIRE: float = 0.3
const MAXIMO_EN_EL_AIRE: float = 1.8


func _init() -> void:
	id = &"super_salto"
	display_name = "Súper Salto"
	description = "Salta bien alto y cae con un pisotón: %d de daño a todos a %.1f m." % [
		int(DAMAGE), RADIO]
	stamina_cost = 26.0
	cooldown = 9.0
	channel_time = 0.0
	icon_color = Color(0.95, 0.30, 0.25)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null or not caster3d.has_method("apply_knockback"):
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var plano := Vector3(dir.x, 0.0, dir.z).normalized()
	if plano.is_zero_approx():
		plano = -caster3d.global_transform.basis.z
	var tramo := plano * DISTANCIA_LIBRE
	var blanco := _blanco(caster3d, origin, plano)
	if blanco != null:
		var hacia := blanco.global_position - caster3d.global_position
		hacia.y = 0.0
		tramo = hacia.normalized() * maxf(0.0, hacia.length() - ANTES_DEL_BLANCO)
	# Lo que dura en el aire, con la gravedad del juego: el avance se reparte en ese tiempo
	# para caer justo donde apunto.
	var gravedad := float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
	var vuelo := 2.0 * IMPULSO_ARRIBA / maxf(1.0, gravedad)
	caster3d.call("apply_knockback", Vector3.UP * IMPULSO_ARRIBA)
	_avanzar(caster3d, tramo, vuelo)
	Sfx.play_3d(caster, &"salto", caster3d.global_position, 2.0)
	FX.spawn_impact_burst(caster, caster3d.global_position + Vector3.UP * 0.2, Color(0.95, 0.92, 0.85, 0.8))

	var t := 0.0
	var proxima := CORREGIR_CADA
	while t < MAXIMO_EN_EL_AIRE:
		await tree.physics_frame
		t += caster3d.get_physics_process_delta_time()
		if Ability.interrumpida(caster3d):
			return
		if t >= proxima and t < vuelo - SIN_CORREGIR and is_instance_valid(blanco) 				and not (blanco.get_node("Health") as Health).is_dead:
			proxima += CORREGIR_CADA
			var hacia := blanco.global_position - caster3d.global_position
			hacia.y = 0.0
			_avanzar(caster3d, hacia.normalized() * maxf(0.0, hacia.length() - ANTES_DEL_BLANCO), vuelo - t)
		var health := caster.get_node_or_null("Health") as Health
		if health != null and health.is_dead:
			return
		if t >= MINIMO_EN_EL_AIRE and _en_el_piso(caster3d):
			break

	# Si cayo antes de lo previsto —en un escalon, contra una pared—, no sigue patinando.
	if caster3d.has_method("stop_charge"):
		caster3d.call("stop_charge")
	# EL PISOTON, donde cayo.
	var punto := caster3d.global_position
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster3d, punto + Vector3.UP * 0.5, RADIO):
		CombatUtils.deal_damage(target, DAMAGE, source_id)
		CombatUtils.apply_knockback(target, target.global_position - punto, KNOCKBACK, KNOCKBACK_LIFT)
		FX.spawn_impact_burst(caster, target.global_position + Vector3.UP, Color(1.0, 0.85, 0.35, 0.95))
	FX.spawn_pisoton(caster3d, punto, RADIO)
	FX.camera_shake(1.2)
	Sfx.play_3d(caster, &"aterrizaje", punto, 4.0)


## Reparte `tramo` en los `resta` segundos que le quedan en el aire, sin pasarse de
## VELOCIDAD_MAXIMA.
static func _avanzar(caster: Node3D, tramo: Vector3, resta: float) -> void:
	if not caster.has_method("launch_charge") or resta <= 0.05:
		return
	if tramo.length() <= 0.2:
		caster.call("stop_charge")
		return
	caster.call("launch_charge", tramo.normalized(), minf(tramo.length() / resta, VELOCIDAD_MAXIMA), resta)


## A quien caerle encima: el mas cercano de los que tiene adelante.
static func _blanco(caster: Node3D, origin: Vector3, plano: Vector3) -> Node3D:
	var mejor: Node3D = null
	var mejor_dist := INF
	for t: Node3D in CombatUtils.get_players_in_cone(caster, origin, plano, ALCANCE, ANGULO):
		var d := caster.global_position.distance_to(t.global_position)
		if d < mejor_dist:
			mejor = t
			mejor_dist = d
	return mejor


## Tiene piso a menos de un palmo. Con un rayo y no con is_on_floor(): en el servidor, el
## cuerpo de un jugador remoto sigue la posicion que llega por la red y no corre su propia
## fisica, asi que is_on_floor() ahi no dice nada.
static func _en_el_piso(cuerpo: Node3D) -> bool:
	var espacio := cuerpo.get_world_3d().direct_space_state
	if espacio == null:
		return true
	var desde := cuerpo.global_position + Vector3.UP * 0.15
	var rayo := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 0.4)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	return not espacio.intersect_ray(rayo).is_empty()
