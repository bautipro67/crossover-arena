extends Node3D
## Un personaje en varias poses, para ver que el modelo sigue a la animacion.
##
##   godot --path . --resolution 900x700 res://tests/captura_pose.tscn -- <carpeta> <id>

var _salida := ""
var _id: StringName = &"noelle"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	if args.size() > 1:
		_id = StringName(args[1])
	DirAccess.make_dir_recursive_absolute(_salida)
	Settings.mostrar_hitboxes = false
	var ent := Environment.new()
	ent.background_mode = Environment.BG_COLOR
	ent.background_color = Color(0.10, 0.12, 0.18)
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.6, 0.65, 0.78)
	ent.ambient_light_energy = 0.5
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35.0, 160.0, 0.0)
	add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.look_at_from_position(Vector3(2.2, 1.6, -4.6), Vector3(0.0, 1.05, 0.0))
	_run.call_deferred()


func _run() -> void:
	var cuerpo := Cuerpo.new()
	add_child(cuerpo)
	var visual := PlayerVisual.new()
	cuerpo.add_child(visual)
	await get_tree().process_frame
	visual.apply_character(CharacterDB.get_character(_id))
	for pose: StringName in [&"", &"channel_up", &"desafio", &"victoria", &"embiste"]:
		visual.actuar(pose)
		for _i: int in range(40):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_pose_%s.png" % [_salida, _id, pose if pose != &"" else &"quieto"])
	visual.actuar(&"")
	visual.play_attack()
	for _i: int in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_pose_pina.png" % [_salida, _id])
	get_tree().quit()


## Un cuerpo minimo: lo que PlayerVisual le pregunta al jugador.
class Cuerpo extends CharacterBody3D:
	func is_dashing() -> bool:
		return false
