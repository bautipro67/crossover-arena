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

const ARENA_SIZE: float = 60.0
const WALL_HEIGHT: float = 9.0

## Maniquies del modo practica. Aguantan bastante para que puedas probar el combo
## completo (apilar escarcha -> congelar -> Snowgrave) sin que se mueran antes.
const DUMMY_COUNT: int = 3
const DUMMY_HEALTH: float = 250.0
const DUMMY_RESPAWN_DELAY: float = 3.0

signal player_spawned(player: Player)
signal local_player_spawned(player: Player)

var _spawn_points: Array[Transform3D] = []
var _players: Dictionary = {}
## Donde vuelve cada maniqui cuando lo matas.
var _dummy_spawns: Dictionary = {}

var _floor_material: StandardMaterial3D = null
var _floor_alt_material: StandardMaterial3D = null
var _wall_material: StandardMaterial3D = null
var _cover_material: StandardMaterial3D = null
var _cover_top_material: StandardMaterial3D = null
var _trim_material: StandardMaterial3D = null


func _ready() -> void:
	_make_materials()
	_build_environment()
	_build_floor()
	_build_walls()
	_build_cover()
	_build_spawn_points()

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


func _build_environment() -> void:
	var env := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.07, 0.10, 0.22)
	sky_material.sky_horizon_color = Color(0.42, 0.55, 0.74)
	sky_material.sky_curve = 0.15
	sky_material.ground_bottom_color = Color(0.05, 0.06, 0.11)
	sky_material.ground_horizon_color = Color(0.26, 0.34, 0.48)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55

	# Niebla fria: da profundidad y separa las capas del mapa.
	env.fog_enabled = true
	env.fog_light_color = Color(0.42, 0.55, 0.76)
	env.fog_density = 0.010
	env.fog_sky_affect = 0.3

	# Glow: es lo que hace que los trims y los proyectiles se sientan luminosos en vez
	# de ser simplemente celestes.
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_bloom = 0.15
	# Umbral alto: que brillen SOLO las cosas emisivas de verdad. Mas bajo, el dorado
	# de Dio y los trims se queman y se pierde el detalle.
	env.glow_hdr_threshold = 1.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05

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

	# Circulo central marcado, como una arena de verdad.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 11.4
	ring_mesh.outer_radius = 12.0
	ring.mesh = ring_mesh
	ring.material_override = _trim_material
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

	# Torres en las esquinas, para que el perimetro no sea una caja pelada.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_add_pillar(Vector3(half * sx * 0.96, 0.0, half * sz * 0.96), 2.2, h + 3.0)


func _build_cover() -> void:
	var index := 0

	# --- Plataforma central elevada, con rampas a dos lados ---
	_add_box(Vector3(0.0, 1.0, 0.0), Vector3(14.0, 2.0, 14.0), _cover_material, "Cover%d" % index)
	index += 1
	_add_prop(Vector3(0.0, 2.03, 0.0), Vector3(14.3, 0.12, 14.3), _cover_top_material)
	_add_ramp(Vector3(0.0, 0.55, 11.2), Vector3(7.0, 0.5, 9.0), -13.0)
	_add_ramp(Vector3(0.0, 0.55, -11.2), Vector3(7.0, 0.5, 9.0), 13.0)

	# Torre en el centro de la plataforma.
	_add_box(Vector3(0.0, 4.0, 0.0), Vector3(4.0, 4.0, 4.0), _cover_material, "Cover%d" % index)
	index += 1
	_add_prop(Vector3(0.0, 6.06, 0.0), Vector3(4.5, 0.22, 4.5), _trim_material)

	# --- Coberturas de flanco, todas distintas ---
	var blocks: Array = [
		{"pos": Vector3(-15.0, 1.3, -10.0), "size": Vector3(8.0, 2.6, 3.2)},
		{"pos": Vector3(14.0, 1.7, 12.0), "size": Vector3(3.2, 3.4, 9.0)},
		{"pos": Vector3(-18.0, 1.0, 15.0), "size": Vector3(5.5, 2.0, 5.5)},
		{"pos": Vector3(19.0, 2.1, -14.0), "size": Vector3(4.5, 4.2, 4.5)},
		{"pos": Vector3(-7.0, 0.7, 20.0), "size": Vector3(10.0, 1.4, 2.6)},
		{"pos": Vector3(9.0, 0.7, -21.0), "size": Vector3(2.6, 1.4, 10.0)},
		{"pos": Vector3(-22.0, 1.5, -2.0), "size": Vector3(3.0, 3.0, 7.0)},
		{"pos": Vector3(22.0, 1.2, 4.0), "size": Vector3(3.0, 2.4, 6.0)},
	]
	for block: Dictionary in blocks:
		var pos: Vector3 = block["pos"]
		var size: Vector3 = block["size"]
		_add_box(pos, size, _cover_material, "Cover%d" % index)
		index += 1
		# Borde claro arriba: hace que la silueta de la cobertura se lea de lejos.
		_add_prop(pos + Vector3(0.0, size.y * 0.5 + 0.07, 0.0),
			Vector3(size.x * 1.03, 0.14, size.z * 1.03), _cover_top_material)

	# Pilares sueltos, para romper las lineas rectas.
	var spots: Array[Vector3] = [
		Vector3(-11.0, 0.0, 22.0), Vector3(12.0, 0.0, -18.0),
		Vector3(-24.0, 0.0, 9.0), Vector3(24.0, 0.0, -8.0),
	]
	for spot: Vector3 in spots:
		_add_pillar(spot, 0.9, 5.5)


# ---------------------------------------------------------- Piezas del escenario

## Cuerpo solido con su malla.
func _add_box(pos: Vector3, size: Vector3, material: StandardMaterial3D, node_name: String) -> void:
	var body := StaticBody3D.new()
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
func _add_ramp(pos: Vector3, size: Vector3, angle_deg: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = Vector3(angle_deg, 0.0, 0.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.add_child(Art.box(size, _cover_top_material))
	add_child(body)


func _add_pillar(base: Vector3, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = GameConfig.LAYER_WORLD
	body.collision_mask = 0
	body.position = base + Vector3(0.0, height * 0.5, 0.0)

	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)

	body.add_child(Art.cylinder(radius, height, _wall_material))
	body.add_child(Art.cylinder(radius * 1.07, 0.3, _trim_material, Vector3(0.0, -height * 0.5 + 1.3, 0.0)))
	body.add_child(Art.cylinder(radius * 1.07, 0.3, _trim_material, Vector3(0.0, height * 0.5 - 0.9, 0.0)))
	add_child(body)


# ------------------------------------------------------------------- Spawn points

func _build_spawn_points() -> void:
	var positions: Array[Vector3] = [
		Vector3(-24.0, 0.0, -24.0),
		Vector3(24.0, 0.0, -24.0),
		Vector3(-24.0, 0.0, 24.0),
		Vector3(24.0, 0.0, 24.0),
		Vector3(0.0, 0.0, -25.0),
		Vector3(0.0, 0.0, 25.0),
		Vector3(-25.0, 0.0, 0.0),
		Vector3(25.0, 0.0, 0.0),
	]
	_spawn_points.clear()
	for pos: Vector3 in positions:
		# Cada spawn mira al centro del mapa.
		var to_center := (Vector3.ZERO - pos)
		var yaw := atan2(-to_center.x, -to_center.z)
		_spawn_points.append(Transform3D(Basis(Vector3.UP, yaw), pos))


## Devuelve el spawn mas lejano de todos los jugadores vivos, para no aparecer en la
## cara de alguien.
func get_free_spawn_point() -> Transform3D:
	if _spawn_points.is_empty():
		return Transform3D.IDENTITY

	var best := _spawn_points[0]
	var best_score := -1.0
	for t: Transform3D in _spawn_points:
		var nearest := 9999.0
		for player: Player in _living_players():
			nearest = minf(nearest, t.origin.distance_to(player.global_position))
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


# ------------------------------------------------------- Maniquies (modo practica)

## Tres maniquies parados en linea. No se mueven ni devuelven golpes: estan para medir
## daño, ver como suben los stacks de escarcha y practicar el timing del canalizado.
func _spawn_dummies() -> void:
	var data := _make_dummy_data()
	for i: int in range(DUMMY_COUNT):
		var pos := Vector3(-8.0 + float(i) * 8.0, 0.0, -20.0)
		var dummy: Player = PLAYER_SCENE.instantiate()
		var id := -(i + 1)
		dummy.name = "Dummy_%d" % (i + 1)
		dummy.peer_id = id
		dummy.is_dummy = true
		dummy.player_name = "Maniqui %d" % (i + 1)
		add_child(dummy)
		dummy.global_position = pos
		dummy.home_position = pos
		dummy.rotation.y = PI
		dummy.setup_character(data)
		dummy.health.set_max(DUMMY_HEALTH)
		dummy.name_label.text = dummy.player_name
		dummy.name_label.visible = true
		_players[id] = dummy
		_dummy_spawns[id] = pos
		dummy.died.connect(_on_player_died.bind(id))


## Personaje solo para los maniquies. No se registra en CharacterDB a proposito: no
## queremos que aparezca como opcion en la sala de espera.
func _make_dummy_data() -> CharacterData:
	var data := CharacterData.new()
	data.id = &"dummy"
	data.display_name = "Maniqui"
	data.origin_game = "Practica"
	data.body_color = Color(0.40, 0.42, 0.50)
	data.accent_color = Color(0.88, 0.42, 0.36)
	data.skin_color = Color(0.58, 0.60, 0.66)
	data.max_health = DUMMY_HEALTH
	data.max_stamina = 100.0
	data.move_speed = 0.0
	data.silhouette = &"none"
	return data


# ------------------------------------------------------------------ Muerte / respawn

func _on_player_died(killer_id: int, victim_id: int) -> void:
	if not Net.is_server():
		return
	var victim := get_player(victim_id)
	# Las muertes de maniqui no suman al marcador: es practica, no una partida.
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
	dummy.status.clear_all()
	dummy._apply_respawn(pos, PI)


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
