class_name ControlesMenu
extends Control
## Pantalla para cambiar las teclas. Se abre desde Opciones.
##
## Una fila por accion: el nombre y un boton con la tecla que tiene. Se aprieta el boton,
## se aprieta la tecla nueva, listo. Escape cancela.
##
## LA ESPERA SE ESCUCHA EN _input Y SE MARCA COMO USADA, y las dos cosas hacen falta. En
## _input porque corre antes que la interfaz: si no, apretar el boton izquierdo para
## asignarlo le haria click a lo que este abajo del mouse. Y marcada como usada porque si
## no, la tecla que elegiste ademas haria lo suyo —Escape cerraria el menu de abajo, E
## tiraria una habilidad si estas en partida— en el mismo instante en que la asignas.

signal cerrado()

var _filas: VBoxContainer = null
var _aviso: Label = null
## La accion que esta esperando tecla. &"" = ninguna.
var _esperando: StringName = &""
var _boton_esperando: Button = null
## Un frame de gracia: el click que empezo la espera no puede ser la tecla elegida.
var _listo_para_escuchar: bool = false


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var title := UITheme.make_label("CONTROLES", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var ayuda := UITheme.make_label(
		"Apretá el botón de una acción y después la tecla o el botón del mouse que quieras. Escape cancela. Si la tecla ya era de otra acción, se intercambian. La columna del mando es fija, y con el mando el stick derecho mueve la cámara.",
		11, UITheme.TEXT_DIM)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ayuda)

	# Con scroll: trece filas no entran en 720 de alto junto con el titulo y los botones.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_filas = VBoxContainer.new()
	_filas.add_theme_constant_override("separation", 5)
	_filas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_filas)

	_aviso = UITheme.make_label("", 12, UITheme.GOLD)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.custom_minimum_size = Vector2(0, 18)
	box.add_child(_aviso)

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 8)
	box.add_child(abajo)
	var restablecer := UITheme.make_button("RESTABLECER")
	restablecer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restablecer.pressed.connect(func() -> void:
		_cancelar()
		Controles.restablecer()
		_avisar("Volvieron las teclas de fábrica."))
	abajo.add_child(restablecer)
	var volver := UITheme.make_button("VOLVER", true)
	volver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volver.pressed.connect(func() -> void:
		_cancelar()
		cerrado.emit())
	abajo.add_child(volver)
	Mando.anotar(self, volver)

	Controles.cambio.connect(_armar)
	_armar()


func _exit_tree() -> void:
	if Controles.cambio.is_connected(_armar):
		Controles.cambio.disconnect(_armar)


func _armar() -> void:
	if not is_instance_valid(_filas):
		return
	for hijo: Node in _filas.get_children():
		hijo.queue_free()
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	_filas.add_child(cabecera)
	var vacio := Control.new()
	vacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(vacio)
	for par_titulo: Array in [["TECLADO Y MOUSE", 160], ["MANDO", 96]]:
		var t := UITheme.make_label(par_titulo[0], 11, UITheme.TEXT_DIM)
		t.custom_minimum_size = Vector2(par_titulo[1], 0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cabecera.add_child(t)
	for par: Array in Controles.ACCIONES:
		var accion := StringName(par[0])
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_filas.add_child(fila)

		var nombre := UITheme.make_label(par[1], 14)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nombre)

		# La tecla de TECLADO, aunque se este usando el mando: esta columna es la que se
		# reasigna, y tiene que decir lo que se va a cambiar.
		var boton := UITheme.make_button(Controles.nombre_evento(Controles.evento_de(accion)))
		boton.custom_minimum_size = Vector2(160, 34)
		boton.focus_mode = Control.FOCUS_NONE
		boton.pressed.connect(func() -> void: _empezar(accion, boton))
		fila.add_child(boton)

		# El mando se muestra y no se cambia: es la disposicion de los shooters de heroes,
		# la que ya sabe quien viene de cualquiera de ellos.
		var mando := UITheme.make_label(Controles.nombre_mando(accion), 13, UITheme.TEXT_DIM)
		mando.custom_minimum_size = Vector2(96, 0)
		mando.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fila.add_child(mando)


func _empezar(accion: StringName, boton: Button) -> void:
	_cancelar()
	_esperando = accion
	_boton_esperando = boton
	boton.text = "Apretá una tecla…"
	_listo_para_escuchar = false
	# El boton se dispara al SOLTAR el click. Un frame despues ya no queda nada de ese
	# click en camino, y lo proximo que llegue es la tecla que el jugador eligio.
	await get_tree().process_frame
	_listo_para_escuchar = true


func _cancelar() -> void:
	if is_instance_valid(_boton_esperando) and _esperando != &"":
		_boton_esperando.text = Controles.nombre_evento(Controles.evento_de(_esperando))
	_esperando = &""
	_boton_esperando = null
	_listo_para_escuchar = false


func _input(event: InputEvent) -> void:
	if _esperando == &"" or not _listo_para_escuchar:
		return
	# Escape cancela la espera, y solo eso: no cierra el menu.
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and \
			(k.physical_keycode == KEY_ESCAPE or k.keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_cancelar()
		return
	if not Controles.es_valido(event):
		return
	get_viewport().set_input_as_handled()
	var accion := _esperando
	_esperando = &""
	_boton_esperando = null
	var con := Controles.reasignar(accion, event)
	if con.is_empty():
		_avisar("%s: %s" % [Controles.nombre_accion(accion), _tecla(accion)])
	else:
		# Se avisa el intercambio: si no, la otra accion cambia de tecla sin que nadie se
		# entere y la proxima partida "deja de andar" el salto.
		_avisar("%s ahora es %s. %s pasó a la tecla anterior." % [
			Controles.nombre_accion(accion), _tecla(accion), con])


func _tecla(accion: StringName) -> String:
	return Controles.nombre_evento(Controles.evento_de(accion))


func _avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.6)
