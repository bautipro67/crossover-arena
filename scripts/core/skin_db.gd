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
	copia.body_color = skin.body_color
	copia.accent_color = skin.accent_color
	copia.skin_color = skin.skin_color
	copia.trouser_color = skin.trouser_color
	return copia
