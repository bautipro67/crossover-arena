class_name Historia
extends RefCounted
## El modo historia. PARTE 1: LA GRIETA y PARTE 2: EL TORNEO DEL NUCLEO. Diez capitulos
## cada una, en una sola lista: el capitulo 11 es el primero de la parte 2, y se abre al
## ganar el 10 como cualquier otro.
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
##            fuerte. Abre la parte 2. "¡Hola, soy Goku!", "¡qué emocion!", y todo
##            torneo le parece el Tenkaichi Budokai.
##   Mario    llega en la parte 2 por una tuberia equivocada. Habla poco y contento —
##            "¡Mamma mia!", "¡Wahoo!", "okey-dokey", "¡Let's-a go!"— y rescatar gente es
##            lo que hace siempre. Lo esperan la princesa Peach y un pastel.
##
## LA PARTE 2. Cuando Dio apreto el nucleo, se partio: los fragmentos quedaron repartidos
## por la Arena y Dio escapo con el mas grande. La Arena, herida, llama a un TORNEO para
## rearmarse, y tira adentro a los mas fuertes: Goku, y Mario. Juntar los fragmentos, subir
## a la torre del centro y sacarle el nucleo a Dio, que se quiere convertir en la Arena.
##
## TODO LO QUE SE DICE ES ORIGINAL. De las obras salen los personajes y las frases que son
## su marca, nada mas.
##
## CADA CAPITULO: personaje, aliados, enemigos, objetivo, eventos, y las escenas de
## entrada y salida. El formato de las escenas esta en Cinematica, y el de la pelea en
## MisionHistoria. Las posiciones son (x, z) desde el jugador; adelante es z negativo.

## Las partes, en orden, y cuantos capitulos trae cada una. Los capitulos van todos en la
## misma lista: la parte de un capitulo sale de contar.
const PARTES: Array[Dictionary] = [
	{"titulo": "PARTE 1: LA GRIETA", "capitulos": 10},
	{"titulo": "PARTE 2: EL TORNEO DEL NÚCLEO", "capitulos": 10},
]
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


## En que parte esta el capitulo `i` (0, 1...).
static func parte_de(i: int) -> int:
	var hasta := 0
	for k: int in range(PARTES.size()):
		hasta += int(PARTES[k]["capitulos"])
		if i < hasta:
			return k
	return PARTES.size() - 1


## El primer capitulo de la parte `k`.
static func primero_de(k: int) -> int:
	var desde := 0
	for j: int in range(mini(k, PARTES.size())):
		desde += int(PARTES[j]["capitulos"])
	return desde


static func titulo_parte(k: int) -> String:
	return String(PARTES[clampi(k, 0, PARTES.size() - 1)]["titulo"])


## Como se lo nombra: "CAPÍTULO 3" en la parte 1, "PARTE 2 · CAPÍTULO 3" en las demas. Cada
## parte cuenta desde uno: el primero de la parte 2 no es el "capitulo 11".
static func titulo_capitulo(i: int) -> String:
	var k := parte_de(i)
	var n := i - primero_de(k) + 1
	if k == 0:
		return "CAPÍTULO %d" % n
	return "PARTE %d · CAPÍTULO %d" % [k + 1, n]


# ------------------------------------------------------------------ Dificultad

## LAS DIFICULTADES, que se eligen en la pantalla de capitulos. Mueven dos cosas: cuanto
## aguantan y cuanto pegan los enemigos —los aliados no cambian—, y cuanto paga jugar: la
## baja, el plus por ganar y la experiencia se multiplican por "premio". Si facil pagara
## lo mismo, jugar en facil seria la unica forma sensata de juntar monedas.
const DIFICULTADES: Array[Dictionary] = [
	{"nombre": "FÁCIL", "vida": 0.75, "daño": 0.65, "premio": 0.5,
		"texto": "Enemigos más débiles. La mitad de monedas y experiencia."},
	{"nombre": "NORMAL", "vida": 1.0, "daño": 1.0, "premio": 1.0,
		"texto": "La historia como fue pensada. Monedas y experiencia normales."},
	{"nombre": "DIFÍCIL", "vida": 1.3, "daño": 1.35, "premio": 1.5,
		"texto": "Enemigos más duros. 50% más de monedas y experiencia."},
]
const DIFICULTAD_NORMAL: int = 1

## LA CUESTA: los enemigos se endurecen con cada capitulo y con cada parte, encima de lo
## que diga el capitulo y de la dificultad elegida. Cada pelea estaba calibrada para
## costar mas o menos lo mismo, y el ultimo capitulo se sentia como el segundo.
##
## CUENTA LOS CAPITULOS DE PUNTA A PUNTA, no dentro de cada parte: contando desde cero en
## cada parte, el primero de la parte 2 salia mas facil que el ultimo de la 1. Y pasar de
## parte suma un escalon mas.
##
## LOS JEFES SUBEN MAS: arrancan un escalon arriba de los ecos de su mismo capitulo.
##
## EL DAÑO SUBE LA MITAD QUE LA VIDA. Las dos cosas juntas se multiplican entre si, y con
## la cuesta entera en las dos, la parte 2 salia casi imposible: medido con un bot de
## jugador, el capitulo 18 se ganaba 2 de 24, siempre muriendo antes de los veinte segundos.
const CUESTA_CAPITULO: float = 0.015
const CUESTA_PARTE: float = 0.05
const CUESTA_JEFE: float = 1.12
const CUESTA_DAÑO: float = 0.5


static func dificultad(d: int) -> Dictionary:
	return DIFICULTADES[clampi(d, 0, DIFICULTADES.size() - 1)]


## Cuanto se multiplica la vida de un enemigo del capitulo `i`, antes de la dificultad
## elegida. El daño sube la mitad: ver CUESTA_DAÑO.
static func cuesta(i: int, jefe: bool) -> float:
	var f := 1.0 + CUESTA_CAPITULO * float(i) + CUESTA_PARTE * float(parte_de(i))
	return f * CUESTA_JEFE if jefe else f


## Un enemigo del capitulo `i` con la cuesta y la dificultad `d` encima. Devuelve una
## copia: los datos del capitulo no se tocan, o rejugarlo lo endureceria otra vez.
static func escalar(e: Dictionary, i: int, d: int) -> Dictionary:
	var out := e.duplicate()
	var dif := dificultad(d)
	var f := cuesta(i, e.get("jefe", false))
	out["vida"] = float(e.get("vida", 60.0)) * f * float(dif["vida"])
	out["daño"] = float(e.get("daño", 0.4)) * (1.0 + (f - 1.0) * CUESTA_DAÑO) * float(dif["daño"])
	return out


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
			[["tiempo", 3.0], [["decir", NARRADOR, "Cada habilidad tiene su recarga: alterná entre ellas y el golpe básico, y no dejes de moverte."]]],
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
				"daño": 0.22, "pos": Vector2(0, -10), "jefe": true, "oculto": true},
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
			{"id": &"desconocido", "personaje": &"goku", "nombre": "???", "vida": 150.0, "daño": 0.44,
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

	# ================================================================ PARTE 2
	#
	# EL TORNEO DEL NUCLEO. Arranca donde termino la parte 1: Goku recien caido del cielo.

	# ------------------------------------------------------------------ 11
	#
	# GOKU NO SE JUEGA EN LA HISTORIA: es el premio del pase pro, y jugarlo aca seria usarlo
	# antes de ganarlo. Esta en la trama de punta a punta, del otro lado o como aliado.
	c.append({
		"titulo": "El que vino a pelear",
		"personaje": &"sonic",
		"enemigos": [
			# Una pelea de practica: Goku no es jefe.
			{"id": &"goku", "personaje": &"goku", "nombre": "Goku", "vida": 120.0, "daño": 0.35,
				"pos": Vector2(0, -7)},
		],
		"objetivo": {"tipo": "derrotar", "id": &"goku", "hasta": 0.5,
			"texto": "Ganale el combate de práctica a Goku"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "Es una pelea amistosa: con bajarle la mitad de la vida alcanza."]]],
			[["vida", &"goku", 0.75], [["decir", &"goku", "¡Uh! ¡Qué rápido sos! ¡Esto me encanta!"]]],
		],
		"intro": [
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(0, -7), 180.0],
			["aparecer", &"noelle_", &"noelle", Vector2(-4, 2), ""],
			["aparecer", &"rick_", &"rick", Vector2(4, 2), ""],
			["plano", "general"],
			["narrar", "La Arena, un rato después. El cielo sigue roto, y el que cayó de él no para de estirarse."],
			["plano", "abajo", &"goku"],
			["pose", &"goku", &"desafio", 1.6],
			["decir", &"goku", "¡Bueno! ¿Quién pelea conmigo primero? Prometo no ir con todo... al principio."],
			["plano", "cerca", &"noelle_"],
			["decir", &"noelle_", "E-eh... ¿no deberíamos descansar? Recién le ganamos a Dio..."],
			["plano", "dos", &"goku", &"sonic"],
			["decir", &"sonic", "¿Fuerte? Yo no soy fuerte. Soy RÁPIDO. Que es mejor."],
			["decir", &"goku", "¡Qué bueno! Nunca peleé con alguien que corra tanto."],
			["plano", "cerca", &"rick_"],
			["decir", &"rick_", "Un mono espacial contra un erizo con zapatillas. Qué gran uso de nuestro tiempo."],
			["plano", "abajo", &"goku"],
			["decir", &"goku", "¡Una peleíta corta y después comemos! ¿Hay comida acá?"],
			["plano", "cerca", &"sonic"],
			["pose", &"sonic", &"senalar", 1.4],
			["decir", &"sonic", "Si me alcanzás, te invito. Spoiler: no me vas a alcanzar."],
		],
		"outro": [
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(0, -3.5), 180.0],
			["aparecer", &"noelle_", &"noelle", Vector2(-4, 2), ""],
			["aparecer", &"rick_", &"rick", Vector2(4, 2), ""],
			["plano", "dos", &"sonic", &"goku"],
			["decir", &"goku", "¡Uf! Sos rapidísimo. ¡Casi no te veía!"],
			["decir", &"sonic", "Vos tampoco estás tan mal. Para no ser yo, sos bastante rápido."],
			["decir", &"goku", "¡Tenemos que repetirla!"],
			["temblor", 1.0],
			["narrar", "El piso late. Desde el centro de la Arena sale un zumbido que se mete en los huesos."],
			["plano", "cerca", &"rick_"],
			["decir", &"rick_", "Es el núcleo. Cuando Dio lo apretó, se partió, y los pedazos quedaron desparramados por toda la Arena."],
			["decir", &"rick_", "El que junte los fragmentos, manda acá. Y adivinen quién se llevó el más grande."],
			["plano", "cerca", &"noelle_"],
			["decir", &"noelle_", "Dio..."],
			["narrar", "Y entonces la Arena habla. Con mil voces a la vez, una sola palabra: TORNEO."],
			["plano", "abajo", &"goku"],
			["pose", &"goku", &"victoria", 1.8],
			["decir", &"goku", "¡¿Un torneo?! ¡Como el Tenkaichi Budokai! ¡Qué emoción!"],
			["plano", "cerca", &"rick_"],
			["decir", &"rick_", "No es un torneo, es un organismo hambriento que quiere que nos matemos. ...Pero sí, técnicamente es un torneo."],
		],
	})

	# ------------------------------------------------------------------ 12
	c.append({
		"titulo": "Una tubería equivocada",
		"personaje": &"mario",
		"enemigos": [
			_eco("e1", &"goku", Vector2(-4, -10), 34.0, 0.18),
			_eco("e2", &"dio", Vector2(0, -12), 34.0, 0.18),
			_eco("e3", &"flowery", Vector2(4, -10), 34.0, 0.18),
		],
		"objetivo": {"tipo": "derrotar_todos", "texto": "Derrotá a los ecos"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "Los ecos pelean como aquel al que copian. La bola de fuego pica: tirala al piso delante de ellos."]]],
			[["tiempo", 12.0], [
				["refuerzos", [_eco("e4", &"rick", Vector2(-7, -12), 34.0, 0.18, false)]],
				["decir", &"mario", "¡Mamma mia! ¡Viene otro!"]]],
		],
		"intro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["plano", "libre", Vector3(5, 3, 6), Vector3(0, 1.2, 0)],
			["narrar", "En otra punta de la Arena, donde nadie miraba, una tubería verde asoma del piso como si siempre hubiera estado ahí."],
			["aparecer", &"mario", &"mario", Vector2(0, 0), "caida"],
			["plano", "cerca", &"mario"],
			["pose", &"mario", &"pensar", 1.6],
			["decir", &"mario", "¡Mamma mia! Esto no es el Reino Champiñón..."],
			["decir", &"mario", "La princesa Peach me invitó a comer pastel. Tomé la tubería de siempre. Y la tubería de siempre me trajo acá."],
			["aparecer", &"e1", &"goku", Vector2(-4, -10), "sombra"],
			["aparecer", &"e2", &"dio", Vector2(0, -12), "sombra"],
			["aparecer", &"e3", &"flowery", Vector2(4, -10), "sombra"],
			["plano", "general"],
			["narrar", "Tres sombras suben del piso. Tienen forma de gente, pero no tienen cara."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¿Goombas sin cara? ¿Bowser, sos vos?"],
			["pose", &"mario", &"desafio", 1.4],
			["grito", &"mario", "¡LET'S-A GO!", &"voz_lets_go"],
		],
		"outro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["aparecer", &"goku", &"goku", Vector2(0, -5), "teletransporte"],
			["mirar", &"goku", &"mario"],
			["mirar", &"mario", &"goku"],
			["plano", "abajo", &"goku"],
			["pose", &"goku", &"saludo", 1.8],
			["decir", &"goku", "¡Uh, qué bien peleás! Sentí tu ki desde la otra punta y vine con la teletransportación."],
			["plano", "dos", &"mario", &"goku"],
			["decir", &"goku", "¡Hola, soy Goku!"],
			["decir", &"mario", "¡It's-a me, Mario!"],
			["decir", &"goku", "Oye, Mario, ¿tenés algo de comer? Pelear me da un hambre terrible."],
			["decir", &"mario", "Tengo un hongo. Te hace crecer. Mucho."],
			["decir", &"goku", "¡¿En serio?! ¡Qué buena comida tienen en tu mundo!"],
			["aparecer", &"rick", &"rick", Vector2(3, -1), "portal"],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Genial. Un plomero. Justo lo que le faltaba a esta pesadilla: alguien que sepa de tuberías."],
			["decir", &"rick", "Tu tubería no es una tubería, bigote. Es una grieta con forma de tubería. La Arena te trajo porque peleás bien."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "Okey-dokey. Entonces ayudo, y después vuelvo con la princesa. ¡Wahoo!"],
		],
	})

	# ------------------------------------------------------------------ 13
	c.append({
		"titulo": "El fragmento azul",
		"personaje": &"rick",
		"aliados": [
			_aliado(&"mario", "Mario", Vector2(2.5, 1.5), 100.0, 0.55),
			_aliado(&"noelle", "Noelle", Vector2(-2.5, 1.5), 100.0, 0.55),
		],
		"enemigos": [
			_eco("e1", &"sonic", Vector2(-6, -18), 46.0, 0.25),
			_eco("e2", &"goku", Vector2(6, -18), 46.0, 0.25),
		],
		"objetivo": {"tipo": "zona", "centro": Vector2(0, -12), "radio": 6.0, "segundos": 30.0,
			"texto": "Quedate en el círculo mientras el rastreador saca el fragmento"},
		"eventos": [
			[["inicio"], [["decir", &"rick", "¡Al círculo! Si salgo, el rastreador se detiene. Así funciona la ciencia."]]],
			[["tiempo", 9.0], [
				["refuerzos", [_eco("e3", &"dio", Vector2(0, -22), 46.0, 0.25, false),
					_eco("e4", &"flowery", Vector2(-9, -10), 46.0, 0.25, false)]],
				["decir", &"noelle", "¡V-vienen más por los costados!"]]],
			[["tiempo", 18.0], [
				["refuerzos", [_eco("e5", &"mario", Vector2(9, -10), 46.0, 0.25, false)]],
				["decir", &"mario", "¡Mamma mia! ¡Ese eco tiene mi bigote!"]]],
		],
		"intro": [
			["colocar", &"rick", Vector2(0, 0), 0.0],
			["colocar", &"mario", Vector2(2.5, 1.5), 0.0],
			["colocar", &"noelle", Vector2(-2.5, 1.5), 0.0],
			["plano", "cerca", &"rick"],
			["pose", &"rick", &"pensar", 1.6],
			["decir", &"rick", "El rastreador marca un fragmento del núcleo acá adelante. Enterrado en el piso, como una muela."],
			["decir", &"rick", "Treinta segundos parado encima y sale solo. Mario, Noelle: que nadie me interrumpa."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¡Okey-dokey!"],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "E-entendido, señor Rick. Voy a... voy a hacerle frío en la cara a quien venga."],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Esa es la actitud, Morty."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "Soy Mario."],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Es lo mismo."],
			["aparecer", &"e1", &"sonic", Vector2(-6, -18), "sombra"],
			["aparecer", &"e2", &"goku", Vector2(6, -18), "sombra"],
			["plano", "general"],
			["narrar", "Los ecos huelen el fragmento. Vienen por él."],
		],
		"outro": [
			["colocar", &"rick", Vector2(0, 0), 0.0],
			["colocar", &"mario", Vector2(2.5, 1.5), -20.0],
			["colocar", &"noelle", Vector2(-2.5, 1.5), 20.0],
			["plano", "cerca", &"rick"],
			["pose", &"rick", &"victoria", 1.4],
			["decir", &"rick", "Fragmento uno. Azul, brillante, y zumbando como una heladera vieja."],
			["temblor", 0.8],
			["aparecer", &"dio_", &"dio", Vector2(0, -8), "sombra"],
			["plano", "abajo", &"dio_"],
			["pose", &"dio_", &"brazos_cruzados"],
			["decir", &"dio_", "¿Juntan migajas, insectos? Yo tengo el pan entero."],
			["decir", &"dio_", "Cada fragmento que tocan, lo siento. Y cada eco que matan, la Arena me lo devuelve más fuerte."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "¡¿Dio?! ¡¿Está acá?!"],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "No. Es una proyección. Un holograma de vampiro. Hasta los hologramas de este tipo son insoportables."],
			["desaparecer", &"dio_", "sombra"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "Un malo que habla mucho y se esconde en un castillo. Eso ya lo conozco."],
		],
	})

	# ------------------------------------------------------------------ 14
	c.append({
		"titulo": "Luz prestada",
		"personaje": &"noelle",
		"aliados": [
			{"id": &"flowery", "personaje": &"flowery", "nombre": "Flowery", "vida": 110.0, "daño": 0.5,
				"pos": Vector2(0, 3), "quieto": true, "pose": &"pensar"},
			_aliado(&"goku", "Goku", Vector2(2.5, 1.5), 100.0, 0.55),
		],
		"enemigos": [
			_eco("e1", &"dio", Vector2(-5, -12), 64.0, 0.40),
			_eco("e2", &"dio", Vector2(5, -12), 64.0, 0.40),
		],
		"objetivo": {"tipo": "proteger", "id": &"flowery", "segundos": 40.0,
			"texto": "Protegé a Flowery mientras enciende el faro"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "Si Flowery cae, el faro se apaga. Que los ecos te elijan a vos."]]],
			[["tiempo", 12.0], [
				["refuerzos", [_eco("e3", &"goku", Vector2(-8, -14), 64.0, 0.40, false),
					_eco("e4", &"rick", Vector2(8, -14), 64.0, 0.40, false)]],
				["decir", &"goku", "¡Ja! ¡Llegan más! ¡Esto se pone bueno!"]]],
			[["tiempo", 25.0], [
				["refuerzos", [_eco("e5", &"sonic", Vector2(0, -16), 64.0, 0.40, false),
					_eco("e6", &"mario", Vector2(-6, -16), 64.0, 0.40, false)]],
				["decir", &"flowery", "¡Ya casi, amigos! ¡Ya veo la luz del otro lado!"]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"flowery", Vector2(0, 3), 180.0],
			["colocar", &"goku", Vector2(2.5, 1.5), 0.0],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Rick me dio el fragmento. Tiene luz adentro, amigos. Luz de verdad. De la que no se apaga."],
			["decir", &"flowery", "Con esto el reino de las flores de Asgore brillaría para siempre..."],
			["plano", "dos", &"noelle", &"flowery"],
			["decir", &"noelle", "F-Flowery..."],
			["decir", &"flowery", "Tranqui, Noelle. Esta vez no. Esta luz la voy a usar para encontrar los otros fragmentos: un faro que se vea desde toda la Arena."],
			["decir", &"flowery", "Pero tengo que quedarme quieta cuarenta segundos. Y los ecos van a venir derechito a mí."],
			["plano", "cerca", &"goku"],
			["pose", &"goku", &"desafio", 1.4],
			["decir", &"goku", "¡Dejámelos a mí! Bueno, a nosotros. ¡Vamos, Noelle!"],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "S-sí. Nadie la va a tocar. Se lo prometo."],
			["aparecer", &"e1", &"dio", Vector2(-5, -12), "sombra"],
			["aparecer", &"e2", &"dio", Vector2(5, -12), "sombra"],
			["plano", "general"],
		],
		"outro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"flowery", Vector2(0, 3), 180.0],
			["colocar", &"goku", Vector2(2.5, 1.5), 0.0],
			["plano", "abajo", &"flowery"],
			["habilidad", &"flowery", &"last_jarona"],
			["narrar", "Una columna de luz dorada sube desde las manos de Flowery y parte el cielo roto en dos."],
			["decir", &"flowery", "¡Ahí están! Todos los fragmentos que faltan... están en la torre del centro."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Donde está Dio."],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Y no me quedé con la luz. Asgore me enseñó algo sin decírmelo: la luz que vale es la que se comparte."],
			["plano", "cerca", &"goku"],
			["decir", &"goku", "¡Muy bien, Flowery! ¡A la torre! ...¿Queda algún lugar para comer de camino?"],
		],
	})

	# ------------------------------------------------------------------ 15
	c.append({
		"titulo": "¿Quién es el más rápido?",
		"personaje": &"sonic",
		"aliados": [_aliado(&"mario", "Mario", Vector2(2.5, 1.5), 100.0, 0.55)],
		"enemigos": [
			_eco("e1", &"noelle", Vector2(-6, -12), 32.0, 0.18),
			_eco("e2", &"rick", Vector2(6, -12), 32.0, 0.18),
			_eco("e3", &"dio", Vector2(0, -14), 32.0, 0.18),
			_eco("e4", &"goku", Vector2(-9, -16), 32.0, 0.18),
			_eco("e5", &"flowery", Vector2(9, -16), 32.0, 0.18),
		],
		"objetivo": {"tipo": "derrotar_todos", "texto": "Limpiá el camino antes de que se cierre la torre",
			"limite": 120.0},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "La puerta de la torre se está cerrando: si no caen todos a tiempo, hay que volver a empezar."]]],
			[["quedan", 2], [
				["refuerzos", [_eco("e6", &"sonic", Vector2(0, -18), 32.0, 0.18, false),
					_eco("e7", &"mario", Vector2(-5, -18), 32.0, 0.18, false)]],
				["decir", &"mario", "¡Mamma mia! ¡Un eco con MI cara! ¡Y otro con la tuya!"]]],
		],
		"intro": [
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["colocar", &"mario", Vector2(2.5, 1.5), 0.0],
			["aparecer", &"e1", &"noelle", Vector2(-6, -12), "sombra"],
			["aparecer", &"e2", &"rick", Vector2(6, -12), "sombra"],
			["aparecer", &"e3", &"dio", Vector2(0, -14), "sombra"],
			["aparecer", &"e4", &"goku", Vector2(-9, -16), "sombra"],
			["aparecer", &"e5", &"flowery", Vector2(9, -16), "sombra"],
			["plano", "general"],
			["narrar", "El camino a la torre está lleno de ecos. Y la puerta de la torre se está cerrando."],
			["plano", "dos", &"mario", &"sonic"],
			["decir", &"sonic", "Bueno, bigotes. Carrera: el que derrote más ecos antes de que cierre la puerta, gana."],
			["decir", &"mario", "¡Como en las Olimpíadas!"],
			["decir", &"sonic", "Ahí siempre ganaba yo."],
			["decir", &"mario", "Mmm... no me acuerdo así."],
			["plano", "cerca", &"sonic"],
			["pose", &"sonic", &"senalar", 1.2],
			["decir", &"sonic", "¡Demasiado lento! ¡Arrancamos!"],
		],
		"outro": [
			["colocar", &"sonic", Vector2(0, 0), 0.0],
			["colocar", &"mario", Vector2(2.5, 1.5), -30.0],
			["plano", "dos", &"sonic", &"mario"],
			["decir", &"mario", "¿Cuántos te hiciste? Yo, cuatro."],
			["decir", &"sonic", "...Cuatro. Empate. Esto no queda así."],
			["decir", &"mario", "¡Revancha en las próximas Olimpíadas!"],
			["temblor", 0.8],
			["narrar", "La puerta de la torre se abre sola. Desde arriba, alguien aplaude, despacio."],
			["aparecer", &"dio_", &"dio", Vector2(0, -12), "sombra"],
			["plano", "abajo", &"dio_"],
			["pose", &"dio_", &"brazos_cruzados"],
			["decir", &"dio_", "Carreras. Juegos de niños. Qué inútil."],
			["decir", &"dio_", "Suban, si quieren. Los espero con el núcleo casi entero."],
			["desaparecer", &"dio_", "sombra"],
		],
	})

	# ------------------------------------------------------------------ 16
	c.append({
		"titulo": "La flor y su sombra",
		"personaje": &"flowery",
		"aliados": [
			{"id": &"noelle", "personaje": &"noelle", "nombre": "Noelle", "vida": 100.0, "daño": 0.55,
				"pos": Vector2(-2.5, 1.5), "reserva": true},
		],
		"enemigos": [
			{"id": &"sombra", "personaje": &"flowery", "nombre": "Flowery Oscura", "vida": 130.0,
				"daño": 0.30, "pos": Vector2(0, -9), "jefe": true, "eco": true, "oculto": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"sombra", "texto": "Derrotá a tu propio eco"},
		"eventos": [
			[["inicio"], [["decir", &"sombra", "Dale, embestime. Sé exactamente para dónde vas a ir."]]],
			[["vida", &"sombra", 0.5], [
				["cinematica", [
					["plano", "abajo", &"sombra"],
					["decir", &"sombra", "Nunca vas a ser suficiente. Para Asgore eras una flor en un florero. Nada más."],
					["plano", "cerca", &"flowery"],
					["decir", &"flowery", "...Puede ser. Pero me regó todos los días."],
					["aparecer", &"noelle", &"noelle", Vector2(-2.5, 1.5), "teletransporte"],
					["plano", "cerca", &"noelle"],
					["decir", &"noelle", "¡Flowery! ¡No estás sola! Los demás me mandaron a buscarte."],
					["plano", "abajo", &"sombra"],
					["decir", &"sombra", "¿Una amiga? Yo nunca tuve una."],
					["plano", "cerca", &"flowery"],
					["decir", &"flowery", "Por eso sos el eco, y yo soy yo."],
				]],
				["entrar", &"noelle"],
				["potenciar", &"sombra", 14.0],
				["objetivo", {"tipo": "derrotar", "id": &"sombra", "texto": "Derrotá a tu eco junto a Noelle"}]]],
		],
		"intro": [
			["colocar", &"flowery", Vector2(0, 0), 0.0],
			["plano", "cerca", &"flowery"],
			["narrar", "En la escalera de la torre, Flowery sube sola. Los demás se quedaron abajo, peleando con los ecos de la entrada."],
			["decir", &"flowery", "Groovy, groovy... Nadie a la vista. Qué raro que esté todo tan tranquilo."],
			["aparecer", &"sombra", &"flowery", Vector2(0, -9), "sombra"],
			["mirar", &"sombra", &"flowery"],
			["plano", "abajo", &"sombra"],
			["pose", &"sombra", &"brazos_cruzados"],
			["decir", &"sombra", "Hola, yo. Qué mal te queda el valor."],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Ah... sos un eco. Un eco mío. Con mi pelo, pero sin mi onda."],
			["plano", "abajo", &"sombra"],
			["decir", &"sombra", "Soy todo lo que pensás de noche. Que le fallaste a Asgore. Que le fallaste a Dio. Que les vas a fallar a estos."],
			["plano", "cerca", &"flowery"],
			["pose", &"flowery", &"desafio", 1.4],
			["grito", &"flowery", "¡JARONA!", &"voz_jarona"],
		],
		"outro": [
			["colocar", &"flowery", Vector2(0, 0), 0.0],
			["colocar", &"noelle", Vector2(-2.5, 1.0), 20.0],
			["colocar", &"sombra", Vector2(0, -5), 180.0],
			["plano", "abajo", &"sombra"],
			["decir", &"sombra", "Si ganás... ¿qué queda de mí?"],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Queda lo que sirve. El miedo me avisa. Pero ya no decide."],
			["desaparecer", &"sombra", "sombra"],
			["plano", "dos", &"noelle", &"flowery"],
			["decir", &"noelle", "Eso fue... muy valiente."],
			["decir", &"flowery", "¡Groovy! Y vos llegaste justo. Como una amiga de verdad."],
			["decir", &"noelle", "¿A-amiga?"],
			["decir", &"flowery", "Amiga. Sin descuento."],
		],
	})

	# ------------------------------------------------------------------ 17
	c.append({
		"titulo": "Un saiyajin contra el tiempo",
		"personaje": &"mario",
		"enemigos": [
			{"id": &"dio", "personaje": &"dio", "nombre": "DIO", "vida": 270.0, "daño": 0.42,
				"pos": Vector2(0, -9), "jefe": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"dio", "hasta": 0.3, "texto": "Hacé retroceder a DIO"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "DIO tiene un fragmento grande del núcleo y no se frena a golpes: esquivá lo suyo y pegale cuando termina."]]],
			# Por vida y no por tiempo: la escena del 60% lo nombra, y un Mario que le
			# bajaba la vida rapido llegaba a esa escena antes que Goku.
			[["vida", &"dio", 0.85], [
				["aliado", _aliado(&"goku", "Goku", Vector2(3, 2), 100.0, 0.55)],
				["decir", &"goku", "¡Llegué con la teletransportación! ¡Aguantá, Mario!"]]],
			[["vida", &"dio", 0.6], [
				["cinematica", [
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¡Suficiente! ¡Les voy a mostrar el mundo de DIO!"],
					["habilidad", &"dio", &"za_warudo"],
					["grito", &"dio", "¡ZA WARUDO!", &"voz_za_warudo"],
					["temblor", 1.4],
					["plano", "cerca", &"mario"],
					["decir", &"mario", "¡Mamma mia! No me puedo mover..."],
					["plano", "cerca", &"goku"],
					["decir", &"goku", "Yo tampoco... pero el ki no se detiene."],
					["pose", &"goku", &"channel_up", 1.6],
					["grito", &"goku", "¡SUPER SAIYAJIN!"],
					["temblor", 1.2],
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¡¿Se mueve?! ¡¿En MI tiempo?!"],
				]],
				["potenciar", &"goku", 14.0]]],
		],
		"intro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["colocar", &"dio", Vector2(0, -9), 180.0],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"brazos_cruzados"],
			["decir", &"dio", "El plomero. ¿Vos sos lo mejor que me mandó la Arena? Qué decepción."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "Conozco a los que son como vos. Grandes, gritones, y con un castillo."],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "Voy a detener el tiempo, y en ese tiempo detenido vas a aprender lo que es la desesperación."],
			["plano", "cerca", &"mario"],
			["pose", &"mario", &"desafio", 1.6],
			["decir", &"mario", "¡Okey-dokey! Pero primero me tenés que alcanzar. ¡Wahoo!"],
		],
		"outro": [
			["colocar", &"dio", Vector2(0, -6), 180.0],
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["pose", &"dio", &"dolor", 1.2],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "Tsk. Un plomero y un mono con suerte. No importa."],
			["aparecer", &"noelle_", &"noelle", Vector2(-3, -9), ""],
			["aparecer", &"rick_", &"rick", Vector2(3, -9), ""],
			["pose", &"noelle_", &"tirado"],
			["pose", &"rick_", &"tirado"],
			["plano", "general"],
			["decir", &"dio", "Mientras jugaban, mis ecos me trajeron invitados. Si los quieren de vuelta, suban a la cima de la torre."],
			["desaparecer", &"dio", "sombra"],
			["desaparecer", &"noelle_", "sombra"],
			["desaparecer", &"rick_", "sombra"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¡Noelle! ¡Rick!"],
			["plano", "cerca", &"goku"],
			["decir", &"goku", "Se los llevó. Pero siento sus ki: están arriba. ¡Vamos, Mario!"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¡Let's-a go!"],
		],
	})

	# ------------------------------------------------------------------ 18
	c.append({
		"titulo": "Tu amiga está en otro castillo",
		"personaje": &"mario",
		"aliados": [_aliado(&"goku", "Goku", Vector2(2.5, 1.5), 100.0, 0.55)],
		"enemigos": [
			_eco("e1", &"dio", Vector2(-5, -12), 38.0, 0.19),
			_eco("e2", &"dio", Vector2(5, -12), 38.0, 0.19),
			_eco("e3", &"goku", Vector2(0, -15), 38.0, 0.19),
			_eco("e4", &"sonic", Vector2(-8, -10), 38.0, 0.19),
		],
		"objetivo": {"tipo": "derrotar_todos", "limite": 170.0,
			"texto": "Llegá a la cima antes de que Dio les saque la energía a Noelle y a Rick"},
		"eventos": [
			[["inicio"], [["decir", NARRADOR, "Hay tiempo contado: cada segundo, Dio les saca un poco más de energía."]]],
			[["quedan", 1], [
				["decir", NARRADOR, "Un eco se inclina, muy educado, y dice: «Gracias, Mario. Pero tu amiga está en otro castillo»."],
				["refuerzos", [_eco("e5", &"dio", Vector2(0, -18), 38.0, 0.19, false),
					_eco("e6", &"flowery", Vector2(-6, -16), 38.0, 0.19, false),
					_eco("e7", &"rick", Vector2(6, -16), 38.0, 0.19, false)]],
				["decir", &"mario", "¡Mamma mia! ¡¿Otra vez?!"]]],
		],
		"intro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(2.5, 1.5), 0.0],
			["plano", "general"],
			["narrar", "La torre de la Arena por dentro: escaleras que no terminan nunca, y ecos en cada piso."],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¡Noelle! ¡Rick! ¡Ya vamos!"],
			["plano", "cerca", &"goku"],
			["decir", &"goku", "Siento el ki de los dos más arriba. Débil, pero está. ¡Hay que apurarse!"],
			["aparecer", &"e1", &"dio", Vector2(-5, -12), "sombra"],
			["aparecer", &"e2", &"dio", Vector2(5, -12), "sombra"],
			["aparecer", &"e3", &"goku", Vector2(0, -15), "sombra"],
			["aparecer", &"e4", &"sonic", Vector2(-8, -10), "sombra"],
			["plano", "general"],
			["plano", "cerca", &"mario"],
			["pose", &"mario", &"desafio", 1.2],
			["grito", &"mario", "¡WAHOO!", &"voz_wahoo"],
		],
		"outro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(2.5, 1.5), 0.0],
			["aparecer", &"noelle_", &"noelle", Vector2(-2, -4), "teletransporte"],
			["aparecer", &"rick_", &"rick", Vector2(2, -4), "teletransporte"],
			["mirar", &"noelle_", &"mario"],
			["mirar", &"rick_", &"mario"],
			["plano", "general"],
			["narrar", "En el último piso, atrás de una puerta que ya no está: Noelle y Rick."],
			["plano", "cerca", &"rick_"],
			["decir", &"rick_", "Tardaron. Estuve a punto de rescatarme solo. Tenía un plan con un clip y un eructo."],
			["plano", "cerca", &"noelle_"],
			["decir", &"noelle_", "¡G-gracias, señor Mario! ¡Gracias, Goku!"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "Solo Mario. Y de nada. Rescatar gente es lo que hago todos los fines de semana."],
			["plano", "cerca", &"goku"],
			["decir", &"goku", "Dio está en la cima, con todos los fragmentos menos el nuestro. ¡Ya casi!"],
		],
	})

	# ------------------------------------------------------------------ 19
	c.append({
		"titulo": "Todos los ecos",
		"personaje": &"noelle",
		"aliados": [
			{"id": &"rick", "personaje": &"rick", "nombre": "Rick", "vida": 120.0, "daño": 0.5,
				"pos": Vector2(0, 3), "quieto": true, "pose": &"pensar"},
			_aliado(&"sonic", "Sonic", Vector2(2.5, 1.5), 90.0, 0.55),
			_aliado(&"flowery", "Flowery", Vector2(-2.5, 1.5), 95.0, 0.55),
		],
		"enemigos": [
			_eco("e1", &"mario", Vector2(-5, -12), 66.0, 0.50),
			_eco("e2", &"goku", Vector2(5, -12), 66.0, 0.50),
			_eco("e3", &"noelle", Vector2(0, -14), 66.0, 0.50),
		],
		"objetivo": {"tipo": "proteger", "id": &"rick", "segundos": 45.0,
			"texto": "Protegé a Rick mientras abre el portal a la cima"},
		"eventos": [
			[["inicio"], [["decir", &"rick", "Y si me pegan, se corta. Así que no me peguen. Gracias."]]],
			[["tiempo", 14.0], [
				["refuerzos", [_eco("e4", &"sonic", Vector2(-8, -14), 66.0, 0.50, false),
					_eco("e5", &"dio", Vector2(8, -14), 66.0, 0.50, false)]],
				["decir", &"flowery", "¡Más invitados! ¡Esta fiesta se está llenando!"]]],
			[["tiempo", 30.0], [
				["refuerzos", [_eco("e6", &"flowery", Vector2(0, -16), 66.0, 0.50, false),
					_eco("e7", &"rick", Vector2(-6, -16), 66.0, 0.50, false)]],
				["decir", &"rick", "¡Quince segundos! ¡Aguanten, Mortys!"]]],
		],
		"intro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"rick", Vector2(0, 3), 180.0],
			["colocar", &"sonic", Vector2(2.5, 1.5), 0.0],
			["colocar", &"flowery", Vector2(-2.5, 1.5), 0.0],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Dio rompió la escalera de arriba. Necesito cuarenta y cinco segundos para abrir un portal a la cima."],
			["decir", &"rick", "No me interrumpan. Ni para agradecerme. Sobre todo para agradecerme."],
			["temblor", 1.0],
			["narrar", "La Arena siente el núcleo casi entero en las manos de Dio, y se defiende como sabe: con ecos. Ecos de todos."],
			["aparecer", &"e1", &"mario", Vector2(-5, -12), "sombra"],
			["aparecer", &"e2", &"goku", Vector2(5, -12), "sombra"],
			["aparecer", &"e3", &"noelle", Vector2(0, -14), "sombra"],
			["plano", "general"],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Un eco mío... Qué raro verse sin cara."],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "Con cara o sin cara, son lentos. ¡Vamos, Noelle!"],
			["plano", "cerca", &"noelle"],
			["pose", &"noelle", &"desafio", 1.4],
			["decir", &"noelle", "¡Sí! ¡Nadie toca a Rick!"],
		],
		"outro": [
			["colocar", &"noelle", Vector2(0, 0), 0.0],
			["colocar", &"rick", Vector2(0, 3), 180.0],
			["colocar", &"sonic", Vector2(2.5, 1.5), 0.0],
			["colocar", &"flowery", Vector2(-2.5, 1.5), 0.0],
			["plano", "cerca", &"rick"],
			["habilidad", &"rick", &"portal_gun"],
			["decir", &"rick", "Portal abierto. Directo a la cima. Pasen antes de que me arrepienta."],
			["aparecer", &"goku_", &"goku", Vector2(3.5, -2), "teletransporte"],
			["aparecer", &"mario_", &"mario", Vector2(-3.5, -2), "caida"],
			["plano", "general"],
			["decir", &"goku_", "¡Llegamos! ¿Nos perdimos algo?"],
			["decir", &"mario_", "¡Todos juntos! ¡Let's-a go!"],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Todos juntos."],
		],
	})

	# ------------------------------------------------------------------ 20
	c.append({
		"titulo": "El corazón de la Arena",
		"personaje": &"mario",
		"aliados": [
			_aliado(&"goku", "Goku", Vector2(2.5, 1.5), 110.0, 0.55),
			_aliado(&"noelle", "Noelle", Vector2(-2.5, 1.5), 95.0, 0.5),
			{"id": &"sonic", "personaje": &"sonic", "nombre": "Sonic", "vida": 90.0, "daño": 0.5,
				"pos": Vector2(4, 2.5), "reserva": true},
			{"id": &"rick", "personaje": &"rick", "nombre": "Rick", "vida": 90.0, "daño": 0.5,
				"pos": Vector2(-4, 2.5), "reserva": true},
			{"id": &"flowery", "personaje": &"flowery", "nombre": "Flowery", "vida": 95.0, "daño": 0.55,
				"pos": Vector2(0, 3.5), "reserva": true},
		],
		"enemigos": [
			{"id": &"dio", "personaje": &"dio", "nombre": "DIO del Núcleo", "vida": 400.0, "daño": 0.46,
				"pos": Vector2(0, -9), "jefe": true},
		],
		"objetivo": {"tipo": "derrotar", "id": &"dio", "texto": "Derrotá a DIO del Núcleo"},
		"eventos": [
			[["inicio"], [["decir", &"goku", "¡Por fin alguien fuerte de verdad! ¡Vamos, Mario!"]]],
			[["vida", &"dio", 0.6], [
				["cinematica", [
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¡Con el núcleo entero, YO soy la Arena! ¡Y en mi Arena, el tiempo es mío!"],
					["habilidad", &"dio", &"za_warudo"],
					["grito", &"dio", "¡ZA WARUDO!", &"voz_za_warudo"],
					["pose", &"noelle", &"tirado"],
					["temblor", 1.4],
					["plano", "cerca", &"mario"],
					["decir", &"mario", "¡Noelle!"],
					["aparecer", &"sonic", &"sonic", Vector2(4, 2.5), "teletransporte"],
					["aparecer", &"rick", &"rick", Vector2(-4, 2.5), "portal"],
					["aparecer", &"flowery", &"flowery", Vector2(0, 3.5), "teletransporte"],
					["plano", "general"],
					["decir", &"sonic", "¿Nos extrañaron? Llegué primero, obvio."],
					["decir", &"rick", "Traje refuerzos. Y por refuerzos me refiero a mí."],
					["decir", &"flowery", "¡Here I come, San Fransdisco! ¡Y esta vez del lado bueno!"],
				]],
				["retirar", &"noelle"],
				["entrar", &"sonic"],
				["entrar", &"rick"],
				["entrar", &"flowery"],
				["potenciar", &"dio", 20.0],
				["objetivo", {"tipo": "derrotar", "id": &"dio", "texto": "Derrotá a DIO con todos"}]]],
			[["vida", &"dio", 0.25], [
				["cinematica", [
					["temblor", 1.5],
					["narrar", "La Arena tiembla. No quiere un dueño: quiere peleas. Y Dio no pelea, manda."],
					["plano", "abajo", &"dio"],
					["decir", &"dio", "¡¿Qué pasa?! ¡El núcleo... me rechaza!"],
					["plano", "cerca", &"goku"],
					["decir", &"goku", "¡Ahora, Mario! ¡Todos juntos, con todo lo que tenemos!"],
					["grito", &"goku", "¡SUPER SAIYAJIN!"],
					["plano", "cerca", &"mario"],
					["grito", &"mario", "¡WAHOO!", &"voz_wahoo"],
				]],
				["potenciar", &"goku", 15.0],
				["potenciar", &"mario", 15.0],
				["decir", &"mario", "¡Esto se termina acá, Dio!"]]],
		],
		"intro": [
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(2.5, 1.5), 0.0],
			["colocar", &"noelle", Vector2(-2.5, 1.5), 0.0],
			["colocar", &"dio", Vector2(0, -9), 180.0],
			["plano", "general"],
			["narrar", "La cima de la torre. El cielo roto está tan cerca que se puede tocar, y en el medio, Dio, con el núcleo casi entero en el pecho."],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"brazos_cruzados"],
			["decir", &"dio", "Llegaron. Justo a tiempo para ver a un hombre convertirse en el mundo."],
			["plano", "cerca", &"goku"],
			["decir", &"goku", "Te hiciste mucho más fuerte, Dio. ¡Eso me pone muy contento!"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "A mí no. Mamma mia, qué feo te queda ese brillo."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Devolvenos el núcleo. Es de todos los que pelearon acá."],
			["plano", "abajo", &"dio"],
			["pose", &"dio", &"senalar", 1.6],
			["decir", &"dio", "¡Fui yo, DIO, el que juntó cada pedazo! ¡Y va a ser DIO el que reine en cada mundo!"],
			["grito", &"dio", "¡WRYYY!"],
		],
		"outro": [
			["colocar", &"dio", Vector2(0, -6), 180.0],
			["colocar", &"mario", Vector2(0, 0), 0.0],
			["colocar", &"goku", Vector2(2.5, 1.5), -15.0],
			["colocar", &"noelle", Vector2(-2.5, 1.5), 15.0],
			["colocar", &"sonic", Vector2(4.5, 2.5), -25.0],
			["colocar", &"rick", Vector2(-4.5, 2.5), 25.0],
			["colocar", &"flowery", Vector2(0, 3.5), 0.0],
			["pose", &"dio", &"dolor", 1.4],
			["plano", "abajo", &"dio"],
			["decir", &"dio", "Yo... DIO... el dueño de todos los mundos... ¡¿derrotado por un plomero y un mono?!"],
			["temblor", 1.6],
			["narrar", "El núcleo se le escapa del pecho y se arma solo en el aire: entero, por primera vez en mil años."],
			["desaparecer", &"dio", "sombra"],
			["plano", "general"],
			["narrar", "Y la Arena, satisfecha por fin, abre una puerta para cada mundo que tocó la grieta."],
			["plano", "cerca", &"noelle"],
			["decir", &"noelle", "Hometown... Papá. Susie. Kris. Ya voy."],
			["plano", "cerca", &"sonic"],
			["decir", &"sonic", "Fue divertido. Pero hay un doctor gordo que seguro está tramando algo sin mí."],
			["plano", "cerca", &"flowery"],
			["decir", &"flowery", "Vuelvo con Asgore. Sin luz robada. Con una historia para contarle, que es mejor."],
			["plano", "cerca", &"rick"],
			["decir", &"rick", "Yo me quedo un rato. Un coliseo que come peleas y abre portales: lo voy a estudiar. Y a patentar."],
			["plano", "cerca", &"goku"],
			["pose", &"goku", &"victoria", 2.0],
			["decir", &"goku", "¡Yo también me quedo! Acá siempre aparece alguien fuerte. ¡Nos vemos en el próximo torneo!"],
			["plano", "cerca", &"mario"],
			["decir", &"mario", "¡La princesa me espera con el pastel! ...Ojalá esta vez esté en ESTE castillo."],
			["fundido", "negro", 1.0],
			["narrar", "En lo más hondo de la Arena, donde no llega ninguna puerta, algo que no es un eco abre los ojos."],
			["titulo", "FIN DE LA PARTE 2", "La historia continuará"],
		],
	})

	return c
