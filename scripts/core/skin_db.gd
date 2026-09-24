extends Node
## Autoload: SkinDB
## Catalogo de skins. Tres por personaje.
##
## CADA SKIN SALE DE ALGO DEL ORIGINAL, no de mover el tono al azar. Noelle congelada es
## la ruta Snowgrave; Dio dorado es su forma vampirica; Flowery arcoiris es Omega Flowery;
## Rick verde es Pickle Rick. Una paleta inventada se ve como un error de color, una
## paleta que referencia algo se ve como una skin.
##
## PARA AGREGAR UNA: una entrada en _registrar_todas() y listo. Si tiene precio entra sola
## en la tienda, y si la nombra un escalon del pase entra sola en el pase.

var _skins: Dictionary = {}
var _orden: Array[StringName] = []


func _ready() -> void:
	_registrar_todas()
	_detallar()


func _registrar_todas() -> void:
	# --------------------------------------------------------------- Noelle
	_add(_hacer(&"noelle_snowgrave", &"noelle", "Noelle Congelada",
		"La ruta que nadie deberia haber tomado.",
		Color(0.80, 0.90, 1.00), Color(0.45, 0.78, 1.00),
		Color(0.85, 0.93, 1.00), Color(0.20, 0.34, 0.52), &"legendaria", 0))
	_add(_hacer(&"noelle_fiesta", &"noelle", "Noelle de Fiesta",
		"Rojo y verde, como corresponde a su apellido.",
		Color(0.92, 0.24, 0.26), Color(0.20, 0.62, 0.32),
		Color(0.95, 0.87, 0.76), Color(0.14, 0.36, 0.22), &"rara", 900))
	_add(_hacer(&"noelle_sombra", &"noelle", "Noelle Sombra",
		"Todo el pelaje en gris ceniza.",
		Color(0.30, 0.31, 0.36), Color(0.62, 0.64, 0.72),
		Color(0.55, 0.56, 0.62), Color(0.16, 0.16, 0.20), &"epica", 1800))

	# ------------------------------------------------------------------ Dio
	_add(_hacer(&"dio_vampiro", &"dio", "Dio Vampiro",
		"Piel de muerto y la sangre en la ropa.",
		Color(0.16, 0.13, 0.18), Color(0.86, 0.14, 0.20),
		Color(0.88, 0.85, 0.88), Color(0.12, 0.10, 0.14), &"legendaria", 0))
	_add(_hacer(&"dio_dorado", &"dio", "Dio Dorado",
		"Oro entero, sin una sola parte que no brille.",
		Color(1.00, 0.84, 0.32), Color(1.00, 0.92, 0.55),
		Color(0.97, 0.90, 0.80), Color(0.86, 0.68, 0.20), &"epica", 0))
	_add(_hacer(&"dio_noche", &"dio", "Dio Nocturno",
		"Purpura y negro, el color de su Stand.",
		Color(0.30, 0.20, 0.46), Color(0.72, 0.44, 0.95),
		Color(0.90, 0.84, 0.86), Color(0.18, 0.12, 0.28), &"rara", 900))

	# -------------------------------------------------------------- Flowery
	_add(_hacer(&"flowery_omega", &"flowery", "Omega Flowery",
		"Los siete colores de las flores, todos a la vez.",
		Color(1.00, 0.95, 0.72), Color(1.00, 0.45, 0.72),
		Color(0.80, 0.92, 0.45), Color(0.52, 0.30, 0.68), &"legendaria", 0))
	_add(_hacer(&"flowery_dorado", &"flowery", "Flor Dorada",
		"La flor dorada de la que salio, antes del mundo oscuro.",
		Color(1.00, 0.90, 0.48), Color(0.72, 0.52, 0.12),
		Color(0.95, 0.88, 0.40), Color(0.60, 0.44, 0.16), &"epica", 1800))
	_add(_hacer(&"flowery_nocturno", &"flowery", "Flowery Nocturno",
		"El traje que usaria si fuera el villano que dice ser.",
		Color(0.14, 0.15, 0.22), Color(0.36, 0.86, 0.62),
		Color(0.42, 0.56, 0.34), Color(0.10, 0.11, 0.16), &"rara", 0))

	# ----------------------------------------------------------------- Rick
	_add(_hacer(&"rick_pickle", &"rick", "Rick Pepinillo",
		"Se convirtio en pepinillo. Es la mejor que hizo.",
		Color(0.42, 0.72, 0.28), Color(0.24, 0.46, 0.18),
		Color(0.56, 0.80, 0.34), Color(0.28, 0.50, 0.20), &"legendaria", 0))
	_add(_hacer(&"rick_maligno", &"rick", "Rick Maligno",
		"De otra dimension, y no de una buena.",
		Color(0.20, 0.22, 0.26), Color(0.92, 0.72, 0.20),
		Color(0.76, 0.70, 0.66), Color(0.14, 0.15, 0.18), &"epica", 0))
	_add(_hacer(&"rick_cosmico", &"rick", "Rick Cosmico",
		"Demasiados portales seguidos.",
		Color(0.34, 0.26, 0.62), Color(0.55, 0.92, 1.00),
		Color(0.80, 0.74, 0.92), Color(0.22, 0.16, 0.42), &"rara", 0))


	# ------------------------------------------- Solo tienda, una por personaje
	#
	# Existen porque sin ellas la tienda se quedaba con cuatro articulos: las ocho que da
	# el pase no se venden, y una tienda de cuatro renglones no da ganas de juntar monedas.
	_add(_hacer(&"noelle_reno", &"noelle", "Noelle Reno",
		"Se dejo de disimular lo de las astas.",
		Color(0.86, 0.32, 0.28), Color(0.96, 0.94, 0.90),
		Color(0.90, 0.76, 0.58), Color(0.48, 0.28, 0.20), &"rara", 900))
	_add(_hacer(&"dio_piedra", &"dio", "Dio de Piedra",
		"La mascara lo tomo entero.",
		Color(0.56, 0.54, 0.50), Color(0.72, 0.70, 0.64),
		Color(0.64, 0.62, 0.58), Color(0.40, 0.39, 0.36), &"epica", 1800))
	_add(_hacer(&"flowery_marchito", &"flowery", "Flowery Marchito",
		"Las flores duraban un dia.",
		Color(0.52, 0.46, 0.34), Color(0.30, 0.26, 0.20),
		Color(0.58, 0.52, 0.30), Color(0.34, 0.28, 0.20), &"rara", 900))
	_add(_hacer(&"rick_bata", &"rick", "Rick de Laboratorio",
		"La bata limpia. Duro una tarde.",
		Color(0.94, 0.95, 0.96), Color(0.30, 0.52, 0.72),
		Color(0.90, 0.78, 0.63), Color(0.72, 0.74, 0.78), &"epica", 1800))

	# ----------------------------------------------------------------- Sonic
	#
	# Las tres salen de formas que el personaje tuvo de verdad: Super Sonic es dorado,
	# Shadow es negro con vetas rojas y Sonic clasico es el azul oscuro de 1991, mas
	# saturado que el cobalto moderno.
	_add(_hacer(&"sonic_super", &"sonic", "Sonic Dorado",
		"Las siete Esmeraldas Chaos, sin las esmeraldas.",
		Color(1.00, 0.86, 0.22), Color(0.95, 0.72, 0.10),
		Color(1.00, 0.93, 0.70), Color(0.92, 0.76, 0.16), &"legendaria", 0))
	_add(_hacer(&"sonic_oscuro", &"sonic", "Sonic Oscuro",
		"Negro con vetas rojas. No pregunten de dónde salió.",
		Color(0.13, 0.13, 0.16), Color(0.88, 0.13, 0.13),
		Color(0.92, 0.84, 0.76), Color(0.10, 0.10, 0.13), &"epica", 1800))
	_add(_hacer(&"sonic_clasico", &"sonic", "Sonic Clásico",
		"El azul de 1991, más oscuro y más redondo.",
		Color(0.09, 0.16, 0.66), Color(0.90, 0.18, 0.16),
		Color(0.99, 0.80, 0.56), Color(0.07, 0.13, 0.55), &"rara", 900))

	_registrar_temporada_1()


# ------------------------------------------------------------- Temporada 1
#
# SIETE EN EL PASE Y CINCO EN LA TIENDA, como en la temporada 0: el que no compra el pase
# igual tiene de donde elegir, y el pase tiene lo que no se consigue en otro lado.
#
# LAS DE GOKU VAN TODAS EN LA TIENDA, y no por olvido: Goku es el premio del ULTIMO
# escalon del pase pro, asi que una skin suya en el pase caeria antes de tenerlo y no se
# podria usar. En la tienda se compran recien cuando ya lo ganaste.
func _registrar_temporada_1() -> void:
	var nuevas: Array[SkinData] = [
		# --- El pase ---
		_hacer(&"sonic_metal", &"sonic", "Sonic Metálico",
			"Hecho en una fábrica que no aparece en ningún mapa.",
			Color(0.16, 0.20, 0.42), Color(0.85, 0.12, 0.12),
			Color(0.72, 0.76, 0.84), Color(0.14, 0.18, 0.38), &"epica", 0),
		_hacer(&"noelle_otono", &"noelle", "Noelle de Otoño",
			"Hojas secas y chocolate caliente.",
			Color(0.86, 0.46, 0.18), Color(0.95, 0.70, 0.30),
			Color(0.95, 0.87, 0.76), Color(0.30, 0.18, 0.10), &"rara", 0),
		_hacer(&"flowery_primavera", &"flowery", "Flowery Primavera",
			"Florece. Literalmente.",
			Color(0.98, 0.95, 0.92), Color(0.98, 0.55, 0.72),
			Color(0.74, 0.84, 0.42), Color(0.50, 0.72, 0.45), &"epica", 0),
		_hacer(&"rick_toxico", &"rick", "Rick Tóxico",
			"Toda la toxicidad de un Rick, separada en uno solo.",
			Color(0.45, 0.75, 0.25), Color(0.20, 0.35, 0.10),
			Color(0.78, 0.88, 0.58), Color(0.30, 0.45, 0.15), &"epica", 0),
		_hacer(&"dio_blanco", &"dio", "Dio de Blanco",
			"Blanco de pies a cabeza, para que se note la sangre.",
			Color(0.95, 0.95, 0.92), Color(0.85, 0.70, 0.30),
			Color(0.94, 0.86, 0.82), Color(0.92, 0.90, 0.85), &"rara", 0),
		_hacer(&"noelle_aurora", &"noelle", "Noelle Aurora",
			"El cielo del norte, en un suéter.",
			Color(0.35, 0.90, 0.75), Color(0.55, 0.35, 0.95),
			Color(0.95, 0.90, 0.86), Color(0.12, 0.14, 0.30), &"legendaria", 0),
		_hacer(&"dio_cielo", &"dio", "Dio del Cielo",
			"Más allá del cielo. Más allá de todo.",
			Color(0.97, 0.97, 0.95), Color(1.00, 0.82, 0.30),
			Color(0.96, 0.90, 0.86), Color(0.92, 0.90, 0.86), &"legendaria", 0),
		# --- La tienda ---
		# Las tres transformaciones de Goku, con los colores de la serie: dorado con ojos
		# turquesa, celeste, y plateado de pies a cabeza.
		_hacer(&"goku_ssj", &"goku", "Goku Super Saiyajin",
			"Dorado, y con los ojos turquesa. El enojo, hecho luz.",
			Color(0.98, 0.50, 0.12), Color(0.13, 0.20, 0.52),
			Color(0.98, 0.83, 0.68), Color(0.96, 0.47, 0.11), &"legendaria", 2600),
		_hacer(&"goku_blue", &"goku", "Goku Super Saiyajin Blue",
			"El ki de un dios, con el cuerpo de un Saiyajin.",
			Color(0.96, 0.48, 0.12), Color(0.12, 0.30, 0.62),
			Color(0.98, 0.83, 0.68), Color(0.94, 0.45, 0.11), &"epica", 1800),
		_hacer(&"goku_ui", &"goku", "Goku Ultra Instinto",
			"El cuerpo se mueve solo. El pelo se vuelve plata.",
			Color(0.94, 0.46, 0.14), Color(0.20, 0.22, 0.40),
			Color(0.97, 0.84, 0.72), Color(0.92, 0.44, 0.13), &"legendaria", 2600),
		_hacer(&"noelle_menta", &"noelle", "Noelle Menta",
			"Fresca, como una mañana de invierno.",
			Color(0.62, 0.92, 0.80), Color(0.30, 0.70, 0.60),
			Color(0.95, 0.87, 0.76), Color(0.18, 0.34, 0.32), &"rara", 900),
		_hacer(&"rick_gala", &"rick", "Rick de Gala",
			"Traje, moño y ninguna intención de quedarse a la cena.",
			Color(0.96, 0.96, 0.96), Color(0.60, 0.10, 0.15),
			Color(0.90, 0.78, 0.63), Color(0.08, 0.08, 0.10), &"rara", 900),
	]
	for sk: SkinData in nuevas:
		sk.temporada = 1
		_add(sk)


# -------------------------------------------------------------- Los detalles
#
# CUANTO SE NOTA DEPENDE DE LA RAREZA, y es la unica forma de que la rareza signifique
# algo mirando al personaje y no solo el marco de la tarjeta:
#
#   rara        recolorea el disfraz ENTERO (pelo, ropa, detalles), no solo el torso.
#   epica       ademas, un acabado (metal, piedra, sombra) o un accesorio.
#   legendaria  ademas, un aura de particulas y ojos que brillan.
#
# Las partes que no se nombran quedan de fabrica. Los nombres de las partes los define
# cada personaje en su constructor de PlayerVisual.

func _detallar() -> void:
	# ---------------------------------------------------------------- Noelle
	_det(&"noelle_snowgrave", {
		&"pelo": Color(0.88, 0.95, 1.00), &"sueter_a": Color(0.55, 0.80, 1.00),
		&"sueter_b": Color(0.20, 0.40, 0.72), &"oscuro": Color(0.16, 0.24, 0.38),
		&"astas": Color(0.78, 0.94, 1.00)},
		&"hielo", &"nieve", Color(0.85, 0.95, 1.0), Color(0.45, 0.90, 1.0), &"",
		Color(0.55, 0.85, 1.0, 0.8))
	_det(&"noelle_fiesta", {
		&"sueter_a": Color(0.92, 0.20, 0.22), &"sueter_b": Color(0.18, 0.62, 0.30)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"gorro", Color(1.0, 0.35, 0.35, 0.75))
	_det(&"noelle_sombra", {
		&"pelo": Color(0.66, 0.68, 0.76), &"sueter_a": Color(0.36, 0.37, 0.44),
		&"sueter_b": Color(0.22, 0.23, 0.29), &"oscuro": Color(0.10, 0.10, 0.13),
		&"astas": Color(0.52, 0.53, 0.60)},
		&"sombra", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.70, 0.60, 1.0, 0.75))
	_det(&"noelle_reno", {
		&"pelo": Color(0.60, 0.40, 0.26), &"sueter_a": Color(0.86, 0.30, 0.26),
		&"sueter_b": Color(0.96, 0.94, 0.90), &"astas": Color(0.52, 0.36, 0.20)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"nariz_roja", Color(1.0, 0.45, 0.35, 0.75))

	# ------------------------------------------------------------------- Dio
	_det(&"dio_vampiro", {
		&"pelo": Color(0.95, 0.92, 0.80), &"detalle": Color(0.72, 0.06, 0.12),
		&"musculosa": Color(0.07, 0.05, 0.07), &"tela": Color(0.16, 0.03, 0.06),
		&"joya": Color(0.95, 0.10, 0.15)},
		&"sombra", &"niebla", Color(0.85, 0.08, 0.14), Color(1.0, 0.12, 0.12), &"",
		Color(0.95, 0.12, 0.18, 0.8))
	_det(&"dio_dorado", {
		&"pelo": Color(1.00, 0.90, 0.45), &"detalle": Color(1.00, 0.78, 0.22),
		&"musculosa": Color(0.84, 0.64, 0.14), &"tela": Color(0.74, 0.54, 0.12)},
		&"metal", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(1.0, 0.85, 0.30, 0.8))
	_det(&"dio_noche", {
		&"pelo": Color(0.86, 0.78, 1.00), &"detalle": Color(0.72, 0.44, 0.95),
		&"musculosa": Color(0.14, 0.09, 0.22), &"tela": Color(0.20, 0.12, 0.34),
		&"joya": Color(0.80, 0.55, 1.0)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.72, 0.50, 1.0, 0.75))
	_det(&"dio_piedra", {
		&"pelo": Color(0.64, 0.62, 0.58), &"detalle": Color(0.50, 0.48, 0.44),
		&"musculosa": Color(0.38, 0.37, 0.34), &"tela": Color(0.46, 0.45, 0.42),
		&"joya": Color(0.70, 0.68, 0.62)},
		&"piedra", &"polvo", Color(0.62, 0.60, 0.55), Color(0, 0, 0, 0), &"",
		Color(0.65, 0.63, 0.58, 0.7))

	# --------------------------------------------------------------- Flowery
	_det(&"flowery_omega", {
		&"pelo": Color(1.00, 0.95, 0.62), &"chaleco_a": Color(1.00, 0.45, 0.72),
		&"chaleco_b": Color(0.45, 0.85, 1.00), &"campera": Color(0.52, 0.30, 0.68),
		&"camisa": Color(1.00, 1.00, 0.92)},
		&"brillo", &"arcoiris", Color(1.0, 0.55, 0.75), Color(1.0, 0.85, 0.30), &"",
		Color(1.0, 0.55, 0.80, 0.85))
	_det(&"flowery_dorado", {
		&"pelo": Color(1.00, 0.88, 0.35), &"chaleco_a": Color(0.95, 0.75, 0.20),
		&"chaleco_b": Color(0.80, 0.55, 0.12), &"campera": Color(0.58, 0.42, 0.14),
		&"camisa": Color(1.00, 0.96, 0.80)},
		&"metal", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(1.0, 0.85, 0.35, 0.8))
	_det(&"flowery_nocturno", {
		&"pelo": Color(0.20, 0.20, 0.27), &"chaleco_a": Color(0.36, 0.86, 0.62),
		&"chaleco_b": Color(0.18, 0.48, 0.38), &"campera": Color(0.07, 0.07, 0.11),
		&"camisa": Color(0.26, 0.27, 0.34)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.36, 0.90, 0.65, 0.75))
	_det(&"flowery_marchito", {
		&"pelo": Color(0.64, 0.57, 0.40), &"chaleco_a": Color(0.45, 0.40, 0.26),
		&"chaleco_b": Color(0.52, 0.36, 0.20), &"campera": Color(0.30, 0.26, 0.20),
		&"camisa": Color(0.70, 0.66, 0.55)},
		&"", &"hojas", Color(0.60, 0.40, 0.18), Color(0, 0, 0, 0), &"",
		Color(0.65, 0.48, 0.25, 0.7))

	# ------------------------------------------------------------------ Rick
	_det(&"rick_pickle", {
		&"pelo": Color(0.34, 0.60, 0.20), &"guardapolvo": Color(0.48, 0.78, 0.30),
		&"cinto": Color(0.24, 0.44, 0.14), &"hebilla": Color(0.72, 0.92, 0.40),
		&"medias": Color(0.55, 0.80, 0.35)},
		&"metal", &"burbujas", Color(0.60, 1.0, 0.45), Color(0.60, 1.0, 0.30), &"",
		Color(0.55, 1.0, 0.35, 0.8))
	_det(&"rick_maligno", {
		&"pelo": Color(0.52, 0.55, 0.60), &"guardapolvo": Color(0.20, 0.22, 0.26),
		&"cinto": Color(0.08, 0.08, 0.10), &"hebilla": Color(0.95, 0.74, 0.20)},
		&"sombra", &"", Color.WHITE, Color(0, 0, 0, 0), &"parche",
		Color(0.95, 0.74, 0.25, 0.75))
	_det(&"rick_cosmico", {
		&"pelo": Color(0.55, 0.92, 1.00), &"guardapolvo": Color(0.34, 0.26, 0.62),
		&"cinto": Color(0.20, 0.14, 0.40), &"hebilla": Color(0.55, 0.92, 1.00)},
		&"", &"estrellas", Color(0.60, 0.95, 1.0), Color(0, 0, 0, 0), &"",
		Color(0.55, 0.92, 1.0, 0.8))
	_det(&"rick_bata", {
		&"pelo": Color(0.82, 0.90, 0.94), &"guardapolvo": Color(1.00, 1.00, 1.00),
		&"cinto": Color(0.30, 0.52, 0.72), &"hebilla": Color(0.86, 0.88, 0.92)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"gafas", Color(0.60, 0.85, 1.0, 0.75))

	# ----------------------------------------------------------------- Sonic
	# Super Sonic tiene los ojos ROJOS, y no es un invento: es su rasgo mas reconocible
	# transformado, junto con el dorado. Sonic Clasico los tiene NEGROS, como en 1991.
	_det(&"sonic_super", {
		&"pua": Color(1.00, 0.80, 0.16), &"pelo": Color(1.00, 0.86, 0.26),
		&"piel": Color(1.00, 0.93, 0.70), &"ojos": Color(0.85, 0.10, 0.10)},
		&"brillo", &"chispas", Color(1.0, 0.88, 0.30), Color(1.0, 0.15, 0.10), &"",
		Color(1.0, 0.85, 0.25, 0.85))
	_det(&"sonic_oscuro", {
		&"pua": Color(0.12, 0.12, 0.15), &"pelo": Color(0.15, 0.15, 0.19),
		&"piel": Color(0.90, 0.82, 0.74), &"ojos": Color(0.88, 0.12, 0.12)},
		&"sombra", &"", Color.WHITE, Color(0.95, 0.15, 0.15), &"",
		Color(0.95, 0.18, 0.18, 0.8))
	_det(&"sonic_clasico", {
		&"pua": Color(0.08, 0.16, 0.62), &"pelo": Color(0.09, 0.18, 0.66),
		&"ojos": Color(0.05, 0.05, 0.07)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.30, 0.45, 1.0, 0.75))

	# ------------------------------------------------------------ Temporada 1
	_det(&"sonic_metal", {
		&"pua": Color(0.18, 0.24, 0.50), &"pelo": Color(0.20, 0.27, 0.55),
		&"piel": Color(0.72, 0.76, 0.84), &"guante": Color(0.60, 0.64, 0.72),
		&"ojos": Color(0.90, 0.10, 0.10)},
		&"metal", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.95, 0.20, 0.20, 0.8))
	_det(&"noelle_otono", {
		&"sueter_a": Color(0.86, 0.46, 0.18), &"sueter_b": Color(0.55, 0.30, 0.14),
		&"oscuro": Color(0.30, 0.18, 0.10), &"astas": Color(0.62, 0.44, 0.28)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(1.0, 0.60, 0.25, 0.75))
	_det(&"flowery_primavera", {
		&"pelo": Color(1.00, 0.92, 0.55), &"chaleco_a": Color(0.98, 0.62, 0.78),
		&"chaleco_b": Color(0.55, 0.88, 0.60), &"campera": Color(0.95, 0.95, 0.90),
		&"camisa": Color(1.00, 1.00, 1.00)},
		&"brillo", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(1.0, 0.65, 0.80, 0.8))
	_det(&"rick_toxico", {
		&"pelo": Color(0.65, 0.95, 0.40), &"guardapolvo": Color(0.55, 0.85, 0.25),
		&"cinto": Color(0.25, 0.45, 0.10), &"hebilla": Color(0.85, 1.00, 0.30)},
		&"brillo", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.65, 1.0, 0.25, 0.8))
	_det(&"dio_blanco", {
		&"musculosa": Color(0.95, 0.95, 0.92), &"tela": Color(0.90, 0.88, 0.82),
		&"detalle": Color(0.85, 0.70, 0.30), &"joya": Color(0.30, 0.80, 0.50)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.95, 0.90, 0.70, 0.75))
	_det(&"noelle_aurora", {
		&"pelo": Color(0.85, 0.95, 1.00), &"sueter_a": Color(0.35, 0.95, 0.75),
		&"sueter_b": Color(0.55, 0.35, 0.95), &"oscuro": Color(0.12, 0.14, 0.30),
		&"astas": Color(0.70, 0.95, 0.95)},
		&"hielo", &"estrellas", Color(0.60, 1.0, 0.85), Color(0.50, 1.0, 0.80), &"",
		Color(0.50, 0.95, 0.85, 0.85))
	_det(&"dio_cielo", {
		&"pelo": Color(1.00, 0.93, 0.65), &"musculosa": Color(0.97, 0.97, 0.95),
		&"tela": Color(0.92, 0.90, 0.86), &"detalle": Color(1.00, 0.82, 0.30),
		&"joya": Color(0.95, 0.30, 0.35)},
		&"brillo", &"chispas", Color(1.0, 0.90, 0.45), Color(1.0, 0.30, 0.30), &"",
		Color(1.0, 0.88, 0.45, 0.85))
	# Goku: el pelo claro brilla solo (lo decide el constructor del disfraz), asi que las
	# tres se notan sin acabado. La Blue lleva brillo porque es epica y no tiene aura.
	_det(&"goku_ssj", {
		&"pelo": Color(1.00, 0.86, 0.25), &"ojos": Color(0.20, 0.72, 0.62)},
		&"", &"chispas", Color(1.0, 0.90, 0.40), Color(0.30, 0.95, 0.80), &"",
		Color(1.0, 0.88, 0.35, 0.85))
	_det(&"goku_blue", {
		&"pelo": Color(0.35, 0.80, 1.00), &"ojos": Color(0.30, 0.70, 0.95),
		&"munequeras": Color(0.10, 0.28, 0.62), &"faja": Color(0.10, 0.30, 0.66)},
		&"brillo", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.40, 0.80, 1.0, 0.85))
	_det(&"goku_ui", {
		&"pelo": Color(0.86, 0.89, 0.96), &"ojos": Color(0.82, 0.86, 0.96),
		&"camiseta": Color(0.14, 0.16, 0.34)},
		&"", &"niebla", Color(0.80, 0.86, 1.0), Color(0.85, 0.90, 1.0), &"",
		Color(0.85, 0.90, 1.0, 0.85))
	_det(&"noelle_menta", {
		&"sueter_a": Color(0.62, 0.92, 0.80), &"sueter_b": Color(0.30, 0.70, 0.60),
		&"oscuro": Color(0.18, 0.34, 0.32)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.55, 0.95, 0.80, 0.75))
	_det(&"rick_gala", {
		&"guardapolvo": Color(0.10, 0.10, 0.12), &"cinto": Color(0.05, 0.05, 0.06),
		&"hebilla": Color(0.90, 0.80, 0.40), &"medias": Color(0.08, 0.08, 0.10)},
		&"", &"", Color.WHITE, Color(0, 0, 0, 0), &"", Color(0.75, 0.20, 0.25, 0.75))


func _det(id: StringName, partes: Dictionary, acabado: StringName, aura: StringName,
		aura_color: Color, ojos: Color, accesorio: StringName, estela: Color) -> void:
	var sk := get_skin(id)
	if sk == null:
		push_warning("[skins] detalle para una skin que no existe: %s" % id)
		return
	sk.partes = partes
	sk.acabado = acabado
	sk.aura = aura
	sk.aura_color = aura_color
	sk.ojos_brillo = ojos
	sk.accesorio = accesorio
	sk.estela = estela


func _hacer(id: StringName, personaje: StringName, nombre: String, desc: String,
		cuerpo: Color, acento: Color, piel: Color, pantalon: Color,
		rareza: StringName, precio: int) -> SkinData:
	var s := SkinData.new()
	s.id = id
	s.character_id = personaje
	s.display_name = nombre
	s.descripcion = desc
	s.body_color = cuerpo
	s.accent_color = acento
	s.skin_color = piel
	s.trouser_color = pantalon
	s.rareza = rareza
	s.precio = precio
	return s


func _add(s: SkinData) -> void:
	_skins[s.id] = s
	_orden.append(s.id)


func get_skin(id: StringName) -> SkinData:
	return _skins.get(id)


func existe(id: StringName) -> bool:
	return _skins.has(id)


func todas() -> Array[StringName]:
	return _orden.duplicate()


## Las skins de un personaje, en orden de registro.
func de_personaje(character_id: StringName) -> Array[StringName]:
	var salida: Array[StringName] = []
	for id: StringName in _orden:
		if (_skins[id] as SkinData).character_id == character_id:
			salida.append(id)
	return salida


## Las que se pueden comprar. Precio 0 significa "solo sale del pase".
func en_tienda() -> Array[StringName]:
	var salida: Array[StringName] = []
	for id: StringName in _orden:
		if (_skins[id] as SkinData).precio > 0:
			salida.append(id)
	return salida


## Aplica la paleta de la skin equipada sobre los datos del personaje.
##
## DEVUELVE UNA COPIA, siempre. CharacterDB entrega el MISMO objeto a todo el mundo —es un
## registro, no una fabrica— asi que pintarlo encima le cambiaria el color al personaje
## para todos los jugadores de la partida, incluido el que no compro nada. Paso en la
## primera version y se veia como un bug de red.
func aplicar(base: CharacterData, skin_id: StringName) -> CharacterData:
	if base == null:
		return null
	var skin := get_skin(skin_id)
	if skin == null or skin.character_id != base.id:
		return base
	var copia: CharacterData = base.duplicate()
	copia.skin_id = skin.id
	copia.body_color = skin.body_color
	copia.accent_color = skin.accent_color
	copia.skin_color = skin.skin_color
	copia.trouser_color = skin.trouser_color
	return copia
