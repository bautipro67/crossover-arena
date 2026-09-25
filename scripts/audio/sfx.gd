extends Node
## Autoload: Sfx
## Todos los sonidos del juego, SINTETIZADOS POR CODIGO.
##
## No hay ni un archivo de audio en el proyecto: cada efecto se genera como PCM crudo al
## arrancar y se guarda en un AudioStreamWAV en memoria.
##
## POR QUE NO SON LOS SONIDOS ORIGINALES. Son de Deltarune y de JoJo, o sea material con
## dueño, y este es un fangame gratuito: meter los samples rippeados seria distribuir
## audio ajeno. Lo que se hace en cambio es RECONSTRUIRLOS: cada efecto imita el timbre,
## la envolvente y el gesto del original con sintesis propia. Un Snowgrave suena a
## campana helada porque asi suena en Deltarune, no porque sea la misma onda.
##
## De ahi que aca abajo haya filtros de verdad y no senos sueltos. Lo que separa un
## efecto que "suena a juego" de uno que suena a pitido es casi siempre lo mismo: cuerpo
## abajo, un transitorio arriba, y algo que no sea una sinusoide limpia en el medio.

## 32000 y no los 22050 de antes, y no cuesta un solo byte del .zip.
##
## Los sonidos se generan en memoria al arrancar, asi que subir la tasa no agranda nada
## que se descargue. A 22050 el techo de frecuencia eran 11 kHz, y ahi arriba es justo
## donde viven el brillo del hielo, el filo del metal y el chasquido de un golpe: todo
## sonaba tapado, como a traves de una pared. Con 32000 el techo sube a 16 kHz, que ya
## cubre todo eso.
##
## POR QUE NO 44100. Lo probe, y generar el banco pasaba a tardar 851 ms. Eso es casi un
## segundo de arranque —peor en el navegador, que corre wasm en un solo hilo— a cambio
## de frecuencias arriba de 16 kHz que casi nadie oye y que en estos efectos no aportan
## nada. 32000 deja el banco en la mitad de tiempo y suena igual.
const MIX_RATE: int = 32000
## Cuantos reproductores 3D simultaneos como maximo. Evita que una pelea llene el arbol.
const MAX_VOICES: int = 24

## Sonidos que NO se desafinan al repetirse. Ver _play_variacion().
const SIN_VARIACION: Array[StringName] = [
	&"za_warudo", &"snowgrave", &"last_jarona", &"channel", &"ui_click", &"respawn",
]

var master_volume: float = 0.8:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

var _bank: Dictionary = {}
var _ui_player: AudioStreamPlayer = null
var _voices: int = 0
## Reproductores 3D vivos, para poder cortarlos todos al cerrar.
var _active: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)
	_apply_volume()
	_build_bank()


func _exit_tree() -> void:
	stop_all()


## Corta todo lo que este sonando. Un AudioStreamPlayer que sigue activo cuando el
## juego cierra deja vivos su playback y su AudioStreamWAV, y Godot avisa de instancias
## sin liberar al salir.
func stop_all() -> void:
	for player: AudioStreamPlayer3D in _active:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_active.clear()
	_voices = 0
	if is_instance_valid(_ui_player):
		_ui_player.stop()
		_ui_player.stream = null


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0:
		return
	if is_zero_approx(master_volume):
		AudioServer.set_bus_mute(bus, true)
	else:
		AudioServer.set_bus_mute(bus, false)
		AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))


## Busca una grabacion para este sonido en assets/audio/.
##
## Acepta .ogg y .wav. El .ogg es el que conviene publicar —pesa una fraccion y la
## version web se descarga entera antes de jugar— pero el .wav entra igual para poder
## probar una toma sin convertirla primero.
##
## Devuelve null si no hay nada, y eso NO es un error: significa "esta la sintetiza el
## codigo", que es el caso de casi todo el juego.
func _audio_de_archivo(id: StringName) -> AudioStream:
	for ext: String in ["ogg", "wav"]:
		var ruta := "res://assets/audio/%s.%s" % [id, ext]
		if ResourceLoader.exists(ruta):
			var recurso := load(ruta)
			if recurso is AudioStream:
				return recurso as AudioStream
			push_warning("[sfx] %s existe pero no es un audio" % ruta)
	return null


# ------------------------------------------------------------------ Reproduccion

## Cuanto dura un sonido del banco, en segundos. 0 si no existe.
##
## Hace falta porque desde que los sonidos pueden venir de un archivo, su duracion dejo de
## ser un numero que conoce el que escribio la habilidad: la decide el que dejo caer el
## .ogg. Lo que se encadena con un sonido tiene que preguntar, no suponer.
func duracion(sound: StringName) -> float:
	var s: AudioStream = _bank.get(sound)
	return s.get_length() if s != null else 0.0


## Sonido no posicional (UI, avisos).
func play_2d(sound: StringName, volume_db: float = 0.0) -> void:
	if not _bank.has(sound) or _ui_player == null:
		return
	_ui_player.stream = _bank[sound]
	_ui_player.volume_db = volume_db
	_ui_player.play()


## Sonido posicional en el mundo 3D.
func play_3d(context: Node, sound: StringName, position: Vector3, volume_db: float = 0.0) -> void:
	if not _bank.has(sound) or _voices >= MAX_VOICES:
		return
	if not is_instance_valid(context) or not context.is_inside_tree():
		return
	var tree := context.get_tree()
	if tree == null or tree.current_scene == null:
		return

	var player := AudioStreamPlayer3D.new()
	player.stream = _bank[sound]
	player.volume_db = volume_db
	player.pitch_scale = _play_variacion(sound)
	player.unit_size = 14.0
	player.max_distance = 60.0
	tree.current_scene.add_child(player)
	player.global_position = position
	player.play()
	_voices += 1
	_active.append(player)
	player.finished.connect(func() -> void:
		_voices = maxi(0, _voices - 1)
		_active.erase(player)
		if is_instance_valid(player):
			player.queue_free()
	)


## Cada repeticion suena un poco distinta.
##
## UNA RAFAGA DE MUDA SON VEINTE GOLPES EN DOS SEGUNDOS, y veinte veces el mismo archivo
## identico no se oye como veinte golpes: se oye como un motor. Basta con moverle un 6%
## el tono a cada uno para que el oido los separe. Es el truco mas barato que hay para
## que un banco chico de sonidos no delate su tamaño.
##
## Los grandes quedan afuera: un Snowgrave o un ZA WARUDO suenan una vez y son la firma
## del personaje, asi que tienen que sonar SIEMPRE igual.
func _play_variacion(sound: StringName) -> float:
	if SIN_VARIACION.has(sound):
		return 1.0
	return randf_range(0.94, 1.06)


# ------------------------------------------------------------- Taller de sintesis
#
# Generadores y filtros. Todo opera sobre PackedFloat32Array en [-1, 1].

## Diente de sierra. Rico en armonicos: es la base de cualquier sonido con cuerpo, y lo
## que una sinusoide nunca va a dar.
## Ruido blanco barato, con un generador congruencial propio.
##
## randf_range() es una llamada de motor POR MUESTRA, y el banco tiene cientos de miles;
## era una de las dos cosas que hacian lento el arranque. Esto es aritmetica entera pura
## y para ruido audible da exactamente igual de aleatorio.
static var _semilla: int = 0x2545F491

static func _ruido() -> float:
	_semilla = (_semilla * 1103515245 + 12345) & 0x7FFFFFFF
	return float(_semilla) / 1073741823.5 - 1.0


static func _sierra(fase: float) -> float:
	return 2.0 * (fase - floor(fase + 0.5))


## La fuente de las VOCES: una parabola, no un diente de sierra.
##
## Es una correccion fisica, no un gusto. La cadena de una voz es
##     flujo glotico  ->  garganta (formantes)  ->  labios  ->  aire
## donde el flujo glotico cae 12 dB por octava y los labios, que radian su derivada,
## suben 6. El resultado son los -6 dB/octava que mide una persona hablando.
##
## Un diente de sierra cae 6 y no 12. Con los mismos labios eso deja la voz en 0: medido,
## salia en -2.3 dB/octava cuando tenia que estar entre -6 y -12. Tres veces mas brillante
## que cualquier garganta humana, y eso se oye como chillon y metalico por mas que los
## formantes esten exactamente en su lugar. Era el defecto de fondo.
##
## Una parabola cae exactamente 12 dB por octava —sus armonicos van como 1/n² en vez de
## 1/n— y ademas es suave, asi que tampoco genera armonicos altos que se doblen.
##
## (Probe antes el pulso de Rosenberg, que es la forma glotica de manual. Tambien cae 12,
## pero por arriba se apaga mucho mas rapido y se llevo puestos los formantes altos: el
## reconocimiento de vocales se cayo de 31 sobre 31 a 24. La parabola da la misma
## pendiente conservando los armonicos que las vocales necesitan para entenderse.)
static func _parabola(fase: float) -> float:
	var t: float = fase - floor(fase)
	return 8.0 * t * (1.0 - t) - 1.0


## Onda cuadrada con ancho de pulso. `ancho` 0.5 da cuadrada; valores chicos dan ese
## timbre nasal de chiptune que usa Deltarune para casi todo.
static func _pulso(fase: float, ancho: float) -> float:
	return 1.0 if fase - floor(fase) < ancho else -1.0


## Campana por FM. Dos osciladores con razon NO entera dan parciales inarmonicos, que es
## exactamente lo que hace que algo suene a metal o a cristal y no a flauta.
static func _campana(t: float, freq: float, razon: float, indice: float) -> float:
	return sin(TAU * freq * t + indice * sin(TAU * freq * razon * t))


## Pasabajos de un polo, en el lugar. Le saca el filo al ruido y lo convierte en aire.
static func _pasabajos(buf: PackedFloat32Array, corte: float) -> void:
	var k: float = clampf(corte / (corte + float(MIX_RATE) * 0.15), 0.001, 1.0)
	var y := 0.0
	for i: int in range(buf.size()):
		y += (buf[i] - y) * k
		buf[i] = y


## Pasaaltos de un polo, en el lugar. Saca el retumbe de abajo cuando estorba.
static func _pasaaltos(buf: PackedFloat32Array, corte: float) -> void:
	var k: float = clampf(corte / (corte + float(MIX_RATE) * 0.15), 0.001, 1.0)
	var y := 0.0
	for i: int in range(buf.size()):
		y += (buf[i] - y) * k
		buf[i] = buf[i] - y


## Resonador de dos polos: SUMA al buffer una copia filtrada en banda estrecha.
##
## Es la pieza clave para que una voz suene a voz. Un grito no es un tono: es una fuente
## rica pasada por las resonancias de una garganta. Poniendo dos o tres de estos en las
## frecuencias de formante correctas, un diente de sierra se convierte en una vocal.
static func _resonar(buf: PackedFloat32Array, fuente: PackedFloat32Array,
		freq: float, r: float, ganancia: float) -> void:
	var w: float = TAU * freq / float(MIX_RATE)
	var b1: float = 2.0 * r * cos(w)
	var b2: float = -r * r
	var a0: float = (1.0 - r * r) * ganancia
	var y1 := 0.0
	var y2 := 0.0
	for i: int in range(buf.size()):
		var y: float = a0 * fuente[i] + b1 * y1 + b2 * y2
		y2 = y1
		y1 = y
		buf[i] += y


## Saturacion suave. Redondea los picos en vez de recortarlos: da fuerza sin el crujido
## del clipping duro, que es lo que hace que un golpe "pegue" en vez de solo sonar.
static func _saturar(buf: PackedFloat32Array, cantidad: float) -> void:
	var norm: float = tanh(cantidad)
	for i: int in range(buf.size()):
		buf[i] = tanh(buf[i] * cantidad) / norm


## Deja el pico en `objetivo`. Asi ningun efecto sale mas fuerte que los demas por
## accidente, que es como se termina con un banco donde hay que bajar el volumen general.
static func _normalizar(buf: PackedFloat32Array, objetivo: float) -> void:
	var pico := 0.0
	for v: float in buf:
		pico = maxf(pico, absf(v))
	if pico < 0.0001:
		return
	var g: float = objetivo / pico
	for i: int in range(buf.size()):
		buf[i] *= g


## Le pone un ataque y una caida suaves a los bordes. Sin esto, un buffer que arranca o
## termina fuera de cero hace "clic".
static func _bordes(buf: PackedFloat32Array, ataque_ms: float, caida_ms: float) -> void:
	var n := buf.size()
	var a := maxi(1, int(float(MIX_RATE) * ataque_ms * 0.001))
	var c := maxi(1, int(float(MIX_RATE) * caida_ms * 0.001))
	for i: int in range(mini(a, n)):
		buf[i] *= float(i) / float(a)
	for i: int in range(mini(c, n)):
		buf[n - 1 - i] *= float(i) / float(c)


static func _vacio(segundos: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(float(MIX_RATE) * segundos))
	return out


# -------------------------------------------------------------------- El banco

## Arma el banco. LOS DE INTERFAZ YA; LOS DE COMBATE, REPARTIDOS ENTRE FRAMES.
##
## Generar los dieciseis de una tarda unos 600 ms, y eso es medio segundo de pantalla
## congelada al abrir el juego —peor en el navegador, que corre wasm en un solo hilo—.
## Repartidos de a uno por frame, el menu aparece al instante y el banco termina de
## armarse mientras el jugador lee la pantalla, mucho antes de que entre a una partida.
##
## Los de interfaz NO pueden esperar: el click del menu es lo primero que suena, asi que
## esos tres se hacen sincronos. Son los mas cortos y juntos no llegan al milisegundo.
##
## play_2d/play_3d ya ignoran lo que todavia no esta en el banco, asi que un sonido
## pedido antes de tiempo simplemente no suena, no rompe nada.
func _build_bank() -> void:
	for par: Array in [[&"ui_click", _synth_ui_click], [&"no_stamina", _synth_no_stamina],
			[&"respawn", _synth_respawn]]:
		var grabado := _audio_de_archivo(par[0])
		_bank[par[0]] = grabado if grabado != null else _make((par[1] as Callable).call())
	_build_combate.call_deferred()


## Cuantos sonidos tiene que haber cuando el banco esta completo.
const TOTAL_SONIDOS: int = 34

## Termino de armarse el banco? Lo usan los arneses, que arrancan una partida en el
## primer frame y no pueden asumir que los sonidos largos ya existen.
func banco_listo() -> bool:
	return _bank.size() >= TOTAL_SONIDOS


func _build_combate() -> void:
	var arranque := Time.get_ticks_msec()
	var receta: Array = [
		[&"hit_punch", _synth_punch], [&"hit_ice", _synth_ice_hit],
		[&"petals", _synth_petals], [&"knife", _synth_knife],
		[&"paso", _synth_paso], [&"salto", _synth_salto], [&"aterrizaje", _synth_aterrizaje],
		[&"dash", _synth_dash], [&"ice_shock", _synth_ice_shock],
		[&"freeze", _synth_freeze],
		[&"death", _synth_death], [&"channel", _synth_channel],
		[&"plasma", _synth_plasma], [&"plasma_blast", _synth_plasma_blast],
		[&"meeseeks", _synth_meeseeks],
		[&"last_jarona", _synth_last_jarona], [&"snowgrave", _synth_snowgrave],
		[&"portal", _synth_portal], [&"za_warudo", _synth_za_warudo],
		[&"fuego", _synth_fuego], [&"estrella", _synth_estrella],
		# Las voces al final: son las mas caras de generar —tres resonadores moviles por
		# palabra— y son las unicas que nadie puede necesitar en el primer segundo,
		# porque para gritar una habilidad primero hay que tener una habilidad lista.
		[&"voz_jarona", _synth_voz_jarona],
		[&"voz_here_i_come", _synth_voz_here_i_come],
		[&"voz_last_jarona", _synth_voz_last_jarona],
		[&"voz_muda", _synth_voz_muda],
		[&"voz_za_warudo", _synth_voz_za_warudo],
		[&"voz_toki", _synth_voz_toki],
		[&"voz_kamehameha", _synth_voz_kamehameha],
		[&"voz_ha", _synth_voz_ha],
		[&"voz_wahoo", _synth_voz_wahoo],
		[&"voz_lets_go", _synth_voz_lets_go],
	]
	# Ordenados de mas corto a mas largo a proposito: los golpes basicos —que son los que
	# se pueden llegar a necesitar antes— quedan listos en los primeros frames.
	for item: Array in receta:
		var generador: Callable = item[1]
		# UN ARCHIVO GANA SIEMPRE, si existe. Para CUALQUIER sonido del banco.
		#
		# El juego se sintetiza entero por codigo y esa sigue siendo la regla: es lo que
		# hace que pese 9 MB y que no dependa de nada. Pero la sintesis tiene un techo, muy
		# duro en las voces —puede decir palabras entendibles, no suena a una persona— y
		# real tambien en los efectos con identidad propia. Asi que cualquiera se puede
		# reemplazar por una grabacion.
		#
		# Empezo valiendo solo para las voces y se generalizo apenas aparecio el primer
		# efecto grabado. No hay motivo para que el mecanismo distinga: un id, un archivo.
		#
		# Es una comprobacion por sonido y no un modo aparte a proposito. Se pueden tener
		# tres voces grabadas y tres sintetizadas sin configurar nada: cada una busca su
		# archivo y, si no esta, se genera. Nada se rompe por faltar, que es lo que importa
		# cuando los archivos los va poniendo alguien de a uno.
		var grabada := _audio_de_archivo(item[0])
		_bank[item[0]] = grabada if grabada != null else _make(generador.call())
		if is_inside_tree():
			await get_tree().process_frame
	print("[sfx] banco completo en %d ms (%d sonidos a %d Hz)" % [
		Time.get_ticks_msec() - arranque, _bank.size(), MIX_RATE])


# ----------------------------------------------------------------------- Voz
#
# Los personajes ANUNCIAN sus ataques, y en los dos originales ese anuncio es audible.
# Hasta aca el juego tenia gritos —un "AAAH" con los formantes de una A— pero ninguna
# PALABRA: se oia a alguien gritando, no se oia "Jarona".
#
# La diferencia entre las dos cosas es que las vocales se MUEVAN. Un grito sostenido es
# un formante fijo; una palabra es una garganta cambiando de forma en el medio. Con los
# formantes quietos, "ja-ro-na" y "za-wa-ru-do" suenan exactamente igual.

## Formantes por vocal, en Hz: [F1, F2, F3]. Son los valores medidos de una garganta
## masculina adulta; cada personaje los escala segun el tamaño del suyo.
const VOCALES: Dictionary = {
	"a": [730.0, 1090.0, 2440.0],
	"e": [530.0, 1840.0, 2480.0],
	"i": [270.0, 2290.0, 3010.0],
	"o": [570.0, 840.0, 2410.0],
	"u": [300.0, 870.0, 2240.0],
}

## Cuanto tarda la boca en pasar de una vocal a la siguiente. 45 ms es lo que tarda una
## de verdad: mas rapido suena a corte de cinta, mas lento se vuelve un aullido y las
## silabas dejan de separarse.
const TRANSICION: float = 0.045


## Resonador de dos polos con la frecuencia EN MOVIMIENTO.
##
## El _resonar de arriba tiene la frecuencia clavada, que alcanza para un grito pero no
## para una palabra: si el formante no se mueve no hay articulacion, y todas las silabas
## salen con la misma vocal.
##
## Los coeficientes se recalculan cada 64 muestras y no en cada una. A 32 kHz eso son 500
## actualizaciones por segundo, diez veces mas rapido que lo que tarda una boca en
## moverse, y evita 28 mil cosenos por formante y por palabra.
## NORMALIZADO EN EL PICO, y ahi estaba el bug que hacia que no se entendiera nada.
##
## El _resonar de arriba usa a0 = (1 - r²), que deja ganancia uno cerca de continua pero
## NO en la resonancia. Y cuanto mas arriba esta el formante, peor: medido, el mismo a0
## daba pico 16 a 313 Hz y pico 1.8 a 2650 Hz. Diecinueve decibeles de diferencia que no
## pidio nadie, y que caen justo sobre F2 y F3.
##
## Consecuencia: el F2 de una "i" salia 36 dB por debajo de F1 —en una voz de verdad son
## 10 o 15— asi que sencillamente no estaba. Medido en el espectro: donde tenia que haber
## un pico a 2650 Hz habia un MINIMO. El sintetizador decia todas las vocales con la
## misma boca.
##
## La ganancia real en el pico de un resonador de dos polos es
##     a0 / [ (1-r) · sqrt(1 - 2r·cos(2w) + r²) ]
## asi que multiplicar por ese denominador la deja en uno, sea cual sea la frecuencia.
## Recien con eso `ganancia` significa lo que aparenta y se pueden usar las amplitudes de
## formante de los libros.
static func _resonar_movil(buf: PackedFloat32Array, fuente: PackedFloat32Array,
		pista: PackedFloat32Array, r: float, ganancia: float) -> void:
	var b2: float = -r * r
	var a0: float = 0.0
	var b1: float = 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i: int in range(buf.size()):
		if i % 64 == 0:
			var w: float = TAU * pista[i] / float(MIX_RATE)
			b1 = 2.0 * r * cos(w)
			a0 = ganancia * (1.0 - r) * sqrt(maxf(0.0,
				1.0 - 2.0 * r * cos(2.0 * w) + r * r))
		var y: float = a0 * fuente[i] + b1 * y1 + b2 * y2
		y2 = y1
		y1 = y
		buf[i] += y


## Una palabra gritada.
##
## `silabas` es una lista de [vocal, duracion, ataque]. El ataque es la consonante con la
## que arranca la silaba, y es lo que hace que se oigan SEPARADAS: sin el, las vocales se
## funden en un solo sonido largo aunque los formantes se muevan bien.
##
##   "golpe" -> oclusiva sorda (t, k): silencio y despues un chasquido. El silencio es la
##              parte que importa; es lo que el oido lee como "empezo una silaba nueva".
##   "suave" -> oclusiva sonora (d, b, g): el mismo gesto pero mucho mas corto y sin
##              silencio del todo, porque la garganta no deja de vibrar. Tratar una "d"
##              como una "t" le come 30 ms a la vocal que viene atras, y en una silaba de
##              100 ms eso es un tercio.
##   "aire"  -> fricativa (j, s, h): soplido que se funde con la vocal.
##   "nasal" -> m, n: el primer formante se hunde y el volumen baja un momento.
##   ""      -> la vocal entra directo.
## Los cuatro ultimos parametros son los que hacen que dos personajes no suenen igual.
## Cambiar solo el tono no alcanza: dos voces al mismo tono siguen siendo la misma persona
## cantando mas grave. Lo que separa a una de otra es el CUERPO (escala), la FORMA DE
## DECIR (dramatismo), el BRILLO y la aspereza de las cuerdas (rasgado).
static func _voz(silabas: Array, f0_pico: float, escala: float,
		aspereza: float = 0.12, dramatismo: float = 1.0,
		brillo_alto: float = 1.0, rasgado: float = 0.0) -> PackedFloat32Array:
	var dur := 0.08
	for s: Array in silabas:
		dur += s[1] as float
	var n_total: int = int(dur * MIX_RATE)
	var p1 := PackedFloat32Array()
	p1.resize(n_total)
	var p2 := PackedFloat32Array()
	p2.resize(n_total)
	var p3 := PackedFloat32Array()
	p3.resize(n_total)
	var env := PackedFloat32Array()
	env.resize(n_total)
	var ruidoso := PackedFloat32Array()
	ruidoso.resize(n_total)

	# --- Pistas de formante y envolvente, silaba por silaba ---
	var t0 := 0.0
	for k: int in range(silabas.size()):
		var sil: Array = silabas[k]
		var vocal: String = sil[0]
		var largo: float = sil[1]
		var ataque: String = sil[2]
		var f: Array = VOCALES[vocal]
		var previa: Array = f if k == 0 else VOCALES[(silabas[k - 1] as Array)[0] as String]
		var desde: int = int(t0 * MIX_RATE)
		var hasta: int = mini(n_total, int((t0 + largo) * MIX_RATE))

		# Cuanto dura la consonante antes de que entre la vocal.
		# LA TRANSICION SE ACORTA EN LAS SILABAS CORTAS.
		#
		# 45 ms es lo que tarda una boca de verdad, pero las silabas de "mu-da mu-da" duran
		# 100 ms de vocal: la transicion se comia la mitad y la vocal nunca llegaba a su
		# lugar. Medido, las tres "a" de MUDA se reconocian como "o", que es exactamente la
		# vocal por la que pasa la "u" camino a la "a".
		var pre := 0.0
		if ataque == "golpe":
			pre = 0.032
		elif ataque == "suave":
			pre = 0.018
		elif ataque == "aire":
			pre = 0.042
		elif ataque == "nasal":
			pre = 0.035

		# Y EN LAS CORTAS SE ACELERA BASTANTE MAS QUE PROPORCIONALMENTE.
		#
		# Al 35% la vocal llegaba a destino justo cuando la silaba ya se estaba apagando, y
		# medido se reconocia como la vocal por la que venia pasando: las "a" cortas salian
		# "o". Es un fenomeno real —en el habla rapida las vocales no llegan a su lugar— y
		# es exactamente lo que uno NO hace cuando grita un nombre de ataque para que se
		# entienda. Al 22% la boca llega y se queda.
		var desliz: float = minf(TRANSICION, (largo - pre) * 0.22)
		for i: int in range(desde, hasta):
			var t: float = float(i) / MIX_RATE - t0
			# La boca no salta de una vocal a la otra: se desliza. El deslizamiento
			# arranca DESPUES de la consonante, porque la consonante es justamente el
			# momento en que la boca esta cerrada.
			var mezcla: float = clampf((t - pre) / desliz, 0.0, 1.0)
			p1[i] = lerpf(previa[0] as float, f[0] as float, mezcla) * escala
			p2[i] = lerpf(previa[1] as float, f[1] as float, mezcla) * escala
			p3[i] = lerpf(previa[2] as float, f[2] as float, mezcla) * escala

			var a := 1.0
			if t < pre:
				var q: float = t / maxf(pre, 0.0001)
				if ataque == "golpe":
					# Silencio, y recien al final el chasquido. Es el silencio el que
					# marca la silaba; el chasquido solo la hace sonar dura.
					a = 0.0 if q < 0.72 else 1.4
					ruidoso[i] = 1.0 if q >= 0.72 else 0.0
				elif ataque == "suave":
					# Nunca llega a cero: una oclusiva sonora sigue sonando mientras la
					# boca esta cerrada, y es eso lo que la hace sonar a "d" y no a "t".
					a = 0.28 + q * 0.95
					ruidoso[i] = 0.35 if q >= 0.6 else 0.0
				elif ataque == "aire":
					a = q * 0.55
					ruidoso[i] = 1.0 - q * 0.5
				elif ataque == "nasal":
					a = 0.35 + q * 0.4
					# Nasal: el primer formante se hunde, que es lo que distingue una
					# "n" de la vocal que viene despues.
					p1[i] = lerpf(260.0 * escala, p1[i], q)
			else:
				var resto: float = (t - pre) / maxf(largo - pre, 0.0001)
				# Cae hacia el final de la silaba. Sin esta caida las silabas se pegan.
				a = 1.0 - 0.5 * pow(clampf((resto - 0.55) / 0.45, 0.0, 1.0), 1.5)
			env[i] = a
		t0 += largo

	# Cola: la ultima vocal se apaga sola en vez de cortarse.
	var ultima: Array = silabas[silabas.size() - 1]
	var f_ult: Array = VOCALES[ultima[0] as String]
	for i: int in range(int(t0 * MIX_RATE), n_total):
		var q: float = (float(i) / MIX_RATE - t0) / 0.08
		p1[i] = (f_ult[0] as float) * escala
		p2[i] = (f_ult[1] as float) * escala
		p3[i] = (f_ult[2] as float) * escala
		env[i] = maxf(0.0, 0.5 * (1.0 - q))

	# --- La fuente: cuerdas vocales mas aire ---
	var fuente := _vacio(dur)
	var soplido := _vacio(dur)
	var silbido := _vacio(dur)
	var fase := 0.0
	var ciclo_previo: int = -1
	var jitter: float = 1.0
	var shimmer: float = 1.0
	for i: int in range(n_total):
		var t: float = float(i) / MIX_RATE
		var p: float = t / dur
		# El tono de un grito: se dispara y despues se desinfla. Es lo que separa gritar
		# de hablar, y sin la caida final suena a robot leyendo.
		# El contorno de tono ES la actuacion. Un anuncio teatral se dispara hacia arriba
		# y se desploma al final; una amenaza contenida se queda casi plana y grave. Con
		# el mismo contorno, dos personajes suenan al mismo actor.
		var sube: float = 0.30 * dramatismo
		var cae: float = 0.34 * dramatismo
		var f0: float = f0_pico * (1.0 - sube + sube * (1.0 - exp(-p * 14.0)) - cae * p * p)
		f0 *= 1.0 + sin(TAU * 5.2 * t) * (0.016 * dramatismo)
		# JITTER Y SHIMMER: las dos imperfecciones que separan una voz de un oscilador.
		#
		# Ninguna garganta repite dos ciclos iguales: el periodo varia cerca del 0.6% y la
		# amplitud otro tanto. Es poquisimo y es decisivo — un tono perfectamente periodico
		# se oye como una maquina por mas que los formantes esten impecables. Se sortean
		# una vez POR CICLO, porque es una variacion de ciclo a ciclo; sorteada por muestra
		# seria ruido encima de la voz, no una voz temblando.
		var ciclo: int = int(fase)
		if ciclo != ciclo_previo:
			ciclo_previo = ciclo
			jitter = 1.0 + _ruido() * 0.006
			shimmer = 1.0 + _ruido() * 0.045
		fase += f0 * jitter / float(MIX_RATE)
		var pulso: float = _parabola(fase) * 0.85 * shimmer
		# RASGADO: un subarmonico a la mitad del tono.
		#
		# Es lo que hace una garganta forzada —los ciclos dejan de ser todos iguales y
		# aparece una periodicidad al doble— y es el ingrediente de un grito amenazante.
		# Sin esto, gritar fuerte solo suena mas alto, nunca mas peligroso.
		if rasgado > 0.0:
			pulso *= 1.0 - rasgado * 0.5 * (1.0 + sin(PI * fase))
		fuente[i] = pulso * env[i]
		# El aire va aparte porque hay que filtrarlo distinto (ver abajo).
		soplido[i] = _ruido() * aspereza * env[i]
		silbido[i] = _ruido() * ruidoso[i] * 0.85 * env[i]

	# PREENFASIS PARA LOS FORMANTES DE ARRIBA, y sin esto no se entiende una palabra.
	#
	# Un diente de sierra pierde 6 dB por octava: el armonico numero diez ya viene diez
	# veces mas debil que el primero. F1 vive abajo y sale fuerte, pero F2 y F3 viven
	# arriba y quedan enterrados —medido: las seis palabras daban F2 entre 600 y 800 Hz
	# SIN IMPORTAR la vocal, o sea que la "i" y la "u" salian identicas—.
	#
	# Y F2 es justamente el formante que distingue las vocales entre si. F1 dice cuan
	# abierta esta la boca; F2 dice si la lengua esta adelante o atras, que es lo que
	# separa "i" de "u". Con F2 aplastado no hay palabras, hay un quejido con ritmo.
	#
	# EL AIRE DE LA VOZ TAMBIEN SE INCLINA, y esto era lo que arruinaba todo lo demas.
	#
	# El soplido estaba como ruido blanco, o sea PLANO. Con una fuente que cae 12 dB por
	# octava, arriba de los 2 kHz el ruido ya es mas fuerte que la voz y se queda con todo
	# el agudo: medido, la pendiente total no bajaba de -3 dB/octava por mas que se
	# arreglara la fuente, porque no la mandaba la fuente sino el ruido.
	#
	# Un soplido de verdad tampoco es plano —sale de la glotis y lo filtra la misma
	# garganta— asi que cortarlo arriba no es un truco, es lo que falta.
	#
	# El silbido de las consonantes NO se toca: una "s" o una "j" SON ruido agudo, y
	# filtrarlas las convertiria en soplidos sordos.
	_pasabajos(soplido, 2200.0)
	for i: int in range(n_total):
		fuente[i] += soplido[i] + silbido[i]

	# La derivada de primer orden sube 6 dB por octava y cancela exactamente la caida.
	# Es ademas lo que fisicamente hace una boca: los labios radian la derivada del flujo
	# de aire, no el flujo.
	#
	# Y LOS TRES FORMANTES TIENEN QUE LEER DE ACA, no solo los de arriba.
	#
	# Estuvo un rato con F1 leyendo la fuente cruda y F2/F3 la preenfatizada, que parecia
	# lo razonable —subir solo lo que hace falta— y no servia de nada: el preenfasis no da
	# una ventaja absoluta sino RELATIVA dentro de la misma señal, asi que si F1 lee otra
	# copia el balance entre ellos no cambia. Peor: a 2650 Hz el filtro vale 0.51, o sea
	# que F2 perdia 6 dB en vez de ganar. Medido, F2 quedaba 31 dB debajo de F1 cuando en
	# una voz de verdad son 10 o 20.
	var brillo := _vacio(dur)
	var previo_x := 0.0
	for i: int in range(n_total):
		brillo[i] = fuente[i] - previo_x * 0.97
		previo_x = fuente[i]

	var out := _vacio(dur)
	# Amplitudes de formante de manual: F1 manda, F2 algo mas de la mitad, F3 un cuarto.
	# Ahora que los tres estan normalizados en el pico, estos numeros significan eso.
	# LOS ANCHOS DE BANDA, que son lo que decide si dos vocales se confunden.
	#
	# El ancho de un resonador de dos polos es (1-r)·frecuencia_de_muestreo/pi. Con r=0.976
	# eso da 244 Hz, y el F2 de la "a" y el de la "o" estan a 242 Hz uno del otro: los dos
	# picos se solapaban casi por completo y el oido no tenia con que separarlos. Medido,
	# cuatro "a" se reconocian como "o".
	#
	# Una garganta de verdad tiene F1 de unos 70 Hz de ancho y F2 de unos 120. Estos son
	# esos: no es afinar a ojo, es dejar de tener formantes tres veces mas anchos que los
	# de una persona.
	_resonar_movil(out, brillo, p1, 0.9932, 1.0)
	_resonar_movil(out, brillo, p2, 0.9882, 0.62)
	# El brillo: cuanta energia hay arriba. Una voz juvenil y declamada tiene los formantes
	# altos presentes; una voz de pecho, oscura y amenazante, los tiene apagados.
	_resonar_movil(out, brillo, p3, 0.9820, 0.26 * brillo_alto)
	# Saturacion suave y no fuerte: el tanh distorsiona F1 —que es el mas potente— y esos
	# armonicos nuevos caen justo encima de F2. Apretar de mas vuelve a tapar lo que el
	# preenfasis acaba de destapar.
	# INCLINACION ESPECTRAL: la otra mitad de "esta es otra persona".
	#
	# Subir la ganancia de F3 no alcanza —es un formante, mueve poco el balance general—
	# y medido dejaba a los dos personajes con el centroide a un 19% de distancia, que es
	# menos de lo que separa a dos grabaciones de la misma persona en dos dias distintos.
	#
	# Esto inclina el espectro ENTERO: una voz juvenil y declamada tiene presencia arriba,
	# una voz de pecho amenazante la tiene apagada. Es lo que uno oye primero, antes que
	# ningun formante.
	#
	# PERO CON LA MANO MUCHO MAS LIVIANA QUE AL PRINCIPIO. Estuvo al doble de esto, y a esa
	# altura no separaba personajes: los rompia. Le devolvia al agudo todo lo que la fuente
	# glotica acababa de sacarle, y la voz volvia a quedar en -3 dB/octava, o sea chillona.
	# La diferencia entre los dos personajes la tienen que hacer el tono y el tamaño de la
	# garganta, que son fisicos; esto es un retoque, no el mecanismo.
	if not is_equal_approx(brillo_alto, 1.0):
		var lado := out.duplicate()
		if brillo_alto > 1.0:
			_pasaaltos(lado, 1700.0)
			for i: int in range(out.size()):
				out[i] += lado[i] * (brillo_alto - 1.0) * 0.7
		else:
			_pasabajos(lado, 1700.0)
			for i: int in range(out.size()):
				out[i] = lerpf(out[i], lado[i], (1.0 - brillo_alto) * 0.7)

	_saturar(out, 1.45)
	_normalizar(out, 0.85)
	_bordes(out, 2.0, 30.0)
	return out


# --- FLOWERY ---
#
# ERA AGUDO Y CHICO, Y ESTA MAL. Lo hice con la garganta corta —formantes estirados un
# 16%— dando por sentado que "Flowery" era una florcita. No lo es: en Deltarune es un
# humanoide RUBIO Y ALTO, adulto, que hace poses dramaticas y esta dibujado en estilo
# anime. Una garganta corta es justo lo contrario de lo que corresponde.
#
# Y no es un personaje de blips: es el unico de Deltarune con lineas de voz actuadas
# mientras habla. O sea que hay una voz de verdad que imitar, y es la de un fanfarron
# teatral que anuncia sus golpes con nombres de ataque de anime inventados.
#
# De ahi salen sus cuatro numeros: garganta de adulto normal (1.00), tono de varon joven
# y no de criatura (165 Hz), mucho dramatismo —el tono se dispara y se desploma, que es
# como se declama un nombre de ataque— y brillo alto. Sin rasgado: no amenaza, presume.
const F_TONO: float = 165.0
const F_CUERPO: float = 1.00
const F_DRAMA: float = 1.45
const F_BRILLO: float = 1.40


## "¡JARONA!" — ja-ro-na. Su grito, el que suelta antes de cada embestida.
func _synth_voz_jarona() -> PackedFloat32Array:
	return _voz([["a", 0.17, "aire"], ["o", 0.15, ""], ["a", 0.26, "nasal"]],
		F_TONO, F_CUERPO, 0.10, F_DRAMA, F_BRILLO)


## "¡HERE I COME, SAN FRANCISCO!" — he-re-i-come-san-fran-cis-co.
##
## La frase entera, que es el nombre completo del ataque. Ocho silabas se dicen rapido o
## no entran: el ataque dura lo que dura y un anuncio que termina despues del golpe deja
## de ser un aviso.
func _synth_voz_here_i_come() -> PackedFloat32Array:
	return _voz([
		["i", 0.13, "aire"], ["a", 0.09, ""], ["i", 0.07, ""], ["a", 0.15, "golpe"],
		["a", 0.14, "aire"], ["a", 0.12, "aire"], ["i", 0.09, "aire"], ["o", 0.24, "golpe"],
	], F_TONO + 6.0, F_CUERPO, 0.10, F_DRAMA, F_BRILLO)


## "¡LAST JARONA!" — el mismo tipo, forzando la voz.
##
## No es otro personaje: es EL MISMO mas abajo y con las cuerdas raspando, que es lo que
## le pasa a una garganta que grita al limite. Cambiarle el cuerpo lo volveria otro.
func _synth_voz_last_jarona() -> PackedFloat32Array:
	return _voz([["a", 0.20, ""], ["a", 0.15, "aire"], ["o", 0.15, ""],
		["a", 0.34, "nasal"]], F_TONO - 18.0, F_CUERPO - 0.02, 0.17, F_DRAMA + 0.2,
		F_BRILLO - 0.15, 0.22)


# --- DIO ---
#
# Lo contrario de Flowery en las cuatro cosas: mas grave, mas cuerpo, contenido en vez de
# declamado, y oscuro en vez de brillante. Un hombre grande que no necesita gritar para
# que le tengan miedo.
#
# El rasgado es lo que lo vuelve amenazante y no solamente fuerte: un subarmonico a la
# mitad del tono, que es lo que hace una garganta forzada de verdad.
const D_TONO: float = 108.0
const D_CUERPO: float = 0.95
const D_DRAMA: float = 0.65
const D_BRILLO: float = 0.78
const D_RASGADO: float = 0.38


## "¡MUDA MUDA MUDA!" — mu-da, tres veces, rapido y encima del golpe.
func _synth_voz_muda() -> PackedFloat32Array:
	var silabas: Array = []
	for _i: int in range(3):
		silabas.append(["u", 0.12, "nasal"])
		silabas.append(["a", 0.14, "suave"])
	return _voz(silabas, D_TONO + 8.0, D_CUERPO, 0.16, D_DRAMA, D_BRILLO, D_RASGADO)


## "¡ZA WARUDO!" — za-wa-ru-do. Lento y abierto: es el anuncio, no el golpe.
func _synth_voz_za_warudo() -> PackedFloat32Array:
	return _voz([["a", 0.20, "golpe"], ["a", 0.15, ""], ["u", 0.13, ""],
		["o", 0.32, "golpe"]], D_TONO, D_CUERPO, 0.14, D_DRAMA, D_BRILLO, D_RASGADO)


## "¡TOKI YO TOMARE!" — to-ki-yo-to-ma-re. La orden, no el nombre.
##
## Mas rapida y mas plana que ZA WARUDO a proposito: la primera es el anuncio y esta es
## la orden que lo ejecuta. Si las dos se dijeran igual, la segunda sonaria a eco.
func _synth_voz_toki() -> PackedFloat32Array:
	return _voz([["o", 0.12, "golpe"], ["i", 0.12, "golpe"], ["o", 0.14, ""],
		["o", 0.12, "golpe"], ["a", 0.15, "nasal"], ["e", 0.26, ""]],
		D_TONO - 6.0, D_CUERPO, 0.13, D_DRAMA - 0.15, D_BRILLO, D_RASGADO + 0.06)


# --- GOKU ---
#
# Un tipo joven con la voz arriba y abierta: ni la garganta grande de Dio ni el declamado
# de Flowery. Cuando grita, grita con todo el cuerpo, y por eso el "¡HA!" lleva rasgado:
# es la garganta al limite, soltando algo que venia aguantando.
const G_TONO: float = 158.0
const G_CUERPO: float = 0.98
const G_DRAMA: float = 1.25
const G_BRILLO: float = 1.15


## "KA... ME... HA... ME..." — la carga. Lento y separado, una silaba por tramo: es el
## reloj del ataque, y el que lo escucha tiene que poder contar cuanto falta.
func _synth_voz_kamehameha() -> PackedFloat32Array:
	return _voz([["a", 0.22, "golpe"], ["e", 0.22, "nasal"], ["a", 0.24, "aire"],
		["e", 0.30, "nasal"]], G_TONO - 10.0, G_CUERPO, 0.11, G_DRAMA - 0.2, G_BRILLO)


## "¡HAAA!" — el disparo. Una sola vocal larga, mas aguda y raspando.
func _synth_voz_ha() -> PackedFloat32Array:
	return _voz([["a", 0.55, "aire"]], G_TONO + 22.0, G_CUERPO, 0.16, G_DRAMA + 0.3,
		G_BRILLO, 0.26)


# --- MARIO ---
#
# La voz mas aguda y la mas contenta del juego: un tipo bajito que salta gritando de
# alegria. Mucho brillo y nada de rasgado: Mario no grita de esfuerzo, grita de ganas.
const M_TONO: float = 212.0
const M_CUERPO: float = 1.06
const M_DRAMA: float = 1.5
const M_BRILLO: float = 1.35


## "¡WAHOO!" — ua-ju. El del salto: sube en el "ua" y se estira en el "ju".
func _synth_voz_wahoo() -> PackedFloat32Array:
	return _voz([["u", 0.08, "suave"], ["a", 0.16, ""], ["u", 0.28, "aire"]],
		M_TONO, M_CUERPO, 0.08, M_DRAMA, M_BRILLO)


## "¡LET'S-A GO!" — le-tsa-go. El de la estrella, con la "a" de mas que le pone siempre.
func _synth_voz_lets_go() -> PackedFloat32Array:
	return _voz([["e", 0.12, "golpe"], ["a", 0.13, "aire"], ["o", 0.32, "golpe"]],
		M_TONO - 8.0, M_CUERPO, 0.09, M_DRAMA - 0.1, M_BRILLO)


## La bola de fuego: un "piu" de onda cuadrada que cae, y un chisporroteo.
##
## Onda cuadrada porque es el sonido de Mario desde 1985: todo lo suyo es chiptune, y una
## bola de fuego con un soplido realista sonaria a otro juego.
func _synth_fuego() -> PackedFloat32Array:
	var dur := 0.16
	var out := _vacio(dur)
	var n := out.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		fase += lerpf(980.0, 260.0, sqrt(p)) / float(MIX_RATE)
		var env: float = exp(-p * 4.5)
		out[i] = _pulso(fase, 0.5) * 0.40 * env + _ruido() * 0.18 * exp(-t * 60.0)
	_pasaaltos(out, 200.0)
	_normalizar(out, 0.62)
	_bordes(out, 0.3, 8.0)
	return out


## La Superestrella: un arpegio que sube, con brillo de campana.
##
## NO ES LA MUSICA DE LA ESTRELLA, a proposito: esa melodia es de Nintendo y no se copia.
## Es un acorde mayor subiendo rapido, que se lee como "algo bueno acaba de pasar" en
## cualquier juego, con el timbre cuadrado del resto de Mario.
func _synth_estrella() -> PackedFloat32Array:
	var dur := 0.7
	var out := _vacio(dur)
	var n := out.size()
	var notas: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.5]
	var paso := 0.07
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var k := mini(int(t / paso), notas.size() - 1)
		var f: float = notas[k]
		fase += f / float(MIX_RATE)
		var local := t - float(k) * paso
		var env: float = exp(-local * 9.0) * (1.0 if k < notas.size() - 1 else exp(-(t - float(k) * paso) * 3.0))
		out[i] = _pulso(fase, 0.25) * 0.28 * env + _campana(t, f * 2.0, 1.41, 1.2) * 0.16 * env
	_normalizar(out, 0.6)
	_bordes(out, 0.3, 30.0)
	return out


# ------------------------------------------------------------------- Deltarune
#
# El mundo de Noelle y Flowery. Los efectos de Deltarune son limpios y sinteticos: ondas
# de pulso para lo chico y campanas para la magia. Casi nada de ruido.

## Petalos: tres blips de onda de pulso, subiendo de tono.
##
## Pulso y no seno a proposito: ese timbre nasal y estrecho es el sonido de Deltarune
## para todo lo chico, y con tres notas subiendo se lee como una rafaga y no como un
## golpe repetido.
func _synth_petals() -> PackedFloat32Array:
	var out := _vacio(0.26)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var v := 0.0
		for k: int in range(3):
			var dt := t - float(k) * 0.05
			if dt < 0.0 or dt > 0.09:
				continue
			var f := 880.0 * pow(1.18, float(k))
			var env: float = exp(-dt * 34.0)
			v += _pulso(f * dt, 0.28) * 0.5 * env
			# Un armonico arriba le da el brillo que tiene el original.
			v += sin(TAU * f * 2.0 * dt) * 0.12 * env
		out[i] = v
	_pasabajos(out, 7000.0)
	_normalizar(out, 0.55)
	_bordes(out, 1.0, 8.0)
	return out


## Golpe de hielo: cristal que se parte.
##
## Dos campanas inarmonicas encima de un chasquido de ruido muy corto. Lo inarmonico es
## lo que hace que suene a cristal; con armonicos enteros sonaria a xilofon.
func _synth_ice_hit() -> PackedFloat32Array:
	var out := _vacio(0.34)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var golpe: float = exp(-t * 90.0)
		var cola: float = exp(-t * 13.0)
		var v := _ruido() * 0.55 * golpe
		v += _campana(t, 1870.0, 2.41, 3.0 * cola) * 0.34 * cola
		v += _campana(t, 3140.0, 1.73, 2.0 * cola) * 0.18 * cola
		out[i] = v
	_pasaaltos(out, 500.0)
	_normalizar(out, 0.72)
	_bordes(out, 0.4, 10.0)
	return out


## Ice Shock: el proyectil. Barrido cristalino hacia arriba, con brillo encima.
func _synth_ice_shock() -> PackedFloat32Array:
	var out := _vacio(0.45)
	var n := out.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / 0.45
		var f: float = lerpf(620.0, 2350.0, p * p)
		fase += f / float(MIX_RATE)
		var env: float = minf(1.0, t * 90.0) * exp(-p * 3.6)
		var v := _pulso(fase, 0.42) * 0.42 * env
		v += _campana(t, f * 1.5, 2.1, 1.4) * 0.22 * env
		# Escarcha: ruido agudo y finito que acompaña el barrido.
		v += _ruido() * 0.16 * env * p
		out[i] = v
	_pasaaltos(out, 350.0)
	_normalizar(out, 0.7)
	_bordes(out, 1.0, 14.0)
	return out


## Congelacion: la campana que suena cuando algo queda hecho hielo.
func _synth_freeze() -> PackedFloat32Array:
	var out := _vacio(0.9)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env: float = exp(-t * 3.6)
		var v := _campana(t, 1174.7, 3.47, 4.2 * env) * 0.45
		v += _campana(t, 1760.0, 2.13, 2.6 * env) * 0.26
		v += sin(TAU * 2637.0 * t) * 0.10
		out[i] = v * env
	_normalizar(out, 0.6)
	_bordes(out, 2.0, 40.0)
	return out


## SNOWGRAVE: el sonido mas grande del juego, y el mas frio.
##
## Tres capas: una campana enorme que cae, un viento que crece por debajo y un sub que
## aparece al final. Lo que lo vuelve siniestro no es el volumen sino que la campana
## BAJE de tono mientras el viento SUBE: dos cosas yendo en direcciones contrarias
## suenan mal a proposito.
func _synth_snowgrave() -> PackedFloat32Array:
	var dur := 1.6
	var out := _vacio(dur)
	var viento := _vacio(dur)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		var env: float = minf(1.0, t * 12.0) * exp(-p * 2.3)
		var f: float = lerpf(1560.0, 240.0, sqrt(p))
		var v := _campana(t, f, 2.76, 5.0 * (1.0 - p)) * 0.5
		v += _campana(t, f * 2.02, 1.41, 2.0) * 0.16
		# El sub entra tarde: es el peso del hechizo cerrando.
		v += sin(TAU * lerpf(90.0, 42.0, p) * t) * 0.45 * smoothstep(0.25, 0.8, p) * exp(-p * 1.6)
		out[i] = v * env
		viento[i] = _ruido() * (0.10 + 0.30 * p) * env
	_pasabajos(viento, 2600.0)
	for i: int in range(n):
		out[i] += viento[i]
	_saturar(out, 1.4)
	_normalizar(out, 0.92)
	_bordes(out, 3.0, 60.0)
	return out


## LAST JARONA: el mismo grito una octava abajo, mas largo y con el mundo cayendose.
##
## Mismos formantes pero corridos hacia abajo: una garganta mas grande. Y debajo, un sub
## que entra tarde, que es lo que lo separa de "Jarona pero mas fuerte".
func _synth_last_jarona() -> PackedFloat32Array:
	# YA NO ES UNA VOZ, es lo que pasa DEBAJO de la voz.
	#
	# Era un grito de formantes una octava abajo, y ahora que el personaje dice "LAST
	# JARONA" de verdad los dos se pisaban: dos gargantas distintas diciendo cosas
	# distintas al mismo tiempo. Lo que hacia falta de este sonido no era la voz sino el
	# peso, asi que queda el peso.
	var dur := 1.5
	var out := _vacio(dur)
	var n := out.size()
	var barrido := _vacio(dur)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		# El sub que cae: es el suelo yendose.
		out[i] = sin(TAU * lerpf(78.0, 30.0, p) * t) * 0.85 * smoothstep(0.0, 0.12, p) * exp(-p * 1.8)
		# Segundo grave apenas desafinado: el batido entre los dos es lo que hace que no
		# suene a una nota sino a una masa.
		out[i] += sin(TAU * lerpf(83.0, 32.5, p) * t) * 0.45 * smoothstep(0.02, 0.2, p) * exp(-p * 1.7)
		barrido[i] = _ruido() * pow(1.0 - p, 1.4) * 0.5
	_pasabajos(barrido, 700.0)
	for i: int in range(n):
		out[i] += barrido[i]
	_saturar(out, 2.4)
	_normalizar(out, 0.95)
	_bordes(out, 3.0, 50.0)
	return out


# ------------------------------------------------------------------------ JoJo
#
# El mundo de Dio. Aca todo es peso e impacto: golpes con cuerpo, metal con filo, y un
# tiempo detenido que se siente en el pecho.

## MUDA: el puñetazo del Stand.
##
## TRES CAPAS, que es como se arma cualquier impacto que se sienta:
##   1. el CUERPO, un seno grave cuya frecuencia se desploma  -> el peso
##   2. el CHASQUIDO, ruido de banda media muy corto          -> el contacto
##   3. la PALMADA, un transitorio agudo de dos milisegundos  -> el filo
##
## Antes era solo la capa 1 y por eso sonaba a bombo de goma: tenia el peso y le faltaba
## el momento exacto del golpe.
func _synth_punch() -> PackedFloat32Array:
	var out := _vacio(0.2)
	var chasquido := _vacio(0.2)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var cuerpo: float = exp(-t * 26.0)
		var f: float = lerpf(190.0, 52.0, minf(1.0, t * 26.0))
		out[i] = sin(TAU * f * t) * 0.9 * cuerpo
		chasquido[i] = _ruido() * exp(-t * 120.0)
	_pasabajos(chasquido, 2200.0)
	_pasaaltos(chasquido, 300.0)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		out[i] += chasquido[i] * 0.85
		# La palmada: brevisima, pero es lo que hace que el golpe "suene cerca".
		out[i] += _ruido() * 0.35 * exp(-t * 420.0)
	# --- Y UNA CAPA VOCAL DEBAJO ---
	#
	# En el original lo que se oye no es solo el golpe: es DIO GRITANDO encima de cada
	# uno. Una voz no se puede sintetizar sin que suene a robot, pero SI se puede poner
	# el gesto: un diente de sierra grave pasado por los formantes de una "U" —que es la
	# vocal de MUDA— durante las mismas dos decimas que dura el impacto. No se oye como
	# una palabra; se oye como que alguien esta ahi.
	var fuente := _vacio(0.2)
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / 0.2
		fase += (128.0 - 26.0 * p) / float(MIX_RATE)
		fuente[i] = _sierra(fase) * exp(-p * 5.5) * minf(1.0, p * 12.0)
	var voz := _vacio(0.2)
	# Formantes de una "U" cerrada: F1 bajo y F2 bajo tambien, muy juntos.
	_resonar(voz, fuente, 320.0, 0.982, 1.0)
	_resonar(voz, fuente, 800.0, 0.972, 0.42)
	_resonar(voz, fuente, 2240.0, 0.960, 0.12)
	for i: int in range(n):
		out[i] += voz[i] * 0.55

	_saturar(out, 2.6)
	_normalizar(out, 0.9)
	_bordes(out, 0.3, 12.0)
	return out


## Cuchillo: el zing del acero.
##
## Parciales inarmonicos altos (una barra de metal no vibra en armonicos enteros) mas un
## siseo de aire que lo precede: primero corta el aire, despues suena el filo.
func _synth_knife() -> PackedFloat32Array:
	var out := _vacio(0.26)
	var aire := _vacio(0.26)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env: float = exp(-t * 16.0)
		var f: float = lerpf(3100.0, 1750.0, minf(1.0, t * 7.0))
		var v := sin(TAU * f * t) * 0.45
		v += sin(TAU * f * 1.47 * t) * 0.3
		v += sin(TAU * f * 2.09 * t) * 0.16
		out[i] = v * env
		aire[i] = _ruido() * exp(-t * 28.0)
	_pasaaltos(aire, 3500.0)
	for i: int in range(n):
		out[i] += aire[i] * 0.4
	_normalizar(out, 0.75)
	_bordes(out, 0.5, 14.0)
	return out


## ZA WARUDO: el tiempo se detiene.
##
## LA FORMA ES AL REVES QUE TODO LO DEMAS, y ahi esta el truco. Los sonidos empiezan
## fuerte y se apagan; este CRECE —un barrido de ruido que se abre durante medio
## segundo—, revienta en un golpe grave, y despues deja un drone que no termina de irse.
## Esa inversion es la que el oido lee como "algo se paro".
func _synth_za_warudo() -> PackedFloat32Array:
	var dur := 1.9
	var out := _vacio(dur)
	var subida := _vacio(dur)
	var n := out.size()
	var golpe_en := 0.55
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		if t < golpe_en:
			# El swell al reves: algo que se acerca y se abre.
			var p := t / golpe_en
			# Ruido MAS UN TONO QUE SUBE. Solo con ruido quedaba un "chsss" de aerosol
			# —medido: 2562 cruces por cero por segundo, mas brillante que un cuchillo—
			# y esto tiene que sonar a algo grande acercandose, no a aire escapando.
			# El tono grave subiendo es lo que le da la masa.
			subida[i] = _ruido() * pow(p, 2.4) * 0.55
			subida[i] += sin(TAU * lerpf(34.0, 96.0, p * p) * t) * pow(p, 1.6) * 0.8
		else:
			var dt := t - golpe_en
			var boom: float = exp(-dt * 2.6)
			var bf: float = lerpf(150.0, 36.0, minf(1.0, dt * 2.4))
			var v := sin(TAU * bf * t) * 0.95 * boom
			# El drone: dos graves batiendo entre si, apenas desafinados. El batido es
			# lo que hace que el silencio despues no se sienta vacio sino suspendido.
			var drone: float = minf(1.0, dt * 3.0) * exp(-dt * 0.85)
			v += (sin(TAU * 55.0 * t) * 0.34 + sin(TAU * 82.6 * t) * 0.2) * drone
			out[i] = v
	# Corte bajo: lo que queda es un retumbe, no un siseo.
	_pasabajos(subida, 900.0)
	for i: int in range(n):
		out[i] += subida[i]
	_saturar(out, 1.8)
	_normalizar(out, 0.95)
	_bordes(out, 4.0, 90.0)
	return out


# --------------------------------------------------------- Rick and Morty
#
# El mundo de Rick. Todo lo suyo es un APARATO: sintetico, electrico y un poco
# desafinado, porque lo armo en el garage.

## Disparo de plasma: barrido de tono hacia abajo, muy corto.
##
## Hacia ABAJO y no hacia arriba, que es lo que uno escribiria primero. Un barrido
## ascendente se oye como algo que se carga; uno descendente, como algo que ya salio
## disparado. La diferencia entre un arma y un cargador es la direccion del barrido.
func _synth_plasma() -> PackedFloat32Array:
	var out := _vacio(0.22)
	var n := out.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / 0.22
		var f: float = lerpf(1750.0, 380.0, sqrt(p))
		fase += f / float(MIX_RATE)
		var env: float = exp(-p * 7.0)
		var v := _pulso(fase, 0.24) * 0.45 * env
		v += _campana(t, f * 1.7, 1.9, 1.6) * 0.18 * env
		# Chispazo del disparo, solo en los primeros milisegundos.
		v += _ruido() * 0.30 * exp(-t * 180.0)
		out[i] = v
	_pasaaltos(out, 260.0)
	_saturar(out, 1.7)
	_normalizar(out, 0.68)
	_bordes(out, 0.4, 12.0)
	return out


## Explosion de la granada: el mismo timbre electrico del disparo, pero reventando.
func _synth_plasma_blast() -> PackedFloat32Array:
	var out := _vacio(0.8)
	var cuerpo := _vacio(0.8)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / 0.8
		var golpe: float = exp(-t * 9.0)
		# Sub que cae: es el peso, y lo que la separa de un chisporroteo.
		out[i] = sin(TAU * lerpf(150.0, 40.0, minf(1.0, t * 9.0)) * t) * 0.85 * golpe
		# Y el zumbido electrico encima, que es lo que la hace de plasma y no de polvora.
		out[i] += _pulso(lerpf(420.0, 90.0, p) * t, 0.35) * 0.30 * exp(-p * 5.0)
		cuerpo[i] = _ruido() * exp(-t * 11.0)
	_pasabajos(cuerpo, 2400.0)
	for i: int in range(n):
		out[i] += cuerpo[i] * 0.55
	_saturar(out, 2.2)
	_normalizar(out, 0.92)
	_bordes(out, 0.5, 40.0)
	return out


## El portal: barrido ascendente con un batido adentro.
##
## El batido —dos tonos casi al unisono peleandose— es lo que le da esa sensacion de
## cosa inestable. Un barrido limpio sonaria a puerta de nave espacial; este tiene que
## sonar a agujero abierto a la fuerza.
func _synth_portal() -> PackedFloat32Array:
	var dur := 0.7
	var out := _vacio(dur)
	var n := out.size()
	var f1 := 0.0
	var f2 := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		# EL BAMBOLEO. El portal del original no es un barrido limpio: tiene un vaiven
		# rapido encima que lo hace sonar a algo liquido e inestable. Un barrido derecho
		# suena a puerta de nave espacial; esto tiene que sonar a agujero abierto a la
		# fuerza en el aire.
		var vaiven: float = 1.0 + sin(TAU * 13.0 * t) * 0.09 * (1.0 - p * 0.5)
		var base: float = lerpf(210.0, 1150.0, p * p) * vaiven
		f1 += base / float(MIX_RATE)
		f2 += base * 1.031 / float(MIX_RATE)
		var env: float = minf(1.0, p * 9.0) * exp(-p * 2.4)
		var v := (_sierra(f1) + _sierra(f2)) * 0.26 * env
		v += _campana(t, base * 2.0, 1.48, 2.2) * 0.18 * env
		# Chisporroteo del borde del portal.
		v += _ruido() * 0.13 * env * p
		out[i] = v
	_pasabajos(out, 7000.0)
	_pasaaltos(out, 180.0)
	_saturar(out, 1.6)
	_normalizar(out, 0.78)
	_bordes(out, 2.0, 30.0)
	return out


## "I'M MISTER MEESEEKS": tres notas subiendo, con vibrato ancho.
##
## No es una voz —no hay forma de hacer una frase por sintesis sin que suene a robot—
## pero si el GESTO de una: el vibrato exagerado y las tres notas para arriba son lo que
## el oido lee como alguien hablando entusiasmado.
func _synth_meeseeks() -> PackedFloat32Array:
	var dur := 0.65
	var out := _vacio(dur)
	var n := out.size()
	var notas: Array[float] = [392.0, 523.25, 659.25]
	var paso := 0.17
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var k: int = mini(notas.size() - 1, int(t / paso))
		var dt := t - float(k) * paso
		var f: float = notas[k] * (1.0 + sin(TAU * 7.5 * t) * 0.035)
		fase += f / float(MIX_RATE)
		var env: float = minf(1.0, dt * 40.0) * exp(-dt * 5.0) * exp(-t * 1.2)
		out[i] = (_pulso(fase, 0.36) * 0.42 + sin(TAU * f * 2.0 * t) * 0.14) * env
	_pasabajos(out, 5200.0)
	_normalizar(out, 0.62)
	_bordes(out, 1.0, 25.0)
	return out


# ------------------------------------------------------------- Cuerpo y suelo
#
# Los tres sonidos que faltaban, y que son los que mas suenan en toda la partida: cada
# paso, cada salto y cada caida. Sin ellos el personaje se desliza en silencio y el
# mundo se siente de cartón, por muy bien que suenen las habilidades.

## Un paso. Sordo, muy corto y sin tono definido.
##
## LO IMPORTANTE ES QUE SEA DISCRETO. Un paso suena unas dos veces por segundo mientras
## caminas: cualquier cosa con tono se vuelve insoportable a los treinta segundos. Ruido
## filtrado bien abajo y una envolvente de cuarenta milisegundos.
func _synth_paso() -> PackedFloat32Array:
	var out := _vacio(0.13)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		out[i] = _ruido() * exp(-t * 46.0)
	_pasabajos(out, 900.0)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		# Un golpe grave debajo: es lo que lo hace un pie y no un siseo.
		out[i] += sin(TAU * lerpf(120.0, 58.0, minf(1.0, t * 30.0)) * t) * 0.5 * exp(-t * 38.0)
	_normalizar(out, 0.30)
	_bordes(out, 0.3, 10.0)
	return out


## Salto: aire que sube. Barrido corto hacia arriba, muy suave.
func _synth_salto() -> PackedFloat32Array:
	var out := _vacio(0.22)
	var n := out.size()
	for i: int in range(n):
		out[i] = _ruido()
	_pasabajos(out, 1900.0)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / 0.22
		# El ruido sube de volumen y ademas se abre el filtro: las dos cosas juntas son
		# lo que el oido lee como "hacia arriba".
		out[i] *= (0.25 + 0.75 * p) * exp(-p * 2.2) * 0.8
		out[i] += sin(TAU * lerpf(210.0, 430.0, p) * t) * 0.22 * exp(-p * 3.5)
	_normalizar(out, 0.34)
	_bordes(out, 1.0, 16.0)
	return out


## Aterrizaje: el golpe contra el piso. Es el paso, pero con el doble de cuerpo.
func _synth_aterrizaje() -> PackedFloat32Array:
	var out := _vacio(0.3)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		out[i] = sin(TAU * lerpf(150.0, 44.0, minf(1.0, t * 22.0)) * t) * 0.9 * exp(-t * 15.0)
		# La raspada de las suelas, encima y muy corta.
		out[i] += _ruido() * 0.45 * exp(-t * 32.0)
	_pasabajos(out, 2600.0)
	_saturar(out, 1.8)
	_normalizar(out, 0.55)
	_bordes(out, 0.3, 24.0)
	return out


# --------------------------------------------------------------------- Comunes

## Dash: aire cortado. Ruido pasabajos con la envolvente en forma de campana.
func _synth_dash() -> PackedFloat32Array:
	var out := _vacio(0.26)
	var n := out.size()
	for i: int in range(n):
		out[i] = _ruido()
	_pasabajos(out, 1500.0)
	_pasaaltos(out, 260.0)
	for i: int in range(n):
		var p := float(i) / float(n)
		# Sube y baja rapido: el sonido pasa al lado tuyo, no se queda.
		out[i] *= sin(PI * p) * (1.0 - p * 0.4)
	_normalizar(out, 0.5)
	_bordes(out, 2.0, 20.0)
	return out


## Muerte: caida cromatica en onda de pulso. El "perdiste" de un juego de 8 bits.
func _synth_death() -> PackedFloat32Array:
	var out := _vacio(0.85)
	var n := out.size()
	var notas: Array[float] = [523.25, 415.30, 329.63, 246.94]
	var paso := 0.16
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var k: int = mini(notas.size() - 1, int(t / paso))
		var dt := t - float(k) * paso
		var f: float = notas[k]
		fase += f / float(MIX_RATE)
		var env: float = exp(-dt * 6.0) * exp(-t * 1.4)
		out[i] = (_pulso(fase, 0.5) * 0.4 + sin(TAU * f * 0.5 * t) * 0.25) * env
	_pasabajos(out, 5000.0)
	_normalizar(out, 0.6)
	_bordes(out, 2.0, 30.0)
	return out


## Canalizando: zumbido que sube. Tiene que dar nervios, no molestar.
func _synth_channel() -> PackedFloat32Array:
	var dur := 1.0
	var out := _vacio(dur)
	var n := out.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		var f: float = lerpf(150.0, 460.0, p * p)
		fase += f / float(MIX_RATE)
		# Tremolo que se acelera: el pulso apurandose es lo que crea la tension.
		var trem: float = 0.72 + 0.28 * sin(TAU * lerpf(5.0, 16.0, p) * t)
		var env: float = minf(1.0, p * 8.0) * minf(1.0, (1.0 - p) * 8.0)
		out[i] = (_sierra(fase) * 0.35 + sin(TAU * f * 2.0 * t) * 0.12) * env * trem
	_pasabajos(out, 3200.0)
	_normalizar(out, 0.45)
	_bordes(out, 5.0, 40.0)
	return out


func _synth_ui_click() -> PackedFloat32Array:
	var out := _vacio(0.08)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		out[i] = _pulso(1200.0 * t, 0.3) * 0.5 * exp(-t * 55.0)
	_pasabajos(out, 6000.0)
	_normalizar(out, 0.4)
	_bordes(out, 0.5, 6.0)
	return out


## "No te alcanza la stamina": grave, feo y corto, a proposito.
func _synth_no_stamina() -> PackedFloat32Array:
	var out := _vacio(0.24)
	var n := out.size()
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env: float = exp(-t * 8.0)
		# Dos pulsos casi al unisono: el batido es lo que lo vuelve desagradable.
		var v := _pulso(138.0 * t, 0.5) * 0.3 + _pulso(146.0 * t, 0.5) * 0.3
		out[i] = v * env
	_pasabajos(out, 1800.0)
	_normalizar(out, 0.4)
	_bordes(out, 1.0, 20.0)
	return out


## Reaparecer: arpegio ascendente. El unico sonido del juego que es una buena noticia.
func _synth_respawn() -> PackedFloat32Array:
	var out := _vacio(0.55)
	var n := out.size()
	var notas: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	var paso := 0.11
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var k: int = mini(notas.size() - 1, int(t / paso))
		var dt := t - float(k) * paso
		var f: float = notas[k]
		var env: float = exp(-dt * 8.0)
		out[i] = (_campana(t, f, 2.0, 1.2 * env) * 0.4 + sin(TAU * f * t) * 0.2) * env
	_normalizar(out, 0.5)
	_bordes(out, 1.0, 30.0)
	return out


# ------------------------------------------------------------------- Conversion

## Convierte samples float [-1, 1] en un AudioStreamWAV de 16 bits mono.
func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, v)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
