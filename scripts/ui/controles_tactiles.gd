class_name ControlesTactiles
extends CanvasLayer
## Los botones en pantalla para jugar con el dedo, en un celular o una tablet.
##
## A LA IZQUIERDA, EL STICK. Aparece donde apoyas el pulgar, no en un lugar fijo: cada mano
## y cada celular son distintos, y un stick fijo obliga a mirar la pantalla para encontrarlo
## en medio de una pelea.
##
## A LA DERECHA, LOS BOTONES, en arco alrededor del golpe, que es el que mas se usa y por
## eso el mas grande y el mas cerca del pulgar. Cada uno muestra su propio cooldown: con el
## dedo, el HUD esconde las cartas de habilidades, porque quedaban debajo de estos botones.
##
## CUALQUIER OTRO LUGAR, ARRASTRANDO, GIRA LA CAMARA. Y arrastrar desde un boton de combate
## tambien: es como se apunta en todos los juegos de celular, apretar y corregir sin
## levantar el dedo.
##
## MULTITOUCH DE VERDAD, y por eso esto lee los toques en _input y no usa botones de Godot:
## los botones de la interfaz solo reciben el primer dedo, convertido en click de mouse.
## Caminar con un pulgar y pegar con el otro necesita dos dedos a la vez.
##
## LOS BOTONES NO LLAMAN AL JUGADOR: aprietan la accion, como una tecla. Asi el jugador no
## sabe ni le importa si el dash vino de Shift, de B o de un dedo, y todo lo que ya andaba
## con teclado —cooldowns, stamina, congelado— anda igual con el dedo sin tocar nada.
##
## LA VERSION 2 (2026-10-10, "mejora mucho la jugabilidad y camara de la version de celular y
## sus botones"): mas grandes, con el tamaño y la opacidad que elija cada uno (Settings), el
## nombre y el color de cada habilidad adentro del boton, la carga de la definitiva como un
## anillo que se llena y late cuando esta lista, el fijado que se ve prendido, un boton para
## pasar al siguiente rival, una vibracion corta al apretar, y todo corrido adentro de la
## parte de la pantalla que no tapa la camara de fotos (el "notch").

const RADIO_STICK: float = 100.0
const RADIO_PERILLA: float = 42.0
## Por debajo de esto el stick no mueve: un pulgar apoyado nunca esta quieto del todo.
const ZONA_MUERTA: float = 0.12
## Hasta donde llega la zona del stick, como parte del ancho de la pantalla.
const ZONA_STICK: float = 0.40
## Un toque cuenta como boton hasta un poco afuera del circulo. Con el borde exacto, un
## pulgar que cae apenas al costado gira la camara en vez de pegar.
const MARGEN_TOQUE: float = 1.2
## Cada cuanto se vuelve a preguntar por el notch: puede cambiar al girar el celular.
const CADA_MARGENES: float = 1.0
## Los toques de vibracion, en milisegundos.
const VIBRA_BOTON: int = 12
const VIBRA_DEFINITIVA: int = 40

## Los botones. "pos" se mide desde la esquina de abajo a la derecha, o desde la de
## arriba a la derecha si "arriba" es true. "habilidad" es el lugar en el kit (-1 si no es
## una habilidad) y "gira" si arrastrar desde el tambien mueve la camara. "solo_fijado":
## se muestra solo con alguien fijado.
var _botones: Array[Dictionary] = []

var _jugador: Player = null
var _lienzo: Control = null
var _activo: bool = false

## Cada dedo apoyado: indice -> {"tipo": &"stick" / &"camara" / &"boton", "boton": i}.
var _dedos: Dictionary = {}
var _stick_dedo: int = -1
var _stick_centro: Vector2 = Vector2.ZERO
var _stick_vector: Vector2 = Vector2.ZERO
## Botones apretados ahora: indice -> true.
var _apretados: Dictionary = {}
## Lo que no tapa el notch, como margenes en pixeles de la pantalla del juego:
## (izquierda, arriba, derecha, abajo).
var _margenes: Vector4 = Vector4.ZERO
var _margenes_t: float = 0.0
var _tiempo: float = 0.0


func _ready() -> void:
	layer = 15
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	# El dibujo no atrapa nada: los toques se leen en _input, y los clicks que Godot
	# inventa a partir de ellos tienen que seguir de largo.
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_dibujar)
	# APAGADO DE ENTRADA, y es lo que arregla el fantasma. Un Control nace visible y se
	# dibuja una vez al entrar al arbol; _actualizar_activo solo lo toca cuando el estado
	# CAMBIA, y arrancando con teclado no cambia nunca. Resultado: los botones quedaban
	# dibujados encima del HUD de cualquiera que jugara con teclado, sin responder a nada.
	_lienzo.visible = false
	add_child(_lienzo)
	_armar_botones()
	_actualizar_activo()


func _exit_tree() -> void:
	_soltar_todo()


func bind_player(jugador: Player) -> void:
	_jugador = jugador


func _armar_botones() -> void:
	# El arco: centro en el golpe, radio 170, de 55 a 195 grados. Los que mas se usan
	# (dash, H1) quedan abajo a la izquierda del golpe, donde el pulgar llega sin estirarse;
	# los de una vez por pelea (definitiva, salto) arriba.
	var golpe := Vector2(-150.0, -145.0)
	_boton(&"attack_basic", golpe, 74.0, 0, true)
	var arco: Array = [
		[&"jump", 55.0, -1, false, 42.0],
		[&"ability_ultimate", 90.0, 3, true, 52.0],
		[&"ability_2", 125.0, 2, true, 48.0],
		[&"ability_1", 160.0, 1, true, 48.0],
		[&"dash", 195.0, -1, false, 44.0],
	]
	for fila: Array in arco:
		var a := deg_to_rad(float(fila[1]))
		_boton(fila[0], golpe + Vector2(cos(a), -sin(a)) * 170.0, float(fila[4]), int(fila[2]), bool(fila[3]))
	# Arriba a la derecha, lo que no es de combate. La pausa en la esquina, que es donde
	# se la busca.
	_boton(&"pausa", Vector2(-46.0, 44.0), 30.0, -1, false, true, "II")
	_boton(&"scoreboard", Vector2(-116.0, 44.0), 30.0, -1, false, true)
	_boton(&"practice_panel", Vector2(-186.0, 44.0), 30.0, -1, false, true)
	# FIJAR, sobre el arco de combate, donde el pulgar llega sin soltar el stick de la
	# camara: con el dedo se aprieta una vez y la camara hace sola lo que en el celular mas
	# cuesta, que es seguir a alguien arrastrando. Y al lado, con alguien fijado, PASAR AL
	# SIGUIENTE.
	#
	# Medidos para no pisarse con el salto y la definitiva, ni con los de arriba con los
	# botones al maximo (Settings.BOTONES_MAX): lo vigila solo_test.
	_boton(&"fijar_objetivo", Vector2(-55.0, -380.0), 34.0, -1, false)
	_boton(&"cambiar_objetivo", Vector2(-135.0, -405.0), 28.0, -1, false, false, "SIG", true)


func _boton(accion: StringName, pos: Vector2, radio: float, habilidad: int, gira: bool,
		arriba: bool = false, texto: String = "", solo_fijado: bool = false) -> void:
	_botones.append({
		"accion": accion, "pos": pos, "radio": radio, "habilidad": habilidad,
		"gira": gira, "arriba": arriba, "solo_fijado": solo_fijado,
		"texto": texto if not texto.is_empty() else Controles.ETIQUETA_TACTIL.get(accion, "?"),
	})


func _tam() -> Vector2:
	return _lienzo.size if _lienzo.size.x > 0.0 else get_viewport().get_visible_rect().size


## Cuanto se agrandan los botones: lo que elija el jugador (Settings.tamano_botones).
func escala() -> float:
	return Settings.tamano_botones if Settings != null else 1.0


func _opacidad() -> float:
	return Settings.opacidad_botones if Settings != null else 1.0


func radio(i: int) -> float:
	return float(_botones[i]["radio"]) * escala()


## Donde esta un boton en la pantalla: su esquina, corrida adentro del notch, mas su lugar
## escalado con el tamaño de los botones.
func centro(i: int) -> Vector2:
	var b: Dictionary = _botones[i]
	var t := _tam()
	var esquina := Vector2(t.x - _margenes.z, _margenes.y) if b["arriba"] \
		else Vector2(t.x - _margenes.z, t.y - _margenes.w)
	return esquina + (b["pos"] as Vector2) * escala()


func _visible(i: int) -> bool:
	var accion: StringName = _botones[i]["accion"]
	# El panel de practica solo existe en la practica.
	if accion == &"practice_panel" and not Practica.disponible():
		return false
	if bool(_botones[i]["solo_fijado"]):
		return _hay_fijado()
	return true


func _hay_fijado() -> bool:
	return is_instance_valid(_jugador) and is_instance_valid(_jugador.camera_pivot) \
		and _jugador.camera_pivot.esta_fijado()


## El indice de un boton por su accion. Para los chequeos.
func indice_de(accion: StringName) -> int:
	for i: int in range(_botones.size()):
		if _botones[i]["accion"] == accion:
			return i
	return -1


func centro_del_stick_en_reposo() -> Vector2:
	var t := _tam()
	var r := RADIO_STICK * escala()
	return Vector2(_margenes.x + r + 70.0, t.y - _margenes.w - r - 70.0)


# ------------------------------------------------------------------- El notch

## LO QUE TAPA LA CAMARA DE FOTOS, en pixeles del juego. Solo en la aplicacion del celular:
## en el navegador la "zona segura" que da el sistema es la de la ventana del navegador, y
## correria los botones sin motivo.
func _medir_margenes() -> void:
	_margenes = Vector4.ZERO
	if not (OS.has_feature("android") or OS.has_feature("ios")):
		return
	var pantalla := DisplayServer.screen_get_size()
	var seguro := DisplayServer.get_display_safe_area()
	if pantalla.x <= 0 or pantalla.y <= 0 or seguro.size.x <= 0:
		return
	var t := _tam()
	var k := Vector2(t.x / float(pantalla.x), t.y / float(pantalla.y))
	_margenes = Vector4(seguro.position.x * k.x, seguro.position.y * k.y,
		(pantalla.x - seguro.end.x) * k.x, (pantalla.y - seguro.end.y) * k.y)


# ------------------------------------------------------------------- Activo

## Se usa solo jugando con el dedo, y no con un menu encima: con la pausa abierta, los
## toques tienen que llegar a los botones de la pausa.
func esta_activo() -> bool:
	return _activo


func _actualizar_activo() -> void:
	var ahora := Controles.dispositivo == &"tactil" and not Mando.hay_menu_abierto()
	if ahora == _activo:
		return
	_activo = ahora
	# Al apagarse suelta todo: un dedo que estaba en el stick cuando se abrio la pausa
	# dejaria al personaje caminando solo para siempre.
	if not _activo:
		_soltar_todo()
	else:
		_medir_margenes()
	_lienzo.visible = _activo


func _process(delta: float) -> void:
	_actualizar_activo()
	if not _activo:
		return
	_tiempo += delta
	_margenes_t -= delta
	if _margenes_t <= 0.0:
		_margenes_t = CADA_MARGENES
		_medir_margenes()
	_lienzo.queue_redraw()


# ------------------------------------------------------------------- Toques

func _input(event: InputEvent) -> void:
	if procesar(event):
		get_viewport().set_input_as_handled()


## Lee un toque. Devuelve true si era para estos botones. Separado de _input para que el
## arnes pueda mandar toques sin pasar por la ventana.
func procesar(event: InputEvent) -> bool:
	if not _activo:
		return false
	var t := event as InputEventScreenTouch
	if t != null:
		return _apoyar(t.index, t.position) if t.pressed else _levantar(t.index)
	var d := event as InputEventScreenDrag
	if d != null:
		return _arrastrar(d.index, d.position, d.relative)
	return false


func _apoyar(dedo: int, pos: Vector2) -> bool:
	# El boton mas cercano que este al alcance, no el primero de la lista: dos botones
	# vecinos pueden tocarse con el margen, y gana el que el dedo tiene mas encima.
	var elegido := -1
	var mejor := INF
	for i: int in range(_botones.size()):
		if not _visible(i):
			continue
		var dist := pos.distance_to(centro(i))
		if dist <= radio(i) * MARGEN_TOQUE and dist < mejor:
			elegido = i
			mejor = dist
	if elegido >= 0:
		_dedos[dedo] = {"tipo": &"boton", "boton": elegido}
		_apretar(elegido, true)
		return true

	var t := _tam()
	var r := RADIO_STICK * escala()
	if _stick_dedo < 0 and pos.x < t.x * ZONA_STICK:
		_stick_dedo = dedo
		# El stick aparece bajo el pulgar, pero entero adentro de la pantalla (y del notch).
		_stick_centro = Vector2(
			clampf(pos.x, _margenes.x + r + 8.0, maxf(_margenes.x + r + 8.0, t.x * ZONA_STICK)),
			clampf(pos.y, _margenes.y + r + 8.0, t.y - _margenes.w - r - 8.0))
		_stick_vector = Vector2.ZERO
		_dedos[dedo] = {"tipo": &"stick"}
		_mover(pos)
		return true

	_dedos[dedo] = {"tipo": &"camara"}
	return true


func _arrastrar(dedo: int, pos: Vector2, relativo: Vector2) -> bool:
	if not _dedos.has(dedo):
		return false
	var d: Dictionary = _dedos[dedo]
	match d["tipo"]:
		&"stick":
			_mover(pos)
		&"camara":
			_girar(relativo)
		&"boton":
			if bool(_botones[int(d["boton"])]["gira"]):
				_girar(relativo)
	return true


func _levantar(dedo: int) -> bool:
	if not _dedos.has(dedo):
		return false
	var d: Dictionary = _dedos[dedo]
	_dedos.erase(dedo)
	match d["tipo"]:
		&"stick":
			_stick_dedo = -1
			_stick_vector = Vector2.ZERO
			_aplicar_movimiento()
		&"boton":
			_apretar(int(d["boton"]), false)
	return true


func _mover(pos: Vector2) -> void:
	var r := RADIO_STICK * escala()
	var v := (pos - _stick_centro) / r
	if v.length() > 1.0:
		v = v.normalized()
		# EL STICK SIGUE AL PULGAR: si el dedo se va mas alla del borde, el centro lo sigue
		# hasta quedar a un radio. Asi volver para el otro lado responde en el acto, en vez
		# de tener que recorrer de nuevo todo el camino que el pulgar se paso.
		_stick_centro = pos - v * r
	_stick_vector = v
	_aplicar_movimiento()


## El stick aprieta las cuatro acciones de caminar con la fuerza que corresponde, igual
## que un stick de mando. El jugador lee Input.get_vector y no sabe de donde vino.
##
## LA ZONA MUERTA SE DESCUENTA, no se corta: pasado el borde, la fuerza arranca de cero y
## llega a uno en el borde del stick. Cortada, el personaje arrancaba ya al 15% de golpe.
func _aplicar_movimiento() -> void:
	var largo := _stick_vector.length()
	var v := Vector2.ZERO
	if largo >= ZONA_MUERTA:
		v = _stick_vector / largo * inverse_lerp(ZONA_MUERTA, 1.0, minf(largo, 1.0))
	_fuerza(&"move_right", maxf(v.x, 0.0))
	_fuerza(&"move_left", maxf(-v.x, 0.0))
	_fuerza(&"move_back", maxf(v.y, 0.0))
	_fuerza(&"move_forward", maxf(-v.y, 0.0))


func _fuerza(accion: StringName, valor: float) -> void:
	if valor > 0.0:
		Input.action_press(accion, valor)
	else:
		Input.action_release(accion)


func _girar(relativo: Vector2) -> void:
	if is_instance_valid(_jugador) and is_instance_valid(_jugador.camera_pivot):
		_jugador.camera_pivot.girar_por_toque(relativo)


## Aprieta o suelta la accion de un boton COMO UN EVENTO, no solo como estado: el dash y
## las habilidades se disparan en _unhandled_input, y ahi solo llegan eventos. Un
## Input.action_press dejaria la accion apretada sin que nadie se entere.
func _apretar(i: int, si: bool) -> void:
	var accion: StringName = _botones[i]["accion"]
	if si:
		_apretados[i] = true
		Settings.vibrar(VIBRA_DEFINITIVA if accion == &"ability_ultimate" else VIBRA_BOTON)
	else:
		_apretados.erase(i)
	# PASAR AL SIGUIENTE no es una tecla: va derecho a la camara.
	if accion == &"cambiar_objetivo":
		if si and is_instance_valid(_jugador) and is_instance_valid(_jugador.camera_pivot):
			_jugador.camera_pivot.siguiente_objetivo()
		return
	var ev := InputEventAction.new()
	ev.action = accion
	ev.pressed = si
	ev.strength = 1.0 if si else 0.0
	Input.parse_input_event(ev)


func _soltar_todo() -> void:
	for i: int in _apretados.keys():
		_apretar(i, false)
	_apretados.clear()
	_dedos.clear()
	_stick_dedo = -1
	_stick_vector = Vector2.ZERO
	_aplicar_movimiento()


# ------------------------------------------------------------------- Dibujo

func _dibujar() -> void:
	var fuente := ThemeDB.fallback_font
	var op := _opacidad()

	# --- El stick ---
	var en_uso := _stick_dedo >= 0
	var r := RADIO_STICK * escala()
	var c := _stick_centro if en_uso else centro_del_stick_en_reposo()
	_lienzo.draw_circle(c, r, Color(0.02, 0.03, 0.06, (0.30 if en_uso else 0.18) * op))
	_lienzo.draw_arc(c, r, 0.0, TAU, 56, Color(1, 1, 1, (0.5 if en_uso else 0.28) * op), 3.0, true)
	var perilla := c + _stick_vector * r
	_lienzo.draw_circle(perilla, RADIO_PERILLA * escala(), Color(1, 1, 1, (0.5 if en_uso else 0.24) * op))
	if en_uso and _stick_vector.length() > ZONA_MUERTA:
		# Una flechita hacia donde camina: con el pulgar encima, la perilla no se ve.
		var dir := _stick_vector.normalized()
		var punta := c + dir * (r + 14.0 * escala())
		var lado := dir.orthogonal() * 9.0 * escala()
		_lienzo.draw_colored_polygon(PackedVector2Array([punta, punta - dir * 14.0 * escala() + lado,
			punta - dir * 14.0 * escala() - lado]), Color(1, 1, 1, 0.55 * op))

	# --- Los botones ---
	for i: int in range(_botones.size()):
		if not _visible(i):
			continue
		_dibujar_boton(i, fuente, op)


func _dibujar_boton(i: int, fuente: Font, op: float) -> void:
	var b: Dictionary = _botones[i]
	var c := centro(i)
	var r := radio(i)
	var apretado := _apretados.has(i)
	if apretado:
		# Se hunde un poco al apretarlo: la respuesta que el dedo no siente.
		r *= 0.93

	# Si se puede usar ahora. Un boton que no alcanza —sin stamina, sin carga— se apaga,
	# como las cartas del HUD que reemplaza.
	var usable := true
	var espera := 0.0
	var total := 0.0
	var nombre := ""
	var color_hab := Color.WHITE
	var carga := -1.0
	var lista := false
	var h: int = b["habilidad"]
	if is_instance_valid(_jugador):
		if h >= 0:
			var hab := _jugador.caster.get_ability(h)
			if hab != null:
				espera = _jugador.caster.get_cooldown_remaining(h)
				total = hab.cooldown
				usable = hab.stamina_cost <= 0.0 or _jugador.stamina.current >= hab.stamina_cost
				nombre = _nombre_corto(hab.display_name)
				color_hab = hab.icon_color
				# La definitiva pide ademas la carga llena: se ve como un anillo que se llena.
				if h == 3:
					carga = _jugador.ultimate.get_ratio()
					lista = _jugador.ultimate.is_ready() and usable and espera <= 0.0
					if not _jugador.ultimate.is_ready():
						usable = false
		elif b["accion"] == &"dash":
			var ratio := _jugador.get_dash_cooldown_ratio()
			if ratio > 0.0:
				espera = ratio * _jugador.dash_cooldown
				total = _jugador.dash_cooldown

	var fondo := Color(0.05, 0.07, 0.12, 0.48)
	if h >= 0:
		fondo = Color(color_hab.darkened(0.72), 0.55)
	if apretado:
		fondo = Color(UITheme.ACCENT, 0.6)
	if b["accion"] == &"fijar_objetivo" and _hay_fijado():
		fondo = Color(0.85, 0.15, 0.18, 0.62)
	fondo.a *= op
	_lienzo.draw_circle(c, r, fondo)
	if espera > 0.0 and total > 0.0:
		_torta(c, r, clampf(espera / total, 0.0, 1.0), Color(0, 0, 0, 0.6 * op))

	var borde := Color(1, 1, 1, (0.65 if usable else 0.28) * op)
	if h >= 0 and usable:
		borde = Color(color_hab.lightened(0.25), 0.85 * op)
	if h == 0:
		borde = Color(UITheme.ACCENT, 0.85 * op)
	_lienzo.draw_arc(c, r, 0.0, TAU, 56, borde, 3.0, true)

	# La carga de la definitiva: un anillo dorado que se llena, y que late cuando esta lista.
	if carga >= 0.0:
		if carga > 0.0:
			_lienzo.draw_arc(c, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(carga, 0.0, 1.0), 56,
				Color(UITheme.GOLD, 0.9 * op), 5.0, true)
		if lista:
			var latido := 0.5 + 0.5 * sin(_tiempo * 7.0)
			_lienzo.draw_arc(c, r + 11.0 + latido * 5.0, 0.0, TAU, 56,
				Color(UITheme.GOLD, (0.35 + 0.45 * latido) * op), 3.0, true)

	var texto: String = b["texto"]
	if espera > 0.0:
		texto = "%.1f" % espera
	var tam_fuente := 21 if r > 55.0 else (16 if r > 34.0 else 14)
	var color_texto := Color(1, 1, 1, (0.95 if usable else 0.5) * op)
	var y_texto := tam_fuente * 0.36
	if not nombre.is_empty() and espera <= 0.0:
		# Con el nombre de la habilidad abajo, la etiqueta sube un poco.
		y_texto -= 7.0
	_lienzo.draw_string(fuente, c + Vector2(-r, y_texto), texto,
		HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, tam_fuente, color_texto)
	if not nombre.is_empty() and espera <= 0.0:
		_lienzo.draw_string(fuente, c + Vector2(-r * 0.92, y_texto + 15.0), nombre,
			HORIZONTAL_ALIGNMENT_CENTER, r * 1.84, 11, Color(1, 1, 1, (0.85 if usable else 0.45) * op))
	if carga >= 0.0 and carga < 1.0 and espera <= 0.0:
		_lienzo.draw_string(fuente, c + Vector2(-r, y_texto + 29.0), "%d%%" % int(floor(carga * 100.0)),
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color(UITheme.GOLD, 0.9 * op))


## El nombre de la habilidad, corto para que entre en el boton: la primera palabra que
## diga algo ("Rueda de Agua" -> "Rueda"), hasta diez letras.
static func _nombre_corto(nombre: String) -> String:
	var palabras := nombre.split(" ", false)
	if palabras.is_empty():
		return ""
	var corto := palabras[0]
	if corto.length() <= 3 and palabras.size() > 1:
		corto += " " + palabras[1]
	return corto.substr(0, 10)


## Un sector de circulo que arranca arriba y gira en sentido horario, como un reloj: lo
## que falta de cooldown.
func _torta(c: Vector2, r: float, fraccion: float, color: Color) -> void:
	if fraccion <= 0.01:
		return
	var puntos := PackedVector2Array([c])
	var pasos := maxi(3, int(40.0 * fraccion))
	for k: int in range(pasos + 1):
		var a := -PI * 0.5 + TAU * fraccion * float(k) / float(pasos)
		puntos.append(c + Vector2(cos(a), sin(a)) * r)
	_lienzo.draw_colored_polygon(puntos, color)
