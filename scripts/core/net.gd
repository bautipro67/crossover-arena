extends Node
## Autoload: Net
## Conexion, lista de jugadores y marcador.
##
## El peer 1 es la autoridad de TODO lo que importa (daño, stamina, kills, respawn).
## Puede ser un jugador que hostea (listen server) o un servidor dedicado que no juega.
##
## TRANSPORTE: WebSocket en TODAS las plataformas.
##
## Por que no ENet, que es UDP y seria mejor para un juego de accion: el export web NO
## puede abrir sockets UDP, punto. Si el escritorio usara ENet y el navegador WebSocket,
## tendriamos dos redes incompatibles y un jugador de navegador nunca podria entrar al
## servidor de uno de escritorio. Un solo transporte = todos juegan juntos.
##
## El costo es real y conviene tenerlo presente: TCP reordena y reenvia, asi que con mal
## ping se nota mas que con UDP. A 20 Hz de sincronizacion y con el daño resuelto en el
## servidor, es perfectamente jugable.
##
## Como el juego entero usa la API de alto nivel (rpc/rpc_id) y no toca el peer despues
## de crearlo, cambiar de transporte fue cambiar que clase se instancia.

signal player_list_changed()
signal connection_failed()
signal server_disconnected()
signal match_started()
signal match_ended(winner_id: int)
## Seguimos insistiendo con un servidor que todavia no contesta (attempt, segundos).
signal connection_retrying(attempt: int, elapsed: float)
signal kill_registered(killer_id: int, victim_id: int)
## Cambio el mapa elegido para la proxima partida (la sala lo muestra).
signal mapa_cambiado()
signal modo_cambiado()

# --------------------------------------------------------------- Los modos en linea
#
# MAS MODOS EN LINEA (2026-10-10, "haz mas modos multijugador online"). Hasta aca habia uno
# solo, todos contra todos a quince bajas. Ahora son cinco, y los decide el servidor: el
# publico los va rotando con el mapa en cada partida, y el que hostea lo elige en la sala.
# Las reglas que cambian el combate (caos, un toque) las leen Modos y CombatUtils; el daño
# lo decide siempre el servidor, asi que un cliente desactualizado no puede saltearlas.
const MODO_TODOS: StringName = &"todos"
const MODO_EQUIPOS: StringName = &"equipos"
const MODO_COLINA: StringName = &"colina"
const MODO_CAOS: StringName = &"caos"
const MODO_TOQUE: StringName = &"toque"
const MODOS_ONLINE: Array[StringName] = [MODO_TODOS, MODO_EQUIPOS, MODO_COLINA, MODO_CAOS, MODO_TOQUE]
## Lo que hay que juntar para ganar en cada uno: bajas propias, bajas del equipo o puntos.
const META_ONLINE: Dictionary = {
	MODO_TODOS: 15, MODO_EQUIPOS: 25, MODO_COLINA: 60, MODO_CAOS: 20, MODO_TOQUE: 10,
}
## La colina en linea: el circulo del centro, y cada cuanto suma un punto el que esta solo.
const RADIO_COLINA_ONLINE: float = 8.0
const EQUIPO_NOMBRES: Array[String] = ["ROJO", "AZUL"]
const EQUIPO_COLORES: Array[Color] = [Color(1.0, 0.42, 0.42), Color(0.45, 0.70, 1.0)]

var modo_online: StringName = MODO_TODOS

## peer_id -> {name: String, character_id: String, kills: int, deaths: int}
var players: Dictionary = {}
var local_name: String = "Jugador"
var local_character_id: String = "noelle"
var in_match: bool = false
## Partida de practica sin red: no se abre ningun puerto y la arena spawnea maniquies.
var solo_mode: bool = false

## Servidor que no juega: no se spawnea a si mismo ni aparece en la lista.
var dedicated: bool = false

var _peer: WebSocketMultiplayerPeer = null

## REINTENTOS AL CONECTAR, para servidores que se duermen.
##
## Un hosting gratuito (Render, Fly) apaga la instancia cuando no queda nadie conectado
## y tarda en volver. El primer intento del que entra despues NO falla porque el servidor
## no exista: falla porque se esta prendiendo. Rendirse ahi le muestra "no se pudo
## conectar" a alguien cuyo servidor esta perfecto, y ese jugador no vuelve.
##
## Asi que insistimos en silencio hasta WAKE_TIMEOUT y avisamos que estamos esperando.
const WAKE_TIMEOUT: float = 75.0
## Pausa entre intentos. Golpear mas seguido no lo despierta antes.
const RETRY_DELAY: float = 3.0
## Cuanto le damos a UN intento antes de descartarlo. Hace falta porque un socket contra
## una instancia apagada puede quedarse colgado sin dar error nunca.
const ATTEMPT_TIMEOUT: float = 9.0

var _joining: bool = false
var _join_address: String = ""
var _join_port: int = 0
var _join_elapsed: float = 0.0
var _attempt_elapsed: float = 0.0
var _join_attempt: int = 0

## Peers que ya terminaron de armar la arena y pueden recibir RPCs de jugadores.
##
## Sin esto, el servidor le manda posiciones y estados a un cliente que todavia no
## creo los nodos, y ENet tira "Node not found / Invalid packet received". El cliente
## avisa que esta listo (Arena._srv_client_ready) y recien ahi entra en esta lista.
var _ready_peers: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ------------------------------------------------------------------ Conexion

## Practica en solitario. No abre puerto ni toca la red: el juego entero ya funciona
## sin peer (is_server() devuelve true cuando no hay multiplayer_peer), asi que solo
## hay que armar la lista de jugadores a mano.
func start_solo(player_name: String) -> void:
	leave_game()
	local_name = _clean_name(player_name)
	players.clear()
	players[1] = _make_entry(local_name, local_character_id)
	solo_mode = true
	player_list_changed.emit()


## Un navegador NO puede escuchar en un puerto: solo puede ser cliente. Hostear es
## cosa del build de escritorio o del servidor dedicado.
func can_host() -> bool:
	return not OS.has_feature("web")


func host_game(port: int, player_name: String) -> Error:
	if not can_host():
		return ERR_UNAVAILABLE
	leave_game()
	local_name = _clean_name(player_name)
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_server(port)
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	players.clear()
	players[1] = _make_entry(local_name, local_character_id)
	player_list_changed.emit()
	return OK


## Servidor que no juega. Lo usa el build dedicado en el VPS.
func host_dedicated(port: int) -> Error:
	var err := host_game(port, "Servidor")
	if err != OK:
		return err
	dedicated = true
	# El servidor no es un jugador: se saca de la lista para que no aparezca en el
	# marcador ni cuente para el spawn.
	players.clear()
	player_list_changed.emit()
	return OK


func join_game(address: String, port: int, player_name: String) -> Error:
	leave_game()
	local_name = _clean_name(player_name)

	# OJO: esto va DESPUES de leave_game(), que apaga _joining.
	_join_address = address
	_join_port = port
	_join_elapsed = 0.0
	_attempt_elapsed = 0.0
	_join_attempt = 1

	var err := _open_client()
	if err != OK:
		return err
	_joining = true
	return OK


func _open_client() -> Error:
	_peer = WebSocketMultiplayerPeer.new()
	var err := _peer.create_client(build_url(_join_address, _join_port))
	if err != OK:
		_peer = null
		return err
	multiplayer.multiplayer_peer = _peer
	return OK


## Estamos esperando a que un servidor conteste?
func is_joining() -> bool:
	return _joining


func join_elapsed() -> float:
	return _join_elapsed


func _process(delta: float) -> void:
	if not _joining:
		return
	_join_elapsed += delta
	_attempt_elapsed += delta
	var peer := multiplayer.multiplayer_peer
	if peer == null:
		return  # entre intento e intento no hay peer; el timer lo vuelve a abrir
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		return
	# Un intento que no avanza ni da error. Lo cortamos y probamos de nuevo.
	if _attempt_elapsed >= ATTEMPT_TIMEOUT:
		_retry_or_give_up()


func _retry_or_give_up() -> void:
	if not _joining:
		return

	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null

	if _join_elapsed >= WAKE_TIMEOUT:
		_joining = false
		connection_failed.emit()
		return

	_join_attempt += 1
	_attempt_elapsed = 0.0
	connection_retrying.emit(_join_attempt, _join_elapsed)

	await get_tree().create_timer(RETRY_DELAY).timeout
	# Mientras esperabamos el jugador pudo volver al menu.
	if not _joining:
		return
	if _open_client() != OK:
		_joining = false
		connection_failed.emit()


## Arma la URL del servidor a partir de lo que escribio el jugador.
##
## Acepta "miservidor.com", "192.168.1.5" o una URL entera "wss://host/juego".
## Si no trae esquema, elegimos uno:
##
##   - En el NAVEGADOR va wss:// salvo que sea una direccion local. itch.io sirve la
##     pagina por HTTPS, y un navegador NO deja abrir un WebSocket inseguro desde una
##     pagina segura: lo bloquea por contenido mixto. Sin TLS en el servidor, el juego
##     web no se conecta a ningun lado.
##   - En escritorio alcanza ws://.
static func build_url(address: String, port: int) -> String:
	var addr := address.strip_edges()
	if addr.is_empty():
		addr = "127.0.0.1"
	if addr.begins_with("ws://") or addr.begins_with("wss://"):
		return addr

	var is_local := (addr == "localhost"
		or addr.begins_with("127.")
		or addr.begins_with("192.168.")
		or addr.begins_with("10."))
	var scheme := "wss://" if (OS.has_feature("web") and not is_local) else "ws://"
	return "%s%s:%d" % [scheme, addr, port]


func leave_game() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_peer = null
	players.clear()
	_ready_peers.clear()
	_joining = false
	in_match = false
	solo_mode = false
	dedicated = false
	player_list_changed.emit()


func is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


## Hay una conexion de red viva? Sin esto, cualquier .rpc() tira error en modo solo.
func _has_peer() -> bool:
	return multiplayer.multiplayer_peer != null


# ------------------------------------------------------- Peers listos para recibir

func mark_peer_ready(id: int) -> void:
	_ready_peers[id] = true


func mark_peer_unready(id: int) -> void:
	_ready_peers.erase(id)


func is_peer_ready(id: int) -> bool:
	return _ready_peers.has(id)


## Peers remotos que ya pueden recibir RPCs de nodos de partida.
func get_ready_peers() -> Array[int]:
	var out: Array[int] = []
	for id: int in _ready_peers.keys():
		out.append(id)
	return out


## Manda un RPC solo a los peers listos. Reemplaza a node.rpc() para todo lo que
## dependa de que el receptor ya tenga el nodo creado.
func rpc_ready(node: Node, method: StringName, args: Array = []) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	for id: int in _ready_peers.keys():
		node.rpc_id.callv([id, method] + args)


## Igual que rpc_ready pero a un solo peer, si esta listo.
func rpc_ready_id(node: Node, id: int, method: StringName, args: Array = []) -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if not is_peer_ready(id):
		return
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	node.rpc_id.callv([id, method] + args)


func local_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()


func is_connected_to_game() -> bool:
	return multiplayer.multiplayer_peer != null


# ------------------------------------------------------------- Lista de jugadores

func get_player_info(id: int) -> Dictionary:
	if players.has(id):
		return players[id]
	return _make_entry("???", "noelle")


func get_player_name(id: int) -> String:
	return String(get_player_info(id).get("name", "???"))


## EL MAPA DE LA PARTIDA (ver Mapas). Lo elige el host —o la sala offline, o la historia—
## y el servidor se lo manda a cada cliente: todos tienen que armar la MISMA arena, que es
## la que el servidor simula. Viaja tambien con el aviso de que arranco la partida.
func elegir_mapa(id: StringName) -> void:
	if not Mapas.existe(id):
		return
	Mapas.elegido = id
	if is_server() and _has_peer():
		_net_mapa.rpc(String(id))
	mapa_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _net_mapa(id: String) -> void:
	if Mapas.existe(StringName(id)):
		Mapas.elegido = StringName(id)
	mapa_cambiado.emit()


func set_local_character(id: String) -> void:
	local_character_id = id
	if is_server():
		if players.has(local_id()):
			players[local_id()]["character_id"] = id
			players[local_id()]["skin_id"] = String(Progreso.skin_de(StringName(id)))
			_broadcast_players()
			player_list_changed.emit()
	else:
		_srv_set_character.rpc_id(1, id)
		# Y LA SKIN DE ESE PERSONAJE, atras: el servidor no sabe que tiene puesta cada uno
		# (vive en el disco de cada maquina). Sin esto, al cambiar de personaje en la sala
		# se veia la de fabrica.
		_srv_set_skin.rpc_id(1, String(Progreso.skin_de(StringName(id))))


## Avisa que cambio la skin equipada. Mismo camino que el personaje.
func set_local_skin(skin_id: StringName) -> void:
	if is_server():
		if players.has(local_id()):
			players[local_id()]["skin_id"] = String(skin_id)
			_broadcast_players()
			player_list_changed.emit()
	else:
		_srv_set_skin.rpc_id(1, String(skin_id))


@rpc("any_peer", "call_remote", "reliable")
func _srv_set_skin(skin_id: String) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if not players.has(sender):
		return
	# SE VALIDA CONTRA EL CATALOGO, no contra lo que el cliente diga tener.
	#
	# El servidor no puede saber que desbloqueo cada uno —eso vive en el disco de cada
	# maquina— asi que no hay nada que verificar ahi. Lo que si se puede, y hace falta,
	# es que el id EXISTA: sin esto un cliente modificado manda cualquier cosa y el
	# resto del juego tiene que aguantar un id inventado en cada lugar que lo lea.
	if not skin_id.is_empty() and not SkinDB.existe(StringName(skin_id)):
		return
	# Y QUE SEA DEL PERSONAJE QUE TIENE ELEGIDO: una skin de Goku puesta sobre Noelle no se
	# dibuja (SkinDB.aplicar la ignora), pero ensuciaria la tabla de todos.
	var skin := SkinDB.get_skin(StringName(skin_id))
	if skin != null and String(skin.character_id) != String(players[sender].get("character_id", "")):
		return
	players[sender]["skin_id"] = skin_id
	_broadcast_players()
	player_list_changed.emit()


## SOLO SERVIDOR. Cambia el modo en linea y se lo avisa a todos (como el mapa).
func elegir_modo_online(id: StringName) -> void:
	if not MODOS_ONLINE.has(id):
		return
	modo_online = id
	if is_server() and _has_peer():
		_net_modo.rpc(String(id))
	modo_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _net_modo(id: String) -> void:
	if MODOS_ONLINE.has(StringName(id)):
		modo_online = StringName(id)
	modo_cambiado.emit()


## El que sigue en la rotacion del servidor publico.
static func siguiente_modo(desde: StringName, paso: int = 1) -> StringName:
	var i := MODOS_ONLINE.find(desde)
	if i < 0:
		return MODOS_ONLINE[0]
	return MODOS_ONLINE[(i + paso + MODOS_ONLINE.size()) % MODOS_ONLINE.size()]


func es_equipos() -> bool:
	return modo_online == MODO_EQUIPOS


func meta_online() -> int:
	return int(META_ONLINE.get(modo_online, GameConfig.SCORE_TO_WIN))


func equipo_de(id: int) -> int:
	return int(get_player_info(id).get("equipo", -1)) if players.has(id) else -1


## Las bajas de un equipo: las de todos sus jugadores.
func puntos_equipo(e: int) -> int:
	var total := 0
	for id: int in players.keys():
		if int(players[id].get("equipo", -1)) == e:
			total += int(players[id].get("kills", 0))
	return total


## EL GANADOR DE UN EQUIPO VIAJA COMO UN NUMERO NEGATIVO: -1 el rojo, -2 el azul. Asi el
## aviso de fin de partida sigue siendo el mismo para todos los modos.
static func id_de_equipo(e: int) -> int:
	return -1 - e


static func equipo_del_ganador(winner_id: int) -> int:
	return -1 - winner_id if winner_id < 0 else -1


func _equipo_mas_chico(salvo: int) -> int:
	var cuantos := [0, 0]
	for id: int in players.keys():
		var e := int(players[id].get("equipo", -1))
		if id != salvo and e >= 0 and e <= 1:
			cuantos[e] += 1
	return 0 if cuantos[0] <= cuantos[1] else 1


## SOLO SERVIDOR. La colina en linea suma puntos (los cuenta la arena) y gana el que llega.
func sumar_punto_colina(id: int) -> void:
	if not is_server() or not players.has(id) or not in_match:
		return
	players[id]["puntos"] = int(players[id].get("puntos", 0)) + 1
	_broadcast_players()
	player_list_changed.emit()
	if int(players[id]["puntos"]) >= meta_online():
		end_match(id)


static func nombre_modo_online(id: StringName) -> String:
	match id:
		MODO_EQUIPOS: return "Por equipos"
		MODO_COLINA: return "Rey de la colina"
		MODO_CAOS: return "Modo caos"
		MODO_TOQUE: return "Un toque"
	return "Todos contra todos"


static func descripcion_modo_online(id: StringName) -> String:
	match id:
		MODO_EQUIPOS:
			return "Rojo contra azul, sin fuego amigo. El primer equipo en llegar a %d bajas gana." % int(META_ONLINE[MODO_EQUIPOS])
		MODO_COLINA:
			return "El que está solo adentro del círculo del centro suma un punto por segundo. Primero a %d." % int(META_ONLINE[MODO_COLINA])
		MODO_CAOS:
			return "Recargas cortísimas, sin stamina y el ultimate en un rato. Primero a %d bajas." % int(META_ONLINE[MODO_CAOS])
		MODO_TOQUE:
			return "Cualquier golpe mata. Primero a %d bajas." % int(META_ONLINE[MODO_TOQUE])
	return "Cada uno por su lado. Primero a %d bajas." % int(META_ONLINE[MODO_TODOS])


## La linea de arriba en una partida en linea: como va, segun el modo.
func marcador_online() -> String:
	if not in_match:
		return ""
	var yo := get_player_info(local_id())
	var meta := meta_online()
	match modo_online:
		MODO_EQUIPOS:
			var mio := int(yo.get("equipo", -1))
			var texto := "ROJO %d  —  AZUL %d    (a %d)" % [puntos_equipo(0), puntos_equipo(1), meta]
			if mio >= 0 and players.has(local_id()):
				texto += "    SOS DEL %s" % EQUIPO_NOMBRES[mio]
			return texto
		MODO_COLINA:
			var lider := -1
			var lider_puntos := -1
			for id: int in players.keys():
				var p := int(players[id].get("puntos", 0))
				if p > lider_puntos:
					lider = id
					lider_puntos = p
			var texto := "COLINA    VOS %d / %d" % [int(yo.get("puntos", 0)), meta]
			if lider >= 0 and lider != local_id() and lider_puntos > 0:
				texto += "    PUNTERO: %s %d" % [get_player_name(lider), lider_puntos]
			return texto
	return "%s    VOS %d / %d BAJAS" % [nombre_modo_online(modo_online).to_upper(), int(yo.get("kills", 0)), meta]


func get_skin_id(id: int) -> StringName:
	return StringName(get_player_info(id).get("skin_id", ""))


## SOLO SERVIDOR. Suma una kill y evalua si termino la partida.
func add_kill(killer_id: int, victim_id: int) -> void:
	if not is_server():
		return
	if players.has(victim_id):
		players[victim_id]["deaths"] = int(players[victim_id].get("deaths", 0)) + 1
	# Suicidio o muerte sin asesino claro: no suma punto.
	if killer_id != 0 and killer_id != victim_id and players.has(killer_id):
		players[killer_id]["kills"] = int(players[killer_id].get("kills", 0)) + 1

	_broadcast_players()
	player_list_changed.emit()
	if _has_peer():
		_net_kill.rpc(killer_id, victim_id)
	kill_registered.emit(killer_id, victim_id)

	# GANAR DEPENDE DEL MODO: bajas propias, bajas del equipo, o (en la colina) los puntos,
	# que cuenta la arena y no las bajas.
	if killer_id != 0 and players.has(killer_id):
		if es_equipos():
			var e := equipo_de(killer_id)
			if e >= 0 and puntos_equipo(e) >= meta_online():
				end_match(id_de_equipo(e))
		elif modo_online != MODO_COLINA:
			if int(players[killer_id].get("kills", 0)) >= meta_online():
				end_match(killer_id)


## SOLO SERVIDOR.
func start_match() -> void:
	if not is_server():
		return
	for id: int in players.keys():
		players[id]["kills"] = 0
		players[id]["deaths"] = 0
		players[id]["puntos"] = 0
		players[id]["equipo"] = -1
	# Los equipos se arman al empezar, parejos: de a uno a cada lado, en el orden en que
	# entraron (el host primero).
	if es_equipos():
		var ids := players.keys()
		ids.sort()
		for k: int in range(ids.size()):
			players[ids[k]]["equipo"] = k % 2
	_broadcast_players()
	in_match = true
	if _has_peer():
		_net_start_match.rpc(String(Mapas.elegido))
	match_started.emit()


## SOLO SERVIDOR.
func end_match(winner_id: int) -> void:
	if not is_server() or not in_match:
		return
	in_match = false
	if _has_peer():
		_net_end_match.rpc(winner_id)
	match_ended.emit(winner_id)


# ------------------------------------------------------------------ Callbacks

func _on_peer_connected(id: int) -> void:
	# El servidor espera a que el cliente se presente con _srv_register.
	if is_server():
		print("[Net] Peer conectado: ", id)


func _on_peer_disconnected(id: int) -> void:
	if is_server():
		players.erase(id)
		mark_peer_unready(id)
		_broadcast_players()
		player_list_changed.emit()


func _on_connected_to_server() -> void:
	_joining = false
	# Ya estamos adentro: nos presentamos al servidor.
	_srv_register.rpc_id(1, local_name, local_character_id)
	# LA SKIN, ENSEGUIDA DESPUES (2026-10-10, "haz que las skins se vean en el online"). El
	# servidor arma la entrada del que llega con SU guardado, y el servidor dedicado no tiene
	# ninguna: todos se veian con la de fabrica. Va en otro mensaje, y no como un parametro
	# mas de _srv_register, para que un cliente nuevo siga entrando a un servidor viejo. Los
	# dos van por el mismo canal confiable, asi que llega antes de que se cree su jugador.
	_srv_set_skin.rpc_id(1, String(Progreso.skin_de(StringName(local_character_id))))


func _on_connection_failed() -> void:
	if _joining:
		_retry_or_give_up()
		return
	multiplayer.multiplayer_peer = null
	_peer = null
	connection_failed.emit()


func _on_server_disconnected() -> void:
	# Un servidor despertando puede cortar el handshake a medias. Si todavia estabamos
	# entrando, eso es un intento fallido, no una desconexion en partida.
	if _joining:
		_retry_or_give_up()
		return
	multiplayer.multiplayer_peer = null
	_peer = null
	players.clear()
	in_match = false
	server_disconnected.emit()


# ----------------------------------------------------------------------- RPCs

@rpc("any_peer", "call_remote", "reliable")
func _srv_register(player_name: String, character_id: String) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return
	var safe_char := character_id if CharacterDB.has_character(StringName(character_id)) else "noelle"
	players[sender] = _make_entry(_clean_name(player_name), safe_char)
	# La skin de la entrada sale del guardado de ESTE proceso, que no es el del que llega:
	# arranca en la de fabrica y la manda el cliente con _srv_set_skin.
	players[sender]["skin_id"] = ""
	# El que llega a una partida por equipos va al equipo mas chico.
	if es_equipos():
		players[sender]["equipo"] = _equipo_mas_chico(sender)

	# OJO EL ORDEN: hay que mirar in_match ANTES de emitir.
	#
	# En el servidor dedicado, player_list_changed dispara start_match(), que ya le
	# avisa a TODOS (incluido este peer). Si despues preguntabamos "in_match?" ya era
	# true y le mandabamos el aviso una segunda vez: el cliente creaba la arena dos
	# veces, la segunda chocaba de nombre con la primera, Godot la renombraba a algo
	# como @Node3D@225 y a partir de ahi ninguna ruta de RPC coincidia.
	var was_in_match := in_match

	_broadcast_players()
	# El mapa elegido, para que su sala lo muestre (y su arena sea la del servidor). Y el
	# modo, antes de que se arme su partida: las reglas tienen que estar puestas al spawnear.
	_net_mapa.rpc_id(sender, String(Mapas.elegido))
	_net_modo.rpc_id(sender, String(modo_online))
	player_list_changed.emit()

	# Solo si la partida YA estaba en curso antes de que entrara.
	if was_in_match:
		_net_start_match.rpc_id(sender, String(Mapas.elegido))


@rpc("any_peer", "call_remote", "reliable")
func _srv_set_character(character_id: String) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or not players.has(sender):
		return
	if not CharacterDB.has_character(StringName(character_id)):
		return
	players[sender]["character_id"] = character_id
	# La skin era del personaje anterior. La nueva la manda el cliente atras de esto.
	players[sender]["skin_id"] = ""
	_broadcast_players()
	player_list_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_players(data: Dictionary) -> void:
	players = data
	player_list_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_start_match(mapa: String) -> void:
	# Idempotente: dos avisos seguidos no tienen que rearmar la partida.
	if in_match:
		return
	if Mapas.existe(StringName(mapa)):
		Mapas.elegido = StringName(mapa)
	in_match = true
	match_started.emit()


@rpc("authority", "call_remote", "reliable")
func _net_end_match(winner_id: int) -> void:
	in_match = false
	match_ended.emit(winner_id)


@rpc("authority", "call_remote", "reliable")
func _net_kill(killer_id: int, victim_id: int) -> void:
	kill_registered.emit(killer_id, victim_id)


# ----------------------------------------------------------------------- Interno

func _broadcast_players() -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.is_server():
		_net_players.rpc(players)


func _make_entry(player_name: String, character_id: String) -> Dictionary:
	return {
		"name": player_name,
		"character_id": character_id,
		# LA SKIN VIAJA CON EL JUGADOR, no se lee del disco.
		#
		# Es lo unico que puede funcionar: el progreso esta guardado en la maquina de cada
		# uno, asi que si el que dibuja mirara SU archivo, todos verian a todos con la
		# skin que ellos mismos tienen equipada. Va en la entrada del jugador, igual que
		# el personaje, y se replica por el mismo camino.
		"skin_id": Progreso.skin_de(StringName(character_id)),
		"kills": 0,
		"deaths": 0,
		# Por equipos: 0 rojo, 1 azul (-1 en los demas modos). En la colina, los puntos.
		"equipo": -1,
		"puntos": 0,
	}


func _clean_name(raw: String) -> String:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return "Jugador"
	return trimmed.substr(0, 16)
