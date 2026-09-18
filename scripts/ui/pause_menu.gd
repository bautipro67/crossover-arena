class_name PauseMenu
extends CanvasLayer
## Pausa con ESC. No pausa el juego de verdad (es multijugador, el mundo sigue),
## solo libera el mouse y te deja salir.

signal resume_requested()
signal leave_requested()

var _root: Control = null
var _is_open: bool = false


func _ready() -> void:
	layer = 20
	_build()
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(320, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := UITheme.make_label("PAUSA", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UITheme.make_spacer(8))

	var resume := UITheme.make_button("REANUDAR", true)
	resume.pressed.connect(close)
	box.add_child(resume)

	var options_button := UITheme.make_button("OPCIONES")
	options_button.pressed.connect(_open_options)
	box.add_child(options_button)

	var leave := UITheme.make_button("SALIR DE LA PARTIDA")
	leave.pressed.connect(func() -> void: leave_requested.emit())
	box.add_child(leave)


func _open_options() -> void:
	var options := OptionsMenu.new()
	options.closed.connect(func() -> void: options.queue_free())
	_root.add_child(options)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_is_open = true
	_root.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_is_open = false
	_root.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	resume_requested.emit()
