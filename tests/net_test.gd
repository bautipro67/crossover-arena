extends Node
## Test de red real: dos procesos de Godot, uno hostea y el otro se une.
##
## Verifica lo que el test de humo no puede: que el handshake funcione, que el cliente
## que entra reciba los jugadores que ya estaban, y que ambos lados terminen viendo
## la misma cantidad de jugadores en la arena.
##
## Correlo con:
##   godot --headless --path . res://tests/net_test.tscn -- host
##   godot --headless --path . res://tests/net_test.tscn -- client

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PORT: int = 27099
const TIMEOUT: float = 18.0

var _role: String = "host"
var _main: Node = null
var _failures: Array[String] = []
var _checks: int = 0
var _elapsed: float = 0.0
var _finished: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_role = String(args[0])
	print("[%s] arrancando" % _role)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT and not _finished:
		_check(false, "el test termino antes del timeout de %.0fs" % TIMEOUT)
		_finish()


func _run() -> void:
	await get_tree().process_frame
	if _role == "host":
		await _run_host()
	else:
		await _run_client()


func _run_host() -> void:
	var err := Net.host_game(PORT, "Host")
	_check(err == OK, "el servidor abrio el puerto %d" % PORT)
	if err != OK:
		_finish()
		return

	# Esperamos a que se conecte el cliente.
	var waited := 0.0
	while Net.players.size() < 2 and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(Net.players.size() == 2, "el cliente se registro en el servidor (hay %d jugadores)" % Net.players.size())
	if Net.players.size() < 2:
		_finish()
		return

	Net.start_match()
	await _wait(1.0)

	var arena := _get_arena()
	_check(arena != null, "[host] la arena existe")
	if arena != null:
		# Esperamos por la CONDICION, no por reloj. Con un sleep fijo el test es fragil:
		# el handshake de WebSocket tarda mas que el de ENet y el cliente todavia no
		# habia avisado que tenia la arena lista.
		var count := await _wait_for_players(arena, 2, 8.0)
		_check(count == 2, "[host] hay 2 jugadores en la arena (hay %d)" % count)
		var local := arena.get_local_player()
		_check(local != null, "[host] el jugador local existe")
		if local != null:
			_check(local.caster.abilities.size() == 3, "[host] el jugador local tiene su kit cargado")

	# Le damos tiempo al cliente a terminar sus chequeos antes de cortar.
	await _wait(3.0)
	_finish()


func _run_client() -> void:
	# Le damos al host tiempo de levantar el servidor.
	await _wait(1.5)
	var err := Net.join_game("127.0.0.1", PORT, "Cliente")
	_check(err == OK, "el cliente inicio la conexion")
	if err != OK:
		_finish()
		return

	# Poleamos el estado real de Net en vez de usar un flag capturado en un lambda:
	# en GDScript los lambdas copian las locales, asi que un flag local nunca se actualiza.
	var waited := 0.0
	while not Net.in_match and waited < 10.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(Net.is_connected_to_game(), "el cliente quedo conectado")
	_check(Net.in_match, "el cliente recibio el arranque de la partida")

	await _wait(1.0)

	var arena := _get_arena()
	_check(arena != null, "[cliente] la arena existe")
	if arena != null:
		var count := await _wait_for_players(arena, 2, 8.0)
		_check(count == 2, "[cliente] ve a los 2 jugadores (ve %d)" % count)
		var local := arena.get_local_player()
		_check(local != null, "[cliente] su propio jugador existe")
		if local != null:
			_check(local.peer_id == Net.local_id(), "[cliente] su jugador tiene el peer id correcto")
			_check(local.caster.abilities.size() == 3, "[cliente] tiene su kit cargado")

	_finish()


# ------------------------------------------------------------------- Helpers

func _get_arena() -> Arena:
	if not is_instance_valid(_main):
		return null
	return _main.get_node_or_null("Arena") as Arena


## Espera hasta que la arena tenga `wanted` jugadores, o hasta que se acabe el tiempo.
## Devuelve cuantos habia al final.
func _wait_for_players(arena: Arena, wanted: int, timeout: float) -> int:
	var waited := 0.0
	while waited < timeout:
		var count := _count_players(arena)
		if count >= wanted:
			return count
		await get_tree().process_frame
		waited += get_process_delta_time()
	return _count_players(arena)


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
		print("  OK   [%s] %s" % [_role, description])
	else:
		print("  FALLA [%s] %s" % [_role, description])
		_failures.append(description)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("")
	if _failures.is_empty():
		print("RESULTADO[%s]: TODO OK — %d verificaciones" % [_role, _checks])
	else:
		print("RESULTADO[%s]: FALLARON %d de %d" % [_role, _failures.size(), _checks])
		for f: String in _failures:
			print("   - ", f)
	# Cierre ordenado. Llamar a quit() con la musica sonando y tweens vivos hacia que
	# Godot avisara de instancias sin liberar al salir.
	Music.stop(true)
	Sfx.stop_all()
	Net.leave_game()
	for _i: int in range(4):
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
