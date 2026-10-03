extends Node
## Fotos de la escena de una definitiva (EscenaUlti), plano por plano, sin correr todo el
## chequeo visual.
##
##   godot --path . --resolution 1280x720 res://tests/captura_ulti.tscn -- <carpeta> [saitama|sukuna ...]

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TOMAS: Dictionary = {
	&"saitama": [[0.30, "cara"], [0.95, "hombro"], [1.48, "onda"], [2.2, "despues"]],
	&"sukuna": [[0.30, "manos"], [1.20, "templo"], [2.2, "dominio"], [3.4, "fin"]],
}

var _main: Node = null


func _ready() -> void:
	Arena.set_bots_active(false)
	Settings.mostrar_hitboxes = false
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_correr.call_deferred()


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	var salida := String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(salida)
	var ids: Array[StringName] = []
	for k: int in range(1, args.size()):
		ids.append(StringName(args[k]))
	if ids.is_empty():
		ids = [&"saitama", &"sukuna"]
	await get_tree().create_timer(0.5).timeout
	Net.start_solo("Tester")
	Net.start_match()
	await get_tree().create_timer(1.5).timeout
	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if player == null:
		print("[ulti] no hay jugador")
		get_tree().quit()
		return
	for id: StringName in ids:
		player.setup_character(CharacterDB.get_character(id))
		player.respawn_at(arena.find_clear_spot(Vector3(-8.0, 0.6, -16.0), 1.5), 0.0)
		player.health.set_max(3000.0)
		await get_tree().create_timer(1.0).timeout
		player.stamina.restore_full()
		player.ultimate.current = UltimateCharge.MAX_CHARGE
		player.caster.reset_state()
		player.caster.request_use(3)
		var pasado := 0.0
		for toma: Array in TOMAS.get(id, []):
			await get_tree().create_timer(float(toma[0]) - pasado).timeout
			pasado = float(toma[0])
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(salida.path_join("%s_%s.png" % [id, toma[1]]))
			print("[ulti] ", id, " ", toma[1])
		await get_tree().create_timer(2.0).timeout
	get_tree().quit()
