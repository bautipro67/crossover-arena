class_name Lobby
extends Control
## Sala de espera: quien esta conectado, que personaje elegis y su kit.
##
## El selector de personajes se arma solo desde CharacterDB, asi que cuando sumes
## un personaje nuevo aparece aca sin tocar una linea de esta pantalla.

signal start_requested()
signal leave_requested()

var _player_list: VBoxContainer = null
var _character_list: VBoxContainer = null
var _kit_box: VBoxContainer = null
var _start_button: Button = null
var _status_label: Label = null

var _selected_id: StringName = &"noelle"


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected_id = StringName(Net.local_character_id)

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

	# --- Columna 2: seleccion de personaje ---
	var chars_panel := UITheme.make_panel()
	chars_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(chars_panel)
	var chars_box := VBoxContainer.new()
	chars_box.add_theme_constant_override("separation", 6)
	chars_panel.add_child(chars_box)
	chars_box.add_child(UITheme.make_heading("PERSONAJE"))
	_character_list = VBoxContainer.new()
	_character_list.add_theme_constant_override("separation", 6)
	chars_box.add_child(_character_list)

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

	_start_button = UITheme.make_button("EMPEZAR PARTIDA", true)
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_button.pressed.connect(func() -> void: start_requested.emit())
	buttons.add_child(_start_button)

	Net.player_list_changed.connect(_refresh)
	_build_character_list()
	_refresh()


func _exit_tree() -> void:
	if Net.player_list_changed.is_connected(_refresh):
		Net.player_list_changed.disconnect(_refresh)


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
		var button := UITheme.make_button("%s  ·  %s" % [data.display_name, data.origin_game], id == _selected_id)
		button.pressed.connect(_on_character_picked.bind(id))
		_character_list.add_child(button)


func _on_character_picked(id: StringName) -> void:
	_selected_id = id
	Net.set_local_character(String(id))
	_build_character_list()
	_build_kit()


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
