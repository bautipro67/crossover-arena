extends Node
## Autoload: GameConfig
## Constantes globales + registro del InputMap.
##
## Las acciones de input se registran ACA por codigo en vez de en project.godot.
## Es a proposito: asi todos los controles del juego estan en un solo lugar legible
## y no hay que pelear con el formato serializado de project.godot para rebindear.

const DEFAULT_PORT: int = 27015

## Servidor publico del juego. Si lo dejas vacio, el menu no muestra el boton y cada
## uno escribe la direccion a mano.
##
## Poné la URL COMPLETA con wss://, por ejemplo "wss://juego.midominio.com".
## Tiene que ser wss:// y no ws://: itch.io sirve la pagina por HTTPS y el navegador
## bloquea un WebSocket inseguro desde una pagina segura. Ver docs/SERVIDOR.md.
const OFFICIAL_SERVER_URL: String = ""
const MAX_PLAYERS: int = 8

## Cada cuanto el cliente le manda su transform al servidor.
const NET_TICK_HZ: float = 20.0

# --- Capas de fisica (valores de bitmask, no indices) ---
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_PROJECTILE: int = 1 << 2

# --- Reglas de partida ---
const RESPAWN_DELAY: float = 4.0
const SCORE_TO_WIN: int = 15

## Accion -> lista de eventos. Se registran en _ready().
## Para rebindear un control, cambia esta tabla.
const BINDINGS: Dictionary = {
	"move_forward": [KEY_W],
	"move_back": [KEY_S],
	"move_left": [KEY_A],
	"move_right": [KEY_D],
	"jump": [KEY_SPACE],
	# Dash en Shift: es la accion que mas se usa en pelea, va en la tecla mas comoda.
	"dash": [KEY_SHIFT],
	# Sprint manual. Solo hace falta si apagas "correr automaticamente" en Opciones;
	# con el auto-correr prendido (por defecto) ya corres sin apretar nada.
	"sprint": [KEY_CTRL],
	"ability_ultimate": [KEY_Q],
	"scoreboard": [KEY_TAB],
}

## Acciones ligadas al mouse: accion -> boton.
const MOUSE_BINDINGS: Dictionary = {
	"attack_basic": MOUSE_BUTTON_LEFT,
	"ability_1": MOUSE_BUTTON_RIGHT,
}


func _ready() -> void:
	_register_input_actions()


func _register_input_actions() -> void:
	for action_name: String in BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		for keycode: int in BINDINGS[action_name]:
			var ev := InputEventKey.new()
			ev.physical_keycode = keycode
			InputMap.action_add_event(action_name, ev)

	for action_name: String in MOUSE_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BINDINGS[action_name]
		InputMap.action_add_event(action_name, mb)
