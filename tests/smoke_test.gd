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
	await _test_economia_stamina(player, arena)
	await _test_defensa_de_hielo(player, arena)
	await _test_rafaga_del_stand(player, arena)
	_test_arena(arena)

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
	var hp_before := player.health.current
	var shield_before := player.health.shield
	CombatUtils.deal_damage(player, 20.0, enemy.peer_id)
	await get_tree().process_frame
	_check(is_equal_approx(player.health.current, hp_before),
		"con escudo, un golpe chico no toca la vida (%.0f)" % player.health.current)
	_check(player.health.shield < shield_before,
		"el escudo bajo en vez de la vida (%.0f -> %.0f)" % [shield_before, player.health.shield])

	# Y el sobrante de un golpe grande SI pasa a la vida: un escudo de 5 no puede
	# anular un Snowgrave de 260.
	var resto := player.health.shield + 30.0
	var hp_antes := player.health.current
	CombatUtils.deal_damage(player, resto, enemy.peer_id)
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
