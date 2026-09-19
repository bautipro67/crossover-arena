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
##
## SE DERIVA DEL MAPA, no es un numero suelto. Estuvo fijo en 34 metros y cuando la
## arena paso de 60 a 92 quedo mas corto que media diagonal: los bots nacian a 50
## metros del jugador, nunca lo detectaban y se quedaban parados toda la partida. El
## modo practica estuvo roto hasta que lo medi.
##
## La diagonal de un cuadrado de lado L es L * 1.415. Con eso, un bot ve cualquier
## punto del mapa desde cualquier otro, que es lo que tiene que pasar en una arena de
## tres bots contra uno: si no te encuentran, no hay practica.
static func detect_range() -> float:
	return Arena.ARENA_SIZE * 1.5
## Distancia a la que se planta a pelear cuerpo a cuerpo.
const MELEE_RANGE: float = 2.7
## Mas cerca que esto, retrocede.
##
## Subio de 1.7 a 2.4 mirando capturas: a 1.7 el bot se metia literalmente adentro de
## la camara en tercera persona y tapaba media pantalla con su torso. No es solo feo,
## es injugable — no ves lo que te esta por pegar.
const TOO_CLOSE: float = 2.4
## Cuanto se puede alejar de su puesto antes de volver.
##
## Tambien derivada del mapa. Existe para que un bot no se vaya al infinito si algo sale
## mal, NO para limitar la persecucion: con la correa vieja de 46 metros, un jugador
## parado en una esquina quedaba fuera de alcance y los bots se daban media vuelta.
static func leash() -> float:
	return Arena.ARENA_SIZE * 1.5
## Pausa propia entre habilidad y habilidad, aparte de los cooldowns del juego.
##
## Sin esto el bot encadena todo lo que tiene disponible en el mismo instante y tres
## bots bajan al jugador de 100 a 14 en dos segundos y medio. Medido, no estimado.
## No es dificultad: es que no da tiempo a reaccionar, que es lo contrario de lo que
## tiene que enseñar el modo practica.
const ATTACK_COOLDOWN: float = 0.9
## A que distancia empiezan a separarse entre ellos.
##
## Sin esto los tres convergen al mismo punto y terminan a 70 cm uno de otro: se tapan,
## se leen como un solo enemigo con tres cuerpos y no podes elegir a cual pegarle.
const SEPARACION: float = 3.2

## Apagable para el chequeo visual, que necesita capturas quietas y reproducibles.
static var globally_enabled: bool = true

var home: Vector3 = Vector3.ZERO

var _body: Player = null
## Navegacion real. Reemplaza a la evasion por rayos, que no sabia rodear nada mas
## grande que un bloque suelto.
var _agent: NavigationAgent3D = null
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

	_agent = NavigationAgent3D.new()
	_agent.name = "NavAgent"
	_agent.radius = 0.55
	_agent.height = 1.8
	# Cada cuanto da por alcanzado un punto del camino. Muy chico y el bot se queda
	# orbitando el punto sin llegar; muy grande y corta las esquinas por adentro de las
	# coberturas.
	_agent.path_desired_distance = 0.9
	_agent.target_desired_distance = 1.2
	# Sin evasion entre agentes: los bots no colisionan entre si (solo con el mundo), y
	# prenderla los hacia orbitarse en vez de ir al jugador.
	_agent.avoidance_enabled = false
	# CUELGA DEL PLAYER, no de este nodo.
	#
	# NavigationAgent3D saca su posicion del PADRE. BotBrain es un Node pelado, sin
	# transform, asi que colgado de aca el agente no sabia donde estaba: pedia caminos
	# desde el origen del mundo, is_target_reachable() daba siempre false y el bot caia
	# al rumbo recto y se empotraba contra la plataforma central.
	#
	# Sintoma que lo delato: el servidor de navegacion devolvia un camino de 30 puntos
	# para el mismo par de posiciones que el agente daba por inalcanzable.
	_body.add_child(_agent)

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
		# Mas lento que antes (1.1-2.5s): con el cambio rapido, el bot invertia el rumbo
		# una vez por segundo y se veia indeciso en vez de esquivo.
		_strafe_left = 1.9 + randf() * 1.8
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
	var best_dist := detect_range()
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
	if _body.global_position.distance_to(home) > leash():
		_go_home()
		return

	var lateral := plano.cross(Vector3.UP) * _strafe_dir
	# Corre solo para cerrar distancia. Pegado al rival camina, que es lo que deja leer
	# sus movimientos y poder esquivarlos.
	_body.bot_wants_run = dist > MELEE_RANGE + 2.5

	if dist > MELEE_RANGE:
		# LEJOS: va por el camino del navmesh, que rodea las coberturas.
		#
		# El strafe lateral se suma SOLO un poco y solo en los ultimos metros. Mezclarlo
		# durante todo el trayecto desviaba al bot del camino calculado y volvia a
		# meterlo contra las paredes, que es justo lo que el navmesh viene a resolver.
		var camino := _rumbo_navegado(target.global_position)
		if dist < MELEE_RANGE + 6.0:
			# Solo en los ultimos metros se le suma strafe y separacion. Durante el
			# trayecto largo manda el camino y nada mas: cualquier cosa que se le sume
			# ahi lo desvia de la ruta y lo vuelve a meter contra una pared.
			camino = (camino + lateral * 0.35 + _separacion()).normalized()
		_body.bot_move_dir = camino
	elif dist < TOO_CLOSE:
		# PEGADO: ya no hace falta camino, y a un metro el navmesh devuelve rumbos
		# erraticos porque el objetivo esta dentro del radio del punto actual.
		_body.bot_move_dir = (-plano + lateral * 0.5 + _separacion()).normalized()
	else:
		_body.bot_move_dir = (lateral + _separacion()).normalized()

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
	_body.bot_move_dir = _rumbo_navegado(home)
	_body.bot_look_yaw = atan2(-hacia.x, -hacia.z)


## Empujon lateral para no encimarse con los otros bots.
##
## Los bots no colisionan entre si (su mascara es solo el mundo), asi que sin esto
## terminan literalmente adentro del mismo espacio. Medido: 0.7 metros entre los tres.
func _separacion() -> Vector3:
	var empuje := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group("players"):
		var otro := node as Player
		if otro == null or otro == _body or not otro.is_dummy:
			continue
		if not is_instance_valid(otro) or otro.health.is_dead:
			continue
		var d := _body.global_position - otro.global_position
		d.y = 0.0
		var dist := d.length()
		if dist > SEPARACION or dist < 0.01:
			continue
		# Cuanto mas cerca, mas fuerte. Al borde del radio no aporta nada, asi que no
		# desvia a un bot que ya estaba lo bastante lejos.
		empuje += d.normalized() * (1.0 - dist / SEPARACION)
	# Flojo a proposito: es un empujon que corrige, no un rumbo que manda. Con 0.9
	# competia con el camino del navmesh, sacaba a los bots de la ruta y uno de los
	# tres volvia a quedarse trabado el 29% del tiempo.
	return empuje * 0.4


## Rumbo hacia `destino` segun el camino del navmesh.
##
## Devuelve la direccion al PROXIMO punto del camino, no al destino final: eso es lo que
## hace que el bot rodee la plataforma central en vez de empotrarse contra ella.
##
## Si la navegacion todavia no esta lista (el primer frame, antes de que el mapa termine
## de hornearse) cae a la linea recta, que es peor pero no es nada.
func _rumbo_navegado(destino: Vector3) -> Vector3:
	if _agent == null or not _agent.is_inside_tree():
		return _recto_hacia(destino)
	_agent.target_position = destino
	if not _agent.is_target_reachable():
		return _recto_hacia(destino)
	var siguiente := _agent.get_next_path_position()
	var dir := siguiente - _body.global_position
	dir.y = 0.0
	if dir.length() < 0.05:
		return _recto_hacia(destino)
	return dir.normalized()


func _recto_hacia(destino: Vector3) -> Vector3:
	var dir := destino - _body.global_position
	dir.y = 0.0
	if dir.is_zero_approx():
		return Vector3.ZERO
	return dir.normalized()


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()
