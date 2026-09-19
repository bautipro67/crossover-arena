class_name BotBrain
extends Node
## Cerebro de un bot del modo practica. Va como hijo del Player que controla.
##
## QUE TIENE QUE LOGRAR: que practicar se parezca a pelear. Un maniqui quieto te deja
## ensayar la animacion de un combo, pero no te enseña nada de lo unico que importa en
## esta arena — medir distancia, usar las coberturas y elegir cuando gastar stamina.
##
## QUE NO TIENE QUE HACER: ganarte. Un bot con punteria perfecta y reaccion de un frame
## no es dificil, es injusto, y practicar contra el te enseña mañas que no sirven contra
## una persona. Por eso piensa cada 200 ms y no en cada frame, y no usa el ultimate.
##
## CORRE SOLO EN EL SERVIDOR. Los bots existen unicamente en modo practica, que no abre
## ninguna conexion, pero la guarda esta igual por si algun dia se usan en una partida.

## Cada cuanto reevalua. Es tambien su tiempo de reaccion: bajarlo lo vuelve
## sobrehumano, subirlo lo vuelve tonto de una forma que se nota fea.
const THINK_INTERVAL: float = 0.2
## A partir de aca deja de perseguir y vuelve a su puesto.
const DETECT_RANGE: float = 34.0
## Distancia a la que se planta a pelear cuerpo a cuerpo.
const MELEE_RANGE: float = 2.7
## Mas cerca que esto, retrocede.
##
## Subio de 1.7 a 2.4 mirando capturas: a 1.7 el bot se metia literalmente adentro de
## la camara en tercera persona y tapaba media pantalla con su torso. No es solo feo,
## es injugable — no ves lo que te esta por pegar.
const TOO_CLOSE: float = 2.4
## Cuanto se puede alejar de su puesto antes de volver.
const LEASH: float = 46.0
## Pausa propia entre habilidad y habilidad, aparte de los cooldowns del juego.
##
## Sin esto el bot encadena todo lo que tiene disponible en el mismo instante y tres
## bots bajan al jugador de 100 a 14 en dos segundos y medio. Medido, no estimado.
## No es dificultad: es que no da tiempo a reaccionar, que es lo contrario de lo que
## tiene que enseñar el modo practica.
const ATTACK_COOLDOWN: float = 0.55
## Cuanto mira hacia adelante para esquivar. Poco mas que un par de pasos: mas lejos y
## empieza a rodear coberturas que todavia no le estorban.
const AVOID_DISTANCE: float = 2.8

## Apagable para el chequeo visual, que necesita capturas quietas y reproducibles.
static var globally_enabled: bool = true

var home: Vector3 = Vector3.ZERO

var _body: Player = null
var _think_left: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_left: float = 0.0
var _attack_left: float = 0.0
## Indices de habilidad que este bot puede usar, sin el ultimate.
var _usable: Array[int] = []


func setup(body: Player, home_position: Vector3) -> void:
	_body = body
	home = home_position
	# Desfase inicial distinto por bot: si todos piensan en el mismo frame, atacan a la
	# vez y se lee como un solo enemigo con tres cuerpos.
	_think_left = randf() * THINK_INTERVAL
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	set_process(false)
	# Esperamos un frame: el kit lo carga setup_character y puede no estar todavia.
	await get_tree().process_frame
	if not is_instance_valid(_body):
		return
	_usable.clear()
	for i: int in range(_body.caster.abilities.size()):
		var ability := _body.caster.abilities[i]
		# El ultimate queda afuera a proposito: 260 de daño sin aviso no se practica,
		# se sufre. Y el medidor se lo ganaria pegandote, o sea justo cuando ya vas
		# perdiendo el intercambio.
		if ability != null and not ability.requires_charge:
			_usable.append(i)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_body) or not _is_server():
		return

	if not globally_enabled or _body.health.is_dead or not _body.status.can_act():
		_body.bot_move_dir = Vector3.ZERO
		_body.bot_wants_run = false
		return

	_attack_left = maxf(0.0, _attack_left - delta)

	_strafe_left -= delta
	if _strafe_left <= 0.0:
		# Cambiar de lado cada tanto hace que no sea un blanco que se acerca en linea
		# recta, que es trivial de castigar.
		_strafe_left = 1.1 + randf() * 1.4
		_strafe_dir = -_strafe_dir

	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = THINK_INTERVAL

	var target := _pick_target()
	if target == null:
		_go_home()
		return
	_fight(target)


# ---------------------------------------------------------------------- Decisiones

## El vivo mas cercano que no sea otro bot. Los bots no se pelean entre ellos: seria
## gracioso una vez y despues dejaria al jugador mirando.
func _pick_target() -> Player:
	var best: Player = null
	var best_dist := DETECT_RANGE
	for node: Node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == null or other == _body or other.is_dummy:
			continue
		if not is_instance_valid(other) or other.health.is_dead:
			continue
		var d := _body.global_position.distance_to(other.global_position)
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _fight(target: Player) -> void:
	var hacia := target.global_position - _body.global_position
	var dist := Vector3(hacia.x, 0.0, hacia.z).length()
	var plano := Vector3(hacia.x, 0.0, hacia.z).normalized()
	if plano.is_zero_approx():
		plano = -_body.global_transform.basis.z

	# Mirar y apuntar al objetivo. El apuntado va por aim_override porque un bot no
	# tiene camara: get_aim_direction() saldria de un CameraPivot apagado.
	_body.bot_look_yaw = atan2(-plano.x, -plano.z)
	_body.aim_override = (target.get_aim_origin() - _body.get_aim_origin()).normalized()

	# Si se alejo demasiado de su puesto, vuelve aunque tenga a quien pegarle. Sin esto
	# los tres bots terminan arrinconando al jugador contra una pared del mapa.
	if _body.global_position.distance_to(home) > LEASH:
		_go_home()
		return

	var lateral := plano.cross(Vector3.UP) * _strafe_dir
	# Corre solo para cerrar distancia. Pegado al rival camina, que es lo que deja leer
	# sus movimientos y poder esquivarlos.
	_body.bot_wants_run = dist > MELEE_RANGE + 2.5
	var deseada: Vector3
	if dist > MELEE_RANGE:
		# Se acerca, pero en diagonal: de frente es un blanco perfecto.
		deseada = (plano + lateral * 0.35).normalized()
	elif dist < TOO_CLOSE:
		deseada = (-plano + lateral * 0.5).normalized()
	else:
		deseada = lateral
	_body.bot_move_dir = _esquivar(deseada)

	_try_attack(dist)


## Elige que tirar segun la distancia. Recorre el kit de la mas cara a la mas barata,
## asi usa la habilidad buena cuando puede y cae al golpe gratis cuando no.
func _try_attack(dist: float) -> void:
	var caster := _body.caster
	if caster.is_channeling or _attack_left > 0.0:
		return

	for i: int in _usable:
		if i == 0:
			continue  # el basico lo dejamos para el final
		var ability := caster.get_ability(i)
		if ability == null or caster.is_on_cooldown(i):
			continue
		if not _body.stamina.has_enough(ability.stamina_cost):
			continue
		# Las habilidades cuerpo a cuerpo solo de cerca; las de rango, de lejos.
		if not _good_distance(ability, dist):
			continue
		caster.request_use(i)
		_attack_left = ATTACK_COOLDOWN
		return

	# Golpe basico: gratis, asi que siempre que este a tiro.
	if dist <= MELEE_RANGE + 0.6 and not caster.is_on_cooldown(0):
		caster.request_use(0)
		_attack_left = ATTACK_COOLDOWN


## Rango util aproximado de cada habilidad, por id. No lee el alcance real porque cada
## habilidad lo guarda en su propia constante; esto es una tabla de intenciones y con
## eso alcanza para que el bot no tire un cono de 3m desde quince metros.
func _good_distance(ability: Ability, dist: float) -> bool:
	match ability.id:
		&"ice_shock", &"knife_throw":
			return dist > 3.0 and dist < 26.0
		&"stand_barrage":
			return dist <= 3.4
		&"ice_defense":
			# Defensiva: la levanta cuando la tiene cerca, que es cuando le sirve.
			return dist < 8.0
		_:
			return dist <= MELEE_RANGE + 0.6


func _go_home() -> void:
	_body.aim_override = Vector3.ZERO
	var hacia := home - _body.global_position
	hacia.y = 0.0
	if hacia.length() < 1.0:
		_body.bot_move_dir = Vector3.ZERO
		_body.bot_wants_run = false
		return
	_body.bot_wants_run = hacia.length() > 8.0
	_body.bot_move_dir = _esquivar(hacia.normalized())
	_body.bot_look_yaw = atan2(-hacia.x, -hacia.z)


## Esquiva lo que tenga adelante desviando la direccion, sin navmesh.
##
## POR QUE HACE FALTA: el mapa tiene 18 coberturas y el bot va derecho a donde esta el
## jugador. Sin esto se clava contra el primer bloque que se le cruza y se queda
## empujando la pared, que es la forma mas rapida de que un bot se vea roto. Medido
## antes de agregarlo: cerraba 4 metros en dos segundos corriendo a 9.
##
## No es pathfinding: no rodea un laberinto. Alcanza para coberturas sueltas, que es lo
## que hay, y cuesta tres rayos cortos cada 200 ms.
func _esquivar(deseada: Vector3) -> Vector3:
	if deseada.is_zero_approx():
		return deseada
	if _libre(deseada):
		return deseada
	# Bloqueado de frente: probamos abrirnos, primero poco y despues mucho, y hacia el
	# lado al que ya venia haciendo strafe para no dudar y quedarse temblando.
	for grados: float in [45.0, -45.0, 80.0, -80.0]:
		var giro := deseada.rotated(Vector3.UP, deg_to_rad(grados * _strafe_dir))
		if _libre(giro):
			return giro
	return deseada


func _libre(dir: Vector3) -> bool:
	var space := _body.get_world_3d().direct_space_state
	if space == null:
		return true
	# A la altura del pecho: a la altura de los pies pegaria contra cualquier rampa.
	var desde := _body.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(desde, desde + dir.normalized() * AVOID_DISTANCE)
	query.collision_mask = GameConfig.LAYER_WORLD
	return space.intersect_ray(query).is_empty()


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
