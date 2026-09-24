extends Node3D
## Retrato de un personaje: de frente, de tres cuartos y de espaldas, con la ropa de
## fabrica y con cada una de sus skins.
##
## Para mirar un personaje nuevo antes de darlo por bueno. Los arneses dicen si algo
## funciona; esto dice si SE PARECE, que ningun chequeo puede decir.
##
##   godot --path . --resolution 900x900 res://tests/captura_personaje.tscn -- <carpeta> <id>

var _salida: String = ""
var _personaje: StringName = &"goku"
var _pivote: Node3D = null


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 1:
		_personaje = StringName(args[1])
	DirAccess.make_dir_recursive_absolute(_salida)

	var ent := Environment.new()
	ent.background_mode = Environment.BG_COLOR
	ent.background_color = Color(0.10, 0.12, 0.18)
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.6, 0.65, 0.78)
	ent.ambient_light_energy = 0.45
	ent.glow_enabled = true
	ent.glow_intensity = 0.25
	ent.tonemap_mode = Environment.TONE_MAPPER_ACES
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 0.9
	sol.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	add_child(sol)
	var camara := Camera3D.new()
	camara.fov = 30.0
	add_child(camara)
	var ojo := Vector3(0.0, 1.15, 5.2)
	camara.transform = Transform3D(Basis.looking_at(Vector3(0.0, 1.0, 0.0) - ojo, Vector3.UP), ojo)
	camara.current = true
	_pivote = Node3D.new()
	add_child(_pivote)
	_correr.call_deferred()


func _correr() -> void:
	var base := CharacterDB.get_character(_personaje)
	var variantes: Array[StringName] = [&""]
	variantes.append_array(SkinDB.de_personaje(_personaje))
	for sid: StringName in variantes:
		for hijo: Node in _pivote.get_children():
			hijo.queue_free()
		var visual := PlayerVisual.new()
		_pivote.add_child(visual)
		visual.apply_character(SkinDB.aplicar(base, sid))
		for vista: Array in [["frente", 180.0], ["tres_cuartos", 215.0], ["espalda", 0.0]]:
			_pivote.rotation_degrees = Vector3(0.0, vista[1], 0.0)
			for _i: int in range(8):
				await get_tree().process_frame
			var nombre := "%s_%s_%s.png" % [_personaje, sid if sid != &"" else &"fabrica", vista[0]]
			get_viewport().get_texture().get_image().save_png(_salida.path_join(nombre))
			print("[retrato] ", nombre)
	get_tree().quit()
