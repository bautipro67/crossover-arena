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

## 22050 y no 11025. La musica se genera en memoria, asi que la tasa no agranda el .zip.
##
## A 11025 el techo de frecuencia eran 5.5 kHz: por encima de eso no entraba NADA. Ahi
## viven los hi-hats, el aire del redoblante y los armonicos que le dan filo al bajo, y
## por eso sonaba a radio AM. Con 22050 el techo sube a 11 kHz y la percusion aparece.
const MIX_RATE: int = 22050

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
##
## SIGUE SIN TENER UNA MELODIA PEGADIZA, y es a proposito: esta es la pantalla donde la
## gente configura cosas y lee texto, y un tema que se te mete en la cabeza ahi molesta
## a los diez minutos. Lo que se mejoro es el TIMBRE, no el gancho:
##
##   - Pads en dos voces desafinadas en vez de una sola. Una sola suena a tono de
##     prueba; dos batiendo suenan a instrumento.
##   - Un contracanto de tres notas por vuelta, muy separadas y muy suaves. No es una
##     melodia, es algo que pasa: alcanza para que el loop no se sienta estatico.
##   - Un sub sostenido debajo de todo, que es lo que le da el cuerpo que no tenia.
func _compose_menu() -> PackedFloat32Array:
	var compas := 4.0
	var total := compas * 4.0
	var buffer := PackedFloat32Array()
	buffer.resize(int(total * MIX_RATE))

	# Triadas de cada acorde, en semitonos respecto de La4 (440 Hz).
	var acordes: Array = [
		[-24, -12, -5, 0],    # Am
		[-29, -17, -10, -5],  # F
		[-24, -12, -8, -3],   # C
		[-26, -14, -7, -2],   # G
	]
	# El contracanto: [compas, semitono, largo en segundos]. Tres notas por vuelta.
	var contracanto: Array = [
		[0, 7, 2.6], [1, 4, 2.2], [2, 0, 3.0], [3, 2, 2.4],
	]

	for i: int in range(4):
		var t := compas * float(i)
		for semi: int in acordes[i]:
			# Ataque MUY lento (0.9s): el pad crece en vez de aparecer. Lo que hace que
			# un fondo sea fondo es que nunca tenga un ataque que llame la atencion.
			_render(buffer, t, compas * 1.05, _freq(semi), &"tri", 0.075, 0.9, 0.9, 0.0, 1.004)
		# Campanitas sueltas, en la octava alta.
		var campana_a: int = int(acordes[i][2]) + 12
		var campana_b: int = int(acordes[i][3]) + 12
		_render(buffer, t + 0.5, 1.4, _freq(campana_a), &"sine", 0.09, 0.004, 0.55)
		_render(buffer, t + 2.25, 1.4, _freq(campana_b), &"sine", 0.075, 0.004, 0.55)

	# Contracanto: una linea lenta arriba, con vibrato apenas perceptible.
	for nota: Array in contracanto:
		var t: float = compas * float(nota[0]) + 1.2
		_render(buffer, t, float(nota[2]), _freq(int(nota[1]) + 12), &"tri", 0.055, 0.35, 0.8, 3.2)

	# Sub sostenido debajo de todo. Es lo que separa un fondo con cuerpo de uno flaco.
	_render(buffer, 0.0, total, _freq(-36), &"sine", 0.10, 1.5, 1.5)
	return buffer


## Tema de combate: 150 BPM, 16 compases, CON MELODIA.
##
## LO QUE LE FALTABA ERA UN TEMA. Antes eran bajo, arpegio y bateria sobre cuatro
## acordes: un colchon correcto y nada mas. Un colchon no se te queda en la cabeza, y
## como el loop duraba 13 segundos, lo que si se te quedaba era darte cuenta de que se
## repetia.
##
## Ahora tiene forma de cancion: 16 compases partidos en A (se presenta) y B (entra la
## melodia), y dura 25 segundos. Ese contraste es lo que hace que un loop no se sienta
## como un loop: cuando la parte A vuelve, suena a que volvio, no a que nunca se fue.
func _compose_combat() -> PackedFloat32Array:
	var bpm := 150.0
	var beat := 60.0 / bpm
	var compas := beat * 4.0
	var compases := 16
	var total := compas * float(compases)
	var buffer := PackedFloat32Array()
	buffer.resize(int(total * MIX_RATE))

	# Am - F - C - G. Raices en semitonos desde La4.
	var raices: Array[int] = [-24, -29, -21, -26]
	var acordes: Array = [
		[0, 3, 7],   # Am
		[0, 4, 7],   # F
		[0, 4, 7],   # C
		[0, 4, 7],   # G
	]
	# LA MELODIA: [compas.beat de entrada, semitonos sobre la raiz, largo en negras].
	# Entra en el compas 8 y es la mitad B del tema.
	var melodia: Array = [
		[0.0, 12, 1.0], [1.0, 15, 0.5], [1.5, 14, 0.5], [2.0, 12, 1.0], [3.0, 10, 1.0],
		[4.0, 12, 1.5], [5.5, 15, 0.5], [6.0, 19, 2.0],
		[8.0, 17, 1.0], [9.0, 15, 1.0], [10.0, 14, 2.0],
		[12.0, 12, 0.75], [12.75, 14, 0.75], [13.5, 15, 0.75], [14.25, 17, 1.75],
	]

	for c: int in range(compases):
		var t := compas * float(c)
		var i := c % 4
		var raiz: int = raices[i]
		var seccion_b := c >= 8

		for p: int in range(4):
			var tp := t + beat * float(p)

			# --- Bajo ---
			# DOS SIERRAS APENAS DESAFINADAS. Una sola suena fina y sintetica; dos
			# batiendo entre si suenan a bajo de verdad. Es el truco mas viejo del
			# sintetizador y el que mas rinde por lo poco que cuesta.
			_render(buffer, tp, beat * 0.44, _freq(raiz), &"saw", 0.20, 0.003, 0.09, 0.0, 1.006)
			if p == 3:
				_render(buffer, tp + beat * 0.5, beat * 0.36, _freq(raiz + 12), &"saw", 0.15, 0.003, 0.08, 0.0, 1.006)
			else:
				_render(buffer, tp + beat * 0.5, beat * 0.30, _freq(raiz), &"saw", 0.11, 0.003, 0.07, 0.0, 1.006)

			# --- Arpegio en semicorcheas ---
			# En la seccion B baja de volumen para dejar pasar la melodia. Si compiten,
			# no se entiende ninguno de los dos.
			var amp_arp := 0.030 if seccion_b else 0.052
			var notas: Array = acordes[i]
			for sc: int in range(4):
				var semi: int = raiz + 24 + int(notas[sc % notas.size()])
				_render(buffer, tp + beat * 0.25 * float(sc), beat * 0.20, _freq(semi),
					&"square", amp_arp, 0.002, 0.05)

			# --- Percusion ---
			if p == 0 or p == 2:
				_render_kick(buffer, tp)
			# Sincopa: un bombo adelantado antes del 3. Es lo que le da empuje en vez
			# de sonar a metronomo.
			if p == 1:
				_render_kick(buffer, tp + beat * 0.75)
			if p == 1 or p == 3:
				_render_snare(buffer, tp)
			_render_hat(buffer, tp, 0.030)
			_render_hat(buffer, tp + beat * 0.5, 0.048)

		# Hi-hat abierto cerrando cada cuatro compases: marca la vuelta de la progresion
		# y evita que el loop se sienta como una pared lisa.
		if i == 3:
			_render_hat_abierto(buffer, t + compas - beat * 0.5, 0.06)

	# --- La melodia, arriba de todo, solo en la seccion B ---
	var t_b := compas * 8.0
	for nota: Array in melodia:
		var cuando: float = t_b + beat * float(nota[0])
		var raiz_m: int = raices[int(float(nota[0]) / 4.0) % 4]
		var semi: int = raiz_m + int(nota[1])
		var largo: float = beat * float(nota[2])
		# Lead con vibrato: una nota sostenida sin vibrato suena a tono de prueba.
		_render(buffer, cuando, largo * 0.95, _freq(semi), &"lead", 0.115, 0.010, 0.12, 5.5)

	return buffer


# ---------------------------------------------------------------- Sintetizadores

func _freq(semitones_from_a4: int) -> float:
	return 440.0 * pow(2.0, float(semitones_from_a4) / 12.0)


## Suma una nota al buffer. attack y release estan en segundos.
##
## `vibrato_hz` en 0 desactiva el vibrato. `detune` mayor que 1 suma una segunda voz
## desafinada por ese factor.
func _render(buffer: PackedFloat32Array, start: float, duration: float, freq: float,
		wave: StringName, amp: float, attack: float, release: float,
		vibrato_hz: float = 0.0, detune: float = 0.0) -> void:
	var from := int(start * MIX_RATE)
	var count := int(duration * MIX_RATE)
	var size := buffer.size()
	var attack_n := maxf(1.0, attack * MIX_RATE)
	var release_n := maxf(1.0, release * MIX_RATE)
	var phase := 0.0
	var phase2 := 0.0

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

		var value := _onda(wave, phase)
		if detune > 1.0:
			value = (value + _onda(wave, phase2)) * 0.5

		buffer[index] += value * env * amp

		# El vibrato modula la frecuencia, asi que el paso se recalcula por muestra.
		var f := freq
		if vibrato_hz > 0.0:
			# Entra de a poco: un vibrato que arranca al maximo suena a error, no a
			# expresion. Un cantante tampoco lo empieza en la primera decima de segundo.
			var entrada: float = minf(1.0, float(i) / float(MIX_RATE) * 4.0)
			f *= 1.0 + sin(TAU * vibrato_hz * float(i) / float(MIX_RATE)) * 0.012 * entrada
		phase += f / float(MIX_RATE)
		if detune > 1.0:
			phase2 += f * detune / float(MIX_RATE)


## Las formas de onda, aparte para que _render no sea un match de treinta lineas.
static func _onda(wave: StringName, phase: float) -> float:
	match wave:
		&"tri":
			# Tipado a mano: floor() devuelve Variant y := no puede inferir de ahi.
			var p: float = phase - floor(phase)
			return 4.0 * absf(p - 0.5) - 1.0
		&"saw":
			return 2.0 * (phase - floor(phase)) - 1.0
		&"square":
			return 1.0 if phase - floor(phase) < 0.5 else -1.0
		&"lead":
			# Pulso angosto: es el timbre de lead de los chiptunes y corta por encima del
			# bajo y del arpegio sin tener que subirle el volumen, que es lo que hace un
			# aficionado y lo que termina tapando todo lo demas.
			return 1.0 if phase - floor(phase) < 0.32 else -1.0
		_:
			return sin(TAU * phase)


## Hi-hat abierto: como el cerrado pero con la cola larga.
func _render_hat_abierto(buffer: PackedFloat32Array, start: float, amp: float) -> void:
	var from := int(start * MIX_RATE)
	var count := int(0.26 * MIX_RATE)
	var size := buffer.size()
	for i: int in range(count):
		var index := from + i
		if index < 0 or index >= size:
			break
		var t := float(i) / MIX_RATE
		buffer[index] += randf_range(-1.0, 1.0) * amp * exp(-t * 11.0)


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
