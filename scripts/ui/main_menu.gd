class_name MainMenu
extends Control
## Menu principal: practicar solo, hostear o unirse por IP.
##
## LAYOUT: MarginContainer -> VBox centrado -> panel con SHRINK_CENTER.
## La version anterior usaba un CenterContainer con un panel mas alto que la pantalla,
## y cuando el contenido no entra, el CenterContainer deja de centrar y lo tira contra
## el borde: los botones de abajo quedaban fuera de la ventana en 1280x720.
## Por eso el contenido de esta pantalla tiene que entrar en 720px de alto.

signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, ip: String, port: int)
signal practice_requested(player_name: String)
signal quit_requested()

var message: String = ""

var _name_field: LineEdit = null
var _ip_field: LineEdit = null
var _port_field: LineEdit = null
var _message_label: Label = null


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	UITheme.build_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var outer := VBoxContainer.new()
	outer.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(outer)

	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	outer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := UITheme.make_label("CROSSOVER ARENA", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := UITheme.make_label("Habilidades de personajes de distintos juegos", 13, UITheme.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(UITheme.make_spacer(10))

	box.add_child(UITheme.make_label("Tu nombre", 13, UITheme.TEXT_DIM))
	_name_field = UITheme.make_line_edit("Nombre", Settings.player_name)
	_name_field.text_changed.connect(func(text: String) -> void: Settings.set_player_name(text))
	box.add_child(_name_field)

	box.add_child(UITheme.make_spacer(8))

	# Primero el modo practica: el que baja el juego casi siempre esta solo, y si lo
	# primero que ve es "hostear / unirse" se va sin jugar.
	var practice_button := UITheme.make_button("PRACTICAR SOLO", true)
	practice_button.pressed.connect(func() -> void: practice_requested.emit(_name_field.text))
	box.add_child(practice_button)

	var practice_hint := UITheme.make_label("Tres bots que pelean de verdad. No necesitas a nadie mas.", 11, UITheme.TEXT_DIM)
	practice_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(practice_hint)

	box.add_child(UITheme.make_spacer(8))
	box.add_child(HSeparator.new())
	box.add_child(UITheme.make_spacer(2))

	# Un boton para entrar al servidor publico sin escribir nada. Solo aparece si hay
	# uno configurado en GameConfig.
	if not GameConfig.OFFICIAL_SERVER_URL.is_empty():
		var official := UITheme.make_button("JUGAR ONLINE", true)
		official.pressed.connect(func() -> void:
			join_requested.emit(_name_field.text, GameConfig.OFFICIAL_SERVER_URL, GameConfig.DEFAULT_PORT)
		)
		box.add_child(official)
		var official_hint := UITheme.make_label("Servidor publico. Entras directo.", 11, UITheme.TEXT_DIM)
		official_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(official_hint)
		box.add_child(UITheme.make_spacer(6))

	# Un navegador no puede escuchar en un puerto: solo puede ser cliente. Mostrar el
	# boton y que falle seria mentirle al jugador.
	if Net.can_host():
		var host_button := UITheme.make_button("HOSTEAR PARTIDA")
		host_button.pressed.connect(_on_host_pressed)
		box.add_child(host_button)
	else:
		var web_note := UITheme.make_label(
			"Desde el navegador solo podes UNIRTE a un servidor. Para hostear, baja la version de escritorio.",
			11, UITheme.TEXT_DIM)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(web_note)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)

	_ip_field = UITheme.make_line_edit("Direccion del servidor", "127.0.0.1")
	_ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ip_field)

	_port_field = UITheme.make_line_edit("Puerto", str(GameConfig.DEFAULT_PORT))
	_port_field.custom_minimum_size = Vector2(100, 38)
	row.add_child(_port_field)

	var join_button := UITheme.make_button("UNIRSE")
	join_button.pressed.connect(_on_join_pressed)
	box.add_child(join_button)

	_message_label = UITheme.make_label(message, 13, UITheme.DANGER)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message_label)

	box.add_child(UITheme.make_spacer(8))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	box.add_child(bottom)

	var options_button := UITheme.make_button("OPCIONES")
	options_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_button.pressed.connect(_open_options)
	bottom.add_child(options_button)

	var quit_button := UITheme.make_button("SALIR")
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	bottom.add_child(quit_button)


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
