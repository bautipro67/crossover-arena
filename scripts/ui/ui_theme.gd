class_name UITheme
extends RefCounted
## Paleta y fabricas de controles.
##
## Centralizado para que toda la UI se vea igual y para no repetir cuarenta veces el
## mismo StyleBoxFlat. Si queres cambiarle el aspecto al juego entero, se cambia aca.
##
## Criterio: paneles con esquinas redondeadas y sombra, un borde fino que apenas se
## nota, y el acento celeste reservado para lo que importa. Nada de bordes gruesos:
## lo que separa las cosas es la sombra y el espacio, no las lineas.

# --------------------------------------------------------------------- Paleta

const BG := Color(0.05, 0.06, 0.10)
const BG_DEEP := Color(0.03, 0.04, 0.07)
const PANEL := Color(0.10, 0.12, 0.19, 0.97)
const PANEL_SOFT := Color(0.13, 0.16, 0.24, 0.95)
const BORDER := Color(0.24, 0.33, 0.48, 0.8)
const SHADOW := Color(0.0, 0.0, 0.0, 0.45)

const TEXT := Color(0.92, 0.95, 1.0)
const TEXT_DIM := Color(0.58, 0.65, 0.77)
const ACCENT := Color(0.42, 0.78, 1.0)

const HEALTH := Color(0.48, 0.86, 0.55)
const HEALTH_TRACK := Color(0.10, 0.20, 0.14, 0.9)
const STAMINA := Color(0.36, 0.72, 1.0)
const STAMINA_TRACK := Color(0.08, 0.13, 0.22, 0.9)
const STAMINA_LOW := Color(1.0, 0.45, 0.40)
const DANGER := Color(1.0, 0.42, 0.40)
const GOLD := Color(1.0, 0.80, 0.30)


# ------------------------------------------------------------------- StyleBoxes

static func panel_style(bg: Color = PANEL, radius: int = 14, shadow: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	# LA LUZ DE ARRIBA: el borde superior mas grueso y mas claro. Es lo que hace que un
	# panel se lea como una placa con volumen y no como un rectangulo pintado.
	sb.border_width_top = 2
	sb.border_blend = true
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 13
	sb.content_margin_bottom = 13
	if shadow > 0:
		sb.shadow_color = SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 3)
	return sb


## Bloque de color plano y redondeado, sin margenes. Para barras y acentos.
static func bar_style(color: Color, radius: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(0)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	return sb


static func make_panel(bg: Color = PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg))
	return p


# ---------------------------------------------------------------------- Texto

static func make_label(text: String, size: int = 16, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_title(text: String) -> Label:
	var l := make_label(text, 40, TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Titulo de seccion con una barra de acento debajo. Da jerarquia sin necesitar otra
## tipografia, que es lo unico que no tenemos.
static func make_heading(text: String, size: int = 18) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(make_label(text, size, ACCENT))
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(38, 3)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.add_theme_stylebox_override("panel", bar_style(ACCENT, 2))
	box.add_child(rule)
	return box


# --------------------------------------------------------------------- Botones

static func make_button(text: String, accent: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 17)

	var base := ACCENT.darkened(0.62) if accent else PANEL_SOFT
	b.add_theme_stylebox_override("normal", _button_style(base, accent))
	var hover := _button_style(base.lightened(0.14), accent)
	# EL BRILLO AL PASAR EL MOUSE: una sombra del color del acento, sin desplazar. Se lee
	# como que el boton se enciende, que es mas claro que un cambio de tono.
	hover.shadow_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.28)
	hover.shadow_size = 9
	hover.shadow_offset = Vector2.ZERO
	b.add_theme_stylebox_override("hover", hover)
	var apretado := _button_style(base.lightened(0.26), accent)
	# Apretado, el relieve de abajo se achica: el boton "baja".
	apretado.border_width_bottom = 1
	b.add_theme_stylebox_override("pressed", apretado)
	b.add_theme_stylebox_override("disabled", _button_style(base.darkened(0.35), false))
	b.add_theme_stylebox_override("focus", _foco())
	b.add_theme_color_override("font_color", TEXT if accent else TEXT_DIM.lightened(0.25))
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.pressed.connect(func() -> void: Sfx.play_2d(&"ui_click", -8.0))

	# --- Reaccion al mouse ---
	#
	# Los estilos de hover/pressed ya cambiaban el color, pero un cambio de color solo
	# no se siente: el boton no ACUSA el toque. Un crecimiento del 2.5% al pasar por
	# encima y un hundimiento al apretar hacen que responda como un boton fisico, y
	# cuestan dos tweens.
	#
	# El pivote se recalcula en cada resize porque un Control escala desde su esquina
	# superior izquierda: sin centrarlo, el boton crece hacia abajo y a la derecha y se
	# ve como si se desalineara.
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void:
		_escalar(b, 1.025, 0.10)
		# Solo si alguien grabo assets/audio/ui_hover: sin archivo no suena nada.
		Sfx.play_2d(&"ui_hover", -14.0))
	b.mouse_exited.connect(func() -> void: _escalar(b, 1.0, 0.10))
	b.button_down.connect(func() -> void: _escalar(b, 0.975, 0.06))
	b.button_up.connect(func() -> void: _escalar(b, 1.0, 0.09))
	return b


static func _escalar(control: Control, destino: float, tiempo: float) -> void:
	if not is_instance_valid(control):
		return
	var tw := control.create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(control, "scale", Vector2(destino, destino), tiempo)


static func _button_style(bg: Color, accent: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(0)
	# Franja de acento a la izquierda: marca el boton principal sin gritar.
	sb.border_width_left = 3
	# Y EL RELIEVE DE ABAJO: un borde inferior mas oscuro, como el canto de una tecla.
	sb.border_width_bottom = 3
	sb.border_color = ACCENT if accent else BORDER
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


## UN BOTON GRANDE DEL MENU PRINCIPAL: el nombre en grande y abajo una linea que dice que
## hay adentro, con la franja y el brillo del color que se le pase. El texto va en dos
## Labels hijos (un Button no tiene dos renglones de distinto tamaño); se cambia con
## big_button_text().
static func make_big_button(titulo: String, color: Color, subtitulo: String = "") -> Button:
	var b := make_card_button(color)
	b.custom_minimum_size = Vector2(0, 62 if not subtitulo.is_empty() else 52)
	var textos := VBoxContainer.new()
	textos.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	textos.offset_left = 20
	textos.offset_right = -12
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", 0)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(textos)
	var t := make_label(titulo, 22, TEXT)
	t.add_theme_constant_override("outline_size", 4)
	t.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.35))
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(t)
	b.set_meta(&"titulo", t)
	if not subtitulo.is_empty():
		var s := make_label(subtitulo, 12, color.lightened(0.15))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		textos.add_child(s)
	return b


static func big_button_text(b: Button, texto: String) -> void:
	var t := b.get_meta(&"titulo", null) as Label
	if t != null:
		t.text = texto


## UNA TARJETA: un boton sin texto propio, con la franja de su color a la izquierda, que se
## enciende de ese color al pasar el mouse o con el foco. El contenido se lo pone cada uno.
static func make_card_button(color: Color) -> Button:
	var b := Button.new()
	b.text = ""
	b.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r * 0.16 + 0.06, color.g * 0.16 + 0.07, color.b * 0.16 + 0.12, 0.96)
	normal.set_corner_radius_all(12)
	normal.border_width_left = 4
	normal.border_width_bottom = 3
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_color = Color(color.r, color.g, color.b, 0.85)
	normal.border_blend = true
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.10)
	hover.border_color = color
	hover.shadow_color = Color(color.r, color.g, color.b, 0.35)
	hover.shadow_size = 12
	hover.shadow_offset = Vector2.ZERO
	var apretado := hover.duplicate() as StyleBoxFlat
	apretado.bg_color = normal.bg_color.lightened(0.18)
	apretado.border_width_bottom = 1
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.set_corner_radius_all(12)
	foco.set_border_width_all(2)
	foco.border_color = color.lightened(0.3)
	foco.set_expand_margin_all(3.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", apretado)
	b.add_theme_stylebox_override("focus", foco)
	b.add_theme_stylebox_override("disabled", normal)
	b.pressed.connect(func() -> void: Sfx.play_2d(&"ui_click", -8.0))
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void:
		_escalar(b, 1.02, 0.10)
		Sfx.play_2d(&"ui_hover", -14.0))
	b.mouse_exited.connect(func() -> void: _escalar(b, 1.0, 0.10))
	b.button_down.connect(func() -> void: _escalar(b, 0.98, 0.06))
	b.button_up.connect(func() -> void: _escalar(b, 1.0, 0.09))
	return b


## El marco del boton elegido con el mando.
##
## UN BORDE Y NO UN COLOR: Godot dibuja el foco ENCIMA del estilo del boton, asi que uno
## relleno tapaba si el boton era el principal o no, y uno apenas mas claro —el que habia—
## no se distinguia del resto al recorrer un menu con la cruceta. El mouse no lo ve nunca:
## Godot muestra el foco solo cuando llega con el teclado o el mando.
static func _foco() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = ACCENT.lightened(0.25)
	sb.set_expand_margin_all(3.0)
	return sb


static func make_line_edit(placeholder: String, value: String = "") -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = value
	le.custom_minimum_size = Vector2(0, 40)
	le.add_theme_font_size_override("font_size", 16)
	le.add_theme_color_override("font_color", TEXT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = BG_DEEP
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(1)
	normal.border_color = BORDER.darkened(0.3)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ACCENT
	focus.set_border_width_all(2)

	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	return le


# ---------------------------------------------------------------------- Barras

## Barra de progreso: pista oscura redondeada con un relleno del mismo radio.
## Devuelve [pista, relleno]. El relleno se mueve con anchor_right.
static func make_bar(fill_color: Color, track_color: Color, height: int) -> Array:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(0, height)
	track.add_theme_stylebox_override("panel", bar_style(track_color, int(height * 0.35)))
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# La pista con un borde apenas mas claro: marca hasta donde llega la barra llena.
	var pista := bar_style(track_color, int(height * 0.35))
	pista.set_border_width_all(1)
	pista.border_color = Color(1.0, 1.0, 1.0, 0.10)
	track.add_theme_stylebox_override("panel", pista)

	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", bar_style(fill_color, int(height * 0.35)))
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	# EL BRILLO: una franja clara en la mitad de arriba del relleno, que se mueve con el.
	# Es lo que hace que una barra plana se vea como un tubo lleno de algo.
	var brillo := Panel.new()
	brillo.add_theme_stylebox_override("panel", bar_style(Color(1.0, 1.0, 1.0, 0.16), int(height * 0.3)))
	brillo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	brillo.offset_left = 3
	brillo.offset_right = -3
	brillo.offset_top = 2
	brillo.anchor_bottom = 0.42
	brillo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_child(brillo)

	return [track, fill]


static func make_spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Tamaño de diseño de la UI. Con stretch_mode = canvas_items, las pantallas SIEMPRE
## trabajan en este espacio sin importar el tamaño real de la ventana, asi que se puede
## posicionar contra estos numeros sin preguntarle nada al viewport.
const DESIGN_SIZE := Vector2(1280.0, 720.0)


## Fondo animado de las pantallas de menu.
##
## POR QUE: antes era un ColorRect de un solo color. Funcionaba, pero la primera
## pantalla del juego es la que decide si alguien le da una oportunidad, y un
## rectangulo liso dice "esto es un prototipo". Son tres capas baratas:
##
##   1. un degrade vertical, que da profundidad;
##   2. un resplandor detras del contenido, que dirige la mirada al centro;
##   3. nieve cayendo, que ata la pantalla al tema helado del juego y —lo importante—
##      MUEVE algo: una pantalla quieta se lee como una imagen, una con movimiento se
##      lee como un juego encendido.
##
## Todo generado por codigo, como el resto: el proyecto no tiene un solo archivo de arte.
static func build_background(parent: Control) -> void:
	# --- 1. Degrade vertical ---
	var grad := Gradient.new()
	grad.set_color(0, BG_DEEP)
	grad.set_color(1, Color(0.12, 0.11, 0.21))
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0.5, 0.0)
	grad_tex.fill_to = Vector2(0.5, 1.0)
	grad_tex.width = 8
	grad_tex.height = 256
	parent.add_child(_stretched(grad_tex))

	# --- 2. Resplandor radial en el centro ---
	var halo := Gradient.new()
	halo.set_color(0, Color(0.30, 0.52, 0.95, 0.34))
	halo.set_color(1, Color(0.30, 0.52, 0.95, 0.0))
	var halo_tex := GradientTexture2D.new()
	halo_tex.gradient = halo
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 256
	halo_tex.height = 256
	parent.add_child(_stretched(halo_tex))

	# --- 2b. Las luces de la temporada: dos bandas diagonales, una celeste y una dorada,
	# que se mueven de a poco. Le dan al fondo la energia de un menu de pelea, y como van
	# muy por detras y muy transparentes no compiten con el texto.
	for k: int in range(2):
		var luz := Gradient.new()
		var tono := Color(0.35, 0.65, 1.0) if k == 0 else Color(1.0, 0.75, 0.30)
		# LOS TRES PUNTOS DE UNA, en orden. Con set_color despues de add_point, el indice 1
		# ya era el punto del medio y el ultimo quedaba blanco opaco: la "luz" tapaba media
		# pantalla.
		luz.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		luz.colors = PackedColorArray([Color(tono.r, tono.g, tono.b, 0.0),
			Color(tono.r, tono.g, tono.b, 0.09 if k == 0 else 0.06), Color(tono.r, tono.g, tono.b, 0.0)])
		var luz_tex := GradientTexture2D.new()
		luz_tex.gradient = luz
		luz_tex.fill_from = Vector2(0.0, 0.5)
		luz_tex.fill_to = Vector2(1.0, 0.5)
		luz_tex.width = 128
		luz_tex.height = 8
		var banda := TextureRect.new()
		banda.texture = luz_tex
		banda.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banda.stretch_mode = TextureRect.STRETCH_SCALE
		banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banda.size = Vector2(520.0, DESIGN_SIZE.y * 2.2)
		banda.pivot_offset = banda.size * 0.5
		banda.rotation = deg_to_rad(28.0 if k == 0 else -24.0)
		banda.position = Vector2(DESIGN_SIZE.x * (0.30 if k == 0 else 0.72) - 260.0, -DESIGN_SIZE.y * 0.6)
		parent.add_child(banda)
		var va := banda.create_tween().set_loops()
		va.tween_property(banda, "position:x", banda.position.x + 160.0, 9.0 + float(k) * 3.0) \
			.set_trans(Tween.TRANS_SINE)
		va.tween_property(banda, "position:x", banda.position.x, 9.0 + float(k) * 3.0) \
			.set_trans(Tween.TRANS_SINE)

	# --- 3. Nieve ---
	var nieve := CPUParticles2D.new()
	nieve.amount = 110
	nieve.lifetime = 11.0
	# Arranca con la vida ya corrida: si no, la pantalla aparece vacia y la nieve entra
	# de a poco desde arriba durante los primeros diez segundos.
	nieve.preprocess = 11.0
	nieve.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	nieve.emission_rect_extents = Vector2(DESIGN_SIZE.x * 0.6, 8.0)
	nieve.position = Vector2(DESIGN_SIZE.x * 0.5, -12.0)
	nieve.direction = Vector2(0.0, 1.0)
	nieve.spread = 12.0
	nieve.gravity = Vector2(0.0, 6.0)
	nieve.initial_velocity_min = 16.0
	nieve.initial_velocity_max = 44.0
	# Vaiven lateral: sin esto caen en lineas rectas y parece lluvia, no nieve.
	nieve.tangential_accel_min = -7.0
	nieve.tangential_accel_max = 7.0
	# CON TEXTURA, si o si. Un CPUParticles2D sin textura dibuja un punto de un pixel:
	# la primera version tenia la nieve funcionando perfecto y era literalmente
	# invisible en la captura.
	nieve.texture = _copo_textura()
	# Chicos y tenues. Con 0.22-0.75 y alfa 0.65 parecian bokeh de foto, no nieve:
	# competian con el panel en vez de acompañarlo.
	nieve.scale_amount_min = 0.07
	nieve.scale_amount_max = 0.30
	nieve.color = Color(0.82, 0.92, 1.0, 0.42)
	# NADA de mouse_filter aca: CPUParticles2D es un Node2D y no lo tiene. Asignarlo
	# aborta la funcion en ese renglon, antes del add_child, y la nieve no llegaba a
	# existir — el fondo se veia "bien" y faltaba una capa entera sin ningun sintoma.
	parent.add_child(nieve)


## Copo: un circulo suave de 32 px, generado igual que todo lo demas.
static func _copo_textura() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	# Un punto intermedio hace el borde mas suave; sin el, el copo tiene un anillo duro.
	g.add_point(0.45, Color(1.0, 1.0, 1.0, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


static func _stretched(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Estira un Control a toda la pantalla.
##
## POR QUE HACE FALTA: estas pantallas cuelgan de Main, que es un Node pelado y no un
## Control. set_anchors_preset por si solo deja los offsets viejos y el Control termina
## dimensionado a su contenido, pegado arriba a la izquierda en vez de ocupar la ventana.
static func fill_viewport(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
