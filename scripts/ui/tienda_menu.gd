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

# --- El probador ---
#
# LA SKIN SE VE PUESTA ANTES DE COMPRARLA. Tres cuadraditos de color no dicen como queda
# un personaje con pelo nuevo, un acabado de metal, un aura o un gorro: la mitad de lo que
# hace una skin no entra en una muestra de paleta. Con el probador, pasar el mouse por una
# tarjeta la muestra en el personaje, girando.
var _probador_pivote: Node3D = null
var _probador_visual: PlayerVisual = null
var _probador_nombre: Label = null
var _probando: String = ""


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
	Mando.anotar(self, volver)

	_aviso = UITheme.make_label("", 13, UITheme.GOLD)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_aviso)

	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 14)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cuerpo)
	cuerpo.add_child(_armar_probador())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuerpo.add_child(scroll)

	_grilla = VBoxContainer.new()
	_grilla.add_theme_constant_override("separation", 12)
	_grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grilla)

	Progreso.cambio.connect(_refrescar)
	_refrescar()
	# Arranca mostrando al primer personaje con lo que tiene puesto.
	var primero: StringName = CharacterDB.get_all_ids()[0]
	_probar(primero, Progreso.skin_de(primero))


## Un mundo 3D propio, chico, con su luz: el personaje girando en un pedestal.
##
## own_world_3d en true: sin eso el visor mostraria el mundo del juego que haya detras —en
## la pausa, la arena entera— en vez de un fondo limpio.
func _armar_probador() -> Control:
	var caja := UITheme.make_panel(UITheme.PANEL_SOFT)
	caja.custom_minimum_size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	caja.add_child(v)

	v.add_child(UITheme.make_label("PROBADOR", 13, UITheme.TEXT_DIM))
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.custom_minimum_size = Vector2(0, 380)
	contenedor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(contenedor)

	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = false
	vista.msaa_3d = Viewport.MSAA_2X
	contenedor.add_child(vista)

	var ent := Environment.new()
	ent.background_mode = Environment.BG_COLOR
	ent.background_color = Color(0.07, 0.08, 0.13)
	ent.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ent.ambient_light_color = Color(0.55, 0.60, 0.75)
	ent.ambient_light_energy = 0.6
	# Resplandor bajo: el probador esta a dos metros del personaje y en el juego la camara
	# va mucho mas lejos. Con el mismo resplandor que la arena, las skins que brillan se
	# quemaban en una mancha blanca y no se veia la skin, que es lo unico que importa aca.
	ent.glow_enabled = true
	ent.glow_intensity = 0.22
	ent.tonemap_mode = Environment.TONE_MAPPER_ACES
	var mundo := WorldEnvironment.new()
	mundo.environment = ent
	vista.add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.light_energy = 1.15
	sol.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	vista.add_child(sol)
	# Un contraluz: sin el, el costado en sombra se funde con el fondo oscuro y no se ve
	# el borde del personaje, que es justo donde se lucen los acabados.
	var contra := DirectionalLight3D.new()
	contra.light_energy = 0.55
	contra.light_color = Color(0.55, 0.70, 1.0)
	contra.rotation_degrees = Vector3(-20.0, -150.0, 0.0)
	vista.add_child(contra)

	var camara := Camera3D.new()
	# Encuadra al mas alto con aire arriba: Flowery mide casi dos metros y Sonic uno, y
	# el mismo encuadre tiene que servir para los dos sin cortarle la cabeza a nadie.
	camara.fov = 32.0
	vista.add_child(camara)
	# La orientacion armada a mano y no con look_at: look_at necesita el nodo DENTRO del
	# arbol, y el probador se arma antes de que la tienda lo agregue. Fallaba con un error
	# cada vez que se abria la tienda y la camara quedaba sin la inclinacion.
	var ojo := Vector3(0.0, 1.05, 5.4)
	camara.transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.95, 0.0) - ojo, Vector3.UP), ojo)

	var piso := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 0.9
	disco.bottom_radius = 0.9
	disco.height = 0.05
	piso.mesh = disco
	piso.material_override = Art.toon(Color(0.16, 0.18, 0.26), 0.0)
	vista.add_child(piso)
	piso.position = Vector3(0.0, -0.03, 0.0)

	_probador_pivote = Node3D.new()
	vista.add_child(_probador_pivote)

	_probador_nombre = UITheme.make_label("", 15)
	_probador_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_probador_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_probador_nombre)
	return caja


func _process(delta: float) -> void:
	if is_instance_valid(_probador_pivote):
		_probador_pivote.rotation.y += delta * 0.8


## Pone al personaje con esa skin en el probador. &"" = la de fabrica.
func _probar(cid: StringName, sid: StringName) -> void:
	var clave := "%s/%s" % [cid, sid]
	if clave == _probando or not is_instance_valid(_probador_pivote):
		return
	_probando = clave
	if is_instance_valid(_probador_visual):
		_probador_visual.queue_free()
	var base := CharacterDB.get_character(cid)
	if base == null:
		return
	# Un visual nuevo cada vez y no uno recoloreado: es la misma receta que usa el juego
	# de verdad al aparecer, asi que lo que se ve aca es exactamente lo que se va a ver en
	# la partida, acabado y aura incluidos.
	_probador_visual = PlayerVisual.new()
	_probador_pivote.add_child(_probador_visual)
	_probador_visual.apply_character(SkinDB.aplicar(base, sid))
	var skin := SkinDB.get_skin(sid)
	if skin == null:
		_probador_nombre.text = "%s — original" % base.display_name
		_probador_nombre.add_theme_color_override("font_color", UITheme.TEXT)
	else:
		_probador_nombre.text = "%s\n%s" % [skin.display_name, SkinData.nombre_rareza(skin.rareza)]
		_probador_nombre.add_theme_color_override("font_color", SkinData.color_rareza(skin.rareza))


## Pasar el mouse por una tarjeta la prueba. Se engancha a la tarjeta Y a su boton: el
## boton tapa la tarjeta, y sobre el la tarjeta no recibe el aviso de que el mouse entro.
func _hover(nodo: Control, cid: StringName, sid: StringName) -> void:
	nodo.mouse_entered.connect(func() -> void: _probar(cid, sid))


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
	caja.custom_minimum_size = Vector2(196, 0)
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
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_hover(caja, p.id, &"")
	_hover(b, p.id, &"")
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
	elif s.precio <= 0 and Progreso.modo_dev:
		# En modo desarrollador las del pase tambien se pueden probar. Las monedas
		# infinitas existen PARA probar skins, y la mitad de las skins son del pase: sin
		# esto, el modo servia para la mitad de lo que se pidio.
		b = UITheme.make_button("DESBLOQUEAR (DEV)", true)
		b.pressed.connect(func() -> void:
			Progreso.desbloquear_skin(s.id)
			_equipar(s.character_id, s.id)
			_avisar("%s desbloqueada (modo desarrollador)" % s.display_name))
	elif s.precio <= 0:
		# Del pase. El boton no se puede apretar pero dice de donde sale: un candado
		# mudo hace que la gente piense que es un error del juego.
		b = UITheme.make_button("SOLO EN EL PASE")
		b.disabled = true
	else:
		b = UITheme.make_button("COMPRAR — %d ◆" % s.precio, true)
		b.disabled = not Progreso.alcanza(s.precio)
		b.pressed.connect(func() -> void: _comprar(s))
	v.add_child(b)
	_hover(caja, s.character_id, s.id)
	_hover(b, s.character_id, s.id)
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
