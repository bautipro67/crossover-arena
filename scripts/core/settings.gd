extends Node
## Autoload: Settings
## Opciones del jugador, guardadas en disco (user://settings.cfg).
##
## Es lo minimo que espera cualquiera que baje un juego de itch.io: poder bajarle el
## volumen, ajustar la sensibilidad del mouse y ponerlo en pantalla completa.

const CONFIG_PATH: String = "user://settings.cfg"

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


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "player_name", player_name)
	cfg.set_value("game", "auto_run", auto_run)
	cfg.set_value("game", "mostrar_hitboxes", mostrar_hitboxes)
	cfg.save(CONFIG_PATH)


## Aplica las opciones al motor. Se llama al arrancar y cada vez que cambia algo.
func apply() -> void:
	Sfx.master_volume = master_volume
	Music.music_volume = music_volume
	if fullscreen:
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


func set_player_name(value: String) -> void:
	player_name = value.strip_edges().substr(0, 16)
	save_settings()
