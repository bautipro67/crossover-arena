class_name SkinData
extends Resource
## Un aspecto alternativo para un personaje.
##
## UNA SKIN ES SOLO UNA PALETA, y eso no es una limitacion: es el motivo por el que el
## sistema entero cabe en dos archivos. El juego dibuja los cuerpos por codigo a partir de
## cuatro colores —ropa, acento, piel, pantalon— asi que cambiarlos alcanza para que un
## personaje se vea distinto sin modelar nada nuevo.
##
## LO QUE UNA SKIN NO PUEDE TOCAR: vida, daño, velocidad, cooldowns, hitbox y silueta.
## Los primeros cinco porque el juego es PvP y pagar no puede dar ventaja. La silueta
## porque es como se reconoce a un personaje a veinte metros: si una skin le cambia la
## forma, el rival ya no sabe contra que esta peleando, y eso SI es una ventaja.

@export var id: StringName = &""
@export var character_id: StringName = &""
@export var display_name: String = ""
## Una linea para la tienda y para el pase.
@export var descripcion: String = ""

@export var body_color: Color = Color.WHITE
@export var accent_color: Color = Color.CYAN
@export var skin_color: Color = Color(0.98, 0.85, 0.74)
@export var trouser_color: Color = Color(0.14, 0.16, 0.25)

## comun / rara / epica / legendaria. Decide el color del marco y el precio sugerido.
@export var rareza: StringName = &"comun"
## Cuanto sale en la tienda. 0 = no se vende, solo sale del pase.
@export var precio: int = 0


## El color del marco segun la rareza. Es lo unico que hace que una lista de veinte
## recuadros se pueda leer de un vistazo en vez de tener que leerlos uno por uno.
static func color_rareza(r: StringName) -> Color:
	match r:
		&"legendaria":
			return Color(1.0, 0.72, 0.25)
		&"epica":
			return Color(0.76, 0.48, 1.0)
		&"rara":
			return Color(0.38, 0.72, 1.0)
		_:
			return Color(0.62, 0.68, 0.78)


static func nombre_rareza(r: StringName) -> String:
	match r:
		&"legendaria":
			return "LEGENDARIA"
		&"epica":
			return "EPICA"
		&"rara":
			return "RARA"
		_:
			return "COMUN"
