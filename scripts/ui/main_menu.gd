class_name MainMenu
extends Control
## Menu principal.
##
## REHECHO ENTERO EL 2026-10-02, a pedido ("cambia por completo el menu inicial"). Antes era
## un panel centrado con trece botones de modo en una grilla apretada, el online y la
## tienda, todo con la misma jerarquia: una planilla. Ahora es una portada:
##
##   - A LA IZQUIERDA, el logo, tu perfil y las acciones grandes: JUGAR, HISTORIA, ONLINE,
##     y abajo el pase, la tienda, las opciones y salir.
##   - A LA DERECHA, TU PERSONAJE: de cuerpo entero, girando, con su skin, y flechas para
##     cambiarlo. El que elegis aca es el que aparece elegido en la sala de espera.
##   - JUGAR NO ARRANCA NADA: cambia la vitrina por las TARJETAS DE LOS MODOS, cada una con
##     su color, su nombre y su descripcion entera. Antes la descripcion aparecia solo al
##     pasar el mouse, y con el mando —o en el celular— no se veia nunca.
##
## TODO TIENE QUE ENTRAR EN 1280x720 (ver todo_a_la_vista y solo_test): la version vieja
## perdio el boton de SALIR fuera de la pantalla dos veces.

signal host_requested(player_name: String, port: int)
signal join_requested(player_name: String, ip: String, port: int)
## Un modo offline. `modo` es una de las constantes de Modos.
signal modo_requested(player_name: String, modo: StringName)
signal pase_requested()
signal tienda_requested()
signal historia_requested(player_name: String)
signal quit_requested()

var message: String = ""

var _name_field: LineEdit = null
var _ip_field: LineEdit = null
var _port_field: LineEdit = null
var _message_label: Label = null
## La derecha: la vitrina del personaje o las tarjetas de los modos.
var _vitrina_caja: VBoxContainer = null
var _vitrina: Control = null
var _nombre_pj: Label = null
var _detalle_pj: Label = null
var _modos_caja: VBoxContainer = null
var _boton_jugar: Button = null
var _personaje: StringName = &"noelle"

## Un color por modo, para que las tarjetas se distingan de un vistazo.
const COLOR_MODO: Dictionary = {
	&"duelo": Color(0.42, 0.78, 1.0),
	&"caos": Color(0.95, 0.35, 0.80),
	&"bomba": Color(1.0, 0.55, 0.18),
	&"toque": Color(1.0, 0.35, 0.35),
	&"contrarreloj": Color(1.0, 0.85, 0.30),
	&"esferas": Color(1.0, 0.72, 0.22),
	&"colina": Color(0.45, 0.92, 0.55),
	&"campal": Color(0.70, 0.50, 1.0),
	&"meteoritos": Color(1.0, 0.45, 0.25),
	&"supervivencia": Color(0.35, 0.90, 0.85),
	&"ultimo_en_pie": Color(0.92, 0.25, 0.35),
	&"jefes": Color(0.80, 0.45, 1.0),
	&"practica": Color(0.62, 0.68, 0.78),
}


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Mando.anotar(self)
	UITheme.build_background(self)
	_personaje = _personaje_inicial()

	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 52)
	margen.add_theme_constant_override("margin_right", 40)
	margen.add_theme_constant_override("margin_top", 26)
	margen.add_theme_constant_override("margin_bottom", 22)
	add_child(margen)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 30)
	margen.add_child(fila)

	fila.add_child(_armar_izquierda())

	var derecha := Control.new()
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	derecha.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fila.add_child(derecha)
	_vitrina_caja = _armar_vitrina()
	derecha.add_child(_vitrina_caja)
	_modos_caja = _armar_modos()
	_modos_caja.visible = false
	derecha.add_child(_modos_caja)


# ------------------------------------------------------------------ Izquierda

func _armar_izquierda() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(470, 0)
	col.add_theme_constant_override("separation", 8)

	# --- El logo ---
	var logo := VBoxContainer.new()
	logo.add_theme_constant_override("separation", -14)
	col.add_child(logo)
	logo.add_child(_letras("CROSSOVER", 58, UITheme.TEXT))
	logo.add_child(_letras("ARENA", 58, UITheme.ACCENT))
	var temporada := UITheme.make_label(Pase.NOMBRE.to_upper(), 14, UITheme.GOLD)
	col.add_child(temporada)
	var raya := Panel.new()
	raya.custom_minimum_size = Vector2(120, 3)
	raya.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	raya.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.GOLD, 2))
	col.add_child(raya)
	col.add_child(UITheme.make_spacer(2))

	col.add_child(PerfilBarra.new())

	var fila_nombre := HBoxContainer.new()
	fila_nombre.add_theme_constant_override("separation", 8)
	col.add_child(fila_nombre)
	fila_nombre.add_child(UITheme.make_label("Tu nombre", 13, UITheme.TEXT_DIM))
	_name_field = UITheme.make_line_edit("Nombre", Settings.player_name)
	_name_field.custom_minimum_size = Vector2(0, 36)
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_field.text_changed.connect(func(text: String) -> void: Settings.set_player_name(text))
	fila_nombre.add_child(_name_field)

	# --- Las acciones grandes ---
	_boton_jugar = UITheme.make_big_button("▶  JUGAR", UITheme.ACCENT, "Duelo, bomba, supervivencia y diez modos más")
	_boton_jugar.pressed.connect(func() -> void: mostrar_modos(not _modos_caja.visible))
	col.add_child(_boton_jugar)

	var b_historia := UITheme.make_big_button("MODO HISTORIA", UITheme.GOLD,
		"Seis partes, con escenas, aliados y rutas secretas")
	b_historia.pressed.connect(func() -> void: historia_requested.emit(_name_field.text))
	col.add_child(b_historia)

	if not GameConfig.OFFICIAL_SERVER_URL.is_empty():
		var online := UITheme.make_big_button("JUGAR ONLINE", Color(0.55, 0.95, 0.65),
			"Contra otros jugadores, en el servidor público")
		online.pressed.connect(func() -> void:
			join_requested.emit(_name_field.text, GameConfig.OFFICIAL_SERVER_URL, GameConfig.DEFAULT_PORT))
		col.add_child(online)

	# La partida privada, chica: es lo que usa uno de cada cien.
	var fila_red := HBoxContainer.new()
	fila_red.add_theme_constant_override("separation", 6)
	col.add_child(fila_red)
	# Un navegador no puede escuchar en un puerto: solo puede ser cliente. Mostrar el
	# boton y que falle seria mentirle al jugador.
	if Net.can_host():
		var host_button := _chico(UITheme.make_button("HOSTEAR"))
		host_button.custom_minimum_size = Vector2(96, 36)
		host_button.pressed.connect(_on_host_pressed)
		fila_red.add_child(host_button)
	_ip_field = UITheme.make_line_edit("Dirección del servidor", "127.0.0.1")
	_ip_field.custom_minimum_size = Vector2(0, 36)
	_ip_field.add_theme_font_size_override("font_size", 14)
	_ip_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila_red.add_child(_ip_field)
	_port_field = UITheme.make_line_edit("Puerto", str(GameConfig.DEFAULT_PORT))
	_port_field.custom_minimum_size = Vector2(76, 36)
	_port_field.add_theme_font_size_override("font_size", 14)
	fila_red.add_child(_port_field)
	var join_button := _chico(UITheme.make_button("UNIRSE"))
	join_button.custom_minimum_size = Vector2(90, 36)
	join_button.pressed.connect(_on_join_pressed)
	fila_red.add_child(join_button)
	if not Net.can_host():
		var web_note := UITheme.make_label(
			"Desde el navegador solo podés UNIRTE. Para hostear, bajá la versión de escritorio.",
			11, UITheme.TEXT_DIM)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(web_note)

	_message_label = UITheme.make_label(message, 12, UITheme.DANGER)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.visible = not message.is_empty()
	col.add_child(_message_label)
	# El aviso de fin de temporada, una sola vez y en dorado: no es un error, es una
	# noticia. Se lo lleva el primer menu que lo muestra.
	var aviso := Pase.tomar_aviso()
	if not aviso.is_empty():
		var aviso_label := UITheme.make_label(aviso, 12, UITheme.GOLD)
		aviso_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(aviso_label)

	var resto := Control.new()
	resto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(resto)

	# --- Abajo: pase, tienda, opciones, salir ---
	var abajo := GridContainer.new()
	abajo.columns = 4
	abajo.add_theme_constant_override("h_separation", 6)
	col.add_child(abajo)
	# El pase avisa cuando hay algo sin cobrar. Es lo unico que hace que alguien vuelva a
	# abrirlo: sin el punto, un pase con tres recompensas esperando se queda sin cobrar.
	var hay_pase := Pase.hay_algo_para_reclamar()
	var b_pase := _chico(UITheme.make_button("PASE ●" if hay_pase else "PASE", hay_pase))
	b_pase.pressed.connect(func() -> void: pase_requested.emit())
	abajo.add_child(b_pase)
	var b_tienda := _chico(UITheme.make_button("TIENDA"))
	b_tienda.pressed.connect(func() -> void: tienda_requested.emit())
	abajo.add_child(b_tienda)
	var b_opciones := _chico(UITheme.make_button("OPCIONES"))
	b_opciones.pressed.connect(_open_options)
	abajo.add_child(b_opciones)
	var b_salir := _chico(UITheme.make_button("SALIR"))
	b_salir.pressed.connect(func() -> void: quit_requested.emit())
	abajo.add_child(b_salir)
	return col


## Letras del logo: grandes, con contorno y sombra. El juego no tiene tipografia propia, y
## esto es lo que hace que el titulo se lea como un logo y no como un renglon.
func _letras(texto: String, tam: int, color: Color) -> Label:
	var l := UITheme.make_label(texto, tam, color)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.08, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 5)
	return l


func _chico(boton: Button) -> Button:
	boton.custom_minimum_size = Vector2(0, 38)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.add_theme_font_size_override("font_size", 14)
	return boton


# ------------------------------------------------------------------- La vitrina

func _armar_vitrina() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 4)
	_vitrina = Retrato.vitrina(_personaje, Vector2(560, 520))
	_vitrina.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	caja.add_child(_vitrina)

	var placa := HBoxContainer.new()
	placa.alignment = BoxContainer.ALIGNMENT_CENTER
	placa.add_theme_constant_override("separation", 14)
	caja.add_child(placa)
	var antes := _chico(UITheme.make_button("◀"))
	antes.custom_minimum_size = Vector2(52, 44)
	antes.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	antes.pressed.connect(func() -> void: _cambiar_personaje(-1))
	placa.add_child(antes)
	var textos := VBoxContainer.new()
	textos.custom_minimum_size = Vector2(300, 0)
	textos.add_theme_constant_override("separation", 0)
	placa.add_child(textos)
	_nombre_pj = _letras("", 30, UITheme.TEXT)
	_nombre_pj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	textos.add_child(_nombre_pj)
	_detalle_pj = UITheme.make_label("", 13, UITheme.TEXT_DIM)
	_detalle_pj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	textos.add_child(_detalle_pj)
	var despues := _chico(UITheme.make_button("▶"))
	despues.custom_minimum_size = Vector2(52, 44)
	despues.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	despues.pressed.connect(func() -> void: _cambiar_personaje(1))
	placa.add_child(despues)
	_poner_placa()
	return caja


## El personaje de la vitrina: el ultimo que elegiste, si lo podes usar.
func _personaje_inicial() -> StringName:
	var ultimo := StringName(Net.local_character_id)
	if CharacterDB.get_character(ultimo) != null and Progreso.puede_usar_personaje(ultimo):
		return ultimo
	return &"noelle"


func _cambiar_personaje(paso: int) -> void:
	var usables: Array[StringName] = []
	for id: StringName in CharacterDB.get_all_ids():
		if Progreso.puede_usar_personaje(id):
			usables.append(id)
	if usables.is_empty():
		return
	var i := usables.find(_personaje)
	_personaje = usables[(i + paso + usables.size()) % usables.size()]
	# El que elegis aca es el que aparece elegido en la sala de espera.
	Net.set_local_character(String(_personaje))
	var nueva := Retrato.vitrina(_personaje, Vector2(560, 520))
	nueva.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lugar := _vitrina.get_index()
	_vitrina.queue_free()
	_vitrina_caja.add_child(nueva)
	_vitrina_caja.move_child(nueva, lugar)
	_vitrina = nueva
	_poner_placa()


func _poner_placa() -> void:
	var data := CharacterDB.get_character(_personaje)
	if data == null:
		return
	_nombre_pj.text = data.display_name.to_upper()
	var skin := SkinDB.get_skin(Progreso.skin_de(_personaje))
	_detalle_pj.text = "%s  ·  %s" % [data.origin_game,
		skin.display_name if skin != null else "Ropa de fábrica"]


# ---------------------------------------------------------------------- Modos

func _armar_modos() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caja.add_theme_constant_override("separation", 10)

	var cabeza := HBoxContainer.new()
	caja.add_child(cabeza)
	var titulo := _letras("ELEGÍ UN MODO", 30, UITheme.TEXT)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabeza.add_child(titulo)
	var volver := _chico(UITheme.make_button("VOLVER"))
	volver.custom_minimum_size = Vector2(120, 40)
	volver.size_flags_horizontal = Control.SIZE_SHRINK_END
	volver.pressed.connect(func() -> void: mostrar_modos(false))
	cabeza.add_child(volver)

	var grilla := GridContainer.new()
	grilla.columns = 3
	grilla.add_theme_constant_override("h_separation", 10)
	grilla.add_theme_constant_override("v_separation", 10)
	caja.add_child(grilla)
	# La lista sale de Modos y no esta escrita aca: agregar un modo alla lo hace aparecer
	# aca solo, con su nombre y su descripcion. Van en el orden en que Modos los lista, que
	# es del mas parejo al mas dificil.
	for id: StringName in Modos.LISTA:
		grilla.add_child(_tarjeta_modo(id))
	return caja


## Una tarjeta: la franja de color del modo, el nombre y la descripcion entera.
func _tarjeta_modo(id: StringName) -> Button:
	var antes := Modos.actual
	Modos.actual = id
	var nombre := Modos.nombre().to_upper()
	var desc := Modos.descripcion()
	Modos.actual = antes
	var color: Color = COLOR_MODO.get(id, UITheme.ACCENT)
	var tarjeta := UITheme.make_card_button(color)
	tarjeta.custom_minimum_size = Vector2(0, 112)
	tarjeta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tarjeta.tooltip_text = desc
	tarjeta.pressed.connect(func() -> void: modo_requested.emit(_name_field.text, id))
	var textos := VBoxContainer.new()
	textos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	textos.offset_left = 16
	textos.offset_right = -10
	textos.offset_top = 9
	textos.offset_bottom = -6
	textos.add_theme_constant_override("separation", 3)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(textos)
	var t := UITheme.make_label(nombre, 16, color.lightened(0.25))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(t)
	var d := UITheme.make_label(desc, 11, UITheme.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 4
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(d)
	return tarjeta


## Muestra las tarjetas de los modos en lugar del personaje, o al reves.
func mostrar_modos(si: bool) -> void:
	_modos_caja.visible = si
	_vitrina_caja.visible = not si
	UITheme.big_button_text(_boton_jugar, "◀  VOLVER" if si else "▶  JUGAR")
	if si:
		# Con el mando, el foco salta a la primera tarjeta: si no, habria que cruzar todo
		# el menu para llegar a lo que se acaba de abrir.
		var primera := _modos_caja.find_children("*", "Button", true, false)
		for b: Node in primera:
			if b is Button and (b as Button).tooltip_text != "":
				(b as Button).grab_focus.call_deferred()
				break


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


## Todos los botones adentro de la pantalla. Lo vigila solo_test: cada modo nuevo suma una
## tarjeta, y dos veces ya empujaron SALIR fuera de los 720 de alto.
func todo_a_la_vista() -> bool:
	var vista := get_viewport_rect()
	for nodo: Node in find_children("*", "Button", true, false):
		var boton := nodo as Button
		if boton.is_visible_in_tree() and not vista.encloses(boton.get_global_rect()):
			return false
	return true
