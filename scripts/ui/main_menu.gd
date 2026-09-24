class_name MainMenu
extends Control
## Menu principal: modos offline, online por IP, pase y tienda.
##
## LAYOUT: MarginContainer -> VBox centrado -> panel con SHRINK_CENTER.
## La version anterior usaba un CenterContainer con un panel mas alto que la pantalla,
## y cuando el contenido no entra, el CenterContainer deja de centrar y lo tira contra
## el borde: los botones de abajo quedaban fuera de la ventana en 1280x720.
## Por eso el contenido de esta pantalla tiene que entrar en 720px de alto.
##
## Y ESO MANDA SOBRE TODO LO DEMAS. Al sumar los cuatro modos offline, el pase y la
## tienda, la lista de botones no entraba: los modos van en una grilla de dos por dos con
## el detalle abajo en vez de seis botones apilados, y eso no es estetica sino la unica
## forma de que el boton de SALIR siga estando dentro de la pantalla.

signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, ip: String, port: int)
## Un modo offline. `modo` es una de las constantes de Modos.
signal modo_requested(player_name: String, modo: StringName)
signal pase_requested()
signal tienda_requested()
signal quit_requested()

var message: String = ""

var _name_field: LineEdit = null
var _ip_field: LineEdit = null
var _port_field: LineEdit = null
var _message_label: Label = null
var _detalle: Label = null


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Mando.anotar(self)
	UITheme.build_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(outer)

	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	box.add_child(PerfilBarra.new())

	var title := UITheme.make_label("CROSSOVER ARENA", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var fila_nombre := HBoxContainer.new()
	fila_nombre.add_theme_constant_override("separation", 8)
	box.add_child(fila_nombre)
	fila_nombre.add_child(UITheme.make_label("Tu nombre", 13, UITheme.TEXT_DIM))
	_name_field = UITheme.make_line_edit("Nombre", Settings.player_name)
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.text_changed.connect(func(text: String) -> void: Settings.set_player_name(text))
	fila_nombre.add_child(_name_field)

	# --- Modos offline ---
	#
	# Primero, y no el online: el que baja el juego casi siempre esta solo, y si lo
	# primero que ve es "hostear / unirse" se va sin jugar.
	box.add_child(UITheme.make_label("JUGAR SOLO", 13, UITheme.TEXT_DIM))
	var grilla := GridContainer.new()
	grilla.columns = 2
	grilla.add_theme_constant_override("h_separation", 6)
	grilla.add_theme_constant_override("v_separation", 6)
	box.add_child(grilla)

	# La lista sale de Modos y no esta escrita aca: agregar un modo alla lo hace aparecer
	# aca solo, con su nombre y su descripcion. Van en el orden en que Modos los lista, que
	# es del mas parejo al mas dificil — el que abre el juego por primera vez tiene que
	# encontrar el duelo antes que la torre de jefes.
	for id: StringName in Modos.LISTA:
		var antes := Modos.actual
		Modos.actual = id
		var etiqueta := Modos.nombre().to_upper()
		Modos.actual = antes
		var boton := UITheme.make_button(etiqueta, id == Modos.DUELO)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		boton.pressed.connect(func() -> void: modo_requested.emit(_name_field.text, id))
		# Al pasar el mouse, el detalle abajo. Evita cuatro renglones de explicacion
		# permanentes, que es justo lo que no entra en la pantalla.
		boton.mouse_entered.connect(func() -> void: _mostrar_detalle(id))
		# Con el mando no hay mouse que pase por encima: el detalle sigue al foco.
		boton.focus_entered.connect(func() -> void: _mostrar_detalle(id))
		grilla.add_child(boton)

	_detalle = UITheme.make_label("Pasá el mouse por un modo para ver de qué se trata.",
		11, UITheme.TEXT_DIM)
	_detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detalle.custom_minimum_size = Vector2(0, 30)
	box.add_child(_detalle)

	box.add_child(HSeparator.new())

	# --- Online ---
	if not GameConfig.OFFICIAL_SERVER_URL.is_empty():
		var official := UITheme.make_button("JUGAR ONLINE", true)
		official.pressed.connect(func() -> void:
			join_requested.emit(_name_field.text, GameConfig.OFFICIAL_SERVER_URL, GameConfig.DEFAULT_PORT)
		)
		box.add_child(official)

	var fila_red := HBoxContainer.new()
	fila_red.add_theme_constant_override("separation", 6)
	box.add_child(fila_red)

	# Un navegador no puede escuchar en un puerto: solo puede ser cliente. Mostrar el
	# boton y que falle seria mentirle al jugador.
	if Net.can_host():
		var host_button := UITheme.make_button("HOSTEAR")
		host_button.custom_minimum_size = Vector2(120, 0)
		host_button.pressed.connect(_on_host_pressed)
		fila_red.add_child(host_button)

	_ip_field = UITheme.make_line_edit("Dirección del servidor", "127.0.0.1")
	_ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_red.add_child(_ip_field)

	_port_field = UITheme.make_line_edit("Puerto", str(GameConfig.DEFAULT_PORT))
	_port_field.custom_minimum_size = Vector2(84, 38)
	fila_red.add_child(_port_field)

	var join_button := UITheme.make_button("UNIRSE")
	join_button.custom_minimum_size = Vector2(110, 0)
	join_button.pressed.connect(_on_join_pressed)
	fila_red.add_child(join_button)

	if not Net.can_host():
		var web_note := UITheme.make_label(
			"Desde el navegador solo podés UNIRTE. Para hostear, bajá la versión de escritorio.",
			11, UITheme.TEXT_DIM)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(web_note)

	_message_label = UITheme.make_label(message, 12, UITheme.DANGER)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message_label)

	# El aviso de fin de temporada, una sola vez y en dorado: no es un error, es una
	# noticia. Se lo lleva el primer menu que lo muestra.
	var aviso := Pase.tomar_aviso()
	if not aviso.is_empty():
		var aviso_label := UITheme.make_label(aviso, 12, UITheme.GOLD)
		aviso_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		aviso_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(aviso_label)

	box.add_child(HSeparator.new())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	box.add_child(bottom)

	# El pase avisa cuando hay algo sin cobrar. Es lo unico que hace que alguien vuelva a
	# abrirlo: sin el punto, un pase con tres recompensas esperando se queda sin cobrar.
	var texto_pase := "PASE"
	if Pase.hay_algo_para_reclamar():
		texto_pase = "PASE ●"
	var b_pase := UITheme.make_button(texto_pase, Pase.hay_algo_para_reclamar())
	b_pase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_pase.pressed.connect(func() -> void: pase_requested.emit())
	bottom.add_child(b_pase)

	var b_tienda := UITheme.make_button("TIENDA")
	b_tienda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_tienda.pressed.connect(func() -> void: tienda_requested.emit())
	bottom.add_child(b_tienda)

	var options_button := UITheme.make_button("OPCIONES")
	options_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_button.pressed.connect(_open_options)
	bottom.add_child(options_button)

	var quit_button := UITheme.make_button("SALIR")
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	bottom.add_child(quit_button)


func _mostrar_detalle(modo: StringName) -> void:
	var antes := Modos.actual
	Modos.actual = modo
	_detalle.text = "%s — %s" % [Modos.nombre(), Modos.descripcion()]
	Modos.actual = antes


func _open_options() -> void:
	var options := OptionsMenu.new()
	options.closed.connect(func() -> void: options.queue_free())
	add_child(options)


func _get_port() -> int:
	var text := _port_field.text.strip_edges()
	if text.is_valid_int():
		return clampi(text.to_int(), 1024, 65535)
	return GameConfig.DEFAULT_PORT


func _on_host_pressed() -> void:
	host_requested.emit(_name_field.text, _get_port())


func _on_join_pressed() -> void:
	var ip := _ip_field.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	join_requested.emit(_name_field.text, ip, _get_port())
