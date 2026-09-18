extends Node
## Test del SERVIDOR DEDICADO: el que vas a correr en el VPS.
##
## A diferencia de net_test (que prueba un listen server, donde el host tambien juega),
## este prueba el modo que usa la version online: un proceso que no juega, no dibuja
## nada y solo acepta conexiones.
##
## Correlo con DOS procesos:
##   godot --headless --path . -- --server 27098          <- el juego de verdad, modo servidor
##   godot --headless --path . res://tests/server_test.tscn -- 27098
##
## Verifica lo que romperia la version online:
##   - que el servidor NO se spawnee a si mismo (si no, hay un jugador fantasma)
##   - que arranque la partida solo cuando entra alguien
##   - que el cliente pueda jugar de verdad contra el

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TIMEOUT: float = 90.0
## Puerto donde no escucha nadie, para probar el arranque en frio.
const DEAD_PORT: int = 27011

var _port: int = 27098
var _main: Node = null
var _failures: Array[String] = []
var _checks: int = 0
var _elapsed: float = 0.0
var _finished: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]).is_valid_int():
		_port = String(args[0]).to_int()
	print("[cliente] conectando al servidor dedicado en el puerto %d" % _port)

	# OJO: Main va colgado de /root, NO de este nodo.
	#
	# Godot direcciona los RPC por RUTA DE NODO. El servidor corre main.tscn, asi que
	# alla el arbol es /root/Main/Arena. Si aca lo colgaramos del test quedaria en
	# /root/ServerTest/Main/Arena, las rutas no coincidirian, los paquetes no se podrian
	# rutear y Godot terminaria desconectando al peer por paquete invalido.
	_main = MAIN_SCENE.instantiate()
	_main.name = "Main"
	get_tree().root.call_deferred("add_child", _main)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _finished:
		_check(false, "el test termino antes del timeout de %.0fs" % TIMEOUT)
		_finish()


func _run() -> void:
	# Le damos al servidor tiempo de levantarse y a Main de entrar al arbol.
	await _wait(2.0)

	var err := Net.join_game("127.0.0.1", _port, "Cliente")
	_check(err == OK, "el cliente inicio la conexion al servidor dedicado")
	if err != OK:
		_finish()
		return

	# El servidor arranca la partida SOLO, sin que nadie toque un boton.
	var waited := 0.0
	while not Net.in_match and waited < 12.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(Net.is_connected_to_game(), "el cliente quedo conectado")
	_check(Net.in_match, "el servidor arranco la partida solo (%.1fs)" % waited)

	var arena := await _wait_for_arena(10.0)
	_check(arena != null, "la arena se creo en el cliente")
	if arena == null:
		_finish()
		return

	var player := await _wait_for_local_player(arena, 10.0)
	_check(player != null, "el cliente tiene su jugador en la arena")
	if player == null:
		_finish()
		return

	_check(player.caster.abilities.size() == 3, "el cliente tiene su kit cargado")
	_check(player.peer_id == Net.local_id(), "el peer id del jugador es el del cliente")

	# EL CHEQUEO CLAVE: el servidor dedicado NO juega. Si se spawneara a si mismo,
	# habria un jugador fantasma parado en el mapa que nadie controla.
	var total := _count_players(arena)
	_check(total == 1, "el servidor NO se spawneo a si mismo (hay %d jugador/es)" % total)
	_check(not Net.players.has(1), "el servidor no figura en la lista de jugadores")

	# Y que se pueda jugar de verdad contra el: pedirle una habilidad y que responda.
	player.stamina.restore_full()
	player.caster.reset_state()
	var before := player.stamina.current
	player.caster.request_use(1)  # Ice Shock, 28 de stamina
	await _wait(1.0)
	_check(player.stamina.current < before,
		"el servidor autorizo la habilidad y cobro la stamina (%.0f -> %.0f)" % [before, player.stamina.current])

	await _test_servidor_dormido()
	_finish()


## Lo que pasa SIEMPRE en un hosting gratuito: la instancia esta apagada y el primer
## intento de conexion falla. Lo simulamos apuntando a un puerto donde no hay nada.
##
## El cliente tiene que insistir y avisar que espera. Si se rinde al primer fallo, el
## jugador ve "no se pudo conectar" en un servidor que estaba por prenderse y se va.
func _test_servidor_dormido() -> void:
	Net.leave_game()
	await _wait(0.5)

	# Diccionarios y no bools sueltos: los lambdas de GDScript copian las locales, asi
	# que un bool capturado nunca se entera de nada y el chequeo pasa siempre.
	var retries := {"count": 0}
	var gave_up := {"yes": false}
	var on_retry := func(attempt: int, _elapsed: float) -> void: retries["count"] = attempt
	var on_fail := func() -> void: gave_up["yes"] = true
	Net.connection_retrying.connect(on_retry)
	Net.connection_failed.connect(on_fail)

	var err := Net.join_game("127.0.0.1", DEAD_PORT, "Insistente")
	_check(err == OK, "el cliente acepta apuntar a un servidor dormido")
	_check(Net.is_joining(), "queda esperando en vez de fallar al instante")

	var waited := 0.0
	while retries["count"] < 2 and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(retries["count"] >= 2,
		"reintenta solo (%d intentos en %.0fs)" % [retries["count"], waited])
	_check(not gave_up["yes"],
		"no se rindio antes de los %.0fs de espera" % Net.WAKE_TIMEOUT)

	Net.leave_game()
	_check(not Net.is_joining(), "volver al menu corta los reintentos")

	Net.connection_retrying.disconnect(on_retry)
	Net.connection_failed.disconnect(on_fail)


# ------------------------------------------------------------------- Helpers

func _wait_for_arena(timeout: float) -> Arena:
	var waited := 0.0
	while waited < timeout:
		var arena := _main.get_node_or_null("Arena") as Arena
		if arena != null:
			return arena
		await get_tree().process_frame
		waited += get_process_delta_time()
	return null


func _wait_for_local_player(arena: Arena, timeout: float) -> Player:
	var waited := 0.0
	while waited < timeout:
		var player := arena.get_local_player()
		if player != null:
			return player
		await get_tree().process_frame
		waited += get_process_delta_time()
	return null


func _count_players(arena: Arena) -> int:
	var n := 0
	for child: Node in arena.get_children():
		if child is Player:
			n += 1
	return n


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  OK   ", description)
	else:
		print("  FALLA ", description)
		_failures.append(description)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("")
	if _failures.is_empty():
		print("RESULTADO[servidor dedicado]: TODO OK — %d verificaciones" % _checks)
	else:
		print("RESULTADO[servidor dedicado]: FALLARON %d de %d" % [_failures.size(), _checks])
		for f: String in _failures:
			print("   - ", f)
	Music.stop(true)
	Sfx.stop_all()
	Net.leave_game()
	if is_instance_valid(_main):
		_main.queue_free()
	for _i: int in range(4):
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
