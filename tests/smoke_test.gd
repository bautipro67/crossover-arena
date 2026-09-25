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

## Un peer que no es de nadie. POSITIVO a proposito: con uno negativo, deal_damage lo
## tomaria por un bot y le aplicaria la rebaja de daño del modo practica, que es lo que
## ya rompio una vez el chequeo del escudo.
const FUENTE_NEUTRA: int = 99

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
	await _test_economia_stamina(player, arena)
	await _test_defensa_de_hielo(player, arena)
	await _test_rafaga_del_stand(player, arena)
	await _test_flowery(player, arena)
	Arena.set_bots_active(true)
	await _test_rick(player, arena)
	await _test_sonic(player, arena)
	await _test_goku(player, arena)
	await _test_mario(player, arena)
	await _test_madara(player, arena)
	_test_descripciones()
	await _test_escena_corta_habilidades(player)
	await _test_practica(player, arena)
	await _test_arena(arena)

	_finish()


# ------------------------------------------------------------------ El kit

func _test_kit(player: Player) -> void:
	var abilities := player.caster.abilities
	_check(abilities.size() == 4, "Noelle tiene 4 habilidades (tiene %d)" % abilities.size())
	if abilities.size() < 4:
		return

	# El orden del array ES el de las teclas y el del HUD. El ultimate va ultimo.
	_check(abilities[0].display_name == "Icicle Strike", "slot 0 es Icicle Strike")
	_check(abilities[1].display_name == "Ice Shock", "slot 1 es Ice Shock")
	_check(abilities[2].display_name == "Defensa de Hielo", "slot 2 es Defensa de Hielo")
	_check(abilities[3].display_name == "Snowgrave", "slot 3 es Snowgrave")
	_check(abilities[3].requires_charge, "el ultimate es el ultimo del kit")

	_check(is_zero_approx(abilities[0].stamina_cost), "el golpe basico NO cuesta stamina")
	_check(abilities[1].stamina_cost == 28.0, "Ice Shock cuesta 28 de stamina")
	_check(abilities[2].stamina_cost == 30.0, "la Defensa de Hielo cuesta 30")
	_check(abilities[3].stamina_cost == 100.0, "Snowgrave cuesta la barra entera (100)")
	_check(abilities[3].requires_charge, "Snowgrave necesita el medidor de ultimate cargado")
	_check(abilities[3].channel_time > 0.0, "Snowgrave canaliza antes de dispararse")
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
	player.caster.request_use(3)  # Snowgrave, ahora en el slot 3
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
	_check(kit.size() == 4, "Dio tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is MudaRush, "slot 0 de Dio es MUDA MUDA")
	_check(kit[1] is KnifeThrow, "slot 1 de Dio es Knife Throw")
	_check(kit[2] is StandBarrage, "slot 2 de Dio es la Rafaga del Stand")
	_check(kit[3] is ZaWarudo, "slot 3 de Dio es ZA WARUDO")

	# La regla de stamina vale para TODOS los personajes, no solo para Noelle.
	_check(is_zero_approx(kit[0].stamina_cost), "el golpe basico de Dio NO cuesta stamina")
	_check(kit[1].stamina_cost == 26.0, "Knife Throw cuesta 26")
	_check(kit[3].stamina_cost == 100.0, "ZA WARUDO cuesta la barra entera (100)")
	_check(kit[3].requires_charge, "ZA WARUDO necesita el medidor de ultimate cargado")

	# Los ultimates cuestan la barra ENTERA: tirarlos te deja sin nada. Ya no existe el
	# combo de ultimate + habilidad seguidos, y es a proposito.
	_check(kit[3].stamina_cost >= 100.0, "el ultimate se come toda la stamina")
	_check(kit[3].stamina_cost + kit[1].stamina_cost > 100.0,
		"no alcanza para ultimate y habilidad seguidos")

	# Cambiar de personaje en caliente tiene que reconfigurar todo.
	player.setup_character(data)
	await get_tree().process_frame
	_check(player.caster.abilities.size() == 4, "al cambiar a Dio se recargo el kit")
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

	# --- Y DIO LO ANUNCIA, EN DOS TIEMPOS ---
	#
	# "ZA WARUDO" y despues "toki yo tomare" (tiempo, detente) son dos frases separadas
	# por una pausa, no una sola: en el original el tiempo se para ENTRE las dos. Aca eso
	# calza con el canalizado de la habilidad, asi que la pausa no es un efecto agregado
	# sino el segundo que el rival ya tenia para reaccionar.
	player.setup_character(CharacterDB.get_character(&"dio"))
	player.stamina.restore_full()
	player.caster.reset_state()
	player.ultimate.add_from_damage(99999.0)  # ZA WARUDO es el ultimate: hay que cargarlo
	player.caster.request_use(3)  # ZA WARUDO
	var dichas: Dictionary = {}
	# VENTANA LARGA, y hace falta desde que los sonidos pueden ser grabaciones.
	#
	# La segunda frase ya no sale a los 0.75 s fijos: espera a que termine de sonar la
	# primera, que es lo correcto —el "ZA WARUDO" grabado dura 1.8 s y antes la orden le
	# caia encima— pero significa que su momento lo decide el archivo. Con los 2.5 s de
	# antes el test se quedaba corto y reportaba que Dio decia una sola frase.
	for _i: int in range(360):
		await get_tree().physics_frame
		var burbuja := player.get_node_or_null(^"GritoFrase") as Label3D
		if burbuja != null:
			dichas[burbuja.get_instance_id()] = burbuja.text
	var frases_dio: Array = dichas.values()
	_check(frases_dio.size() >= 2,
		"Dio dice sus dos frases al parar el tiempo (dijo %d)" % frases_dio.size())
	_check(frases_dio.has("¡ZA WARUDO!") and frases_dio.has("¡TOKI YO TOMARE!"),
		"y son las del original, en orden: %s" % str(frases_dio))
	player.status.clear_all()
	player.stamina.restore_full()


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

	# --- Y QUE LE PEGUEN A ALGUIEN ---
	#
	# Este chequeo faltaba y es el unico que importa de verdad. Todo lo de arriba mide
	# que el proyectil NAZCA y SE MUEVA; con eso pasa en verde un proyectil que atraviesa
	# jugadores y paredes sin tocarlos, que es exactamente lo que estaba pasando.
	# EL BLANCO SE PONE EN UN CARRIL LIBRE Y SE FIJA EL APUNTADO.
	#
	# La primera version lo puso hacia -basis.z del jugador y disparo con la mira de la
	# camara, que apuntaba a otro lado: el proyectil paso a 6.77 metros del blanco y el
	# chequeo fallaba por como estaba armado. Y el blanco caia en z=-52, fuera del mapa,
	# porque _spawn_dummy no recorta a los limites de la arena.
	var sitio := arena.find_clear_spot(Vector3(0.0, 0.6, 0.0), 1.5)
	var linea := _carril_libre(player, sitio, 12.0)
	player.respawn_at(sitio, atan2(-linea.x, -linea.z))
	for _i: int in range(6):
		await get_tree().physics_frame
	var blanco2 := _spawn_dummy(arena, sitio + linea * 7.0)
	blanco2.health.set_max(2000.0)
	player.aim_override = linea
	await get_tree().process_frame

	var vida_blanco := blanco2.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	for _i: int in range(90):
		await get_tree().physics_frame
	player.aim_override = Vector3.ZERO
	_check(blanco2.health.current < vida_blanco,
		"y un proyectil le PEGA al que tiene enfrente (le saco %.0f)" % (vida_blanco - blanco2.health.current))
	blanco2.queue_free()
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
	player.caster.request_use(3)
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
	player.caster.request_use(3)
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


# ------------------------------------------------------- Economia de stamina

## La regla nueva: la stamina se regenera despacio, pero PEGAR la devuelve.
func _test_economia_stamina(player: Player, arena: Arena) -> void:
	var target := _spawn_dummy(arena, arena.find_clear_spot(Vector3(30.0, 0.6, 30.0)))
	await get_tree().process_frame

	_check(player.stamina.regen_per_second <= 10.0,
		"la regeneracion pasiva es lenta (%.0f/s)" % player.stamina.regen_per_second)

	# Gastamos y medimos cuanto devuelve un golpe.
	player.stamina.restore_full()
	player.stamina.predict_spend(60.0)
	var before := player.stamina.current
	CombatUtils.deal_damage(target, 40.0, player.peer_id)
	await get_tree().process_frame
	var gained := player.stamina.current - before
	_check(gained > 0.0, "pegar devuelve stamina (subio %.1f)" % gained)
	_check(absf(gained - 40.0 * player.stamina.restore_per_damage) < 1.5,
		"lo que devuelve es proporcional al daño (%.1f por 40)" % gained)

	# Y tiene que pagar TAMBIEN durante la pausa post-gasto: si no, castearia y
	# quedarias sin recurso justo cuando entras a pelear.
	player.stamina.current = 10.0
	player.stamina.try_spend(5.0)  # arranca el bloqueo de regeneracion
	var blocked_before := player.stamina.current
	CombatUtils.deal_damage(target, 30.0, player.peer_id)
	await get_tree().process_frame
	_check(player.stamina.current > blocked_before,
		"el golpe paga aunque la regeneracion este en pausa")

	# El daño de un ULTIMATE no paga: ni stamina ni medidor.
	player.stamina.current = 20.0
	var ult_before := player.stamina.current
	CombatUtils.deal_damage(target, 200.0, player.peer_id, false)
	await get_tree().process_frame
	_check(absf(player.stamina.current - ult_before) < 0.5,
		"el daño de un ultimate NO devuelve stamina (quedo en %.0f)" % player.stamina.current)

	# Al que le pegan no le devuelve nada.
	var victim_before := target.stamina.current
	CombatUtils.deal_damage(target, 25.0, player.peer_id)
	await get_tree().process_frame
	_check(target.stamina.current <= victim_before + 0.5,
		"recibir golpes no devuelve stamina")

	target.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------- Defensa de Hielo

func _test_defensa_de_hielo(player: Player, arena: Arena) -> void:
	player.setup_character(CharacterDB.get_character(&"noelle"))
	# Lo revivimos de verdad: un test anterior lo mata y queda sin collider.
	player.respawn_at(arena.find_clear_spot(Vector3(-30.0, 0.6, -30.0)), 0.0)
	for _i: int in range(4):
		await get_tree().physics_frame

	var shield_ability := player.caster.abilities[2]
	_check(shield_ability is IceDefense, "el slot 2 de Noelle es la Defensa de Hielo")

	var enemy := _spawn_dummy(arena, player.global_position + Vector3(2.0, 0.0, 0.0))
	await get_tree().process_frame

	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	await get_tree().process_frame

	_check(player.health.shield > 0.0,
		"levantar la defensa da escudo (%.0f)" % player.health.shield)
	_check(enemy.status.chill_stacks > 0,
		"la rafaga de frio escarcha a los que estan cerca (%d)" % enemy.status.chill_stacks)

	# El escudo se come el golpe ANTES que la vida.
	#
	# OJO CON LA FUENTE DEL DAÑO: un peer NEGATIVO es un bot, y a los bots se les aplica
	# GameConfig.BOT_DAMAGE_SCALE. Usando enemy.peer_id (-77) estos numeros salian a la
	# mitad y el "golpe grande" ya no reventaba el escudo. Aca se prueba la mecanica del
	# escudo, no el balance de los bots, asi que el golpe viene de un peer neutro.
	var hp_before := player.health.current
	var shield_before := player.health.shield
	CombatUtils.deal_damage(player, 20.0, FUENTE_NEUTRA)
	await get_tree().process_frame
	_check(is_equal_approx(player.health.current, hp_before),
		"con escudo, un golpe chico no toca la vida (%.0f)" % player.health.current)
	_check(player.health.shield < shield_before,
		"el escudo bajo en vez de la vida (%.0f -> %.0f)" % [shield_before, player.health.shield])

	# Y el sobrante de un golpe grande SI pasa a la vida: un escudo de 5 no puede
	# anular un Snowgrave de 260.
	var resto := player.health.shield + 30.0
	var hp_antes := player.health.current
	CombatUtils.deal_damage(player, resto, FUENTE_NEUTRA)
	await get_tree().process_frame
	_check(is_zero_approx(player.health.shield), "un golpe grande revienta el escudo")
	_check(player.health.current < hp_antes,
		"el sobrante pasa a la vida (%.0f -> %.0f)" % [hp_antes, player.health.current])

	# Respawnear lo limpia.
	player.health.revive_full()
	await get_tree().process_frame
	_check(is_zero_approx(player.health.shield), "revivir limpia el escudo")

	enemy.queue_free()
	await get_tree().process_frame


# ------------------------------------------------------- Rafaga del Stand

func _test_rafaga_del_stand(player: Player, arena: Arena) -> void:
	player.setup_character(CharacterDB.get_character(&"dio"))
	await get_tree().process_frame

	var barrage := player.caster.abilities[2]
	_check(barrage is StandBarrage, "el slot 2 de Dio es la Rafaga del Stand")

	# Posiciones FIJAS y despejadas, no relativas a donde quedo el jugador. Despues de
	# los tests anteriores puede estar en cualquier lado (arriba de la plataforma, contra
	# una cobertura) y el blanco terminaba fuera del cono o detras de un bloque.
	#
	# SIEMPRE respawn_at() para reubicar al jugador en un test, nunca global_position.
	#
	# Dos razones, las dos aprendidas rompiendo este test:
	#   - morir DESACTIVA el collider, y solo respawn_at lo vuelve a activar. Un test
	#     anterior mata al jugador, asi que teletransportarlo a mano lo dejaba cayendo
	#     por el piso: la rafaga tiraba los seis golpes desde -6 metros de altura.
	#   - el cuerpo copia el yaw de la CAMARA en cada frame de fisica, asi que tocar
	#     rotation.y solo dura un frame. respawn_at fija los dos.
	# Un hueco libre con dos metros de margen para los dos cuerpos, pedido a la arena.
	var libre := arena.find_clear_spot(Vector3(22.0, 0.6, 26.0), 2.2)
	player.respawn_at(Vector3(libre.x, 0.6, libre.z + 2.0), 0.0)
	for _i: int in range(6):
		await get_tree().physics_frame
	var enemy := _spawn_dummy(arena, Vector3(libre.x, 0.6, libre.z))
	for _i: int in range(4):
		await get_tree().physics_frame

	var hp_before := enemy.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)

	# Un solo frame: todavia no puede haber pegado los seis golpes.
	await get_tree().process_frame
	var tras_primero := hp_before - enemy.health.current

	# Esperamos a que termine la rafaga entera.
	await get_tree().create_timer(StandBarrage.TICKS * StandBarrage.TICK_INTERVAL + 0.4).timeout
	var total := hp_before - enemy.health.current

	_check(tras_primero > 0.0, "el primer golpe pega al instante (%.0f)" % tras_primero)
	_check(total > tras_primero * 2.0,
		"la rafaga sigue pegando en el tiempo (%.0f al final vs %.0f al principio)" % [total, tras_primero])
	# Contra un blanco quieto tienen que entrar CASI TODOS. Este numero es el que
	# detecta la regresion que ya tuvimos: si el empujon por golpe crece, la rafaga se
	# saca al rival de encima sola y la mitad pega al aire.
	_check(total >= StandBarrage.DAMAGE_PER_TICK * (StandBarrage.TICKS - 1),
		"contra un blanco quieto entran casi todos los golpes (%.0f de %.0f)" % [
			total, StandBarrage.DAMAGE_PER_TICK * StandBarrage.TICKS])

	enemy.queue_free()
	await get_tree().process_frame


## Devuelve una direccion horizontal con `largo` metros despejados desde `desde`.
##
## Existe por la misma razon que Arena.find_clear_spot: cualquier direccion escrita a
## mano deja de estar libre en cuanto alguien mueve una cobertura.
func _carril_libre(contexto: Node3D, desde: Vector3, largo: float) -> Vector3:
	var space := contexto.get_world_3d().direct_space_state
	var mejor := Vector3.FORWARD
	var mejor_dist := -1.0
	for i: int in range(12):
		var ang := TAU * float(i) / 12.0
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var origen := desde + Vector3.UP * 1.0
		var query := PhysicsRayQueryParameters3D.create(origen, origen + dir * largo)
		query.collision_mask = GameConfig.LAYER_WORLD
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return dir
		# Ninguna totalmente libre: nos quedamos con la mas despejada.
		var d: float = origen.distance_to(hit["position"])
		if d > mejor_dist:
			mejor_dist = d
			mejor = dir
	return mejor


## Maniqui en una posicion despejada, listo para recibir.
func _spawn_dummy(arena: Arena, at: Vector3) -> Player:
	var dummy: Player = Arena.PLAYER_SCENE.instantiate()
	dummy.peer_id = -77
	dummy.is_dummy = true
	dummy.player_name = "Blanco"
	arena.add_child(dummy)
	dummy.global_position = at
	dummy.home_position = Vector3(at.x, 0.0, at.z)
	dummy.setup_character(CharacterDB.get_character(&"noelle"))
	return dummy


# ----------------------------------------------------------------- Flowery

## Vuelve a plantar a Flowery en su marca con la victima justo adelante.
##
## HACE FALTA ANTES DE CADA SUB-CHEQUEO, y aprendido por las malas. Las embestidas
## encadenadas lo dejan a cuarenta metros y mirando para cualquier lado, asi que poner a
## la victima con el `rumbo` del arranque la dejaba DETRAS suyo. El chequeo del
## canalizado fallaba asi: Jarona embestia perfecto, nada mas que para el lado contrario
## —el jugador apuntaba a (-0.76, 0.64) y la victima estaba en (+0.87, +0.50)—.
##
## La espera de 24 frames no es de mas: la direccion de la embestida sale de un rayo que
## arranca EN LA CAMARA, y el brazo de la camara tarda varios frames en acomodarse
## despues de un respawn.
func _plantar_flowery(player: Player, victima: Player, puesto: Vector3, rumbo: Vector3,
		distancia: float) -> void:
	var yaw := atan2(-rumbo.x, -rumbo.z)
	player.respawn_at(puesto, yaw)
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)
	player.status.clear_all()
	victima.global_position = puesto + rumbo * distancia
	victima.velocity = Vector3.ZERO
	victima.health.revive_full()
	victima.status.clear_all()
	for _i: int in range(24):
		await get_tree().physics_frame


func _test_flowery(player: Player, arena: Arena) -> void:
	# LOS BOTES AFUERA, Y NO ES UN PARCHE COSMETICO.
	#
	# Las embestidas de Flowery encadenadas recorren mas de cien metros en un mapa de
	# noventa y dos, asi que lo llevan derecho encima de los tres bots de practica. Con
	# los bots prendidos el jugador se moria A MITAD de JARONA y respawneaba en un punto
	# de spawn, y el chequeo del canalizado fallaba porque el que tenia que atropellar a
	# la victima estaba en la otra punta del mapa. El bug no era de la habilidad.
	#
	# (Que los bots maten a alguien que les pasa por al lado es exactamente lo que se
	# les pidio; el problema es medir a Flowery con ellos encima.)
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()

	# Y SE ESPERA UN RESPAWN AJENO ANTES DE MEDIR NADA.
	#
	# _test_ultimate_charge mata al jugador a proposito —para comprobar que morir no
	# borra el medidor— y eso deja un respawn programado a 4 segundos. Esos 4 segundos
	# vencian justo en la TERCERA PASADA de JARONA: el jugador aparecia de golpe en un
	# punto de spawn a setenta metros, y "cuanto lo mueve la embestida" daba 103 metros
	# de embestida que nunca existio. El chequeo pasaba en verde midiendo un
	# teletransporte.
	await get_tree().create_timer(GameConfig.RESPAWN_DELAY + 0.5).timeout

	_check(CharacterDB.has_character(&"flowery"), "Flowery esta registrada")
	var data := CharacterDB.get_character(&"flowery")
	_check(data != null and data.origin_game == "Deltarune", "Flowery viene de Deltarune")
	_check(data != null and data.silhouette == &"petals",
		"Flowery tiene silueta propia (no las astas ni las hombreras)")

	var kit := CharacterDB.build_abilities_for(&"flowery")
	_check(kit.size() == 4, "Flowery tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is PetalShot, "slot 0 es Petalos")
	_check(kit[1] is Jarona, "slot 1 es JARONA")
	_check(kit[2] is HereICome, "slot 2 es Here I Come, San Francisco")
	_check(kit[3] is LastJarona, "slot 3 es LAST JARONA")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")
	_check(kit[3].stamina_cost == 100.0 and kit[3].requires_charge,
		"el ultimate cuesta la barra entera Y el medidor")

	player.setup_character(data)
	# La carga necesita PISTA: un punto libre no alcanza si la pared esta a dos metros.
	# La primera version la puso pegada a una cobertura, cargaba 2.6 de los 13 metros y
	# el test fallaba por la colocacion, no por la habilidad.
	var puesto := arena.find_clear_spot(Vector3(-30.0, 0.6, 30.0), 1.5)
	var rumbo := _carril_libre(player, puesto, 16.0)
	player.respawn_at(puesto, atan2(-rumbo.x, -rumbo.z))
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(atan2(-rumbo.x, -rumbo.z))
	# ESPERA LARGA, y hace falta.
	#
	# La direccion de la carga sale de get_aim_direction(), que lanza un rayo DESDE LA
	# CAMARA. Despues de un respawn el brazo de la camara tarda varios frames en
	# acomodarse, y si se pregunta antes el rayo sale de una posicion vieja: el test
	# alternaba entre cargar 15 metros y cargar 1.7 segun cuando cayera la medicion.
	for _i: int in range(24):
		await get_tree().physics_frame

	# --- JARONA: embestida que REBOTA y vuelve ---
	#
	# Es la mecanica central y la que la hace distinta de cualquier otro golpe: su
	# duracion la decide el rival. Si te quedas en el camino te pasa por encima varias
	# veces; si te corres, la primera pasada al aire lo deja plantado.
	var victima := _spawn_dummy(arena, player.global_position + rumbo * 5.0)
	victima.setup_character(CharacterDB.get_character(&"noelle"))
	victima.caster.owner_peer_id = Net.local_id()
	victima.health.set_max(3000.0)
	await get_tree().process_frame

	var vida_antes := victima.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)  # JARONA

	# SE MIDE EL CAMINO RECORRIDO, NO EL DESPLAZAMIENTO NETO.
	#
	# La embestida rebota y reapunta, o sea que OSCILA alrededor del rival: arranca y
	# termina casi en el mismo punto aunque haya recorrido treinta metros. Midiendo
	# "distancia entre el inicio y el final" daba 2.9 m y parecia que no se habia movido.
	#
	# Y el salto por frame es mejor detector de teletransporte que un tope de distancia
	# total: a 30 m/s un frame son 50 cm, asi que cualquier salto de metros es un
	# teletransporte y no una carrera. Antes esto se cubria con un tope a la distancia
	# total, que un respawn ajeno ya habia burlado una vez.
	#
	# La ventana son 6 segundos y hacen falta: cada pasada son 0.58s entre ida, rebote y
	# pausa, asi que con los 2.5s de antes entraban cuatro y el test no podia distinguir
	# "se corto sola a las cuatro" de "se acabo el tiempo de mirar".
	var recorrido := 0.0
	var salto_max := 0.0
	var gritos: Dictionary = {}
	var previo := player.global_position
	for _i: int in range(360):
		await get_tree().physics_frame
		# Cuantas veces grito. Se cuentan INSTANCIAS distintas y no apariciones, porque
		# la burbuja se reemplaza a si misma: la misma que ya estaba no es un grito nuevo.
		var burbuja := player.get_node_or_null(^"GritoFrase") as Label3D
		if burbuja != null:
			gritos[burbuja.get_instance_id()] = burbuja.text
		# EL JUGADOR APUNTA AL RIVAL, porque ahora la cadena depende de eso.
		#
		# Cada rebote sale hacia donde mira el jugador, no hacia el rival mas cercano.
		# Sin nadie apuntando, la cadena se corta sola a las dos pasadas —que es el
		# comportamiento correcto— y el chequeo medía a un jugador que no jugaba.
		if is_instance_valid(victima):
			var hacia: Vector3 = victima.global_position - player.global_position
			hacia.y = 0.0
			if not hacia.is_zero_approx():
				player.aim_override = hacia.normalized()
		var paso := previo.distance_to(player.global_position)
		recorrido += paso
		salto_max = maxf(salto_max, paso)
		previo = player.global_position
	player.aim_override = Vector3.ZERO
	var daño := vida_antes - victima.health.current
	_check(recorrido > 12.0,
		"JARONA es una embestida: recorre camino (%.1f m)" % recorrido)
	_check(salto_max < 5.0,
		"y lo recorre embistiendo, no teletransportandose (salto maximo %.2f m)" % salto_max)
	_check(daño >= Jarona.DAMAGE * 1.5,
		"rebota y vuelve a pegar: %.0f de daño, o sea mas de una pasada" % daño)
	# LO QUE LA TERMINA ES FALLAR, NO UN CONTADOR. Estuvo topeada en 4 pasadas, que la
	# convertia en "cuatro embestidas" en vez de "embiste hasta que lo esquives".
	_check(daño > Jarona.DAMAGE * 2.0,
		"y mientras lo sigas apuntando, sigue encadenando (%.0f de daño)" % daño)
	# Y EL TECHO, que es lo que la volvia rompedora.
	#
	# El blanco de este chequeo esta quieto y acorralado: come la cadena ENTERA, que es
	# el peor caso posible. Con daño plano eran 210 contra los 100 de vida de un jugador,
	# o sea un boton de matar. Con el decaimiento la cadena completa tiene que doler
	# mucho y aun asi dejarte vivo, porque si no, no hay nada que jugar despues.
	var vida_de_un_jugador := 100.0
	_check(daño < vida_de_un_jugador,
		"y la cadena ENTERA no alcanza para matar: %.0f contra %.0f de vida" % [
			daño, vida_de_un_jugador])

	# --- Y LO GRITA, UNA VEZ POR PASADA ---
	#
	# En Deltarune el "¡Jarona!" y el destello blanco son la misma señal y salen antes de
	# cada embestida: son el aviso con el que el otro esquiva. Por eso se pide MAS DE UNO
	# y no "al menos uno": gritarlo solo al empezar dejaria mudas las pasadas siguientes,
	# que son justo las que todavia se pueden esquivar.
	var textos: Array = gritos.values()
	_check(gritos.size() >= 2,
		"Flowery grita su frase en cada embestida, no solo en la primera (%d veces)" % gritos.size())
	_check(not textos.is_empty() and textos[0] == "¡JARONA!",
		"y lo que grita es el nombre del ataque: %s" % str(textos.slice(0, 1)))

	# --- EL EMPUJON ES EN EL IMPACTO, NO AL FINAL DEL RECORRIDO ---
	#
	# Reclamo: el empujon llegaba tarde. La causa era que la pasada corria sus tres
	# decimas enteras aunque hubiera tocado a alguien al principio, asi que se veia al
	# personaje atravesar al rival, seguir de largo, frenar, y recien ahi salir despedido.
	#
	# Se mide por lo que deja: con el rival a 3 metros, una pasada que frena al tocar no
	# puede haber recorrido los 9 metros que cubre una pasada completa. Y el que embiste
	# tiene que terminar con velocidad HACIA ATRAS, que es el empujon.
	await _plantar_flowery(player, victima, puesto, rumbo, 3.0)
	var antes_choque := player.global_position
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	var avanzo_max := 0.0
	var retrocedio := false
	for _i: int in range(26):
		await get_tree().physics_frame
		var delta_pos := player.global_position - antes_choque
		avanzo_max = maxf(avanzo_max, Vector3(delta_pos.x, 0.0, delta_pos.z).dot(rumbo))
		if Vector3(player.velocity.x, 0.0, player.velocity.z).dot(rumbo) < -2.0:
			retrocedio = true
	_check(avanzo_max < 7.0,
		"la embestida FRENA al tocar, no sigue de largo (avanzo %.1f m con el rival a 3)" % avanzo_max)
	_check(retrocedio, "y al que embiste lo tira para atras en el choque")
	await _esperar_quieto(player, 400)

	# Y si no toca a nadie, se corta en la primera pasada en vez de seguir rebotando.
	victima.global_position = player.global_position + rumbo * 60.0
	await get_tree().process_frame
	var solo_desde := player.global_position
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	for _i: int in range(150):
		await get_tree().physics_frame
	var recorrido_vacio := solo_desde.distance_to(player.global_position)
	_check(recorrido_vacio < 14.0,
		"una pasada al aire lo deja plantado (%.1f m, no cuatro pasadas)" % recorrido_vacio)

	# --- Y atropellar corta canalizados ---
	victima.health.set_max(3000.0)
	await _plantar_flowery(player, victima, puesto, rumbo, 4.0)
	victima.stamina.restore_full()
	victima.ultimate.current = UltimateCharge.MAX_CHARGE
	victima.caster.reset_state()
	victima.caster.request_use(3)  # Snowgrave, que canaliza 1.5s
	await get_tree().process_frame
	_check(victima.caster.is_channeling, "la victima esta canalizando Snowgrave")

	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	for _i: int in range(40):
		await get_tree().physics_frame
		if not victima.caster.is_channeling:
			break
	_check(not victima.caster.is_channeling, "la embestida le corta el canalizado")

	# --- HERE I COME: si engancha, cadena de golpes ---
	victima.health.set_max(3000.0)
	await _plantar_flowery(player, victima, puesto, rumbo, 6.0)

	var vida_cadena := victima.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	# EL RIVAL SE VA: se lo empuja lejos apenas lo engancha. Flowery lo tiene que seguir y
	# meterle la cadena entera; antes, alejarse caminando la cortaba en el primer golpe.
	var espera_enganche := 0
	while is_equal_approx(victima.health.current, vida_cadena) and espera_enganche < 60:
		await get_tree().physics_frame
		espera_enganche += 1
	victima.velocity = rumbo * 9.0
	for _i: int in range(120):
		await get_tree().physics_frame
	var total_cadena := vida_cadena - victima.health.current
	var minimo := HereICome.IMPACT_DAMAGE + HereICome.CHAIN_DAMAGE * (HereICome.CHAIN_HITS - 1)
	_check(total_cadena >= minimo,
		"engancha y lo sigue aunque se aleje: la cadena entra entera (%.0f de daño, minimo %.0f)" % [
			total_cadena, minimo])

	# --- LAST JARONA: siete embestidas, y no se corta si falla una ---
	_check(LastJarona.FALLOS_TOLERADOS > 0,
		"LAST JARONA aguanta esquives y por eso dura mas que JARONA (%d)" % LastJarona.FALLOS_TOLERADOS)
	victima.health.set_max(9000.0)
	await _plantar_flowery(player, victima, puesto, rumbo, 5.0)

	var vida_ulti := victima.health.current
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	player.caster.request_use(3)
	# Canaliza 1.2s y despues encadena embestidas con sus explosiones, apuntando: el
	# ultimate usa el mismo bucle que JARONA, asi que tambien reapunta a donde mires.
	for _i: int in range(420):
		await get_tree().physics_frame
		if is_instance_valid(victima):
			var hacia_v: Vector3 = victima.global_position - player.global_position
			hacia_v.y = 0.0
			if not hacia_v.is_zero_approx():
				player.aim_override = hacia_v.normalized()
	player.aim_override = Vector3.ZERO
	var daño_ulti := vida_ulti - victima.health.current
	_check(daño_ulti > daño,
		"el ultimate pega mucho mas que JARONA (%.0f contra %.0f)" % [daño_ulti, daño])
	_check(daño_ulti >= LastJarona.DAMAGE * 2.0,
		"encadena varias embestidas de verdad (%.0f de daño)" % daño_ulti)

	victima.queue_free()
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
	# Le PEDIMOS a la arena un lugar libre en vez de escribir coordenadas: al agrandar
	# el mapa, el (20, 20) que estaba aca quedo adentro de una cobertura nueva y los
	# golpes pegaban contra el bloque.
	var spot := arena.find_clear_spot(Vector3(20.0, 0.6, 20.0))
	spot.y = 0.6
	target.global_position = spot
	target.home_position = Vector3(spot.x, 0.0, spot.z)
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

	# Que vuelva solo a su marca se prueba en solo_test, con un bot de verdad: volver
	# a casa dejo de ser algo que hace el cuerpo y paso a ser una decision del
	# BotBrain, y este blanco es a proposito un cuerpo sin cerebro para poder medir el
	# empujon sin que se mueva por su cuenta.

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

	# --- EL CUERPO SE INCLINA AL GIRAR ---
	#
	# Una persona que dobla corriendo se inclina hacia adentro de la curva; sin eso el
	# personaje gira como una torreta, perfectamente vertical mientras la direccion cambia
	# debajo. Se mide porque a ojo son unos grados: se nota que algo esta mal antes de
	# poder decir que, y una captura no lo prueba.
	#
	# SE PRUEBA SOBRE UN BOT Y NO SOBRE EL JUGADOR LOCAL. Al jugador local le pisan las
	# dos entradas que esto necesita: la camara le reescribe rotation.y todos los ticks de
	# fisica, y sin teclas apretadas la velocidad se frena sola. Medido: el yaw se quedaba
	# clavado y la velocidad en cero, asi que el test daba casi nada y parecia un problema
	# del codigo. Un bot se mueve y gira por codigo, que es justo lo que hace falta.
	Arena.set_bots_active(false)
	var girador := _spawn_dummy(arena, arena.find_clear_spot(Vector3(24.0, 0.6, 24.0), 1.5))
	await get_tree().process_frame
	girador.visual._root.rotation.z = 0.0
	var recto := 0.0
	for i: int in range(45):
		await get_tree().physics_frame
		# Corriendo y doblando: la inclinacion solo aplica en movimiento, porque girar
		# parado es mirar alrededor y no doblar una curva.
		girador.bot_move_dir = Vector3(1.0, 0.0, 0.0)
		girador.bot_look_yaw += 0.10
		await get_tree().process_frame
		recto = maxf(recto, absf(girador.visual._root.rotation.z))
	_check(recto > 0.04, "el cuerpo se inclina al doblar corriendo (%.3f rad)" % recto)

	# Y al dejar de girar se endereza: si no, quedaria torcido el resto de la partida.
	girador.bot_move_dir = Vector3.ZERO
	for _i: int in range(50):
		await get_tree().process_frame
	_check(absf(girador.visual._root.rotation.z) < 0.02,
		"y se endereza al parar (%.3f rad)" % girador.visual._root.rotation.z)
	girador.queue_free()
	await get_tree().process_frame

	# --- LAS CAJAS DE COLISION MUESTRAN LA DE VERDAD ---
	#
	# Una caja dibujada a mano al lado de la real es peor que no dibujar nada: muestra con
	# total seguridad algo que no es cierto. Se comprueba que la capsula dibujada tenga las
	# medidas EXACTAS de la de choque, y que siga a la opcion.
	var con_caja := arena.get_local_player()
	var marca := con_caja.get_node_or_null(^"CajaColision") as MeshInstance3D
	_check(marca != null, "cada cuerpo tiene su caja de colision preparada")
	if marca != null:
		var real := con_caja.collision.shape as CapsuleShape3D
		var dibujada := marca.mesh as CapsuleMesh
		_check(real != null and dibujada != null
			and is_equal_approx(real.radius, dibujada.radius)
			and is_equal_approx(real.height, dibujada.height),
			"y mide exactamente lo mismo que la de choque")
		var antes_opcion := Settings.mostrar_hitboxes
		Settings.mostrar_hitboxes = false
		Settings.changed.emit()
		_check(not marca.visible, "con la opcion apagada no se dibuja")
		Settings.mostrar_hitboxes = true
		Settings.changed.emit()
		_check(marca.visible, "y con la opcion prendida si")
		Settings.mostrar_hitboxes = antes_opcion
		Settings.changed.emit()

	# --- TODO PUNTO DE APARICION TIENE QUE ESTAR LIBRE ---
	#
	# Bug reportado: la aparicion se bugueaba. Eran tres de los ocho puntos, que al
	# rehacer el mapa quedaron adentro de un bloque o de una columna. Aparecer incrustado
	# hace que la fisica te escupa, y desde afuera eso no se parece en nada a "el spawn
	# esta mal puesto": se parece a que el juego se rompio.
	#
	# Se prueban los OCHO, no el que toque: get_free_spawn_point elige segun donde este
	# la gente, asi que en una partida cualquiera puede tocar cualquiera.
	var espacio_arena := arena.get_world_3d().direct_space_state
	var rotos := ""
	for t2: Transform3D in arena._spawn_points:
		var p2 := arena.find_clear_spot(t2.origin, 0.8)
		var forma2 := PhysicsShapeQueryParameters3D.new()
		var esf := SphereShape3D.new()
		esf.radius = 0.55
		forma2.shape = esf
		forma2.collision_mask = GameConfig.LAYER_WORLD
		forma2.transform = Transform3D(Basis.IDENTITY, p2 + Vector3.UP * 1.0)
		if not espacio_arena.intersect_shape(forma2, 1).is_empty():
			rotos += "ocupado%v " % p2
			continue
		var suelo2 := PhysicsRayQueryParameters3D.create(p2 + Vector3.UP * 0.8, p2 + Vector3.DOWN * 6.0)
		suelo2.collision_mask = GameConfig.LAYER_WORLD
		if espacio_arena.intersect_ray(suelo2).is_empty():
			rotos += "sinpiso%v " % p2
	_check(rotos.is_empty(), "los %d puntos de aparicion estan libres y con piso %s" % [
		arena._spawn_points.size(), rotos])

	# LA INVARIANTE DEL ESCALON, que es invisible y cara de descubrir jugando.
	#
	# El navmesh promete caminos que suben escalones de hasta NAV_MAX_CLIMB; el cuerpo
	# sube hasta STEP_HEIGHT. Si el navegador promete mas de lo que el cuerpo puede, manda
	# a los bots por encima de labios que no pueden trepar y se quedan clavados ahi HASTA
	# EL FINAL DE LA PARTIDA, sin ningun otro sintoma. Asi estuvo el bot de Flowery el 83%
	# del tiempo, y desde afuera parecia "el bot esta tonto", no "la navegacion miente".
	#
	# El margen de una celda (0.25) es por el redondeo de Recast, que cuantiza las alturas
	# y puede ver un desnivel de 0.6 como uno de 0.5.
	_check(Player.STEP_HEIGHT >= Arena.NAV_MAX_CLIMB + 0.25,
		"el cuerpo sube mas escalon del que el navmesh promete (%.2f contra %.2f)" % [
			Player.STEP_HEIGHT, Arena.NAV_MAX_CLIMB])
	# Y el otro lado: que subir escalones no vuelva escalables las coberturas, que es lo
	# que sostiene que sirvan de cobertura.
	var cobertura_mas_baja := 99.0
	for child: Node in arena.get_children():
		if not child.name.begins_with("Cover"):
			continue
		var forma := child.get_child(0) as CollisionShape3D
		if forma != null and forma.shape is BoxShape3D:
			cobertura_mas_baja = minf(cobertura_mas_baja, (forma.shape as BoxShape3D).size.y)
	_check(cobertura_mas_baja > Player.STEP_HEIGHT * 2.0,
		"las coberturas siguen sin poder escalarse (la mas baja mide %.1f m)" % cobertura_mas_baja)


## Espera a que el cuerpo deje de moverse solo.
##
## Hace falta entre tests: las habilidades son corrutinas que siguen vivas despues de
## que el test que las disparo termino, y la siguiente medicion se toma sobre un cuerpo
## que todavia viene empujado por la habilidad anterior.
func _esperar_quieto(player: Player, tope: int) -> void:
	var quietos := 0
	for _i: int in range(tope):
		await get_tree().physics_frame
		if Vector3(player.velocity.x, 0.0, player.velocity.z).length() < 0.6:
			quietos += 1
			if quietos >= 10:
				return
		else:
			quietos = 0


# ------------------------------------------------------------------- Rick

func _test_rick(player: Player, arena: Arena) -> void:
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()

	# ESPERAR A QUE EL CUERPO SE QUEDE QUIETO ANTES DE MEDIR NADA.
	#
	# El test anterior es el de Flowery, y JARONA son hasta diez pasadas encadenadas que
	# tardan unos seis segundos. La corrutina sigue viva y sigue empujando el cuerpo
	# aunque el personaje ya haya cambiado, asi que las primeras mediciones de Rick se
	# tomaban sobre un cuerpo que venia a 30 m/s de la habilidad de otro. El sintoma era
	# desconcertante: el portal llegaba al punto exacto y el chequeo daba 8 metros de
	# diferencia, porque despues de llegar lo seguian arrastrando.
	await _esperar_quieto(player, 480)

	_check(CharacterDB.has_character(&"rick"), "Rick esta registrado")
	var data := CharacterDB.get_character(&"rick")
	_check(data != null and data.origin_game == "Rick and Morty", "Rick viene de Rick and Morty")
	var kit := CharacterDB.build_abilities_for(&"rick")
	_check(kit.size() == 4, "Rick tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is PlasmaShot, "slot 0 es la pistola de plasma")
	_check(kit[1] is PortalGun, "slot 1 es la PISTOLA DE PORTALES")
	_check(kit[2] is PlasmaGrenade, "slot 2 es la granada")
	_check(kit[3] is MeeseeksBox, "slot 3 es la caja de Meeseeks")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")

	player.setup_character(data)
	var puesto := arena.find_clear_spot(Vector3(-30.0, 0.6, 30.0), 1.5)
	var rumbo := _carril_libre(player, puesto, 16.0)
	player.respawn_at(puesto, atan2(-rumbo.x, -rumbo.z))
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(atan2(-rumbo.x, -rumbo.z))
	for _i: int in range(24):
		await get_tree().physics_frame

	# --- EL TELETRANSPORTE ---
	#
	# Es lo que se pidio, asi que se comprueba lo que se pidio: que llegue LEJOS y que
	# llegue A DONDE APUNTA. Lo primero solo no alcanza —un empujon fuerte tambien
	# mueve— y lo segundo solo tampoco, porque teletransportarse dos metros adelante
	# tambien cumple "a donde apunto".
	# APUNTADO FIJO PARA MEDIR.
	#
	# get_aim_direction() saca el rumbo de un rayo que arranca en la camara, asi que
	# cambia entre el momento en que el test calcula el destino y el momento en que la
	# habilidad lo recalcula. La primera version comparaba dos destinos distintos y daba
	# 7.3 metros de diferencia sin que nada estuviera roto. aim_override fija el rumbo
	# para los dos, que es lo unico que hace comparable la medicion.
	player.aim_override = rumbo
	var desde := player.global_position
	# SIN LIMITE DE DISTANCIA, que es lo que se pidio.
	#
	# Se comprueba sobre la constante y no midiendo un disparo: cualquier medicion real
	# la corta lo primero que haya en el camino —en un mapa con veinte coberturas eso
	# son diez o quince metros— y entonces el numero habla del mapa, no de la habilidad.
	# Lo que hay que garantizar es que el alcance cubra la diagonal entera: si eso vale,
	# no hay punto del mapa al que no llegue desde ningun otro.
	_check(PortalGun.alcance() > Arena.ARENA_SIZE * 1.42,
		"el portal alcanza la diagonal entera del mapa (%.0f contra %.0f)" % [
			PortalGun.alcance(), Arena.ARENA_SIZE * 1.42])

	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	# El portal avisa antes de mover: hay que esperar el aviso mas margen.
	for _i: int in range(60):
		await get_tree().physics_frame
	var recorrido := player.global_position - desde
	var salto := Vector3(recorrido.x, 0.0, recorrido.z).length()
	_check(salto > 12.0, "y te lleva ahi de verdad (salto de %.1f m)" % salto)

	# EN LA DIRECCION QUE APUNTASTE, que es la promesa de la habilidad.
	#
	# No se compara contra un punto predicho a proposito: la habilidad recalcula su
	# destino al EJECUTARSE, desde su propio origen, asi que un punto calculado antes
	# nunca coincide exacto y el chequeo falla por como esta medido y no por como
	# funciona. Lo que hay que garantizar es la promesa: lejos, y hacia donde mirabas.
	var alineacion := Vector3(recorrido.x, 0.0, recorrido.z).normalized().dot(rumbo)
	_check(alineacion > 0.9,
		"y hacia donde apuntabas, no a cualquier lado (alineacion %.2f)" % alineacion)

	# --- Y QUE TODO DESTINO SEA PISABLE ---
	#
	# Un teletransporte sin limite de distancia es tambien uno que te puede meter adentro
	# de una pared, y eso es peor que no tenerlo: la fisica te expulsa o te deja trabado.
	#
	# Se comprueba la FUNCION y no donde termina el cuerpo, en ocho direcciones. Mirar
	# donde queda el jugador despues de aterrizar mezcla dos cosas —si el destino era
	# bueno, y que le hizo la fisica despues— y cuando falla no se sabe cual de las dos
	# fallo. El contrato de calcular_destino es "un punto libre, dentro del mapa, con
	# piso": eso es lo que se mide.
	var espacio := player.get_world_3d().direct_space_state
	var malos := ""
	for i: int in range(8):
		var ang := TAU * float(i) / 8.0
		var d := Vector3(cos(ang), 0.0, sin(ang))
		var p := PortalGun.calcular_destino(player, player.get_aim_origin(), d)

		var forma := PhysicsShapeQueryParameters3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = 0.45
		forma.shape = esfera
		forma.collision_mask = GameConfig.LAYER_WORLD
		forma.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.0)
		if not espacio.intersect_shape(forma, 1).is_empty():
			malos += "ocupado%v " % p
			continue
		var suelo := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.6, p + Vector3.DOWN * 5.0)
		suelo.collision_mask = GameConfig.LAYER_WORLD
		if espacio.intersect_ray(suelo).is_empty():
			malos += "sinpiso%v " % p
	_check(malos.is_empty(), "todo destino del portal es pisable y esta libre %s" % malos)

	# --- NO SE PUEDE SALIR DEL MAPA ---
	#
	# Bug reportado: con el portal se podia salir de la arena. La causa estaba en
	# find_clear_spot, que recortaba a los limites dentro de su bucle pero devolvia el
	# punto CRUDO en su salida de ultimo recurso. Como el portal es lo unico que pide un
	# punto a 150 metros, era el unico que lo destapaba.
	#
	# Se prueban las direcciones que mas facil se le escapan: las cuatro diagonales y el
	# cielo, que son con las que uno apunta afuera sin querer.
	var limite_mapa := Arena.ARENA_SIZE * 0.5
	var fugas := ""
	for d: Vector3 in [Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(1, 0, -1),
			Vector3(-1, 0, -1), Vector3(1, 0.6, 0), Vector3.UP]:
		var p := PortalGun.calcular_destino(player, player.get_aim_origin(), d.normalized())
		if absf(p.x) > limite_mapa or absf(p.z) > limite_mapa:
			fugas += "%v " % p
	_check(fugas.is_empty(), "el portal nunca te saca del mapa %s" % fugas)

	# --- La granada revienta SOBRE el piso, no bajo tierra ---
	#
	# Bug reportado: atravesaba el piso y tardaba en explotar. Eran lo mismo: ningun
	# proyectil detectaba el mundo, asi que caia hasta que se le acababa la mecha, varios
	# metros bajo tierra, y el estallido no le llegaba a nadie.
	var cerca := _spawn_dummy(arena, player.global_position + rumbo * 5.0)
	cerca.health.set_max(900.0)
	player.aim_override = (rumbo + Vector3.DOWN * 0.18).normalized()
	await get_tree().process_frame
	var vida_cerca := cerca.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	for _i: int in range(150):
		await get_tree().physics_frame
	_check(cerca.health.current < vida_cerca,
		"la granada revienta arriba del piso y alcanza a quien esta al lado (le saco %.0f)" % (vida_cerca - cerca.health.current))
	cerca.queue_free()

	player.aim_override = Vector3.ZERO
	var arriba := PortalGun.calcular_destino(player, player.get_aim_origin(), Vector3.UP)
	_check(is_finite(arriba.x) and is_finite(arriba.y) and is_finite(arriba.z),
		"apuntar al cielo devuelve un destino valido, no un infinito")

	Arena.set_bots_active(true)


# ------------------------------------------------------- La sala de practica

## Los interruptores del panel de practica.
##
## Cada uno toca un sistema distinto —stamina, cooldowns, vida, daño, objetivos de los
## bots— asi que un cambio en cualquiera de esos cinco puede romperlo sin que se note:
## el sintoma seria "la casilla esta tildada y no hace nada", que jugando se confunde
## facil con "la puse mal".
func _test_sonic(player: Player, arena: Arena) -> void:
	Arena.set_bots_active(false)
	await _esperar_quieto(player, 60)

	_check(CharacterDB.has_character(&"sonic"), "Sonic esta registrado")
	var data := CharacterDB.get_character(&"sonic")
	_check(data != null and data.origin_game == "Sonic the Hedgehog", "Sonic viene de su serie")
	_check(data != null and data.silhouette == &"quills",
		"tiene silueta propia: las puas, y no las astas ni los hombros")

	# EL MAS RAPIDO Y EL MAS FRAGIL. Es toda su identidad mecanica: si fuera rapido Y
	# aguantara, no habria ninguna razon para elegir a otro.
	var mas_rapido := true
	var mas_fragil := true
	for otro_id: StringName in CharacterDB.get_all_ids():
		if otro_id == &"sonic":
			continue
		var otro := CharacterDB.get_character(otro_id)
		if otro.move_speed >= data.move_speed:
			mas_rapido = false
		if otro.max_health <= data.max_health:
			mas_fragil = false
	_check(mas_rapido, "es el mas rapido del juego (%.1f)" % data.move_speed)
	_check(mas_fragil, "y el que menos vida tiene (%.0f)" % data.max_health)

	var kit := CharacterDB.build_abilities_for(&"sonic")
	_check(kit.size() == 4, "Sonic tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is SpinAttack, "slot 0 es Spin Attack")
	_check(kit[1] is SpinDash, "slot 1 es Spin Dash")
	_check(kit[2] is HomingAttack, "slot 2 es Homing Attack")
	_check(kit[3] is SuperSonic, "slot 3 es Super Sonic")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")
	_check(kit[3].stamina_cost == 100.0 and kit[3].requires_charge,
		"el ultimate cuesta la barra entera Y el medidor")

	player.setup_character(data)
	var puesto := arena.find_clear_spot(Vector3(30.0, 0.6, -30.0), 1.5)
	player.respawn_at(puesto, 0.0)
	for _i: int in range(16):
		await get_tree().physics_frame

	# --- HOMING ATTACK: sin blanco no sale, y no cobra ---
	#
	# Un homing al vacio seria un dash con otro nombre, y ademas dejaria a Sonic volando
	# hacia la nada por haberse equivocado de momento. Cobrarlo igual castiga por no tener
	# a nadie cerca, que no es algo que el jugador haya hecho mal.
	player.stamina.restore_full()
	player.caster.reset_state()
	var antes_stamina := player.stamina.current
	player.caster.request_use(2)
	for _i: int in range(10):
		await get_tree().physics_frame
	_check(player.stamina.current >= antes_stamina - 1.0,
		"el Homing sin nadie a tiro devuelve la stamina (%.0f de %.0f)" % [
			player.stamina.current, antes_stamina])

	# --- SUPER SONIC: mas rapido, mas resistente, y se APAGA ---
	var estado := player.status
	estado.clear_all()
	_check(is_equal_approx(estado.get_move_speed_multiplier(), 1.0),
		"antes del ultimate se mueve a velocidad normal")
	estado.impulsar(SuperSonic.VELOCIDAD, SuperSonic.RESISTENCIA, SuperSonic.POTENCIA, 0.6)
	await get_tree().physics_frame
	_check(estado.get_move_speed_multiplier() > 1.2,
		"Super Sonic lo acelera (x%.2f)" % estado.get_move_speed_multiplier())
	_check(estado.get_damage_taken_multiplier() < 0.5,
		"y recibe mucho menos daño (x%.2f)" % estado.get_damage_taken_multiplier())
	_check(estado.get_damage_dealt_multiplier() > 1.2,
		"y reparte mas (x%.2f)" % estado.get_damage_dealt_multiplier())
	# CASI invulnerable, no invulnerable: una definitiva que te vuelve intocable no se
	# juega en contra, se espera a que termine.
	_check(estado.get_damage_taken_multiplier() > 0.0,
		"pero NO es invulnerable: se le puede seguir pegando")

	# Y CADUCA. Es lo que dice la ficha del personaje —"consume mucha energia, no se puede
	# mantener mucho tiempo"— y es lo unico que evita que el ultimate sea permanente.
	for _i: int in range(60):
		await get_tree().physics_frame
	_check(not estado.esta_impulsado() and is_equal_approx(estado.get_move_speed_multiplier(), 1.0),
		"y se apaga solo al vencer el tiempo")

	# --- EL HOMING ENCADENA ---
	#
	# Es LA sensacion del personaje: en sus juegos rebota de un enemigo al siguiente sin
	# tocar el piso. Acertar tiene que devolver casi todo el cooldown, y la cadena tiene
	# tope, porque sin tope con suficiente stamina se cruza el mapa entero rebotando.
	var homing: HomingAttack = kit[2]
	player.caster.reset_state()
	player.set_meta(&"homing_cadena", 0)
	player.set_meta(&"homing_ultimo", -99.0)
	player.caster._cooldowns[2] = homing.cooldown
	homing._premiar_cadena(player)
	_check(player.caster.get_cooldown_remaining(2) <= HomingAttack.COOLDOWN_AL_ACERTAR + 0.01,
		"acertar un Homing devuelve casi todo el cooldown (quedan %.2f s)" %
			player.caster.get_cooldown_remaining(2))
	for _i: int in range(HomingAttack.CADENA_MAXIMA):
		player.caster._cooldowns[2] = homing.cooldown
		homing._premiar_cadena(player)
	_check(player.caster.get_cooldown_remaining(2) > HomingAttack.COOLDOWN_AL_ACERTAR + 1.0,
		"pero la cadena tiene tope: pasado el maximo el cooldown vuelve entero (%.1f s)" %
			player.caster.get_cooldown_remaining(2))
	# acortar_cooldown solo acorta: no puede usarse para castigar alargando.
	player.caster._cooldowns[2] = 0.3
	player.caster.acortar_cooldown(2, 5.0)
	_check(player.caster.get_cooldown_remaining(2) <= 0.31,
		"acortar un cooldown nunca lo alarga")
	player.caster.reset_state()

	# Sus skins.
	var skins := SkinDB.de_personaje(&"sonic")
	_check(skins.size() >= 3, "Sonic tiene skins propias (%d)" % skins.size())
	estado.clear_all()
	# LOS BOTS SE VUELVEN A PRENDER. Los apago al empezar para medir sin que nadie me
	# empuje, y dejarlos apagados le rompe la prueba al que viene despues: el chequeo del
	# bot que corre a cortar un canalizado se quedaba sin bot y fallaba por mi culpa, no
	# por la suya.
	Arena.set_bots_active(true)


# -------------------------------------------------------------------- Goku

func _test_goku(player: Player, arena: Arena) -> void:
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()
	await _esperar_quieto(player, 480)

	_check(CharacterDB.has_character(&"goku"), "Goku esta registrado")
	var data := CharacterDB.get_character(&"goku")
	_check(data != null and data.origin_game == "Dragon Ball" and data.silhouette == &"gi",
		"Goku viene de Dragon Ball y tiene silueta propia: el pelo en puntas")
	_check(data != null and data.requiere_desbloqueo,
		"Goku NO viene de fabrica: se gana con el pase pro")

	# ES UN PREMIO Y NO PUEDE SER EL MAS FUERTE. Un personaje que se gana jugando y que
	# ademas le gana a los otros convertiria el pase en un requisito para competir.
	var vida_max := 0.0
	var vel_max := 0.0
	for otro_id: StringName in CharacterDB.get_all_ids():
		if otro_id == &"goku":
			continue
		var otro := CharacterDB.get_character(otro_id)
		vida_max = maxf(vida_max, otro.max_health)
		vel_max = maxf(vel_max, otro.move_speed)
	_check(data.max_health <= vida_max and data.move_speed < vel_max,
		"y no aguanta mas que nadie ni es el mas rapido (%.0f de vida, %.1f de velocidad)" % [
			data.max_health, data.move_speed])

	var kit := CharacterDB.build_abilities_for(&"goku")
	_check(kit.size() == 4, "Goku tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is GokuCombo and kit[1] is KiBlast and kit[2] is Teletransportacion
		and kit[3] is Kamehameha,
		"su kit: combo de golpes, rafaga de ki, teletransportacion y Kamehameha")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")
	_check(kit[3].stamina_cost == 100.0 and kit[3].requires_charge and kit[3].channel_time > 0.0,
		"el Kamehameha cuesta la barra entera, pide el medidor y se CARGA a la vista")

	player.setup_character(data)
	var puesto := arena.find_clear_spot(Vector3(-30.0, 0.6, -30.0), 1.5)
	var rumbo := _carril_libre(player, puesto, 20.0)
	var yaw := atan2(-rumbo.x, -rumbo.z)
	player.respawn_at(puesto, yaw)
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)
	for _i: int in range(24):
		await get_tree().physics_frame
	player.aim_override = rumbo

	# --- TELETRANSPORTACION: sin blanco no sale, y no cobra ---
	player.stamina.restore_full()
	player.caster.reset_state()
	var antes_stamina := player.stamina.current
	var antes_pos := player.global_position
	player.caster.request_use(2)
	for _i: int in range(20):
		await get_tree().physics_frame
	_check(player.stamina.current >= antes_stamina - 1.0
		and player.global_position.distance_to(antes_pos) < 0.5,
		"sin nadie a tiro la teletransportacion no sale y devuelve la stamina (%.0f de %.0f)" % [
			player.stamina.current, antes_stamina])

	# --- Con blanco: aparece DETRAS DE SU ESPALDA y queda mirandolo ---
	var blanco := _spawn_dummy(arena, puesto + rumbo * 10.0)
	blanco.health.set_max(3000.0)
	for _i: int in range(6):
		await get_tree().physics_frame
	var frente := -blanco.global_transform.basis.z
	frente.y = 0.0
	frente = frente.normalized()
	var esperado := blanco.global_position - frente * Teletransportacion.DETRAS
	var vida := blanco.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	for _i: int in range(30):
		await get_tree().physics_frame
	var llegada := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var donde := Vector3(esperado.x, 0.0, esperado.z)
	_check(llegada.distance_to(donde) < 1.0,
		"la teletransportacion te deja detras de la espalda del rival (a %.2f m del punto)" % llegada.distance_to(donde))
	var mira := -player.global_transform.basis.z
	var hacia := blanco.global_position - player.global_position
	hacia.y = 0.0
	_check(Vector3(mira.x, 0.0, mira.z).normalized().dot(hacia.normalized()) > 0.8,
		"y quedas MIRANDOLO, no de espaldas a el")
	_check(blanco.health.current < vida, "y le pega el rodillazo (%.0f)" % (vida - blanco.health.current))

	# --- RAFAGA DE KI: tres esferas, y llegan ---
	var lugar := arena.find_clear_spot(Vector3(-30.0, 0.6, -30.0), 1.5)
	player.respawn_at(lugar, yaw)
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)
	blanco.global_position = lugar + rumbo * 8.0
	blanco.velocity = Vector3.ZERO
	blanco.health.revive_full()
	for _i: int in range(12):
		await get_tree().physics_frame
	vida = blanco.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	for _i: int in range(90):
		await get_tree().physics_frame
	var daño_ki := vida - blanco.health.current
	_check(daño_ki >= KiBlast.DAMAGE * 2.0,
		"la rafaga de ki le pega varias veces al que tiene enfrente (%.0f de %.0f posibles)" % [
			daño_ki, KiBlast.DAMAGE * KiBlast.DISPAROS])

	# --- KAMEHAMEHA: pega en la linea, no al costado ---
	var costado := _spawn_dummy(arena, lugar + rumbo * 12.0 + Vector3(-rumbo.z, 0.0, rumbo.x) * 6.0)
	costado.peer_id = -78
	costado.health.set_max(3000.0)
	blanco.global_position = lugar + rumbo * 12.0
	blanco.velocity = Vector3.ZERO
	blanco.health.revive_full()
	player.respawn_at(lugar, yaw)
	for _i: int in range(12):
		await get_tree().physics_frame
	var vida_linea := blanco.health.current
	var vida_costado := costado.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.request_use(3)
	await get_tree().physics_frame
	_check(player.caster.is_channeling, "el Kamehameha arranca cargando (ka... me... ha... me...)")
	await get_tree().create_timer(Kamehameha.new().channel_time + 0.6).timeout
	_check(blanco.health.current <= vida_linea - Kamehameha.DAMAGE * 0.9,
		"el rayo le pega fuerte al que esta en la linea (%.0f)" % (vida_linea - blanco.health.current))
	_check(is_equal_approx(costado.health.current, vida_costado),
		"y NO al que esta a seis metros al costado: es un rayo, no una explosion")
	_check(player.ultimate.current < 1.0,
		"y su propio daño no le recarga el medidor (quedo en %.0f)" % player.ultimate.current)

	# Sus skins: las tres transformaciones, todas en la tienda y ninguna en el pase.
	var suyas := SkinDB.de_personaje(&"goku")
	var en_tienda := 0
	for sid: StringName in suyas:
		if SkinDB.get_skin(sid).precio > 0:
			en_tienda += 1
	_check(suyas.size() >= 3 and en_tienda == suyas.size(),
		"Goku tiene sus skins y estan todas en la tienda (%d de %d)" % [en_tienda, suyas.size()])

	player.aim_override = Vector3.ZERO
	blanco.queue_free()
	costado.queue_free()
	# De vuelta a Sonic, que es con quien venian las pruebas de despues.
	player.setup_character(CharacterDB.get_character(&"sonic"))
	player.caster.reset_state()
	player.status.clear_all()
	Arena.set_bots_active(true)


func _test_mario(player: Player, arena: Arena) -> void:
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()
	await _esperar_quieto(player, 480)

	_check(CharacterDB.has_character(&"mario"), "Mario esta registrado")
	var data := CharacterDB.get_character(&"mario")
	_check(data != null and data.origin_game == "Super Mario Bros." and data.silhouette == &"gorra",
		"Mario viene de Super Mario Bros. y tiene silueta propia: la gorra")
	_check(data != null and not data.requiere_desbloqueo, "Mario viene de fabrica: gratis desde el principio")

	var kit := CharacterDB.build_abilities_for(&"mario")
	_check(kit.size() == 4, "Mario tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is MarioCombo and kit[1] is BolaDeFuego and kit[2] is SuperSalto
		and kit[3] is Superestrella,
		"su kit: puño y patada, bola de fuego, super salto y superestrella")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")
	_check(kit[3].stamina_cost == 100.0 and kit[3].requires_charge and kit[3].channel_time > 0.0,
		"la Superestrella cuesta la barra entera, pide el medidor y se carga a la vista")

	player.setup_character(data)
	var puesto := arena.find_clear_spot(Vector3(-30.0, 0.6, -30.0), 1.5)
	var rumbo := _carril_libre(player, puesto, 20.0)
	var yaw := atan2(-rumbo.x, -rumbo.z)
	player.respawn_at(puesto, yaw)
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)
	for _i: int in range(24):
		await get_tree().physics_frame
	player.aim_override = rumbo

	# --- BOLA DE FUEGO: pica en el piso y sigue, no se apaga contra el suelo ---
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	await get_tree().create_timer(0.7).timeout
	var bola: BolaFuego = null
	for hijo: Node in arena.get_children():
		if hijo is BolaFuego and not hijo.is_queued_for_deletion():
			bola = hijo
	_check(bola != null and bola._piques >= 1,
		"la bola de fuego pica en el piso y sigue viajando (%d piques)" % (bola._piques if bola != null else -1))

	# --- Y pega ---
	var blanco := _spawn_dummy(arena, puesto + rumbo * 7.0)
	blanco.health.set_max(3000.0)
	for _i: int in range(6):
		await get_tree().physics_frame
	var vida := blanco.health.current
	await get_tree().create_timer(1.2).timeout
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	await get_tree().create_timer(1.4).timeout
	_check(blanco.health.current <= vida - BolaDeFuego.DAMAGE * 0.9,
		"la bola de fuego le pega al que tiene adelante (%.0f)" % (vida - blanco.health.current))

	# --- SUPER SALTO: sube, cae, y el pisoton aplasta alrededor ---
	#
	# Con un maniqui NUEVO a tres metros: el de antes vuelve caminando a su marca, y en lo
	# que dura el salto se iba de abajo.
	player.respawn_at(puesto, yaw)
	var aplastado := _spawn_dummy(arena, puesto + rumbo * 3.0)
	aplastado.health.set_max(3000.0)
	for _i: int in range(12):
		await get_tree().physics_frame
	vida = aplastado.health.current
	var piso := player.global_position.y
	var alto := 0.0
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	for _i: int in range(110):
		await get_tree().physics_frame
		alto = maxf(alto, player.global_position.y - piso)
	_check(alto > 2.0, "el Super Salto sube bien alto (%.1f m)" % alto)
	var caida := Vector3(player.global_position.x - aplastado.global_position.x, 0.0,
		player.global_position.z - aplastado.global_position.z).length()
	_check(aplastado.health.current <= vida - SuperSalto.DAMAGE * 0.9,
		"y al caer, el pisoton le pega al que estaba cerca (%.0f, cayo a %.1f m)" % [
			vida - aplastado.health.current, caida])
	aplastado.queue_free()

	# --- Y CAE ENCIMA DEL QUE APUNTA, aunque este lejos ---
	#
	# Antes el avance se lo comia el freno del movimiento: Mario saltaba casi en el lugar.
	await get_tree().create_timer(0.6).timeout
	player.respawn_at(puesto, yaw)
	var lejano := _spawn_dummy(arena, puesto + rumbo * 9.0)
	lejano.health.set_max(3000.0)
	for _i: int in range(12):
		await get_tree().physics_frame
	vida = lejano.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	for _i: int in range(110):
		await get_tree().physics_frame
	var llegada := Vector3(player.global_position.x - lejano.global_position.x, 0.0,
		player.global_position.z - lejano.global_position.z).length()
	_check(lejano.health.current <= vida - SuperSalto.DAMAGE * 0.9 and llegada < SuperSalto.RADIO,
		"el Super Salto va a buscar al rival a nueve metros y le cae encima (cayo a %.1f m, %.0f de daño)" % [
			llegada, vida - lejano.health.current])
	lejano.queue_free()

	# --- SUPERESTRELLA: invencible de verdad, y el que toca sale volando ---
	player.respawn_at(puesto, yaw)
	for _i: int in range(6):
		await get_tree().physics_frame
	player.stamina.restore_full()
	player.caster.reset_state()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.request_use(3)
	await get_tree().create_timer(Superestrella.new().channel_time + 0.2).timeout
	var antes := player.health.current
	var hecho := CombatUtils.deal_damage(player, 50.0, -77)
	player.status.freeze_for(2.0)
	player.status.stun_for(1.0)
	_check(player.status.es_invencible() and hecho == 0.0 and is_equal_approx(player.health.current, antes)
		and player.status.can_act(),
		"con la Superestrella nada le saca vida ni lo frena (congelar ni aturdir)")
	blanco.global_position = player.global_position + rumbo * 0.8
	blanco.velocity = Vector3.ZERO
	blanco.health.revive_full()
	vida = blanco.health.current
	await get_tree().create_timer(0.5).timeout
	_check(blanco.health.current < vida, "y el que lo toca sale lastimado (%.0f)" % (vida - blanco.health.current))
	_check(player.ultimate.current < 1.0,
		"y su propio daño no le recarga el medidor (quedo en %.0f)" % player.ultimate.current)
	await get_tree().create_timer(Superestrella.DURACION).timeout
	hecho = CombatUtils.deal_damage(player, 5.0, -77)
	_check(not player.status.es_invencible() and hecho > 0.0,
		"y cuando se apaga, vuelve a recibir daño como cualquiera")

	# Sus skins: las tres, en la tienda.
	var suyas := SkinDB.de_personaje(&"mario")
	var en_tienda := 0
	for sid: StringName in suyas:
		if SkinDB.get_skin(sid).precio > 0:
			en_tienda += 1
	_check(suyas.size() >= 3 and en_tienda == suyas.size(),
		"Mario tiene sus skins y estan todas en la tienda (%d de %d)" % [en_tienda, suyas.size()])

	player.aim_override = Vector3.ZERO
	blanco.queue_free()
	player.setup_character(CharacterDB.get_character(&"sonic"))
	player.caster.reset_state()
	player.status.clear_all()
	player.health.revive_full()
	Arena.set_bots_active(true)


# ------------------------------------------------------------------- Madara

func _test_madara(player: Player, arena: Arena) -> void:
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()
	await _esperar_quieto(player, 480)

	_check(CharacterDB.has_character(&"madara"), "Madara esta registrado")
	var data := CharacterDB.get_character(&"madara")
	_check(data != null and data.origin_game == "Naruto Shippuden" and data.silhouette == &"uchiha",
		"Madara viene de Naruto y tiene silueta propia: la melena")
	_check(data != null and not data.requiere_desbloqueo, "Madara viene de fabrica: gratis desde el principio")

	var kit := CharacterDB.build_abilities_for(&"madara")
	_check(kit.size() == 4, "Madara tiene 4 habilidades (tiene %d)" % kit.size())
	if kit.size() < 4:
		return
	_check(kit[0] is GolpeGunbai and kit[1] is GokaMesshitsu and kit[2] is Susanoo
		and kit[3] is TengaiShinsei,
		"su kit: gunbai, Katon Goka Messhitsu, Susano'o y Tengai Shinsei")
	_check(is_zero_approx(kit[0].stamina_cost), "su basico NO cuesta stamina")
	_check(kit[3].stamina_cost == 100.0 and kit[3].requires_charge and kit[3].channel_time > 0.0,
		"los meteoritos cuestan la barra entera, piden el medidor y se cargan a la vista")

	player.setup_character(data)
	var puesto := arena.find_clear_spot(Vector3(-30.0, 0.6, -30.0), 1.5)
	var rumbo := _carril_libre(player, puesto, 20.0)
	var yaw := atan2(-rumbo.x, -rumbo.z)
	player.respawn_at(puesto, yaw)
	if is_instance_valid(player.camera_pivot):
		player.camera_pivot.set_yaw(yaw)
	for _i: int in range(24):
		await get_tree().physics_frame
	player.aim_override = rumbo

	# --- KATON: el muro de fuego le pega al que tiene adelante ---
	var blanco := _spawn_dummy(arena, puesto + rumbo * 6.0)
	blanco.health.set_max(3000.0)
	for _i: int in range(12):
		await get_tree().physics_frame
	var vida := blanco.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(1)
	await get_tree().create_timer(GokaMesshitsu.new().channel_time + 0.3).timeout
	_check(blanco.health.current <= vida - GokaMesshitsu.DAMAGE * 0.9,
		"el Katon le pega al que tiene adelante, a seis metros (%.0f)" % (vida - blanco.health.current))
	blanco.queue_free()

	# --- SUSANO'O: el escudo, y el espadazo al frente ---
	await get_tree().create_timer(0.4).timeout
	player.respawn_at(puesto, yaw)
	var cortado := _spawn_dummy(arena, puesto + rumbo * 3.0)
	cortado.health.set_max(3000.0)
	for _i: int in range(12):
		await get_tree().physics_frame
	vida = cortado.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.caster.request_use(2)
	await get_tree().create_timer(Susanoo.new().channel_time + 0.25).timeout
	_check(player.health.get_shield() >= Susanoo.ESCUDO * 0.99,
		"el Susano'o lo envuelve en un escudo (%.0f)" % player.health.get_shield())
	_check(cortado.health.current <= vida - Susanoo.DAMAGE * 0.9,
		"y el espadazo le pega al que tiene adelante (%.0f)" % (vida - cortado.health.current))
	var vida_madara := player.health.current
	CombatUtils.deal_damage(player, 20.0, -77)
	_check(is_equal_approx(player.health.current, vida_madara),
		"lo que le pegan mientras dura se lo come el escudo, no la vida")
	cortado.queue_free()
	await get_tree().create_timer(Susanoo.DURACION).timeout

	# --- TENGAI SHINSEI: dos meteoritos gigantes, uno tras otro, sobre el que apunta ---
	player.respawn_at(puesto, yaw)
	player.status.clear_all()
	var aplastado := _spawn_dummy(arena, puesto + rumbo * 12.0)
	aplastado.health.set_max(3000.0)
	for _i: int in range(12):
		await get_tree().physics_frame
	vida = aplastado.health.current
	player.stamina.restore_full()
	player.caster.reset_state()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.request_use(3)
	var carga := TengaiShinsei.new().channel_time
	await get_tree().create_timer(carga + TengaiShinsei.CAIDA * 0.5).timeout
	_check(is_equal_approx(aplastado.health.current, vida),
		"los meteoritos se ven venir: a mitad de la caida todavia no pego nada")
	await get_tree().create_timer(TengaiShinsei.CAIDA * 0.5 + 0.25).timeout
	var primero := vida - aplastado.health.current
	await get_tree().create_timer(TengaiShinsei.ENTRE).timeout
	var total := vida - aplastado.health.current
	_check(primero >= TengaiShinsei.DAMAGE * 0.9 and total >= TengaiShinsei.DAMAGE * 1.8,
		"caen dos meteoritos, uno tras otro, sobre el que apunta (%.0f el primero, %.0f entre los dos)" % [
			primero, total])
	_check(player.ultimate.current < 1.0,
		"y su propio daño no le recarga el medidor (quedo en %.0f)" % player.ultimate.current)
	aplastado.queue_free()

	# Sus skins: las tres, en la tienda.
	var suyas := SkinDB.de_personaje(&"madara")
	var en_tienda := 0
	for sid: StringName in suyas:
		if SkinDB.get_skin(sid).precio > 0:
			en_tienda += 1
	_check(suyas.size() >= 3 and en_tienda == suyas.size(),
		"Madara tiene sus skins y estan todas en la tienda (%d de %d)" % [en_tienda, suyas.size()])

	player.aim_override = Vector3.ZERO
	player.setup_character(CharacterDB.get_character(&"sonic"))
	player.caster.reset_state()
	player.status.clear_all()
	player.health.revive_full()
	Arena.set_bots_active(true)


func _test_practica(player: Player, arena: Arena) -> void:
	Practica.restablecer()
	_check(Practica.bots == 3 and not Practica.invulnerable,
		"la practica arranca en valores de fabrica")

	# --- Stamina infinita ---
	player.stamina.restore_full()
	var antes_stamina := player.stamina.current
	Practica.set_stamina_infinita(true)
	var gasto := player.stamina.try_spend(60.0)
	_check(gasto and is_equal_approx(player.stamina.current, antes_stamina),
		"stamina infinita: la habilidad sale y la barra no baja")
	Practica.set_stamina_infinita(false)
	_check(player.stamina.try_spend(60.0) and player.stamina.current < antes_stamina,
		"y apagandola vuelve a costar")

	# --- Sin cooldowns ---
	player.caster.reset_state()
	player.stamina.restore_full()
	player.caster.request_use(1)
	await get_tree().process_frame
	_check(player.caster.is_on_cooldown(1), "normalmente una habilidad queda en espera")
	Practica.set_sin_cooldowns(true)
	_check(not player.caster.is_on_cooldown(1), "sin esperas: se puede repetir en el acto")
	Practica.set_sin_cooldowns(false)

	# --- No puedo morir ---
	player.health.revive_full()
	Practica.set_invulnerable(true)
	player.health.apply_damage(player.health.max_health * 3.0, FUENTE_NEUTRA)
	_check(not player.health.is_dead and player.health.current > 0.0,
		"no puedo morir: la vida se planta en %.0f en vez de llegar a cero" % player.health.current)
	_check(player.health.current < player.health.max_health,
		"pero la vida SI baja y se ve: no es un escudo, es un piso")
	Practica.set_invulnerable(false)
	player.health.revive_full()

	# --- Cuanto pegan los bots ---
	var maniqui := _spawn_dummy(arena, arena.find_clear_spot(Vector3(20.0, 0.6, -20.0), 1.5))
	maniqui.health.set_max(2000.0)
	await get_tree().process_frame
	# Fuente NEGATIVA a proposito: asi se reconoce a un bot en deal_damage.
	Practica.set_daño_bots(0.0)
	var vida := maniqui.health.current
	CombatUtils.deal_damage(maniqui, 50.0, -1)
	_check(is_equal_approx(maniqui.health.current, vida),
		"en x0 los bots atacan igual pero no sacan vida")
	Practica.set_daño_bots(1.0)
	CombatUtils.deal_damage(maniqui, 50.0, -1)
	_check(maniqui.health.current < vida, "y en x1 vuelven a pegar")

	# --- Que se peleen entre ellos ---
	#
	# Se le pregunta AL CEREBRO a quien elige, en vez de mirar barras de vida. Mirando
	# vida, un bot que no llega a tiempo se confundiria con uno que no cambio de
	# objetivo, y serian dos bugs distintos con el mismo sintoma.
	#
	# El cerebro se arma a mano porque este arnes hostea una partida en vez de usar el
	# modo solo, asi que la arena no spawnea bots propios: los unicos maniquies son los
	# que crea el test, y esos no traen cerebro.
	var uno := _spawn_dummy(arena, arena.find_clear_spot(Vector3(-24.0, 0.6, -16.0), 1.5))
	var otro := _spawn_dummy(arena, uno.global_position + Vector3(3.0, 0.0, 0.0))
	var cerebro := BotBrain.new()
	cerebro.name = "BotBrain"
	cerebro.setup(uno, uno.global_position)
	uno.add_child(cerebro)
	await get_tree().process_frame
	await get_tree().process_frame

	Practica.set_bots_se_pelean(false)
	var elegido := cerebro._pick_target()
	_check(elegido != null and not elegido.is_dummy,
		"apagado, un bot te elige a VOS aunque tenga otro bot al lado")

	Practica.set_bots_se_pelean(true)
	var rival := cerebro._pick_target()
	_check(rival == otro,
		"prendido, elige al bot que tiene a tres metros en vez de a vos")

	Practica.restablecer()
	_check(cerebro._pick_target() != otro,
		"y al restablecer vuelve a ignorar a los otros bots")

	# --- Castigar al que canaliza ---
	#
	# El bot tiene que dejar de orbitar y venirse encima del que esta cargando algo. Es
	# lo que le enseña al jugador que canalizar en campo abierto se paga; sin esto podes
	# cargar un Snowgrave a tres metros de un bot y el bot sigue haciendo circulos.
	# AL JUGADOR SE LO PLANTA EN UN LUGAR CONOCIDO PRIMERO.
	#
	# El test de Rick termina con el jugador teletransportado a donde haya quedado, que
	# puede ser contra una pared del mapa. Colocando al bot a nueve metros de ahi sin
	# mirar, el bot puede caer fuera de la arena o dentro de una cobertura, y entonces
	# lo que se mide no es si persigue sino donde lo pusimos.
	# EN LA PLAZA, que es la zona abierta del mapa, y con los DOS puntos buscados.
	#
	# Antes plantaba al jugador con find_clear_spot y al bot nueve metros al este SIN
	# mirar. En el mapa nuevo eso cae a veces sobre una rampa o contra un bloque, y
	# entonces lo que falla no es que el bot no persiga sino donde lo pusimos: el chequeo
	# venia dando 0.99, 0.32 y 0.26 en corridas seguidas sin que nada cambiara.
	var claro := arena.find_clear_spot(Vector3(40.0, 0.6, 38.0), 2.5)
	player.global_position = claro
	await get_tree().physics_frame
	uno.global_position = arena.find_clear_spot(claro + Vector3(9.0, 0.0, 0.0), 1.2)
	uno.bot_move_dir = Vector3.ZERO
	uno.bot_wants_run = false
	# El bot se resetea antes de medirlo. El bloque de arriba pone a los bots a pelear
	# entre ellos, y un bot congelado o aturdido por el otro no se moveria por una razon
	# que no tiene nada que ver con lo que se mide aca. (No era la causa del fallo
	# intermitente de abajo —se comprobo: el bot podia actuar, estaba vivo y tenia blanco—,
	# pero es un estado ajeno que no tiene por que entrar en la medicion.)
	uno.health.revive_full()
	uno.status.clear_all()
	uno.caster.reset_state()
	player.stamina.restore_full()
	player.ultimate.current = UltimateCharge.MAX_CHARGE
	player.caster.reset_state()
	player.caster.request_use(3)
	await get_tree().process_frame
	_check(player.caster.is_channeling, "el jugador esta canalizando para el chequeo")
	# SE ESPERA TIEMPO DE JUEGO, NO FRAMES, y esta era la causa del fallo intermitente.
	#
	# El cerebro piensa cada THINK_INTERVAL (0.2 s de juego). Esto esperaba 24 frames
	# dando por sentado que eran 0.4 s, o sea sesenta por segundo — pero sin pantalla Godot
	# dibuja tan rapido como puede, y medido, 24 frames eran 0.163 s: MENOS que un ciclo de
	# pensamiento. Si el ultimo pensamiento del bot habia caido justo antes de que la prueba
	# le pusiera la direccion en cero, no volvia a pensar dentro de la ventana y el chequeo
	# daba 0.00 exacto; si caia despues, 0.99. Todo o nada, y segun cuanto pesara cada frame,
	# que es por lo que cualquier cambio en otro lado del juego lo destapaba.
	#
	# Un temporizador cuenta tiempo de juego y no frames: dos ciclos y medio de pensamiento
	# pasan siempre, a cualquier velocidad de dibujo. Y el canalizado de la definitiva que
	# este usando el jugador dura mas que eso, asi que sigue cargando cuando se mide.
	await get_tree().create_timer(BotBrain.THINK_INTERVAL * 2.5).timeout
	var hacia_vos := (player.global_position - uno.global_position).normalized()
	var va_hacia := uno.bot_move_dir.dot(hacia_vos)
	_check(uno.bot_wants_run and va_hacia > 0.4,
		"el bot corre a cortarte el canalizado (alineacion %.2f%s)" % [va_hacia,
			"" if va_hacia > 0.4 else ", puede actuar: %s, muerto: %s, a %.1f m, global: %s, activos: %s, blanco: %s, piensa en: %.2f, canaliza: %s" % [
				uno.status.can_act(), uno.health.is_dead,
				uno.global_position.distance_to(player.global_position),
				BotBrain.globally_enabled, Practica.bots_activos,
				str(cerebro._pick_target().name) if cerebro._pick_target() != null else "NINGUNO",
				cerebro._think_left, player.caster.is_channeling]])
	player.caster.cancel_channel()

	uno.queue_free()
	otro.queue_free()
	maniqui.queue_free()


# ------------------------------------------------------------------- Resultados

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  OK   ", description)
	else:
		print("  FALLA ", description)
		_failures.append(description)


## Minimo de chequeos que esta suite TIENE que correr.
##
## Ya paso tres veces, siempre igual y siempre en verde: una corrutina se corta a la
## mitad y el resumen dice "TODO OK" con veinte pruebas menos. Las tres causas fueron
## distintas —un error de tipo, un id que paso a ser archivo, y una funcion que se volvio
## corrutina sin que su llamador la esperara— y las tres se vieron igual: nada.
##
## Subir este numero al agregar chequeos es el precio de que el verde signifique algo.
## LO QUE DICE UNA HABILIDAD ES LO QUE HACE. Dos descripciones tenian el daño escrito a
## mano y quedaron mintiendo cuando se balanceo el numero (los cuchillos de Dio decian 12
## con 10 de daño). La que habla de daño tiene que decir el de su constante DAMAGE; las que
## no dan numeros ("Gratis, rapida, corto alcance") no mienten.
func _test_descripciones() -> void:
	var mal := ""
	for pj: StringName in CharacterDB.get_all_ids():
		for ability: Ability in CharacterDB.build_abilities_for(pj):
			var constantes: Dictionary = ability.get_script().get_script_constant_map()
			if not constantes.has("DAMAGE"):
				continue
			var daño := str(int(constantes["DAMAGE"]))
			if ability.description.contains("daño") and not ability.description.contains(daño):
				mal += "%s(%s) " % [ability.id, daño]
	_check(mal.is_empty(), "las descripciones muestran el daño de verdad %s" % mal)


## UNA ESCENA CORTA LO QUE VENIA PASANDO. Jugando el capitulo 4, la escena de mitad de
## pelea arranco con Flowery a mitad de JARONA, y siguio "tirando jaronas" durante todo el
## dialogo: destello, grito y ondas en cada una de las diez pasadas, quieta en el lugar.
func _test_escena_corta_habilidades(player: Player) -> void:
	player.health.revive_full()
	player.status.clear_all()
	var antes := player.global_position
	Cinematica.activa = true
	var t0 := Time.get_ticks_msec()
	await Jarona.correr_embestida(player, Vector3.FORWARD, Jarona.MAX_PASSES, Jarona.DAMAGE,
		Callable(), 0)
	var tardo := Time.get_ticks_msec() - t0
	Cinematica.activa = false
	_check(tardo < 100 and player.global_position.distance_to(antes) < 0.2,
		"una JARONA que arranca durante una escena se corta enseguida (%d ms)" % tardo)


const CHEQUEOS_MINIMOS: int = 249


func _finish() -> void:
	if _checks < CHEQUEOS_MINIMOS:
		_failures.append("la suite corrio %d chequeos y tenia que correr al menos %d: se corto a la mitad" % [
			_checks, CHEQUEOS_MINIMOS])
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
