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


# ------------------------------------------------------------ Lo que se nota
#
# LOS CUATRO COLORES DE ARRIBA NO ALCANZABAN, y no por pocos: los disfraces de cada
# personaje tenian sus colores escritos a mano y no leian la skin. Una skin recoloreaba el
# torso y las piernas, pero el pelo de Dio, el sueter de Noelle, el guardapolvo de Rick y
# las puas de Sonic quedaban iguales — "Sonic Dorado" tenia la cabeza azul. Por eso no se
# notaban.
#
# LO QUE NINGUN CAMPO DE ACA PUEDE HACER: cambiar la silueta, la hitbox, ni volverte menos
# visible. Una skin oscura que te camufla contra el piso seria una ventaja comprada. Por
# eso el acabado "sombra" oscurece Y prende un borde claro: el cuerpo queda recortado,
# mas visible que el de fabrica, no menos.

## Color por parte del disfraz: &"pelo", &"sueter_a", &"guardapolvo", &"pua"... Cada
## personaje nombra las suyas en su constructor. La que no este aca queda de fabrica.
@export var partes: Dictionary = {}
## Terminacion de la superficie: &"" (toon comun), &"metal", &"brillo", &"hielo",
## &"piedra" o &"sombra".
@export var acabado: StringName = &""
## Particulas alrededor del cuerpo: &"" (ninguna), &"nieve", &"chispas", &"niebla",
## &"estrellas", &"arcoiris", &"polvo", &"hojas", &"burbujas".
@export var aura: StringName = &""
@export var aura_color: Color = Color.WHITE
## Ojos que emiten luz, y de que color. Con alfa 0 no brillan.
@export var ojos_brillo: Color = Color(0, 0, 0, 0)
## Un adorno chico: &"" (ninguno), &"gorro", &"nariz_roja", &"parche", &"gafas".
@export var accesorio: StringName = &""
## Color de la estela del dash. Con alfa 0, la de fabrica.
@export var estela: Color = Color(0, 0, 0, 0)


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
