class_name TengaiShinsei
extends Ability
## Slot 3 de Madara: "TENGAI SHINSEI", los meteoritos. Su definitiva.
##
## En la guerra Madara hace caer del cielo un meteorito del tamaño de una montaña, y cuando
## se lo frenan avisa que atras viene otro. Eso es esta habilidad: DOS METEORITOS GIGANTES,
## UNO TRAS OTRO, donde apunta.
##
## SE VEN VENIR, y eso es lo que la hace justa en un PvP: el primero sale a la vista desde
## arriba, y el piso marca donde va a caer mientras baja. El segundo viene escondido atras
## del primero —como en la serie— y pega en un radio mas grande: el que se aparto apenas
## del primero se come el segundo.
##
## CAE SOBRE EL QUE APUNTA. Apuntandole a alguien de frente, el rayo de la mira sigue de
## largo hasta una pared lejana, y los meteoritos caian veinte metros atras del rival: el
## punto es el primer rival sobre la linea de la mira, y si no hay nadie, el piso o la pared
## donde termina.

const ALCANCE: float = 36.0
## Lo ancho de la linea de la mira para encontrar a quien caerle: generoso, es un meteorito.
const RADIO_MIRA: float = 2.5
## Desde que sale hasta que pega el primero, y del primero al segundo.
const CAIDA: float = 1.6
const ENTRE: float = 1.3
const RADIO_PRIMERO: float = 7.0
const RADIO_SEGUNDO: float = 8.5
const DAMAGE: float = 40.0
const KNOCKBACK: float = 12.0
const KNOCKBACK_LIFT: float = 5.0


func _init() -> void:
	id = &"tengai_shinsei"
	display_name = "Tengai Shinsei"
	description = "Dos meteoritos gigantes, uno tras otro, donde apuntás: %d de daño cada uno en %d m a la redonda. Se ven venir." % [
		int(DAMAGE), int(RADIO_PRIMERO)]
	stamina_cost = 100.0
	cooldown = 10.0
	channel_time = 0.8
	requires_charge = true
	icon_color = Color(0.88, 0.36, 0.16)


func execute(caster: Node, origin: Vector3, dir: Vector3) -> void:
	var caster3d := caster as Node3D
	if caster3d == null:
		return
	var tree := caster.get_tree()
	if tree == null:
		return
	var punto := donde_caen(caster3d, origin, dir)
	# El sonido va adentro del efecto: el efecto corre en el servidor y en cada cliente.
	FX.spawn_tengai_shinsei(caster, punto, rumbo_de(caster3d, dir))
	await tree.create_timer(CAIDA).timeout
	if Ability.interrumpida(caster3d):
		return
	_impacto(caster3d, punto, RADIO_PRIMERO)
	await tree.create_timer(ENTRE).timeout
	if Ability.interrumpida(caster3d):
		return
	_impacto(caster3d, punto, RADIO_SEGUNDO)


static func _impacto(caster: Node3D, punto: Vector3, radio: float) -> void:
	var source_id: int = caster.peer_id
	for target: Node3D in CombatUtils.get_players_in_sphere(caster, punto + Vector3.UP, radio):
		# grants_charge = false: un ultimate que pega fuerte no puede recargarse a si mismo.
		CombatUtils.deal_damage(target, DAMAGE, source_id, false)
		CombatUtils.apply_knockback(target, target.global_position - punto, KNOCKBACK, KNOCKBACK_LIFT)


## Desde donde llegan: por detras de Madara, en la direccion en que mira.
static func rumbo_de(caster: Node3D, dir: Vector3) -> Vector3:
	var plano := Vector3(dir.x, 0.0, dir.z)
	if plano.is_zero_approx():
		plano = -caster.global_transform.basis.z
	return plano.normalized()


## Donde caen: el primer rival sobre la linea de la mira, o la pared o el piso donde
## termina. Siempre apoyado en el piso.
##
## La usan el servidor —para saber a quien pega— y los clientes —para dibujar la sombra y
## los meteoritos—. Es la misma cuenta en los dos.
static func donde_caen(caster: Node3D, origin: Vector3, dir: Vector3) -> Vector3:
	var rumbo := dir.normalized()
	if rumbo.is_zero_approx():
		rumbo = -caster.global_transform.basis.z
	var punto := origin + rumbo * ALCANCE
	var mas_cerca := INF
	for t: Node3D in CombatUtils.get_players_in_line(caster, origin, rumbo, ALCANCE, RADIO_MIRA):
		var d := origin.distance_to(t.global_position)
		if d < mas_cerca:
			mas_cerca = d
			punto = t.global_position
	var mundo := caster.get_world_3d()
	var espacio := mundo.direct_space_state if mundo != null else null
	if espacio == null:
		return punto
	if is_inf(mas_cerca):
		var rayo := PhysicsRayQueryParameters3D.create(origin, origin + rumbo * ALCANCE)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		rayo.exclude = [caster.get_rid()]
		var golpe := espacio.intersect_ray(rayo)
		if not golpe.is_empty():
			# Un poco antes de la pared, para que el meteorito no caiga del otro lado.
			punto = (golpe["position"] as Vector3) - rumbo * 0.5
	var abajo := PhysicsRayQueryParameters3D.create(punto + Vector3.UP * 3.0, punto + Vector3.DOWN * 60.0)
	abajo.collision_mask = GameConfig.LAYER_WORLD
	var piso := espacio.intersect_ray(abajo)
	if not piso.is_empty():
		punto = piso["position"]
	return punto
