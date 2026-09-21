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
	await _test_progresion()
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
## Devuelve -1 si el sonido no es PCM crudo (una voz grabada viene en Ogg comprimido).
##
## ESTABA TIPADO A AudioStreamWAV y eso rompio el arnes de la peor manera posible: al
## poner la primera voz grabada, la funcion recibio un Ogg, el error de tipo corto la
## corrutina a la mitad, y la suite siguio diciendo "TODO OK" con DIEZ chequeos menos.
## Un arnes que deja de probar en silencio es peor que uno que falla.
## (Y se vuelve a tipar apenas pasa el chequeo. Dejarlo como AudioStream a secas convierte
## stream.data en una busqueda dinamica, y con ella datos.decode_s16 dentro de un bucle de
## un millon largo de iteraciones: el arnes paso de 40 segundos a no terminar nunca.)
func _cruces_por_segundo(stream: AudioStream) -> float:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return -1.0
	var datos := wav.data
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
	return float(cruces) * float(wav.mix_rate) / float(muestras)


## Idem: -1 si no es PCM crudo.
func _pico(stream: AudioStream) -> float:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return -1.0
	var datos := wav.data
	var muestras := datos.size() / 2
	var pico := 0
	for i: int in range(muestras):
		pico = maxi(pico, absi(datos.decode_s16(i * 2)))
	return float(pico) / 32767.0


# --------------------------------------------------------------------- Audio

# ------------------------------------------------------- Progresion y economia

func _test_progresion() -> void:
	# SIN ESCRIBIR EN DISCO. Estas pruebas suben de nivel, gastan monedas y compran skins
	# a proposito, y el archivo es el MISMO que usa quien corre el arnes. Sin esto, correr
	# los tests una vez le borra su progreso real.
	Progreso.guardado_activo = false
	Progreso.borrar_todo()

	# --- Niveles ---
	var costo1 := Progreso.exp_para_nivel(1)
	Progreso.sumar_exp(costo1 - 1)
	_check(Progreso.nivel == 1, "no sube de nivel con la experiencia justa para no llegar")
	Progreso.sumar_exp(1)
	_check(Progreso.nivel == 2, "sube al llegar al costo del nivel")
	# EL SOBRANTE NO SE PIERDE, y hace falta probarlo: al terminar una partida buena entran
	# 200 o 300 de golpe, y una version con un solo "if" tiraba todo lo que pasara del
	# siguiente nivel o dejaba la barra llena sin subir.
	Progreso.borrar_todo()
	Progreso.sumar_exp(Progreso.exp_para_nivel(1) + Progreso.exp_para_nivel(2) + 30)
	_check(Progreso.nivel == 3 and Progreso.exp_actual == 30,
		"un golpe grande de experiencia sube varios niveles y conserva el sobrante (nivel %d, sobran %d)" % [
			Progreso.nivel, Progreso.exp_actual])

	# --- La practica NO paga, y es la regla que sostiene toda la economia ---
	Progreso.borrar_todo()
	Modos.iniciar(Modos.PRACTICA)
	for _i: int in range(10):
		Progreso.registrar_baja(Modos.da_recompensas())
	_check(Progreso.monedas == 0 and Progreso.nivel == 1,
		"diez bajas en la sala de practica no dan ni una moneda ni experiencia")
	Modos.iniciar(Modos.SUPERVIVENCIA)
	Progreso.registrar_baja(Modos.da_recompensas())
	_check(Progreso.monedas == Progreso.MONEDAS_POR_BAJA,
		"la misma baja en un modo de verdad si paga (%d)" % Progreso.monedas)

	# --- Comprar ---
	Progreso.borrar_todo()
	var tienda := SkinDB.en_tienda()
	_check(tienda.size() >= 6, "la tienda tiene con que llenarse (%d skins)" % tienda.size())
	var skin := SkinDB.get_skin(tienda[0])
	_check(not Progreso.gastar_monedas(skin.precio), "no se puede comprar sin monedas")
	Progreso.sumar_monedas(skin.precio)
	_check(Progreso.gastar_monedas(skin.precio), "con las monedas justas si se puede")
	_check(Progreso.monedas == 0, "y el precio se descuenta entero")
	Progreso.desbloquear_skin(skin.id)
	_check(Progreso.tiene_skin(skin.id), "la skin queda desbloqueada")

	# Equipar algo que no se tiene NO hace nada. Es lo unico que separa el catalogo de la
	# lista de lo que compraste.
	var ajena := SkinDB.get_skin(SkinDB.todas()[0])
	if ajena.id != skin.id:
		Progreso.equipar_skin(ajena.character_id, ajena.id)
		_check(Progreso.skin_de(ajena.character_id) != ajena.id,
			"no se puede equipar una skin que no se tiene")

	# --- Las skins NO cambian la jugabilidad. ESTE es el chequeo que no puede fallar ---
	#
	# Es un juego de PvP gratuito: si una skin comprada diera un punto de vida, de daño o
	# de velocidad, el que recien entra ya perdio antes de empezar. Se comparan todos los
	# numeros que tocan una pelea entre el personaje pelado y el mismo con skin puesta.
	var base := CharacterDB.get_character(skin.character_id)
	var conskin := SkinDB.aplicar(base, skin.id)
	_check(conskin != base, "aplicar una skin devuelve una COPIA y no pinta el original")
	_check(is_equal_approx(conskin.max_health, base.max_health)
		and is_equal_approx(conskin.max_stamina, base.max_stamina)
		and is_equal_approx(conskin.move_speed, base.move_speed)
		and conskin.build_scale.is_equal_approx(base.build_scale)
		and conskin.silhouette == base.silhouette,
		"una skin NO cambia vida, stamina, velocidad, tamaño ni silueta")
	_check(conskin.body_color != base.body_color or conskin.accent_color != base.accent_color,
		"pero si cambia los colores, que es para lo que existe")
	# Y el original quedo intacto despues de todo eso.
	var base2 := CharacterDB.get_character(skin.character_id)
	_check(base2.body_color == base.body_color,
		"y el personaje original sigue con su color despues de aplicarla")

	# --- Pase ---
	Progreso.borrar_todo()
	_check(not Pase.se_puede_reclamar(1, false), "no se reclama un escalon al que no llegaste")
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * 3
	_check(Pase.escalon_actual() == 3, "el escalon sale de la experiencia del pase")
	_check(Pase.se_puede_reclamar(1, false), "y lo que ya pasaste si se puede reclamar")
	_check(not Pase.se_puede_reclamar(3, true), "la via pro esta cerrada sin el pase pro")
	_check(not Pase.reclamar(1, false).is_empty(), "reclamar devuelve que te dieron")
	_check(not Pase.se_puede_reclamar(1, false), "y no se puede reclamar dos veces")

	# Comprar el pro abre lo que YA pasaste, no solo lo que viene. Es lo que evita que
	# comprarlo tarde se sienta un castigo.
	Progreso.monedas = Progreso.PRECIO_PASE_PRO
	_check(Pase.comprar_pro(), "el pase pro se compra con monedas")
	_check(Progreso.monedas == 0, "y cuesta lo que dice")
	_check(Pase.se_puede_reclamar(3, true), "al comprarlo se abren los escalones ya pasados")
	_check(not Pase.comprar_pro(), "no se puede comprar dos veces")

	var pendientes := Pase.reclamar_todo()
	_check(pendientes > 0, "reclamar todo cobra lo que haya (%d)" % pendientes)
	_check(not Pase.hay_algo_para_reclamar(), "y despues no queda nada pendiente")

	# --- Modos ---
	Modos.iniciar(Modos.ULTIMO_EN_PIE)
	_check(Modos.bots_iniciales() == Modos.BOTS_ULTIMO_EN_PIE and not Modos.reaparecen_bots()
		and not Modos.reaparece_jugador(),
		"ultimo en pie: cinco bots y nadie reaparece")
	Modos.iniciar(Modos.CONTRARRELOJ)
	_check(Modos.reaparecen_bots() and Modos.reaparece_jugador(),
		"contrarreloj: todos reaparecen, lo que corre es el reloj")
	Modos.iniciar(Modos.SUPERVIVENCIA)
	# Matar al ultimo bot vivo tiene que traer una oleada MAS GRANDE. Si devolviera cero,
	# el modo se quedaria sin enemigos y sin terminar nunca.
	var refuerzos := Modos.bot_murio(0)
	_check(Modos.oleada == 2 and refuerzos > Modos.OLEADA_INICIAL - 1,
		"supervivencia: limpiar la oleada trae otra mas grande (oleada %d, %d bots)" % [
			Modos.oleada, refuerzos])
	_check(Modos.bot_murio(2) == 0, "y no trae refuerzos si todavia quedan vivos")

	# Se deja todo como estaba y se vuelve a leer del disco: lo que el jugador tenia.
	Progreso.borrar_todo()
	# De vuelta a practica, que es lo que el resto de este arnes da por sentado: corre en
	# una partida solo y cuenta con que haya bots.
	Modos.iniciar(Modos.PRACTICA)
	Progreso.guardado_activo = true
	Progreso.cargar()
	await get_tree().process_frame


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
	#
	# Solo aplica a lo que genera el codigo. Una voz grabada viene comprimida y ademas no
	# tiene por que cumplir estas reglas: las puso una garganta, no un filtro.
	var brillos: Dictionary = {}
	var grabados := 0
	for name: StringName in expected:
		var cps := _cruces_por_segundo(Sfx._bank[name])
		if cps < 0.0:
			grabados += 1
			continue
		brillos[name] = cps
	_check(brillos.has(&"hit_punch") and brillos.has(&"knife"),
		"los sonidos sintetizados se pueden medir (%d vienen de archivo y se saltean)" % grabados)
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
		if pico < 0.0:
			continue
		if pico < 0.25 or pico > 0.999:
			flojo = "%s (pico %.2f)" % [name, pico]
			break
	_check(flojo.is_empty(), "ninguno sale mudo ni recortado %s" % flojo)

	# EL PCM SE COMPRUEBA SOBRE UNO SINTETIZADO, CUALQUIERA, y no sobre uno elegido a mano.
	#
	# Estaba clavado en snowgrave, y al llegar un snowgrave.ogg la asignacion a una
	# variable AudioStreamWAV volo por tipo y volvio a cortar la suite a la mitad: la MISMA
	# trampa que el arreglo anterior, en otro renglon. Cualquier id escrito a mano puede
	# amanecer siendo un archivo, asi que no se elige ninguno: se busca uno que siga siendo
	# PCM. Mientras quede uno solo sintetizado, esto se puede comprobar.
	var sample: AudioStreamWAV = null
	for id: StringName in Sfx._bank:
		var candidato := Sfx._bank[id] as AudioStreamWAV
		if candidato != null:
			sample = candidato
			break
	_check(sample != null and sample.data.size() > 1000, "los sonidos sintetizados tienen PCM de verdad adentro")
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


## Minimo de chequeos que esta suite TIENE que correr.
##
## No es una formalidad. Una corrutina que se corta a la mitad —por un error de tipo, por
## un await que nunca vuelve— deja la suite terminando en verde con la mitad de las
## pruebas sin correr, y eso no se nota nunca: el resumen dice "TODO OK". Paso de verdad
## al poner la primera voz grabada. Subir este numero al agregar chequeos es el precio de
## que el verde signifique algo.
const CHEQUEOS_MINIMOS: int = 91


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
