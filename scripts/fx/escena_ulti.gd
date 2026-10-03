class_name EscenaUlti
extends Node3D
## LA ESCENA DE LA DEFINITIVA, SOLO PARA EL QUE LA TIRA.
##
## Saitama y Sukuna tienen una escena propia mientras cargan la definitiva: la camara se
## va de atras del hombro a un primer plano, aparecen las barras de cine y el nombre de la
## tecnica, y al soltar se ve el golpe desde lejos antes de volver a la camara de siempre.
##
## LA VE SOLO EL QUE LA TIRA (Player.is_local_player): es SU pantalla la que cambia. Los
## demas no pierden el control de su camara en medio de una pelea; ven lo mismo que pasa
## en el mundo —el templo que sube, el viento alrededor del puño, la onda— desde donde
## estan parados. Eso lo arma PlayerVisual._on_channel_started para todos.
##
## NO CAMBIA NADA DEL JUEGO. La carga dura lo mismo, se puede cortar igual (un aturdido
## la cancela y la escena se cierra), y la punteria sigue siendo la del mouse: el plano
## sobre el hombro mira hacia donde estas apuntando, para que sepas a donde va a salir.

## Cada definitiva con escena: lo que dice antes, el nombre, el color y cuanto se queda
## mirando despues de soltar.
const ESCENAS: Dictionary = {
	&"golpe_serio": {"previo": "SERIE SERIA", "titulo": "GOLPE SERIO",
		"color": Color(1.0, 0.86, 0.22), "despues": 0.75},
	&"santuario": {"previo": "EXPANSIÓN DE DOMINIO", "titulo": "SANTUARIO MALÉVOLO",
		"color": Color(1.0, 0.18, 0.22), "despues": 1.0},
}
## Lo que tarda en volver a la camara del jugador, al final.
const VUELTA: float = 0.3
## Hasta donde llegan las barras, en fraccion del alto de la pantalla.
const BARRA: float = 0.11

## La que esta corriendo, si hay. Una a la vez.
static var actual: EscenaUlti = null

var jugador: Player = null
var habilidad: StringName = &""
var _carga: float = 1.3
var _t: float = 0.0
var _soltada: bool = false
var _t_soltada: float = 0.0
var _cerrando: bool = false
## Desde donde vuelve la camara al final (el ultimo plano).
var _desde_vuelta: Transform3D = Transform3D.IDENTITY
var _camara: Camera3D = null
var _ui: CanvasLayer = null
var _barras: Array[ColorRect] = []
var _previo: Label = null
var _titulo: Label = null
var _destello: ColorRect = null
var _escondidos: Array[CanvasLayer] = []


static func tiene(id: StringName) -> bool:
	return ESCENAS.has(id)


## Arranca la escena si corresponde: definitiva con escena, jugador LOCAL y sin una escena
## de la historia en curso.
static func empezar(quien: Player, id: StringName, carga: float) -> void:
	if not ESCENAS.has(id) or not is_instance_valid(quien) or not quien.is_local_player():
		return
	if Cinematica.activa or not quien.is_inside_tree():
		return
	if is_instance_valid(actual):
		actual._cerrar()
	var arena := quien.get_parent()
	if arena == null:
		return
	var escena := EscenaUlti.new()
	escena.name = &"EscenaUlti"
	escena.jugador = quien
	escena.habilidad = id
	escena._carga = maxf(0.2, carga)
	arena.add_child(escena)
	actual = escena


func _ready() -> void:
	_camara = Camera3D.new()
	_camara.fov = 55.0
	add_child(_camara)
	var plano := _plano()
	_camara.global_transform = plano
	_camara.current = true
	FX.register_camera(_camara)
	_armar_ui()
	if is_instance_valid(jugador) and jugador.caster != null:
		jugador.caster.channel_finished.connect(_on_soltada)
		jugador.caster.channel_cancelled.connect(_on_cortada)
	# El HUD se esconde: la escena es la pantalla entera. Vuelve al cerrar.
	for nodo: Node in get_tree().get_nodes_in_group(&"hud"):
		var item := nodo as CanvasLayer
		if item != null and item.visible:
			item.visible = false
			_escondidos.append(item)


func _exit_tree() -> void:
	if actual == self:
		actual = null


func _process(delta: float) -> void:
	# Una escena de la historia manda: esta se va sin tocar la camara, que ya es de ella.
	if Cinematica.activa:
		_cerrar(false)
		return
	if not is_instance_valid(jugador) or jugador.health.is_dead:
		_cerrar()
		return
	_t += delta
	if _soltada:
		_t_soltada += delta
	var despues := float(ESCENAS[habilidad]["despues"])
	if _cerrando or (_soltada and _t_soltada >= despues):
		_volver(delta)
		return
	var destino := _plano()
	_camara.global_transform = _camara.global_transform.interpolate_with(destino, minf(1.0, delta * 9.0))
	_actualizar_ui()


# ------------------------------------------------------------------ Planos

## El plano que toca ahora. u va de 0 a 1 durante la carga; despues de soltar, el plano
## de lejos.
func _plano() -> Transform3D:
	var c := jugador.global_position
	var frente := -jugador.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized() if not frente.is_zero_approx() else Vector3.FORWARD
	var mira_jug := jugador.get_aim_direction()
	var apunta := Vector3(mira_jug.x, 0.0, mira_jug.z)
	apunta = apunta.normalized() if not apunta.is_zero_approx() else frente
	var derecha := frente.cross(Vector3.UP).normalized()
	var alto := 1.0
	if jugador.visual != null:
		alto = jugador.visual.build_scale.y
	var u := clampf(_t / _carga, 0.0, 1.0)
	var pos := Vector3.ZERO
	var mira := Vector3.ZERO
	match habilidad:
		&"golpe_serio":
			if _soltada:
				# De costado y lejos: la onda cruzando la pantalla de punta a punta.
				var der_ap := apunta.cross(Vector3.UP).normalized()
				pos = c - der_ap * 7.0 + Vector3.UP * 2.6 + apunta * (3.0 + _t_soltada * 2.0)
				mira = c + apunta * 11.0 + Vector3.UP * 1.0
			elif u < 0.42:
				# LA CARA SERIA: primer plano de frente, acercandose.
				var cabeza := c + Vector3.UP * (1.62 * alto)
				pos = cabeza + frente * (1.25 - u * 0.6) + derecha * 0.3 - Vector3.UP * 0.08
				mira = cabeza
			else:
				# SOBRE EL HOMBRO, bajo, mirando hacia donde va a salir.
				var der_ap := apunta.cross(Vector3.UP).normalized()
				var k := (u - 0.42) / 0.58
				pos = c - apunta * (3.3 - k * 0.5) + der_ap * 1.2 + Vector3.UP * (1.15 + k * 0.15)
				mira = c + apunta * 14.0 + Vector3.UP * 1.3
		&"santuario":
			if _soltada:
				# Desde arriba, girando: el circulo entero y el templo.
				var giro := frente.rotated(Vector3.UP, _t_soltada * 0.6)
				pos = c + giro * 11.0 + Vector3.UP * 13.0
				mira = c - frente * 1.5
			elif u < 0.38:
				# LAS MANOS EN EL SELLO, con la cara: de frente y un poco de arriba.
				var pecho := c + Vector3.UP * (1.40 * alto)
				pos = pecho + frente * (2.2 - u * 0.6) + Vector3.UP * 0.25 - derecha * 0.35
				mira = pecho
			else:
				# CONTRAPICADO: desde el piso, con el templo subiendo detras.
				var k := (u - 0.38) / 0.62
				pos = c + frente * (6.8 - k * 1.2) + derecha * (1.8 - k * 3.0) + Vector3.UP * 0.45
				mira = c + Vector3.UP * (2.6 + k * 1.2) - frente * 2.0
		_:
			pos = c + Vector3.UP * 3.0 + frente * 5.0
			mira = c + Vector3.UP
	pos = _sin_paredes(mira, pos)
	return Transform3D(Basis.looking_at(mira - pos, Vector3.UP), pos)


## NUNCA ADENTRO DE UNA PARED (ver Cinematica._sin_paredes): si hay algo entre lo que se
## mira y la camara, la camara se acerca hasta quedar del lado de adentro.
func _sin_paredes(desde: Vector3, hasta: Vector3) -> Vector3:
	var mundo := get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return hasta
	var hacia := hasta - desde
	if hacia.length() < 0.5:
		return hasta
	var rayo := PhysicsRayQueryParameters3D.create(desde + hacia.normalized() * 0.3, hasta)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	var golpe := mundo.direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return hasta
	var punto := golpe["position"] as Vector3
	return punto + (desde - punto).normalized() * 0.35


## LA VUELTA: del ultimo plano a la camara del jugador, sin corte. Corta de golpe se
## pierde donde estaba cada uno; deslizada se entiende.
func _volver(delta: float) -> void:
	if not _cerrando:
		_cerrando = true
		_t = 0.0
		_desde_vuelta = _camara.global_transform
		_mostrar_barras(false)
	else:
		_t += delta
	var propia := _camara_jugador()
	if propia == null:
		_cerrar()
		return
	var k := clampf(_t / VUELTA, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_camara.global_transform = _desde_vuelta.interpolate_with(propia.global_transform, k)
	_camara.fov = lerpf(55.0, propia.fov, k)
	if k >= 1.0:
		_cerrar()


func _camara_jugador() -> Camera3D:
	if not is_instance_valid(jugador) or not is_instance_valid(jugador.camera_pivot):
		return null
	return jugador.camera_pivot.camera


func _on_soltada(_index: int) -> void:
	if _soltada or _cerrando:
		return
	_soltada = true
	_t_soltada = 0.0
	if is_instance_valid(_destello):
		var tw := _destello.create_tween()
		tw.tween_property(_destello, "color:a", 0.0, 0.35).from(0.75)


func _on_cortada(_index: int) -> void:
	# Lo cortaron: vuelve ya, sin el plano de despues.
	if not _cerrando:
		_volver(0.0)


## Cierra la escena. `devolver` = false cuando la camara ya es de otro (una escena de la
## historia que arranco encima).
func _cerrar(devolver: bool = true) -> void:
	if is_instance_valid(jugador) and jugador.caster != null:
		if jugador.caster.channel_finished.is_connected(_on_soltada):
			jugador.caster.channel_finished.disconnect(_on_soltada)
		if jugador.caster.channel_cancelled.is_connected(_on_cortada):
			jugador.caster.channel_cancelled.disconnect(_on_cortada)
	if devolver:
		var propia := _camara_jugador()
		if propia != null:
			propia.current = true
			FX.register_camera(propia)
	for nodo: CanvasLayer in _escondidos:
		if is_instance_valid(nodo) and not Cinematica.activa:
			nodo.visible = true
	_escondidos.clear()
	if is_instance_valid(_ui):
		_ui.queue_free()
	if actual == self:
		actual = null
	set_process(false)
	queue_free()


# ---------------------------------------------------------------------- UI

func _armar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 24
	add_child(_ui)
	var raiz := Control.new()
	UITheme.fill_viewport(raiz)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(raiz)
	var datos: Dictionary = ESCENAS[habilidad]
	var color := datos["color"] as Color

	_destello = ColorRect.new()
	_destello.color = Color(1.0, 1.0, 1.0, 0.0)
	_destello.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_destello.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(_destello)

	for arriba: bool in [true, false]:
		var barra := ColorRect.new()
		barra.color = Color.BLACK
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
		barra.anchor_bottom = 0.0 if arriba else 1.0
		barra.anchor_top = 0.0 if arriba else 1.0
		raiz.add_child(barra)
		_barras.append(barra)
	_mostrar_barras(true)

	_previo = UITheme.make_label(String(datos["previo"]), 22, Color(0.95, 0.95, 0.95))
	_previo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_previo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_previo.add_theme_constant_override("outline_size", 8)
	_previo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_previo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_previo.offset_left = -500.0
	_previo.offset_right = 500.0
	_previo.offset_top = -190.0
	_previo.offset_bottom = -160.0
	_previo.modulate.a = 0.0
	raiz.add_child(_previo)

	_titulo = UITheme.make_label(String(datos["titulo"]), 54, color)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_titulo.add_theme_constant_override("outline_size", 12)
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_titulo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_titulo.offset_left = -600.0
	_titulo.offset_right = 600.0
	_titulo.offset_top = -165.0
	_titulo.offset_bottom = -95.0
	_titulo.pivot_offset = Vector2(600.0, 35.0)
	_titulo.modulate.a = 0.0
	raiz.add_child(_titulo)


func _mostrar_barras(si: bool) -> void:
	var alto := get_viewport().get_visible_rect().size.y * BARRA if get_viewport() != null else 80.0
	for k: int in range(_barras.size()):
		var barra := _barras[k]
		if not is_instance_valid(barra):
			continue
		var arriba := k == 0
		var tw := barra.create_tween()
		if arriba:
			tw.tween_property(barra, "offset_bottom", alto if si else 0.0, 0.22).set_trans(Tween.TRANS_CUBIC)
		else:
			tw.tween_property(barra, "offset_top", -alto if si else 0.0, 0.22).set_trans(Tween.TRANS_CUBIC)


## El nombre: primero lo que dice al empezar, y en el cambio de plano el nombre grande.
func _actualizar_ui() -> void:
	var u := clampf(_t / _carga, 0.0, 1.0)
	var corte := 0.42 if habilidad == &"golpe_serio" else 0.38
	if is_instance_valid(_previo):
		_previo.modulate.a = clampf(_t / 0.2, 0.0, 1.0)
	if is_instance_valid(_titulo) and (u >= corte or _soltada):
		if _titulo.modulate.a <= 0.0:
			var tw := _titulo.create_tween().set_parallel()
			tw.tween_property(_titulo, "modulate:a", 1.0, 0.12)
			tw.tween_property(_titulo, "scale", Vector2.ONE, 0.25).from(Vector2.ONE * 1.6) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			FX.camera_shake(0.6)
