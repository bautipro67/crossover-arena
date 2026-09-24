class_name DialogoHistoria
extends Control
## El cuadro de dialogo del modo historia: quien habla, que dice, y su retrato.
##
## EL RETRATO ES EL PERSONAJE DE VERDAD, en 3D, no un dibujo: el juego no tiene imagenes,
## y el mismo PlayerVisual que se ve en la partida —con la skin que tenga puesta— es lo
## que mejor dice quien habla. El narrador no tiene cuerpo, y el retrato se esconde.
##
## SE AVANZA CON LO QUE SEA: click, toque, Espacio, Enter o A. Si el texto todavia se esta
## escribiendo, el primer toque lo completa y el segundo pasa: nadie tiene por que esperar
## a que termine de aparecer algo que ya leyo. SALTAR (o B) termina todo el dialogo.

signal terminado()

## Letras por segundo. Rapido: es para que el texto "hable", no para hacer esperar.
const VELOCIDAD: float = 55.0

## [quien, texto] por linea. Ver Historia.
var lineas: Array = []

var _i: int = -1
var _escrito: float = 0.0
var _texto: Label = null
var _nombre: Label = null
var _pista: Label = null
var _marco_retrato: Control = null
var _pivote: Node3D = null
var _visual: PlayerVisual = null
var _hablante: StringName = &""
var _listo: bool = false


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_marco_retrato = _armar_retrato()
	add_child(_marco_retrato)

	var panel := UITheme.make_panel()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 40.0
	panel.offset_right = -40.0
	panel.offset_top = -210.0
	panel.offset_bottom = -30.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(caja)
	_nombre = UITheme.make_label("", 20, UITheme.GOLD)
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_nombre)
	_texto = UITheme.make_label("", 19, UITheme.TEXT)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size = Vector2(0, 90)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_texto)
	_pista = UITheme.make_label("", 11, UITheme.TEXT_DIM)
	_pista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(_pista)

	var saltar := UITheme.make_button("SALTAR")
	saltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	saltar.offset_left = -170.0
	saltar.offset_right = -24.0
	saltar.offset_top = 20.0
	saltar.offset_bottom = 64.0
	# SIN FOCO, a proposito: con foco, el mando se lo daria al primer toque de A y el
	# siguiente A saltearia el dialogo entero en vez de pasar de linea. B lo aprieta igual.
	saltar.focus_mode = Control.FOCUS_NONE
	saltar.pressed.connect(_terminar)
	add_child(saltar)
	Mando.anotar(self, saltar)

	_pista.text = "Click, Espacio o %s para seguir" % Controles.nombre_mando(&"ui_accept") \
		if Controles.dispositivo == &"mando" else "Click, toque o Espacio para seguir"
	_siguiente()


## Un rincon 3D propio con el personaje que habla, como el probador de la tienda.
func _armar_retrato() -> Control:
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	contenedor.offset_left = 60.0
	contenedor.offset_right = 360.0
	contenedor.offset_top = -560.0
	contenedor.offset_bottom = -200.0
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = true
	vista.msaa_3d = Viewport.MSAA_2X
	contenedor.add_child(vista)

	var ent := Environment.new()
	ent.background_mode = Environment.BG_CLEAR_COLOR
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.55, 0.60, 0.75)
	ent.ambient_light_energy = 0.6
	ent.tonemap_mode = Environment.TONE_MAPPER_ACES
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.1
	sol.rotation_degrees = Vector3(-30.0, 35.0, 0.0)
	vista.add_child(sol)
	var camara := Camera3D.new()
	camara.fov = 30.0
	vista.add_child(camara)
	# Encuadre de medio cuerpo para arriba: la cara es lo que habla.
	var ojo := Vector3(0.0, 1.45, 3.4)
	camara.transform = Transform3D(Basis.looking_at(Vector3(0.0, 1.35, 0.0) - ojo, Vector3.UP), ojo)
	_pivote = Node3D.new()
	# Tres cuartos, mirando hacia el cuadro de texto.
	_pivote.rotation_degrees = Vector3(0.0, 200.0, 0.0)
	vista.add_child(_pivote)
	return contenedor


func _mostrar_hablante(quien: StringName) -> void:
	if quien == _hablante:
		return
	_hablante = quien
	if is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null
	var hay_cuerpo := quien != Historia.NARRADOR and CharacterDB.has_character(quien)
	_marco_retrato.visible = hay_cuerpo
	if not hay_cuerpo:
		return
	_visual = PlayerVisual.new()
	_pivote.add_child(_visual)
	_visual.apply_character(SkinDB.aplicar(CharacterDB.get_character(quien), Progreso.skin_de(quien)))


func _siguiente() -> void:
	_i += 1
	if _i >= lineas.size():
		_terminar()
		return
	var linea: Array = lineas[_i]
	var quien := StringName(linea[0])
	_mostrar_hablante(quien)
	var nombre := Historia.nombre_de(quien)
	_nombre.text = nombre.to_upper()
	_nombre.visible = not nombre.is_empty()
	if not nombre.is_empty():
		_nombre.add_theme_color_override("font_color", Frases.color_de(quien))
	_texto.text = String(linea[1])
	# El narrador en cursiva no hay; se lo distingue por el color, mas apagado.
	_texto.add_theme_color_override("font_color",
		UITheme.TEXT_DIM.lightened(0.2) if quien == Historia.NARRADOR else UITheme.TEXT)
	_texto.visible_characters = 0
	_escrito = 0.0


func _process(delta: float) -> void:
	if _texto == null or _texto.visible_characters < 0:
		return
	_escrito += delta * VELOCIDAD
	var total := _texto.get_total_character_count()
	_texto.visible_characters = mini(int(_escrito), total)
	if _texto.visible_characters >= total:
		_texto.visible_characters = -1


## Un toque: completa la linea si todavia se esta escribiendo, o pasa a la siguiente.
func avanzar() -> void:
	if _listo:
		return
	if _texto.visible_characters >= 0:
		_texto.visible_characters = -1
		return
	_siguiente()


func _terminar() -> void:
	if _listo:
		return
	_listo = true
	terminado.emit()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		avanzar()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		avanzar()
	elif event is InputEventKey and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_terminar()
