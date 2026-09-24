class_name PaseMenu
extends Control
## Pantalla del pase de temporada.
##
## LOS TREINTA ESCALONES VAN EN UNA TIRA HORIZONTAL, no en una lista vertical. Es la forma
## en que se lee un pase: se ve donde estas, cuanto falta para lo siguiente y que hay mas
## adelante, todo de un vistazo. Una lista vertical de treinta filas obliga a hacer scroll
## para saber si vale la pena seguir jugando, que es exactamente la pregunta que la
## pantalla tiene que contestar sin que la hagas.
##
## Las dos vias van una arriba de la otra y alineadas por escalon: asi se ve de golpe lo
## que el pase pro agrega, que es la unica forma honesta de mostrarlo.

signal cerrado()

const ANCHO_ESCALON: int = 104

var _tira: HBoxContainer = null
var _progreso_pase: Label = null
var _barra_pase: Panel = null
var _boton_pro: Button = null
var _boton_todo: Button = null
var _boton_escalon: Button = null
var _aviso: Label = null
var _scroll: ScrollContainer = null


func _ready() -> void:
	UITheme.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.build_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for lado: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + lado, 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(PerfilBarra.new())

	var titulo := UITheme.make_label(Pase.NOMBRE, 26)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titulo)

	# --- Progreso del pase ---
	var caja := UITheme.make_panel(UITheme.PANEL_SOFT)
	col.add_child(caja)
	var vcaja := VBoxContainer.new()
	vcaja.add_theme_constant_override("separation", 4)
	caja.add_child(vcaja)
	_progreso_pase = UITheme.make_label("", 14, UITheme.TEXT_DIM)
	vcaja.add_child(_progreso_pase)
	var partes := UITheme.make_bar(UITheme.GOLD, UITheme.STAMINA_TRACK, 9)
	_barra_pase = partes[1]
	vcaja.add_child(partes[0])

	# --- Botones de arriba ---
	var acciones := HBoxContainer.new()
	acciones.add_theme_constant_override("separation", 8)
	col.add_child(acciones)

	_boton_pro = UITheme.make_button("", true)
	_boton_pro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_pro.pressed.connect(_comprar_pro)
	acciones.add_child(_boton_pro)

	_boton_escalon = UITheme.make_button("")
	_boton_escalon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_escalon.pressed.connect(_comprar_escalon)
	acciones.add_child(_boton_escalon)

	_boton_todo = UITheme.make_button("RECLAMAR TODO")
	_boton_todo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boton_todo.pressed.connect(_reclamar_todo)
	acciones.add_child(_boton_todo)

	var volver := UITheme.make_button("VOLVER")
	volver.custom_minimum_size = Vector2(150, 0)
	volver.pressed.connect(func() -> void: cerrado.emit())
	acciones.add_child(volver)
	Mando.anotar(self, volver)

	_aviso = UITheme.make_label("", 13, UITheme.GOLD)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_aviso)

	# --- La tira de escalones ---
	_scroll = ScrollContainer.new()
	# Centrada en el espacio que sobra, no pegada arriba. Con EXPAND_FILL el contenedor
	# se comia media pantalla y la tira quedaba flotando sobre un vacio del alto de si
	# misma, con la barra de desplazamiento a doscientos pixeles de lo que desplaza.
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_scroll.custom_minimum_size = Vector2(0, 218)
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)

	_tira = HBoxContainer.new()
	_tira.add_theme_constant_override("separation", 6)
	_scroll.add_child(_tira)

	Progreso.cambio.connect(_refrescar)
	_refrescar()
	# Deja a la vista el escalon en el que esta el jugador, no el primero. Abrir el pase
	# en el escalon 1 cuando vas por el 14 obliga a arrastrar antes de ver nada tuyo.
	await get_tree().process_frame
	_scroll.scroll_horizontal = maxi(0, (Pase.escalon_actual() - 2) * (ANCHO_ESCALON + 6))


func _exit_tree() -> void:
	if Progreso.cambio.is_connected(_refrescar):
		Progreso.cambio.disconnect(_refrescar)


func _refrescar() -> void:
	if not is_instance_valid(_tira):
		return
	var escalon := Pase.escalon_actual()
	_progreso_pase.text = "Escalón %d de %d        %d / %d para el siguiente" % [
		escalon, Pase.ESCALONES,
		Progreso.pase_exp % Pase.EXP_POR_ESCALON, Pase.EXP_POR_ESCALON]
	_barra_pase.anchor_right = Pase.progreso_escalon()

	if Progreso.pase_pro:
		_boton_pro.text = "PASE PRO ACTIVO"
		_boton_pro.disabled = true
	else:
		_boton_pro.text = "COMPRAR PASE PRO — %d ◆" % Progreso.PRECIO_PASE_PRO
		_boton_pro.disabled = not Progreso.alcanza(Progreso.PRECIO_PASE_PRO)
	_boton_todo.disabled = not Pase.hay_algo_para_reclamar()
	if Pase.escalones_restantes() <= 0:
		_boton_escalon.text = "PASE COMPLETO"
		_boton_escalon.disabled = true
	else:
		_boton_escalon.text = "COMPRAR ESCALÓN — %d ◆" % Progreso.PRECIO_ESCALON
		_boton_escalon.disabled = not Progreso.alcanza(Progreso.PRECIO_ESCALON)

	for hijo: Node in _tira.get_children():
		hijo.queue_free()
	for i: int in range(1, Pase.ESCALONES + 1):
		_tira.add_child(_columna(i, escalon))


## Una columna = el numero del escalon y sus dos recompensas.
func _columna(i: int, escalon_actual: int) -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(ANCHO_ESCALON, 0)
	col.add_theme_constant_override("separation", 4)

	var alcanzado := i <= escalon_actual
	var num := UITheme.make_label(str(i), 15,
		UITheme.ACCENT if alcanzado else UITheme.TEXT_DIM)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(num)

	col.add_child(_tarjeta(i, false, alcanzado))
	var etiqueta := UITheme.make_label("PRO", 10,
		UITheme.GOLD if Progreso.pase_pro else UITheme.TEXT_DIM)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(etiqueta)
	col.add_child(_tarjeta(i, true, alcanzado))
	return col


## El recuadro de una recompensa. Se puede apretar solo si se puede cobrar.
func _tarjeta(i: int, pro: bool, alcanzado: bool) -> Control:
	var r := Pase.recompensa(i, pro)
	var vacia := (r[0] as StringName) == Pase.NADA
	var reclamada := Pase.reclamada(i, pro)
	var se_puede := Pase.se_puede_reclamar(i, pro)

	var boton := Button.new()
	boton.custom_minimum_size = Vector2(0, 74)
	# Con foco, para que el mando pueda cobrar. Sin foco, la unica forma de cobrar una
	# recompensa suelta era el mouse. El recuadro no se marca al hacerle click: Godot solo
	# muestra el foco cuando llega con el teclado o el mando.
	boton.focus_mode = Control.FOCUS_ALL
	boton.disabled = not se_puede
	boton.clip_text = true
	boton.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# El color dice el estado sin una sola palabra de leyenda: gris = todavia no,
	# encendido = cobralo, apagado con tilde = ya es tuyo.
	var fondo := UITheme.PANEL_SOFT
	var texto := Pase.describir(i, pro)
	if vacia:
		texto = "—"
		fondo = Color(0.08, 0.09, 0.13, 0.7)
	elif reclamada:
		texto = "✓ " + texto
		fondo = Color(0.11, 0.20, 0.15, 0.9)
	elif se_puede:
		fondo = Color(0.16, 0.26, 0.20, 0.95) if not pro else Color(0.28, 0.22, 0.09, 0.95)
	elif not alcanzado:
		fondo = Color(0.08, 0.09, 0.13, 0.85)

	if pro and not Progreso.pase_pro and not vacia:
		texto = "🔒 " + texto

	# Las skins llevan el color de su rareza en el borde: es lo que distingue "500
	# monedas" de "una legendaria" antes de leer el renglon.
	var borde := UITheme.BORDER
	var grosor := 1
	if (r[0] as StringName) == Pase.SKIN:
		var sk := SkinDB.get_skin(StringName(r[1]))
		if sk != null:
			borde = SkinData.color_rareza(sk.rareza)
			grosor = 2
	elif (r[0] as StringName) == Pase.PERSONAJE:
		# El premio mayor, con el borde mas grueso de la tira: es la razon por la que se
		# juega el pase entero, y tiene que verse desde el escalon 1.
		borde = UITheme.GOLD
		grosor = 3

	var estilo := UITheme.panel_style(fondo, 8, 4)
	estilo.border_color = borde
	estilo.set_border_width_all(grosor)
	boton.add_theme_stylebox_override("normal", estilo)
	boton.add_theme_stylebox_override("hover", estilo)
	boton.add_theme_stylebox_override("pressed", estilo)
	boton.add_theme_stylebox_override("disabled", estilo)
	boton.add_theme_font_size_override("font_size", 11)
	boton.add_theme_color_override("font_color", UITheme.TEXT if not vacia else UITheme.TEXT_DIM)
	boton.add_theme_color_override("font_disabled_color",
		UITheme.TEXT_DIM if not reclamada else UITheme.HEALTH)
	boton.text = texto

	if se_puede:
		boton.pressed.connect(func() -> void:
			var ganado := Pase.reclamar(i, pro)
			if not ganado.is_empty():
				_mostrar_aviso("Reclamado: %s" % ganado)
			Sfx.play_2d(&"ui_click"))
	return boton


func _comprar_pro() -> void:
	if Pase.comprar_pro():
		_mostrar_aviso("¡Pase Pro activado! Se desbloquearon los escalones que ya pasaste.")
	else:
		_mostrar_aviso("No te alcanzan las monedas.")
	Sfx.play_2d(&"ui_click")


func _comprar_escalon() -> void:
	if Pase.comprar_escalon():
		_mostrar_aviso("Subiste al escalón %d." % Pase.escalon_actual())
	else:
		_mostrar_aviso("No te alcanzan las monedas.")
	Sfx.play_2d(&"ui_click")


func _reclamar_todo() -> void:
	var n := Pase.reclamar_todo()
	_mostrar_aviso("Reclamaste %d recompensa%s." % [n, "" if n == 1 else "s"])
	Sfx.play_2d(&"ui_click")


func _mostrar_aviso(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.7)
