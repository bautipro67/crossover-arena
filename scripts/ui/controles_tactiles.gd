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

const RADIO_STICK: float = 90.0
const RADIO_PERILLA: float = 38.0
## Por debajo de esto el stick no mueve: un pulgar apoyado nunca esta quieto del todo.
const ZONA_MUERTA: float = 0.15
## Hasta donde llega la zona del stick, como parte del ancho de la pantalla.
const ZONA_STICK: float = 0.40
## Un toque cuenta como boton hasta un poco afuera del circulo. Con el borde exacto, un
## pulgar que cae apenas al costado gira la camara en vez de pegar.
const MARGEN_TOQUE: float = 1.15

## Los botones. "pos" se mide desde la esquina de abajo a la derecha, o desde la de
## arriba a la derecha si "arriba" es true. "habilidad" es el lugar en el kit (-1 si no es
## una habilidad) y "gira" si arrastrar desde el tambien mueve la camara.
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
	# El arco: centro en el golpe, radio 150, de 55 a 195 grados. Los que mas se usan
	# (dash, H1) quedan abajo a la izquierda del golpe, donde el pulgar llega sin estirarse;
	# los de una vez por pelea (definitiva, salto) arriba.
	var golpe := Vector2(-140.0, -135.0)
	_boton(&"attack_basic", golpe, 66.0, 0, true)
	var arco: Array = [
		[&"jump", 55.0, -1, false],
		[&"ability_ultimate", 90.0, 3, true],
		[&"ability_2", 125.0, 2, true],
		[&"ability_1", 160.0, 1, true],
		[&"dash", 195.0, -1, false],
	]
	for fila: Array in arco:
		var a := deg_to_rad(float(fila[1]))
		_boton(fila[0], golpe + Vector2(cos(a), -sin(a)) * 150.0, 40.0, int(fila[2]), bool(fila[3]))
	# Arriba a la derecha, lo que no es de combate. La pausa en la esquina, que es donde
	# se la busca.
	_boton(&"pausa", Vector2(-44.0, 40.0), 28.0, -1, false, true, "II")
	_boton(&"scoreboard", Vector2(-110.0, 40.0), 28.0, -1, false, true)
	_boton(&"practice_panel", Vector2(-176.0, 40.0), 28.0, -1, false, true)
	# Fijar, a la izquierda del resto: con el dedo se aprieta una vez y la camara hace sola
	# lo que en el celular mas cuesta, que es seguir a alguien arrastrando.
	_boton(&"fijar_objetivo", Vector2(-242.0, 40.0), 28.0, -1, false, true)


func _boton(accion: StringName, pos: Vector2, radio: float, habilidad: int, gira: bool,
		arriba: bool = false, texto: String = "") -> void:
	_botones.append({
		"accion": accion, "pos": pos, "radio": radio, "habilidad": habilidad,
		"gira": gira, "arriba": arriba,
		"texto": texto if not texto.is_empty() else Controles.ETIQUETA_TACTIL.get(accion, "?"),
	})


func _tam() -> Vector2:
	return _lienzo.size if _lienzo.size.x > 0.0 else get_viewport().get_visible_rect().size


## Donde esta un boton en la pantalla.
func centro(i: int) -> Vector2:
	var b: Dictionary = _botones[i]
	var t := _tam()
	var esquina := Vector2(t.x, 0.0) if b["arriba"] else t
	return esquina + (b["pos"] as Vector2)


func _visible(i: int) -> bool:
	# El panel de practica solo existe en la practica.
	return _botones[i]["accion"] != &"practice_panel" or Practica.disponible()


## El indice de un boton por su accion. Para los chequeos.
func indice_de(accion: StringName) -> int:
	for i: int in range(_botones.size()):
		if _botones[i]["accion"] == accion:
			return i
	return -1


func centro_del_stick_en_reposo() -> Vector2:
	var t := _tam()
	return Vector2(170.0, t.y - 170.0)


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
	_lienzo.visible = _activo


func _process(_delta: float) -> void:
	_actualizar_activo()
	if _activo:
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
		if dist <= float(_botones[i]["radio"]) * MARGEN_TOQUE and dist < mejor:
			elegido = i
			mejor = dist
	if elegido >= 0:
		_dedos[dedo] = {"tipo": &"boton", "boton": elegido}
		_apretar(elegido, true)
		return true

	var t := _tam()
	if _stick_dedo < 0 and pos.x < t.x * ZONA_STICK:
		_stick_dedo = dedo
		# El stick aparece bajo el pulgar, pero entero adentro de la pantalla.
		_stick_centro = Vector2(
			clampf(pos.x, RADIO_STICK + 8.0, t.x * ZONA_STICK),
			clampf(pos.y, RADIO_STICK + 8.0, t.y - RADIO_STICK - 8.0))
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
	var v := (pos - _stick_centro) / RADIO_STICK
	if v.length() > 1.0:
		v = v.normalized()
	_stick_vector = v
	_aplicar_movimiento()


## El stick aprieta las cuatro acciones de caminar con la fuerza que corresponde, igual
## que un stick de mando. El jugador lee Input.get_vector y no sabe de donde vino.
func _aplicar_movimiento() -> void:
	var v := _stick_vector if _stick_vector.length() >= ZONA_MUERTA else Vector2.ZERO
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
	var ev := InputEventAction.new()
	ev.action = _botones[i]["accion"]
	ev.pressed = si
	ev.strength = 1.0 if si else 0.0
	Input.parse_input_event(ev)
	if si:
		_apretados[i] = true
	else:
		_apretados.erase(i)


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

	# --- El stick ---
	var en_uso := _stick_dedo >= 0
	var c := _stick_centro if en_uso else centro_del_stick_en_reposo()
	_lienzo.draw_circle(c, RADIO_STICK, Color(0.02, 0.03, 0.06, 0.28 if en_uso else 0.18))
	_lienzo.draw_arc(c, RADIO_STICK, 0.0, TAU, 48, Color(1, 1, 1, 0.45 if en_uso else 0.25), 3.0, true)
	_lienzo.draw_circle(c + _stick_vector * RADIO_STICK, RADIO_PERILLA,
		Color(1, 1, 1, 0.45 if en_uso else 0.22))

	# --- Los botones ---
	for i: int in range(_botones.size()):
		if not _visible(i):
			continue
		_dibujar_boton(i, fuente)


func _dibujar_boton(i: int, fuente: Font) -> void:
	var b: Dictionary = _botones[i]
	var c := centro(i)
	var r: float = b["radio"]
	var apretado := _apretados.has(i)

	# Si se puede usar ahora. Un boton que no alcanza —sin stamina, sin carga— se apaga,
	# como las cartas del HUD que reemplaza.
	var usable := true
	var espera := 0.0
	var total := 0.0
	var extra := ""
	var h: int = b["habilidad"]
	if is_instance_valid(_jugador):
		if h >= 0:
			var hab := _jugador.caster.get_ability(h)
			if hab != null:
				espera = _jugador.caster.get_cooldown_remaining(h)
				total = hab.cooldown
				usable = hab.stamina_cost <= 0.0 or _jugador.stamina.current >= hab.stamina_cost
				# La definitiva pide ademas la carga llena. Si falta, dice cuanto tiene: sin
				# eso se ve apagado y no se sabe por que.
				if h == 3 and not _jugador.ultimate.is_ready():
					usable = false
					extra = "%d%%" % int(floor(_jugador.ultimate.get_ratio() * 100.0))
		elif b["accion"] == &"dash":
			var ratio := _jugador.get_dash_cooldown_ratio()
			if ratio > 0.0:
				espera = ratio * _jugador.dash_cooldown
				total = _jugador.dash_cooldown

	var fondo := Color(0.05, 0.07, 0.12, 0.42)
	if apretado:
		fondo = Color(UITheme.ACCENT, 0.55)
	_lienzo.draw_circle(c, r, fondo)
	if espera > 0.0 and total > 0.0:
		_torta(c, r, clampf(espera / total, 0.0, 1.0), Color(0, 0, 0, 0.55))
	var borde := Color(1, 1, 1, 0.6 if usable else 0.25)
	if h == 0:
		borde = Color(UITheme.ACCENT, 0.8)
	_lienzo.draw_arc(c, r, 0.0, TAU, 48, borde, 3.0, true)

	var texto: String = b["texto"]
	if espera > 0.0:
		texto = "%.1f" % espera
	var tam_fuente := 20 if r > 50.0 else (15 if r > 30.0 else 13)
	var color_texto := Color(1, 1, 1, 0.92 if usable else 0.45)
	_lienzo.draw_string(fuente, c + Vector2(-r, tam_fuente * 0.36), texto,
		HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, tam_fuente, color_texto)
	if not extra.is_empty():
		_lienzo.draw_string(fuente, c + Vector2(-r, tam_fuente * 0.36 + 16.0), extra,
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color(UITheme.GOLD, 0.9))


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
