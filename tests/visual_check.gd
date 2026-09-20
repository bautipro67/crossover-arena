extends Node
## Chequeo visual: abre el juego de verdad (con ventana), lo maneja solo y saca
## capturas en los momentos que importan.
##
## Sirve para ver que lo que se dibuja es lo que uno cree, algo que ningun test
## headless puede decirte: que el HUD este bien puesto, que se distingan las siluetas
## de los personajes, que el hielo se vea encima de un congelado.
##
## Correlo con:
##   godot --path . res://tests/visual_check.tscn -- C:\ruta\donde\guardar
##
## NO uses --headless: sin render el viewport sale en negro.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _out_dir: String = ""
var _main: Node = null
var _shots: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out_dir = String(args[0]) if args.size() > 0 else OS.get_user_data_dir()
	print("[visual] guardando capturas en: ", _out_dir)
	# Bots quietos: con ellos persiguiendo, cada corrida sale distinta y la mitad de
	# las capturas tienen un bot cruzado delante de la camara. Se prenden a proposito
	# para la captura de combate del final.
	Arena.set_bots_active(false)
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _process(_delta: float) -> void:
	# El juego captura el mouse al spawnear. Como esto corre solo, se lo devolvemos
	# al usuario en cada frame para no secuestrarle el cursor.
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _run() -> void:
	await _wait(1.0)
	await _shot("01_menu_principal")

	# --- Servidor gratuito despertando ---
	# Es literalmente lo primero que ve quien entra al servidor publico cuando estaba
	# apagado, o sea casi siempre. Lo reproducimos apuntando a un puerto muerto, asi la
	# captura no depende de tener nada levantado.
	Net.join_game("127.0.0.1", 27011, "Tester")
	_main.show_lobby()
	await _wait(8.5)
	await _shot("01b_servidor_despertando")
	Net.leave_game()
	_main.show_main_menu()
	await _wait(0.6)

	# --- Modo practica ---
	Net.start_solo("Tester")
	_main.show_lobby()
	await _wait(0.8)
	await _shot("02_lobby_noelle")

	# Pasamos a Dio para ver que su kit se muestre distinto.
	Net.set_local_character("dio")
	await _wait(0.6)
	await _shot("03_lobby_dio")

	# Volvemos a Noelle para la partida.
	Net.set_local_character("noelle")
	await _wait(0.4)

	Net.start_match()
	await _wait(2.0)

	var arena: Arena = _main.get_node_or_null("Arena") as Arena
	if arena == null:
		print("[visual] ERROR: no se creo la arena")
		_finish()
		return
	var player: Player = arena.get_local_player()
	if player == null:
		print("[visual] ERROR: no hay jugador local")
		_finish()
		return

	# Nos paramos enfrente del maniqui de la izquierda (esta en x = -8, z = -20).
	# OJO 1: en Godot el frente es -Z, asi que yaw 0 YA mira hacia los maniquies.
	# OJO 2: nos paramos alineados con el maniqui y cerca, para que la plataforma
	#        central no corte la linea de vision. Que la corte esta bien —es para lo
	#        que esta— pero para mirar los efectos hace falta vista libre.
	_place(player, Vector3(-8.0, 0.0, -16.0), 0.0)
	await _wait(1.0)
	await _shot("04_arena_noelle_hud")

	# --- Combate con Noelle ---
	var dummy := _find_dummy(arena)
	if dummy != null:
		# El golpe dura ~0.24s, asi que hay que capturarlo temprano o ya volvio a la pose.
		player.caster.request_use(0)  # Icicle Strike
		await _wait(0.10)
		await _shot("05_golpe_basico")

		# Demo del retroceso, con camara lateral: de frente el desplazamiento no se nota.
		await _knockback_demo(player, dummy)

		# El medidor de ultimate llenandose a golpes, que es la mecanica nueva.
		await _charge_demo(player, dummy)

		# Primer plano de la cara ANTES de congelarlo: con el hielo encima sale todo
		# lavado y no se puede juzgar nada.
		await _face_closeup(player, dummy, "05b_cara_de_cerca")

		# Defensa de Hielo: la barrera encima de Noelle y la barra de escudo del HUD.
		player.stamina.restore_full()
		player.caster.reset_state()
		player.caster.request_use(2)
		await _wait(0.5)
		await _shot("05c_defensa_de_hielo")
		# Y como se ve cuando le pegan con el escudo puesto.
		CombatUtils.deal_damage(player, 18.0, dummy.peer_id)
		await _wait(0.3)
		await _shot("05d_escudo_aguantando")

		player.stamina.restore_full()
		player.caster.reset_state()
		player.caster.request_use(1)  # Ice Shock
		await _wait(0.25)
		await _shot("06_ice_shock_proyectil")

		# Congelamos al del medio para ver la capsula de hielo y el aviso del HUD.
		await _wait(0.6)
		for _i: int in range(StatusEffects.MAX_CHILL):
			dummy.status.add_chill(1)
		await _wait(0.6)
		await _shot("07_maniqui_congelado")

		# Snowgrave sobre el congelado. El medidor viene GANADO de la demo de arriba:
		# no se lo seteamos a mano, asi el disparo demuestra que el sistema funciona.
		player.stamina.restore_full()
		player.caster.reset_state()
		player.caster.request_use(3)
		await _wait(0.9)
		await _shot("08_canalizando_snowgrave")
		await _wait(1.2)
		await _shot("09_snowgrave")

	# --- Cambio a Dio ---
	await _wait(1.5)
	player.setup_character(CharacterDB.get_character(&"dio"))
	player.stamina.restore_full()
	player.caster.reset_state()
	_place(player, Vector3(-8.0, 0.0, -16.0), 0.0)
	# Rebindeamos el HUD para que muestre el kit nuevo.
	# El HUD se crea con HUD.new() y no lleva nombre fijo, asi que lo buscamos por tipo.
	var hud := _find_hud()
	if hud != null:
		hud.bind_player(player)
	await _wait(1.0)
	await _shot("10_arena_dio_hud")

	player.caster.request_use(1)  # Knife Throw
	await _wait(0.25)
	await _shot("11_cuchillos")

	# Rafaga del Stand: seis golpes encadenados. Capturamos a mitad de rafaga, que es
	# donde se ve que son muchos y no uno.
	await _wait(1.0)
	var victima := _find_dummy(_main.get_node_or_null("Arena") as Arena)
	if victima != null:
		_place(player, victima.global_position + Vector3(0.0, 0.0, 2.2), 0.0)
		await _wait(0.4)
		player.stamina.restore_full()
		player.caster.reset_state()
		player.caster.request_use(2)
		await _wait(StandBarrage.TICKS * StandBarrage.TICK_INTERVAL * 0.5)
		await _shot("11b_rafaga_del_stand")

	await _wait(1.0)
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	player.caster.request_use(3)  # ZA WARUDO
	# Canaliza 0.9s: capturamos la pose de carga antes de que se suelte.
	await _wait(0.55)
	await _shot("12_canalizando_zawarudo")
	await _wait(0.75)
	await _shot("13_za_warudo")
	await _wait(0.6)
	await _shot("14_tiempo_detenido")

	# --- Flowery ---
	await _flowery()

	# --- Los bots peleando, que es lo que cambia el modo practica ---
	await _bots_en_combate()

	# --- Vista aerea del mapa entero ---
	await _vista_aerea()

	# --- Marcador ---
	await _wait(0.8)
	await _shot("15_final")

	_finish()


# ------------------------------------------------------------------- Helpers

## El medidor de ultimate llenandose a golpes.
##
## Usa el GOLPE BASICO de verdad, que es gratis y hace 11 de daño: cada impacto suma
## 8.8 al medidor. Lo unico que hace trampa es saltear el cooldown entre golpe y golpe
## para que la demo dure diez segundos y no uno.
func _charge_demo(player: Player, dummy: Player) -> void:
	if not is_instance_valid(dummy):
		return
	player.ultimate.reset()
	player.stamina.restore_full()
	player.health.revive_full()
	dummy.health.revive_full()
	dummy.status.clear_all()

	# Bien cerca: el golpe basico llega a 3.2m.
	_place(player, dummy.global_position + Vector3(0.0, 0.0, 2.4), 0.0)
	await _wait(0.7)
	await _shot("06c_medidor_vacio")

	for _i: int in range(6):
		player.caster.reset_state()
		player.caster.request_use(0)
		await _wait(0.14)
	await _wait(0.3)
	await _shot("06d_medidor_a_medias")

	# Seguimos pegando hasta que quede listo.
	var guard := 0
	while not player.ultimate.is_ready() and guard < 30:
		player.caster.reset_state()
		player.caster.request_use(0)
		await _wait(0.11)
		guard += 1
	await _wait(0.5)
	await _shot("06e_ultimate_listo")

	dummy.health.revive_full()
	dummy.status.clear_all()
	await _wait(0.3)


## Demo del retroceso: dos capturas desde un costado, antes y despues del impacto.
##
## La camara va PERPENDICULAR a la direccion del golpe. De frente, un objetivo que sale
## despedido hacia atras solo se ve "un poco mas chico" y no se entiende nada.
func _knockback_demo(player: Player, dummy: Player) -> void:
	if not is_instance_valid(dummy):
		return

	# Nos paramos detras del maniqui y le pegamos hacia -Z.
	_place(player, dummy.global_position + Vector3(0.0, 0.0, 5.0), 0.0)
	await _wait(0.6)

	var focus := dummy.global_position + Vector3(0.0, 1.0, 0.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 55.0
	cam.global_position = focus + Vector3(9.5, 2.2, -1.0)
	cam.look_at(focus, Vector3.UP)
	cam.current = true
	await _wait(0.4)
	await _shot("06a_retroceso_antes")

	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)  # Ice Shock: empuja 5.5 con algo de vertical
	await _wait(0.42)
	await _shot("06b_retroceso_despues")

	cam.queue_free()
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.camera.current = true
	# Lo dejamos volver a su marca antes de seguir con el resto.
	await _wait(2.2)


## Primer plano de la cara de un objetivo, con una camara dedicada.
##
## Intente antes acercar la camara del jugador y no sirve: esa camara mira desde ATRAS
## del jugador, asi que por mas que te pegues terminas viendo su nuca. Para revisar una
## cara hay que poner una camara enfrente de la cara.
func _face_closeup(player: Player, target: Player, shot_name: String) -> void:
	if not is_instance_valid(target):
		return
	# Los maniquies miran hacia +Z, asi que la camara va de ese lado.
	var head := target.global_position + Vector3(0.0, 1.78, 0.0)
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 45.0
	cam.global_position = head + Vector3(0.10, 0.04, 1.05)
	cam.look_at(head, Vector3.UP)
	cam.current = true

	await _wait(0.5)
	await _shot(shot_name)

	cam.queue_free()
	if is_instance_valid(player) and is_instance_valid(player.camera_pivot):
		player.camera_pivot.camera.current = true
	await _wait(0.3)


## El kit de Flowery, que es el mas visual de los tres.
func _flowery() -> void:
	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if arena == null or player == null:
		return

	player.setup_character(CharacterDB.get_character(&"flowery"))
	var hud := _find_hud()
	if hud != null:
		hud.bind_player(player)
	_place(player, arena.find_clear_spot(Vector3(-6.0, 0.0, 26.0), 1.5), PI)
	player.health.set_max(3000.0)
	player.status.clear_all()
	await _wait(1.2)
	await _shot("20_flowery_hud")
	# De frente: es donde se ven el flequillo partido, el chaleco abierto y la cara.
	await _face_closeup(player, player, "20b_flowery_de_frente")

	# Un blanco al frente para que los efectos tengan contra que pegar.
	var blanco := _find_dummy(arena)
	if blanco != null:
		_place(blanco, player.global_position - player.global_transform.basis.z * 5.0, 0.0)
		blanco.health.revive_full()
	await _wait(0.4)

	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(0)  # Petalos
	await _wait(0.18)
	await _shot("21_petalos")

	await _wait(0.9)
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)  # JARONA
	await _wait(0.14)
	await _shot("22_jarona")

	await _wait(1.2)
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)  # Here I Come, San Francisco
	await _wait(0.22)
	await _shot("23_here_i_come")

	await _wait(1.6)
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	player.caster.request_use(3)  # LAST JARONA
	await _wait(0.9)
	await _shot("24_canalizando_last_jarona")
	await _wait(0.55)
	await _shot("25_last_jarona")
	await _wait(0.9)
	player.health.set_max(100.0)


## Camara alta mirando al centro, para juzgar el MAPA y no la partida.
##
## Desde la camara del jugador no se puede evaluar un mapa de 92 metros: ves cinco
## metros de piso y una cobertura. Esta vista es la unica forma de ver si el reparto
## de coberturas tiene huecos o si una zona quedo vacia.
func _vista_aerea() -> void:
	var arena := _main.get_node_or_null("Arena") as Arena
	if arena == null:
		return
	var cam := Camera3D.new()
	cam.fov = 62.0
	arena.add_child(cam)
	cam.global_position = Vector3(0.0, 62.0, 66.0)
	cam.look_at(Vector3(0.0, 2.0, 0.0), Vector3.UP)
	cam.make_current()
	await _wait(0.6)
	await _shot("18_mapa_desde_arriba")

	# Y una segunda, mas baja y de costado, que muestra la silueta del mapa.
	cam.global_position = Vector3(48.0, 22.0, 48.0)
	cam.look_at(Vector3(0.0, 3.0, 0.0), Vector3.UP)
	await _wait(0.5)
	await _shot("19_mapa_de_costado")
	cam.queue_free()


## Prende los bots y los deja acercarse, para ver como se ve el modo practica ahora.
func _bots_en_combate() -> void:
	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if arena == null or player == null:
		return

	# Vida alta: la captura tiene que mostrar la pelea, no la pantalla de muerte.
	player.health.set_max(3000.0)
	player.status.clear_all()
	_place(player, arena.find_clear_spot(Vector3(0.0, 0.6, -14.0), 1.5), PI)
	for child: Node in arena.get_children():
		var bot := child as Player
		if bot != null and bot.is_dummy:
			bot.health.revive_full()
			bot.status.clear_all()
	Arena.set_bots_active(true)

	await _wait(2.6)
	await _shot("16_bots_acercandose")
	await _wait(2.2)
	await _shot("17_bots_peleando")
	Arena.set_bots_active(false)


func _place(player: Player, pos: Vector3, yaw: float) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)


func _find_hud() -> HUD:
	for child: Node in _main.get_children():
		var hud := child as HUD
		if hud != null:
			return hud
	return null


func _find_dummy(arena: Arena) -> Player:
	for child: Node in arena.get_children():
		var p := child as Player
		if p != null and p.is_dummy:
			return p
	return null


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, shot_name]
	var err := image.save_png(path)
	if err == OK:
		_shots.append(shot_name)
		print("[visual] captura: ", shot_name)
	else:
		print("[visual] FALLO al guardar ", shot_name, " error ", err)


func _finish() -> void:
	print("[visual] %d capturas guardadas" % _shots.size())
	# Cierre ordenado: cortar musica, volver al menu (libera arena, HUD y todos los
	# nodos de efecto) y recien entonces salir. Llamar a quit() en medio de tweens y
	# particulas vivas hacia que Godot avisara de instancias sin liberar al salir.
	# OJO EL ORDEN: show_main_menu() vuelve a arrancar la musica del menu, asi que
	# hay que pararla DESPUES, no antes.
	Net.leave_game()
	if is_instance_valid(_main) and _main.has_method("show_main_menu"):
		_main.show_main_menu()
	Music.stop(true)
	Sfx.stop_all()
	for _i: int in range(4):
		await get_tree().process_frame
	get_tree().quit(0)
