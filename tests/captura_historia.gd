extends Node
## Capturas del modo historia: la lista de capitulos, el cuadro de dialogo con su retrato y
## una pelea contra los ecos. Para mirar que se lea y que nada tape nada.
##
##   godot --path . --resolution 1280x720 res://tests/captura_historia.tscn -- <carpeta>
##
## No guarda nada: el progreso del jugador queda como estaba.

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


func _dialogo() -> DialogoHistoria:
	for hijo: Node in main.get_children():
		if hijo is DialogoHistoria:
			return hijo
	return null


func _correr() -> void:
	await _esperar(1.0)
	await _foto("h0_menu")
	main.show_historia()
	await _esperar(0.5)
	await _foto("h1_capitulos")
	for hijo: Node in main.get_children():
		if hijo is HistoriaMenu:
			hijo.queue_free()
	main._empezar_capitulo(0)
	await _esperar(1.2)
	await _foto("h2_narrador")
	var d := _dialogo()
	d.avanzar()
	d.avanzar()
	await _esperar(1.5)
	await _foto("h3_noelle_habla")
	d._terminar()
	await _esperar(2.5)
	# Los ecos al frente de la camara, para verlos en la foto.
	var arena := main.get_node_or_null("Arena") as Arena
	var jugador := arena.get_local_player()
	var frente := -jugador.global_transform.basis.z
	var i := 0
	for hijo: Node in arena.get_children():
		var p := hijo as Player
		if p != null and p.is_dummy:
			p.global_position = jugador.global_position + frente * (6.0 + i) \
				+ Vector3(-frente.z, 0.0, frente.x) * (float(i) - 1.0) * 2.2
			i += 1
	Arena.set_bots_active(false)
	await _esperar(0.8)
	await _foto("h4_pelea_ecos")
	get_tree().quit()
