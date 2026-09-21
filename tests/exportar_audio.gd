extends Node
## Vuelca TODO el audio del juego a archivos .wav para poder escucharlo.
##
## POR QUE EXISTE. El audio esta sintetizado por codigo, asi que no hay archivos que
## abrir: la unica forma de oir un efecto es jugar hasta que salga. Eso hace que ajustar
## un sonido sea un ciclo de varios minutos, y que nadie pueda revisar el banco entero
## sin provocar cada habilidad del juego a mano.
##
## Esto lo escribe todo en disco de una, en unos segundos:
##
##     godot --headless --path . res://tests/exportar_audio.tscn -- build/audio
##
## No es un test —no verifica nada, no falla— es una herramienta. Vive en tests/ porque
## es lo que el exportador ya excluye del .zip, asi que no se publica por accidente.

var _dir: String = "build/audio"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = String(args[0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))

	# Los efectos se generan repartidos entre frames, asi que hay que esperarlos.
	var espera := 0
	while not Sfx.banco_listo() and espera < 600:
		await get_tree().process_frame
		espera += 1
	while not Music._ready_to_play and espera < 1800:
		await get_tree().process_frame
		espera += 1

	var escritos := 0
	escritos += _volcar("efectos", Sfx._bank)
	escritos += _volcar("musica", Music._tracks)
	print("")
	print("%d archivos en %s" % [escritos, _dir])
	get_tree().quit(0)


func _volcar(grupo: String, banco: Dictionary) -> int:
	var n := 0
	print("--- %s ---" % grupo)
	for nombre: StringName in banco.keys():
		var stream: AudioStreamWAV = banco[nombre]
		if stream == null:
			continue
		var ruta := "%s/%s_%s.wav" % [_dir, grupo, nombre]
		var err := stream.save_to_wav(ProjectSettings.globalize_path(ruta))
		var segundos := float(stream.data.size() / 2) / float(stream.mix_rate)
		if err == OK:
			print("   %-22s %5.2f s   %d Hz" % [nombre, segundos, stream.mix_rate])
			n += 1
		else:
			print("   %-22s FALLO (error %d)" % [nombre, err])
	return n
