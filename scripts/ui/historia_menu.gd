class_name HistoriaMenu
extends Control
## La pantalla del modo historia: los capitulos, en orden, y cual se puede jugar.
##
## Van TODOS A LA VISTA, tambien los que no se abrieron todavia: ver que hay cinco y que
## vas por el segundo es lo que da ganas de seguir. Uno cerrado dice con quien se juega
## pero no como se llama la pelea, para no adelantar la historia.

signal cerrado()
signal capitulo_elegido(i: int)


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.build_background(self)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var panel := UITheme.make_panel()
	panel.custom_minimum_size = Vector2(620, 0)
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	panel.add_child(caja)

	var titulo := UITheme.make_label("MODO HISTORIA", 28)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)
	var parte := UITheme.make_label(Historia.PARTE, 15, UITheme.GOLD)
	parte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(parte)
	caja.add_child(UITheme.make_spacer(6))

	# CON SCROLL: diez capitulos, con el titulo y el boton de volver, no entran en 720 de
	# alto. Sin esto el panel se pasaba de la pantalla y VOLVER quedaba afuera, sin forma de
	# llegar a el con el mouse. El titulo y VOLVER quedan fijos; se desplaza la lista.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Con el mando, el foco que baja por la lista la arrastra con el.
	scroll.follow_focus = true
	caja.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	var primero_disponible: Button = null
	for i: int in range(Historia.cantidad()):
		var cap := Historia.capitulo(i)
		var personaje := CharacterDB.get_character(StringName(cap["personaje"]))
		var hecho := Progreso.capitulo_completado(i)
		var abierto := Progreso.capitulo_disponible(i)
		var texto := ""
		if not abierto:
			texto = "🔒  Capítulo %d" % (i + 1)
		else:
			texto = "%s  Capítulo %d · %s" % ["✓" if hecho else "▶", i + 1, cap["titulo"]]
		var boton := UITheme.make_button(texto, abierto and not hecho)
		boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boton.disabled = not abierto
		boton.tooltip_text = "Jugás con %s" % personaje.display_name
		boton.pressed.connect(func() -> void: capitulo_elegido.emit(i))
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		boton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(boton)
		var con := UITheme.make_label(personaje.display_name, 13,
			Frases.color_de(personaje.id) if abierto else UITheme.TEXT_DIM)
		con.custom_minimum_size = Vector2(110, 0)
		fila.add_child(con)
		lista.add_child(fila)
		if abierto and not hecho and primero_disponible == null:
			primero_disponible = boton

	var todos := true
	for i: int in range(Historia.cantidad()):
		todos = todos and Progreso.capitulo_completado(i)
	if todos:
		var fin := UITheme.make_label("Terminaste la parte 1. La historia sigue en la parte 2.", 12,
			UITheme.GOLD)
		fin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(fin)

	caja.add_child(UITheme.make_spacer(4))
	var volver := UITheme.make_button("VOLVER")
	volver.pressed.connect(func() -> void: cerrado.emit())
	caja.add_child(volver)
	Mando.anotar(self, volver)
	# Que se vea el que toca jugar: con la lista desplazable, el capitulo 8 quedaria abajo
	# de todo al abrir la pantalla.
	if primero_disponible != null:
		_mostrar.call_deferred(scroll, primero_disponible)


func _mostrar(scroll: ScrollContainer, boton: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(boton):
		scroll.ensure_control_visible(boton)
