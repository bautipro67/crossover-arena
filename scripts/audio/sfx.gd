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


# ------------------------------------------------------------------ Reproduccion

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
	_bank[&"ui_click"] = _make(_synth_ui_click())
	_bank[&"no_stamina"] = _make(_synth_no_stamina())
	_bank[&"respawn"] = _make(_synth_respawn())
	_build_combate.call_deferred()


## Cuantos sonidos tiene que haber cuando el banco esta completo.
const TOTAL_SONIDOS: int = 16

## Termino de armarse el banco? Lo usan los arneses, que arrancan una partida en el
## primer frame y no pueden asumir que los sonidos largos ya existen.
func banco_listo() -> bool:
	return _bank.size() >= TOTAL_SONIDOS


func _build_combate() -> void:
	var arranque := Time.get_ticks_msec()
	var receta: Array = [
		[&"hit_punch", _synth_punch], [&"hit_ice", _synth_ice_hit],
		[&"petals", _synth_petals], [&"knife", _synth_knife],
		[&"dash", _synth_dash], [&"ice_shock", _synth_ice_shock],
		[&"jarona", _synth_jarona], [&"freeze", _synth_freeze],
		[&"death", _synth_death], [&"channel", _synth_channel],
		[&"last_jarona", _synth_last_jarona], [&"snowgrave", _synth_snowgrave],
		[&"za_warudo", _synth_za_warudo],
	]
	# Ordenados de mas corto a mas largo a proposito: los golpes basicos —que son los que
	# se pueden llegar a necesitar antes— quedan listos en los primeros frames.
	for item: Array in receta:
		var generador: Callable = item[1]
		_bank[item[0]] = _make(generador.call())
		if is_inside_tree():
			await get_tree().process_frame
	print("[sfx] banco completo en %d ms (%d sonidos a %d Hz)" % [
		Time.get_ticks_msec() - arranque, _bank.size(), MIX_RATE])


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


## JARONA: el grito de Flowery.
##
## SINTESIS DE FORMANTES, que es la unica forma de que algo suene a voz.
##
## Un grito no es un tono con ruido encima —asi estaba antes y sonaba a alarma de horno—.
## Es una fuente rica —las cuerdas vocales, aca un diente de sierra— pasada por las
## resonancias de una garganta. Poniendo tres resonadores en las frecuencias de formante
## de una "A" (730 / 1090 / 2440 Hz) el diente de sierra se convierte en una vocal, y
## como el tono sube y despues cae, se lee como alguien gritando y no como una nota.
func _synth_jarona() -> PackedFloat32Array:
	var dur := 0.6
	var fuente := _vacio(dur)
	var n := fuente.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		# La curva de un grito: arranca, se dispara y despues se desinfla.
		var f0: float = 190.0 + 210.0 * (1.0 - exp(-p * 11.0)) - 120.0 * p
		# Vibrato: una voz nunca se queda quieta en una frecuencia.
		f0 *= 1.0 + sin(TAU * 5.5 * t) * 0.022
		fase += f0 / float(MIX_RATE)
		var env: float = minf(1.0, p * 16.0) * exp(-p * 2.9)
		# Un poco de aire mezclado con la fuente: es lo aspero de gritar fuerte.
		fuente[i] = (_sierra(fase) * 0.8 + _ruido() * 0.12) * env
	var out := _vacio(dur)
	# Formantes de una "A" abierta.
	_resonar(out, fuente, 730.0, 0.985, 1.0)
	_resonar(out, fuente, 1090.0, 0.975, 0.55)
	_resonar(out, fuente, 2440.0, 0.965, 0.22)
	_saturar(out, 2.2)
	_normalizar(out, 0.85)
	_bordes(out, 2.0, 25.0)
	return out


## LAST JARONA: el mismo grito una octava abajo, mas largo y con el mundo cayendose.
##
## Mismos formantes pero corridos hacia abajo: una garganta mas grande. Y debajo, un sub
## que entra tarde, que es lo que lo separa de "Jarona pero mas fuerte".
func _synth_last_jarona() -> PackedFloat32Array:
	var dur := 1.5
	var fuente := _vacio(dur)
	var n := fuente.size()
	var fase := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		var f0: float = 105.0 + 150.0 * (1.0 - exp(-p * 8.0)) - 70.0 * p
		f0 *= 1.0 + sin(TAU * 4.2 * t) * 0.03
		fase += f0 / float(MIX_RATE)
		var env: float = minf(1.0, p * 9.0) * exp(-p * 1.9)
		fuente[i] = (_sierra(fase) * 0.8 + _ruido() * 0.16) * env
	var out := _vacio(dur)
	_resonar(out, fuente, 590.0, 0.988, 1.0)
	_resonar(out, fuente, 900.0, 0.978, 0.6)
	_resonar(out, fuente, 2100.0, 0.968, 0.25)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var p := t / dur
		out[i] += sin(TAU * lerpf(70.0, 34.0, p) * t) * 0.75 * smoothstep(0.05, 0.4, p) * exp(-p * 2.0)
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
