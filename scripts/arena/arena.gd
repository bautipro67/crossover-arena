class_name Arena
extends Node3D
## Arena PvP. Todo el escenario se genera por codigo.
##
## CRITERIO DE DISEÑO DEL MAPA:
##   (a) una plataforma central elevada con rampas, para que pelear no sea siempre en
##       el mismo plano;
##   (b) una torre arriba de ella que corta el duelo a traves del mapa;
##   (c) coberturas de flanco de alturas distintas;
##   (d) pilares sueltos que rompen las lineas rectas.
##
## Sin todo eso, Snowgrave con su cono de 18m y ZA WARUDO con sus 20m no tendrian
## contrajuego: el que apretaba primero ganaba.
##
## RED: el servidor spawnea, mata y respawnea. Los clientes solo reflejan lo que les
## llega. Un cliente que entra a mitad de partida avisa que esta listo y recien ahi el
## servidor le manda todos los jugadores que ya estaban.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

## 92 x 92. Crecio desde 60 para que las habilidades de largo alcance (el cono de 20m
## de Snowgrave, los 20m de ZA WARUDO) no cubran media arena y se pueda reposicionar
## de verdad.
##
## OJO: agrandar el mapa SIN agregar cobertura lo empeora. Un descampado grande deja
## al que tiene rango pegando gratis desde lejos y al de cuerpo a cuerpo cruzando
## veinte metros al descubierto. Por eso el mapa crecio ~50% y las coberturas pasaron
## de 8 a 18: la densidad quedo mas alta que antes, no mas baja.
## Grupo con toda la geometria solida. El navmesh se hornea a partir de el.
const NAV_GROUP: StringName = &"arena_solida"
## Escalon que el navmesh da por subible.
##
## TIENE QUE SER MENOR QUE Player.STEP_HEIGHT, y por al menos una celda (0.25). No es
## un detalle de ajuste, es la invariante que mantiene honesto al navegador:
##
##     lo que el navmesh PROMETE  <  lo que el cuerpo PUEDE
##
## Recast cuantiza las alturas a celdas, asi que un desnivel real de 0.6 lo puede ver
## como 0.5 y darlo por subible. Si el cuerpo sube exactamente lo mismo que el navmesh
## promete, ese redondeo alcanza para que el camino pase por un labio que el cuerpo no
## puede trepar, y el bot se clava ahi hasta el final de la partida. Con el margen de
## una celda, el error de redondeo cae del lado seguro.
##
## Lo probe primero al reves —igualar los dos en 0.5— y el bot trabado no desaparecio:
## se mudo del costado de una rampa al de la otra, donde el labio mide 0.6.
const NAV_MAX_CLIMB: float = 0.25

const ARENA_SIZE: float = 92.0
const WALL_HEIGHT: float = 12.0

## Bots del modo practica. Ya no son maniquies quietos: usan personajes reales y te
## devuelven los golpes (ver BotBrain).
##
## La vida bajo de 250 a 170. Con 250 y bots que no pegaban, el numero grande servia
## para ensayar combos largos sin que se murieran; ahora que se defienden, 250 haria
## que cada pelea fuera una eternidad. 170 alcanza para practicar el combo completo
## (apilar escarcha -> congelar -> Snowgrave) y deja que matarlos se sienta como un
## logro y no como un tramite.
const DUMMY_COUNT: int = 3
const DUMMY_HEALTH: float = 170.0
const DUMMY_RESPAWN_DELAY: float = 4.0

signal player_spawned(player: Player)
signal local_player_spawned(player: Player)

var _spawn_points: Array[Transform3D] = []
var _players: Dictionary = {}
## Donde reaparece cada bot cuando lo matas.
var _dummy_spawns: Dictionary = {}

var _floor_material: StandardMaterial3D = null
var _floor_alt_material: StandardMaterial3D = null
var _wall_material: StandardMaterial3D = null
var _cover_material: StandardMaterial3D = null
var _cover_top_material: StandardMaterial3D = null
var _trim_material: StandardMaterial3D = null
var _pillar_material: StandardMaterial3D = null
var _cover_warm_material: StandardMaterial3D = null
var _cover_cool_material: StandardMaterial3D = null
var _marking_material: StandardMaterial3D = null


func _ready() -> void:
	_make_materials()
	_build_environment()
	_build_floor()
	_build_walls()
	_build_cover()
	_build_spawn_points()
	_build_navigation()

	if Net.is_server():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		# El servidor dedicado NO juega: no se spawnea a si mismo. Los clientes se
		# spawnean solos cuando avisan que tienen la arena lista.
		if not Net.dedicated:
			var t := get_free_spawn_point()
			var char_id := String(Net.get_player_info(Net.local_id()).get("character_id", "noelle"))
			_create_player(Net.local_id(), char_id, t.origin, t.basis.get_euler().y)
		if Net.solo_mode:
			_spawn_dummies()
			# El panel puede pedir otra cantidad en cualquier momento.
			Practica.bots_a_rehacer.connect(_on_bots_a_rehacer)
	else:
		# Avisamos al servidor que ya tenemos la arena armada y podemos recibir spawns.
		_srv_client_ready.rpc_id(1)


# ------------------------------------------------------------ Construccion del mapa

func _make_materials() -> void:
	_floor_material = Art.toon(Art.FLOOR_DARK, 0.0)
	_floor_alt_material = Art.toon(Art.FLOOR_LIGHT, 0.0)
	_wall_material = Art.toon(Art.WALL, 0.03)
	_cover_material = Art.toon(Art.COVER, 0.03)
	_cover_top_material = Art.toon(Art.COVER_TOP, 0.03)
	_trim_material = Art.glow(Art.TRIM, 1.8)
	# Los pilares NO pueden usar el material de pared: con el cielo nuevo, mas claro,
	# ese azul casi negro los convertia en siluetas planas recortadas contra el fondo.
	_pillar_material = Art.toon(Color(0.20, 0.25, 0.39), 0.03)
	# Dos tintes de cobertura, uno por diagonal del mapa.
	#
	# Primero intente hacerlo con luces de color y NO funciono: el sol ya deja las
	# superficies casi blancas y el toon shading cuantiza, asi que el dorado de una
	# omni de energia 8 se perdia en el blanco. Teñir el material se ve siempre, a
	# cualquier distancia y en cualquier renderer, y no cuesta un solo frame.
	_cover_warm_material = Art.toon(Color(0.46, 0.38, 0.30), 0.03)
	_cover_cool_material = Art.toon(Color(0.26, 0.36, 0.58), 0.03)
	# Las marcas del piso van mucho mas apagadas que los trims verticales. Con la
	# emision de 1.8 se quemaban en una mancha blanca que tapaba media pantalla.
	_marking_material = Art.glow(Art.TRIM, 0.55)


func _build_environment() -> void:
	var env := Environment.new()
	# Cielo de atardecer frio. El horizonte tira a violeta y el cenit a azul profundo:
	# el degrade da una direccion de luz clara y hace que el mapa no se lea plano.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.04, 0.06, 0.18)
	sky_material.sky_horizon_color = Color(0.55, 0.47, 0.72)
	sky_material.sky_curve = 0.09
	sky_material.sky_energy_multiplier = 1.15
	sky_material.ground_bottom_color = Color(0.03, 0.04, 0.09)
	sky_material.ground_horizon_color = Color(0.30, 0.30, 0.46)
	# Sol visible, alineado con la luz direccional de abajo. Tener de donde viene la luz
	# es la diferencia entre un escenario y una caja iluminada.
	sky_material.sun_angle_max = 8.0
	sky_material.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Bajo a proposito. Con 0.55 la luz del cielo tapaba las luces de color del mapa y
	# los 92 metros se veian de un solo azul plano de punta a punta.
	env.ambient_light_energy = 0.34

	# Niebla fria: da profundidad y separa las capas del mapa.
	env.fog_enabled = true
	env.fog_light_color = Color(0.46, 0.50, 0.78)
	# Mas fina que antes (0.010): el mapa ahora mide 92 metros y con la densidad vieja
	# el borde opuesto quedaba lavado y no se veia venir a nadie.
	env.fog_density = 0.0038
	env.fog_sky_affect = 0.25
	env.fog_aerial_perspective = 0.35

	# Glow: es lo que hace que los trims y los proyectiles se sientan luminosos en vez
	# de ser simplemente celestes.
	env.glow_enabled = true
	# Medido en capturas: con 0.55/0.22 las rampas y las marcas del piso se fundian en
	# una mancha blanca que tapaba un cuarto de la pantalla.
	env.glow_intensity = 0.46
	env.glow_bloom = 0.14
	# Umbral alto: que brillen SOLO las cosas emisivas de verdad. Mas bajo, el dorado
	# de Dio y los trims se queman y se pierde el detalle.
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# FX lo necesita para gradear la imagen (por ejemplo, desaturar en ZA WARUDO).
	FX.register_environment(env)

	# Sol principal, con sombras que acompañan el cel-shading.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.96, 0.88)
	# Energia moderada: con cel-shading y colores saturados, mas luz no ilumina,
	# quema. El dorado de Dio se convertia en una mancha blanca.
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	add_child(sun)

	# Relleno azulado desde el lado opuesto. Sin esto las caras en sombra quedan negras
	# y los personajes se pierden contra el piso.
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.62, 1.0)
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-28.0, -145.0, 0.0)
	add_child(fill)

	_build_accent_lights()


## Luces de color en el mapa.
##
## POR QUE: con una sola direccional, 92 x 92 metros del mismo azul se leen como un
## galpon. Unas pocas luces de color le dan identidad a cada zona y, sobre todo, te
## dicen DONDE ESTAS sin mirar el minimapa (que no hay).
##
## Son OmniLight3D y no algo mas caro porque el build web corre en Compatibility, donde
## no hay SSAO ni niebla volumetrica: lo que rinde ahi es luz y emision.
func _build_accent_lights() -> void:
	# DOS MITADES DE COLOR: la diagonal dorada y la diagonal helada. No es decoracion —
	# en un mapa cuadrado y simetrico de 92 metros, sin color no sabes en que esquina
	# estas, y el juego no tiene minimapa.
	#
	# Las energias son altas (8-9) porque el rango es grande: una omni reparte su
	# energia en todo el radio, y con 2.4 a 24 metros no llegaba nada al piso.
	var puntos: Array = [
		# El centro, en hielo: es el punto al que todos miran.
		{"pos": Vector3(0.0, 9.0, 0.0), "color": Art.ICE, "energia": 9.0, "radio": 30.0},
		# Diagonal calida.
		{"pos": Vector3(-32.0, 7.0, -32.0), "color": Art.GOLD, "energia": 8.0, "radio": 34.0},
		{"pos": Vector3(32.0, 7.0, 32.0), "color": Art.GOLD, "energia": 8.0, "radio": 34.0},
		# Diagonal fria.
		{"pos": Vector3(32.0, 7.0, -32.0), "color": Color(0.35, 0.62, 1.0), "energia": 7.0, "radio": 34.0},
		{"pos": Vector3(-32.0, 7.0, 32.0), "color": Color(0.35, 0.62, 1.0), "energia": 7.0, "radio": 34.0},
	]
	for punto: Dictionary in puntos:
		var luz := OmniLight3D.new()
		luz.position = punto["pos"]
		luz.light_color = punto["color"]
		luz.light_energy = punto["energia"]
		luz.omni_range = punto["radio"]
		luz.light_specular = 0.2
		# Sin sombras: cinco luces con sombra no las banca el build web, y lo que
		# aportan aca es color ambiente, no definicion.
		luz.shadow_enabled = false
		add_child(luz)


## Piso a cuadros. Es puramente visual pero cambia todo: sobre un plano liso no tenes
## referencia de velocidad ni de distancia y el mapa se siente vacio.
func _build_floor() -> void:
	var half := ARENA_SIZE * 0.5
	_add_box(Vector3(0.0, -0.5, 0.0), Vector3(ARENA_SIZE, 1.0, ARENA_SIZE), _floor_material, "Floor")

	var tile := 6.0
	var count := int(ARENA_SIZE / tile)
	for x: int in range(count):
		for z: int in range(count):
			if (x + z) % 2 == 1:
				continue
			var pos := Vector3(-half + tile * (float(x) + 0.5), 0.006, -half + tile * (float(z) + 0.5))
			_add_plane(pos, Vector2(tile, tile), _floor_alt_material)

	# --- Marcas luminosas en el piso ---
	#
	# No son decoracion: en 92 x 92 metros de damero, sin referencias fijas no sabes
	# hacia donde estas corriendo. Los anillos y las lineas dan un centro y cuatro
	# direcciones, que es lo minimo para orientarse sin minimapa.
	#
	# Y en el build web rinden mas que cualquier otra cosa: Compatibility no tiene SSAO
	# ni niebla volumetrica, pero la emision con glow se ve igual que en escritorio.
	_add_ring(15.0, 15.7, Art.TRIM, 0.9)
	_add_ring(30.0, 30.4, Color(0.30, 0.42, 0.68), 0.6)

	# Cuatro lineas del centro a cada rampa: marcan los accesos a la plataforma.
	for i: int in range(4):
		var ang := TAU * float(i) / 4.0
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var largo := 13.0
		var centro := dir * (15.0 + largo * 0.5)
		var linea := MeshInstance3D.new()
		var plano := PlaneMesh.new()
		plano.size = Vector2(0.55, largo) if absf(dir.z) > 0.5 else Vector2(largo, 0.55)
		linea.mesh = plano
		linea.material_override = _marking_material
		linea.position = Vector3(centro.x, 0.02, centro.z)
		add_child(linea)


## Anillo plano en el piso.
func _add_ring(inner: float, outer: float, color: Color, energy: float = 0.9) -> void:
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = inner
	ring_mesh.outer_radius = outer
	ring.mesh = ring_mesh
	ring.material_override = Art.glow(color, energy)
	ring.position = Vector3(0.0, 0.03, 0.0)
	add_child(ring)


func _build_walls() -> void:
	var half := ARENA_SIZE * 0.5
	var h := WALL_HEIGHT
	_add_box(Vector3(0.0, h * 0.5, -half), Vector3(ARENA_SIZE, h, 1.0), _wall_material, "WallN")
	_add_box(Vector3(0.0, h * 0.5, half), Vector3(ARENA_SIZE, h, 1.0), _wall_material, "WallS")
	_add_box(Vector3(-half, h * 0.5, 0.0), Vector3(1.0, h, ARENA_SIZE), _wall_material, "WallW")
	_add_box(Vector3(half, h * 0.5, 0.0), Vector3(1.0, h, ARENA_SIZE), _wall_material, "WallE")

	# Trim luminoso arriba de cada muro: marca el limite del mapa de un vistazo.
	_add_prop(Vector3(0.0, h, -half), Vector3(ARENA_SIZE, 0.24, 1.35), _trim_material)
	_add_prop(Vector3(0.0, h, half), Vector3(ARENA_SIZE, 0.24, 1.35), _trim_material)
	_add_prop(Vector3(-half, h, 0.0), Vector3(1.35, 0.24, ARENA_SIZE), _trim_material)
	_add_prop(Vector3(half, h, 0.0), Vector3(1.35, 0.24, ARENA_SIZE), _trim_material)

	# Franjas verticales cada 11.5 metros. Con paredes de 12 metros de alto y lisas, el
	# borde del mapa era un muro sin escala; las franjas dan altura y ritmo, y de paso
	# sirven de referencia para medir distancias de un vistazo.
	var paso := 11.5
	var cuantas := int(ARENA_SIZE / paso)
	for i: int in range(cuantas + 1):
		var t := -half + paso * float(i)
		if absf(t) > half - 1.0:
			continue
		_add_prop(Vector3(t, h * 0.5, -half + 0.6), Vector3(0.28, h * 0.72, 0.16), _trim_material)
		_add_prop(Vector3(t, h * 0.5, half - 0.6), Vector3(0.28, h * 0.72, 0.16), _trim_material)
		_add_prop(Vector3(-half + 0.6, h * 0.5, t), Vector3(0.16, h * 0.72, 0.28), _trim_material)
		_add_prop(Vector3(half - 0.6, h * 0.5, t), Vector3(0.16, h * 0.72, 0.28), _trim_material)

	# Torres en las esquinas, para que el perimetro no sea una caja pelada.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add_pillar(Vector3(half * sx * 0.96, 0.0, half * sz * 0.96), 2.2, h + 3.0)


func _build_cover() -> void:
	var index := 0

	# --- Plataforma central elevada, con rampas en los CUATRO lados ---
	# Cuatro accesos y no dos: en un mapa de 92 metros, dos rampas convierten la
	# plataforma en una fortaleza a la que hay que dar media vuelta para subir.
	_add_box(Vector3(0.0, 1.1, 0.0), Vector3(20.0, 2.2, 20.0), _cover_material, "Cover%d" % index)
	index += 1
	_add_prop(Vector3(0.0, 2.24, 0.0), Vector3(20.4, 0.12, 20.4), _cover_top_material)
	_add_ramp(Vector3(0.0, 0.6, 14.8), Vector3(8.0, 0.5, 10.0), -12.5)
	_add_ramp(Vector3(0.0, 0.6, -14.8), Vector3(8.0, 0.5, 10.0), 12.5)
	_add_ramp(Vector3(14.8, 0.6, 0.0), Vector3(10.0, 0.5, 8.0), 0.0, -12.5)
	_add_ramp(Vector3(-14.8, 0.6, 0.0), Vector3(10.0, 0.5, 8.0), 0.0, 12.5)

	# Torre en el centro de la plataforma: corta el duelo de punta a punta.
	_add_box(Vector3(0.0, 4.6, 0.0), Vector3(5.0, 5.0, 5.0), _cover_material, "Cover%d" % index)
	index += 1
	_add_prop(Vector3(0.0, 7.14, 0.0), Vector3(5.6, 0.16, 5.6), _marking_material)

	# --- Anillo interior: coberturas bajas y medias alrededor de la plataforma ---
	var blocks: Array = [
		{"pos": Vector3(-21.0, 1.3, -15.0), "size": Vector3(9.0, 2.6, 3.4)},
		{"pos": Vector3(20.0, 1.8, 17.0), "size": Vector3(3.4, 3.6, 10.0)},
		{"pos": Vector3(-25.0, 1.0, 21.0), "size": Vector3(6.5, 2.0, 6.5)},
		{"pos": Vector3(26.0, 2.2, -19.0), "size": Vector3(5.0, 4.4, 5.0)},
		{"pos": Vector3(-10.0, 0.7, 27.0), "size": Vector3(12.0, 1.4, 2.8)},
		{"pos": Vector3(13.0, 0.7, -28.0), "size": Vector3(2.8, 1.4, 12.0)},
		{"pos": Vector3(-30.0, 1.5, -3.0), "size": Vector3(3.2, 3.0, 8.0)},
		{"pos": Vector3(30.0, 1.2, 5.0), "size": Vector3(3.2, 2.4, 7.0)},

		# --- Anillo exterior: el que evita que las esquinas sean un descampado ---
		{"pos": Vector3(-36.0, 1.6, -30.0), "size": Vector3(7.0, 3.2, 3.2)},
		{"pos": Vector3(36.0, 1.6, 30.0), "size": Vector3(7.0, 3.2, 3.2)},
		{"pos": Vector3(-35.0, 1.1, 33.0), "size": Vector3(3.2, 2.2, 8.0)},
		{"pos": Vector3(35.0, 1.1, -33.0), "size": Vector3(3.2, 2.2, 8.0)},
		{"pos": Vector3(0.0, 1.4, 36.0), "size": Vector3(10.0, 2.8, 3.0)},
		{"pos": Vector3(0.0, 1.4, -36.0), "size": Vector3(10.0, 2.8, 3.0)},
		{"pos": Vector3(-38.0, 1.4, 8.0), "size": Vector3(3.0, 2.8, 10.0)},
		{"pos": Vector3(38.0, 1.4, -8.0), "size": Vector3(3.0, 2.8, 10.0)},
	]
	for block: Dictionary in blocks:
		var pos: Vector3 = block["pos"]
		var size: Vector3 = block["size"]
		_add_box(pos, size, _zone_material(pos), "Cover%d" % index)
		index += 1
		# Borde claro arriba: hace que la silueta de la cobertura se lea de lejos.
		_add_prop(pos + Vector3(0.0, size.y * 0.5 + 0.07, 0.0),
			Vector3(size.x * 1.03, 0.14, size.z * 1.03), _cover_top_material)

	# --- Dos plataformas laterales elevadas, para que la altura no sea solo el centro ---
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * 28.0, 0.75, side * -27.0)
		_add_box(base, Vector3(11.0, 1.5, 11.0), _zone_material(base), "Cover%d" % index)
		index += 1
		_add_prop(base + Vector3(0.0, 0.83, 0.0), Vector3(11.3, 0.12, 11.3), _cover_top_material)
		_add_ramp(base + Vector3(side * -8.5, -0.28, 0.0), Vector3(8.0, 0.4, 6.0), 0.0, side * 10.0)

	# Pilares sueltos, para romper las lineas rectas.
	var spots: Array[Vector3] = [
		Vector3(-16.0, 0.0, 30.0), Vector3(17.0, 0.0, -26.0),
		Vector3(-33.0, 0.0, 13.0), Vector3(33.0, 0.0, -12.0),
		Vector3(-12.0, 0.0, -22.0), Vector3(11.0, 0.0, 23.0),
		Vector3(-42.0, 0.0, -14.0), Vector3(42.0, 0.0, 14.0),
	]
	for spot: Vector3 in spots:
		_add_pillar(spot, 0.95, 6.5)


# ---------------------------------------------------------- Piezas del escenario

## Cuerpo solido con su malla.
func _add_box(pos: Vector3, size: Vector3, material: StandardMaterial3D, node_name: String) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(NAV_GROUP)
	body.name = node_name
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(Art.box(size, material))
	add_child(body)


## Decoracion sin colision.
func _add_prop(pos: Vector3, size: Vector3, material: Material) -> void:
	add_child(Art.box(size, material, pos))


## Placa fina apoyada en el piso, sin colision.
func _add_plane(pos: Vector3, size: Vector2, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	add_child(mi)


## Rampa: una caja rotada. El angulo se mantiene bajo para que se pueda subir corriendo
## (el floor_max_angle por defecto de CharacterBody3D son 45 grados).
## Tinte segun en que diagonal del mapa cae la cobertura.
##
## El mapa es un cuadrado simetrico de 92 metros: sin una señal de color, las cuatro
## esquinas son indistinguibles y te perdes. Dos diagonales, dos temperaturas.
func _zone_material(pos: Vector3) -> StandardMaterial3D:
	if pos.x * pos.z > 0.0:
		return _cover_warm_material
	return _cover_cool_material


## Rampa inclinada. angle_x inclina sobre el eje X (rampas norte/sur) y angle_z sobre
## el Z (rampas este/oeste): con cuatro accesos hacen falta las dos orientaciones.
func _add_ramp(pos: Vector3, size: Vector3, angle_deg: float, angle_z_deg: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(NAV_GROUP)
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = Vector3(angle_deg, 0.0, angle_z_deg)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(Art.box(size, _cover_top_material))
	add_child(body)


func _add_pillar(base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.add_to_group(NAV_GROUP)
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = base + Vector3(0.0, height * 0.5, 0.0)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)

	body.add_child(Art.cylinder(radius, height, _pillar_material))
	body.add_child(Art.cylinder(radius * 1.07, 0.3, _trim_material, Vector3(0.0, -height * 0.5 + 1.3, 0.0)))
	body.add_child(Art.cylinder(radius * 1.07, 0.3, _trim_material, Vector3(0.0, height * 0.5 - 0.9, 0.0)))
	add_child(body)


# ------------------------------------------------------------------- Navegacion

## Hornea el navmesh de la arena.
##
## POR QUE HACE FALTA: los bots iban derecho a donde estaba el jugador y se clavaban
## contra la plataforma central. Medido con tests/bot_diag: uno de los tres pasaba el
## 69% del tiempo trabado, ninguno llegaba nunca a distancia de pegar y los tres
## terminaban amontonados a 10 cm contra la misma pared.
##
## Lo habia intentado con tres rayos de evasion. Alcanza para una cobertura suelta y NO
## alcanza para una plataforma de 20 metros: el bot se abre 45 grados, sigue chocando,
## se abre 80, sigue chocando, y termina empujando la pared. Rodear un obstaculo grande
## es pathfinding, y pathfinding se hace con un navmesh.
##
## Se hornea en runtime porque el mapa se genera por codigo: no hay escena que hornear
## en el editor.
func _build_navigation() -> void:
	var region := NavigationRegion3D.new()
	region.name = "NavRegion"

	var nav := NavigationMesh.new()
	# TODO ESTO EN MULTIPLOS DE LA CELDA, a proposito.
	#
	# Godot redondea agent_radius y agent_height hacia arriba y agent_max_climb hacia
	# abajo, siempre a unidades de celda, y avisa por consola cada vez que lo hace. Los
	# valores de antes (0.65 / 1.8 / 0.4) se convertian en 0.75 / 2.0 / 0.25 en silencio,
	# asi que lo que decia el codigo y lo que usaba el horneado no eran lo mismo.
	# Escritos ya redondeados, el codigo dice la verdad y la consola queda limpia.
	#
	# El radio es mas ancho que el jugador (capsula de 0.4) para que el camino no pase
	# raspando las esquinas y el bot no se trabe al doblar.
	nav.agent_radius = 0.75
	nav.agent_height = 2.0
	# Menor que Player.STEP_HEIGHT a proposito: ver NAV_MAX_CLIMB. Las coberturas miden
	# de 1.4 a 4.4 metros y siguen siendo inescalables con cualquiera de los dos valores.
	#
	# Las rampas no se rompen con un valor tan bajo: con 12.5 grados de pendiente, una
	# celda de 25 cm sube 5.5 cm, muy por debajo del limite, asi que la superficie de la
	# rampa sigue siendo una sola pieza conectada.
	nav.agent_max_climb = NAV_MAX_CLIMB
	nav.agent_max_slope = 48.0
	# La altura de celda TIENE que coincidir con la del mapa de navegacion del proyecto
	# (0.25 por defecto). Con 0.2 Godot avisa de errores de rasterizacion en los bordes
	# y el navmesh sale inutilizable.
	nav.cell_size = 0.25
	nav.cell_height = 0.25

	# De los cuerpos solidos, no de las mallas: las mallas incluyen adornos sin colision
	# (trims, anillos del piso) que crearian caminos falsos por el aire.
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = GameConfig.LAYER_WORLD
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = NAV_GROUP

	region.navigation_mesh = nav
	add_child(region)
	# Sincrono: los bots piden un camino apenas nacen y con horneado en hilo el primer
	# pedido sale vacio y arrancan caminando a cualquier lado.
	region.bake_navigation_mesh(false)
	# Si sale vacio, los bots no se mueven y no hay ningun otro sintoma: conviene que
	# grite aca en vez de que alguien lo descubra jugando.
	if region.navigation_mesh.get_polygon_count() == 0:
		push_warning("[arena] el navmesh salio VACIO: los bots no van a poder moverse")


# ------------------------------------------------------------------- Spawn points

func _build_spawn_points() -> void:
	# Pegados al borde del mapa nuevo (medio lado = 46) pero adentro de las paredes, y
	# lejos de las coberturas para no aparecer encajado en una.
	var positions: Array[Vector3] = [
		Vector3(-40.0, 0.0, -40.0),
		Vector3(40.0, 0.0, -40.0),
		Vector3(-40.0, 0.0, 40.0),
		Vector3(40.0, 0.0, 40.0),
		Vector3(-6.0, 0.0, -41.0),
		Vector3(6.0, 0.0, 41.0),
		Vector3(-41.0, 0.0, 24.0),
		Vector3(41.0, 0.0, -24.0),
	]
	_spawn_points.clear()
	for pos: Vector3 in positions:
		# Cada spawn mira al centro del mapa.
		var to_center := (Vector3.ZERO - pos)
		var yaw := atan2(-to_center.x, -to_center.z)
		_spawn_points.append(Transform3D(Basis(Vector3.UP, yaw), pos))


## Busca un punto despejado cerca de `alrededor`, probando en espiral hacia afuera.
##
## POR QUE EXISTE: cualquier coordenada escrita a mano deja de ser valida en cuanto
## alguien mueve una cobertura. Paso de verdad: al agrandar el mapa, dos tests que
## ponian un maniqui en (20, 20) empezaron a meterlo adentro de un bloque y sus golpes
## pegaban contra la pared. Con esto, el que necesita un lugar libre lo pide.
func find_clear_spot(alrededor: Vector3, radius: float = 0.75) -> Vector3:
	var space := get_world_3d().direct_space_state
	if space == null:
		return alrededor

	var shape := SphereShape3D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = GameConfig.LAYER_WORLD

	var limite := ARENA_SIZE * 0.5 - 3.0
	for intento: int in range(28):
		# Espiral: el primer intento es el punto pedido, los siguientes se abren en
		# circulos cada vez mas grandes.
		var radio := float(intento) * 0.9
		var ang := float(intento) * 2.399  # angulo aureo, reparte sin repetir direccion
		var probe := alrededor + Vector3(cos(ang) * radio, 0.0, sin(ang) * radio)
		probe.x = clampf(probe.x, -limite, limite)
		probe.z = clampf(probe.z, -limite, limite)
		query.transform = Transform3D(Basis.IDENTITY, probe + Vector3.UP * 1.0)
		if space.intersect_shape(query, 1).is_empty():
			return probe
	return alrededor


## Devuelve el spawn mas lejano de los demas JUGADORES, para no aparecer en la cara de
## alguien.
##
## LOS BOTS NO CUENTAN, y es deliberado. La regla de "aparecer lejos" existe para que
## nadie te camperee el spawn, y un bot no campea: te viene a buscar. Contandolos, esta
## funcion elegia el punto del mapa MAS ALEJADO de los bots, o sea que en modo practica
## empezabas a cincuenta metros de los unicos rivales que hay. Combinado con el alcance
## de deteccion viejo, los bots no te encontraban nunca.
func get_free_spawn_point() -> Transform3D:
	if _spawn_points.is_empty():
		return Transform3D.IDENTITY

	var best := _spawn_points[0]
	var best_score := -1.0
	for t: Transform3D in _spawn_points:
		var nearest := 9999.0
		for player: Player in _living_players():
			if player.is_dummy:
				continue
			nearest = minf(nearest, t.origin.distance_to(player.global_position))
		# Pero tampoco aparecer ENCIMA de un bot: eso es un golpe gratis en la cara.
		for player: Player in _living_players():
			if not player.is_dummy:
				continue
			var d := t.origin.distance_to(player.global_position)
			if d < 8.0:
				nearest = minf(nearest, d)
		if nearest > best_score:
			best_score = nearest
			best = t
	return best


func _living_players() -> Array[Player]:
	var out: Array[Player] = []
	for id: int in _players.keys():
		var p: Player = _players[id]
		if is_instance_valid(p) and not p.health.is_dead:
			out.append(p)
	return out


# --------------------------------------------------------------- Spawn de jugadores

func _create_player(id: int, character_id: String, spawn_position: Vector3, yaw: float) -> Player:
	if _players.has(id) and is_instance_valid(_players[id]):
		return _players[id]

	var player: Player = PLAYER_SCENE.instantiate()
	player.name = "Player_%d" % id
	player.peer_id = id
	player.player_name = Net.get_player_name(id)
	add_child(player)
	player.global_position = spawn_position
	player.rotation.y = yaw

	var data := CharacterDB.get_character(StringName(character_id))
	player.setup_character(data)

	_players[id] = player

	if Net.is_server():
		player.died.connect(_on_player_died.bind(id))

	player_spawned.emit(player)
	if player.is_local_player():
		local_player_spawned.emit(player)
	return player


func get_player(id: int) -> Player:
	if _players.has(id) and is_instance_valid(_players[id]):
		return _players[id]
	return null


func get_local_player() -> Player:
	return get_player(Net.local_id())


func _remove_player(id: int) -> void:
	if not _players.has(id):
		return
	var player: Player = _players[id]
	if is_instance_valid(player):
		player.queue_free()
	_players.erase(id)


# ------------------------------------------------------------ Bots (modo practica)

## Tres bots que persiguen, esquivan y te devuelven los golpes. Lo que deciden esta en
## BotBrain; aca solo se los arma.
func _spawn_dummies() -> void:
	# Personajes REALES y alternados, no un maniqui generico. Dos razones: practicas
	# contra los kits con los que despues vas a pelear de verdad, y ves de afuera lo
	# que hacen tus propias habilidades, que jugandolas en primera persona no se ve.
	var ids := CharacterDB.get_all_ids()
	if ids.is_empty():
		return

	# En arco al otro lado del mapa: entran juntos pero no en fila india. Cinco puestos
	# porque el panel de practica deja pedir hasta cinco bots.
	var puestos: Array[Vector3] = [
		Vector3(-14.0, 0.0, -30.0),
		Vector3(0.0, 0.0, -34.0),
		Vector3(14.0, 0.0, -30.0),
		Vector3(-26.0, 0.0, -24.0),
		Vector3(26.0, 0.0, -24.0),
	]

	# En practica manda el panel; si no, el numero de siempre.
	var cuantos := Practica.bots if Net.solo_mode else DUMMY_COUNT
	for i: int in range(cuantos):
		var base: Vector3 = puestos[i] if i < puestos.size() else Vector3(float(i) * 8.0, 0.0, -30.0)
		var pos := find_clear_spot(base, 1.0)
		var data := CharacterDB.get_character(ids[i % ids.size()])
		if data == null:
			continue

		var bot: Player = PLAYER_SCENE.instantiate()
		var id := -(i + 1)
		bot.name = "Bot_%d" % (i + 1)
		bot.peer_id = id
		bot.is_dummy = true
		bot.player_name = "Bot %s" % data.display_name.split(" ")[0]
		add_child(bot)
		bot.global_position = pos
		bot.home_position = pos
		bot.rotation.y = 0.0
		bot.bot_look_yaw = 0.0
		bot.setup_character(data)
		bot.health.set_max(DUMMY_HEALTH)

		# El servidor es el dueño de las habilidades del bot.
		#
		# HACE FALTA: setup_character deja owner_peer_id en el peer del bot (-1, -2...),
		# y AbilityCaster rechaza cualquier pedido cuyo emisor no sea el dueño. Con el
		# id negativo, el bot no podia tirar ni una habilidad y el rechazo era mudo.
		bot.caster.owner_peer_id = Net.local_id()

		bot.name_label.text = bot.player_name
		bot.name_label.visible = true

		var brain := BotBrain.new()
		brain.name = "BotBrain"
		brain.setup(bot, pos)
		bot.add_child(brain)

		_players[id] = bot
		_dummy_spawns[id] = pos
		bot.died.connect(_on_player_died.bind(id))


## Prende o apaga a todos los bots.
##
## Lo usa el chequeo visual: necesita capturas quietas y reproducibles, y con los bots
## persiguiendo al jugador cada corrida salia distinta y la mitad de las fotos tenian
## un bot cruzado delante de la camara.
static func set_bots_active(active: bool) -> void:
	BotBrain.globally_enabled = active


func _on_bots_a_rehacer() -> void:
	rehacer_bots()


## Borra los bots que haya y vuelve a crearlos con la cantidad que pida el panel.
##
## EN CALIENTE, sin reiniciar la partida. Ese es medio punto del panel: probar "y si
## fueran dos" sin volver al menu, perder la posicion y tener que recargar cooldowns.
func rehacer_bots() -> void:
	if not Net.is_server():
		return
	for id: int in _players.keys().duplicate():
		if id >= 0:
			continue
		var bot: Node = _players[id]
		if is_instance_valid(bot):
			bot.queue_free()
		_players.erase(id)
		_dummy_spawns.erase(id)
	# Un frame para que los queue_free() se hagan efectivos: si no, los bots nuevos
	# nacen mientras los viejos todavia estan en el grupo "players" y se cuentan entre
	# ellos para separarse y para elegir objetivo.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_spawn_dummies()


# ------------------------------------------------------------------ Muerte / respawn

func _on_player_died(killer_id: int, victim_id: int) -> void:
	if not Net.is_server():
		return
	var victim := get_player(victim_id)
	# Las muertes de bot no suman al marcador: es practica, no una partida.
	if victim != null and victim.is_dummy:
		_respawn_dummy_after_delay(victim_id)
		return
	Net.add_kill(killer_id, victim_id)
	_respawn_after_delay(victim_id)


func _respawn_after_delay(victim_id: int) -> void:
	await get_tree().create_timer(GameConfig.RESPAWN_DELAY).timeout
	if not Net.is_server():
		return
	var player := get_player(victim_id)
	if player == null:
		return
	var t := get_free_spawn_point()
	player.respawn_at(t.origin, t.basis.get_euler().y)


func _respawn_dummy_after_delay(dummy_id: int) -> void:
	await get_tree().create_timer(DUMMY_RESPAWN_DELAY).timeout
	var dummy := get_player(dummy_id)
	if dummy == null:
		return
	var pos: Vector3 = _dummy_spawns.get(dummy_id, Vector3.ZERO)
	dummy.health.revive_full()
	dummy.stamina.restore_full()
	dummy.status.clear_all()
	dummy.caster.reset_state()
	dummy.bot_move_dir = Vector3.ZERO
	dummy.aim_override = Vector3.ZERO
	dummy._apply_respawn(find_clear_spot(pos, 1.0), 0.0)


func _on_peer_disconnected(id: int) -> void:
	if not Net.is_server():
		return
	_remove_player(id)
	Net.rpc_ready(self, &"_net_despawn", [id])


# ------------------------------------------------------------------------- Red

@rpc("any_peer", "call_remote", "reliable")
func _srv_client_ready() -> void:
	if not Net.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return

	# 1) Al que recien llega le mandamos todos los jugadores que ya estaban.
	for id: int in _players.keys():
		var existing: Player = _players[id]
		if not is_instance_valid(existing):
			continue
		_net_spawn.rpc_id(sender, id, String(existing.character_id), existing.global_position, existing.rotation.y)

	# 2) Lo creamos en el servidor.
	var t := get_free_spawn_point()
	var char_id := String(Net.get_player_info(sender).get("character_id", "noelle"))
	var yaw := t.basis.get_euler().y
	_create_player(sender, char_id, t.origin, yaw)

	# 3) Avisamos del nuevo a los clientes que YA estaban listos.
	Net.rpc_ready(self, &"_net_spawn", [sender, char_id, t.origin, yaw])

	# 4) Y al recien llegado le mandamos su propio jugador.
	_net_spawn.rpc_id(sender, sender, char_id, t.origin, yaw)

	# 5) Recien ahora puede recibir posiciones y estados sin que se pierdan paquetes.
	Net.mark_peer_ready(sender)


@rpc("authority", "call_remote", "reliable")
func _net_spawn(id: int, character_id: String, spawn_position: Vector3, yaw: float) -> void:
	_create_player(id, character_id, spawn_position, yaw)


@rpc("authority", "call_remote", "reliable")
func _net_despawn(id: int) -> void:
	_remove_player(id)
