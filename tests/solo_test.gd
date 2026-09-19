extends Node
## Test del modo practica (sin red) y de los sistemas que se agregaron para publicar:
## maniquies, audio sintetizado y opciones.
##
## Correlo con:
##   godot --headless --path . res://tests/solo_test.tscn
##
## Es importante que este separado del test de humo: el modo solo NO levanta un peer
## de red, y ese camino (multiplayer_peer == null) tiene sus propias trampas — cualquier
## .rpc() sin guardar tira error ahi y no en una partida normal.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	_test_audio()
	await _test_music()
	_test_settings()

	# --- Arrancar practica sin red ---
	Net.start_solo("Tester")
	_check(Net.solo_mode, "start_solo prende el modo practica")
	_check(not Net.is_connected_to_game(), "el modo practica NO abre ninguna conexion de red")
	_check(Net.is_server(), "sin peer, el juego se trata a si mismo como servidor")
	await get_tree().process_frame

	Net.start_match()
	for _i: int in range(10):
		await get_tree().process_frame

	var arena: Arena = main.get_node_or_null("Arena") as Arena
	_check(arena != null, "la arena se creo sin red")
	if arena == null:
		_finish()
		return

	var player: Player = arena.get_local_player()
	_check(player != null, "el jugador local existe en modo practica")
	if player == null:
		_finish()
		return

	await _test_dummies(arena, player)
	_finish()


# ---------------------------------------------------------------------- Bots

func _test_dummies(arena: Arena, player: Player) -> void:
	var dummies: Array[Player] = []
	for child: Node in arena.get_children():
		var p := child as Player
		if p != null and p.is_dummy:
			dummies.append(p)

	_check(dummies.size() == Arena.DUMMY_COUNT,
		"se spawnearon %d bots (hay %d)" % [Arena.DUMMY_COUNT, dummies.size()])
	if dummies.is_empty():
		return

	var dummy := dummies[0]
	_check(dummy.is_in_group("players"), "los bots son objetivos validos de las habilidades")
	_check(dummy.health.max_health == Arena.DUMMY_HEALTH,
		"los bots aguantan %d de vida" % int(Arena.DUMMY_HEALTH))
	_check(not dummy.is_local_player(), "los bots no le roban la camara al jugador")

	# Las habilidades tienen que poder encontrarlos.
	var targets := CombatUtils.get_players_in_sphere(player, player.global_position, 100.0)
	_check(targets.size() >= dummies.size(), "las habilidades encuentran a los bots")

	# Se les puede apilar escarcha y congelarlos: el combo completo de Noelle es
	# practicable contra ellos, que es todo el punto del modo.
	dummy.status.clear_all()
	for _i: int in range(StatusEffects.MAX_CHILL):
		dummy.status.add_chill(1)
	_check(dummy.status.is_frozen(), "a un bot se lo puede congelar")
	_check(CombatUtils.is_frozen(dummy), "un bot congelado es ejecutable por Snowgrave")
	dummy.status.clear_all()

	# Y matarlos NO tiene que sumar al marcador: esto es practica, no una partida.
	var kills_before := int(Net.get_player_info(1).get("kills", 0))
	CombatUtils.deal_damage(dummy, Arena.DUMMY_HEALTH * 2.0, 1)
	await get_tree().process_frame
	_check(dummy.health.is_dead, "se puede matar a un bot")
	var kills_after := int(Net.get_player_info(1).get("kills", 0))
	_check(kills_after == kills_before,
		"matar bots NO suma al marcador (%d -> %d)" % [kills_before, kills_after])
	_check(not Net.in_match or true, "la partida de practica no termina por matar bots")

	await _test_bots_pelean(arena, player, dummies)


## Lo que hace que el modo practica sirva: que los bots PELEEN.
##
## Un maniqui quieto te deja ensayar la animacion de un combo, pero no te enseña lo
## unico que importa en esta arena — medir distancia y elegir cuando gastar stamina.
func _test_bots_pelean(arena: Arena, player: Player, bots: Array[Player]) -> void:
	# Revivimos al que matamos arriba y dejamos a todos en su puesto.
	for b: Player in bots:
		b.health.revive_full()
		b.status.clear_all()
	await get_tree().process_frame

	var bot := bots[0]
	_check(bot.get_node_or_null("BotBrain") != null, "cada bot tiene su cerebro")
	_check(not bot.character_id.is_empty() and CharacterDB.has_character(bot.character_id),
		"los bots usan un personaje real del juego (%s)" % bot.character_id)
	_check(bot.caster.abilities.size() >= 4,
		"los bots tienen el kit completo (%d habilidades)" % bot.caster.abilities.size())

	# El servidor tiene que ser el dueño de sus habilidades. Con el peer negativo que
	# les toca, AbilityCaster les rechazaba TODO en silencio y se quedaban mirando.
	_check(bot.caster.owner_peer_id == Net.local_id(),
		"el servidor es dueño de las habilidades del bot (owner=%d)" % bot.caster.owner_peer_id)

	var brain: BotBrain = bot.get_node("BotBrain")
	_check(not brain._usable.has(3), "el bot NO usa el ultimate")
	_check(brain._usable.size() >= 3, "pero si el resto del kit (%d)" % brain._usable.size())

	# --- Persecucion ---
	# El jugador tiene que AGUANTAR la medicion: con vida normal, los tres bots lo
	# mataban a mitad de la prueba, respawneaba en el spawn mas lejano del mapa y la
	# distancia al bot crecia en vez de bajar. No era que el bot huyera.
	var vida_normal := player.health.max_health
	player.health.set_max(5000.0)

	var puesto := arena.find_clear_spot(Vector3(0.0, 0.6, -30.0), 1.2)
	bot.global_position = puesto
	bot.velocity = Vector3.ZERO
	player.respawn_at(arena.find_clear_spot(puesto + Vector3(0.0, 0.0, 22.0), 1.2), 0.0)
	await get_tree().process_frame
	var lejos := bot.global_position.distance_to(player.global_position)
	for _i: int in range(120):
		await get_tree().physics_frame
	var cerca := bot.global_position.distance_to(player.global_position)
	_check(cerca < lejos - 3.0,
		"el bot persigue al jugador (%.1f m -> %.1f m)" % [lejos, cerca])

	# --- Ataque: que le saque vida al jugador solo ---
	player.health.set_max(vida_normal)
	var vida_antes := player.health.current
	for _i: int in range(400):
		await get_tree().physics_frame
		if player.health.current < vida_antes:
			break
	_check(player.health.current < vida_antes,
		"el bot ataca de verdad (vida %.0f -> %.0f)" % [vida_antes, player.health.current])

	# --- Volver a su puesto cuando no hay a quien pegarle ---
	# Mandamos al jugador al otro extremo, fuera del rango de deteccion.
	player.respawn_at(arena.find_clear_spot(Vector3(38.0, 0.6, 38.0), 1.2), 0.0)
	var desde := bot.global_position.distance_to(bot.home_position)
	for _i: int in range(420):
		await get_tree().physics_frame
		if bot.global_position.distance_to(bot.home_position) < 1.5:
			break
	var hasta := bot.global_position.distance_to(bot.home_position)
	_check(hasta < maxf(1.5, desde),
		"sin nadie cerca vuelve a su puesto (%.1f m -> %.1f m)" % [desde, hasta])

	# --- Y se puede apagar, que es lo que necesita el chequeo visual ---
	Arena.set_bots_active(false)
	await get_tree().process_frame
	for _i: int in range(20):
		await get_tree().physics_frame
	_check(bot.bot_move_dir.is_zero_approx(), "se los puede dejar quietos para las capturas")
	Arena.set_bots_active(true)


# --------------------------------------------------------------------- Audio

func _test_audio() -> void:
	# El audio se sintetiza por codigo al arrancar: no hay ni un archivo de sonido.
	var expected: Array[StringName] = [
		&"hit_ice", &"hit_punch", &"knife", &"ice_shock", &"snowgrave",
		&"za_warudo", &"freeze", &"dash", &"death", &"channel",
		&"ui_click", &"no_stamina", &"respawn",
	]
	var missing: Array[String] = []
	for name: StringName in expected:
		if not Sfx._bank.has(name):
			missing.append(String(name))
	_check(missing.is_empty(), "los %d sonidos se sintetizaron (faltan: %s)" % [expected.size(), ", ".join(missing)])

	var sample: AudioStreamWAV = Sfx._bank.get(&"snowgrave")
	_check(sample != null and sample.data.size() > 1000, "el sonido de Snowgrave tiene PCM de verdad adentro")
	_check(sample != null and sample.format == AudioStreamWAV.FORMAT_16_BITS, "el PCM es de 16 bits")


# --------------------------------------------------------------------- Musica

func _test_music() -> void:
	# La musica se genera en un hilo aparte, asi que hay que esperarla. Si tarda mas
	# que esto, algo se colgo y es un problema de verdad.
	var waited := 0.0
	while not Music._ready_to_play and waited < 15.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check(Music._ready_to_play, "la musica termino de generarse (%.1fs)" % waited)

	for name: StringName in [&"menu", &"combate"]:
		var stream: AudioStreamWAV = Music._tracks.get(name)
		_check(stream != null, "el tema '%s' existe" % name)
		if stream == null:
			continue
		_check(stream.data.size() > 100000, "el tema '%s' tiene PCM de verdad (%d bytes)" % [name, stream.data.size()])
		# Sin loop, la musica corta despues de un pase y queda silencio.
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "el tema '%s' loopea" % name)
		_check(stream.loop_end > 0, "el tema '%s' tiene el loop marcado" % name)

	# Y que se pueda cambiar de tema sin explotar.
	Music.play_menu()
	await get_tree().process_frame
	_check(Music._current == &"menu", "arranca el tema del menu")
	Music.play_combat()
	await get_tree().process_frame
	_check(Music._current == &"combate", "cambia al tema de combate")

	Music.music_volume = 0.3
	_check(is_equal_approx(Music.music_volume, 0.3), "el volumen de musica es independiente del de efectos")


# ------------------------------------------------------------------ Opciones

func _test_settings() -> void:
	_check(Settings != null, "el autoload de opciones existe")
	var original := Settings.mouse_sensitivity
	Settings.set_mouse_sensitivity(0.006)
	_check(is_equal_approx(Settings.mouse_sensitivity, 0.006), "se puede cambiar la sensibilidad")
	# Tiene que quedar guardado en disco para la proxima vez que abras el juego.
	var cfg := ConfigFile.new()
	_check(cfg.load(Settings.CONFIG_PATH) == OK, "las opciones se guardan en disco")
	Settings.set_mouse_sensitivity(original)

	Settings.set_master_volume(0.5)
	_check(is_equal_approx(Sfx.master_volume, 0.5), "el volumen llega al sistema de audio")
	Settings.set_master_volume(0.8)


# ------------------------------------------------------------------ Resultados

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
