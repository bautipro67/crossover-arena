class_name Historia
extends RefCounted
## El modo historia. PARTE 1: LA GRIETA.
##
## Cinco capitulos, cada uno con lo mismo: una charla antes, una pelea, una charla despues.
## Cada capitulo te da un personaje —no se elige: la historia es de ellos— y te pone
## enfrente a quien le toca. Ganar abre el siguiente.
##
## LA TRAMA: un experimento de Rick rompe la pared entre los mundos, y todo lo que cae por
## la grieta termina en la Arena, un lugar que se alimenta de peleas. Noelle despierta ahi
## sin saber como. Se cruzan Rick, Sonic y Flowery, y descubren que alguien quiere usar el
## nucleo de la Arena para quedarse con todos los mundos a la vez: Dio. La parte 1 termina
## con Dio derrotado pero escapando, la grieta todavia abierta, y alguien nuevo cayendo del
## cielo buscando pelea. Ese alguien es Goku, que es el que abre la parte 2.
##
## TODO LO QUE SE DICE ES ORIGINAL. De las obras salen los personajes y un par de frases
## que son su marca —el "ZA WARUDO" de Dio, el "JARONA" de Flowery—, nada mas.
##
## EL FORMATO DE CADA LINEA: [quien habla, texto]. Quien habla es un id de personaje o
## NARRADOR. Es lo que decide el nombre, el color y el retrato del cuadro de dialogo.

const PARTE: String = "PARTE 1: LA GRIETA"
const NARRADOR: StringName = &"narrador"

## Los enemigos de cada capitulo: personaje, nombre que se le ve arriba, vida, cuanto pega
## (como fraccion del daño normal) y si es un ECO —una copia oscura, sin cara—.
##
## CALIBRADO CON PELEAS SIMULADAS (tests/balance_modos.tscn -- historia [heroe]), un bot
## haciendo de heroe, quince peleas por capitulo. La historia la juega cualquiera, no solo
## el que ya domina un personaje: los tres primeros se ganan casi siempre, y el jefe final
## queda cerca de la mitad, a la altura de la torre de jefes.
##
## EL CAPITULO 4 SE BAJO DE 42 A 32 DE VIDA Y DE 0.24 A 0.17 DE DAÑO por eco. Medido con
## Noelle de heroe —para separar la dificultad del capitulo de lo mal que un bot maneja a
## Rick—, cuatro ecos a la vez daban 3 de 15: con el tambaleo de los combos, cuatro
## enemigos que se turnan para pegar no te dejan salir. Ahora da 10 de 15.
const CAPITULOS: Array[Dictionary] = [
	{
		"titulo": "Nieve en ningún lado",
		"personaje": &"noelle",
		"pista": "Cada golpe deja al rival tambaleando un instante: encadená el golpe básico con tus habilidades antes de que se reponga.",
		"enemigos": [
			{"personaje": &"rick", "nombre": "Eco", "vida": 40.0, "daño": 0.22, "eco": true},
			{"personaje": &"sonic", "nombre": "Eco", "vida": 40.0, "daño": 0.22, "eco": true},
			{"personaje": &"dio", "nombre": "Eco", "vida": 40.0, "daño": 0.22, "eco": true},
		],
		"antes": [
			[NARRADOR, "Una noche de invierno, en un pueblo tranquilo, la nieve empezó a caer hacia arriba."],
			[&"noelle", "¿E-eh? ¿Dónde estoy? Hace un segundo estaba en mi casa..."],
			[&"noelle", "Esto no es Hometown. El piso brilla, el cielo está roto... y hay alguien ahí."],
			[NARRADOR, "Siluetas oscuras se acercan. Tienen la forma de una persona, pero no tienen cara."],
			[&"noelle", "¡N-no se acerquen! ...Perdón. ¡Pero de verdad, no se acerquen!"],
		],
		"despues": [
			[&"noelle", "Se... se deshicieron como nieve."],
			[&"rick", "Ecos. Copias de pelea. Este lugar las fabrica con lo que le sobra de cada uno que cae."],
			[&"noelle", "¿Quién dijo eso? ¡Muéstrese!"],
		],
	},
	{
		"titulo": "El culpable",
		"personaje": &"noelle",
		"pista": "Rick pega de lejos pero es frágil: acercate y no le des espacio.",
		"enemigos": [
			{"personaje": &"rick", "nombre": "Rick", "vida": 115.0, "daño": 0.58, "eco": false},
		],
		"antes": [
			[&"rick", "Yo lo dije. Rick Sanchez. El tipo más inteligente de todos los universos, incluido este, que es bastante feo."],
			[&"noelle", "¿Usted sabe cómo salir de acá?"],
			[&"rick", "Salir, entrar, es lo mismo con la pistola correcta. Pero primero necesito saber si sos real o un eco con peinado."],
			[&"noelle", "¡Soy real! Me llamo Noelle y—"],
			[&"rick", "Eso mismo diría un eco. Vamos a comprobarlo a la antigua."],
		],
		"despues": [
			[&"rick", "Okay, okay. Los ecos no piden perdón cada tres palabras. Sos real."],
			[&"rick", "Y ya que estamos siendo honestos: esto es culpa mía. Estaba probando un estabilizador dimensional y... se desestabilizó."],
			[&"rick", "Rompió la pared entre los mundos. Todo lo que cayó por la grieta vino a parar acá: a la Arena. Un lugar que vive de las peleas."],
			[&"noelle", "¿Y cómo se arregla?"],
			[&"rick", "Encontrando el núcleo de la Arena. Y rezando para que nadie lo haya encontrado antes."],
		],
	},
	{
		"titulo": "Demasiado lento",
		"personaje": &"sonic",
		"pista": "Flowery embiste hasta que lo esquivás: esperá la embestida, salí de costado y castigalo.",
		"enemigos": [
			{"personaje": &"flowery", "nombre": "Flowery", "vida": 110.0, "daño": 0.55, "eco": false},
		],
		"antes": [
			[NARRADOR, "En la otra punta de la Arena, algo azul cruza el mapa tres veces antes de que termine esta frase."],
			[&"sonic", "¡Wooo! ¡Este lugar es enorme! Rampas, pistas, nadie que me pida que frene... ¡me encanta!"],
			[&"flowery", "Buenas tardes. Disculpe la molestia. ¿Usted va para San Francisco?"],
			[&"sonic", "¿San Francisco? Voy para donde haya más lugar para correr."],
			[&"flowery", "Qué lástima. Me contaron que el que junte más peleas acá abre una puerta a cualquier lugar. Y yo tengo que llegar a San Francisco."],
			[&"flowery", "Así que voy a necesitar su pelea. Con todo respeto. ¡JARONA!"],
			[&"sonic", "¡Ja! ¿Una carrera? ¡Dale!"],
		],
		"despues": [
			[&"flowery", "Usted es... muy rápido. Casi descortésmente rápido."],
			[&"sonic", "Me lo dicen seguido. ¿Quién te contó lo de la puerta?"],
			[&"flowery", "Un señor muy elegante. Rubio. Con una sonrisa que no me gustó, y eso que yo sonrío todo el tiempo."],
			[&"sonic", "...Eso no suena nada bien."],
		],
	},
	{
		"titulo": "Ruido en el laboratorio",
		"personaje": &"rick",
		"pista": "Son cuatro a la vez: no te quedes quieto, y usá el portal para salir cuando te rodeen.",
		"enemigos": [
			{"personaje": &"noelle", "nombre": "Eco", "vida": 32.0, "daño": 0.17, "eco": true},
			{"personaje": &"flowery", "nombre": "Eco", "vida": 32.0, "daño": 0.17, "eco": true},
			{"personaje": &"sonic", "nombre": "Eco", "vida": 32.0, "daño": 0.17, "eco": true},
			{"personaje": &"dio", "nombre": "Eco", "vida": 32.0, "daño": 0.17, "eco": true},
		],
		"antes": [
			[&"rick", "Armé un rastreador con partes de la pistola de portales y un tostador que encontré tirado. No pregunten."],
			[&"noelle", "¿Encontró el núcleo?"],
			[&"rick", "Encontré una señal enorme en el centro de la Arena. Y encontré otra cosa: los ecos vienen para acá. Muchos."],
			[&"sonic", "¡Llegué! ¿Llegué a tiempo para la parte divertida?"],
			[&"rick", "Llegaste a tiempo para ver cómo un genio se defiende solo. Ustedes cuiden el rastreador."],
		],
		"despues": [
			[&"rick", "La señal está clarísima. Y no es un núcleo tranquilo: alguien lo está usando."],
			[&"flowery", "Perdón la demora. Creo que sé quién es. Y creo que no les va a gustar."],
			[NARRADOR, "En el centro de la Arena, el tiempo empieza a tartamudear."],
		],
	},
	{
		"titulo": "El mundo se detiene",
		"personaje": &"noelle",
		"pista": "Cuando Dio grite ZA WARUDO, alejate: el tiempo detenido solo alcanza a los que tiene cerca.",
		"enemigos": [
			{"personaje": &"dio", "nombre": "DIO", "vida": 170.0, "daño": 0.60, "eco": false},
		],
		"antes": [
			[&"dio", "Vaya, vaya. Una niña, un viejo con olor a laboratorio, un erizo y un señor de chaleco. Este es el ejército que viene a detenerme."],
			[&"noelle", "¡Usted abrió la puerta a todos los mundos! ¡Ciérrela!"],
			[&"dio", "¿Cerrarla? Con el núcleo de esta Arena, cada mundo que tocó la grieta va a ser mío. Cada uno."],
			[&"rick", "Clásico. Siempre hay uno que ve un desastre dimensional y piensa en bienes raíces."],
			[&"dio", "¿Oh? ¿Se me están acercando?"],
			[&"noelle", "S-sí. Me estoy acercando."],
			[&"dio", "Entonces vení. ¡Te voy a mostrar el poder de ZA WARUDO!"],
		],
		"despues": [
			[&"dio", "Imposible... ¡¿Yo, DIO, derrotado por una niña que tiembla?!"],
			[&"noelle", "Temblar no es lo mismo que rendirse."],
			[NARRADOR, "El núcleo se agrieta. Dio se desvanece entre las grietas del tiempo, riéndose."],
			[&"dio", "Esto no terminó. La grieta sigue abierta... y del otro lado viene algo que ni ustedes pueden parar."],
			[&"rick", "Genial. Una amenaza críptica. Me encantan."],
			[NARRADOR, "Del cielo roto cae alguien. Aterriza de pie, sonriendo, con el pelo en puntas."],
			[&"goku", "¡Hola! Soy Goku. Sentí un ki enorme por acá... ¿Alguno de ustedes es fuerte?"],
			[NARRADOR, "CONTINUARÁ EN LA PARTE 2."],
		],
	},
]


static func cantidad() -> int:
	return CAPITULOS.size()


static func capitulo(i: int) -> Dictionary:
	if i < 0 or i >= CAPITULOS.size():
		return {}
	return CAPITULOS[i]


## El nombre de quien habla, para el cuadro de dialogo.
static func nombre_de(hablante: StringName) -> String:
	if hablante == NARRADOR:
		return ""
	var data := CharacterDB.get_character(hablante)
	return data.display_name if data != null and CharacterDB.has_character(hablante) else String(hablante)
