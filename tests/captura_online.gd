extends Node
## Capturas de LOS MODOS EN LINEA y de LA VIDA DE LOS COMPAÑEROS: la sala hosteando con el
## selector de modo, la colina en linea, y un capitulo con aliados (con teclado y con el
## dedo) para ver que la placa de las barras ya no les tapa la vida. No afirma nada.
##
##   godot --path . res://tests/captura_online.tscn -- <carpeta>

var main: Node
var _salida: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_salida)
	Progreso.guardado_activo = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_correr.call_deferred()


func _foto(nombre: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(_salida.path_join(nombre + ".png"))
	print("[captura] ", nombre)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _correr() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Controles.set_process_input(false)
	Controles.usar(&"teclado")
	await _esperar(1.0)

	# --- La sala hosteando, con el modo ---
	Modos.iniciar(Modos.ONLINE)
	Net.host_game(27111, "Host")
	Net.elegir_modo_online(Net.MODO_EQUIPOS)
	main.show_lobby()
	await _esperar(0.8)
	await _foto("o1_sala_modo")

	# --- La colina en linea, sola ---
	Net.elegir_modo_online(Net.MODO_COLINA)
	Net.start_match()
	await _esperar(2.5)
	var arena := main.get_node_or_null("Arena") as Arena
	var yo: Player = arena.get_local_player() if arena != null else null
	if yo != null:
		yo.global_position = Vector3(2.0, 0.6, 6.0)
		yo.camera_pivot.set_yaw(0.0)
	await _esperar(2.5)
	await _foto("o2_colina")
	Net.leave_game()
	main.show_main_menu()
	await _esperar(0.5)

	# --- Un capitulo con aliados: la vida de los compañeros ---
	Progreso.modo_dev = true
	Cinematica.automatica = true
	main.jugar_capitulo(101)
	var espera := 0.0
	while espera < 40.0:
		await _esperar(0.25)
		espera += 0.25
		var m := Modos.mision as MisionHistoria
		if m != null and m._en_pelea and not Cinematica.activa:
			break
	var mision := Modos.mision as MisionHistoria
	if mision != null:
		for id: StringName in [&"kratos", &"saitama"]:
			mision.call("_hacer", [["entrar", id]])
	await _esperar(1.5)
	await _foto("o3_aliados_teclado")
	Controles.usar(&"tactil")
	await _esperar(0.6)
	await _foto("o4_aliados_dedo")
	get_tree().quit()
