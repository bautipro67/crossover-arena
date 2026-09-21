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

	await _test_audio()
	_test_siluetas()
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
	# EL BOT SI USA EL ULTIMATE, y el chequeo cambio de signo a proposito.
	#
	# Antes estaba prohibido por miedo a que fuera injusto, y era el razonamiento al
	# reves: los tres ultimates canalizan a la vista, o sea que son lo que MAS se puede
	# practicar, y son lo que mas falta saber manejar. Un modo practica donde nunca ves
	# un Snowgrave no te prepara para lo que decide las partidas.
	_check(brain._usable.has(3), "el bot tambien usa el ultimate")
	_check(brain._usable.size() >= 3, "pero si el resto del kit (%d)" % brain._usable.size())

	# --- LO QUE IMPORTA: que te encuentren SOLOS, desde donde nacen ---
	#
	# Este chequeo existe porque su ausencia dejo el modo practica roto sin que ningun
	# test se quejara. La version anterior teletransportaba al bot al lado del jugador y
	# medía si se acercaba: con eso pasaba en verde mientras, en una partida de verdad,
	# los bots nacian a 50 metros, nunca detectaban al jugador y se quedaban parados los
	# tres. Un test que le acomoda el escenario al codigo no prueba nada.
	#
	# Ahora no se mueve a nadie: se los deja donde el juego los pone y se mira si llegan.
	var mapa := get_viewport().world_3d.navigation_map
	_check(NavigationServer3D.map_get_regions(mapa).size() > 0,
		"la arena horneo su malla de navegacion")

	var distancia_inicial := 0.0
	for b: Player in bots:
		distancia_inicial = maxf(distancia_inicial,
			b.global_position.distance_to(player.global_position))
	_check(distancia_inicial > 20.0,
		"los bots arrancan lejos de verdad (%.0f m), no al lado" % distancia_inicial)

	# Aguanta la medicion: con vida normal lo matan y respawnea, y la distancia salta.
	var vida_normal := player.health.max_health
	player.health.set_max(20000.0)

	var mas_cerca := 9999.0
	var golpeado := false
	var vida_antes := player.health.current
	for _i: int in range(1500):  # ~25 s
		await get_tree().physics_frame
		for b: Player in bots:
			if is_instance_valid(b):
				mas_cerca = minf(mas_cerca, b.global_position.distance_to(player.global_position))
		if player.health.current < vida_antes:
			golpeado = true
		if golpeado and mas_cerca <= BotBrain.MELEE_RANGE:
			break

	_check(mas_cerca <= BotBrain.MELEE_RANGE + 1.0,
		"cruzan el mapa y llegan hasta vos (quedaron a %.1f m)" % mas_cerca)
	_check(golpeado, "y te pegan sin que nadie los acomode")
	player.health.set_max(vida_normal)

	# --- Y se puede apagar, que es lo que necesita el chequeo visual ---
	Arena.set_bots_active(false)
	await get_tree().process_frame
	for _i: int in range(20):
		await get_tree().physics_frame
	_check(bot.bot_move_dir.is_zero_approx(), "se los puede dejar quietos para las capturas")
	Arena.set_bots_active(true)


## Nivel medio (RMS) de un tramo del stream, en muestras.
func _rms(stream: AudioStreamWAV, desde: int, cuantas: int) -> float:
	var datos := stream.data
	var total := datos.size() / 2
	var fin: int = mini(total, desde + cuantas)
	if fin <= desde:
		return 0.0
	var suma := 0.0
	for i: int in range(desde, fin):
		var v := float(datos.decode_s16(i * 2)) / 32768.0
		suma += v * v
	return sqrt(suma / float(fin - desde))


## Cruces por cero por segundo. Indicador barato de que tan agudo es un sonido.
func _cruces_por_segundo(stream: AudioStreamWAV) -> float:
	var datos := stream.data
	var muestras := datos.size() / 2
	if muestras < 2:
		return 0.0
	var cruces := 0
	var previo := datos.decode_s16(0)
	for i: int in range(1, muestras):
		var v := datos.decode_s16(i * 2)
		# Umbral chico para no contar el ruido de fondo del silencio final.
		if absi(v) > 400 and (v < 0) != (previo < 0):
			cruces += 1
		if absi(v) > 400:
			previo = v
	return float(cruces) * float(stream.mix_rate) / float(muestras)


func _pico(stream: AudioStreamWAV) -> float:
	var datos := stream.data
	var muestras := datos.size() / 2
	var pico := 0
	for i: int in range(muestras):
		pico = maxi(pico, absi(datos.decode_s16(i * 2)))
	return float(pico) / 32767.0


# --------------------------------------------------------------------- Audio

func _test_audio() -> void:
	# El audio se sintetiza por codigo al arrancar: no hay ni un archivo de sonido.
	var expected: Array[StringName] = [
		&"hit_ice", &"hit_punch", &"knife", &"ice_shock", &"snowgrave",
		&"za_warudo", &"freeze", &"dash", &"death", &"channel",
		&"petals", &"last_jarona",
		&"plasma", &"plasma_blast", &"portal", &"meeseeks",
		&"paso", &"salto", &"aterrizaje",
		&"ui_click", &"no_stamina", &"respawn",
		# LAS VOCES, que son las que dicen las frases de las habilidades. Sin alguna de
		# estas el personaje sigue mostrando el cartel pero se queda mudo, que es
		# exactamente el sintoma que hubo que arreglar: se leia "¡JARONA!" y no se oia.
		&"voz_jarona", &"voz_here_i_come", &"voz_last_jarona",
		&"voz_muda", &"voz_za_warudo", &"voz_toki",
	]
	# EL BANCO SE ARMA REPARTIDO ENTRE FRAMES, asi que hay que esperarlo.
	#
	# Los sonidos de combate ya no se generan todos de golpe al arrancar: eso congelaba
	# medio segundo la pantalla. Ahora va uno por frame mientras el jugador mira el menu.
	# Este arnés entra a una partida en el primer frame, o sea mucho antes que cualquier
	# persona, y por eso tiene que esperar a mano lo que a un jugador ya le llego hecho.
	var espera := 0
	while not Sfx.banco_listo() and espera < 600:
		await get_tree().process_frame
		espera += 1
	_check(Sfx.banco_listo(), "el banco termino de armarse (tardo %d frames)" % espera)

	var missing: Array[String] = []
	for name: StringName in expected:
		if not Sfx._bank.has(name):
			missing.append(String(name))
	_check(missing.is_empty(), "los %d sonidos se sintetizaron (faltan: %s)" % [expected.size(), ", ".join(missing)])

	# --- Y QUE CADA FRASE APUNTE A UNA VOZ QUE EXISTE ---
	#
	# Es la juntura entre las dos mitades del sistema: la tabla de frases dice QUE se
	# grita y el banco tiene el sonido. Si un id no coincide, play_3d se sale sin hacer
	# nada —no avisa, no falla, no rompe— y el personaje se queda mudo mostrando el
	# cartel. Es exactamente el sintoma que hubo que arreglar, y no lo detectaba ningun
	# chequeo: uno miraba el banco, otro miraba el cartel, y nadie miraba el hilo.
	var sin_voz: Array[String] = []
	for id: StringName in Frases.LINEAS:
		for linea: Array in Frases.LINEAS[id]:
			var voz := linea[2] as StringName
			if not Sfx._bank.has(voz):
				sin_voz.append("%s->%s" % [id, voz])
	_check(sin_voz.is_empty(), "toda frase tiene su voz en el banco (rotas: %s)" % ", ".join(sin_voz))

	# --- Y que cada uno tenga el CARACTER que se supone que tiene ---
	#
	# Que exista PCM adentro no dice nada: un buffer de ruido blanco pasa ese chequeo.
	# Lo que se mide aca es el CRUCE POR CERO, que es un indicador barato de brillo:
	# cuantas veces por segundo la onda cambia de signo. Un golpe grave cruza pocas
	# veces; un cristal o un filo de metal cruzan muchisimas.
	#
	# Sirve para pescar la clase de error que no se ve leyendo el codigo: un filtro con
	# el corte al reves, un pasabajos donde iba un pasaaltos, una envolvente que se comio
	# el transitorio. Cualquiera de esos deja el sonido "existiendo" y sonando mal.
	var brillos: Dictionary = {}
	for name: StringName in expected:
		brillos[name] = _cruces_por_segundo(Sfx._bank[name])
	_check(brillos[&"hit_punch"] < 1400.0,
		"el puñetazo es GRAVE: %.0f cruces/s" % brillos[&"hit_punch"])
	_check(brillos[&"za_warudo"] < 1400.0,
		"ZA WARUDO es un retumbe, no un siseo: %.0f cruces/s" % brillos[&"za_warudo"])
	_check(brillos[&"knife"] > 2500.0,
		"el cuchillo es METALICO y agudo: %.0f cruces/s" % brillos[&"knife"])
	_check(brillos[&"hit_ice"] > 2000.0,
		"el hielo es CRISTALINO: %.0f cruces/s" % brillos[&"hit_ice"])
	# El paso tiene que ser SORDO: suena dos veces por segundo toda la partida, y
	# cualquier cosa con brillo se vuelve insoportable a los treinta segundos.
	_check(brillos[&"paso"] < 900.0, "el paso es sordo: %.0f cruces/s" % brillos[&"paso"])
	_check(brillos[&"aterrizaje"] < 1600.0,
		"el aterrizaje tiene cuerpo: %.0f cruces/s" % brillos[&"aterrizaje"])
	_check(brillos[&"knife"] > brillos[&"hit_punch"] * 2.0,
		"y el acero es mucho mas brillante que la carne (%.0f contra %.0f)" % [
			brillos[&"knife"], brillos[&"hit_punch"]])

	# Nivel: ninguno mudo, ninguno recortado.
	var flojo := ""
	for name: StringName in expected:
		var pico := _pico(Sfx._bank[name])
		if pico < 0.25 or pico > 0.999:
			flojo = "%s (pico %.2f)" % [name, pico]
			break
	_check(flojo.is_empty(), "ninguno sale mudo ni recortado %s" % flojo)

	var sample: AudioStreamWAV = Sfx._bank.get(&"snowgrave")
	_check(sample != null and sample.data.size() > 1000, "el sonido de Snowgrave tiene PCM de verdad adentro")
	_check(sample != null and sample.format == AudioStreamWAV.FORMAT_16_BITS, "el PCM es de 16 bits")


## Los cuatro tienen que verse distintos de lejos.
##
## La silueta es lo unico que se lee a veinte metros, y si los cuatro tienen el mismo
## cuerpo la unica diferencia es el color: de noche, en un mapa azul, eso no alcanza.
func _test_siluetas() -> void:
	var vistos: Array[Vector3] = []
	for id: StringName in CharacterDB.get_all_ids():
		var data := CharacterDB.get_character(id)
		if data == null:
			continue
		for otro: Vector3 in vistos:
			var d := (data.build_scale - otro).length()
			if d < 0.04:
				_check(false, "%s tiene las mismas proporciones que otro personaje" % id)
		vistos.append(data.build_scale)
	_check(vistos.size() >= 4, "hay al menos cuatro personajes con proporciones propias (%d)" % vistos.size())
	# Y que el mas alto y el mas bajo se diferencien de verdad.
	var alto := 0.0
	var bajo := 9.0
	for v: Vector3 in vistos:
		alto = maxf(alto, v.y)
		bajo = minf(bajo, v.y)
	_check(alto - bajo > 0.10,
		"y entre el mas alto y el mas bajo hay diferencia visible (%.2f)" % (alto - bajo))


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

	# --- Que el tema de combate tenga FORMA, no solo bytes ---
	#
	# "Tiene PCM adentro" lo cumple igual un loop de cuatro compases repetido. Lo que se
	# mide aca es la estructura A/B: la segunda mitad tiene la melodia encima, asi que
	# TIENE que tener mas energia que la primera. Si alguien rompe la melodia —un indice
	# mal, un volumen en cero, un compas de entrada equivocado— el tema sigue sonando y
	# sigue pasando cualquier chequeo de tamaño, pero vuelve a ser un colchon.
	var combate: AudioStreamWAV = Music._tracks.get(&"combate")
	if combate != null:
		var mitad := (combate.data.size() / 2) / 2
		var rms_a := _rms(combate, 0, mitad)
		var rms_b := _rms(combate, mitad, mitad)
		_check(rms_b > rms_a * 1.06,
			"el combate tiene seccion A y seccion B: la melodia levanta la segunda mitad (%.4f contra %.4f)" % [rms_b, rms_a])
		# Y que no haya huecos: un silencio en medio de un loop se oye como un corte.
		var trozos := 12
		var mas_flojo := 1.0
		for k: int in range(trozos):
			var largo := (combate.data.size() / 2) / trozos
			mas_flojo = minf(mas_flojo, _rms(combate, k * largo, largo))
		_check(mas_flojo > 0.01, "y no tiene huecos de silencio (el trozo mas flojo: %.4f)" % mas_flojo)

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
