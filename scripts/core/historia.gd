class_name Historia
extends RefCounted
## El modo historia. PARTE 1: LA GRIETA. Diez capitulos.
##
## LA TRAMA. Rick rompe la pared entre los mundos arreglando su pistola de portales, y del
## otro lado hay algo viejo: la Arena, un coliseo entre mundos que VIVE DE LAS PELEAS. Por
## eso tira gente adentro, y por eso fabrica ecos —copias oscuras de los que pelean ahi—:
## para que nunca falte con quien pelear. Su nucleo guarda la energia de mil años de
## combates, y el que lo controle abre puertas a todos los mundos que toco la grieta.
##
## Dio llego primero y lo entendio primero: quiere el nucleo para quedarse con todos esos
## mundos, que es su idea del cielo. Usa a Flowery prometiendole lo unico que Flowery
## quiere —una luz que no se apague, para que su reino de flores no se muera en la
## oscuridad y Asgore sea feliz—. Noelle, Rick y Sonic caen en el medio.
##
## LAS PERSONALIDADES SALEN DE LAS OBRAS, no de lo que le sirve a la trama:
##   Noelle   timida, educada, pide perdon por todo; valiente cuando hay que cuidar a
##            alguien. Extraña a su papa, a Susie y a Kris.
##   Rick     cinico, genio, eructa, dice que no le importa nada y termina ayudando.
##            Le dice "Morty" a quien tenga al lado.
##   Sonic    canchero y libre, odia que lo encierren, "demasiado lento", le echa la
##            culpa a Eggman de todo lo raro.
##   Flowery  la Flor Dorada del ramo de casamiento de Asgore: un fiestero de los setenta
##            ("¡Jarona!", "San Fransdisco") con complejo de inferioridad, que hace todo
##            por Asgore y su reino de flores. Manipula, pero por amor.
##   Dio      grandilocuente y cruel; "insectos", "inutil", "¡fui yo, DIO!". Cree que el
##            poder lo justifica todo.
##   Goku     aparece al final: contento, con hambre, y con ganas de pelear con alguien
##            fuerte. Abre la parte 2.
##
## TODO LO QUE SE DICE ES ORIGINAL. De las obras salen los personajes y las frases que son
## su marca, nada mas.
##
## CADA CAPITULO: personaje, aliados, enemigos, objetivo, eventos, y las escenas de
## entrada y salida. El formato de las escenas esta en Cinematica, y el de la pelea en
## MisionHistoria. Las posiciones son (x, z) desde el jugador; adelante es z negativo.

const PARTE: String = "PARTE 1: LA GRIETA"
const NARRADOR: StringName = &"narrador"


## Un eco, en una linea: los hay en casi todos los capitulos.
static func _eco(id: String, personaje: StringName, pos: Vector2, vida: float = 40.0,
		daño: float = 0.22, oculto: bool = true) -> Dictionary:
	return {"id": StringName(id), "personaje": personaje, "nombre": "Eco", "vida": vida,
		"daño": daño, "pos": pos, "eco": true, "oculto": oculto}


static func _aliado(personaje: StringName, nombre: String, pos: Vector2, vida: float = 100.0,
		daño: float = 0.55) -> Dictionary:
	return {"id": personaje, "personaje": personaje, "nombre": nombre, "vida": vida,
		"daño": daño, "pos": pos}


static var _capitulos: Array[Dictionary] = []


static func cantidad() -> int:
	return _todos().size()


static func capitulo(i: int) -> Dictionary:
	var t := _todos()
	if i < 0 or i >= t.size():
		return {}
	return t[i]


## El nombre de quien habla, para los carteles.
static func nombre_de(hablante: StringName) -> String:
	if hablante == NARRADOR:
		return ""
	if not CharacterDB.has_character(hablante):
		return String(hablante)
	return CharacterDB.get_character(hablante).display_name


static func _todos() -> Array[Dictionary]:
	if _capitulos.is_empty():
		_capitulos = _armar()
	return _capitulos


static func _armar() -> Array[Dictionary]:
	var c: Array[Dictionary] = []

	# ------------------------------------------------------------------- 1
	c.append({
		"titulo": "Nieve hacia arriba",
		"personaje": &"noelle",
		"enemigos": [
			_eco("eco1", &"rick", Vector2(-4, -10)),
			_eco("eco2", &"sonic", Vector2(0, -12)),
			_eco("eco3", &"dio", Vector2(4, -10)),
		],
		"objetivo": {"tipo": "derrotar_todos", "texto": "Derrotá a los ecos"},
		"eventos": [
			[["inicio"], [["decir", &"noelle", "Tranquila, Noelle. Es como en el Mundo Oscuro. Vos podés."]]],
			[["tiempo", 3.0], [["decir", NARRADOR, "Cada golpe deja al rival tambaleando un instante: encadená el golpe básico con tus habilidades antes de que se reponga."]]],
			[["quedan", 1], [["decir", &"noelle", "¡Queda uno! ...Ay, perdón, no quería gritar."]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["pose", &"noelle", &"tirado"],
			["plano", "libre", Vector3(0, 9, 6), Vector3(0, 0, 0), Vector3(0, -0.4, -0.3)],
			["narrar", "Hometown, una noche de diciembre. Noelle volvía de visitar a su papá en el hospital cuando la nieve empezó a caer hacia arriba."],
			["narrar", "Después, nada. Después, esto."],
			["pose", &"noelle", &""],
			["esperar", 0.8],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¿E-eh...? ¿Dónde...? Esto no es Hometown."],
			["decir", &"noelle", "El cielo está... roto. ¿Kris? ¿Susie? ¡¿Hay alguien?!"],
			["aparecer", &"eco1", &"rick", Vector2(-4, -10), "sombra"],
			["aparecer", &"eco2", &"sonic", Vector2(0, -12), "sombra"],
			["aparecer", &"eco3", &"dio", Vector2(4, -10), "sombra"],
			["plano", "general"],
			["narrar", "Tres siluetas salen del piso. Tienen forma de persona, pero no tienen cara."],
			["plano", "cerca", &"noelle"],
			["pose", &"noelle", &"desafio", 2.0],
			["decir", &"noelle", "N-no se acerquen... ¡Perdón! Pero en serio: no se acerquen."],
		],
		"outro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Se... se deshicieron como nieve. ¿Qué eran?"],
			["aparecer", &"rick", &"rick", Vector2(5, -3), "portal"],
			["mirar", &"noelle", &"rick"],
			["mirar", &"rick", &"noelle"],
			["plano", "abajo", &"rick"],
			["decir", &"rick", "Ecos. Copias de pelea. Este lugar las fabrica con lo que le sobra a cada uno que cae."],
			["decir", &"noelle", "¿Y usted quién es?"],
			["pose", &"rick", &"brazos_cruzados", 3.0],
			["decir", &"rick", "Alguien que no confía en nada que aparece de la nada. *burp* Como vos."],
		],
	})

	# ------------------------------------------------------------------- 2
	c.append({
		"titulo": "El tipo del portal",
		"personaje": &"noelle",
		"enemigos": [
			{"id": &"rick", "personaje": &"rick", "nombre": "Rick", "vida": 120.0, "daño": 0.5,
				"pos": Vector2(0, -9), "jefe": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"rick", "hasta": 0.5, "texto": "Demostrale a Rick que sos real"},
		"eventos": [
			[["tiempo", 2.0], [["decir", NARRADOR, "Rick pega de lejos pero es frágil: pegate a él y no le des espacio. Con bajarle la mitad alcanza."]]],
			[["vida", &"rick", 0.8], [["decir", &"rick", "Okay, pegás fuerte para ser una alucinación."]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"rick", Vector2(0, -6), 180.0],
			["mirar", &"rick", &"noelle"],
			["plano", "dos", &"noelle", &"rick"],
			["decir", &"rick", "Mirá vos. Los ecos cada vez salen mejor. Este hasta tiene cara de asustado."],
			["decir", &"noelle", "¡No soy un eco! Me llamo Noelle Holiday, soy de Hometown, y—"],
			["plano", "cerca", &"rick"],
			["pose", &"rick", &"pensar", 3.0],
			["decir", &"rick", "Eso es exactamente lo que diría un eco programado para decir eso."],
			["decir", &"rick", "Te propongo algo científico: te pego. Si te deshacés, eras un eco."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¡¿Y si no me deshago?!"],
			["decir", &"rick", "Entonces te pido perdón. Probablemente. No es algo que haga seguido."],
		],
		"outro": [
			["colocar", &"rick", Vector2(0, -4), 180.0],
			["mirar", &"rick", &"noelle"],
			["mirar", &"noelle", &"rick"],
			["pose", &"rick", &"dolor", 0.8],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "¡Okay, okay! Los ecos no piden perdón cada vez que pegan. Sos real."],
			["decir", &"noelle", "P-perdón por lo del hielo... ¿Está bien?"],
			["decir", &"rick", "Estuve peor. Una vez fui un pepinillo."],
			["plano", "general"],
			["decir", &"rick", "Ya que estamos siendo honestos: esto es culpa mía. Arreglando la pistola de portales armé un estabilizador dimensional, y... se desestabilizó."],
			["decir", &"rick", "Abrió una grieta entre los mundos. Y del otro lado estaba esto: la Arena. Un coliseo viejo que vive de las peleas."],
			["decir", &"noelle", "¿Vive de... las peleas?"],
			["decir", &"rick", "Cada pelea la alimenta. Por eso tira gente adentro, y por eso fabrica ecos: para que nunca falte con quién pelear."],
			["decir", &"rick", "Si encuentro su núcleo, cierro la grieta. Pero necesito un rastreador. Y alguien que me cubra mientras lo armo."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Yo... yo puedo ayudar. Quiero volver a casa."],
			["decir", &"rick", "Genial. Una ayudante. Vamos, Morty— digo, Noelle."],
		],
	})

	# ------------------------------------------------------------------- 3
	c.append({
		"titulo": "Taller de chatarra",
		"personaje": &"noelle",
		"aliados": [
			{"id": &"rick", "personaje": &"rick", "nombre": "Rick", "vida": 110.0, "daño": 0.5,
				"pos": Vector2(0, 3), "quieto": true, "pose": &"pensar"},
		],
		"enemigos": [
			_eco("eco1", &"noelle", Vector2(-5, -12)),
			_eco("eco2", &"flowery", Vector2(5, -12)),
		],
		"objetivo": {"tipo": "proteger", "id": &"rick", "segundos": 45.0, "texto": "Protegé a Rick mientras arma el rastreador"},
		"eventos": [
			[["inicio"], [["decir", &"rick", "Cuarenta y cinco segundos. Si me pegan, empiezo de cero. Y vos también."]]],
			[["tiempo", 15.0], [
				["refuerzos", [_eco("eco3", &"sonic", Vector2(-8, -14), 40.0, 0.22, false),
					_eco("eco4", &"dio", Vector2(8, -14), 40.0, 0.22, false)]],
				["decir", &"rick", "¡Vienen más! ¿Sabés lo que cuesta un condensador de materia oscura? Yo tampoco. Lo robé."]]],
			[["tiempo", 30.0], [
				["refuerzos", [_eco("eco5", &"rick", Vector2(0, -16), 40.0, 0.22, false)]],
				["decir", &"noelle", "¡Ese es igual a usted!"],
				["decir", &"rick", "Pobre. Tiene toda mi inteligencia y nada de mi encanto."]]],
			[["vida", &"rick", 0.5], [["decir", &"rick", "¡Noelle! ¡Me están haciendo agujeros en la bata!"]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(1.5, 0), 0.0],
			["colocar", &"rick", Vector2(0, 3), 0.0],
			["pose", &"rick", &"pensar"],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Un condensador de materia oscura, dos cables y un tostador. Con eso armo un rastreador."],
			["decir", &"noelle", "¿Un tostador?"],
			["decir", &"rick", "Los tostadores están subestimados, Noelle. Ahora callate y vigilá."],
			["aparecer", &"eco1", &"noelle", Vector2(-5, -12), "sombra"],
			["aparecer", &"eco2", &"flowery", Vector2(5, -12), "sombra"],
			["plano", "general"],
			["decir", &"noelle", "Rick... uno de esos tiene mi forma."],
			["decir", &"rick", "Los ecos copian a los que pelean acá. Felicitaciones: ya sos parte del menú."],
			["plano", "cerca", &"noelle"],
			["pose", &"noelle", &"desafio", 1.8],
			["decir", &"noelle", "Nadie lo va a tocar. Se lo prometo."],
		],
		"outro": [
			["colocar", &"rick", Vector2(0, 3), 0.0],
			["pose", &"rick", &"victoria", 1.8],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "¡Listo! Wubba lubba dub dub. El rastreador funciona."],
			["decir", &"rick", "Dos señales. Una enorme, en el centro de la Arena: el núcleo."],
			["pose", &"rick", &"pensar", 3.0],
			["decir", &"rick", "La otra se mueve. Rapidísimo. Cruzó el mapa tres veces mientras hablábamos."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¿Otra persona que cayó como yo?"],
			["decir", &"rick", "O un problema con piernas. Vamos a averiguarlo."],
		],
	})

	# ------------------------------------------------------------------- 4
	c.append({
		"titulo": "Algo azul",
		"personaje": &"sonic",
		"enemigos": [
			{"id": &"flowery", "personaje": &"flowery", "nombre": "Flowery", "vida": 95.0,
				"daño": 0.25, "pos": Vector2(0, -10), "jefe": true, "oculto": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"flowery", "texto": "Derrotá a Flowery"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "Flowery embiste hasta que lo esquivás: esperá la embestida, salí de costado y castigalo."]]],
			[["vida", &"flowery", 0.5], [
				["cinematica", [
					["plano", "cerca", &"flowery"],
					["decir", &"flowery", "¿Que una flor no sirve para nada? ¡Ahora vas a ver lo que brilla una flor!"],
					["grito", &"flowery", "¡HERE I COME, SAN FRANSDISCO!", &"voz_here_i_come"],
				]],
				["potenciar", &"flowery", 14.0]]],
		],
		"intro": [
			["colocar", &"sonic", Vector2(-9, 4), 60.0],
			["plano", "libre", Vector3(6, 2.5, 6), Vector3(-3, 1, 1)],
			["mover", &"sonic", Vector2(0, 0)],
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "¡Wooo! ¿Qué es este lugar? Rampas, pistas, nadie que me pida que frene..."],
			["decir", &"sonic", "Aunque ese cielo roto tiene cara de máquina de Eggman. Siempre es Eggman."],
			["aparecer", &"flowery", &"flowery", Vector2(0, -7), "teletransporte"],
			["mirar", &"flowery", &"sonic"],
			["plano", "abajo", &"flowery"],
			["pose", &"flowery", &"saludo", 1.8],
			["decir", &"flowery", "¡Qué onda, qué onda! ¡Qué velocidad más groovy tenés, amigo!"],
			["decir", &"sonic", "¡Gracias! Vos tenés... un chaleco muy verde."],
			["decir", &"flowery", "Me dijeron que acá, el que junta más peleas, consigue lo que más quiere."],
			["decir", &"flowery", "Y yo quiero algo MUY grande. Así que voy a necesitar tu pelea. Con todo respeto."],
			["grito", &"flowery", "¡JARONA!", &"voz_jarona"],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "¿Una pelea? ¡Dale! Pero te aviso: sos demasiado lento."],
		],
		"outro": [
			["colocar", &"flowery", Vector2(0, -4), 180.0],
			["mirar", &"flowery", &"sonic"],
			["mirar", &"sonic", &"flowery"],
			["pose", &"flowery", &"tirado", 1.5],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "Buena pelea, en serio. ¿Por qué tanta fuerza por una pelea?"],
			["pose", &"flowery", &""],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Porque alguien me cuidó cuando yo no era más que una flor en un ramo. Asgore."],
			["decir", &"flowery", "Mi reino, el de las flores, vive en la oscuridad. Y las flores no duran sin luz."],
			["decir", &"flowery", "Un señor muy elegante me prometió una luz que no se apaga nunca. Si le junto peleas."],
			["plano", "dos", &"sonic", &"flowery"],
			["decir", &"sonic", "Nadie que encierra gente en un lugar así cumple lo que promete. Te lo digo por experiencia."],
			["aparecer", &"noelle", &"noelle", Vector2(6, 2), "portal"],
			["aparecer", &"rick", &"rick", Vector2(7.5, 3), "portal"],
			["plano", "general"],
			["decir", &"rick", "Ahí está la señal rápida. Es un erizo. Claro que es un erizo."],
			["decir", &"sonic", "¡Hola! Soy Sonic. ¿Ustedes también se cayeron del cielo?"],
		],
	})

	# ------------------------------------------------------------------- 5
	c.append({
		"titulo": "Luz para siempre",
		"personaje": &"flowery",
		"aliados": [_aliado(&"sonic", "Sonic", Vector2(2.5, 1.5), 90.0, 0.55)],
		"enemigos": [
			_eco("e1", &"dio", Vector2(0, -11), 44.0, 0.24),
			_eco("e2", &"rick", Vector2(-5, -12), 44.0, 0.24),
			_eco("e3", &"noelle", Vector2(5, -12), 44.0, 0.24),
		],
		"objetivo": {"tipo": "derrotar_todos", "texto": "Derrotá a los ecos del señor elegante"},
		"eventos": [
			[["inicio"], [["decir", &"sonic", "¡Vamos, flor! ¡Demasiado lentos, todos!"]]],
			[["quedan", 0], [
				["decir", &"flowery", "¡Vienen más! ¿No se cansan nunca de la fiesta?"],
				["refuerzos", [_eco("e4", &"dio", Vector2(-6, -13), 44.0, 0.24, false),
					_eco("e5", &"sonic", Vector2(0, -14), 44.0, 0.24, false),
					_eco("e6", &"flowery", Vector2(6, -13), 44.0, 0.24, false)]]]],
			[["muere", &"sonic"], [["decir", &"flowery", "¡Sonic! Tranquilo, amigo... ¡yo me encargo!"]]],
		],
		"intro": [
			["colocar", &"flowery", Vector2(0, 0), 0.0],
			["colocar", &"sonic", Vector2(2.5, 1.5), 0.0],
			["plano", "cerca", &"flowery"],
			["pose", &"flowery", &"pensar", 3.0],
			["decir", &"flowery", "Si el señor elegante se entera de que perdí... bueno. No creo que se entere."],
			["aparecer", &"e1", &"dio", Vector2(0, -11), "sombra"],
			["aparecer", &"e2", &"rick", Vector2(-5, -12), "sombra"],
			["aparecer", &"e3", &"noelle", Vector2(5, -12), "sombra"],
			["plano", "general"],
			["decir", &"sonic", "Creo que se enteró."],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Me mandó sus ecos. A mí. Después de todas las peleas que le junté."],
			["mirar", &"sonic", &"flowery"],
			["plano", "dos", &"flowery", &"sonic"],
			["decir", &"sonic", "Ey. Yo corro, vos embestís. ¿Hacemos equipo?"],
			["decir", &"flowery", "¿Equipo? ...¡Equipo! ¡Qué onda más linda! ¡JARONA!"],
		],
		"outro": [
			["colocar", &"flowery", Vector2(0, 0), 0.0],
			["colocar", &"sonic", Vector2(2, 1), -30.0],
			["mirar", &"sonic", &"flowery"],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Si él no me va a dar la luz... ¿quién va a salvar mi reino?"],
			["aparecer", &"noelle", &"noelle", Vector2(-3, 2), "portal"],
			["mirar", &"noelle", &"flowery"],
			["mirar", &"flowery", &"noelle"],
			["plano", "dos", &"noelle", &"flowery"],
			["decir", &"noelle", "N-nosotros podemos buscar otra forma. Juntos. Si usted quiere."],
			["decir", &"flowery", "¿Juntos? Nadie me decía juntos desde... desde Asgore."],
			["aparecer", &"rick", &"rick", Vector2(-4.5, 3), "portal"],
			["plano", "general"],
			["decir", &"rick", "Qué lindo todo. Mientras ustedes se abrazan, el rastreador marca algo raro en el centro."],
		],
	})

	# ------------------------------------------------------------------- 6
	c.append({
		"titulo": "La señal",
		"personaje": &"rick",
		"aliados": [
			_aliado(&"noelle", "Noelle", Vector2(-2.5, 1.5), 100.0, 0.55),
			_aliado(&"flowery", "Flowery", Vector2(2.5, 1.5), 95.0, 0.55),
		],
		"enemigos": [
			_eco("e1", &"sonic", Vector2(-6, -18), 40.0, 0.22),
			_eco("e2", &"dio", Vector2(6, -18), 40.0, 0.22),
		],
		"objetivo": {"tipo": "zona", "centro": Vector2(0, -12), "radio": 6.0, "segundos": 30.0,
			"texto": "Mantené el rastreador dentro de la señal"},
		"eventos": [
			[["inicio"], [["decir", &"rick", "Adentro del círculo, gente. Yo no me muevo de ahí ni aunque me paguen."]]],
			[["tiempo", 10.0], [
				["refuerzos", [_eco("e3", &"rick", Vector2(0, -22), 40.0, 0.22, false),
					_eco("e4", &"noelle", Vector2(-9, -10), 40.0, 0.22, false)]],
				["decir", &"flowery", "¡Más invitados a la fiesta!"]]],
			[["tiempo", 20.0], [
				["refuerzos", [_eco("e5", &"flowery", Vector2(9, -10), 40.0, 0.22, false)]],
				["decir", &"noelle", "¡Ya casi, Rick! ¡Aguante!"]]],
		],
		"intro": [
			["colocar", &"rick", Vector2(0, 0), 0.0],
			["colocar", &"noelle", Vector2(-2.5, 1.5), 0.0],
			["colocar", &"flowery", Vector2(2.5, 1.5), 0.0],
			["plano", "cerca", &"rick"],
			["pose", &"rick", &"pensar", 3.0],
			["decir", &"rick", "La señal del núcleo pasa por ahí adelante. Si me quedo adentro treinta segundos, el rastreador aprende el camino."],
			["decir", &"flowery", "¡Treinta segundos! Eso es una canción entera. Una cortita."],
			["decir", &"noelle", "¿Y los ecos? Siempre aparecen justo cuando estamos por lograr algo."],
			["plano", "general"],
			["decir", &"rick", "Para eso los traje. Yo soy el cerebro. Ustedes son... los otros órganos."],
			["aparecer", &"e1", &"sonic", Vector2(-6, -18), "sombra"],
			["aparecer", &"e2", &"dio", Vector2(6, -18), "sombra"],
		],
		"outro": [
			["colocar", &"rick", Vector2(0, -12), 0.0],
			["plano", "cerca", &"rick"],
			["pose", &"rick", &"pensar", 2.5],
			["decir", &"rick", "Lo tengo. El camino al núcleo. Y algo más..."],
			["decir", &"rick", "La energía del núcleo está bajando. Alguien lo está chupando como si fuera un jugo."],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "El señor elegante. Siempre decía que el núcleo iba a ser \"su cielo\"."],
			["plano", "general"],
			["narrar", "En el centro de la Arena, el tiempo empieza a tartamudear."],
		],
	})

	# ------------------------------------------------------------------- 7
	c.append({
		"titulo": "El mundo se detiene",
		"personaje": &"noelle",
		# Los tres que ZA WARUDO deja tirados en la escena. Estan en el capitulo —de reserva,
		# sin pelear— para que sigan tirados DURANTE la pelea: como actores de escena nada
		# mas, desaparecian al empezar la pelea y volvian a aparecer, tirados, en la final.
		"aliados": [
			{"id": &"rick_", "personaje": &"rick", "nombre": "Rick", "vida": 90.0, "daño": 0.5,
				"pos": Vector2(-2.5, 1), "reserva": true},
			{"id": &"sonic_", "personaje": &"sonic", "nombre": "Sonic", "vida": 90.0, "daño": 0.5,
				"pos": Vector2(2.5, 1), "reserva": true},
			{"id": &"flowery_", "personaje": &"flowery", "nombre": "Flowery", "vida": 90.0, "daño": 0.5,
				"pos": Vector2(4, 2.5), "reserva": true},
		],
		"enemigos": [
			{"id": &"dio", "personaje": &"dio", "nombre": "DIO", "vida": 400.0, "daño": 0.6,
				"pos": Vector2(0, -8), "jefe": true},
		],
		"objetivo": {"tipo": "sobrevivir", "segundos": 35.0, "texto": "Aguantá frente a DIO"},
		"eventos": [
			[["inicio"], [["retirar", &"rick_"], ["retirar", &"sonic_"], ["retirar", &"flowery_"],
				["decir", NARRADOR, "No hace falta ganarle: aguantá. Cuando grite ZA WARUDO, alejate."]]],
			[["tiempo", 12.0], [["decir", &"dio", "¡MUDA MUDA MUDA! ¡Inútil! ¡Todo lo que hacés es inútil!"]]],
			[["tiempo", 24.0], [["decir", &"noelle", "No es inútil... ¡no es inútil si los protege!"]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["aparecer", &"rick_", &"rick", Vector2(-2.5, 1), ""],
			["aparecer", &"sonic_", &"sonic", Vector2(2.5, 1), ""],
			["aparecer", &"flowery_", &"flowery", Vector2(4, 2.5), ""],
			["colocar", &"dio", Vector2(0, -8), 180.0],
			["plano", "general"],
			["narrar", "El centro de la Arena. Una escalera que no lleva a ningún lado, y arriba, alguien esperando."],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"brazos_cruzados"],
			["decir", &"dio", "Así que ustedes son los insectos que andan rompiendo mis ecos."],
			["decir", &"flowery_", "Señor elegante... usted me prometió la luz."],
			["decir", &"dio", "Y cumplí. Te iluminé sobre lo útil que podías ser, flor. Ya no lo sos."],
			["plano", "cerca", &"sonic_"],
			["decir", &"sonic_", "¿Vos sos el que encierra gente acá? Tenés cara de Eggman, pero con mejor pelo."],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "¿Oh? ¿Se me acercan? En vez de escapar, vienen directo hacia mí."],
			["pose", &"dio", &""],
			["habilidad", &"dio", &"za_warudo"],
			["grito", &"dio", "¡ZA WARUDO!", &"voz_za_warudo"],
			["pose", &"rick_", &"tirado"],
			["pose", &"sonic_", &"tirado"],
			["pose", &"flowery_", &"tirado"],
			["temblor", 1.4],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¿Q-qué pasó? ¡Estaban parados hace un segundo!"],
			["decir", &"dio", "El tiempo se detuvo. Para ellos. Vos, niña... vos ni siquiera valés el esfuerzo."],
			["pose", &"noelle", &"desafio", 1.8],
			["decir", &"noelle", "Ellos me ayudaron. No los voy a dejar solos."],
		],
		"outro": [
			["colocar", &"dio", Vector2(0, -7), 180.0],
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["mirar", &"noelle", &"dio"],
			["aparecer", &"rick_", &"rick", Vector2(-2.5, 1), ""],
			["aparecer", &"sonic_", &"sonic", Vector2(2.5, 1), ""],
			["aparecer", &"flowery_", &"flowery", Vector2(4, 2.5), ""],
			["pose", &"rick_", &"tirado"],
			["pose", &"sonic_", &"tirado"],
			["pose", &"flowery_", &"tirado"],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "Suficiente. Me aburrís. Treinta y cinco segundos de una niña que tiembla."],
			["decir", &"dio", "Cuando termine de absorber el núcleo, cada mundo que tocó la grieta va a ser mío. Ese es mi cielo."],
			["desaparecer", &"dio", "sombra"],
			["pose", &"rick_", &""],
			["pose", &"sonic_", &""],
			["pose", &"flowery_", &""],
			["esperar", 0.8],
			["plano", "general"],
			["decir", &"rick_", "Bueno. Ahora tenemos un vampiro con un plan de negocios. Excelente."],
			["decir", &"sonic_", "Cuando me paró el tiempo sentí algo raro. Como si la Arena se riera."],
			["decir", &"flowery_", "Me mintió. Y yo le traje todo. Todas las peleas."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Entonces lo vamos a arreglar. Todos juntos. ...¿Sí?"],
		],
	})

	# ------------------------------------------------------------------- 8
	c.append({
		"titulo": "El eco sin nombre",
		"personaje": &"sonic",
		"aliados": [_aliado(&"flowery", "Flowery", Vector2(2.5, 1.5), 100.0, 0.55)],
		"enemigos": [
			{"id": &"desconocido", "personaje": &"goku", "nombre": "???", "vida": 170.0, "daño": 0.44,
				"pos": Vector2(0, -10), "jefe": true, "eco": true, "oculto": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"desconocido", "texto": "Derrotá al eco sin nombre"},
		"eventos": [
			[["inicio"], [["decir", &"flowery", "¡Sonic, yo embisto por la izquierda! ¡Vos corré!"]]],
			[["vida", &"desconocido", 0.6], [["decir", &"sonic", "¡Cuidado! ¡Está juntando energía en las manos!"]]],
			[["vida", &"desconocido", 0.35], [
				["cinematica", [
					["plano", "cerca", &"desconocido"],
					["narrar", "El eco sin cara grita algo que ninguno entiende. El aire se pone pesado."],
					["habilidad", &"desconocido", &"kamehameha"],
				]],
				["potenciar", &"desconocido", 12.0]]],
		],
		"intro": [
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["colocar", &"flowery", Vector2(2.5, 1.5), 0.0],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "El rastreador de Rick marca un eco solo, enorme, por acá. ¿Uno solo? Facilísimo."],
			["temblor", 0.8],
			["aparecer", &"desconocido", &"goku", Vector2(0, -10), "sombra"],
			["plano", "abajo", &"desconocido"],
			["pose", &"desconocido", &"desafio", 2.2],
			["decir", &"flowery", "Ese pelo... no es de ninguno de nosotros."],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "Un eco de alguien que todavía no llegó. ¿La Arena ya lo está esperando?"],
			["decir", &"flowery", "Entonces el original tiene que ser muy fuerte. Y muy despeinado."],
		],
		"outro": [
			["colocar", &"desconocido", Vector2(0, -6), 180.0],
			["pose", &"desconocido", &"tirado"],
			["plano", "general"],
			["narrar", "El eco se deshace en luz. Por un segundo, deja ver una sonrisa."],
			["desaparecer", &"desconocido", "sombra"],
			["aparecer", &"rick", &"rick", Vector2(-3, 2), "portal"],
			["decir", &"rick", "Si eso era la copia, no quiero conocer al original. Bueno, sí. Para estudiarlo."],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "Sea quien sea, viene para acá. Y más vale que llegue del lado de los buenos."],
		],
	})

	# ------------------------------------------------------------------- 9
	c.append({
		"titulo": "Los guardianes",
		"personaje": &"noelle",
		"aliados": [
			_aliado(&"sonic", "Sonic", Vector2(2.5, 1.5), 90.0, 0.5),
			_aliado(&"rick", "Rick", Vector2(-2.5, 1.5), 90.0, 0.5),
		],
		"enemigos": [
			_eco("e1", &"dio", Vector2(-6, -12), 46.0, 0.24),
			_eco("e2", &"flowery", Vector2(6, -12), 46.0, 0.24),
			_eco("e3", &"goku", Vector2(0, -15), 46.0, 0.24),
			_eco("e4", &"rick", Vector2(0, -10), 46.0, 0.24),
		],
		"objetivo": {"tipo": "derrotar_todos", "texto": "Abrite paso hasta el núcleo", "limite": 150.0},
		"eventos": [
			[["inicio"], [["decir", &"sonic", "¡Carrera hasta el núcleo! ¡El último paga los chili dogs!"]]],
			[["quedan", 1], [
				["refuerzos", [_eco("e5", &"sonic", Vector2(-8, -16), 46.0, 0.24, false),
					_eco("e6", &"noelle", Vector2(8, -16), 46.0, 0.24, false),
					_eco("e7", &"dio", Vector2(0, -18), 46.0, 0.24, false)]],
				["decir", &"rick", "¡Genial! Refuerzos. Me encanta cuando el universo me odia."]]],
			[["muere", &"rick"], [["decir", &"noelle", "¡Rick! ...Aguante, ya casi llegamos."]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"sonic", Vector2(2.5, 1.5), 0.0],
			["colocar", &"rick", Vector2(-2.5, 1.5), 0.0],
			["plano", "general"],
			["narrar", "La puerta del núcleo. Dio dejó a sus mejores ecos cuidándola."],
			["decir", &"rick", "Cuanto más peleamos, más fuerte se pone la Arena. Y más fuerte se pone él."],
			["decir", &"sonic", "Entonces peleemos rápido. Es lo mío."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Rick... ¿y Flowery?"],
			["decir", &"rick", "Dijo que tenía algo que hacer. Las flores son así: impredecibles y medio pegajosas."],
			["aparecer", &"e1", &"dio", Vector2(-6, -12), "sombra"],
			["aparecer", &"e2", &"flowery", Vector2(6, -12), "sombra"],
			["aparecer", &"e3", &"goku", Vector2(0, -15), "sombra"],
			["aparecer", &"e4", &"rick", Vector2(0, -10), "sombra"],
			["plano", "cerca", &"noelle"],
			["pose", &"noelle", &"desafio", 1.8],
			["decir", &"noelle", "Esta vez no tengo miedo. ...Bueno, un poco. Pero no importa."],
		],
		"outro": [
			["plano", "general"],
			["narrar", "La puerta se abre. Adentro, el núcleo brilla como un sol chiquito... y Dio lo tiene en la mano."],
			["decir", &"sonic", "Llegamos tarde."],
			["decir", &"rick", "No. Llegamos justo a tiempo para lo peor. Que es distinto."],
		],
	})

	# ------------------------------------------------------------------ 10
	c.append({
		"titulo": "Todo lo que brilla",
		"personaje": &"noelle",
		"aliados": [
			_aliado(&"sonic", "Sonic", Vector2(2.5, 1.5), 90.0, 0.5),
			_aliado(&"rick", "Rick", Vector2(-2.5, 1.5), 90.0, 0.5),
			{"id": &"flowery", "personaje": &"flowery", "nombre": "Flowery", "vida": 110.0,
				"daño": 0.6, "pos": Vector2(3.5, 2.5), "reserva": true},
		],
		"enemigos": [
			{"id": &"dio", "personaje": &"dio", "nombre": "DIO", "vida": 270.0, "daño": 0.48,
				"pos": Vector2(0, -9), "jefe": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"dio", "texto": "Derrotá a DIO"},
		"eventos": [
			[["inicio"], [["decir", &"sonic", "¡Todos juntos! ¡Uno, dos... ya!"]]],
			[["vida", &"dio", 0.5], [
				["cinematica", [
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¡Suficiente! ¡Van a conocer el verdadero poder del núcleo!"],
					["habilidad", &"dio", &"za_warudo"],
					["grito", &"dio", "¡ZA WARUDO!", &"voz_za_warudo"],
					["pose", &"sonic", &"tirado"],
					["pose", &"rick", &"tirado"],
					["temblor", 1.4],
					["plano", "cerca", &"noelle"],
					["decir", &"noelle", "¡No! ¡Sonic! ¡Rick!"],
					["aparecer", &"flowery", &"flowery", Vector2(3.5, 2.5), "teletransporte"],
					["plano", "abajo", &"flowery"],
					["decir", &"flowery", "¡Here I come... y no me importa a dónde! ¡Vengo por mis amigos!"],
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¿La flor? ¿Otra vez? ¿Qué pensás hacer, marchitarte encima mío?"],
					["plano", "cerca", &"flowery"],
					["decir", &"flowery", "Asgore nunca quiso una luz robada. Me cuidó sin pedirme nada. Eso es brillar."],
					["plano", "cerca", &"noelle"],
					["decir", &"noelle", "Flowery... ¡juntos!"],
				]],
				["retirar", &"sonic"],
				["retirar", &"rick"],
				["entrar", &"flowery"],
				["potenciar", &"dio", 25.0],
				["objetivo", {"tipo": "derrotar", "id": &"dio", "texto": "Derrotá a DIO junto a Flowery"}]]],
			[["vida", &"dio", 0.2], [["decir", &"dio", "¡Imposible! ¡¿Cómo se mueve el tiempo sin mi permiso?!"]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"sonic", Vector2(2.5, 1.5), 0.0],
			["colocar", &"rick", Vector2(-2.5, 1.5), 0.0],
			["colocar", &"dio", Vector2(0, -9), 180.0],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"brazos_cruzados"],
			["decir", &"dio", "Llegan justo para ver nacer a un dios. Qué suerte tienen."],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Técnicamente sos un vampiro con una pila muy grande en la mano."],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "El núcleo de la Arena. Mil años de peleas, acá adentro. Con él, cada mundo va a ser mío."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "En uno de esos mundos me esperan. Mi papá. Susie. Kris."],
			["decir", &"noelle", "No se lo voy a dejar."],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"senalar", 1.6],
			["decir", &"dio", "¡Fui yo, DIO, el que llegó primero! ¡Y va a ser DIO el último que quede en pie!"],
			["grito", &"dio", "¡WRYYY!"],
		],
		"outro": [
			["colocar", &"dio", Vector2(0, -6), 180.0],
			["colocar", &"noelle", Vector2(-1, 0), 0.0],
			["colocar", &"flowery", Vector2(1.5, 0.5), 0.0],
			["colocar", &"sonic", Vector2(3, 2), -20.0],
			["colocar", &"rick", Vector2(-3, 2), 20.0],
			["pose", &"dio", &"dolor", 1.2],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "¡¿Yo, DIO... derrotado por una niña que tiembla y una flor?!"],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Temblar no es lo mismo que rendirse."],
			["temblor", 1.2],
			["narrar", "El núcleo se quiebra en la mano de Dio. La Arena entera ruge."],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "Esto no terminó. La grieta sigue abierta... y del otro lado viene algo que ni ustedes pueden parar."],
			["desaparecer", &"dio", "sombra"],
			["plano", "general"],
			["decir", &"rick", "Genial. Una amenaza críptica. Mis favoritas."],
			["decir", &"sonic", "¿Escuchan eso? Algo viene cayendo."],
			["aparecer", &"goku", &"goku", Vector2(0, -5), "caida"],
			["mirar", &"goku", &"noelle"],
			["plano", "abajo", &"goku"],
			["pose", &"goku", &"saludo", 2.2],
			["decir", &"goku", "¡Hola! Soy Goku. Sentí un ki enorme por acá y vine corriendo."],
			["decir", &"goku", "¿Alguno de ustedes es fuerte? ¡Me muero de ganas de pelear! ...Y de comer, también."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¿Otra persona que cayó del cielo...?"],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "No, Noelle. Cayó el dueño del eco sin nombre."],
			["fundido", "negro", 1.0],
			["titulo", "CONTINUARÁ", "Parte 2"],
		],
	})
	return c
