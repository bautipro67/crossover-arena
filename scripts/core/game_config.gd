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
const OFFICIAL_SERVER_URL: String = "wss://crossover-arena.onrender.com"
const MAX_PLAYERS: int = 8

## Cuanto del daño normal hacen los bots de practica.
##
## Con los bots rotos (se trababan y no llegaban) el modo practica hacia 2 de daño por
## segundo y parecia equilibrado. Apenas empezaron a navegar de verdad, los tres juntos
## pasaron a 48 por segundo: con 100 de vida eso es morirse en dos segundos, que no es
## dificultad, es no poder jugar.
##
## Se aplica en CombatUtils.deal_damage a todo atacante con peer negativo, que es como
## se identifican los bots. Las animaciones y los tiempos quedan iguales: lo unico que
## cambia son los numeros, asi que lo que practicas sigue siendo valido.
##
## Bajo de 0.5 a 0.4 al arreglar el escalon del navmesh. No es que los bots peguen mas
## fuerte: es que hasta entonces UNO DE LOS TRES se pasaba la partida clavado contra el
## borde de una rampa, y el 0.5 estaba calibrado sin darse cuenta contra dos bots y
## medio. Con los tres peleando de verdad el mismo numero daba 22 por segundo. Este
## devuelve el modo practica a los 17 por segundo que ya habiamos medido como jugables.
## Bajo otra vez a 0.33 cuando JARONA paso a repetirse hasta fallar: el bot de Flowery
## empezo a encadenar pasadas de verdad y los tres juntos treparon de 17 a 21 por
## segundo. El numero no cambio porque los bots jueguen mejor sino porque una de sus
## habilidades se volvio mas larga, asi que corresponde compensarlo aca.
## Subio a 0.45 con el mapa de 120 metros. No es que peguen mas fuerte: con el mapa mas
## grande pasan mas tiempo caminando y menos pegando —de 55% a 35% del tiempo a distancia
## de golpe— y los tres juntos cayeron de 16 a 9.7 por segundo. El ajuste devuelve el modo
## practica a los ~14 por segundo que ya habiamos medido como jugables.
const BOT_DAMAGE_SCALE: float = 0.45

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
	# Segunda habilidad en E: al lado de WASD, se llega sin soltar el movimiento.
	"ability_2": [KEY_E],
	"ability_ultimate": [KEY_Q],
	"scoreboard": [KEY_TAB],
	# Panel de la sala de practica.
	#
	# P PRIMERO Y F1 DESPUES, y el orden importa aunque las dos funcionen.
	#
	# Arranco solo con F1 y en el navegador NO ABRIA: F1 es la tecla de ayuda del
	# navegador y se la come antes de que llegue al canvas. Lo comprobe en el build web
	# servido en local —Escape abria la pausa, F1 no hacia nada—, y el navegador es
	# justamente donde vive la mayoria de los que juegan esto, porque es lo que esta en
	# itch. F1 queda igual porque en escritorio funciona y es lo que uno prueba primero.
	"practice_panel": [KEY_P, KEY_F1],
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
