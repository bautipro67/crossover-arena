extends Node
## Fotos de cada mapa: desde arriba, de costado y a la altura de los ojos.
##
## Para mirar un mapa antes de darlo por bueno. Arma una practica en cada uno, sin bots
## persiguiendo, y saca las cuatro fotos.
##
##   godot --path . --resolution 1280x720 res://tests/captura_mapa.tscn -- <carpeta> [id ...]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _salida: String = ""
var _main: Node = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_salida)
	Arena.set_bots_active(false)
	Settings.mostrar_hitboxes = false
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_correr.call_deferred()


func _process(_delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array[StringName] = []
	for k: int in range(1, args.size()):
		ids.append(StringName(args[k]))
	if ids.is_empty():
		for m: Dictionary in Mapas.LISTA:
			ids.append(m["id"])
	await get_tree().create_timer(0.5).timeout
	for id: StringName in ids:
		Mapas.elegido = id
		Net.start_solo("Tester")
		Net.start_match()
		await get_tree().create_timer(1.5).timeout
		var arena := _main.get_node_or_null("Arena") as Arena
		if arena == null:
			print("[mapa] no se armo la arena de ", id)
			continue
		var cam := Camera3D.new()
		cam.fov = 62.0
		arena.add_child(cam)
		for vista: Array in [
				["arriba", Vector3(0.0, 62.0, 86.0), Vector3(0.0, 2.0, 0.0)],
				["costado", Vector3(48.0, 22.0, 48.0), Vector3(0.0, 3.0, 0.0)],
				["ojos", Vector3(-6.0, 2.2, 44.0), Vector3(0.0, 3.0, 0.0)],
				["ojos2", Vector3(40.0, 2.4, -6.0), Vector3(-40.0, 3.0, 20.0)]]:
			cam.global_position = vista[1]
			cam.look_at(vista[2], Vector3.UP)
			cam.make_current()
			await get_tree().create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(_salida.path_join("%s_%s.png" % [id, vista[0]]))
			print("[mapa] ", id, " ", vista[0])
		Net.leave_game()
		_main.show_main_menu()
		await get_tree().create_timer(0.6).timeout
	get_tree().quit()
