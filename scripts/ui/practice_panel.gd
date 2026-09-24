class_name PracticePanel
extends CanvasLayer
## El panel de la SALA DE PRACTICA. Se abre con P y solo existe en el modo practica.
##
## POR QUE UN PANEL Y NO UN PRESET. Cada cosa que uno va a ensayar quiere una sala
## distinta, y no hay una configuracion que sirva para todas:
##
##   - Mirar una animacion entera            -> sin cooldowns, bots quietos.
##   - Ensayar un combo largo                -> stamina infinita y no poder morir.
##   - Aprender a esquivar UN ataque         -> un solo bot, daño en cero.
##   - Ver que hace un kit que no jugas      -> que los bots se peleen entre ellos.
##   - Medir un duelo de verdad              -> todo como en una partida.
##
## Cambiar de una a otra tiene que costar dos clicks, no volver al menu y perder la
## posicion, los cooldowns y el medidor.
##
## VA AL COSTADO Y NO TAPA LA PANTALLA, a proposito: casi todos estos ajustes se juzgan
## MIRANDO la arena —cuantos bots hay, si se estan peleando, cuanto te pegan— asi que un
## panel centrado que tape el campo haria que tengas que cerrarlo para ver si lo que
## tocaste era lo que querias.

const ANCHO: float = 330.0

var _root: Control = null
var _abierto: bool = false
var _pista: Label = null
var _contador_bots: Label = null
var _botones_daño: Array[Button] = []
## Interruptor -> como leer su valor. Se relee entero en _refrescar().
var _interruptores: Dictionary = {}


func _ready() -> void:
	layer = 18
	_build()
	_root.visible = false
	Practica.cambio.connect(_refrescar)
	_refrescar()


# ------------------------------------------------------------------- Construccion

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	Mando.anotar(_root)

	var marco := UITheme.make_panel()
	marco.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	marco.offset_left = 12.0
	marco.offset_right = 12.0 + ANCHO
	marco.offset_top = 40.0
	marco.offset_bottom = -34.0
	marco.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(marco)

	# EN UN SCROLL, y hace falta: son nueve controles mas titulos, y a 720 de alto —que
	# es la resolucion de diseño— los ultimos quedaban fuera de la ventana. Ya me habia
	# pasado con la columna de habilidades del lobby.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	marco.add_child(scroll)

	var caja := VBoxContainer.new()
	caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caja.add_theme_constant_override("separation", 6)
	scroll.add_child(caja)

	var titulo := UITheme.make_label("SALA DE PRACTICA", 20)
	caja.add_child(titulo)
	_pista = UITheme.make_label("", 11, UITheme.TEXT_DIM)
	caja.add_child(_pista)
	caja.add_child(UITheme.make_spacer(6))

	# --- Los bots ---
	caja.add_child(UITheme.make_heading("LOS BOTS", 14))
	caja.add_child(_fila_contador())
	_agregar_interruptor(caja, "Que peleen", "bots_activos",
		func(v: bool) -> void: Practica.set_bots_activos(v))
	_agregar_interruptor(caja, "Que se peleen entre ellos", "bots_se_pelean",
		func(v: bool) -> void: Practica.set_bots_se_pelean(v))
	caja.add_child(UITheme.make_label("Dejan de ir solo por vos. Sirve para ver de afuera un kit que no jugas.",
		10, UITheme.TEXT_DIM))
	caja.add_child(UITheme.make_spacer(4))
	caja.add_child(UITheme.make_label("Cuanto pegan", 12, UITheme.TEXT_DIM))
	caja.add_child(_fila_daño())

	# --- El jugador ---
	caja.add_child(UITheme.make_spacer(8))
	caja.add_child(UITheme.make_heading("VOS", 14))
	_agregar_interruptor(caja, "Stamina infinita", "stamina_infinita",
		func(v: bool) -> void: Practica.set_stamina_infinita(v))
	_agregar_interruptor(caja, "Sin esperas entre habilidades", "sin_cooldowns",
		func(v: bool) -> void: Practica.set_sin_cooldowns(v))
	_agregar_interruptor(caja, "No puedo morir", "invulnerable",
		func(v: bool) -> void: Practica.set_invulnerable(v))
	caja.add_child(UITheme.make_label("La vida igual baja y se ve: lo unico que se saca es el respawn.",
		10, UITheme.TEXT_DIM))

	# --- Acciones ---
	caja.add_child(UITheme.make_spacer(10))
	var curar := UITheme.make_button("CURAR TODO", true)
	curar.pressed.connect(_curar_todo)
	caja.add_child(curar)
	var reiniciar := UITheme.make_button("VALORES DE FABRICA")
	reiniciar.pressed.connect(func() -> void: Practica.restablecer())
	caja.add_child(reiniciar)

	# UN BOTON PARA CERRAR, que antes no hacia falta: se cerraba con la misma tecla que lo
	# abre. Con el dedo no hay tecla —y los botones de la pantalla se esconden mientras el
	# panel esta abierto—, asi que sin esto quedaba abierto para siempre. B del mando
	# tambien lo aprieta.
	var cerrar_boton := UITheme.make_button("CERRAR")
	cerrar_boton.pressed.connect(cerrar)
	caja.add_child(cerrar_boton)
	cerrar_boton.set_meta(Mando.META_VOLVER, true)


## Fila de "Bots: [-] 3 [+]".
func _fila_contador() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)

	var etiqueta := UITheme.make_label("Cuantos", 13)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(etiqueta)

	var menos := UITheme.make_button("−")
	menos.custom_minimum_size = Vector2(38, 30)
	menos.pressed.connect(func() -> void: Practica.set_bots(Practica.bots - 1))
	fila.add_child(menos)

	_contador_bots = UITheme.make_label("3", 15)
	_contador_bots.custom_minimum_size = Vector2(28, 0)
	_contador_bots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(_contador_bots)

	var mas := UITheme.make_button("+")
	mas.custom_minimum_size = Vector2(38, 30)
	mas.pressed.connect(func() -> void: Practica.set_bots(Practica.bots + 1))
	fila.add_child(mas)
	return fila


## Fila de multiplicadores de daño. Botones y no un slider: son cuatro valores utiles y
## un slider obliga a apuntar con el mouse para conseguir el que querias.
func _fila_daño() -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 5)
	_botones_daño.clear()
	for valor: float in [0.0, 0.5, 1.0, 2.0]:
		var texto := "x0" if is_zero_approx(valor) else "x%s" % String.num(valor, 1).trim_suffix(".0")
		var boton := UITheme.make_button(texto)
		boton.custom_minimum_size = Vector2(0, 28)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.set_meta("valor", valor)
		boton.pressed.connect(func() -> void: Practica.set_daño_bots(valor))
		fila.add_child(boton)
		_botones_daño.append(boton)
	return fila


func _agregar_interruptor(caja: VBoxContainer, texto: String, campo: String,
		al_cambiar: Callable) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)

	var etiqueta := UITheme.make_label(texto, 13)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(etiqueta)

	var caja_check := CheckButton.new()
	caja_check.toggled.connect(al_cambiar)
	fila.add_child(caja_check)

	caja.add_child(fila)
	_interruptores[campo] = caja_check


# ------------------------------------------------------------------------ Estado

## Relee TODO desde Practica en vez de confiar en lo que muestran los controles.
##
## Hace falta porque los ajustes se pueden mover sin tocar el panel: "valores de fabrica"
## los cambia todos de una, y set_bots() recorta a su rango. Si el panel se dibujara solo
## en respuesta a los clicks, quedaria mostrando un numero que ya no es el que vale.
func _refrescar() -> void:
	if _contador_bots != null:
		_contador_bots.text = str(Practica.bots)
	for campo: String in _interruptores:
		var control := _interruptores[campo] as CheckButton
		if control == null:
			continue
		var valor := bool(Practica.get(campo))
		# set_pressed_no_signal: con set_pressed, refrescar dispararia toggled, que
		# llamaria a Practica, que emitiria cambio, que llamaria a refrescar otra vez.
		control.set_pressed_no_signal(valor)
	for boton: Button in _botones_daño:
		var elegido: bool = is_equal_approx(float(boton.get_meta("valor")), Practica.daño_bots)
		boton.modulate = Color.WHITE if elegido else Color(0.62, 0.66, 0.75)


## Devuelve a todos la vida y la stamina llenas, sin reiniciar la partida.
##
## Es el boton mas usado de un panel asi: despues de probar algo queres volver al estado
## inicial YA, y la alternativa —dejarte matar o esperar la regeneracion— desperdicia el
## rato en el que te acordas de lo que ibas a probar.
func _curar_todo() -> void:
	for node: Node in get_tree().get_nodes_in_group("players"):
		var jugador := node as Player
		if jugador == null or not is_instance_valid(jugador):
			continue
		jugador.health.revive_full()
		jugador.stamina.restore_full()
		jugador.status.clear_all()
		jugador.caster.reset_state()


# ------------------------------------------------------------------------ Apertura

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("practice_panel"):
		return
	# La puerta: fuera de la practica el panel no se abre ni existiendo el nodo.
	if not Practica.disponible():
		return
	if _abierto:
		cerrar()
	else:
		abrir()
	get_viewport().set_input_as_handled()


## Para que los chequeos puedan comprobar el atajo sin hurgar en variables privadas.
func esta_abierto() -> bool:
	return _abierto


func abrir() -> void:
	_abierto = true
	_root.visible = true
	_refrescar()
	# La tecla la dice Controles: con un mando es la cruceta, y con el dedo no hay tecla
	# (esta el boton de cerrar).
	_pista.text = "%s para cerrar" % Controles.nombre_tecla(&"practice_panel")
	_pista.visible = Controles.dispositivo != &"tactil"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func cerrar() -> void:
	_abierto = false
	_root.visible = false
	Controles.capturar_mouse()
