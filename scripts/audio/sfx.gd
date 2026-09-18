extends Node
## Autoload: Sfx
## Todos los sonidos del juego, SINTETIZADOS POR CODIGO.
##
## No hay ni un archivo de audio en el proyecto: cada efecto se genera como PCM crudo
## al arrancar y se guarda en un AudioStreamWAV en memoria. Suena a chiptune/sintetizado,
## que para un juego de primitivas geometricas queda coherente, y ademas mantiene el
## .zip chico y sin problemas de licencias de samples.
##
## Si algun dia conseguis samples de verdad, reemplazas _build_bank() por precargas y
## el resto del juego no cambia: todos llaman a Sfx.play_3d() / Sfx.play_2d().

const MIX_RATE: int = 22050
## Cuantos reproductores 3D simultaneos como maximo. Evita que una pelea llene el arbol.
const MAX_VOICES: int = 24

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
	_build_bank()
	_ui_player = AudioStreamPlayer.new()
	add_child(_ui_player)
	_apply_volume()


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
	if master_volume <= 0.001:
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


# -------------------------------------------------------------------- El banco

func _build_bank() -> void:
	# --- Combate ---
	_bank[&"hit_ice"] = _make(_synth_ice_hit())
	_bank[&"hit_punch"] = _make(_synth_punch())
	_bank[&"knife"] = _make(_synth_knife())
	_bank[&"ice_shock"] = _make(_synth_ice_shock())
	_bank[&"snowgrave"] = _make(_synth_snowgrave())
	_bank[&"za_warudo"] = _make(_synth_za_warudo())
	_bank[&"freeze"] = _make(_synth_freeze())
	_bank[&"dash"] = _make(_synth_dash())
	_bank[&"death"] = _make(_synth_death())
	_bank[&"channel"] = _make(_synth_channel())
	# --- Interfaz ---
	_bank[&"ui_click"] = _make(_synth_ui_click())
	_bank[&"no_stamina"] = _make(_synth_no_stamina())
	_bank[&"respawn"] = _make(_synth_respawn())


## Golpe de hielo: ruido filtrado con caida rapida y un tono agudo encima.
func _synth_ice_hit() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.28)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 22.0)
		var noise := randf_range(-1.0, 1.0) * 0.5
		var tone := sin(TAU * 1400.0 * t) * 0.35 + sin(TAU * 2300.0 * t) * 0.2
		out[i] = (noise + tone) * env
	return out


## Puñetazo: golpe grave y corto.
func _synth_punch() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.16)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 34.0)
		# La frecuencia cae: eso es lo que da la sensacion de impacto.
		var freq := lerpf(220.0, 70.0, minf(1.0, t * 12.0))
		out[i] = (sin(TAU * freq * t) * 0.8 + randf_range(-1.0, 1.0) * 0.25) * env
	return out


## Cuchillo: zing metalico corto.
func _synth_knife() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.2)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 18.0)
		var freq := lerpf(2600.0, 1500.0, minf(1.0, t * 6.0))
		out[i] = (sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.48 * t) * 0.3) * env
	return out


## Ice Shock: barrido ascendente cristalino.
func _synth_ice_shock() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 7.0)
		var freq := lerpf(500.0, 1900.0, t / 0.4)
		out[i] = (sin(TAU * freq * t) * 0.55 + sin(TAU * freq * 2.0 * t) * 0.2) * env
	return out


## Snowgrave: el sonido mas grande del juego. Barrido descendente + ruido helado.
func _synth_snowgrave() -> PackedFloat32Array:
	var n := int(MIX_RATE * 1.6)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var attack := minf(1.0, t * 14.0)
		var env := attack * exp(-t * 2.1)
		var freq := lerpf(1500.0, 120.0, minf(1.0, t / 1.1))
		var body := sin(TAU * freq * t) * 0.5
		var shimmer := sin(TAU * (freq * 2.5) * t) * 0.18
		var wind := randf_range(-1.0, 1.0) * 0.22 * exp(-t * 1.4)
		out[i] = (body + shimmer + wind) * env
	return out


## ZA WARUDO: impacto grave enorme y despues un drone sostenido, como si el aire
## se hubiera quedado quieto.
func _synth_za_warudo() -> PackedFloat32Array:
	var n := int(MIX_RATE * 2.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		# Golpe inicial.
		var boom_env := exp(-t * 3.2)
		var boom_freq := lerpf(160.0, 42.0, minf(1.0, t * 3.0))
		var boom := sin(TAU * boom_freq * t) * 0.85 * boom_env
		# Drone que queda flotando.
		var drone_env := minf(1.0, t * 5.0) * exp(-t * 1.1)
		var drone := (sin(TAU * 58.0 * t) * 0.4 + sin(TAU * 87.0 * t) * 0.22) * drone_env
		out[i] = boom + drone
	return out


## Congelacion: campanita cristalina.
func _synth_freeze() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 4.5)
		out[i] = (sin(TAU * 1760.0 * t) * 0.4
			+ sin(TAU * 2640.0 * t) * 0.25
			+ sin(TAU * 3520.0 * t) * 0.15) * env
	return out


## Dash: soplido de ruido corto.
func _synth_dash() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	var last := 0.0
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := sin(PI * minf(1.0, t / 0.22)) * 0.8
		# Filtro pasabajos casero: suaviza el ruido y lo vuelve un "whoosh".
		last = lerpf(last, randf_range(-1.0, 1.0), 0.35)
		out[i] = last * env
	return out


func _synth_death() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.8)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 3.4)
		var freq := lerpf(420.0, 90.0, minf(1.0, t / 0.7))
		out[i] = (sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 0.5 * t) * 0.3) * env
	return out


## Zumbido sostenido mientras se canaliza.
func _synth_channel() -> PackedFloat32Array:
	var n := int(MIX_RATE * 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t * 6.0) * minf(1.0, (1.0 - t) * 6.0)
		var freq := lerpf(180.0, 540.0, t)
		out[i] = (sin(TAU * freq * t) * 0.3 + sin(TAU * freq * 1.5 * t) * 0.15) * env
	return out


func _synth_ui_click() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.07)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		out[i] = sin(TAU * 900.0 * t) * 0.5 * exp(-t * 45.0)
	return out


## Aviso de "no te alcanza la stamina": zumbido feo y corto, a proposito.
func _synth_no_stamina() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.22)
	var out := PackedFloat32Array()
	out.resize(n)
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var env := exp(-t * 9.0)
		# Onda cuadrada grave: suena a error sin necesidad de explicarlo.
		var square := 1.0 if fmod(t * 150.0, 1.0) < 0.5 else -1.0
		out[i] = square * 0.32 * env
	return out


func _synth_respawn() -> PackedFloat32Array:
	var n := int(MIX_RATE * 0.5)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [523.25, 659.25, 783.99]
	for i: int in range(n):
		var t := float(i) / MIX_RATE
		var step := mini(notes.size() - 1, int(t / 0.14))
		var local_t := t - float(step) * 0.14
		var env := exp(-local_t * 9.0)
		out[i] = sin(TAU * float(notes[step]) * t) * 0.4 * env
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
