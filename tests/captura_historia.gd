extends Node
## Capturas de las escenas del modo historia: para mirar los planos, las poses y que el
## texto se lea. Ningun arnes sin pantalla dice si una camara quedo tapada por una pared.
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
	for i: int in range(Historia.cantidad()):
		Progreso.historia[str(i)] = true
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


func _cine() -> Cinematica:
	var m := Modos.mision as Node
	if m == null:
		return null
	for hijo: Node in m.get_children():
		if hijo is Cinematica:
			return hijo
	return null


## Avanza la escena linea por linea, sacando foto de las que se piden.
func _recorrer(prefijo: String, fotos: Array, tope: int) -> void:
	for n: int in range(tope):
		await _esperar(1.1)
		var c := _cine()
		if c == null:
			return
		if fotos.has(n):
			await _foto("%s_%02d" % [prefijo, n])
		c._avanzar()
		c._avanzar()


func _correr() -> void:
	await _esperar(1.0)
	main.jugar_capitulo(0)
	await _esperar(1.6)
	await _foto("c1_titulo")
	await _recorrer("c1", [0, 1, 2, 3, 5], 8)
	await _esperar(2.0)
	await _foto("c1_pelea")
	Net.leave_game()
	main.show_main_menu()
	await _esperar(0.8)

	main.jugar_capitulo(6)
	await _esperar(2.8)
	await _recorrer("c7", [0, 2, 5, 7, 9], 11)
	Net.leave_game()
	main.show_main_menu()
	await _esperar(0.8)

	main.jugar_capitulo(9)
	await _esperar(1.5)
	var c := _cine()
	if c != null:
		c.saltear()
	await _esperar(1.5)
	var m := Modos.mision as MisionHistoria
	if m != null:
		m._ganar()
	await _recorrer("c10fin", [0, 3, 5, 6, 7, 9], 12)
	get_tree().quit()
