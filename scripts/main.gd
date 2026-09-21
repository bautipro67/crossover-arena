class_name Main
extends Node
## Raiz del juego. Enruta entre menu principal, lobby y partida.
## Es el unico lugar que instancia y libera pantallas, asi no quedan nodos colgados.

var _screen: Control = null
var _arena: Arena = null
var _hud: HUD = null
var _pause: PauseMenu = null
var _practica: PracticePanel = null


func _ready() -> void:
	Net.connection_failed.connect(_on_connection_failed)
	Net.server_disconnected.connect(_on_server_disconnected)
	Net.match_started.connect(_on_match_started)
	Net.match_ended.connect(_on_match_ended)

	if _is_dedicated_server():
		_run_dedicated_server()
		return

	Music.play_menu()
	show_main_menu()


# ------------------------------------------------------------ Servidor dedicado

## Se enciende con:
##     CrossoverArena --headless -- --server [puerto]
##
## El servidor no dibuja nada ni juega: solo acepta conexiones, arranca la partida
## cuando entra alguien y la reinicia cuando termina.
func _is_dedicated_server() -> bool:
	# La variable PORT la define Render (y casi cualquier PaaS) sola. Si esta, esto es
	# un servidor, no un cliente: asi el mismo binario sirve para las dos cosas sin
	# tener que pasarle argumentos en el Dockerfile.
	return (OS.get_cmdline_user_args().has("--server")
		or OS.has_feature("dedicated_server")
		or not OS.get_environment("PORT").is_empty())


func _run_dedicated_server() -> void:
	var port := _server_port_from_args()
	var err := Net.host_dedicated(port)
	if err != OK:
		push_error("[servidor] no se pudo abrir el puerto %d (error %d)" % [port, err])
		get_tree().quit(1)
		return
	print("[servidor] CrossoverArena escuchando WebSocket en el puerto %d" % port)
	Net.player_list_changed.connect(_on_dedicated_players_changed)


## Prioridad: --server PUERTO > variable PORT > el puerto por defecto.
##
## PORT la asigna el hosting y NO es fija: Render te da un puerto distinto en cada
## deploy. Si lo hardcodeas, el servicio levanta pero el balanceador no encuentra nada
## escuchando y el deploy se marca como fallido.
func _server_port_from_args() -> int:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--server")
	if index >= 0 and index + 1 < args.size():
		var value := String(args[index + 1])
		if value.is_valid_int():
			return clampi(value.to_int(), 1024, 65535)

	var env_port := OS.get_environment("PORT")
	if env_port.is_valid_int():
		return clampi(env_port.to_int(), 1, 65535)

	return GameConfig.DEFAULT_PORT


## Arranca la partida sola en cuanto entra alguien, y la corta si se van todos.
func _on_dedicated_players_changed() -> void:
	if not Net.dedicated:
		return
	var count := Net.players.size()
	if count > 0 and not Net.in_match:
		print("[servidor] arrancando partida (%d jugador/es)" % count)
		Net.start_match()
	elif count == 0 and Net.in_match:
		print("[servidor] no queda nadie, cerrando la partida")
		Net.in_match = false
		_clear_match()


# -------------------------------------------------------------------- Pantallas

func show_main_menu(message: String = "") -> void:
	Music.play_menu()
	_clear_match()
	_clear_screen()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var menu := MainMenu.new()
	menu.message = message
	menu.host_requested.connect(_on_host_requested)
	menu.join_requested.connect(_on_join_requested)
	menu.modo_requested.connect(_on_modo_requested)
	menu.pase_requested.connect(show_pase)
	menu.tienda_requested.connect(show_tienda)
	menu.quit_requested.connect(_on_quit_requested)
	_screen = menu
	add_child(menu)


## El pase y la tienda van ENCIMA del menu, no en su lugar.
##
## Asi el menu no se reconstruye al volver, que ademas de ser mas rapido evita el parpadeo
## del fondo animado y que el campo del nombre se vacie si lo estabas escribiendo.
func show_pase() -> void:
	var pantalla := PaseMenu.new()
	pantalla.cerrado.connect(func() -> void:
		pantalla.queue_free()
		# El menu se rehace al volver: el boton del pase lleva un punto cuando hay algo
		# sin cobrar, y si no se rehace el punto queda puesto despues de cobrarlo todo.
		show_main_menu())
	add_child(pantalla)


func show_tienda() -> void:
	var pantalla := TiendaMenu.new()
	pantalla.cerrado.connect(func() -> void: pantalla.queue_free())
	add_child(pantalla)


func show_lobby() -> void:
	Music.play_menu()
	_clear_screen()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var lobby := Lobby.new()
	lobby.start_requested.connect(_on_start_requested)
	lobby.leave_requested.connect(_on_leave_requested)
	_screen = lobby
	add_child(lobby)


func _clear_screen() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null


func _clear_match() -> void:
	if is_instance_valid(_arena):
		_arena.queue_free()
	_arena = null
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	if is_instance_valid(_pause):
		_pause.queue_free()
	_pause = null
	if is_instance_valid(_practica):
		_practica.queue_free()
	_practica = null


# ---------------------------------------------------------------------- Menu

func _on_host_requested(player_name: String, port: int) -> void:
	Modos.iniciar(Modos.ONLINE)
	var err := Net.host_game(port, player_name)
	if err != OK:
		show_main_menu("No se pudo abrir el servidor en el puerto %d (error %d)." % [port, err])
		return
	show_lobby()


func _on_join_requested(player_name: String, ip: String, port: int) -> void:
	Modos.iniciar(Modos.ONLINE)
	var err := Net.join_game(ip, port, player_name)
	if err != OK:
		show_main_menu("No se pudo conectar a %s:%d (error %d)." % [ip, port, err])
		return
	show_lobby()


## Un modo offline: mismo flujo que hostear, pero sin abrir ningun puerto.
func _on_modo_requested(player_name: String, modo: StringName) -> void:
	# Sala nueva, ajustes nuevos. Si no, los de la practica anterior —"no puedo morir",
	# "sin cooldowns"— siguen puestos sin que nadie los haya pedido otra vez.
	Practica.restablecer()
	Modos.iniciar(modo)
	Net.start_solo(player_name)
	show_lobby()


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_start_requested() -> void:
	Net.start_match()


func _on_leave_requested() -> void:
	Net.leave_game()
	show_main_menu()


# -------------------------------------------------------------------- Partida

func _on_match_started() -> void:
	# Si ya hay una arena viva, esto es un aviso repetido: no rearmar nada. Rearmar
	# dejaba dos arenas un instante y la nueva perdia su nombre por colision.
	if is_instance_valid(_arena):
		return
	_clear_screen()
	_clear_match()

	_arena = Arena.new()
	_arena.name = "Arena"
	add_child(_arena)

	# El servidor dedicado solo necesita la arena: no dibuja HUD, no pausa, no suena.
	if Net.dedicated:
		return

	# El cronometro y el contador de oleadas arrancan de cero en cada partida, no en cada
	# vuelta al menu: si no, la segunda contrarreloj empieza con el tiempo de la primera.
	Modos.iniciar(Modos.actual)

	Music.play_combat()
	_hud = HUD.new()
	add_child(_hud)
	if not Modos.termino.is_connected(_on_modo_termino):
		Modos.termino.connect(_on_modo_termino)

	_pause = PauseMenu.new()
	_pause.resume_requested.connect(_on_resume_requested)
	_pause.leave_requested.connect(_on_leave_match_requested)
	add_child(_pause)

	# El panel de practica solo existe en la sala de practica. No es solo que este
	# oculto: en una partida con otros el nodo ni se crea.
	if Practica.disponible():
		_practica = PracticePanel.new()
		# Con nombre fijo: el chequeo visual lo busca por nombre para capturarlo, y un
		# CanvasLayer creado con new() se queda con un nombre autogenerado.
		_practica.name = "PracticePanel"
		add_child(_practica)

	_arena.local_player_spawned.connect(_hud.bind_player)
	# Si el jugador local ya existia cuando se armo el HUD, lo enganchamos igual.
	var local := _arena.get_local_player()
	if local != null:
		_hud.bind_player(local)


## Un modo offline llego a su final: se muestra el resultado y se vuelve al menu.
func _on_modo_termino(gano: bool, titulo: String, detalle: String) -> void:
	if is_instance_valid(_hud):
		_hud.show_match_result("%s
%s" % [titulo, detalle])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(5.0).timeout
	if not Net.solo_mode:
		return
	Net.leave_game()
	show_main_menu()


func _on_match_ended(winner_id: int) -> void:
	# La partida en linea tambien paga: ganar da el plus, y las bajas ya se cobraron una
	# por una mientras se jugaba.
	if not Net.dedicated:
		Progreso.registrar_partida(winner_id == Net.local_id(), Modos.da_recompensas())
	if Net.dedicated:
		print("[servidor] termino la partida, gano %s" % Net.get_player_name(winner_id))
		_restart_dedicated_match()
		return
	var winner_name := Net.get_player_name(winner_id)
	if is_instance_valid(_hud):
		_hud.show_match_result("GANO %s" % winner_name.to_upper())
	# Unos segundos para ver el resultado y despues todos vuelven a la sala de espera,
	# donde el host puede arrancar otra sin tener que reconectar a nadie.
	_return_to_lobby_after(6.0)


## El servidor levanta una partida nueva sin echar a nadie.
func _restart_dedicated_match() -> void:
	await get_tree().create_timer(6.0).timeout
	if not Net.dedicated:
		return
	_clear_match()
	if Net.players.size() > 0:
		print("[servidor] arrancando partida nueva")
		Net.start_match()


func _return_to_lobby_after(delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not Net.is_connected_to_game() and not Net.solo_mode:
		return
	if Net.in_match:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear_match()
	show_lobby()


func _on_resume_requested() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_leave_match_requested() -> void:
	Net.leave_game()
	show_main_menu()


# --------------------------------------------------------------------- Errores

func _on_connection_failed() -> void:
	show_main_menu("No se pudo conectar al servidor. Revisa la IP y el puerto.")


func _on_server_disconnected() -> void:
	show_main_menu("Se perdio la conexion con el servidor.")
