extends Node
## Renderiza material LIMPIO para la pagina de itch.io.
##
## POR QUE NO SIRVEN LAS CAPTURAS DEL CHEQUEO VISUAL. Aquellas existen para revisar que
## el juego se vea bien MIENTRAS SE JUEGA, asi que tienen HUD encima, barras de vida,
## nombres flotando y numeros de daño. Todo eso, que es exactamente lo que uno quiere ver
## revisando, es basura en una portada: tapa el tercio de abajo y le grita al que pasa
## scrolleando cosas que no le interesan todavia.
##
## Esto arma tomas posadas: sin interfaz, con los tres personajes colocados a mano, luz
## del lado que conviene y camara puesta donde se ve la silueta.
##
##     godot --path . res://tests/render_promo.tscn -- build/promo
##
## Sale en 1920x1080 para que despues se pueda recortar a cualquier proporcion sin
## perder definicion: itch pide 630x500 para la portada, 21:9 para la ancha y cuadrado
## para el favicon, y de una sola toma grande salen las tres.
##
## No es un test: no verifica nada y no falla. Vive en tests/ porque es la carpeta que el
## exportador ya excluye del .zip.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _main: Node = null
var _dir: String = "build/promo"
var _tomadas: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = String(args[0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	# Grande: de aca se recorta todo lo demas.
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_window().content_scale_size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await get_tree().process_frame

	Net.start_solo("Promo")
	Net.start_match()
	for _i: int in range(10):
		await get_tree().process_frame

	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if arena == null or player == null:
		print("[promo] no se pudo armar la partida")
		get_tree().quit(1)
		return

	# Fuera todo lo que sea interfaz.
	_ocultar_interfaz()
	# Bots quietos: una pose se arma, no se caza.
	Arena.set_bots_active(false)
	Practica.set_bots_activos(false)
	await _wait(0.4)

	await _trio(arena, player)
	await _retrato(arena, player, &"flowery", "retrato_flowery")
	await _retrato(arena, player, &"noelle", "retrato_noelle")
	await _retrato(arena, player, &"dio", "retrato_dio")
	await _retrato(arena, player, &"rick", "retrato_rick")
	await _poses_de_embestida(arena, player)
	await _panoramica(arena)

	print("")
	print("%d tomas en %s/" % [_tomadas, _dir])
	get_tree().quit(0)


## Los tres, en fila, mirando a camara. Es LA toma: la que sirve de portada, de imagen
## social y de cover ancha, porque tiene a los tres personajes y se lee chiquita.
func _trio(arena: Arena, player: Player) -> void:
	# SOBRE LA PLATAFORMA CENTRAL, no en el piso.
	#
	# La primera version los puso en campo abierto a z=26 y la camara quedo detras de una
	# cobertura: en la toma solo asomaban tres cabezas por encima de una pared azul. En
	# un mapa lleno de bloques, "un punto despejado para el personaje" no garantiza nada
	# sobre la linea de vision de la camara, que es lo que importa en una foto.
	#
	# La plataforma resuelve las dos cosas de una: esta elevada —asi que la camara mira
	# por encima de todo el desorden— y tiene la torre iluminada justo atras, que es el
	# mejor fondo del mapa.
	# En el borde NORTE de la plataforma (que va de z=-10 a z=10).
	#
	# El lado importa por como mira un personaje en Godot: el frente de un nodo es su -Z,
	# asi que con yaw 0 miran hacia z negativo. Poniendolos en el borde norte, la camara
	# va todavia mas al norte y los agarra de frente, con la torre iluminada por detras
	# como fondo en vez de tapandoles la cara.
	var centro := Vector3(0.0, 2.25, -8.0)
	var bots := _bots(arena)

	# El jugador al medio y un poco adelante: es el que tiene que mirarse primero.
	# Yaw 0 = mirando hacia -Z, que es de donde filma la camara. Adelantado el del medio:
	# en fila perfecta los tres se leen como un catalogo, no como un grupo.
	player.setup_character(CharacterDB.get_character(&"flowery"))
	_plantar(player, centro + Vector3(0.0, 0.0, -1.1), 0.0)

	if bots.size() > 0:
		bots[0].setup_character(CharacterDB.get_character(&"noelle"))
		_plantar(bots[0], centro + Vector3(-2.7, 0.0, 0.5), 0.26)
	if bots.size() > 1:
		bots[1].setup_character(CharacterDB.get_character(&"dio"))
		_plantar(bots[1], centro + Vector3(2.7, 0.0, 0.5), -0.26)
	# El tercero, fuera de cuadro.
	if bots.size() > 2:
		_plantar(bots[2], Vector3(0.0, 0.0, 78.0), 0.0)

	await _wait(1.0)
	# Camara a la altura del pecho: filmar desde los ojos aplana, y desde abajo agranda
	# las siluetas, que es lo que hace que alguien se lea como protagonista.
	await _camara(Vector3(0.0, 3.50, -16.0), Vector3(0.0, 3.00, -8.0), 40.0, "trio")
	# Y una segunda mas cerrada, para la imagen social y para recortar el favicon.
	await _camara(Vector3(0.0, 3.55, -13.2), Vector3(0.0, 3.10, -8.2), 34.0, "trio_cerca")


## Un personaje solo, de cuerpo entero y de tres cuartos. Para la imagen social y para
## el favicon —de aca sale la cabeza recortada— y por si queres una portada por
## personaje mas adelante.
func _retrato(arena: Arena, player: Player, id: StringName, nombre: String) -> void:
	var punto := arena.find_clear_spot(Vector3(-18.0, 0.0, 12.0), 3.0)
	player.setup_character(CharacterDB.get_character(id))
	# De tres cuartos, no de frente: de frente un modelo de primitivas se ve plano.
	# Yaw 0 mira a +Z, que es donde esta la camara (ver el comentario en _trio).
	_plantar(player, punto, -0.5)
	for b: Player in _bots(arena):
		_plantar(b, punto + Vector3(0.0, 0.0, 80.0), 0.0)
	await _wait(0.7)
	# 3.9 metros: a 3.6 el personaje quedaba chico en un mar de piso y a 2.65 la camara
	# le cortaba la cabeza. Con fov 34 a esta distancia entra entero, pelo incluido, y
	# todavia sobra margen para recortar.
	await _camara(punto + Vector3(-1.55, 1.30, -3.90), punto + Vector3(0.0, 1.00, 0.0),
		34.0, nombre)
	# Y la cabeza sola, para el favicon: recortarla del cuerpo entero da un cuadrado
	# borroso, porque queda a un octavo del alto original.
	await _camara(punto + Vector3(-0.30, 1.79, -1.15), punto + Vector3(0.0, 1.74, 0.0),
		40.0, nombre + "_cabeza")


## Las dos poses de la embestida, forzadas.
##
## No se pueden cazar jugando: duran tres decimas y caen donde caigan. Forzandolas se
## ven las dos una al lado de la otra, que es la unica forma de juzgar si la de impacto
## es de verdad la opuesta a la de embestir —que es lo que la hace leerse como choque—.
func _poses_de_embestida(arena: Arena, player: Player) -> void:
	var punto := arena.find_clear_spot(Vector3(-18.0, 0.0, 12.0), 3.0)
	player.setup_character(CharacterDB.get_character(&"flowery"))
	_plantar(player, punto, -0.5)
	for b: Player in _bots(arena):
		_plantar(b, punto + Vector3(0.0, 0.0, 80.0), 0.0)

	# LA CAMARA PRIMERO Y EL DISPARO DESPUES.
	#
	# _camara() espera medio segundo a que la escena se asiente antes de capturar, y las
	# dos poses duran menos que eso: la de impacto son 0.29 segundos. Poniendo la camara
	# despues de provocar la pose, para cuando saca la foto ya se apago, y las dos
	# primeras capturas salieron con el personaje parado.
	var cam := Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.global_position = punto + Vector3(-2.2, 1.35, -4.2)
	cam.look_at(punto + Vector3(0.0, 1.05, 0.0), Vector3.UP)
	cam.make_current()
	await _wait(0.6)

	# EMBISTIENDO. Se lanza una carga con velocidad casi cero: lo que enciende la pose es
	# is_dashing(), no el desplazamiento, asi que el cuerpo se queda en cuadro y adopta
	# la pose igual. Con un dash de verdad se iba de la toma antes de la captura.
	player.launch_charge(-player.global_transform.basis.z, 0.01, 0.6)
	await _wait(0.18)
	await _shot("pose_embistiendo")
	player.stop_charge()

	await _wait(1.4)
	_plantar(player, punto, -0.5)
	await _wait(0.4)
	# IMPACTO: se avisa al visual, que es lo mismo que hace la habilidad.
	player.visual.golpe_de_embestida()
	await _wait(0.13)
	await _shot("pose_impacto")
	cam.queue_free()


## El mapa entero desde arriba, para la cover ancha 21:9.
func _panoramica(arena: Arena) -> void:
	# DERIVADA DEL TAMAÑO DEL MAPA. Estaba clavada para 92 metros y con 120 el mapa ya no
	# entraba en cuadro: la toma aerea existe para ver el conjunto, y recortada no sirve.
	var d := Arena.ARENA_SIZE
	await _camara(Vector3(0.0, d * 0.42, d * 0.72), Vector3(0.0, 2.0, -d * 0.05), 55.0, "panoramica")
	await _camara(Vector3(d * 0.40, d * 0.16, d * 0.40), Vector3(0.0, 3.0, 0.0), 58.0, "arena_de_costado")


# ------------------------------------------------------------------------ Piezas

func _camara(donde: Vector3, mirando: Vector3, fov: float, nombre: String) -> void:
	var cam := Camera3D.new()
	cam.fov = fov
	add_child(cam)
	cam.global_position = donde
	cam.look_at(mirando, Vector3.UP)
	cam.make_current()
	await _wait(0.5)
	await _shot(nombre)
	cam.queue_free()


func _plantar(p: Player, pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.rotation.y = yaw
	p.bot_look_yaw = yaw
	# Y EL PIVOTE DE CAMARA TAMBIEN, si es el jugador local.
	#
	# Sin esto, poner rotation.y en el jugador no sirve de nada: _handle_local_movement
	# la reescribe con el yaw del pivote en CADA frame de fisica. Estuve dos tomas
	# creyendo que el modelo miraba al reves cuando en realidad mi valor duraba un frame.
	if is_instance_valid(p.camera_pivot):
		p.camera_pivot.set_yaw(yaw)
	p.velocity = Vector3.ZERO
	p.health.revive_full()
	p.name_label.visible = false


func _bots(arena: Arena) -> Array[Player]:
	var out: Array[Player] = []
	for child: Node in arena.get_children():
		var p := child as Player
		if p != null and p.is_dummy:
			out.append(p)
	return out


## Fuera HUD, pausa y panel. Una portada con barras de vida encima se ve a aficionado.
func _ocultar_interfaz() -> void:
	for child: Node in _main.get_children():
		if child is CanvasLayer or child is Control:
			(child as Node).set("visible", false)
			if child.has_method("hide"):
				child.call("hide")


func _wait(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


func _shot(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var ruta := "%s/%s.png" % [_dir, nombre]
	if img.save_png(ProjectSettings.globalize_path(ruta)) == OK:
		print("   %-22s %dx%d" % [nombre, img.get_width(), img.get_height()])
		_tomadas += 1
	else:
		print("   %-22s FALLO" % nombre)
