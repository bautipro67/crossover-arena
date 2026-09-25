class_name Cinematica
extends Node
## Una escena del modo historia, hecha con el motor del juego: los personajes de verdad,
## en la arena de verdad, con camara propia.
##
## COMO LAS DE XENOVERSE, en lo que se puede sin modelos ni animaciones grabadas: la
## camara corta al que habla y se le acerca despacio, hay planos generales, de a dos y
## contrapicados; los personajes caminan, se dan vuelta, hacen gestos, aparecen y
## desaparecen, y tiran sus tecnicas —ZA WARUDO, el Kamehameha, un portal— con los mismos
## efectos que en la pelea. Barras negras de cine arriba y abajo, y el texto abajo.
##
## UNA ESCENA ES UNA LISTA DE PASOS, y cada paso es un arreglo que empieza con su tipo:
##
##   ["decir", quien, texto]            linea con subtitulo; la camara va al que habla
##   ["narrar", texto]                  linea sin personaje
##   ["plano", "general"]               todos los actores
##   ["plano", "cerca", quien]          primer plano
##   ["plano", "dos", a, b]             por encima del hombro de a, mirando a b
##   ["plano", "abajo", quien]          contrapicado: desde abajo, imponente
##   ["plano", "libre", desde, hacia]   posiciones relativas al ancla (Vector3)
##   ["colocar", quien, Vector2, grados]  lo pone ahi, sin caminar
##   ["mover", quien, Vector2]          camina hasta ahi
##   ["mirar", quien, otro]             se da vuelta hacia otro
##   ["pose", quien, pose, segundos]    un gesto (ver PlayerVisual.actuar)
##   ["grito", quien, texto, voz]       el cartel grande y la voz
##   ["habilidad", quien, id]           los efectos de una tecnica, sin daño
##   ["aparecer", quien, personaje, Vector2, efecto]   efecto: portal, teletransporte, caida, sombra
##   ["desaparecer", quien, efecto]
##   ["temblor", fuerza]  ["esperar", segundos]  ["fundido", "negro"/"claro", segundos]
##   ["titulo", texto, subtitulo]
##
## LAS POSICIONES SON RELATIVAS AL ANCLA, en (x, z): el mismo guion sirve en cualquier
## lugar del mapa, y cada punto se corre al hueco libre mas cercano para no dejar a nadie
## adentro de una cobertura.

signal terminada()

## Hay una escena corriendo. Lo leen el jugador (no se mueve con el teclado), la camara
## (el mouse no gira nada) y la mision (el reloj de la pelea se para).
static var activa: bool = false
## Para el arnes: las lineas pasan solas, sin esperar a nadie.
static var automatica: bool = false

var pasos: Array = []
## id -> Player. Los que pelean los pone la mision; los que solo actuan, "aparecer".
var actores: Dictionary = {}
var ancla: Vector3 = Vector3.ZERO
var arena: Arena = null
## El HUD, para esconderlo mientras dura la escena.
var hud: CanvasLayer = null

var _camara: Camera3D = null
var _cam_pos: Vector3 = Vector3.ZERO
var _cam_mira: Vector3 = Vector3.ZERO
## Cuanto se acerca sola la camara mientras dura el plano, por segundo.
var _cam_deriva: Vector3 = Vector3.ZERO
var _plano_elegido: bool = false
## El par de un plano "dos" en curso. Mientras hablen ellos, la camara va y viene por
## encima del hombro del que escucha: el plano y contraplano de cualquier dialogo.
var _dos: Array[StringName] = []
## El proximo frame la camara salta al plano nuevo en vez de deslizarse.
var _cortar: bool = false

var _ui: CanvasLayer = null
var _raiz: Control = null
var _barras: Array[ColorRect] = []
var _panel: Control = null
var _nombre: Label = null
var _texto: Label = null
var _titulo: Label = null
var _subtitulo: Label = null
var _fundido: ColorRect = null
var _esperando: bool = false
var _escrito: float = 0.0
var _salteada: bool = false
var _extras: Array[Node] = []
## Los carteles de nombre que habia prendidos, para devolverlos al terminar.
var _carteles: Array[Label3D] = []
var _cuantos_extras: int = 0
## La pose que tenia cada actor antes de la escena: Rick trabajando, alguien tirado. Se
## devuelve al terminar; lo que la escena les hizo hacer, no.
var _poses_previas: Dictionary = {}
## Las auras de potencia que se escondieron para la escena (ver _congelar_pelea).
var _auras: Array[Node3D] = []


# ------------------------------------------------------------------ Correr

## Reproduce la escena entera. Se la espera con await.
func reproducir() -> void:
	activa = true
	_armar_ui()
	_armar_camara()
	if is_instance_valid(hud):
		hud.visible = false
	Arena.set_bots_active(false)
	_congelar_pelea()
	# Sin carteles de nombre flotando: en una escena el nombre lo dice el subtitulo, y un
	# "Rick" verde encima de la cabeza la vuelve una captura de la partida.
	#
	# De TODOS los cuerpos de la arena, no solo de los que pelean: uno de reserva esta fuera
	# del grupo "players", y cuando una escena lo hacia aparecer se le prendia el cartel.
	for p: Node in arena.get_children():
		var jugador := p as Player
		if jugador != null and jugador.name_label.visible:
			jugador.name_label.visible = false
			_carteles.append(jugador.name_label)
	await _barras_de_cine(true)
	for paso: Array in pasos:
		if _salteada:
			break
		await _paso(paso)
	_panel.visible = false
	await _barras_de_cine(false)
	_terminar()


func _terminar() -> void:
	for id: StringName in actores:
		var actor := actores[id] as Player
		_frenar(actor)
		if is_instance_valid(actor):
			actor.visual.dejar_de_actuar()
			if _poses_previas.has(id):
				actor.visual.actuar(_poses_previas[id])
	for extra: Node in _extras:
		if is_instance_valid(extra):
			extra.queue_free()
	for aura: Node3D in _auras:
		if is_instance_valid(aura):
			aura.visible = true
	for cartel: Label3D in _carteles:
		if is_instance_valid(cartel):
			cartel.visible = true
	if is_instance_valid(_camara):
		_camara.queue_free()
	var jugador := arena.get_local_player() if is_instance_valid(arena) else null
	if jugador != null and is_instance_valid(jugador.camera_pivot):
		jugador.camera_pivot.camera.current = true
		FX.register_camera(jugador.camera_pivot.camera)
	if is_instance_valid(hud):
		hud.visible = true
	if is_instance_valid(_ui):
		_ui.queue_free()
	activa = false
	terminada.emit()


func _frenar(actor: Node) -> void:
	var p := actor as Player
	if p == null or not is_instance_valid(p):
		return
	p.guion_dir = Vector3.ZERO
	p.bot_move_dir = Vector3.ZERO
	p.bot_wants_run = false


## LA PELEA SE CONGELA mientras dura la escena.
##
## Una escena a mitad de pelea —DIO a media vida, Flowery que se enoja— arranca con todo
## lo que estaba pasando: cuchillos en el aire, Meeseeks buscando, alguien aturdido o a
## mitad de un dash, un Snowgrave cargando. Sin esto los cuchillos seguian pegando
## mientras se hablaba, el aturdido no podia darse vuelta para actuar, el empujado
## patinaba por la escena y el que cargaba soltaba el ultimate en medio del dialogo.
## Ademas, mientras hay escena nadie saca vida (ver CombatUtils.deal_damage).
func _congelar_pelea() -> void:
	for hijo: Node in arena.get_children():
		if hijo is Projectile:
			hijo.queue_free()
	for id: StringName in actores:
		var p := actores[id] as Player
		if p == null or not is_instance_valid(p):
			continue
		_frenar(p)
		p.velocity = Vector3(0.0, minf(p.velocity.y, 0.0), 0.0)
		p.stop_charge()
		p.status.clear_all(true)
		p.caster.cancel_channel()
		if p.visual._pose_guion != &"":
			_poses_previas[id] = p.visual._pose_guion
		# El aura de un potenciado es una capsula brillante que envuelve el cuerpo entero:
		# en un primer plano, a dos metros, no se ve a nadie adentro. Se esconde mientras
		# dura la escena y vuelve con la pelea.
		var aura := p.get_node_or_null(^"AuraSuper") as Node3D
		if aura != null and aura.visible:
			aura.visible = false
			_auras.append(aura)


func saltear() -> void:
	_salteada = true
	_esperando = false


# ------------------------------------------------------------------- Pasos

func _paso(p: Array) -> void:
	match String(p[0]):
		"decir":
			await _decir(StringName(p[1]), String(p[2]))
		"narrar":
			await _decir(&"", String(p[1]))
		"plano":
			_plano(p)
			_plano_elegido = true
		"colocar":
			_colocar(StringName(p[1]), p[2] as Vector2, float(p[3]) if p.size() > 3 else NAN)
		"mover":
			await _mover(StringName(p[1]), p[2] as Vector2)
		"mirar":
			_mirar(StringName(p[1]), StringName(p[2]))
		"pose":
			var a := _actor(StringName(p[1]))
			if a != null:
				a.visual.actuar(StringName(p[2]), float(p[3]) if p.size() > 3 else -1.0)
		"grito":
			var g := _actor(StringName(p[1]))
			if g != null:
				FX.spawn_grito(g, String(p[2]), Frases.color_de(g.character_id))
				if p.size() > 3:
					Sfx.play_3d(g, StringName(p[3]), g.global_position, 2.0)
			await _espera(0.9)
		"habilidad":
			await _habilidad(StringName(p[1]), StringName(p[2]))
		"aparecer":
			await _aparecer(StringName(p[1]), StringName(p[2]), p[3] as Vector2,
				String(p[4]) if p.size() > 4 else "")
		"desaparecer":
			await _desaparecer(StringName(p[1]), String(p[2]) if p.size() > 2 else "")
		"temblor":
			FX.camera_shake(float(p[1]))
		"esperar":
			await _espera(float(p[1]))
		"fundido":
			await _fundir(String(p[1]) == "negro", float(p[2]) if p.size() > 2 else 0.6)
		"titulo":
			await _mostrar_titulo(String(p[1]), String(p[2]) if p.size() > 2 else "")
		_:
			push_warning("[cinematica] paso desconocido: %s" % p[0])


func _actor(id: StringName) -> Player:
	var a: Node = actores.get(id)
	return a as Player if is_instance_valid(a) else null


func _donde(rel: Vector2) -> Vector3:
	var punto := ancla + Vector3(rel.x, 0.0, rel.y)
	if not is_instance_valid(arena):
		return punto
	return MisionHistoria.al_piso(arena, arena.find_clear_spot(punto, 0.8))


func _colocar(id: StringName, rel: Vector2, grados: float) -> void:
	var a := _actor(id)
	if a == null:
		return
	var punto := _donde(rel)
	a.global_position = punto + Vector3.UP * 0.1
	a.velocity = Vector3.ZERO
	if not is_nan(grados):
		_girar_a(a, deg_to_rad(grados))


func _girar_a(a: Player, yaw: float) -> void:
	a.rotation.y = yaw
	a.bot_look_yaw = yaw
	if a.is_local_player() and is_instance_valid(a.camera_pivot):
		a.camera_pivot.set_yaw(yaw)


func _mirar(id: StringName, otro: StringName) -> void:
	var a := _actor(id)
	var b := _actor(otro)
	if a == null or b == null:
		return
	var hacia := b.global_position - a.global_position
	if Vector2(hacia.x, hacia.z).length() > 0.05:
		_girar_a(a, atan2(-hacia.x, -hacia.z))


## Camina hasta el punto: el mismo cuerpo, la misma caminata que en la pelea.
func _mover(id: StringName, rel: Vector2) -> void:
	var a := _actor(id)
	if a == null:
		return
	var destino := _donde(rel)
	var tope := 4.0
	while tope > 0.0 and not _salteada:
		var hacia := destino - a.global_position
		hacia.y = 0.0
		if hacia.length() < 0.35:
			break
		var dir := hacia.normalized()
		_girar_a(a, atan2(-dir.x, -dir.z))
		if a.is_local_player():
			a.guion_dir = dir
		else:
			a.bot_move_dir = dir
		await get_tree().physics_frame
		tope -= get_physics_process_delta_time()
	_frenar(a)


func _habilidad(id: StringName, habilidad: StringName) -> void:
	var a := _actor(id)
	if a == null:
		return
	var origen := a.get_aim_origin()
	var dir := -a.global_transform.basis.z
	match habilidad:
		&"kamehameha":
			a.visual.actuar(&"kame", 1.0)
			a.visual._channel_fx_extra = FX.spawn_kame_carga(a.visual, 1.0)
			await _espera(1.0)
			if is_instance_valid(a.visual._channel_fx_extra):
				a.visual._channel_fx_extra.queue_free()
			a.visual.actuar(&"release", 0.8)
			FX.spawn_kamehameha(a, origen, dir, Kamehameha.largo_hasta_pared(a, origen, dir))
			FX.camera_shake(1.6)
		&"za_warudo":
			a.visual.actuar(&"channel_point", 1.0)
			await _espera(0.6)
			FX.spawn_time_stop(a, a.global_position, ZaWarudo.RADIUS)
			FX.camera_shake(1.2)
		_:
			a.visual.actuar(&"release", 0.6)
			FX.play_ability_cosmetic(a, habilidad, origen, dir)
	await _espera(0.6)


func _aparecer(id: StringName, personaje: StringName, rel: Vector2, efecto: String) -> void:
	var a := _actor(id)
	if a == null:
		a = _crear_extra(personaje)
		actores[id] = a
	var punto := _donde(rel)
	match efecto:
		"caida":
			# De bastante arriba: la caida es la entrada, y tiene que verse.
			a.global_position = punto + Vector3.UP * 14.0
			a.velocity = Vector3.DOWN * 4.0
			var t := 0.0
			while t < 2.5 and not a.is_on_floor():
				await get_tree().physics_frame
				t += get_physics_process_delta_time()
			FX.spawn_impact_burst(a, a.global_position + Vector3.UP * 0.2, Color(1.0, 0.9, 0.6, 1.0))
			FX.camera_shake(1.4)
			Sfx.play_3d(a, &"aterrizaje", a.global_position, 4.0)
		"portal":
			FX.spawn_portal(a, punto, Vector3.FORWARD, true)
			Sfx.play_3d(a, &"portal", punto, -2.0)
			await _espera(0.45)
			a.global_position = punto + Vector3.UP * 0.1
		"teletransporte":
			FX.spawn_teletransporte(a, punto)
			a.global_position = punto + Vector3.UP * 0.1
		"sombra":
			a.visual.volverse_eco()
			a.global_position = punto + Vector3.UP * 0.1
			FX.spawn_impact_burst(a, punto + Vector3.UP, Color(0.25, 0.15, 0.4, 0.9))
		_:
			a.global_position = punto + Vector3.UP * 0.1
	a.visible = true
	await _espera(0.3)


func _desaparecer(id: StringName, efecto: String) -> void:
	var a := _actor(id)
	if a == null:
		return
	match efecto:
		"portal":
			FX.spawn_portal(a, a.global_position, Vector3.FORWARD, false)
			Sfx.play_3d(a, &"portal", a.global_position, -2.0)
		"teletransporte":
			FX.spawn_teletransporte(a, a.global_position)
		_:
			FX.spawn_impact_burst(a, a.global_position + Vector3.UP, Color(0.25, 0.15, 0.4, 0.9))
	await _espera(0.35)
	a.visible = false


## Un actor que no pelea: aparece para la escena y se va con ella.
func _crear_extra(personaje: StringName) -> Player:
	var p: Player = Arena.PLAYER_SCENE.instantiate()
	_cuantos_extras += 1
	p.peer_id = -900 - _cuantos_extras
	p.is_dummy = true
	p.player_name = ""
	p.visible = false
	arena.add_child(p)
	p.setup_character(SkinDB.aplicar(CharacterDB.get_character(personaje), Progreso.skin_de(personaje)))
	p.name_label.visible = false
	p.global_position = ancla + Vector3.UP * 60.0
	_extras.append(p)
	return p


# ------------------------------------------------------------------- Camara

func _armar_camara() -> void:
	_camara = Camera3D.new()
	_camara.fov = 50.0
	arena.add_child(_camara)
	_cam_pos = ancla + Vector3(0.0, 4.0, 9.0)
	_cam_mira = ancla + Vector3.UP * 1.2
	_camara.global_position = _cam_pos
	_camara.look_at(_cam_mira, Vector3.UP)
	_camara.current = true
	_cortar = true
	FX.register_camera(_camara)


func _process(delta: float) -> void:
	if not is_instance_valid(_camara):
		return
	# ENTRE PLANOS, CORTE; DENTRO DE UN PLANO, DERIVA. Es como se filma un dialogo: la
	# camara salta de un personaje al otro y, ya en el plano, se sigue acercando sola,
	# despacio. La primera version deslizaba la camara de un plano al siguiente durante un
	# segundo, y cada linea empezaba con la camara todavia bajando del plano anterior,
	# mirando la coronilla del que hablaba.
	#
	# Y NUNCA ATRAVIESA UNA PARED: si hay algo entre el personaje y donde iria la camara, se
	# acerca hasta quedar del lado de adentro. Una escena filmada desde adentro de una
	# cobertura es una pantalla azul con subtitulos.
	_cam_pos += _cam_deriva * delta
	var destino := _sin_paredes(_cam_mira, _cam_pos)
	if _cortar:
		_camara.global_position = destino
		_cortar = false
	else:
		_camara.global_position = _camara.global_position.lerp(destino, minf(1.0, delta * 8.0))
	if _camara.global_position.distance_to(_cam_mira) > 0.1:
		_camara.look_at(_cam_mira, Vector3.UP)
	_actualizar_texto(delta)


func _sin_paredes(desde: Vector3, hasta: Vector3) -> Vector3:
	var mundo := _camara.get_world_3d()
	if mundo == null or mundo.direct_space_state == null:
		return hasta
	# El rayo arranca un poco despegado de lo que se mira: un plano que mira un punto del
	# piso (alguien tirado) arrancaba el rayo sobre el mismo piso, lo daba por pared y
	# dejaba la camara en el suelo.
	var hacia := hasta - desde
	if hacia.length() < 0.5:
		return hasta
	var inicio := desde + hacia.normalized() * 0.3
	var rayo := PhysicsRayQueryParameters3D.create(inicio, hasta)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	var golpe := mundo.direct_space_state.intersect_ray(rayo)
	if golpe.is_empty():
		return hasta
	var punto := golpe["position"] as Vector3
	return punto + (desde - punto).normalized() * 0.35


func _cabeza(a: Player) -> Vector3:
	return a.global_position + Vector3.UP * (1.55 * a.visual.build_scale.y)


func _plano(p: Array) -> void:
	var tipo := String(p[1])
	_cam_deriva = Vector3.ZERO
	_cortar = true
	_dos.clear()
	match tipo:
		"cerca":
			var a := _actor(StringName(p[2]))
			if a != null:
				_primer_plano(a)
		"dos":
			var a := _actor(StringName(p[2]))
			var b := _actor(StringName(p[3]))
			if a != null and b != null:
				_dos = [StringName(p[2]), StringName(p[3])]
				_sobre_el_hombro(a, b)
		"abajo":
			var a := _actor(StringName(p[2]))
			if a != null:
				_contrapicado(a)
		"libre":
			_cam_pos = ancla + (p[2] as Vector3)
			_cam_mira = ancla + (p[3] as Vector3)
			if p.size() > 4:
				_cam_deriva = p[4] as Vector3
		_:
			_plano_general()


## LA CAMARA BUSCA UN LUGAR DESDE DONDE SE VEA. Cada plano tiene su posicion ideal —de
## frente, sobre el hombro, desde abajo— pero el mapa esta lleno de coberturas, y un actor
## parado cerca de una quedaba tapado de la cintura para abajo, o la camara terminaba
## pegada a la pared mirando una nuca. Se prueban giros alrededor del personaje, del
## ideal hacia los costados, y gana el primero desde el que se le ven la cabeza y el pecho
## sin paredes ni otro personaje en el medio. Si ninguno sirve, queda el ideal y el rayo
## de _sin_paredes la acerca.
const GIROS: Array[float] = [0.0, 28.0, -28.0, 55.0, -55.0, 80.0, -80.0]


## De frente y un poco al costado, a la altura de la cara.
func _primer_plano(a: Player) -> void:
	var frente := _frente(a)
	var cabeza := _cabeza(a)
	_cam_mira = cabeza - Vector3.UP * 0.12
	var mejor := -1
	for giro: float in GIROS:
		var dir := frente.rotated(Vector3.UP, deg_to_rad(giro))
		var pos := cabeza + dir * 2.1 + dir.cross(Vector3.UP).normalized() * 0.55 + Vector3.UP * 0.05
		var nota := _nota(pos, a, [])
		if nota > mejor:
			mejor = nota
			_cam_pos = pos
			# Se acerca sola mientras habla: el "push in" de cualquier escena de dialogo.
			_cam_deriva = -dir * 0.10
		if nota == NOTA_LIMPIA:
			break
	_cortar = true


## Por encima del hombro de `a`, mirando a `b`. Si ese hombro tiene una pared atras, se
## prueba el otro, y despues mas cerca. Si ni asi se ve a `b`, primer plano de `b`: mejor
## perder el hombro que filmar una pared.
func _sobre_el_hombro(a: Player, b: Player) -> void:
	var hacia := b.global_position - a.global_position
	hacia.y = 0.0
	var dir := hacia.normalized() if hacia.length() > 0.05 else _frente(a)
	var lado := dir.cross(Vector3.UP).normalized()
	var mejor := -1
	for atras: float in [2.2, 1.5]:
		for signo: float in [1.0, -1.0]:
			var pos := _cabeza(a) - dir * atras + lado * 0.9 * signo + Vector3.UP * 0.25
			var nota := _nota(pos, b, [a])
			if nota > mejor:
				mejor = nota
				_cam_pos = pos
		if mejor == NOTA_LIMPIA:
			break
	if mejor < NOTA_SIN_PARED:
		_primer_plano(b)
		return
	_cam_mira = _cabeza(b) - Vector3.UP * 0.1
	_cam_deriva = dir * 0.15
	_cortar = true


## Desde abajo y de frente: el que habla se ve imponente.
func _contrapicado(a: Player) -> void:
	var frente := _frente(a)
	_cam_mira = _cabeza(a) + Vector3.UP * 0.2
	var mejor := -1
	for giro: float in GIROS:
		var dir := frente.rotated(Vector3.UP, deg_to_rad(giro))
		var pos := a.global_position + dir * 3.2 + Vector3.UP * 0.35
		var nota := _nota(pos, a, [])
		if nota > mejor:
			mejor = nota
			_cam_pos = pos
			_cam_deriva = -dir * 0.12
		if nota == NOTA_LIMPIA:
			break
	_cortar = true


## A todos los que estan en escena, desde el lado desde el que se vean mas.
##
## La distancia sale del campo visual: la primera version ponia la camara a una distancia
## fija del centro, y con alguien a nueve metros del resto ese quedaba fuera del cuadro.
func _plano_general() -> void:
	var visibles: Array[Player] = []
	for a: Node in actores.values():
		if is_instance_valid(a) and (a as Player).visible:
			visibles.append(a)
	if visibles.is_empty():
		_cam_pos = ancla + Vector3(0.0, 4.5, 10.0)
		_cam_mira = ancla + Vector3.UP
		return
	var centro := Vector3.ZERO
	for a: Player in visibles:
		centro += a.global_position
	centro /= float(visibles.size())
	var radio := 1.5
	for a: Player in visibles:
		var d := a.global_position - centro
		d.y = 0.0
		radio = maxf(radio, d.length())
	var tam := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(16, 9)
	var aspecto := tam.x / maxf(1.0, tam.y)
	var medio_ancho := atan(tan(deg_to_rad(_camara.fov) * 0.5) * aspecto)
	var dist := maxf(6.0, (radio + 1.2) / tan(medio_ancho) + radio)
	var alto := 2.2 + radio * 0.35
	_cam_mira = centro + Vector3.UP * 1.1
	# De frente al grupo, si mira para algun lado; si no, el angulo de siempre.
	var frente := Vector3.ZERO
	for a: Player in visibles:
		frente += _frente(a)
	var base := atan2(frente.x, frente.z) if frente.length() > 0.3 else atan2(0.6, 1.3)
	var mejor := -1
	for k: int in range(8):
		var ang := base + (float((k + 1) / 2) * (1.0 if k % 2 == 1 else -1.0)) * TAU / 8.0
		var pos := centro + Vector3(sin(ang), 0.0, cos(ang)) * dist + Vector3.UP * alto
		var vistos := 0
		for a: Player in visibles:
			if _nota(pos, a, []) >= NOTA_SIN_PARED:
				vistos += 1
		if not _hay_aire(pos):
			vistos -= 1
		if vistos > mejor:
			mejor = vistos
			_cam_pos = pos
		if vistos == visibles.size():
			break
	_cam_deriva = (_cam_mira - _cam_pos).cross(Vector3.UP).normalized() * 0.25


func _frente(a: Player) -> Vector3:
	var f := -a.global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


## Cuanto sirve filmar a `a` desde `desde`: 2 si ninguna pared le tapa la cabeza ni el
## pecho, 1 mas si ningun otro personaje se cruza, y 1 mas si la camara tiene aire
## alrededor. Los de `ignorar` no cuentan: en un plano sobre el hombro, el hombro tapa a
## proposito.
##
## ES UNA NOTA Y NO UN SI O NO porque a veces ningun angulo es perfecto, y ahi hay que
## quedarse con el menos malo. Con un si o no, si ninguno pasaba se volvia al ideal, que
## podia ser justo el que tenia a otro personaje parado delante.
const NOTA_LIMPIA: int = 4
const NOTA_SIN_PARED: int = 2


func _nota(desde: Vector3, a: Player, ignorar: Array) -> int:
	var espacio := _camara.get_world_3d().direct_space_state if is_instance_valid(_camara) else null
	var pared := false
	var cruzado := false
	for alto: float in [1.55, 1.0]:
		var punto := a.global_position + Vector3.UP * alto * a.visual.build_scale.y
		if espacio != null:
			var rayo := PhysicsRayQueryParameters3D.create(desde, punto)
			rayo.collision_mask = GameConfig.LAYER_WORLD
			if not espacio.intersect_ray(rayo).is_empty():
				pared = true
		var seg := punto - desde
		for otro: Node in actores.values():
			var o := otro as Player
			if o == null or not is_instance_valid(o) or o == a or not o.visible or ignorar.has(o):
				continue
			for alto_o: float in [1.0, 1.5]:
				var cuerpo := o.global_position + Vector3.UP * alto_o * o.visual.build_scale.y
				var t := clampf((cuerpo - desde).dot(seg) / maxf(0.001, seg.length_squared()), 0.0, 1.0)
				if t > 0.05 and t < 0.92 and (desde + seg * t).distance_to(cuerpo) < 0.4:
					cruzado = true
	return (0 if pared else 2) + (0 if cruzado else 1) + (1 if _hay_aire(desde) else 0)


## La camara no puede quedar pegada ni adentro de una cobertura.
func _hay_aire(pos: Vector3) -> bool:
	if not is_instance_valid(_camara):
		return true
	var espacio := _camara.get_world_3d().direct_space_state
	var forma := PhysicsShapeQueryParameters3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 0.45
	forma.shape = esfera
	forma.collision_mask = GameConfig.LAYER_WORLD
	forma.transform = Transform3D(Basis.IDENTITY, pos)
	return espacio.intersect_shape(forma, 1).is_empty()


# -------------------------------------------------------------- Texto e UI

func _armar_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 25
	add_child(_ui)
	_raiz = Control.new()
	UITheme.fill_viewport(_raiz)
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.gui_input.connect(_on_gui_input)
	_ui.add_child(_raiz)
	# Anotada como menu: los botones del dedo se esconden y el mando no mueve a nadie.
	Mando.anotar(_raiz)

	for arriba: bool in [true, false]:
		var barra := ColorRect.new()
		barra.color = Color.BLACK
		barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
		barra.set_anchors_preset(Control.PRESET_TOP_WIDE if arriba else Control.PRESET_BOTTOM_WIDE)
		barra.offset_bottom = 0.0 if arriba else 0.0
		barra.offset_top = 0.0
		barra.custom_minimum_size = Vector2(0, 0)
		_raiz.add_child(barra)
		_barras.append(barra)

	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 0)
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_fundido)

	_panel = VBoxContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 120.0
	_panel.offset_right = -120.0
	_panel.offset_top = -150.0
	_panel.offset_bottom = -18.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	_raiz.add_child(_panel)
	_nombre = UITheme.make_label("", 19, UITheme.GOLD)
	_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_nombre)
	_texto = UITheme.make_label("", 21, UITheme.TEXT)
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.add_theme_constant_override("outline_size", 6)
	_texto.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texto)

	var centro := VBoxContainer.new()
	centro.set_anchors_preset(Control.PRESET_CENTER)
	centro.offset_left = -500.0
	centro.offset_right = 500.0
	centro.offset_top = -70.0
	centro.offset_bottom = 70.0
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(centro)
	_titulo = UITheme.make_label("", 46, UITheme.GOLD)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.add_theme_constant_override("outline_size", 10)
	_titulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_titulo.modulate.a = 0.0
	_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_titulo)
	_subtitulo = UITheme.make_label("", 24, UITheme.TEXT)
	_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitulo.add_theme_constant_override("outline_size", 8)
	_subtitulo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_subtitulo.modulate.a = 0.0
	_subtitulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.add_child(_subtitulo)

	var saltar := UITheme.make_button("SALTAR ▶▶")
	saltar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	saltar.offset_left = -190.0
	saltar.offset_right = -20.0
	saltar.offset_top = 16.0
	saltar.offset_bottom = 58.0
	saltar.focus_mode = Control.FOCUS_NONE
	saltar.pressed.connect(saltear)
	saltar.set_meta(Mando.META_VOLVER, true)
	_raiz.add_child(saltar)


func _barras_de_cine(entrar: bool) -> void:
	var alto := 86.0 if entrar else 0.0
	for i: int in range(_barras.size()):
		var barra := _barras[i]
		var tw := barra.create_tween()
		if i == 0:
			tw.tween_property(barra, "offset_bottom", alto, 0.35)
		else:
			tw.tween_property(barra, "offset_top", -alto, 0.35)
	await _espera(0.35)


func _decir(quien: StringName, texto: String) -> void:
	var a := _actor(quien) if quien != &"" else null
	if a != null and _dos.has(quien) and not _plano_elegido:
		# PLANO Y CONTRAPLANO. Con un "dos" en curso, cada linea de uno de los dos corta a
		# por encima del hombro del OTRO: el que habla queda de frente y el que escucha, de
		# espaldas en primer termino. Antes el plano quedaba fijo sobre el hombro del
		# primero, y cuando le tocaba hablar a el se le veia la nuca.
		var otro := _actor(_dos[1] if _dos[0] == quien else _dos[0])
		if otro != null:
			var par := _dos.duplicate()
			_sobre_el_hombro(otro, a)
			_dos = par
	elif a != null and _plano_elegido and _dos.size() == 2 and _dos[0] == quien:
		# El guion pidio "dos" sobre el hombro del que habla: se da vuelta el plano.
		var otro := _actor(_dos[1])
		if otro != null:
			var par := _dos.duplicate()
			_sobre_el_hombro(otro, a)
			_dos = par
	elif a != null and not _plano_elegido:
		_dos.clear()
		_primer_plano(a)
	_plano_elegido = false
	_panel.visible = true
	_nombre.visible = quien != &""
	if quien != &"":
		# El nombre sale del PERSONAJE del actor, no de su id: un actor de escena se puede
		# llamar "rick_" para no chocar con otro, y el cartel tiene que decir Rick.
		var cid := a.character_id if a != null else quien
		_nombre.text = Historia.nombre_de(cid).to_upper()
		_nombre.add_theme_color_override("font_color", Frases.color_de(cid))
	_texto.text = texto
	_texto.add_theme_color_override("font_color",
		UITheme.TEXT if quien != &"" else UITheme.TEXT_DIM.lightened(0.25))
	_texto.visible_characters = 0
	_escrito = 0.0
	_esperando = true
	if automatica:
		_texto.visible_characters = -1
		await get_tree().process_frame
		_esperando = false
	while _esperando and not _salteada:
		await get_tree().process_frame


func _actualizar_texto(delta: float) -> void:
	if _texto == null or _texto.visible_characters < 0:
		return
	_escrito += delta * 55.0
	var total := _texto.get_total_character_count()
	_texto.visible_characters = mini(int(_escrito), total)
	if _texto.visible_characters >= total:
		_texto.visible_characters = -1


func _avanzar() -> void:
	if not _esperando:
		return
	if _texto.visible_characters >= 0:
		_texto.visible_characters = -1
		return
	_esperando = false


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_avanzar()


func _input(event: InputEvent) -> void:
	if not activa:
		return
	if event.is_action_pressed(&"pausa") or (event is InputEventKey and event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		saltear()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"attack_basic"):
		get_viewport().set_input_as_handled()
		_avanzar()


func _mostrar_titulo(texto: String, sub: String) -> void:
	_titulo.text = texto
	_subtitulo.text = sub
	for l: Label in [_titulo, _subtitulo]:
		var tw := l.create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 0.45)
		tw.tween_interval(1.6 if not automatica else 0.05)
		tw.tween_property(l, "modulate:a", 0.0, 0.45)
	await _espera(2.5)


func _fundir(a_negro: bool, t: float) -> void:
	var tw := _fundido.create_tween()
	tw.tween_property(_fundido, "color:a", 1.0 if a_negro else 0.0, t)
	await _espera(t)


func _espera(t: float) -> void:
	if _salteada:
		return
	await get_tree().create_timer(t if not automatica else minf(t, 0.05)).timeout
