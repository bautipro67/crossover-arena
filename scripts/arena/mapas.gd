class_name Mapas
extends RefCounted
## LOS MAPAS: los lugares de la historia, que tambien se juegan en los modos normales.
##
## PEDIDO (2026-10-02): "haz mejores mapas y que esten tematizados por donde estan en la
## historia y que tambien aparezcan en los modos normales". Cada parte de la historia
## pasa en un lugar —el coliseo bajo el cielo roto, la torre del torneo, el sotano del
## espiritu, el Inframundo, el vacio de Gojo, el nucleo— y cada uno es un mapa.
##
## EL TRAZADO ES EL MISMO EN TODOS, a proposito: la plataforma con la torre, las cuatro
## zonas, las pasarelas y el anillo de coberturas son el mapa que esta medido —el
## navmesh, los bots, los alcances de las definitivas, los capitulos que buscan un lugar
## despejado—. Lo que cambia es TODO lo que se ve: el cielo, la luz, la niebla, el piso, las
## paredes, la forma de cada cobertura y de cada columna, lo que hay del otro lado del
## muro y lo que flota en el aire. Ver Escenario, que viste el trazado con cada tema.

## El que se arma en la proxima partida. Lo pone la sala (offline o el host), la historia
## (el lugar del capitulo) o la red (el servidor le avisa a cada cliente).
static var elegido: StringName = &"coliseo"
## El que eligio el jugador en la sala: la historia cambia `elegido` por el lugar de cada
## capitulo, y al volver a un modo normal la sala lo devuelve a este.
static var preferido: StringName = &"coliseo"

const LISTA: Array[Dictionary] = [
	{
		"id": &"coliseo", "nombre": "El Coliseo", "lugar": "La Arena entre los mundos, bajo el cielo roto",
		"cielo": {"arriba": Color(0.05, 0.06, 0.17), "horizonte": Color(0.62, 0.45, 0.66),
			"suelo": Color(0.08, 0.06, 0.10), "energia": 1.15},
		"niebla": [Color(0.50, 0.44, 0.66), 0.0034], "ambiente": 0.36,
		"sol": [Color(1.0, 0.90, 0.78), 1.10, Vector3(-40.0, 35.0, 0.0)], "relleno": [Color(0.55, 0.50, 1.0), 0.45],
		"luces": {"centro": Color(1.0, 0.80, 0.45), "calida": Color(1.0, 0.70, 0.35), "fria": Color(0.65, 0.45, 1.0), "energia": 7.5},
		"piso": {"estilo": "losas", "a": Color(0.47, 0.42, 0.36), "b": Color(0.55, 0.50, 0.43), "marca": Color(1.0, 0.72, 0.30)},
		"pared": {"estilo": "coliseo", "color": Color(0.40, 0.35, 0.31), "trim": Color(1.0, 0.62, 0.25)},
		"cobertura": {"estilo": "ruina", "calida": Color(0.58, 0.50, 0.40), "fria": Color(0.42, 0.42, 0.50),
			"tope": Color(0.66, 0.61, 0.53), "detalle": Color(0.30, 0.26, 0.22)},
		"pilar": {"estilo": "columna", "color": Color(0.80, 0.76, 0.68), "detalle": Color(0.62, 0.58, 0.50)},
		"particulas": {"tipo": "polvo", "color": Color(1.0, 0.82, 0.55)},
		"decorado": "gradas", "acento": Color(0.80, 0.20, 0.25), "acento2": Color(0.95, 0.80, 0.35),
		"grieta": Color(0.85, 0.55, 1.0),
	},
	{
		"id": &"hometown", "nombre": "Hometown", "lugar": "El pueblo de Noelle, una noche de diciembre",
		"cielo": {"arriba": Color(0.01, 0.02, 0.06), "horizonte": Color(0.14, 0.18, 0.34),
			"suelo": Color(0.04, 0.05, 0.08), "energia": 0.9},
		"niebla": [Color(0.20, 0.25, 0.42), 0.0055], "ambiente": 0.42,
		"sol": [Color(0.70, 0.80, 1.0), 0.75, Vector3(-55.0, -30.0, 0.0)], "relleno": [Color(1.0, 0.70, 0.40), 0.30],
		"luces": {"centro": Color(1.0, 0.72, 0.40), "calida": Color(1.0, 0.65, 0.30), "fria": Color(0.45, 0.62, 1.0), "energia": 7.0},
		"piso": {"estilo": "nieve", "a": Color(0.82, 0.86, 0.94), "b": Color(0.74, 0.79, 0.90), "marca": Color(1.0, 0.75, 0.40),
			"calle": Color(0.20, 0.21, 0.25)},
		"pared": {"estilo": "pueblo", "color": Color(0.40, 0.29, 0.21), "trim": Color(1.0, 0.70, 0.35)},
		"cobertura": {"estilo": "nevado", "calida": Color(0.58, 0.30, 0.24), "fria": Color(0.36, 0.40, 0.52),
			"tope": Color(0.94, 0.96, 1.0), "detalle": Color(0.30, 0.20, 0.14)},
		"pilar": {"estilo": "pino", "color": Color(0.16, 0.34, 0.26), "detalle": Color(0.36, 0.24, 0.16)},
		"particulas": {"tipo": "nieve_arriba", "color": Color(0.95, 0.97, 1.0)},
		"decorado": "pueblo", "acento": Color(0.85, 0.18, 0.20), "acento2": Color(0.18, 0.55, 0.30),
	},
	{
		"id": &"torre", "nombre": "La Torre del Torneo", "lugar": "El torneo del nucleo, al pie de la torre",
		"cielo": {"arriba": Color(0.12, 0.22, 0.48), "horizonte": Color(0.95, 0.66, 0.42),
			"suelo": Color(0.12, 0.10, 0.12), "energia": 1.25},
		"niebla": [Color(0.85, 0.66, 0.55), 0.0028], "ambiente": 0.40,
		"sol": [Color(1.0, 0.88, 0.70), 1.0, Vector3(-30.0, 60.0, 0.0)], "relleno": [Color(0.50, 0.65, 1.0), 0.40],
		"luces": {"centro": Color(0.55, 0.85, 1.0), "calida": Color(1.0, 0.75, 0.35), "fria": Color(0.40, 0.65, 1.0), "energia": 7.5},
		"piso": {"estilo": "torneo", "a": Color(0.64, 0.62, 0.58), "b": Color(0.56, 0.54, 0.51), "marca": Color(0.45, 0.80, 1.0)},
		"pared": {"estilo": "torneo", "color": Color(0.72, 0.69, 0.62), "trim": Color(0.45, 0.80, 1.0)},
		"cobertura": {"estilo": "torneo", "calida": Color(0.72, 0.68, 0.60), "fria": Color(0.55, 0.59, 0.68),
			"tope": Color(0.80, 0.78, 0.72), "detalle": Color(0.85, 0.20, 0.20)},
		"pilar": {"estilo": "estandarte", "color": Color(0.60, 0.58, 0.55), "detalle": Color(0.85, 0.20, 0.20)},
		"particulas": {"tipo": "fragmentos", "color": Color(0.50, 0.85, 1.0)},
		"decorado": "torre", "acento": Color(0.85, 0.20, 0.20), "acento2": Color(0.20, 0.45, 0.90),
	},
	{
		"id": &"sotano", "nombre": "El Sotano", "lugar": "Debajo de la Arena, donde desperto el espiritu",
		"techo": Color(0.02, 0.03, 0.035),
		"niebla": [Color(0.08, 0.20, 0.20), 0.0115], "ambiente": 0.55, "ambiente_color": Color(0.25, 0.40, 0.42),
		"sol": [Color(0.50, 0.85, 0.85), 0.55, Vector3(-70.0, 20.0, 0.0)], "relleno": [Color(0.30, 0.95, 0.70), 0.30],
		"luces": {"centro": Color(0.35, 1.0, 0.80), "calida": Color(0.30, 0.95, 0.60), "fria": Color(0.35, 0.70, 1.0), "energia": 9.0},
		"piso": {"estilo": "roca", "a": Color(0.18, 0.19, 0.21), "b": Color(0.23, 0.23, 0.25), "marca": Color(0.30, 1.0, 0.80)},
		"pared": {"estilo": "caverna", "color": Color(0.17, 0.17, 0.19), "trim": Color(0.30, 1.0, 0.80)},
		"cobertura": {"estilo": "cripta", "calida": Color(0.30, 0.28, 0.27), "fria": Color(0.22, 0.25, 0.28),
			"tope": Color(0.34, 0.34, 0.35), "detalle": Color(0.30, 1.0, 0.80)},
		"pilar": {"estilo": "estalagmita", "color": Color(0.26, 0.25, 0.26), "detalle": Color(0.30, 1.0, 0.80)},
		"particulas": {"tipo": "espiritus", "color": Color(0.45, 1.0, 0.85)},
		"decorado": "caverna", "acento": Color(0.30, 1.0, 0.80), "acento2": Color(0.40, 0.30, 0.20),
	},
	{
		"id": &"inframundo", "nombre": "El Inframundo", "lugar": "Del otro lado de la grieta, donde arden las almas",
		"cielo": {"arriba": Color(0.08, 0.0, 0.01), "horizonte": Color(0.70, 0.14, 0.04),
			"suelo": Color(0.05, 0.0, 0.0), "energia": 1.1},
		"niebla": [Color(0.50, 0.12, 0.05), 0.0070], "ambiente": 0.38,
		"sol": [Color(1.0, 0.55, 0.30), 1.0, Vector3(-35.0, 140.0, 0.0)], "relleno": [Color(1.0, 0.30, 0.15), 0.40],
		"luces": {"centro": Color(1.0, 0.40, 0.10), "calida": Color(1.0, 0.45, 0.12), "fria": Color(1.0, 0.20, 0.10), "energia": 8.5},
		"piso": {"estilo": "lava", "a": Color(0.13, 0.10, 0.10), "b": Color(0.17, 0.12, 0.11), "marca": Color(1.0, 0.42, 0.08)},
		"pared": {"estilo": "volcan", "color": Color(0.10, 0.08, 0.08), "trim": Color(1.0, 0.42, 0.08)},
		"cobertura": {"estilo": "obsidiana", "calida": Color(0.20, 0.12, 0.10), "fria": Color(0.14, 0.11, 0.12),
			"tope": Color(0.26, 0.16, 0.13), "detalle": Color(1.0, 0.42, 0.08)},
		"pilar": {"estilo": "espina", "color": Color(0.14, 0.10, 0.10), "detalle": Color(1.0, 0.42, 0.08)},
		"particulas": {"tipo": "brasas", "color": Color(1.0, 0.50, 0.15)},
		"decorado": "volcan", "acento": Color(1.0, 0.42, 0.08), "acento2": Color(0.30, 0.25, 0.22),
	},
	{
		"id": &"vacio", "nombre": "El Vacio Infinito", "lugar": "Lo que se abrio en el centro de la Arena",
		"cielo": {"arriba": Color(0.0, 0.0, 0.02), "horizonte": Color(0.08, 0.04, 0.16),
			"suelo": Color(0.0, 0.0, 0.01), "energia": 0.8},
		"niebla": [Color(0.10, 0.08, 0.22), 0.0030], "ambiente": 0.40, "ambiente_color": Color(0.45, 0.50, 0.80),
		"sol": [Color(0.80, 0.85, 1.0), 0.95, Vector3(-60.0, 10.0, 0.0)], "relleno": [Color(0.55, 0.35, 1.0), 0.50],
		"luces": {"centro": Color(0.70, 0.85, 1.0), "calida": Color(0.70, 0.45, 1.0), "fria": Color(0.35, 0.60, 1.0), "energia": 8.0},
		"piso": {"estilo": "estrellas", "a": Color(0.04, 0.04, 0.08), "b": Color(0.06, 0.05, 0.11), "marca": Color(0.55, 0.75, 1.0)},
		"pared": {"estilo": "vacio", "color": Color(0.03, 0.03, 0.07), "trim": Color(0.55, 0.75, 1.0)},
		"cobertura": {"estilo": "vacio", "calida": Color(0.08, 0.07, 0.14), "fria": Color(0.06, 0.08, 0.14),
			"tope": Color(0.10, 0.10, 0.18), "detalle": Color(0.55, 0.75, 1.0)},
		"pilar": {"estilo": "obelisco", "color": Color(0.05, 0.05, 0.10), "detalle": Color(0.55, 0.75, 1.0)},
		"particulas": {"tipo": "estrellas", "color": Color(0.85, 0.90, 1.0)},
		"decorado": "vacio", "acento": Color(0.55, 0.75, 1.0), "acento2": Color(0.80, 0.40, 1.0),
	},
	{
		"id": &"helada", "nombre": "La Arena Helada", "lugar": "La ruta que nadie deberia haber tomado",
		"secreto": "snowgrave",
		"cielo": {"arriba": Color(0.22, 0.30, 0.46), "horizonte": Color(0.62, 0.70, 0.82),
			"suelo": Color(0.30, 0.36, 0.46), "energia": 0.85},
		"niebla": [Color(0.58, 0.66, 0.80), 0.0075], "ambiente": 0.40,
		"sol": [Color(0.85, 0.92, 1.0), 0.95, Vector3(-50.0, 20.0, 0.0)], "relleno": [Color(0.60, 0.75, 1.0), 0.45],
		"luces": {"centro": Color(0.55, 0.85, 1.0), "calida": Color(0.70, 0.90, 1.0), "fria": Color(0.45, 0.65, 1.0), "energia": 6.5},
		"piso": {"estilo": "hielo", "a": Color(0.50, 0.64, 0.80), "b": Color(0.58, 0.72, 0.87), "marca": Color(0.55, 0.85, 1.0)},
		"pared": {"estilo": "glaciar", "color": Color(0.42, 0.56, 0.74), "trim": Color(0.55, 0.85, 1.0)},
		"cobertura": {"estilo": "hielo", "calida": Color(0.46, 0.60, 0.78), "fria": Color(0.38, 0.52, 0.74),
			"tope": Color(0.84, 0.91, 1.0), "detalle": Color(0.74, 0.88, 1.0)},
		"pilar": {"estilo": "hielo", "color": Color(0.56, 0.74, 0.90), "detalle": Color(0.82, 0.93, 1.0)},
		"particulas": {"tipo": "ventisca", "color": Color(0.95, 0.97, 1.0)},
		"decorado": "glaciar", "acento": Color(0.55, 0.85, 1.0), "acento2": Color(0.30, 0.40, 0.55),
	},
	{
		"id": &"nucleo", "nombre": "El Nucleo", "lugar": "El corazon de la Arena, donde la gravedad se da vuelta",
		"cielo": {"arriba": Color(0.08, 0.03, 0.16), "horizonte": Color(0.58, 0.32, 0.72),
			"suelo": Color(0.06, 0.02, 0.10), "energia": 1.1},
		"niebla": [Color(0.40, 0.22, 0.55), 0.0045], "ambiente": 0.40,
		"sol": [Color(1.0, 0.85, 0.65), 1.0, Vector3(-45.0, -60.0, 0.0)], "relleno": [Color(0.75, 0.40, 1.0), 0.45],
		"luces": {"centro": Color(1.0, 0.80, 0.40), "calida": Color(1.0, 0.70, 0.35), "fria": Color(0.70, 0.40, 1.0), "energia": 8.0},
		"piso": {"estilo": "cristal", "a": Color(0.16, 0.10, 0.24), "b": Color(0.21, 0.13, 0.30), "marca": Color(1.0, 0.78, 0.35)},
		"pared": {"estilo": "cristal", "color": Color(0.20, 0.12, 0.30), "trim": Color(1.0, 0.78, 0.35)},
		"cobertura": {"estilo": "cristal", "calida": Color(0.36, 0.22, 0.48), "fria": Color(0.26, 0.20, 0.46),
			"tope": Color(0.46, 0.32, 0.60), "detalle": Color(0.85, 0.55, 1.0)},
		"pilar": {"estilo": "cristal", "color": Color(0.50, 0.30, 0.70), "detalle": Color(1.0, 0.78, 0.35)},
		"particulas": {"tipo": "escombros_arriba", "color": Color(0.85, 0.60, 1.0)},
		"decorado": "nucleo", "acento": Color(1.0, 0.78, 0.35), "acento2": Color(0.85, 0.55, 1.0),
	},
	{
		"id": &"cielo", "nombre": "El Cielo", "lugar": "Mas alla del cielo. Mas alla de todo",
		"secreto": "cielo",
		"cielo": {"arriba": Color(0.24, 0.42, 0.82), "horizonte": Color(0.95, 0.80, 0.58),
			"suelo": Color(0.70, 0.64, 0.56), "energia": 0.95},
		"niebla": [Color(0.88, 0.80, 0.66), 0.0026], "ambiente": 0.30,
		"sol": [Color(1.0, 0.92, 0.78), 0.95, Vector3(-38.0, 15.0, 0.0)], "relleno": [Color(1.0, 0.80, 0.55), 0.35],
		"luces": {"centro": Color(1.0, 0.88, 0.55), "calida": Color(1.0, 0.82, 0.45), "fria": Color(0.70, 0.85, 1.0), "energia": 6.0},
		"piso": {"estilo": "marmol", "a": Color(0.70, 0.66, 0.60), "b": Color(0.62, 0.58, 0.53), "marca": Color(1.0, 0.82, 0.35)},
		"pared": {"estilo": "nubes", "color": Color(0.78, 0.74, 0.68), "trim": Color(1.0, 0.82, 0.35)},
		"cobertura": {"estilo": "marmol", "calida": Color(0.78, 0.72, 0.62), "fria": Color(0.62, 0.66, 0.74),
			"tope": Color(0.86, 0.82, 0.74), "detalle": Color(0.95, 0.75, 0.30)},
		"pilar": {"estilo": "columna", "color": Color(0.84, 0.80, 0.74), "detalle": Color(0.95, 0.75, 0.30)},
		"particulas": {"tipo": "chispas_doradas", "color": Color(1.0, 0.90, 0.55)},
		"decorado": "nubes", "acento": Color(1.0, 0.82, 0.35), "acento2": Color(0.95, 0.95, 1.0),
	},
]


static func existe(id: StringName) -> bool:
	for m: Dictionary in LISTA:
		if m["id"] == id:
			return true
	return false


static func tema(id: StringName) -> Dictionary:
	for m: Dictionary in LISTA:
		if m["id"] == id:
			return m
	return LISTA[0]


static func actual() -> Dictionary:
	return tema(elegido)


static func nombre(id: StringName) -> String:
	return String(tema(id)["nombre"])


## Los que se pueden elegir en los modos normales. Los de una ruta secreta, recien cuando
## la ruta se abrio: si no, la sala contaria el secreto antes de tiempo.
static func disponibles() -> Array[StringName]:
	var ids: Array[StringName] = []
	for m: Dictionary in LISTA:
		var ruta := String(m.get("secreto", ""))
		if ruta != "" and not Progreso.ruta_abierta(ruta):
			continue
		ids.append(m["id"])
	return ids


## El de al lado en la lista de disponibles (las flechas de la sala).
static func siguiente(desde: StringName, paso: int = 1) -> StringName:
	var ids := disponibles()
	var i := ids.find(desde)
	if i < 0:
		return ids[0]
	return ids[(i + paso + ids.size()) % ids.size()]


## EL LUGAR DE CADA CAPITULO, por lo que cuenta la historia: Hometown es donde empieza
## (la nieve que sube); despues la Arena con el cielo roto, la torre del torneo, el sotano
## del espiritu, el Inframundo, el vacio que se abre en la parte 5, la Arena congelada de
## la ruta Snowgrave, el nucleo de la parte 6 y el cielo del diario de DIO.
static func de_capitulo(i: int) -> StringName:
	if i == 0:
		return &"hometown"
	var parte := Historia.parte_de(i)
	var titulo := String(Historia.PARTES[parte].get("titulo", "")) if parte >= 0 and parte < Historia.PARTES.size() else ""
	var ruta := String(Historia.PARTES[parte].get("ruta", "")) if parte >= 0 and parte < Historia.PARTES.size() else ""
	if ruta == "snowgrave":
		return &"helada"
	if ruta == "cielo":
		return &"cielo"
	if titulo.begins_with("PARTE 2"):
		return &"torre"
	if titulo.begins_with("PARTE 3"):
		return &"sotano"
	if titulo.begins_with("PARTE 4"):
		return &"inframundo"
	if titulo.begins_with("PARTE 5"):
		# La parte 5 pasa en la Arena hasta que en el centro se abre el vacio (el capitulo
		# "Vacio infinito"); de ahi al final, adentro del vacio.
		return &"vacio" if i >= Historia.primero_de(parte) + 8 else &"coliseo"
	if titulo.begins_with("PARTE 6"):
		return &"nucleo"
	return &"coliseo"
