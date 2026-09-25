class_name OptionsMenu
extends Control
## Panel de opciones. Se usa desde el menu principal y desde la pausa.
## Todo lo que se toca aca se guarda solo en user://settings.cfg.

signal closed()

var _sens_label: Label = null
var _volume_label: Label = null
var _auto_run_hint: Label = null
var _music_label: Label = null


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(440, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := UITheme.make_label("OPCIONES", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UITheme.make_spacer(10))

	# CON SCROLL: con las opciones de juego el panel ya no entraba en 720 de alto, y CERRAR
	# quedaba afuera. El titulo y los botones de abajo quedan fijos; se desplaza el medio.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	var marco := box
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	# --- Sensibilidad del mouse ---
	_sens_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	box.add_child(_sens_label)
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.012
	sens.step = 0.0001
	sens.value = Settings.mouse_sensitivity
	sens.custom_minimum_size = Vector2(0, 24)
	sens.value_changed.connect(_on_sens_changed)
	box.add_child(sens)

	box.add_child(UITheme.make_spacer(6))

	# --- Volumen ---
	_volume_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	box.add_child(_volume_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.value = Settings.master_volume
	vol.custom_minimum_size = Vector2(0, 24)
	vol.value_changed.connect(_on_volume_changed)
	box.add_child(vol)

	box.add_child(UITheme.make_spacer(6))

	# --- Volumen de la musica, aparte del de los efectos ---
	_music_label = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	box.add_child(_music_label)
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.01
	music.value = Settings.music_volume
	music.custom_minimum_size = Vector2(0, 24)
	music.value_changed.connect(_on_music_changed)
	box.add_child(music)

	box.add_child(UITheme.make_spacer(6))

	# --- Correr automaticamente ---
	var auto_run := CheckButton.new()
	auto_run.text = "Correr automaticamente"
	auto_run.button_pressed = Settings.auto_run
	auto_run.add_theme_font_size_override("font_size", 16)
	auto_run.toggled.connect(func(pressed: bool) -> void:
		Settings.set_auto_run(pressed)
		_refresh_labels()
	)
	box.add_child(auto_run)

	_auto_run_hint = UITheme.make_label("", 11, UITheme.TEXT_DIM)
	_auto_run_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_auto_run_hint)

	box.add_child(UITheme.make_spacer(6))

	var hitboxes := CheckButton.new()
	hitboxes.text = "Ver cajas de colisión"
	hitboxes.button_pressed = Settings.mostrar_hitboxes
	hitboxes.add_theme_font_size_override("font_size", 16)
	hitboxes.toggled.connect(func(pressed: bool) -> void:
		Settings.set_mostrar_hitboxes(pressed))
	box.add_child(hitboxes)

	var hitboxes_hint := UITheme.make_label(
		"Dibuja la cápsula de cada jugador y bot, el radio de cada proyectil, y el área de cada ataque en el momento en que golpea.",
		11, UITheme.TEXT_DIM)
	hitboxes_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hitboxes_hint)

	box.add_child(UITheme.make_spacer(6))

	# --- Asistencia de apuntado ---
	var asistencia := CheckButton.new()
	asistencia.text = "Asistencia de apuntado"
	asistencia.button_pressed = Settings.asistencia_apuntado
	asistencia.add_theme_font_size_override("font_size", 16)
	asistencia.toggled.connect(func(pressed: bool) -> void:
		Settings.set_asistencia_apuntado(pressed))
	box.add_child(asistencia)
	var asistencia_hint := UITheme.make_label(
		"Las habilidades se corren apenas hacia el rival que tenés casi en la mira, y el golpe básico busca al que tenés al lado.",
		11, UITheme.TEXT_DIM)
	asistencia_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(asistencia_hint)

	box.add_child(UITheme.make_spacer(6))

	# --- Mantener para atacar ---
	var mantener := CheckButton.new()
	mantener.text = "Mantener apretado para atacar"
	mantener.button_pressed = Settings.mantener_para_atacar
	mantener.add_theme_font_size_override("font_size", 16)
	mantener.toggled.connect(func(pressed: bool) -> void:
		Settings.set_mantener_para_atacar(pressed))
	box.add_child(mantener)
	var mantener_hint := UITheme.make_label(
		"Con el golpe básico apretado sigue pegando solo, cada vez que se libera.",
		11, UITheme.TEXT_DIM)
	mantener_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(mantener_hint)

	box.add_child(UITheme.make_spacer(6))

	# --- Pantalla completa ---
	var fs := CheckButton.new()
	fs.text = "Pantalla completa"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_font_size_override("font_size", 16)
	fs.toggled.connect(func(pressed: bool) -> void:
		Settings.set_fullscreen(pressed)
	)
	box.add_child(fs)

	box = marco
	box.add_child(UITheme.make_spacer(6))

	# Antes aca habia un renglon que decia que los controles se cambiaban editando una
	# tabla del codigo fuente. Ahora se cambian aca, como en cualquier juego.
	var controles := UITheme.make_button("CONTROLES…")
	controles.pressed.connect(func() -> void:
		var pantalla := ControlesMenu.new()
		pantalla.cerrado.connect(func() -> void:
			pantalla.queue_free()
			_refresh_labels())
		add_child(pantalla))
	box.add_child(controles)

	box.add_child(UITheme.make_spacer(6))
	var close := UITheme.make_button("CERRAR", true)
	close.pressed.connect(func() -> void: closed.emit())
	box.add_child(close)
	Mando.anotar(self, close)

	_refresh_labels()


func _on_sens_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)
	_refresh_labels()


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value)
	_refresh_labels()
	# Un clic de referencia para que escuches el volumen que estas eligiendo.
	Sfx.play_2d(&"ui_click", -8.0)


func _on_music_changed(value: float) -> void:
	Settings.set_music_volume(value)
	_refresh_labels()


func _refresh_labels() -> void:
	# La sensibilidad cruda es un numero sin sentido para el jugador, asi que la
	# mostramos como porcentaje del rango.
	var t := inverse_lerp(0.0005, 0.012, Settings.mouse_sensitivity)
	_sens_label.text = "Sensibilidad del mouse: %d%%" % int(round(t * 100.0))
	_volume_label.text = "Efectos de sonido: %d%%" % int(round(Settings.master_volume * 100.0))
	if _music_label != null:
		_music_label.text = "Musica: %d%%" % int(round(Settings.music_volume * 100.0))
	if _auto_run_hint != null:
		_auto_run_hint.text = ("Corres siempre sin apretar nada. Correr nunca gasta stamina."
			if Settings.auto_run
			else "Mantené %s para correr. Correr nunca gasta stamina." % Controles.nombre_tecla(&"sprint"))
