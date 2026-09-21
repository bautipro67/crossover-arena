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
## Cuanto pesa ese empujon MIENTRAS VA EN CAMINO al jugador.
##
## Flojo a proposito: ahi compite con la ruta del navmesh. Con 0.9 sacaba a los bots del
## camino calculado, los volvia a meter contra las paredes y uno de los tres terminaba
## trabado el 29% del tiempo. Aca corrige, no manda.
const PESO_EN_RUTA: float = 0.4
## Y cuanto pesa YA PEGADO al jugador, que es un problema distinto.
##
## Aca no hay ruta que respetar —el bot orbita— asi que el empujon puede mandar. Hace
## falta que mande: con el mismo 0.4 de la ruta, los tres bots pasaban un tercio de la
## partida a menos de metro y medio uno del otro, tapandose entre si. Tres cuerpos
## encimados se leen como un enemigo solo y no podes elegir a cual pegarle.
const PESO_PEGADO: float = 0.55
## A que velocidad giran alrededor del jugador, en radianes por segundo. Lento: es una
## ronda que presiona, no un carrusel.
const ORBITA: float = 0.55
## Cada cuanto intenta un esquive, en segundos (se sortea en ese rango, por bot).
##
## POR QUE HACIA FALTA. Los bots NUNCA dasheaban, y eso es lo primero que los delata:
## cualquier persona se despega con un dash apenas la presionan, y un rival que camina
## en linea recta hacia vos no te enseña a leer un esquive. Ahora se van de costado cada
## tanto, y como el intervalo se sortea no podes contar los segundos.
const ESQUIVE_MIN: float = 2.2
const ESQUIVE_MAX: float = 4.8

## Apagable para el chequeo visual, que necesita capturas quietas y reproducibles, y
## desde el panel de practica. Arena.set_bots_active() escribe los dos lados.
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
## Sector propio alrededor del objetivo. Ver _puesto_de_pelea().
var _sector: float = 0.0
var _esquive_left: float = 0.0


func setup(body: Player, home_position: Vector3) -> void:
	_body = body
	home = home_position
	# Desfase inicial distinto por bot: si todos piensan en el mismo frame, atacan a la
	# vez y se lee como un solo enemigo con tres cuerpos.
	_think_left = randf() * THINK_INTERVAL
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	_esquive_left = ESQUIVE_MIN + randf() * (ESQUIVE_MAX - ESQUIVE_MIN)
	# Un sector por bot, repartidos parejo. El peer de un bot es -1, -2, -3...
	var indice := maxi(0, absi(body.peer_id) - 1)
	_sector = TAU * float(indice) / float(maxi(1, Arena.DUMMY_COUNT))


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
		# EL ULTIMATE ENTRA. Antes lo dejaba afuera por miedo a que fuera injusto, y era
		# el razonamiento al reves: los tres ultimates CANALIZAN a la vista de todos, o
		# sea que son justamente lo que MAS se puede practicar. Y son lo que mas falta
		# saber manejar —cortar un Snowgrave, salir de un ZA WARUDO— asi que un modo
		# practica donde nunca los ves no te prepara para lo unico que decide partidas.
		# El bot ademas carga el medidor pegando, y pega a un tercio de daño, o sea que
		# se lo gana despacio y no abre con el.
		if ability != null:
			_usable.append(i)
	set_process(true)


func _process(delta: float) -> void:
	if not is_instance_valid(_body) or not _is_server():
		return

	# DOS INTERRUPTORES, y los dos tienen que estar puestos. `globally_enabled` lo apagan
	# los arneses de prueba, que necesitan capturas quietas y reproducibles;
	# `bots_activos` lo apaga el jugador desde el panel de practica. Son independientes a
	# proposito: si el panel pisara al de los arneses, apagar los bots para sacar una
	# captura dejaria de funcionar.
	if not globally_enabled or not Practica.bots_activos:
		_body.bot_move_dir = Vector3.ZERO
		_body.bot_wants_run = false
		return
	if _body.health.is_dead or not _body.status.can_act():
		_body.bot_move_dir = Vector3.ZERO
		_body.bot_wants_run = false
		return

	_attack_left = maxf(0.0, _attack_left - delta)
	_esquive_left = maxf(0.0, _esquive_left - delta)

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

## El vivo mas cercano. Por defecto ignora a los otros bots y va solo por el jugador.
##
## CON `bots_se_pelean` PUESTO, tambien se eligen entre ellos, y eso cambia para que
## sirve el modo practica: pasa de ser un entrenamiento a ser una pelea que podes MIRAR.
## Es la unica forma de ver que hace un kit que no estas jugando —desde adentro nunca ves
## tu propia animacion completa— y ademas te deja entrar cuando dos ya se gastaron media
## barra, que es una situacion que practicando solo no se da nunca.
func _pick_target() -> Player:
	var best: Player = null
	var best_dist := detect_range()
	var entre_bots: bool = Practica.bots_se_pelean
	for node: Node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == null or other == _body:
			continue
		if other.is_dummy and not entre_bots:
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

	# CASTIGAR AL QUE CANALIZA: si el rival esta cargando algo, se le va encima en vez de
	# seguir orbitando en su sector.
	#
	# Es lo que le enseña al jugador que canalizar en campo abierto se paga. Sin esto se
	# puede cargar un Snowgrave a tres metros de un bot y el bot sigue haciendo circulos.
	if _esta_canalizando(target) and dist > TOO_CLOSE:
		_body.bot_wants_run = true
		_body.bot_move_dir = _rumbo_navegado(target.global_position)
		# Y si le da el dash, lo usa para llegar antes de que termine de cargar.
		if _esquive_left <= 0.0 and dist < 16.0 and _body.dash_hacia(plano):
			_reiniciar_esquive()
		_try_attack(dist)
		return

	# ESQUIVE. De costado si lo tiene cerca, de frente si esta lejos: de cerca sirve para
	# salirse de la linea de un ataque, de lejos para cerrar distancia.
	if _esquive_left <= 0.0 and dist < detect_range() * 0.35:
		var rumbo_esquive := lateral if dist < MELEE_RANGE + 5.0 else plano
		if _body.dash_hacia(rumbo_esquive):
			_reiniciar_esquive()
	# Corre solo para cerrar distancia. Pegado al rival camina, que es lo que deja leer
	# sus movimientos y poder esquivarlos.
	_body.bot_wants_run = dist > MELEE_RANGE + 2.5

	if dist > MELEE_RANGE + 6.0:
		# LEJOS: manda el camino del navmesh y nada mas.
		#
		# Cualquier cosa que se le sume durante el trayecto largo lo desvia de la ruta
		# calculada y lo vuelve a meter contra una pared, que es justo lo que el navmesh
		# viene a resolver.
		_body.bot_move_dir = _rumbo_navegado(target.global_position)
	else:
		# CERCA: va a SU puesto alrededor del jugador, no encima del jugador.
		var puesto := _puesto_de_pelea(target)
		var hacia_puesto := puesto - _body.global_position
		hacia_puesto.y = 0.0
		var falta := hacia_puesto.length()
		if falta < 0.4:
			# Ya esta donde queria: se queda ahi, encarado. Que un bot se plante a veces
			# tambien se lee mejor que uno que tiembla alrededor de su marca.
			_body.bot_move_dir = Vector3.ZERO
		elif falta < 1.5:
			# Al lado del puesto va derecho: a esta distancia el navmesh devuelve rumbos
			# erraticos porque el destino cae dentro del radio del punto actual.
			_body.bot_move_dir = (hacia_puesto.normalized() + _separacion(PESO_PEGADO)).normalized()
		else:
			# Y el resto TAMBIEN POR EL CAMINO DEL NAVMESH.
			#
			# La primera version iba derecho al puesto en cuanto entraba en los ultimos
			# seis metros, y eso reintrodujo el problema que el navmesh resuelve: si entre
			# el bot y su puesto hay una cobertura, camina contra ella. Medido: un bot
			# trabado el 28% de la partida. Estar cerca del jugador no quiere decir que el
			# camino este libre.
			_body.bot_move_dir = (_rumbo_navegado(puesto)
				+ _separacion(PESO_PEGADO)).normalized()

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
		&"snowgrave":
			# Barre un cono de 20 m: tirarlo de mas lejos es regalar el medidor.
			return dist < 17.0
		&"za_warudo":
			# Detiene el tiempo a su alrededor: solo sirve con el rival encima.
			return dist < 9.0
		&"last_jarona":
			# Es una embestida larga: sale de lejos, pero no de punta a punta del mapa.
			return dist < 20.0
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


## Esta el objetivo cargando una habilidad?
static func _esta_canalizando(target: Player) -> bool:
	var ac := target.get_node_or_null("AbilityCaster") as AbilityCaster
	return ac != null and ac.is_channeling


func _reiniciar_esquive() -> void:
	_esquive_left = ESQUIVE_MIN + randf() * (ESQUIVE_MAX - ESQUIVE_MIN)


## Donde quiere pararse este bot: a distancia de pelea del objetivo, pero EN SU SECTOR.
##
## POR QUE UN SECTOR Y NO SOLO UN EMPUJON ENTRE ELLOS. Antes los tres apuntaban al mismo
## punto —el jugador— y se despegaban a empujones. No alcanza, y se puede ver por que: la
## atraccion al jugador y la repulsion entre bots son las dos simetricas, asi que los
## tres terminan oscilando alrededor del mismo lugar. Medido: un tercio de la partida a
## menos de metro y medio uno del otro. Y subir la fuerza del empujon lo EMPEORO —de 27%
## a 41%—, porque un empujon mas fuerte no rompe la simetria, la hace rebotar mas rapido.
##
## Con un sector propio cada uno se para en un lado distinto por construccion, sin
## depender de que las fuerzas se acomoden. Ademas se juega mejor: quedas rodeado en vez
## de amontonado, y tenes que girar la camara en vez de mirar a un solo bulto.
##
## El sector gira despacio (ORBITA) para que no sea una formacion congelada, y GIRA CON
## UN RELOJ COMPARTIDO, no con uno por bot.
##
## Esa parte no es un detalle. La primera version hacia avanzar la orbita de cada bot por
## su cuenta y para el lado de su strafe, que se invierte al azar cada dos o tres
## segundos. El reparto de 120 grados no se mantenia: los angulos derivaban solos hasta
## juntarse, y el amontonamiento volvia entre el 18% y el 46% segun la corrida. Con un
## reloj comun la separacion angular es exacta todo el tiempo, por construccion.
func _puesto_de_pelea(target: Player) -> Vector3:
	var angulo := _sector + float(Time.get_ticks_msec()) * 0.001 * ORBITA
	var ideal := target.global_position + Vector3(cos(angulo), 0.0, sin(angulo)) * MELEE_RANGE
	# Y PEGADO AL NAVMESH, porque el puesto ideal puede caer adentro de una cobertura.
	#
	# Cuando caia ahi, is_target_reachable() daba false, el rumbo se iba al de linea recta
	# y el bot caminaba derecho contra el bloque: las trabas volvieron al 10%. Pedirle al
	# navegador el punto navegable mas cercano mueve el puesto justo hasta el borde de la
	# cobertura, que ademas es una posicion sensata para pararse a pelear.
	var mapa := _body.get_world_3d().navigation_map
	if not mapa.is_valid():
		return ideal
	return NavigationServer3D.map_get_closest_point(mapa, ideal)


## Empujon lateral para no encimarse con los otros bots.
##
## Los bots no colisionan entre si (su mascara es solo el mundo), asi que sin esto
## terminan literalmente adentro del mismo espacio. Medido: 0.7 metros entre los tres.
##
## Ahora es un CORRECTOR, no el mecanismo: de repartirlos se encarga _puesto_de_pelea().
## Esto solo resuelve el caso en que dos sectores se crucen igual, por ejemplo cuando el
## jugador se mueve rapido y los puestos de dos bots quedan momentaneamente juntos.
func _separacion(peso: float) -> Vector3:
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
	return empuje * peso


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
