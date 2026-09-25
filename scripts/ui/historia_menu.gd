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
	caja.add_child(UITheme.make_spacer(2))
	_armar_dificultad(caja)

	# CON SCROLL: diez capitulos, con el titulo y el boton de volver, no entran en 720 de
	# alto. Sin esto el panel se pasaba de la pantalla y VOLVER quedaba afuera, sin forma de
	# llegar a el con el mouse. El titulo y VOLVER quedan fijos; se desplaza la lista.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Con el mando, el foco que baja por la lista la arrastra con el.
	scroll.follow_focus = true
	caja.add_child(scroll)
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lista)

	var primero_disponible: Button = null
	var parte_actual := -1
	for i: int in range(Historia.cantidad()):
		# UN TITULO POR PARTE, arriba de sus capitulos. Una parte cerrada lo dice: si no, la
		# parte 2 entera se veia como diez candados sin explicacion.
		var k := Historia.parte_de(i)
		if k != parte_actual:
			parte_actual = k
			if k > 0:
				lista.add_child(UITheme.make_spacer(6))
			var abierta := Progreso.capitulo_disponible(Historia.primero_de(k))
			var cabecera := UITheme.make_label(Historia.titulo_parte(k) if abierta
				else "%s  ·  se abre al terminar la parte %d" % [Historia.titulo_parte(k), k], 15,
				UITheme.GOLD if abierta else UITheme.TEXT_DIM)
			cabecera.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lista.add_child(cabecera)
		var n := i - Historia.primero_de(k) + 1
		var cap := Historia.capitulo(i)
		var personaje := CharacterDB.get_character(StringName(cap["personaje"]))
		var hecho := Progreso.capitulo_completado(i)
		var abierto := Progreso.capitulo_disponible(i)
		var texto := ""
		if not abierto:
			texto = "🔒  Capítulo %d" % n
		else:
			texto = "%s  Capítulo %d · %s" % ["✓" if hecho else "▶", n, cap["titulo"]]
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
		var fin := UITheme.make_label("Terminaste la parte %d. La historia continuará." % Historia.PARTES.size(),
			12, UITheme.GOLD)
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


## LA DIFICULTAD, arriba de la lista: vale para todos los capitulos y se cambia cuando se
## quiera, tambien para rejugar uno ya ganado. Abajo dice que cambia, con la paga incluida:
## que facil paga menos tiene que saberse ANTES de elegirla.
func _armar_dificultad(caja: VBoxContainer) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var etiqueta := UITheme.make_label("DIFICULTAD", 14, UITheme.TEXT_DIM)
	etiqueta.custom_minimum_size = Vector2(110, 0)
	etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fila.add_child(etiqueta)
	var explicacion := UITheme.make_label(
		String(Historia.dificultad(Progreso.dificultad_historia)["texto"]), 12, UITheme.TEXT_DIM)
	explicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var grupo := ButtonGroup.new()
	# La elegida con el color de acento: con el de apretado de siempre, apenas mas claro, no
	# se distinguia cual estaba puesta.
	var elegida := UITheme._button_style(UITheme.ACCENT.darkened(0.45), true)
	for d: int in range(Historia.DIFICULTADES.size()):
		var b := UITheme.make_button(String(Historia.DIFICULTADES[d]["nombre"]))
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = d == Progreso.dificultad_historia
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", elegida)
		b.add_theme_stylebox_override("hover_pressed", elegida)
		b.pressed.connect(func() -> void:
			Progreso.cambiar_dificultad(d)
			explicacion.text = String(Historia.dificultad(d)["texto"]))
		fila.add_child(b)
	caja.add_child(explicacion)
	caja.add_child(UITheme.make_spacer(2))


func _mostrar(scroll: ScrollContainer, boton: Control) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and is_instance_valid(boton):
		scroll.ensure_control_visible(boton)
