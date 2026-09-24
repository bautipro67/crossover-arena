class_name HUD
extends CanvasLayer
## HUD de combate.
##
## La BARRA DE STAMINA es la protagonista, porque es el recurso que decide si podes
## tirar una habilidad o no. Por eso:
##   - Va grande y abajo a la izquierda, debajo de la vida.
##   - Tiene marcas verticales en el costo de cada habilidad: de un vistazo sabes si
##     te alcanza para Ice Shock o para Snowgrave.
##   - Destella en rojo cuando intentas tirar algo y no te alcanza.
##   - Los iconos de habilidad se apagan cuando no te alcanza la stamina.
##
## El dash y el sprint NO aparecen en la barra de stamina porque no la consumen:
## el dash tiene su propio indicador de cooldown aparte, para que quede claro.

## Las acciones de cada casilla de habilidad, en orden. La tecla que se MUESTRA sale de
## Controles cada vez: estaba escrita a mano ("Click izq", "E"...) y con teclas
## reasignables eso se vuelve mentira en cuanto alguien cambia una.
const ACCIONES_HABILIDAD: Array[StringName] = [&"attack_basic", &"ability_1", &"ability_2",
	&"ability_ultimate"]
var _etiquetas_tecla: Array[Label] = []

var _player: Player = null

var _health_fill: Panel = null
var _health_label: Label = null
var _shield_fill: Panel = null
var _chip_fill: Panel = null
## Hacia donde tiene que ir la barra fantasma, y donde esta ahora.
var _chip_ratio: float = 1.0
var _pulse_t: float = 0.0
var _chip_delay: float = 0.0

## Rojo apagado: tiene que leerse como "esto lo perdiste recien", no competir con la
## barra verde ni con el rojo de peligro.
const CHIP_COLOR: Color = Color(0.72, 0.24, 0.26)

## Celeste claro, distinto del azul de la stamina: son dos recursos y confundirlos
## en pelea te hace tomar la decision equivocada.
const SHIELD_COLOR: Color = Color(0.66, 0.92, 1.0)
var _stamina_fill: Panel = null
var _stamina_label: Label = null
var _stamina_markers: Control = null
var _stamina_flash: ColorRect = null
var _charge_fill: Panel = null
var _charge_label: Label = null

var _ability_row: HBoxContainer = null
## Las barras de vida, stamina y ultimate. Guardadas para moverlas con el dedo.
var _barras: Control = null

# --- El contador de combo ---
#
# Cuenta los golpes que entran MIENTRAS EL RIVAL SIGUE TAMBALEANDO del anterior: eso es un
# combo, una cadena que el otro no pudo cortar. Pasado el tambaleo sin otro golpe, se
# corta y se apaga. No da nada: es para que se vea la cadena que se esta haciendo.
var _combo_caja: Control = null
var _combo_num: Label = null
var _combo_daño_label: Label = null
var _combo_golpes: int = 0
var _combo_daño: float = 0.0
var _combo_ultimo: float = -10.0
var _ability_widgets: Array[Dictionary] = []

var _channel_box: Control = null
var _channel_fill: ColorRect = null
var _channel_label: Label = null

var _dash_panel: PanelContainer = null
var _dash_label: Label = null

var _kill_feed: VBoxContainer = null
var _center_label: Label = null
var _target_label: Label = null
var _premios: VBoxContainer = null
var _monedas_previas: int = -1
var _modo_panel: PanelContainer = null
var _modo_label: Label = null
var _scoreboard: Control = null
var _scoreboard_rows: VBoxContainer = null

var _flash_time: float = 0.0
var _respawn_left: float = 0.0


func _ready() -> void:
	layer = 10
	_build()


# ------------------------------------------------------------------ Construccion

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_crosshair(root)
	_build_bars(root)
	_build_abilities(root)
	_build_channel(root)
	_build_dash(root)
	_build_kill_feed(root)
	_build_center_label(root)
	_build_scoreboard(root)
	_build_modo(root)
	_build_progreso(root)
	_build_combo(root)
	_aplicar_dispositivo()


## Los avisos de progreso: monedas ganadas y subidas de nivel.
##
## SIN ESTO LA PROGRESION NO EXISTE. Las monedas se suman en silencio y subir de nivel
## pasa entre dos respawns sin que nadie se entere: el jugador se entera al volver al
## menu, cuando ya no puede asociarlo con lo que hizo. Un sistema de recompensas que no
## avisa en el momento en que recompensa no es un sistema de recompensas.
##
## Van arriba a la derecha, lejos de la vida y de las habilidades: es informacion buena,
## nunca urgente, y no puede robarle un milimetro a lo que si lo es.
func _build_progreso(root: Control) -> void:
	_premios = VBoxContainer.new()
	_premios.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_premios.position = Vector2(-230.0, 64.0)
	_premios.custom_minimum_size = Vector2(210, 0)
	_premios.alignment = BoxContainer.ALIGNMENT_BEGIN
	_premios.add_theme_constant_override("separation", 3)
	_premios.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_premios)

	_monedas_previas = Progreso.monedas
	Progreso.monedas_cambiaron.connect(_on_monedas)
	# Opciones se puede abrir desde la pausa en plena partida: si se cambia una tecla ahi,
	# las casillas de abajo tienen que enterarse sin esperar a la proxima partida.
	Controles.cambio.connect(_on_controles_cambio)
	Controles.dispositivo_cambio.connect(_on_dispositivo_cambio)
	Progreso.subio_nivel.connect(_on_subio_nivel)


## Al costado de la mira, que es donde estan los ojos mientras se pelea.
func _build_combo(root: Control) -> void:
	_combo_caja = VBoxContainer.new()
	_combo_caja.set_anchors_preset(Control.PRESET_CENTER)
	_combo_caja.position = Vector2(70.0, -10.0)
	_combo_caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_caja.modulate.a = 0.0
	root.add_child(_combo_caja)
	_combo_num = UITheme.make_label("", 30, UITheme.GOLD)
	_combo_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_caja.add_child(_combo_num)
	_combo_daño_label = UITheme.make_label("", 13, UITheme.TEXT)
	_combo_daño_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_caja.add_child(_combo_daño_label)
	FX.golpe_propio.connect(_on_golpe_propio)


## Cuanto puede pasar entre un golpe y el siguiente para que siga siendo el mismo combo:
## el tambaleo, mas un margen para lo que tarda en llegar el aviso por la red.
func _ventana_combo() -> float:
	return StatusEffects.TAMBALEO + 0.12


func _on_golpe_propio(_victima: Node, cantidad: float) -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _combo_ultimo > _ventana_combo():
		_combo_golpes = 0
		_combo_daño = 0.0
	_combo_golpes += 1
	_combo_daño += cantidad
	_combo_ultimo = ahora
	# Un golpe suelto no es un combo: el contador aparece desde el segundo.
	if _combo_golpes < 2 or not is_instance_valid(_combo_caja):
		return
	_combo_num.text = "COMBO ×%d" % _combo_golpes
	_combo_daño_label.text = "%d de daño" % int(round(_combo_daño))
	_combo_caja.modulate.a = 1.0
	# Un saltito con cada golpe: el numero que crece tiene que sentirse, no solo leerse.
	_combo_caja.pivot_offset = _combo_caja.size * 0.5
	var tw := _combo_caja.create_tween()
	tw.tween_property(_combo_caja, "scale", Vector2.ONE, 0.12).from(Vector2.ONE * 1.25)


func _actualizar_combo() -> void:
	if not is_instance_valid(_combo_caja) or _combo_caja.modulate.a <= 0.0:
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if ahora - _combo_ultimo > _ventana_combo():
		# Cortado: se va apagando, no desaparece de golpe, asi se alcanza a leer el total.
		_combo_caja.modulate.a = maxf(0.0, _combo_caja.modulate.a - get_process_delta_time() * 1.6)
		if _combo_caja.modulate.a <= 0.0:
			_combo_golpes = 0
			_combo_daño = 0.0


func _exit_tree() -> void:
	if FX.golpe_propio.is_connected(_on_golpe_propio):
		FX.golpe_propio.disconnect(_on_golpe_propio)
	if Progreso.monedas_cambiaron.is_connected(_on_monedas):
		Progreso.monedas_cambiaron.disconnect(_on_monedas)
	if Progreso.subio_nivel.is_connected(_on_subio_nivel):
		Progreso.subio_nivel.disconnect(_on_subio_nivel)
	if Controles.cambio.is_connected(_on_controles_cambio):
		Controles.cambio.disconnect(_on_controles_cambio)
	if Controles.dispositivo_cambio.is_connected(_on_dispositivo_cambio):
		Controles.dispositivo_cambio.disconnect(_on_dispositivo_cambio)


func _on_monedas(total: int) -> void:
	var ganado := total - _monedas_previas
	_monedas_previas = total
	if ganado > 0:
		_premio("+%d ◆" % ganado, UITheme.GOLD, 16)


func _on_subio_nivel(nivel: int) -> void:
	_premio("NIVEL %d" % nivel, UITheme.ACCENT, 22)
	Sfx.play_2d(&"respawn", -4.0)


## Un aviso que sube y se desvanece. Se limita a cuatro a la vez: en una racha de bajas
## seguidas, sin tope, la columna se come media pantalla.
func _premio(texto: String, color: Color, tamaño: int) -> void:
	if not is_instance_valid(_premios):
		return
	while _premios.get_child_count() >= 4:
		var viejo := _premios.get_child(0)
		_premios.remove_child(viejo)
		viejo.queue_free()

	var etiqueta := UITheme.make_label(texto, tamaño, color)
	etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	etiqueta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_premios.add_child(etiqueta)

	etiqueta.modulate.a = 0.0
	etiqueta.scale = Vector2(0.7, 0.7)
	etiqueta.pivot_offset = Vector2(210.0, 10.0)
	var tw := etiqueta.create_tween()
	tw.set_parallel(true)
	tw.tween_property(etiqueta, "modulate:a", 1.0, 0.12)
	tw.tween_property(etiqueta, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.5)
	tw.chain().tween_property(etiqueta, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(etiqueta.queue_free)


## El marcador del modo: oleada, reloj, cuantos faltan.
##
## ARRIBA Y AL CENTRO, que es el unico lugar libre y ademas el correcto: en supervivencia
## y contrarreloj ese numero es el objetivo de la partida, y un objetivo escondido en una
## esquina no cumple ninguna funcion. En practica y en linea no se dibuja nada.
func _build_modo(root: Control) -> void:
	_modo_panel = UITheme.make_panel(Color(0.08, 0.10, 0.16, 0.82))
	_modo_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_modo_panel.position = Vector2(-140.0, 12.0)
	_modo_panel.custom_minimum_size = Vector2(280, 0)
	_modo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modo_panel.visible = false
	root.add_child(_modo_panel)

	_modo_label = UITheme.make_label("", 18, UITheme.GOLD)
	_modo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_modo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modo_panel.add_child(_modo_label)


func _build_crosshair(root: Control) -> void:
	# Cruz de cuatro trazos con un hueco en el medio: se ve sobre cualquier fondo,
	# a diferencia de un punto, que desaparece contra el hielo o contra el dorado.
	var arms: Array = [
		Vector2(-11, -1), Vector2(4, -1), Vector2(-1, -11), Vector2(-1, 4),
	]
	var sizes: Array = [
		Vector2(7, 2), Vector2(7, 2), Vector2(2, 7), Vector2(2, 7),
	]
	for i: int in range(arms.size()):
		var arm := ColorRect.new()
		arm.color = Color(1.0, 1.0, 1.0, 0.85)
		arm.set_anchors_preset(Control.PRESET_CENTER)
		var offset: Vector2 = arms[i]
		var size: Vector2 = sizes[i]
		arm.offset_left = offset.x
		arm.offset_top = offset.y
		arm.offset_right = offset.x + size.x
		arm.offset_bottom = offset.y + size.y
		arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(arm)

	_target_label = UITheme.make_label("", 13, UITheme.ACCENT)
	_target_label.set_anchors_preset(Control.PRESET_CENTER)
	_target_label.offset_left = -140
	_target_label.offset_top = 22
	_target_label.offset_right = 140
	_target_label.offset_bottom = 44
	_target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_target_label)


func _build_bars(root: Control) -> void:
	var holder := VBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	holder.offset_left = 28
	holder.offset_top = -172
	holder.offset_right = 388
	holder.offset_bottom = -28
	holder.add_theme_constant_override("separation", 6)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	_barras = holder

	# --- Vida ---
	_health_label = UITheme.make_label("VIDA  100 / 100", 13, UITheme.TEXT_DIM)
	holder.add_child(_health_label)
	var health_bar := UITheme.make_bar(UITheme.HEALTH, UITheme.HEALTH_TRACK, 16)
	holder.add_child(health_bar[0])
	_health_fill = health_bar[1]

	# El escudo se dibuja ENCIMA de la barra de vida, no al lado. Asi se lee de un
	# vistazo cuanto aguantas en total, que es la pregunta que te haces en pelea;
	# una segunda barra aparte te obliga a sumar mentalmente.
	# Barra fantasma DETRAS de la vida: se queda donde estabas y baja despacio.
	#
	# POR QUE: la barra normal salta al valor nuevo al instante, asi que un golpe de 22
	# y uno de 65 se ven igual de rapido — solo cambia donde queda. La fantasma muestra
	# CUANTO te acaban de sacar, que es la informacion que te hace decidir si seguis
	# peleando o te tapas. Es el mismo truco de los juegos de pelea.
	_chip_fill = Panel.new()
	_chip_fill.add_theme_stylebox_override("panel", UITheme.bar_style(CHIP_COLOR, 7))
	_chip_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chip_fill.anchor_right = 1.0
	_chip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar[0].add_child(_chip_fill)
	# La vida va ENCIMA de la fantasma, si no la tapa.
	health_bar[0].move_child(_health_fill, -1)

	_shield_fill = Panel.new()
	_shield_fill.add_theme_stylebox_override("panel", UITheme.bar_style(SHIELD_COLOR, 7))
	_shield_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shield_fill.anchor_left = 1.0
	_shield_fill.anchor_right = 1.0
	_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shield_fill.visible = false
	health_bar[0].add_child(_shield_fill)

	holder.add_child(UITheme.make_spacer(5))

	# --- Stamina: mas alta que la de vida, a proposito. Es el recurso que decide
	# si podes tirar una habilidad, tiene que ser lo primero que ves. ---
	_stamina_label = UITheme.make_label("STAMINA  100 / 100", 14, UITheme.STAMINA)
	holder.add_child(_stamina_label)
	var stamina_bar := UITheme.make_bar(UITheme.STAMINA, UITheme.STAMINA_TRACK, 26)
	var stamina_track: Panel = stamina_bar[0]
	holder.add_child(stamina_track)
	_stamina_fill = stamina_bar[1]

	# Marcas de costo de cada habilidad.
	_stamina_markers = Control.new()
	_stamina_markers.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_markers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_track.add_child(_stamina_markers)

	# Capa de destello rojo cuando falta stamina.
	_stamina_flash = ColorRect.new()
	_stamina_flash.color = Color(1.0, 0.3, 0.3, 0.0)
	_stamina_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stamina_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_track.add_child(_stamina_flash)

	holder.add_child(UITheme.make_spacer(5))

	# --- Carga del ultimate: se llena PEGANDO, no esperando ---
	_charge_label = UITheme.make_label("ULTIMATE  0%", 13, UITheme.GOLD)
	holder.add_child(_charge_label)
	var charge_bar := UITheme.make_bar(UITheme.GOLD, Color(0.20, 0.15, 0.06, 0.9), 14)
	holder.add_child(charge_bar[0])
	_charge_fill = charge_bar[1]

	var note := UITheme.make_label("Correr, golpear y dashear no gastan stamina", 11, UITheme.TEXT_DIM)
	holder.add_child(note)


func _build_abilities(root: Control) -> void:
	_ability_row = HBoxContainer.new()
	# Medidas para CUATRO cartas: 4 x 96 + 3 x 8 de separacion = 408, mas 28 de margen.
	# Con las medidas viejas (3 x 104) la cuarta carta se salia de la pantalla.
	_ability_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability_row.offset_left = -436
	_ability_row.offset_top = -128
	_ability_row.offset_right = -28
	_ability_row.offset_bottom = -28
	_ability_row.add_theme_constant_override("separation", 8)
	_ability_row.alignment = BoxContainer.ALIGNMENT_END
	_ability_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_ability_row)


func _build_channel(root: Control) -> void:
	_channel_box = Control.new()
	_channel_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_channel_box.offset_left = -190
	_channel_box.offset_top = 90
	_channel_box.offset_right = 190
	_channel_box.offset_bottom = 140
	_channel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_channel_box.visible = false
	root.add_child(_channel_box)

	_channel_label = UITheme.make_label("", 16, UITheme.TEXT)
	_channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_channel_box.add_child(_channel_label)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.06, 0.08, 0.13, 0.9)
	bar_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bg.offset_top = -16
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_channel_box.add_child(bar_bg)

	_channel_fill = ColorRect.new()
	_channel_fill.color = Color(0.85, 0.95, 1.0)
	_channel_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_channel_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_channel_fill)


func _build_dash(root: Control) -> void:
	_dash_panel = UITheme.make_panel(Color(0.09, 0.12, 0.19, 0.85))
	_dash_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_dash_panel.offset_left = -190
	_dash_panel.offset_top = 22
	_dash_panel.offset_right = -22
	_dash_panel.offset_bottom = 70
	_dash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dash_panel)

	_dash_label = UITheme.make_label("DASH  [%s]  listo" % Controles.nombre_tecla(&"dash"), 14, UITheme.ACCENT)
	_dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dash_panel.add_child(_dash_label)


func _build_kill_feed(root: Control) -> void:
	_kill_feed = VBoxContainer.new()
	_kill_feed.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_kill_feed.offset_left = 22
	_kill_feed.offset_top = 22
	_kill_feed.offset_right = 400
	_kill_feed.offset_bottom = 200
	_kill_feed.add_theme_constant_override("separation", 4)
	_kill_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_kill_feed)
	Net.kill_registered.connect(_on_kill_registered)


func _build_center_label(root: Control) -> void:
	_center_label = UITheme.make_label("", 30, UITheme.TEXT)
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.offset_left = -300
	_center_label.offset_top = -80
	_center_label.offset_right = 300
	_center_label.offset_bottom = -20
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_center_label)


func _build_scoreboard(root: Control) -> void:
	_scoreboard = Control.new()
	_scoreboard.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scoreboard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard.visible = false
	root.add_child(_scoreboard)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scoreboard.add_child(center)

	var panel := UITheme.make_panel(Color(0.05, 0.07, 0.12, 0.93))
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UITheme.make_label("MARCADOR  (primero a %d)" % GameConfig.SCORE_TO_WIN, 20, UITheme.ACCENT))
	box.add_child(HSeparator.new())

	_scoreboard_rows = VBoxContainer.new()
	_scoreboard_rows.add_theme_constant_override("separation", 4)
	box.add_child(_scoreboard_rows)


# --------------------------------------------------------------------- Binding

func bind_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	# Siempre desconectamos primero. Sin esto, rebindear duplica todas las conexiones y
	# cada señal se procesa dos veces.
	#
	# Y OJO: no cortes por "es el mismo jugador". Rebindear al MISMO Player con otro
	# personaje es un caso valido, y saltearlo deja el HUD mostrando el kit viejo.
	_unbind_player()
	_player = player
	_player.health.changed.connect(_on_health_changed)
	_player.health.damaged.connect(_on_player_damaged)
	_player.health.shield_changed.connect(_on_shield_changed)
	_player.health.died.connect(_on_local_died)
	_player.respawned.connect(_on_local_respawned)
	_player.stamina.changed.connect(_on_stamina_changed)
	_player.caster.ability_failed.connect(_on_ability_failed)
	_player.caster.channel_started.connect(_on_channel_started)
	_player.caster.channel_finished.connect(_on_channel_ended)
	_player.caster.channel_cancelled.connect(_on_channel_cancelled)
	_player.ultimate.changed.connect(_on_charge_changed)
	_player.ultimate.became_ready.connect(_on_charge_ready)

	_build_ability_widgets()
	_build_stamina_markers()
	_on_health_changed(_player.health.current, _player.health.max_health)
	_on_shield_changed(_player.health.shield)
	_on_stamina_changed(_player.stamina.current, _player.stamina.max_stamina)
	_on_charge_changed(_player.ultimate.current, UltimateCharge.MAX_CHARGE)


## Corta todas las conexiones con el jugador anterior.
func _unbind_player() -> void:
	if not is_instance_valid(_player):
		_player = null
		return
	var pairs: Array = [
		[_player.health.changed, _on_health_changed],
		[_player.health.damaged, _on_player_damaged],
		[_player.health.shield_changed, _on_shield_changed],
		[_player.health.died, _on_local_died],
		[_player.respawned, _on_local_respawned],
		[_player.stamina.changed, _on_stamina_changed],
		[_player.caster.ability_failed, _on_ability_failed],
		[_player.caster.channel_started, _on_channel_started],
		[_player.caster.channel_finished, _on_channel_ended],
		[_player.caster.channel_cancelled, _on_channel_cancelled],
		[_player.ultimate.changed, _on_charge_changed],
		[_player.ultimate.became_ready, _on_charge_ready],
	]
	for pair: Array in pairs:
		var sig: Signal = pair[0]
		var target: Callable = pair[1]
		if sig.is_connected(target):
			sig.disconnect(target)
	_player = null


func _build_ability_widgets() -> void:
	for child: Node in _ability_row.get_children():
		child.queue_free()
	_ability_widgets.clear()

	for i: int in range(_player.caster.abilities.size()):
		var ability := _player.caster.abilities[i]

		# Carta oscura con una franja del color de la habilidad arriba. Texto claro
		# sobre fondo oscuro: se lee mucho mejor que texto oscuro sobre color saturado,
		# y deja que el color identifique la habilidad sin pelear con la legibilidad.
		var card := Panel.new()
		card.custom_minimum_size = Vector2(96, 100)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := UITheme.bar_style(_card_color(ability.icon_color, true), 9)
		card.add_theme_stylebox_override("panel", style)
		_ability_row.add_child(card)

		var strip := Panel.new()
		strip.add_theme_stylebox_override("panel", UITheme.bar_style(ability.icon_color, 3))
		strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		strip.offset_left = 8
		strip.offset_right = -8
		strip.offset_top = 7
		strip.offset_bottom = 12
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(strip)

		var name_label := UITheme.make_label(ability.display_name, 12, UITheme.TEXT)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		name_label.offset_top = 17
		name_label.offset_left = 5
		name_label.offset_right = -5
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(name_label)

		var free := ability.stamina_cost <= 0.0
		var cost_label := UITheme.make_label(
			"GRATIS" if free else "%d" % int(ability.stamina_cost),
			15 if free else 24,
			UITheme.HEALTH if free else UITheme.STAMINA)
		cost_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cost_label.offset_left = -52
		cost_label.offset_right = 52
		cost_label.offset_top = -2
		cost_label.offset_bottom = 28
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(cost_label)

		var key_label := UITheme.make_label(
			Controles.nombre_tecla(ACCIONES_HABILIDAD[i]) if i < ACCIONES_HABILIDAD.size() else "-",
			11, UITheme.TEXT_DIM)
		_etiquetas_tecla.append(key_label)
		key_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		key_label.offset_top = -21
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(key_label)

		# Sombra de cooldown: baja desde arriba a medida que se recarga.
		var cd := ColorRect.new()
		cd.color = Color(0.0, 0.0, 0.0, 0.62)
		cd.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		cd.anchor_bottom = 0.0
		cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cd)

		var cd_text := UITheme.make_label("", 26, UITheme.TEXT)
		cd_text.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		cd_text.offset_left = -52
		cd_text.offset_right = 52
		cd_text.offset_top = -16
		cd_text.offset_bottom = 16
		cd_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(cd_text)

		_ability_widgets.append({
			"style": style,
			"strip": strip,
			"cooldown": cd,
			"cooldown_text": cd_text,
			"cost_label": cost_label,
			"color": ability.icon_color,
			"cost": ability.stamina_cost,
			"needs_charge": ability.requires_charge,
		})


## Fondo de la carta de habilidad: el color de la habilidad muy oscurecido, asi cada
## una se distingue pero el texto encima sigue siendo legible.
func _card_color(color: Color, affordable: bool) -> Color:
	var base := color.darkened(0.78)
	base.a = 0.94
	if not affordable:
		base = base.darkened(0.45)
		base.a = 0.88
	return base


## Marcas verticales en la barra de stamina, una por cada costo de habilidad.
func _build_stamina_markers() -> void:
	for child: Node in _stamina_markers.get_children():
		child.queue_free()
	var max_stamina := _player.stamina.max_stamina
	if max_stamina <= 0.0:
		return
	for ability: Ability in _player.caster.abilities:
		if ability.stamina_cost <= 0.0:
			continue
		var ratio := clampf(ability.stamina_cost / max_stamina, 0.0, 1.0)
		var mark := ColorRect.new()
		mark.color = Color(1.0, 1.0, 1.0, 0.55)
		mark.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		mark.anchor_left = ratio
		mark.anchor_right = ratio
		mark.offset_left = -1.0
		mark.offset_right = 1.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stamina_markers.add_child(mark)


# ----------------------------------------------------------------------- Update

func _on_controles_cambio() -> void:
	for i: int in range(_etiquetas_tecla.size()):
		if is_instance_valid(_etiquetas_tecla[i]) and i < ACCIONES_HABILIDAD.size():
			_etiquetas_tecla[i].text = Controles.nombre_tecla(ACCIONES_HABILIDAD[i])
	# La barra del ultimate tambien nombra su tecla cuando esta lista.
	if is_instance_valid(_player):
		_on_charge_changed(_player.ultimate.current, UltimateCharge.MAX_CHARGE)


func _on_dispositivo_cambio() -> void:
	_on_controles_cambio()
	_aplicar_dispositivo()


## Con el dedo, el HUD le deja lugar a los botones de la pantalla.
##
## LAS CARTAS DE HABILIDADES Y EL DASH SE ESCONDEN: quedaban exactamente debajo de los
## botones táctiles, y cada boton ya muestra su propio cooldown. Las barras se mudan al
## centro de abajo, que es lo unico libre entre el stick y los botones: abajo a la
## izquierda, donde estaban, es donde se apoya el pulgar para caminar.
func _aplicar_dispositivo() -> void:
	var tactil := Controles.dispositivo == &"tactil"
	if is_instance_valid(_ability_row):
		_ability_row.visible = not tactil
	if is_instance_valid(_dash_panel):
		_dash_panel.visible = not tactil
	if not is_instance_valid(_barras):
		return
	if tactil:
		_barras.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		_barras.offset_left = -180
		_barras.offset_right = 180
	else:
		_barras.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_barras.offset_left = 28
		_barras.offset_right = 388
	_barras.offset_top = -172
	_barras.offset_bottom = -28


func _actualizar_modo() -> void:
	if not is_instance_valid(_modo_label):
		return
	var texto := Modos.marcador()
	_modo_panel.visible = not texto.is_empty()
	_modo_label.text = texto


func _process(delta: float) -> void:
	_actualizar_modo()
	_actualizar_combo()
	_update_chip(delta)
	_update_stamina_pulse(delta)

	if _flash_time > 0.0:
		_flash_time = maxf(0.0, _flash_time - delta * 3.0)
		_stamina_flash.color = Color(1.0, 0.3, 0.3, _flash_time * 0.6)

	if _respawn_left > 0.0:
		_respawn_left = maxf(0.0, _respawn_left - delta)
		_center_label.text = "Te mataron. Reapareces en %.1f s" % _respawn_left

	_scoreboard.visible = Input.is_action_pressed("scoreboard")
	if _scoreboard.visible:
		_refresh_scoreboard()

	if not is_instance_valid(_player):
		return

	_update_abilities()
	_update_dash()
	_update_channel()
	_update_target_info()


## La barra de stamina late cuando queda poca.
##
## POR QUE: la stamina es el recurso que decide si podes tirar la habilidad, y en
## pelea nadie mira la esquina inferior izquierda. El latido lo hace notar con la
## vision periferica, que es la unica disponible mientras esquivas.
func _update_stamina_pulse(delta: float) -> void:
	if _stamina_fill == null or not is_instance_valid(_player):
		return
	var ratio := _player.stamina.get_ratio()
	_pulse_t += delta
	if ratio > 0.3:
		_stamina_fill.modulate = Color.WHITE
		return
	# Cuanto menos queda, mas rapido y mas marcado.
	var vel := lerpf(3.0, 7.5, 1.0 - ratio / 0.3)
	var onda := 0.5 + 0.5 * sin(_pulse_t * vel)
	_stamina_fill.modulate = Color.WHITE.lerp(Color(1.0, 0.55, 0.5), onda * 0.75)


## La barra fantasma: espera un momento y despues baja hasta la vida real.
##
## La pausa antes de empezar a bajar es lo que la hace legible. Sin ella baja junto con
## la vida y no se ve nada.
func _update_chip(delta: float) -> void:
	if _chip_fill == null or not is_instance_valid(_player):
		return
	var objetivo := _health_fill.anchor_right
	if _chip_ratio <= objetivo:
		# Curaste o respawneaste: la fantasma alcanza a la vida sin demora.
		_chip_ratio = objetivo
		_chip_delay = 0.0
	elif _chip_delay > 0.0:
		_chip_delay = maxf(0.0, _chip_delay - delta)
	else:
		_chip_ratio = maxf(objetivo, _chip_ratio - delta * 0.55)
	_chip_fill.anchor_left = 0.0
	_chip_fill.anchor_right = _chip_ratio
	_chip_fill.visible = _chip_ratio > objetivo + 0.001


func _update_abilities() -> void:
	var current_stamina := _player.stamina.current
	for i: int in range(_ability_widgets.size()):
		var w := _ability_widgets[i]
		var remaining := _player.caster.get_cooldown_remaining(i)
		var ability := _player.caster.get_ability(i)
		var total: float = ability.cooldown if ability != null else 1.0

		var cd: ColorRect = w["cooldown"]
		cd.anchor_bottom = clampf(remaining / total, 0.0, 1.0) if total > 0.0 else 0.0

		var cd_text: Label = w["cooldown_text"]
		cd_text.text = "%.1f" % remaining if remaining > 0.05 else ""

		# Carta apagada si no te alcanza la stamina: de un vistazo sabes que podes tirar.
		var cost: float = w["cost"]
		var color: Color = w["color"]
		var affordable := cost <= 0.0 or current_stamina >= cost

		# Los ultimates piden ADEMAS la carga al 100%. Si falta, la carta muestra el
		# porcentaje: sin eso el jugador ve el icono apagado y no sabe por que.
		var charged := true
		if bool(w["needs_charge"]) and is_instance_valid(_player):
			charged = _player.ultimate.is_ready()
			if not charged:
				cd_text.text = "%d%%" % int(floor(_player.ultimate.get_ratio() * 100.0))

		var usable := affordable and charged
		var style: StyleBoxFlat = w["style"]
		var strip: Panel = w["strip"]
		var cost_label: Label = w["cost_label"]
		style.bg_color = _card_color(color, usable)
		strip.modulate.a = 1.0 if usable else 0.35
		cost_label.modulate.a = 1.0 if usable else 0.45


func _update_dash() -> void:
	var ratio := _player.get_dash_cooldown_ratio()
	if ratio <= 0.0:
		_dash_label.text = "DASH  [%s]  listo" % Controles.nombre_tecla(&"dash")
		_dash_label.add_theme_color_override("font_color", UITheme.ACCENT)
	else:
		_dash_label.text = "DASH  [%s]  %.1f s" % [Controles.nombre_tecla(&"dash"),
			ratio * _player.dash_cooldown]
		_dash_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)


func _update_channel() -> void:
	if not _player.caster.is_channeling:
		_channel_box.visible = false
		return
	_channel_box.visible = true
	var index := _player.caster.get_channel_index()
	var ability := _player.caster.get_ability(index)
	_channel_label.text = "Canalizando %s..." % (ability.display_name if ability != null else "")
	_channel_fill.anchor_right = clampf(_player.caster.get_channel_ratio(), 0.0, 1.0)


## Muestra la escarcha del jugador que tenes en la mira. Saber si el rival ya esta
## congelado es lo que te dice si Snowgrave ejecuta o solo hace 40.
func _update_target_info() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_target_label.text = ""
		return
	var origin := _player.get_aim_origin()
	var dir := _player.get_aim_direction()
	var best: Player = null
	var best_dot := 0.985
	for node: Node in get_tree().get_nodes_in_group("players"):
		var other := node as Player
		if other == null or other == _player or not is_instance_valid(other):
			continue
		if other.health.is_dead:
			continue
		var to_other := (other.global_position + Vector3.UP - origin)
		if to_other.length() > 40.0:
			continue
		var d := to_other.normalized().dot(dir)
		if d > best_dot:
			best_dot = d
			best = other
	if best == null:
		_target_label.text = ""
		return
	if best.status.is_frozen():
		_target_label.text = "%s — CONGELADO (Snowgrave ejecuta)" % best.player_name
		_target_label.add_theme_color_override("font_color", UITheme.DANGER)
	elif best.status.is_stunned():
		# Aturdido NO es congelado: no lo ejecuta Snowgrave. Que quede claro en el HUD.
		_target_label.text = "%s — TIEMPO DETENIDO" % best.player_name
		_target_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	else:
		_target_label.text = "%s — escarcha %d/%d" % [best.player_name, best.status.chill_stacks, StatusEffects.MAX_CHILL]
		_target_label.add_theme_color_override("font_color", UITheme.ACCENT)


func _refresh_scoreboard() -> void:
	for child: Node in _scoreboard_rows.get_children():
		child.queue_free()
	var ids := Net.players.keys()
	ids.sort_custom(func(a: int, b: int) -> bool:
		return int(Net.players[a].get("kills", 0)) > int(Net.players[b].get("kills", 0))
	)
	for id: int in ids:
		var info: Dictionary = Net.players[id]
		var data := CharacterDB.get_character(StringName(String(info.get("character_id", "noelle"))))
		var text := "%-16s  %-18s  %d kills   %d muertes" % [
			String(info.get("name", "???")),
			data.display_name if data != null else "?",
			int(info.get("kills", 0)),
			int(info.get("deaths", 0)),
		]
		var color := UITheme.ACCENT if id == Net.local_id() else UITheme.TEXT
		_scoreboard_rows.add_child(UITheme.make_label(text, 15, color))


# ----------------------------------------------------------------------- Señales

func _on_health_changed(current: float, max_value: float) -> void:
	_health_fill.anchor_right = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	_health_label.text = "VIDA  %d / %d" % [int(ceil(current)), int(max_value)]
	if is_instance_valid(_player):
		_on_shield_changed(_player.health.shield)


## Con escudo, la barra entera pasa a representar VIDA + ESCUDO.
##
## El primer intento apoyaba el celeste sobre el tramo de vida y lo dejaba crecer hacia
## la derecha. Con la vida llena eso no dibujaba NADA: el verde ya ocupaba el 100% y al
## escudo no le quedaba barra, justo en el caso mas comun (te escudas antes de que te
## peguen). Reescalar hace que el verde encoja y el celeste aparezca; la barra sigue
## llena, que es la lectura correcta: estas al maximo efectivo.
## Medio segundo quieta antes de bajar: es lo que la hace ver.
func _on_player_damaged(_amount: float, _source_id: int) -> void:
	_chip_delay = 0.5


func _on_shield_changed(value: float) -> void:
	if _shield_fill == null or not is_instance_valid(_player):
		return
	var max_hp := _player.health.max_health
	if max_hp <= 0.0:
		return
	var hp := _player.health.current

	if value <= 0.0:
		_shield_fill.visible = false
		_health_fill.anchor_right = clampf(hp / max_hp, 0.0, 1.0)
		_health_label.text = "VIDA  %d / %d" % [int(ceil(hp)), int(max_hp)]
		return

	var total := max_hp + value
	var hp_ratio := clampf(hp / total, 0.0, 1.0)
	_health_fill.anchor_right = hp_ratio
	_shield_fill.visible = true
	_shield_fill.anchor_left = hp_ratio
	_shield_fill.anchor_right = clampf((hp + value) / total, 0.0, 1.0)
	_health_label.text = "VIDA  %d / %d   +%d ESCUDO" % [int(ceil(hp)), int(max_hp), int(ceil(value))]


func _on_stamina_changed(current: float, max_value: float) -> void:
	_stamina_fill.anchor_right = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	_stamina_label.text = "STAMINA  %d / %d" % [int(floor(current)), int(max_value)]


func _on_charge_changed(current: float, max_value: float) -> void:
	var ratio := clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	_charge_fill.anchor_right = ratio
	if ratio >= 0.999:
		_charge_label.text = "ULTIMATE  LISTO  [%s]" % Controles.nombre_tecla(&"ability_ultimate")
		_charge_label.add_theme_color_override("font_color", UITheme.GOLD)
	else:
		_charge_label.text = "ULTIMATE  %d%%  (se carga pegando)" % int(floor(ratio * 100.0))
		_charge_label.add_theme_color_override("font_color", UITheme.TEXT_DIM)


func _on_charge_ready() -> void:
	_center_label.text = "ULTIMATE LISTO"
	Sfx.play_2d(&"respawn", -4.0)
	_clear_center_label_soon()


func _on_ability_failed(_index: int, reason: String) -> void:
	if reason.contains("stamina") or reason.contains("carga"):
		_flash_time = 1.0
		Sfx.play_2d(&"no_stamina", -6.0)
	_center_label.text = "No podes: %s" % reason
	_clear_center_label_soon()


func _on_channel_started(index: int, _duration: float) -> void:
	var ability := _player.caster.get_ability(index)
	if ability != null:
		_channel_label.text = "Canalizando %s..." % ability.display_name


func _on_channel_ended(_index: int) -> void:
	_channel_box.visible = false


func _on_channel_cancelled(_index: int) -> void:
	_channel_box.visible = false
	_center_label.text = "Canalizacion interrumpida"
	_clear_center_label_soon()


func _on_local_died(killer_id: int) -> void:
	_respawn_left = GameConfig.RESPAWN_DELAY
	var killer := Net.get_player_name(killer_id)
	_center_label.text = "Te mato %s" % killer


func _on_local_respawned() -> void:
	_respawn_left = 0.0
	_center_label.text = ""


func _on_kill_registered(killer_id: int, victim_id: int) -> void:
	var text := "%s elimino a %s" % [Net.get_player_name(killer_id), Net.get_player_name(victim_id)]
	if killer_id == 0 or killer_id == victim_id:
		text = "%s se elimino solo" % Net.get_player_name(victim_id)
	var label := UITheme.make_label(text, 14, UITheme.TEXT)
	_kill_feed.add_child(label)
	var timer := get_tree().create_timer(6.0)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)


func show_match_result(text: String) -> void:
	_center_label.text = text


func _clear_center_label_soon() -> void:
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(func() -> void:
		if _respawn_left <= 0.0 and is_instance_valid(_center_label):
			_center_label.text = ""
	)
