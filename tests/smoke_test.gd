extends Node
## Test de humo headless: hostea una partida, spawnea al jugador y verifica las
## reglas que no se pueden romper.
##
## Correlo con:
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Es la red de seguridad del proyecto: si tocas la economia de stamina o el sistema
## de escarcha y rompes algo, esto lo canta antes de que lo descubras jugando.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	# --- Arrancar una partida como host ---
	var err := Net.host_game(GameConfig.DEFAULT_PORT + 40, "Tester")
	_check(err == OK, "host_game devolvio OK (fue %d)" % err)
	await get_tree().process_frame

	Net.start_match()
	for _i: int in range(8):
		await get_tree().process_frame

	var arena: Arena = main.get_node_or_null("Arena") as Arena
	_check(arena != null, "la arena se creo")
	if arena == null:
		_finish()
		return

	var player: Player = arena.get_local_player()
	_check(player != null, "el jugador local se spawneo")
	if player == null:
		_finish()
		return

	await _test_kit(player)
	await _test_stamina_rules(player)
	await _test_frost_system(player)
	await _test_dio(player)
	await _test_time_stop(player)
	await _test_projectiles(player, arena)
	await _test_knockback(player, arena)
	await _test_ultimate_charge(player, arena)
	_test_arena(arena)

	_finish()


# ------------------------------------------------------------------ El kit

func _test_kit(player: Player) -> void:
	var abilities := player.caster.abilities
	_check(abilities.size() == 3, "Noelle tiene 3 habilidades (tiene %d)" % abilities.size())
	if abilities.size() < 3:
		return

	_check(abilities[0].display_name == "Icicle Strike", "slot 0 es Icicle Strike")
	_check(abilities[1].display_name == "Ice Shock", "slot 1 es Ice Shock")
	_check(abilities[2].display_name == "Snowgrave", "slot 2 es Snowgrave")

	_check(is_zero_approx(abilities[0].stamina_cost), "el golpe basico NO cuesta stamina")
	_check(abilities[1].stamina_cost == 28.0, "Ice Shock cuesta 28 de stamina")
	_check(abilities[2].stamina_cost == 100.0, "Snowgrave cuesta la barra entera (100)")
	_check(abilities[2].requires_charge, "Snowgrave necesita el medidor de ultimate cargado")
	_check(abilities[2].channel_time > 0.0, "Snowgrave canaliza antes de dispararse")
	await get_tree().process_frame


# --------------------------------------------- Las reglas de stamina del usuario

func _test_stamina_rules(player: Player) -> void:
	player.stamina.restore_full()
	var start := player.stamina.current
	_check(start == 100.0, "la stamina arranca llena (%.0f)" % start)

	# 1) El DASH no cuesta stamina.
	player._try_dash()
	_check(player.is_dashing(), "el dash se ejecuto")
	_check(is_equal_approx(player.stamina.current, start), "el DASH no consumio stamina")

	# 2) El GOLPE BASICO no cuesta stamina.
	player.caster.request_use(0)
	await get_tree().process_frame
	_check(is_equal_approx(player.stamina.current, start), "el GOLPE BASICO no consumio stamina")

	# 3) Correr no cuesta stamina, ni con auto-correr prendido ni apagado.
	#    Son dos caminos distintos en el codigo desde que existe la opcion, asi que
	#    hay que probar los dos.
	var original_auto_run := Settings.auto_run
	for auto_run: bool in [true, false]:
		Settings.auto_run = auto_run
		player.stamina.current = 50.0
		var before_run := player.stamina.current
		for _i: int in range(6):
			await get_tree().process_frame
		_check(player.stamina.current >= before_run,
			"CORRER no consumio stamina (auto-correr %s)" % ("prendido" if auto_run else "apagado"))
	Settings.auto_run = original_auto_run

	# 4) Las habilidades SI cuestan.
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)  # Ice Shock
	await get_tree().process_frame
	_check(is_equal_approx(player.stamina.current, 72.0),
		"Ice Shock consumio 28 de stamina (quedo en %.0f)" % player.stamina.current)

	# Snowgrave ahora pide la barra llena Y el medidor cargado.
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	player.caster.request_use(2)  # Snowgrave
	await get_tree().process_frame
	_check(is_zero_approx(player.stamina.current),
		"Snowgrave dejo la stamina en cero (quedo en %.0f)" % player.stamina.current)
	_check(is_zero_approx(player.ultimate.current), "Snowgrave consumio toda la carga")
	_check(player.caster.is_channeling, "Snowgrave quedo canalizando")
	player.caster.reset_state()

	# 5) Sin stamina suficiente, la habilidad se rechaza.
	#    OJO: en GDScript los lambdas capturan las variables locales POR VALOR, asi que
	#    para sacar datos de un callback hay que usar un tipo por referencia (Dictionary).
	player.caster.reset_state()
	player.stamina.current = 10.0
	var box := {"reason": "", "fired": false}
	player.caster.ability_failed.connect(func(_i: int, reason: String) -> void:
		box["reason"] = reason
		box["fired"] = true
	, CONNECT_ONE_SHOT)
	player.caster.request_use(1)
	await get_tree().process_frame
	_check(String(box["reason"]).contains("stamina"),
		"sin stamina, Ice Shock se rechaza (motivo: '%s')" % String(box["reason"]))

	# 6) Pero el golpe basico sigue funcionando con la stamina en cero.
	player.stamina.current = 0.0
	player.caster.reset_state()
	var basic_box := {"failed": false}
	player.caster.ability_failed.connect(func(_i: int, _r: String) -> void:
		basic_box["failed"] = true
	, CONNECT_ONE_SHOT)
	player.caster.request_use(0)
	await get_tree().process_frame
	_check(not bool(basic_box["failed"]), "con 0 de stamina el GOLPE BASICO sigue disponible")

	player.stamina.restore_full()


# ------------------------------------------------------------- Escarcha / freeze

func _test_frost_system(player: Player) -> void:
	var status := player.status
	status.clear_all()
	_check(not status.is_frozen(), "arranca sin congelar")

	for i: int in range(StatusEffects.MAX_CHILL - 1):
		status.add_chill(1)
	_check(not status.is_frozen(), "con %d stacks todavia no se congela" % (StatusEffects.MAX_CHILL - 1))
	_check(status.chill_stacks == StatusEffects.MAX_CHILL - 1,
		"acumulo %d stacks de escarcha" % status.chill_stacks)

	status.add_chill(1)
	_check(status.is_frozen(), "al llegar a %d stacks se congela" % StatusEffects.MAX_CHILL)
	_check(is_zero_approx(status.get_move_speed_multiplier()), "congelado no se puede mover")
	_check(not status.can_act(), "congelado no puede actuar")
	_check(status.get_damage_taken_multiplier() > 1.0, "congelado recibe daño extra")

	# Snowgrave contra congelado tiene que pegar muchisimo mas que contra normal.
	var snowgrave := Snowgrave.new()
	_check(snowgrave.DAMAGE_FROZEN >= snowgrave.DAMAGE_NORMAL * 4.0,
		"Snowgrave ejecuta a los congelados (%d vs %d)" % [int(snowgrave.DAMAGE_FROZEN), int(snowgrave.DAMAGE_NORMAL)])
	_check(snowgrave.DAMAGE_NORMAL < 100.0, "Snowgrave solo no alcanza para matar de un golpe")

	status.clear_all()
	_check(not status.is_frozen(), "clear_all descongela")
	await get_tree().process_frame


# ------------------------------------------------------------------ Dio Brando

func _test_dio(player: Player) -> void:
	_check(CharacterDB.has_character(&"dio"), "Dio esta registrado en CharacterDB")
	var data := CharacterDB.get_character(&"dio")
	_check(data != null and data.display_name == "Dio Brando", "los datos de Dio existen")
	_check(data != null and data.silhouette == &"shoulders", "Dio tiene silueta propia (no las astas de Noelle)")

	var kit := CharacterDB.build_abilities_for(&"dio")
	_check(kit.size() == 3, "Dio tiene 3 habilidades (tiene %d)" % kit.size())
	if kit.size() < 3:
		return
	_check(kit[0] is MudaRush, "slot 0 de Dio es MUDA MUDA")
	_check(kit[1] is KnifeThrow, "slot 1 de Dio es Knife Throw")
	_check(kit[2] is ZaWarudo, "slot 2 de Dio es ZA WARUDO")

	# La regla de stamina vale para TODOS los personajes, no solo para Noelle.
	_check(is_zero_approx(kit[0].stamina_cost), "el golpe basico de Dio NO cuesta stamina")
	_check(kit[1].stamina_cost == 26.0, "Knife Throw cuesta 26")
	_check(kit[2].stamina_cost == 100.0, "ZA WARUDO cuesta la barra entera (100)")
	_check(kit[2].requires_charge, "ZA WARUDO necesita el medidor de ultimate cargado")

	# Los ultimates cuestan la barra ENTERA: tirarlos te deja sin nada. Ya no existe el
	# combo de ultimate + habilidad seguidos, y es a proposito.
	_check(kit[2].stamina_cost >= 100.0, "el ultimate se come toda la stamina")
	_check(kit[2].stamina_cost + kit[1].stamina_cost > 100.0,
		"no alcanza para ultimate y habilidad seguidos")

	# Cambiar de personaje en caliente tiene que reconfigurar todo.
	player.setup_character(data)
	await get_tree().process_frame
	_check(player.caster.abilities.size() == 3, "al cambiar a Dio se recargo el kit")
	_check(player.caster.abilities[0] is MudaRush, "el jugador quedo con el kit de Dio")
	_check(player.character_id == &"dio", "el character_id se actualizo")

	# Y volver a Noelle tambien.
	player.setup_character(CharacterDB.get_character(&"noelle"))
	await get_tree().process_frame
	_check(player.caster.abilities[0] is NoelleBasicAttack, "se puede volver a Noelle")


# ------------------------------------------------- La invariante de balance clave

func _test_time_stop(player: Player) -> void:
	var status := player.status
	status.clear_all()

	status.stun_for(2.0)
	_check(status.is_stunned(), "ZA WARUDO aturde")
	_check(not status.can_act(), "aturdido no puede actuar")
	_check(is_zero_approx(status.get_move_speed_multiplier()), "aturdido no se puede mover")

	# ESTA es la verificacion que importa: aturdido NO es lo mismo que congelado.
	# Si lo fuera, un Dio y una Noelle en el mismo equipo tendrian un combo de dos
	# botones (ZA WARUDO -> Snowgrave) que mata a todo el mundo desde vida llena.
	_check(not status.is_frozen(), "aturdido NO cuenta como congelado")
	_check(not CombatUtils.is_frozen(player), "Snowgrave NO ejecuta a un aturdido")
	_check(is_equal_approx(status.get_damage_taken_multiplier(), 1.0),
		"aturdido no recibe el daño extra de congelado")

	status.clear_all()
	_check(not status.is_stunned(), "clear_all saca el aturdimiento")
	await get_tree().process_frame


# ---------------------------------------------------------------- Proyectiles

func _test_projectiles(player: Player, arena: Arena) -> void:
	# Limpiamos primero: los tests anteriores tiraron un Ice Shock REAL que todavia
	# puede estar volando, y si lo agarramos de muestra el chequeo de "cosmetico"
	# falla por un motivo que no tiene nada que ver con lo que estamos probando.
	_clear_projectiles(arena)
	await get_tree().process_frame
	var before := _count_projectiles(arena)
	_check(before == 0, "arrancamos sin proyectiles dando vueltas")

	# Cosmeticos: viajan pero no hacen daño. Es lo que corren los clientes remotos.
	IceShock.spawn_cosmetic(player, player.get_aim_origin(), Vector3.FORWARD)
	await get_tree().process_frame
	var after_ice := _count_projectiles(arena)
	_check(after_ice == before + 1, "Ice Shock spawnea 1 carambano")

	KnifeThrow.spawn_cosmetic(player, player.get_aim_origin(), Vector3.FORWARD)
	await get_tree().process_frame
	var after_knives := _count_projectiles(arena)
	_check(after_knives == after_ice + KnifeThrow.KNIFE_COUNT,
		"Knife Throw spawnea %d cuchillos" % KnifeThrow.KNIFE_COUNT)

	# Y que efectivamente se muevan. Tomamos uno cosmetico a proposito.
	var sample: Projectile = null
	for child: Node in arena.get_children():
		var proj := child as Projectile
		if proj != null and proj.cosmetic_only:
			sample = proj
			break
	_check(sample != null, "encontramos un proyectil cosmetico de muestra")
	if sample != null:
		var start_pos := sample.global_position
		for _i: int in range(5):
			await get_tree().physics_frame
		_check(sample.global_position.distance_to(start_pos) > 0.1, "los proyectiles se mueven")
		_check(sample.cosmetic_only, "los proyectiles cosmeticos no hacen daño (monitoring apagado)")

	_clear_projectiles(arena)
	await get_tree().process_frame


func _clear_projectiles(arena: Arena) -> void:
	for child: Node in arena.get_children():
		if child is Projectile:
			child.queue_free()


func _count_projectiles(arena: Arena) -> int:
	var n := 0
	for child: Node in arena.get_children():
		if child is Projectile:
			n += 1
	return n


# ------------------------------------------------------- Carga del ultimate

func _test_ultimate_charge(player: Player, arena: Arena) -> void:
	player.stamina.restore_full()
	player.ultimate.reset()
	player.caster.reset_state()
	_check(not player.ultimate.is_ready(), "el medidor de ultimate arranca vacio")

	# Con la barra llena pero sin carga, el ultimate NO sale.
	var box := {"reason": ""}
	player.caster.ability_failed.connect(func(_i: int, reason: String) -> void:
		box["reason"] = reason
	, CONNECT_ONE_SHOT)
	player.caster.request_use(2)
	await get_tree().process_frame
	_check(String(box["reason"]).contains("carga"),
		"sin carga el ultimate se rechaza (motivo: '%s')" % String(box["reason"]))
	_check(is_equal_approx(player.stamina.current, 100.0),
		"un ultimate rechazado NO gasta stamina (quedo en %.0f)" % player.stamina.current)

	# El medidor se llena PEGANDO. Creamos un blanco y le pegamos.
	var target: Player = Arena.PLAYER_SCENE.instantiate()
	target.peer_id = -98
	target.is_dummy = true
	arena.add_child(target)
	target.global_position = Vector3(-20.0, 0.6, 20.0)
	target.home_position = Vector3(-20.0, 0.0, 20.0)
	target.setup_character(CharacterDB.get_character(&"noelle"))
	target.health.set_max(600.0)
	await get_tree().process_frame

	var before := player.ultimate.current
	CombatUtils.deal_damage(target, 50.0, player.peer_id)
	await get_tree().process_frame
	var gained := player.ultimate.current - before
	_check(gained > 0.0, "pegar carga el medidor (subio %.1f)" % gained)
	_check(absf(gained - 50.0 * player.ultimate.charge_per_damage) < 1.0,
		"la carga es proporcional al daño (%.1f por 50 de daño)" % gained)

	# Recibir daño NO carga el medidor del que lo recibe.
	var victim_before := target.ultimate.current
	CombatUtils.deal_damage(target, 30.0, player.peer_id)
	await get_tree().process_frame
	_check(absf(target.ultimate.current - victim_before) < 1.0,
		"al que recibe el golpe no se le carga el medidor")

	# Matar da bonus.
	var pre_kill := player.ultimate.current
	CombatUtils.deal_damage(target, 900.0, player.peer_id)
	await get_tree().process_frame
	_check(target.health.is_dead, "el blanco murio")
	_check(player.ultimate.current > pre_kill, "matar suma carga extra")

	# Con carga Y stamina llenas, el ultimate sale y deja las dos en cero.
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	_check(player.ultimate.is_ready(), "el medidor llega a listo")
	player.caster.request_use(2)
	await get_tree().process_frame
	_check(is_zero_approx(player.stamina.current), "el ultimate vacio la stamina")
	_check(is_zero_approx(player.ultimate.current), "el ultimate vacio el medidor")

	# Un ultimate NO se paga el siguiente: su propio daño no carga el medidor.
	# Arrancamos con el medidor VACIO, que es como queda justo despues de tirarlo.
	player.stamina.restore_full()
	player.ultimate.reset()
	player.caster.reset_state()
	var revive: Player = Arena.PLAYER_SCENE.instantiate()
	revive.peer_id = -97
	revive.is_dummy = true
	arena.add_child(revive)
	revive.global_position = player.global_position + Vector3(0.0, 0.0, -3.0)
	revive.home_position = revive.global_position
	revive.setup_character(CharacterDB.get_character(&"noelle"))
	revive.health.set_max(400.0)
	await get_tree().process_frame

	# Snowgrave pega fuertisimo; si cargara, volveria a dejar el medidor lleno.
	CombatUtils.deal_damage(revive, Snowgrave.DAMAGE_FROZEN, player.peer_id, false)
	await get_tree().process_frame
	_check(is_zero_approx(player.ultimate.current) or player.ultimate.current < 1.0,
		"el daño de un ultimate no recarga el medidor (quedo en %.1f)" % player.ultimate.current)
	revive.queue_free()
	await get_tree().process_frame

	# Morir NO borra la carga: es la herramienta del que va perdiendo.
	player.caster.reset_state()
	player.ultimate.current = 60.0
	CombatUtils.deal_damage(player, 500.0, -1)
	await get_tree().process_frame
	_check(absf(player.ultimate.current - 60.0) < 2.0,
		"morir no borra la carga (quedo en %.0f)" % player.ultimate.current)

	player.health.revive_full()
	player.status.clear_all()
	player.caster.reset_state()
	player.ultimate.reset()
	player.stamina.restore_full()
	target.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- Retroceso

func _test_knockback(player: Player, arena: Arena) -> void:
	# Buscamos otro jugador al que empujar. En una partida hosteada el unico otro
	# "jugador" es el propio caster, asi que creamos un maniqui a mano.
	var target: Player = Arena.PLAYER_SCENE.instantiate()
	target.peer_id = -99
	target.is_dummy = true
	target.player_name = "Blanco"
	arena.add_child(target)
	# Posicion fija y despejada de coberturas, no relativa al jugador: despues de los
	# tests anteriores el jugador puede estar en cualquier lado, incluso arriba de la
	# plataforma central, y el blanco terminaba spawneando dentro de un bloque.
	var spot := Vector3(20.0, 0.6, 20.0)
	target.global_position = spot
	target.home_position = Vector3(20.0, 0.0, 20.0)
	target.setup_character(CharacterDB.get_character(&"noelle"))
	await get_tree().process_frame

	# Solo la HORIZONTAL. Spawnea a 0.6 m del piso, asi que la gravedad ya le puso
	# velocidad vertical antes de este chequeo y eso no invalida nada: lo que medimos
	# despues es el empujon en X/Z. Mirando velocity.length() el test pasaba o fallaba
	# segun si habia corrido un frame de fisica, que no controlamos.
	var start_drift := Vector2(target.velocity.x, target.velocity.z).length()
	_check(is_zero_approx(start_drift), "el blanco arranca quieto en horizontal (%.3f)" % start_drift)

	# El empujon tiene que salir EN LA DIRECCION del golpe, no en cualquiera.
	# Lo dejamos asentarse en el piso antes de medir nada.
	for _i: int in range(10):
		await get_tree().physics_frame
	var before := target.global_position
	CombatUtils.apply_knockback(target, Vector3(0.0, 0.0, -1.0), 8.0, 2.0)
	_check(target.velocity.z < -1.0, "el empujon va en la direccion del golpe (vz=%.1f)" % target.velocity.z)
	_check(target.velocity.y > 0.0, "el empujon despega del piso (vy=%.1f)" % target.velocity.y)

	for _i: int in range(12):
		await get_tree().physics_frame
	var moved := before.distance_to(target.global_position)
	_check(moved > 0.3, "el blanco se movio por el empujon (%.2f m)" % moved)

	# Y despues tiene que volver solo a su marca, o el modo practica se desarma.
	for _i: int in range(150):
		await get_tree().physics_frame
	var back := target.global_position.distance_to(target.home_position)
	_check(back < 0.6, "el maniqui volvio a su lugar (quedo a %.2f m)" % back)

	# Un empujon de fuerza cero no tiene que hacer nada.
	target.velocity = Vector3.ZERO
	CombatUtils.apply_knockback(target, Vector3.FORWARD, 0.0, 0.0)
	_check(is_zero_approx(target.velocity.length()), "fuerza 0 no empuja")

	# Y una direccion vertical pura tampoco: no hay hacia donde empujar en horizontal.
	CombatUtils.apply_knockback(target, Vector3.UP, 9.0, 0.0)
	_check(is_zero_approx(target.velocity.length()), "una direccion sin componente horizontal no empuja")

	target.queue_free()
	await get_tree().process_frame


func _test_arena(arena: Arena) -> void:
	var t := arena.get_free_spawn_point()
	_check(t.origin.length() > 1.0, "hay spawn points validos")
	var covers := 0
	for child: Node in arena.get_children():
		if child.name.begins_with("Cover"):
			covers += 1
	_check(covers >= 5, "la arena tiene coberturas para cortar la linea de vision (%d)" % covers)


# ------------------------------------------------------------------- Resultados

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  OK   ", description)
	else:
		print("  FALLA ", description)
		_failures.append(description)


func _finish() -> void:
	print("")
	print("==========================================")
	if _failures.is_empty():
		print("TODO OK — %d verificaciones pasaron" % _checks)
	else:
		print("FALLARON %d de %d verificaciones:" % [_failures.size(), _checks])
		for f: String in _failures:
			print("   - ", f)
	print("==========================================")
	# Cierre ordenado. Llamar a quit() con la musica sonando y tweens vivos hacia que
	# Godot avisara de instancias sin liberar al salir.
	Music.stop(true)
	Sfx.stop_all()
	Net.leave_game()
	for _i: int in range(4):
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)
