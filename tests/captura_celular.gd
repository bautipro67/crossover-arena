extends Node
## Capturas de LA VERSION DEL CELULAR, sacadas desde la computadora: la pantalla ancha de
## un celular (20:9), la imagen estirada, los botones del dedo, el fijado, la definitiva
## lista y las opciones nuevas. No afirma nada: es para mirar.
##
## Correlo con ventana, con el ancho de un celular y "--celular":
##   godot --path . --resolution 1600x720 res://tests/captura_celular.tscn -- <carpeta> --celular

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
	# La ventana con la forma de un celular (20:9), aunque las opciones digan pantalla
	# completa: si no, la foto sale con la forma del monitor.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1366, 614))
	Controles.usar(&"tactil")
	# Y QUE QUEDE EN TACTIL: el mouse de verdad que pasa por encima de la ventana lo
	# devolveria al teclado en medio de las fotos.
	Controles.set_process_input(false)
	await _esperar(1.2)
	await _foto("c1_menu")

	var opciones := OptionsMenu.new()
	add_child(opciones)
	await _esperar(0.4)
	await _foto("c2_opciones")
	var scroll := _buscar_scroll(opciones)
	if scroll != null:
		scroll.scroll_vertical = 100000
		await _esperar(0.3)
		await _foto("c3_opciones_abajo")
	opciones.queue_free()

	main.show_lobby()
	await _esperar(0.6)
	await _foto("c4_sala")

	# --- La partida con el dedo ---
	Arena.set_bots_active(false)
	Net.start_solo("Tester")
	Net.start_match()
	await _esperar(2.5)
	Controles.usar(&"tactil")
	await _esperar(0.2)
	await _foto("c5_partida")

	var t: ControlesTactiles = main._tactil
	var arena := main.get_node_or_null("Arena") as Arena
	var jugador: Player = arena.get_local_player() if arena != null else null
	if jugador != null:
		jugador.ultimate.current = UltimateCharge.MAX_CHARGE
		jugador.stamina.restore_full()
		jugador.camera_pivot.fijar_o_soltar()
	var tam := get_viewport().get_visible_rect().size
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(260, tam.y - 230)
	e.pressed = true
	t.procesar(e)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = e.position + Vector2(60, -45)
	d.relative = Vector2(60, -45)
	t.procesar(d)
	Controles.usar(&"tactil")
	await _esperar(0.5)
	await _foto("c6_fijado_y_definitiva")
	e.pressed = false
	t.procesar(e)

	Settings.tamano_botones = Settings.BOTONES_MAX
	await _esperar(0.3)
	await _foto("c7_botones_grandes")
	Settings.tamano_botones = Settings.BOTONES_MIN
	Settings.opacidad_botones = 0.4
	await _esperar(0.3)
	await _foto("c8_botones_chicos")
	Settings.load_settings()
	get_tree().quit()


func _buscar_scroll(n: Node) -> ScrollContainer:
	for h: Node in n.get_children():
		if h is ScrollContainer:
			return h
		var r := _buscar_scroll(h)
		if r != null:
			return r
	return null
