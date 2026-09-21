class_name Frases
extends RefCounted
## Lo que grita cada personaje al usar una habilidad.
##
## EN LOS ORIGINALES LAS HABILIDADES SE ANUNCIAN, y eso no es un adorno: es la parte que
## el jugador de enfrente usa para reaccionar. Flowery grita "Jarona!" y recien despues
## embiste —ese aviso es literalmente el tiempo que Deltarune te da para esquivar—, y Dio
## dice "ZA WARUDO" antes de que el tiempo se pare. Un ataque que sale en silencio no se
## puede jugar en contra.
##
## Asi que la frase sale en el MISMO momento que en el original: junto con el gesto de
## carga, antes del golpe. Sirve de tres cosas a la vez —es fiel, avisa, y le pone voz a
## un personaje que no tiene audio grabado—.
##
## POR QUE SOLO LOS ATAQUES CON NOMBRE. El basico de cada uno va mudo. En los originales
## el grito ES el nombre del movimiento, y si se gritara en cada disparo dejaria de
## leerse como un anuncio para ser ruido de fondo.

## Frases por habilidad. Cada una es [texto, retardo en segundos, voz].
##
## El retardo existe por ZA WARUDO, que son dos frases: el nombre y despues la orden
## ("toki yo tomare", "tiempo, detente"). Las dos, en ese orden, con el tiempo parandose
## en el medio.
##
## Es un MINIMO, no un valor exacto: la segunda nunca arranca antes de que termine la
## primera. Con las dos sintetizadas el numero escrito alcanzaba, porque yo elegia cuanto
## duraban. Desde que pueden ser grabaciones ya no: el "ZA WARUDO" de verdad dura 1.8
## segundos y la orden le caia encima a los 0.75, las dos hablando a la vez. Quien pone el
## archivo no tiene por que venir a ajustar un numero en otro lado.
const LINEAS: Dictionary = {
	# --- FLOWERY (Deltarune) ---
	# Los nombres de sus movimientos son nombres de ataques de anime inventados, y los
	# grita enteros. "Jarona" es el que repite antes de cada embestida.
	&"jarona": [["¡JARONA!", 0.0, &"voz_jarona"]],
	&"here_i_come": [["¡HERE I COME, SAN FRANCISCO!", 0.0, &"voz_here_i_come"]],
	&"last_jarona": [["¡LAST JARONA!", 0.0, &"voz_last_jarona"]],
	# --- DIO (JoJo) ---
	&"muda_rush": [["¡MUDA MUDA MUDA!", 0.0, &"voz_muda"]],
	&"stand_barrage": [["¡MUDAMUDAMUDAMUDA!", 0.0, &"voz_muda"]],
	&"za_warudo": [["¡ZA WARUDO!", 0.0, &"voz_za_warudo"],
		["¡TOKI YO TOMARE!", 0.75, &"voz_toki"]],
}

## El color de la burbuja segun quien hable. Sale del acento del personaje, que es el
## color con el que ya se lo reconoce en el resto de la pantalla —su barra, sus efectos,
## su ropa—, asi que la frase queda atada a el sin tener que elegir nada nuevo.
static func color_de(character_id: StringName) -> Color:
	var data := CharacterDB.get_character(character_id)
	if data == null:
		return Color(1.0, 0.95, 0.8)
	# Aclarado: el acento puede ser oscuro (Dio es dorado sobre negro) y un texto oscuro
	# contra el mapa no se lee. Se lo lleva a brillo alto conservando el tono.
	var c := data.accent_color
	var h := c.h
	var s: float = minf(c.s, 0.72)
	return Color.from_hsv(h, s, 1.0)


## Hay algo para gritar con esta habilidad?
static func tiene(ability_id: StringName) -> bool:
	return LINEAS.has(ability_id)


## Dispara la frase (o la secuencia de frases) de una habilidad.
##
## Llama a avisar_grito del jugador, que es el que se encarga de replicarla: la frase
## tiene que verse en las dos pantallas. Si la dijera solo el que ataca, el que la
## necesita —el otro— seria justo el que no la escucha.
static func decir(caster: Node, ability_id: StringName) -> void:
	if not is_instance_valid(caster) or not caster.has_method("avisar_grito"):
		return
	var lineas: Array = LINEAS.get(ability_id, [])
	for i: int in range(lineas.size()):
		var linea: Array = lineas[i]
		var texto := linea[0] as String
		var retardo := linea[1] as float
		var voz := linea[2] as StringName
		if retardo <= 0.0:
			caster.call("avisar_grito", texto, voz)
			continue
		# Despues de que la anterior termine de sonar, con un respiro.
		if i > 0:
			var previa := (lineas[i - 1] as Array)[2] as StringName
			# El respiro es CHICO a proposito. Solo tiene que evitar que se pisen, y las
			# dos mitades de ZA WARUDO salen de una misma toma continua con musica
			# debajo: cualquier hueco de mas se oye como un salto en la musica, no como
			# una pausa dramatica.
			retardo = maxf(retardo, Sfx.duracion(previa) + 0.05)
		var tree := caster.get_tree()
		if tree == null:
			continue
		await tree.create_timer(retardo).timeout
		if is_instance_valid(caster):
			caster.call("avisar_grito", texto, voz)
