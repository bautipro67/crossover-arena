extends Node
## Autoload: Music
## Banda sonora SINTETIZADA POR CODIGO. No hay ni un archivo de audio en el proyecto.
##
## Dos temas, los dos en La menor:
##   - "menu":   lento, frio, pads sostenidos y campanitas sueltas.
##   - "combate": 140 BPM, bajo en corcheas, arpegio en semicorcheas, bombo y hi-hat.
##
## POR QUE EN UN HILO: generar ~30 segundos de audio son mas de un millon de iteraciones
## de GDScript. Hacerlo en _ready() congelaba el arranque medio segundo largo. Se genera
## en un Thread y los temas se enganchan cuando estan listos; si pediste musica antes de
## que termine, queda pendiente y arranca sola.

const MIX_RATE: int = 11025

## Cuanto tarda el cruce entre un tema y otro.
const FADE_TIME: float = 1.2
const SILENT_DB: float = -60.0

var music_volume: float = 0.5:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

var _tracks: Dictionary = {}
var _players: Dictionary = {}
var _current: StringName = &""
var _pending: StringName = &""
var _thread: Thread = null
var _ready_to_play: bool = false
## Fundido activo por tema, para poder cancelarlo.
var _fades: Dictionary = {}


func _ready() -> void:
	for name: StringName in [&"menu", &"combate"]:
		var player := AudioStreamPlayer.new()
		player.volume_db = SILENT_DB
		player.bus = "Master"
		add_child(player)
		_players[name] = player

	# EN EL NAVEGADOR NO USAMOS HILO.
	#
	# Para joinear un Thread hay que bloquear, y bloquear el hilo principal de una
	# pagina esta explicitamente desaconsejado por Emscripten: tira el error
	# "Blocking on the main thread is very dangerous" y puede colgar la pestaña.
	# Como el juego web ya muestra una pantalla de carga mientras arranca, generar
	# sincronico ahi no se nota.
	if OS.has_feature("web"):
		_build_all()
		return

	_thread = Thread.new()
	if _thread.start(_build_all) != OK:
		# Si no se puede usar un hilo, lo hacemos sincrono y aguantamos el tiron.
		_thread = null
		_build_all()


func _exit_tree() -> void:
	# Cortar todo playback antes de salir. Un AudioStreamPlayer que sigue sonando al
	# cierre deja vivos su AudioStreamPlaybackWAV y el AudioStreamWAV, y Godot avisa
	# de instancias sin liberar. Se ve como un warning menor pero es una fuga real.
	for name: StringName in _players.keys():
		var player: AudioStreamPlayer = _players[name]
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_tracks.clear()

	# Sin esto Godot avisa que un Thread se destruyo sin joinear.
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null


# ------------------------------------------------------------------- API publica

## Pone el tema del menu (o lo deja pendiente si todavia se esta generando).
func play_menu() -> void:
	_request(&"menu")


func play_combat() -> void:
	_request(&"combate")


## Corta la musica. Con immediate = true no hace fundido: para cuando el juego se
## esta cerrando y no hay tiempo de esperar 1.2 segundos.
func stop(immediate: bool = false) -> void:
	_pending = &""
	if immediate:
		# TODOS, no solo el actual: al cambiar de tema el anterior queda en fundido y
		# sigue sonando un rato. Si solo paras el actual, ese se queda vivo.
		for track: StringName in _players.keys():
			_stop_now(track)
	elif _current != &"":
		_fade(_current, SILENT_DB)
	_current = &""


func _stop_now(track: StringName) -> void:
	var player: AudioStreamPlayer = _players.get(track)
	if player == null:
		return
	# Cancelar el fundido en curso. Si no, su tween_callback(player.stop) dispara
	# despues y encima sigue moviendo el volumen de un player ya detenido.
	_kill_fade(track)
	player.volume_db = SILENT_DB
	player.stop()


func _kill_fade(track: StringName) -> void:
	var tween: Tween = _fades.get(track)
	if tween != null and tween.is_valid():
		tween.kill()
	_fades.erase(track)


func _request(track: StringName) -> void:
	if not _ready_to_play:
		_pending = track
		return
	if _current == track:
		return
	if _current != &"":
		_fade(_current, SILENT_DB)
	_current = track
	var player: AudioStreamPlayer = _players.get(track)
	if player == null:
		return
	if not player.playing:
		player.play()
	_fade(track, _target_db())


func _target_db() -> float:
	return SILENT_DB if music_volume <= 0.001 else linear_to_db(music_volume)


func _apply_volume() -> void:
	if _current == &"":
		return
	var player: AudioStreamPlayer = _players.get(_current)
	if player != null:
		player.volume_db = _target_db()


func _fade(track: StringName, to_db: float) -> void:
	var player: AudioStreamPlayer = _players.get(track)
	if player == null:
		return
	_kill_fade(track)
	var tween := player.create_tween()
	_fades[track] = tween
	tween.tween_property(player, "volume_db", to_db, FADE_TIME)
	if to_db <= SILENT_DB:
		tween.tween_callback(player.stop)


# ------------------------------------------------------------------- Generacion

## Corre en el hilo (o en el principal, en web). Al terminar avisa de forma diferida,
## que es seguro desde cualquier hilo.
func _build_all() -> void:
	_tracks[&"menu"] = _make_stream(_compose_menu())
	_tracks[&"combate"] = _make_stream(_compose_combat())
	_on_tracks_ready.call_deferred()


func _on_tracks_ready() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
	for name: StringName in _tracks.keys():
		var player: AudioStreamPlayer = _players.get(name)
		if player != null:
			player.stream = _tracks[name]
	_ready_to_play = true
	if _pending != &"":
		var want := _pending
		_pending = &""
		_request(want)


## Tema del menu: cuatro compases de cuatro segundos, Am - F - C - G.
## Pads con ataque lento y campanitas arriba. Tiene que poder escucharse en loop sin
## molestar: nada de melodias pegadizas en la pantalla donde la gente configura cosas.
func _compose_menu() -> PackedFloat32Array:
	var bar := 4.0
	var total := bar * 4.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(total * MIX_RATE))

	# Triadas de cada acorde, en semitonos respecto de La4 (440 Hz).
	var chords: Array = [
		[-24, -12, -5, 0],    # Am
		[-29, -17, -10, -5],  # F
		[-24, -12, -8, -3],   # C
		[-26, -14, -7, -2],   # G
	]
	for i: int in range(4):
		var t := bar * float(i)
		for semi: int in chords[i]:
			_render(buffer, t, bar * 1.05, _freq(semi), &"tri", 0.085, 0.9, 0.9)
		# Campanitas: dos notas sueltas por compas, en la octava alta.
		var bell_a: int = int(chords[i][2]) + 12
		var bell_b: int = int(chords[i][3]) + 12
		_render(buffer, t + 0.5, 1.4, _freq(bell_a), &"sine", 0.10, 0.004, 0.55)
		_render(buffer, t + 2.25, 1.4, _freq(bell_b), &"sine", 0.085, 0.004, 0.55)

	# Una nota grave sostenida abajo de todo, que le da cuerpo.
	_render(buffer, 0.0, total, _freq(-36), &"sine", 0.09, 1.5, 1.5)
	return buffer


## Tema de combate: 140 BPM, 32 tiempos (13.7 s). Bajo, arpegio y percusion.
func _compose_combat() -> PackedFloat32Array:
	var bpm := 140.0
	var beat := 60.0 / bpm
	var beats := 32
	var total := beat * float(beats)
	var buffer := PackedFloat32Array()
	buffer.resize(int(total * MIX_RATE))

	# Progresion de cuatro compases: Am - F - G - Am (raiz en semitonos).
	var roots: Array[int] = [-24, -29, -26, -24]
	# Arpegio de cada acorde.
	var arps: Array = [
		[0, 3, 7, 12],   # Am
		[0, 4, 7, 12],   # F
		[0, 4, 7, 11],   # G
		[0, 3, 7, 12],
	]

	for b: int in range(beats):
		var t := beat * float(b)
		var bar_index := (b / 8) % 4
		var root: int = roots[bar_index]

		# --- Bajo en corcheas, con la segunda corchea una octava arriba ---
		_render(buffer, t, beat * 0.46, _freq(root), &"saw", 0.20, 0.004, 0.10)
		_render(buffer, t + beat * 0.5, beat * 0.40, _freq(root + 12), &"saw", 0.13, 0.004, 0.10)

		# --- Arpegio en semicorcheas, dos octavas arriba ---
		var pattern: Array = arps[bar_index]
		for s: int in range(4):
			var semi: int = root + 24 + int(pattern[s % pattern.size()])
			_render(buffer, t + beat * 0.25 * float(s), beat * 0.22, _freq(semi), &"square", 0.055, 0.003, 0.06)

		# --- Percusion ---
		# Bombo en 1 y 3 de cada compas.
		if b % 2 == 0:
			_render_kick(buffer, t)
		# Hi-hat en cada corchea, mas fuerte en los contratiempos.
		_render_hat(buffer, t, 0.035)
		_render_hat(buffer, t + beat * 0.5, 0.055)
		# Redoblante en 2 y 4.
		if b % 4 == 2:
			_render_snare(buffer, t)

	return buffer


# ---------------------------------------------------------------- Sintetizadores

func _freq(semitones_from_a4: int) -> float:
	return 440.0 * pow(2.0, float(semitones_from_a4) / 12.0)


## Suma una nota al buffer. attack y release estan en segundos.
func _render(buffer: PackedFloat32Array, start: float, duration: float, freq: float,
		wave: StringName, amp: float, attack: float, release: float) -> void:
	var from := int(start * MIX_RATE)
	var count := int(duration * MIX_RATE)
	var size := buffer.size()
	var attack_n := maxf(1.0, attack * MIX_RATE)
	var release_n := maxf(1.0, release * MIX_RATE)
	var phase_step := freq / float(MIX_RATE)
	var phase := 0.0

	for i: int in range(count):
		var index := from + i
		if index < 0 or index >= size:
			break
		# Envolvente: ataque lineal, caida exponencial.
		var env := minf(1.0, float(i) / attack_n)
		var remaining := float(count - i)
		if remaining < release_n:
			env *= remaining / release_n
		env *= exp(-float(i) / (release_n * 2.0))

		var value := 0.0
		match wave:
			&"sine":
				value = sin(TAU * phase)
			&"tri":
				var p := fmod(phase, 1.0)
				value = 4.0 * absf(p - 0.5) - 1.0
			&"saw":
				value = 2.0 * fmod(phase, 1.0) - 1.0
			&"square":
				value = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			_:
				value = sin(TAU * phase)

		buffer[index] += value * env * amp
		phase += phase_step


func _render_kick(buffer: PackedFloat32Array, start: float) -> void:
	var from := int(start * MIX_RATE)
	var count := int(0.16 * MIX_RATE)
	var size := buffer.size()
	for i: int in range(count):
		var index := from + i
		if index < 0 or index >= size:
			break
		var t := float(i) / MIX_RATE
		# La frecuencia cae de 150 a 45 Hz: eso es lo que el oido lee como bombo.
		var freq := lerpf(150.0, 45.0, minf(1.0, t * 14.0))
		buffer[index] += sin(TAU * freq * t) * 0.42 * exp(-t * 22.0)


func _render_snare(buffer: PackedFloat32Array, start: float) -> void:
	var from := int(start * MIX_RATE)
	var count := int(0.13 * MIX_RATE)
	var size := buffer.size()
	var last := 0.0
	for i: int in range(count):
		var index := from + i
		if index < 0 or index >= size:
			break
		var t := float(i) / MIX_RATE
		last = lerpf(last, randf_range(-1.0, 1.0), 0.6)
		buffer[index] += (last * 0.20 + sin(TAU * 190.0 * t) * 0.10) * exp(-t * 26.0)


func _render_hat(buffer: PackedFloat32Array, start: float, amp: float) -> void:
	var from := int(start * MIX_RATE)
	var count := int(0.05 * MIX_RATE)
	var size := buffer.size()
	for i: int in range(count):
		var index := from + i
		if index < 0 or index >= size:
			break
		var t := float(i) / MIX_RATE
		buffer[index] += randf_range(-1.0, 1.0) * amp * exp(-t * 90.0)


## Convierte el buffer en un AudioStreamWAV que loopea sin costura.
func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		# tanh suave por si la suma de voces se paso de 1.0: comprime en vez de clippear.
		var s := samples[i]
		if s > 1.0 or s < -1.0:
			s = signf(s) * (1.0 - exp(-absf(s)))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = samples.size()
	return stream
