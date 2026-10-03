class_name Lobby
extends Control
## Sala de espera: quien esta conectado, que personaje elegis y su kit.
##
## El selector de personajes se arma solo desde CharacterDB, asi que cuando sumes
## un personaje nuevo aparece aca sin tocar una linea de esta pantalla.

signal start_requested()
signal leave_requested()

var _player_list: VBoxContainer = null
var _character_list: GridContainer = null
var _character_scroll: ScrollContainer = null
var _kit_box: VBoxContainer = null
var _start_button: Button = null
var _status_label: Label = null
## EL MAPA: el nombre y, al host (o jugando offline), las flechas para cambiarlo.
var _mapa_label: Label = null
var _mapa_ant: Button = null
var _mapa_sig: Button = null

var _selected_id: StringName = &"noelle"


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Sin boton de volver para B: en la sala, volver es irse de la partida, y eso no puede
	# pasar por apretar el boton equivocado.
	Mando.anotar(self)
	_selected_id = StringName(Net.local_character_id)
	# Uno que todavia no se gano no puede quedar elegido de antes —por un archivo tocado a
	# mano, o por el arnes—: se vuelve al de fabrica.
	if not Progreso.puede_usar_personaje(_selected_id):
		_selected_id = CharacterDB.get_default_id()
		Net.set_local_character(String(_selected_id))

	UITheme.build_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(UITheme.make_title("SALA DE ESPERA"))

	_status_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# --- Columna 1: jugadores conectados ---
	var players_panel := UITheme.make_panel()
	players_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(players_panel)
	var players_box := VBoxContainer.new()
	players_box.add_theme_constant_override("separation", 6)
	players_panel.add_child(players_box)
	players_box.add_child(UITheme.make_heading("JUGADORES"))
	_player_list = VBoxContainer.new()
	_player_list.add_theme_constant_override("separation", 4)
	players_box.add_child(_player_list)
	# EL PERSONAJE ELEGIDO, EN 3D Y GIRANDO, en el lugar que antes quedaba vacio debajo de
	# la lista de jugadores. Se rehace al elegir otro (ver _poner_vitrina).
	var resto := Control.new()
	resto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	players_box.add_child(resto)
	_vitrina_lugar = VBoxContainer.new()
	_vitrina_lugar.alignment = BoxContainer.ALIGNMENT_END
	players_box.add_child(_vitrina_lugar)
	_poner_vitrina()

	# --- Columna 2: seleccion de personaje ---
	var chars_panel := UITheme.make_panel()
	chars_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(chars_panel)
	var chars_box := VBoxContainer.new()
	chars_box.add_theme_constant_override("separation", 6)
	chars_panel.add_child(chars_box)
	chars_box.add_child(UITheme.make_heading("PERSONAJE"))
	# EN DOS COLUMNAS Y CON SCROLL, por lo mismo que el kit de al lado: con diez personajes
	# en fila de a uno la lista crecio mas que la pantalla y empujo "EMPEZAR PARTIDA" y
	# "VOLVER AL MENU" fuera de los 720px (2026-09-26). En dos columnas entran de sobra, y
	# el scroll queda de respaldo para los que vengan.
	_character_scroll = ScrollContainer.new()
	_character_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_character_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chars_box.add_child(_character_scroll)
	_character_list = GridContainer.new()
	_character_list.columns = 2
	_character_list.add_theme_constant_override("h_separation", 6)
	_character_list.add_theme_constant_override("v_separation", 6)
	_character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_scroll.add_child(_character_list)

	# --- Columna 3: kit del personaje ---
	#
	# CON SCROLL, y no es opcional: al pasar de 3 a 4 habilidades esta columna crecio
	# mas alto que la pantalla y empujo los botones "VOLVER AL MENU" y "EMPEZAR" fuera
	# de los 720px. El scroll hace que la sala aguante los kits que vengan sin que haya
	# que acordarse de revisar el alto cada vez.
	var kit_panel := UITheme.make_panel()
	kit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(kit_panel)
	var kit_scroll := ScrollContainer.new()
	kit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	kit_panel.add_child(kit_scroll)
	_kit_box = VBoxContainer.new()
	_kit_box.add_theme_constant_override("separation", 8)
	# Sin esto el VBox toma su ancho minimo y el texto se apretuja en una columna fina.
	_kit_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kit_scroll.add_child(_kit_box)

	# --- Botones ---
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.custom_minimum_size = Vector2(0, 44)
	root.add_child(buttons)

	var leave_button := UITheme.make_button("VOLVER AL MENU")
	leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave_button.pressed.connect(func() -> void: leave_requested.emit())
	buttons.add_child(leave_button)

	# --- El mapa: los lugares de la historia, en los modos normales ---
	var mapa_caja := HBoxContainer.new()
	mapa_caja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mapa_caja.add_theme_constant_override("separation", 6)
	buttons.add_child(mapa_caja)
	_mapa_ant = UITheme.make_button("<")
	_mapa_ant.custom_minimum_size = Vector2(46, 46)
	_mapa_ant.pressed.connect(func() -> void: _cambiar_mapa(-1))
	mapa_caja.add_child(_mapa_ant)
	_mapa_label = UITheme.make_label("", 15)
	_mapa_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mapa_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mapa_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mapa_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mapa_caja.add_child(_mapa_label)
	_mapa_sig = UITheme.make_button(">")
	_mapa_sig.custom_minimum_size = Vector2(46, 46)
	_mapa_sig.pressed.connect(func() -> void: _cambiar_mapa(1))
	mapa_caja.add_child(_mapa_sig)
	Net.mapa_cambiado.connect(_refresh_mapa)
	# La sala vuelve al mapa que eligio el jugador: la historia lo pudo haber cambiado por
	# el lugar de un capitulo.
	if Net.is_server():
		var quiero := Mapas.preferido if Mapas.preferido in Mapas.disponibles() else &"coliseo"
		Net.elegir_mapa(quiero)

	_start_button = UITheme.make_button("EMPEZAR PARTIDA", true)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	buttons.add_child(_start_button)

	Net.player_list_changed.connect(_refresh)
	_build_character_list()
	_refresh()
	_refresh_mapa()


## La vitrina del personaje elegido, con su skin puesta.
var _vitrina_lugar: VBoxContainer = null


func _poner_vitrina() -> void:
	if not is_instance_valid(_vitrina_lugar):
		return
	for hijo: Node in _vitrina_lugar.get_children():
		hijo.queue_free()
	var vitrina := Retrato.vitrina(_selected_id, Vector2(300, 330))
	vitrina.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vitrina_lugar.add_child(vitrina)


func _exit_tree() -> void:
	if Net.player_list_changed.is_connected(_refresh):
		Net.player_list_changed.disconnect(_refresh)
	if Net.mapa_cambiado.is_connected(_refresh_mapa):
		Net.mapa_cambiado.disconnect(_refresh_mapa)


func _cambiar_mapa(paso: int) -> void:
	if not Net.is_server():
		return
	Mapas.preferido = Mapas.siguiente(Mapas.elegido, paso)
	Net.elegir_mapa(Mapas.preferido)


func _refresh_mapa() -> void:
	if _mapa_label == null:
		return
	var tema := Mapas.actual()
	_mapa_label.text = "MAPA: %s" % String(tema["nombre"])
	_mapa_label.tooltip_text = String(tema.get("lugar", ""))
	var puede := Net.is_server()
	_mapa_ant.visible = puede
	_mapa_sig.visible = puede


## Mientras esperamos que conteste el servidor, el cartel cuenta los segundos.
##
## Sin esto la sala se ve identica a una sala vacia y funcionando, y el jugador se va
## pensando que no anda justo cuando faltaban veinte segundos.
func _process(_delta: float) -> void:
	if not Net.is_joining():
		return
	var secs := int(Net.join_elapsed())
	if secs < 6:
		_status_label.text = "Conectando al servidor..."
	else:
		var linea := "Despertando el servidor gratuito... %ds" % secs
		_status_label.text = linea + "\nSe apaga cuando no hay nadie jugando; el primero en entrar lo prende."


func _build_character_list() -> void:
	for child: Node in _character_list.get_children():
		child.queue_free()
	for id: StringName in CharacterDB.get_all_ids():
		var data := CharacterDB.get_character(id)
		# BLOQUEADO SE MUESTRA IGUAL, y diciendo como se gana. Esconderlo haria que nadie
		# supiera que existe, y un premio que no se ve no motiva a nadie.
		# Solo el nombre: la serie de la que viene sale arriba del kit, y con ella el boton
		# no entraba en media columna.
		if not Progreso.puede_usar_personaje(id):
			var cerrado: Button
			if data.como_se_gana != "":
				# Los que no son del pase (Sukuna, de la historia) dicen de donde salen.
				cerrado = UITheme.make_button("🔒  %s  ·  historia" % data.display_name)
				cerrado.tooltip_text = "Se gana %s." % data.como_se_gana
			else:
				cerrado = UITheme.make_button("🔒  %s  ·  pase pro T%d" % [data.display_name, Pase.TEMPORADA])
				cerrado.tooltip_text = "Completá el pase pro de la temporada %d para jugarlo." % Pase.TEMPORADA
			cerrado.disabled = true
			_boton_de_lista(cerrado)
			continue
		# UNA TARJETA DE SU COLOR, con el nombre: la lista se lee como un plantel y no como
		# una columna de botones iguales. El elegido, con la flecha y mas encendido.
		var elegido := id == _selected_id
		var tono := _color_de(data)
		var button := UITheme.make_card_button(tono.lightened(0.1) if elegido else tono.darkened(0.25))
		button.tooltip_text = data.origin_game
		button.pressed.connect(_on_character_picked.bind(id))
		var nombre := UITheme.make_label(("▶ " if elegido else "") + data.display_name, 15,
			UITheme.TEXT if elegido else UITheme.TEXT_DIM.lightened(0.2))
		nombre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		nombre.offset_left = 14
		nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nombre.clip_text = true
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(nombre)
		_boton_de_lista(button)


## El color que mejor dice quien es: el mas vivo entre el del acento y el del cuerpo. Con el
## acento solo, los de acento oscuro (Flowery, Scorpion, Naruto) quedaban con la tarjeta negra.
static func _color_de(data: CharacterData) -> Color:
	var mejor := data.accent_color
	for c: Color in [data.accent_color, data.body_color]:
		if c.s * c.v > mejor.s * mejor.v:
			mejor = c
	if mejor.v < 0.55:
		mejor = Color.from_hsv(mejor.h, mejor.s, 0.75)
	return mejor


## Un boton de la lista de personajes: mas bajo que los demas y estirado a su columna.
func _boton_de_lista(boton: Button) -> void:
	boton.custom_minimum_size = Vector2(0, 42)
	boton.add_theme_font_size_override("font_size", 15)
	boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boton.clip_text = true
	_character_list.add_child(boton)


## Entran todos los personajes sin tener que bajar, y los botones de abajo en la pantalla?
## Lo mira el test: es la pregunta que hay que volver a hacerse cada vez que llega uno.
func todo_a_la_vista() -> bool:
	var alto := get_viewport_rect().size.y
	var lista_entra := _character_list.get_combined_minimum_size().y <= _character_scroll.size.y + 0.5
	return lista_entra and _start_button.get_global_rect().end.y <= alto \
		and _character_scroll.get_global_rect().end.y <= alto


func _on_character_picked(id: StringName) -> void:
	if not Progreso.puede_usar_personaje(id):
		return
	_selected_id = id
	Net.set_local_character(String(id))
	_build_character_list()
	_build_kit()
	_poner_vitrina()


func _build_kit() -> void:
	for child: Node in _kit_box.get_children():
		child.queue_free()

	var data := CharacterDB.get_character(_selected_id)
	if data == null:
		return
	_kit_box.add_child(UITheme.make_heading(data.display_name.to_upper()))
	_kit_box.add_child(UITheme.make_label("De: %s" % data.origin_game, 13, UITheme.TEXT_DIM))
	_kit_box.add_child(UITheme.make_spacer(4))

	# La tecla de cada una sale de Controles, no de una lista escrita aca.
	var keys: Array[String] = []
	for accion: StringName in HUD.ACCIONES_HABILIDAD:
		keys.append(Controles.nombre_tecla(accion))
	var abilities := CharacterDB.build_abilities_for(_selected_id)
	for i: int in range(abilities.size()):
		var ability := abilities[i]
		var key_hint := keys[i] if i < keys.size() else "-"
		var header := UITheme.make_label("%s  [%s]" % [ability.display_name, key_hint], 15, ability.icon_color)
		_kit_box.add_child(header)

		var cost_text := "Sin costo de stamina" if ability.stamina_cost <= 0.0 else "%d de stamina" % int(ability.stamina_cost)
		var meta := "%s  ·  %.1fs de cooldown" % [cost_text, ability.cooldown]
		if ability.channel_time > 0.0:
			meta += "  ·  canaliza %.1fs" % ability.channel_time
		if ability.requires_charge:
			meta += "  ·  necesita el medidor al 100%"
		_kit_box.add_child(UITheme.make_label(meta, 12, UITheme.TEXT_DIM))

		var desc := UITheme.make_label(ability.description, 12, UITheme.TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_kit_box.add_child(desc)
		_kit_box.add_child(UITheme.make_spacer(6))

	if not data.pasiva.is_empty():
		var pasiva := UITheme.make_label(data.pasiva, 12, UITheme.GOLD)
		pasiva.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_kit_box.add_child(pasiva)
		_kit_box.add_child(UITheme.make_spacer(6))
	_kit_box.add_child(UITheme.make_label(
		"Correr, golpear y dashear no gastan stamina. Solo las habilidades.",
		12, UITheme.HEALTH))
	_kit_box.add_child(UITheme.make_label(
		"El ultimate cuesta la barra entera Y el medidor al 100%, que se carga pegando.",
		12, UITheme.GOLD))


func _refresh() -> void:
	for child: Node in _player_list.get_children():
		child.queue_free()

	var ids := Net.players.keys()
	ids.sort()
	for id: int in ids:
		var info: Dictionary = Net.players[id]
		var data := CharacterDB.get_character(StringName(String(info.get("character_id", "noelle"))))
		var suffix := "  (host)" if id == 1 else ""
		var you := "  <- vos" if id == Net.local_id() else ""
		var text := "%s%s  —  %s%s" % [String(info.get("name", "???")), suffix, data.display_name if data != null else "?", you]
		_player_list.add_child(UITheme.make_label(text, 15))

	_start_button.visible = Net.is_server()
	if Net.solo_mode:
		_start_button.text = "EMPEZAR PRACTICA"
		_status_label.text = "Modo practica: tres bots que te devuelven los golpes, sin red. Elegi personaje y arranca."
	elif Net.is_server():
		_start_button.text = "EMPEZAR PARTIDA"
		_status_label.text = "Sos el host. Compartí tu IP para que se unan. Jugadores: %d/%d" % [Net.players.size(), GameConfig.MAX_PLAYERS]
	elif not Net.is_joining():
		_status_label.text = "Conectado. Esperando a que el host empiece la partida..."

	_build_kit()
