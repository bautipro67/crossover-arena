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
	players[sender]["skin_id"] = skin_id
	_broadcast_players()
	player_list_changed.emit()


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

	if killer_id != 0 and players.has(killer_id):
		if int(players[killer_id].get("kills", 0)) >= GameConfig.SCORE_TO_WIN:
			end_match(killer_id)


## SOLO SERVIDOR.
func start_match() -> void:
	if not is_server():
		return
	for id: int in players.keys():
		players[id]["kills"] = 0
		players[id]["deaths"] = 0
	_broadcast_players()
	in_match = true
	if _has_peer():
		_net_start_match.rpc()
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

	# OJO EL ORDEN: hay que mirar in_match ANTES de emitir.
	#
	# En el servidor dedicado, player_list_changed dispara start_match(), que ya le
	# avisa a TODOS (incluido este peer). Si despues preguntabamos "in_match?" ya era
	# true y le mandabamos el aviso una segunda vez: el cliente creaba la arena dos
	# veces, la segunda chocaba de nombre con la primera, Godot la renombraba a algo
	# como @Node3D@225 y a partir de ahi ninguna ruta de RPC coincidia.
	var was_in_match := in_match

	_broadcast_players()
	player_list_changed.emit()

	# Solo si la partida YA estaba en curso antes de que entrara.
	if was_in_match:
		_net_start_match.rpc_id(sender)


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
	_broadcast_players()
	player_list_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_players(data: Dictionary) -> void:
	players = data
	player_list_changed.emit()


@rpc("authority", "call_remote", "reliable")
func _net_start_match() -> void:
	# Idempotente: dos avisos seguidos no tienen que rearmar la partida.
	if in_match:
		return
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
	}


func _clean_name(raw: String) -> String:
	var trimmed := raw.strip_edges()
	if trimmed.is_empty():
		return "Jugador"
	return trimmed.substr(0, 16)
