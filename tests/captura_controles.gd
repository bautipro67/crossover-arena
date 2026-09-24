extends Node
## Capturas de los controles del dedo y del mando: lo que ningun arnes sin pantalla puede
## decir, que los botones se vean, que no tapen el HUD y que el foco del mando se note.
##
## Correlo con ventana, igual que visual_check:
##   godot --path . --resolution 1280x720 res://tests/captura_controles.tscn -- C:uta

var main: Node
var _salida: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_salida)
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


func _joy(boton: int) -> void:
	for apretado: bool in [true, false]:
		var j := InputEventJoypadButton.new()
		j.button_index = boton
		j.pressed = apretado
		Input.parse_input_event(j)
		await get_tree().process_frame


func _correr() -> void:
	await _esperar(1.0)
	# --- Menu principal con el mando ---
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _esperar(0.3)
	await _foto("m1_menu_con_mando")

	# --- Partida con el dedo ---
	Arena.set_bots_active(false)
	Controles.usar(&"tactil")
	Net.start_solo("Tester")
	Net.start_match()
	await _esperar(2.5)
	await _foto("t1_partida_tactil")

	var t: ControlesTactiles = main._tactil
	var tam := get_viewport().get_visible_rect().size
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(230, tam.y - 230)
	e.pressed = true
	t.procesar(e)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = e.position + Vector2(55, -40)
	d.relative = Vector2(55, -40)
	t.procesar(d)
	var g := InputEventScreenTouch.new()
	g.index = 1
	g.position = t.centro(t.indice_de(&"ability_1"))
	g.pressed = true
	t.procesar(g)
	await _esperar(0.35)
	await _foto("t2_dos_dedos")
	g.pressed = false
	t.procesar(g)
	e.pressed = false
	t.procesar(e)

	# --- Pausa con el mando ---
	Controles.usar(&"mando")
	await _joy(JOY_BUTTON_START)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _esperar(0.3)
	await _foto("m2_pausa_con_mando")
	await _joy(JOY_BUTTON_B)
	await _esperar(0.5)
	await _foto("m3_partida_con_mando")
	get_tree().quit()
