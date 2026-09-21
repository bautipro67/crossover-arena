class_name TiendaMenu
extends Control
## Tienda y armario, en una sola pantalla.
##
## NO SON DOS PANTALLAS SEPARADAS a proposito. Separarlas obliga a ir y volver para
## responder "¿me falta esta o ya la tengo?", que es la pregunta que uno se hace mirando
## la tienda. Aca cada skin muestra su estado en el mismo boton —comprala, ponetela, ya la
## tenes puesta, viene del pase— y el recorrido se termina donde empieza.
##
## Las skins que da el pase aparecen igual aunque no se puedan comprar. Esconderlas seria
## mas prolijo y peor: si no las ves, no sabes que existen, y el pase pierde la mitad de
## su atractivo.

signal cerrado()

var _grilla: VBoxContainer = null
var _aviso: Label = null


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

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	col.add_child(fila)
	var titulo := UITheme.make_label("ARMARIO Y TIENDA", 24)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(titulo)
	var volver := UITheme.make_button("VOLVER")
	volver.custom_minimum_size = Vector2(150, 0)
	volver.pressed.connect(func() -> void: cerrado.emit())
	fila.add_child(volver)

	_aviso = UITheme.make_label("", 13, UITheme.GOLD)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_aviso)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_grilla = VBoxContainer.new()
	_grilla.add_theme_constant_override("separation", 12)
	_grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grilla)

	Progreso.cambio.connect(_refrescar)
	_refrescar()


func _exit_tree() -> void:
	if Progreso.cambio.is_connected(_refrescar):
		Progreso.cambio.disconnect(_refrescar)


func _refrescar() -> void:
	if not is_instance_valid(_grilla):
		return
	for hijo: Node in _grilla.get_children():
		hijo.queue_free()

	# Agrupado por personaje: nadie busca "todas las epicas", busca "que tiene Dio".
	for cid: StringName in CharacterDB.get_all_ids():
		var personaje := CharacterDB.get_character(cid)
		if personaje == null:
			continue
		var ids := SkinDB.de_personaje(cid)
		if ids.is_empty():
			continue

		_grilla.add_child(UITheme.make_label(personaje.display_name.to_upper(), 17, UITheme.ACCENT))

		var fila := HFlowContainer.new()
		fila.add_theme_constant_override("h_separation", 10)
		fila.add_theme_constant_override("v_separation", 10)
		_grilla.add_child(fila)

		# La de fabrica primero, para poder volver atras. Sin esto, ponerse una skin es
		# una decision sin vuelta y la gente directamente no se la pone.
		fila.add_child(_tarjeta_original(personaje))
		for sid: StringName in ids:
			fila.add_child(_tarjeta(SkinDB.get_skin(sid)))
		_grilla.add_child(UITheme.make_spacer(2))


func _marco(borde: Color, resaltado: bool) -> PanelContainer:
	var caja := PanelContainer.new()
	caja.custom_minimum_size = Vector2(212, 0)
	var estilo := UITheme.panel_style(
		Color(0.13, 0.16, 0.24, 0.95) if not resaltado else Color(0.12, 0.22, 0.18, 0.97), 10, 6)
	estilo.border_color = borde
	estilo.set_border_width_all(3 if resaltado else 2)
	caja.add_theme_stylebox_override("panel", estilo)
	return caja


## Tres cuadraditos con la paleta. Es toda la vista previa que hace falta: el juego dibuja
## los cuerpos con estos mismos colores, asi que mostrarlos ES mostrar la skin.
func _muestra(cuerpo: Color, acento: Color, pantalon: Color) -> Control:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	for c: Color in [cuerpo, acento, pantalon]:
		var r := ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(0, 26)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(r)
	return fila


func _tarjeta_original(p: CharacterData) -> Control:
	var puesta := Progreso.skin_de(p.id) == &""
	var caja := _marco(UITheme.BORDER if not puesta else UITheme.HEALTH, puesta)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	caja.add_child(v)
	v.add_child(UITheme.make_label("Original", 14))
	v.add_child(UITheme.make_label("Como viene de fábrica.", 11, UITheme.TEXT_DIM))
	v.add_child(_muestra(p.body_color, p.accent_color, p.trouser_color))

	var b := UITheme.make_button("EQUIPADA" if puesta else "EQUIPAR")
	b.disabled = puesta
	b.pressed.connect(func() -> void: _equipar(p.id, &""))
	v.add_child(b)
	return caja


func _tarjeta(s: SkinData) -> Control:
	if s == null:
		return Control.new()
	var tiene := Progreso.tiene_skin(s.id)
	var puesta := tiene and Progreso.skin_de(s.character_id) == s.id
	var caja := _marco(SkinData.color_rareza(s.rareza), puesta)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	caja.add_child(v)

	var enc := HBoxContainer.new()
	enc.add_theme_constant_override("separation", 6)
	v.add_child(enc)
	var nom := UITheme.make_label(s.display_name, 14)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enc.add_child(nom)
	enc.add_child(UITheme.make_label(SkinData.nombre_rareza(s.rareza), 9,
		SkinData.color_rareza(s.rareza)))

	var desc := UITheme.make_label(s.descripcion, 11, UITheme.TEXT_DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(0, 30)
	v.add_child(desc)
	v.add_child(_muestra(s.body_color, s.accent_color, s.trouser_color))

	var b: Button = null
	if puesta:
		b = UITheme.make_button("EQUIPADA")
		b.disabled = true
	elif tiene:
		b = UITheme.make_button("EQUIPAR", true)
		b.pressed.connect(func() -> void: _equipar(s.character_id, s.id))
	elif s.precio <= 0:
		# Del pase. El boton no se puede apretar pero dice de donde sale: un candado
		# mudo hace que la gente piense que es un error del juego.
		b = UITheme.make_button("SOLO EN EL PASE")
		b.disabled = true
	else:
		b = UITheme.make_button("COMPRAR — %d ◆" % s.precio, true)
		b.disabled = Progreso.monedas < s.precio
		b.pressed.connect(func() -> void: _comprar(s))
	v.add_child(b)
	return caja


func _comprar(s: SkinData) -> void:
	# El gasto y el desbloqueo van en este orden y con el resultado mirado: gastar_monedas
	# devuelve false si no alcanza, y desbloquear antes de cobrar regalaria la skin si el
	# boton llega a apretarse dos veces antes de que la pantalla se refresque.
	if not Progreso.gastar_monedas(s.precio):
		_avisar("No te alcanzan las monedas.")
		return
	Progreso.desbloquear_skin(s.id)
	_equipar(s.character_id, s.id)
	_avisar("¡%s desbloqueada y equipada!" % s.display_name)


func _equipar(cid: StringName, sid: StringName) -> void:
	Progreso.equipar_skin(cid, sid)
	# Avisarle a la red, para que los demas te vean con la que acabas de poner. Si no,
	# el cambio se ve solo en esta pantalla hasta la proxima vez que te conectes.
	if String(cid) == Net.local_character_id:
		Net.set_local_skin(sid)
	Sfx.play_2d(&"ui_click")


func _avisar(texto: String) -> void:
	_aviso.text = texto
	_aviso.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(_aviso, "modulate:a", 0.0, 0.7)
