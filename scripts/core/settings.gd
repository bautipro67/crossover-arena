extends Node
## Autoload: Settings
## Opciones del jugador, guardadas en disco (user://settings.cfg).
##
## Es lo minimo que espera cualquiera que baje un juego de itch.io: poder bajarle el
## volumen, ajustar la sensibilidad del mouse y ponerlo en pantalla completa.

const CONFIG_PATH: String = "user://settings.cfg"
const FOV_MIN: float = 60.0
const FOV_MAX: float = 95.0
const DISTANCIA_MIN: float = 0.75
const DISTANCIA_MAX: float = 1.4
const BOTONES_MIN: float = 0.75
const BOTONES_MAX: float = 1.4

signal changed()

var mouse_sensitivity: float = 0.0025
var master_volume: float = 0.8
## Volumen de la musica, aparte del de los efectos: la musica loopea todo el tiempo
## y mucha gente la quiere mas baja que los sonidos de combate.
var music_volume: float = 0.45
var fullscreen: bool = false
var player_name: String = "Jugador"
## Correr sin tener que mantener nada apretado. Prendido por defecto: en un juego de
## arena estas corriendo el 95% del tiempo, obligarte a sostener una tecla es ruido.
var auto_run: bool = true
## Dibujar las cajas de colision: la capsula de cada jugador, el radio de cada proyectil
## y el volumen de cada ataque en el momento en que consulta a quien toca.
##
## APAGADO POR DEFECTO, obviamente, pero es la clase de opcion que un juego de peleas
## tiene que tener: "me pego sin tocarme" es la queja numero uno de cualquier juego de
## combate, y sin poder VER el alcance no hay forma de saber si es cierto o si el que se
## queja calculo mal. Tambien sirve para reportar un bug con algo mas que una impresion.
var mostrar_hitboxes: bool = false
## ASISTENCIA DE APUNTADO: las habilidades se corren apenas hacia el rival que esta casi
## en la mira, y el golpe basico busca al que esta al lado (ver Player.get_aim_direction).
## Prendida por defecto: sin ella, embocar una bola a alguien que se mueve con el mouse es
## lo que mas cuesta al empezar, y con mando o con el dedo, mas todavia.
var asistencia_apuntado: bool = true
## Con el golpe basico apretado, sigue pegando solo (ver Player._mantener_ataque).
var mantener_para_atacar: bool = true

# --- La camara (2026-10-10, "mejora la camara para que sea mas comoda") ---
## Campo de vision vertical, en grados. 75 es el de fabrica de Godot; mas abierto se ve
## mas alrededor y marea menos a algunos, mas cerrado se ve todo mas grande.
var fov: float = 75.0
## Que tan lejos va la camara, como parte de la distancia de fabrica.
var distancia_camara: float = 1.0
## Mirar arriba moviendo el mouse, el stick o el dedo hacia abajo, como en los simuladores.
var invertir_y: bool = false

# --- El celular ---
## Cuanto gira la camara arrastrando el dedo, aparte del mouse: un deslizador que sirve para
## el mouse queda lentisimo o rapidisimo en una pantalla tactil.
var sensibilidad_tactil: float = 1.0
## Con el dedo, la camara se acomoda sola detras tuyo cuando caminas para el costado, y
## vuelve a la altura de siempre. En el celular mover y girar a la vez es lo que mas cuesta.
var camara_automatica: bool = true
## El tamaño de los botones en pantalla y que tan opacos se dibujan.
var tamano_botones: float = 1.0
var opacidad_botones: float = 0.9
## Un toque de vibracion al apretar un boton y al recibir un golpe (solo con el dedo).
var vibracion: bool = true


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.0005, 0.012)
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	player_name = String(cfg.get_value("game", "player_name", player_name))
	auto_run = bool(cfg.get_value("game", "auto_run", auto_run))
	mostrar_hitboxes = bool(cfg.get_value("game", "mostrar_hitboxes", mostrar_hitboxes))
	asistencia_apuntado = bool(cfg.get_value("game", "asistencia_apuntado", asistencia_apuntado))
	mantener_para_atacar = bool(cfg.get_value("game", "mantener_para_atacar", mantener_para_atacar))
	fov = clampf(float(cfg.get_value("camara", "fov", fov)), FOV_MIN, FOV_MAX)
	distancia_camara = clampf(float(cfg.get_value("camara", "distancia", distancia_camara)), DISTANCIA_MIN, DISTANCIA_MAX)
	invertir_y = bool(cfg.get_value("camara", "invertir_y", invertir_y))
	sensibilidad_tactil = clampf(float(cfg.get_value("tactil", "sensibilidad", sensibilidad_tactil)), 0.3, 2.5)
	camara_automatica = bool(cfg.get_value("tactil", "camara_automatica", camara_automatica))
	tamano_botones = clampf(float(cfg.get_value("tactil", "tamano_botones", tamano_botones)), BOTONES_MIN, BOTONES_MAX)
	opacidad_botones = clampf(float(cfg.get_value("tactil", "opacidad_botones", opacidad_botones)), 0.3, 1.0)
	vibracion = bool(cfg.get_value("tactil", "vibracion", vibracion))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "player_name", player_name)
	cfg.set_value("game", "auto_run", auto_run)
	cfg.set_value("game", "mostrar_hitboxes", mostrar_hitboxes)
	cfg.set_value("game", "asistencia_apuntado", asistencia_apuntado)
	cfg.set_value("game", "mantener_para_atacar", mantener_para_atacar)
	cfg.set_value("camara", "fov", fov)
	cfg.set_value("camara", "distancia", distancia_camara)
	cfg.set_value("camara", "invertir_y", invertir_y)
	cfg.set_value("tactil", "sensibilidad", sensibilidad_tactil)
	cfg.set_value("tactil", "camara_automatica", camara_automatica)
	cfg.set_value("tactil", "tamano_botones", tamano_botones)
	cfg.set_value("tactil", "opacidad_botones", opacidad_botones)
	cfg.set_value("tactil", "vibracion", vibracion)
	cfg.save(CONFIG_PATH)


## Aplica las opciones al motor. Se llama al arrancar y cada vez que cambia algo.
func apply() -> void:
	Sfx.master_volume = master_volume
	Music.music_volume = music_volume
	# EN LA APLICACION DEL CELULAR, SIEMPRE A PANTALLA COMPLETA: ahi "ventana" no existe, y
	# pedirla apaga el modo inmersivo (vuelven la barra de arriba y los botones de Android
	# encima del juego).
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0005, 0.012)
	save_settings()
	changed.emit()


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	Sfx.master_volume = master_volume
	save_settings()
	changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	Music.music_volume = music_volume
	save_settings()
	changed.emit()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()


func set_auto_run(value: bool) -> void:
	auto_run = value
	save_settings()
	changed.emit()


func set_mostrar_hitboxes(value: bool) -> void:
	mostrar_hitboxes = value
	save_settings()
	changed.emit()


func set_asistencia_apuntado(value: bool) -> void:
	asistencia_apuntado = value
	save_settings()


func set_mantener_para_atacar(value: bool) -> void:
	mantener_para_atacar = value
	save_settings()


## Cualquiera de las opciones nuevas, por nombre: las de camara y las del celular son
## todas "un numero o un si/no que se guarda y avisa", y una funcion por cada una era ruido.
func set_opcion(nombre: StringName, valor: Variant) -> void:
	match nombre:
		&"fov": fov = clampf(float(valor), FOV_MIN, FOV_MAX)
		&"distancia_camara": distancia_camara = clampf(float(valor), DISTANCIA_MIN, DISTANCIA_MAX)
		&"invertir_y": invertir_y = bool(valor)
		&"sensibilidad_tactil": sensibilidad_tactil = clampf(float(valor), 0.3, 2.5)
		&"camara_automatica": camara_automatica = bool(valor)
		&"tamano_botones": tamano_botones = clampf(float(valor), BOTONES_MIN, BOTONES_MAX)
		&"opacidad_botones": opacidad_botones = clampf(float(valor), 0.3, 1.0)
		&"vibracion": vibracion = bool(valor)
		_: return
	save_settings()
	changed.emit()


## Una vibracion corta, si el jugador la quiere y esta jugando con el dedo. En una
## computadora no hace nada; en el navegador de un celular usa la del navegador.
func vibrar(ms: int) -> void:
	if vibracion and Controles.dispositivo == &"tactil":
		Input.vibrate_handheld(ms)


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().substr(0, 16)
	save_settings()
