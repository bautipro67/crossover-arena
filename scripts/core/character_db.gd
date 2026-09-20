extends Node
## Autoload: CharacterDB
## Registro de todos los personajes jugables.
##
## PARA SUMAR UN PERSONAJE DE OTRO JUEGO:
##   1. Escribi sus habilidades (extends Ability) en scripts/characters/<personaje>/
##   2. Agregale una entrada a _register_all() aca abajo.
## Nada mas. El lobby, el HUD y el selector se arman solos desde este registro.

var _characters: Dictionary = {}
var _order: Array[StringName] = []


func _ready() -> void:
	_register_all()


func _register_all() -> void:
	# ------------------------------------------------------------- Noelle
	var noelle := CharacterData.new()
	noelle.id = &"noelle"
	noelle.display_name = "Noelle Holiday"
	noelle.origin_game = "Deltarune"
	# Verde navideño apagado para el vestido, pelo pelirrojo claro.
	noelle.body_color = Color(0.36, 0.55, 0.47)
	noelle.accent_color = Color(0.93, 0.62, 0.42)
	noelle.skin_color = Color(0.99, 0.89, 0.80)
	noelle.max_health = 100.0
	noelle.max_stamina = 100.0
	noelle.move_speed = 6.0
	noelle.silhouette = &"antlers"
	_add(noelle)

	# ---------------------------------------------------------------- Dio Brando
	# Contrapeso de Noelle: ella controla de lejos y necesita setup, el pelea de
	# cerca y su ultimate le abre una ventana que tiene que aprovechar a mano.
	# Va un poco mas rapido porque su trabajo es cerrar distancia.
	var dio := CharacterData.new()
	dio.id = &"dio"
	dio.display_name = "Dio Brando"
	dio.origin_game = "JoJo's Bizarre Adventure"
	# Amarillo tostado y dorado. Piel palida de vampiro.
	dio.body_color = Color(0.86, 0.72, 0.36)
	dio.accent_color = Color(0.88, 0.66, 0.16)
	dio.skin_color = Color(0.94, 0.86, 0.82)
	dio.max_health = 100.0
	dio.max_stamina = 100.0
	dio.move_speed = 6.6
	dio.silhouette = &"shoulders"
	_add(dio)

	# ------------------------------------------------------------------- Flowery
	# El tercer vertice del roster. Noelle controla de lejos y prepara; Dio entra y
	# revienta de cerca; Flowery hostiga a media distancia y, sobre todo, ES LA UNICA
	# QUE CORTA CANALIZADOS. Sin ella, un Snowgrave o un ZA WARUDO empezado solo se
	# podia frenar congelando al que lo tiraba o rompiendo la linea de vision.
	#
	# Es el mas fragil (88 de vida) porque tiene el unico ataque basico a distancia del
	# juego y una carga para entrar y salir: si ademas aguantara como los otros, no
	# habria forma de castigarle el hostigamiento.
	var flowery := CharacterData.new()
	flowery.id = &"flowery"
	flowery.display_name = "Flowery"
	flowery.origin_game = "Deltarune"
	# Camisa BLANCA (el chaleco verde y marron lo pone la silueta encima), pelo rubio
	# y piel amarillenta, como en el Dark World.
	flowery.body_color = Color(0.94, 0.94, 0.92)
	flowery.accent_color = Color(0.98, 0.86, 0.36)
	flowery.skin_color = Color(0.99, 0.92, 0.76)
	flowery.max_health = 88.0
	flowery.max_stamina = 100.0
	flowery.move_speed = 6.3
	flowery.silhouette = &"petals"
	_add(flowery)


func _add(data: CharacterData) -> void:
	_characters[data.id] = data
	if not _order.has(data.id):
		_order.append(data.id)


func get_character(id: StringName) -> CharacterData:
	if _characters.has(id):
		return _characters[id]
	# Fallback: si piden un id que no existe devolvemos el primero para no crashear.
	if _order.is_empty():
		return null
	return _characters[_order[0]]


func get_all_ids() -> Array[StringName]:
	return _order.duplicate()


func get_default_id() -> StringName:
	return _order[0] if not _order.is_empty() else &"noelle"


func has_character(id: StringName) -> bool:
	return _characters.has(id)


## Construye instancias NUEVAS de las habilidades del personaje.
## Importante que sean nuevas por jugador: cada uno lleva su propio estado de cooldown
## en el AbilityCaster, pero compartir Resources entre jugadores pide problemas.
func build_abilities_for(id: StringName) -> Array[Ability]:
	var list: Array[Ability] = []
	# EL ORDEN ES EL DEL HUD Y EL DE LAS TECLAS:
	#   0 = click izquierdo   1 = click derecho   2 = E   3 = Q (ultimate)
	# El ultimate va siempre ultimo.
	match id:
		&"noelle":
			list.append(NoelleBasicAttack.new())
			list.append(IceShock.new())
			list.append(IceDefense.new())
			list.append(Snowgrave.new())
		&"dio":
			list.append(MudaRush.new())
			list.append(KnifeThrow.new())
			list.append(StandBarrage.new())
			list.append(ZaWarudo.new())
		&"flowery":
			list.append(PetalShot.new())
			list.append(Jarona.new())
			list.append(HereICome.new())
			list.append(LastJarona.new())
		_:
			list.append(NoelleBasicAttack.new())
	return list
