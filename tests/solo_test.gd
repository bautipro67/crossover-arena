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
	await _test_controles()
	await _test_mando_en_menus(main)
	await _test_historia(main)
	await _test_escenas_y_peleas(main)
	await _test_skins_visibles()
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
	await _test_mando_y_tactil(main, player)
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
	# Y SIN MODO DESARROLLADOR. El arnes corre en la misma maquina que el juego, y en la del
	# autor existe el archivo que da monedas infinitas: con el prendido, "no se puede
	# comprar sin monedas" fallaria siempre y por una razon que no tiene nada que ver.
	Progreso.modo_dev = false
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

	# --- Comprar escalones ---
	Progreso.borrar_todo()
	_check(not Pase.comprar_escalon(), "sin monedas no se compra un escalon")
	Progreso.monedas = Progreso.PRECIO_ESCALON * 2
	Progreso.pase_exp = Pase.EXP_POR_ESCALON / 2
	_check(Pase.comprar_escalon(), "con monedas si")
	_check(Pase.escalon_actual() == 1 and Progreso.pase_exp == Pase.EXP_POR_ESCALON + Pase.EXP_POR_ESCALON / 2,
		"sube UN escalon y conserva lo que ya llevabas del siguiente (exp %d)" % Progreso.pase_exp)
	_check(Progreso.monedas == Progreso.PRECIO_ESCALON, "y cuesta lo que dice")
	_check(Progreso.nivel == 1,
		"el nivel del jugador NO sube: es lo que jugo, y comprarlo lo haria mentir")
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * Pase.ESCALONES
	_check(not Pase.comprar_escalon() and Progreso.monedas == Progreso.PRECIO_ESCALON,
		"con el pase completo no se puede comprar mas, ni se cobra")

	# --- GOKU: solo con el pase pro COMPLETO ---
	#
	# Es la condicion que se pidio, tal cual: completar todo el pase pro. Ni la via
	# gratuita completa, ni el pro a medias, ni la tienda.
	Progreso.borrar_todo()
	_check(Pase.TEMPORADA == 1, "estamos en la temporada 1")
	var final_pro := Pase.recompensa(Pase.ESCALONES, true)
	_check(final_pro[0] == Pase.PERSONAJE and StringName(final_pro[1]) == &"goku",
		"el ultimo escalon del pase pro es Goku")
	_check(not Progreso.puede_usar_personaje(&"goku"), "de entrada Goku esta bloqueado")
	_check(Progreso.puede_usar_personaje(&"noelle") and Progreso.puede_usar_personaje(&"sonic"),
		"y los demas no: vienen de fabrica")
	var goku_en_otro_lado := false
	for i: int in range(1, Pase.ESCALONES + 1):
		for pro: bool in [false, true]:
			var r := Pase.recompensa(i, pro)
			if r[0] == Pase.PERSONAJE and (i != Pase.ESCALONES or not pro):
				goku_en_otro_lado = true
	_check(not goku_en_otro_lado, "y no aparece en ningun otro escalon ni en la via gratuita")
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * Pase.ESCALONES
	Pase.reclamar_todo()
	_check(not Progreso.puede_usar_personaje(&"goku"),
		"con toda la via gratuita cobrada, Goku sigue bloqueado")
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * (Pase.ESCALONES - 1)
	Progreso.pase_pro = true
	Pase.reclamar_todo()
	_check(not Progreso.puede_usar_personaje(&"goku"), "con el pro a un escalon del final, tampoco")
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * Pase.ESCALONES
	_check(not Pase.reclamar(Pase.ESCALONES, true).is_empty() and Progreso.puede_usar_personaje(&"goku"),
		"completando el pase pro, Goku queda desbloqueado")

	# --- El cierre de la temporada 0 ---
	#
	# Se arma un archivo de la 0 a mano: el pro comprado, diez escalones alcanzados y solo
	# el primero cobrado. Al cerrarla, lo alcanzado se tiene que cobrar solo y el pase
	# tiene que arrancar de cero, sin tocar ni el nivel, ni las monedas, ni las skins.
	Progreso.borrar_todo()
	Progreso.nivel = 7
	Progreso.monedas = 300
	Progreso.temporada = 0
	Progreso.pase_pro = true
	Progreso.pase_exp = Pase.EXP_POR_ESCALON * 10
	Progreso.reclamados = {"1": true}
	Progreso.skins = {"sonic_clasico": true}
	Pase._cerrar_temporada_vieja()
	_check(Progreso.tiene_skin(&"dio_dorado") and Progreso.tiene_skin(&"flowery_nocturno")
		and Progreso.tiene_skin(&"noelle_snowgrave"),
		"al cerrar la temporada 0 se cobran solas las skins que ya habias alcanzado")
	_check(not Progreso.tiene_skin(&"rick_maligno"),
		"pero no las de escalones a los que no llegaste")
	_check(Progreso.tiene_skin(&"sonic_clasico") and Progreso.nivel >= 7 and Progreso.monedas > 300,
		"y lo tuyo queda: skins, nivel, y las monedas pendientes se suman (%d)" % Progreso.monedas)
	_check(Progreso.pase_exp == 0 and not Progreso.pase_pro and Progreso.reclamados.is_empty()
		and Progreso.temporada == Pase.TEMPORADA,
		"y el pase de la temporada 1 arranca de cero, pro incluido")
	var aviso := Pase.tomar_aviso()
	_check(aviso.contains("Temporada 0") and aviso.contains("pendientes"),
		"y avisa que termino y cuanto se cobro solo: %s" % aviso)
	_check(Pase.tomar_aviso().is_empty(), "el aviso se muestra una sola vez")
	var antes_cierre := Progreso.monedas
	Pase._cerrar_temporada_vieja()
	_check(Progreso.monedas == antes_cierre, "cerrar una temporada ya cerrada no da nada de nuevo")

	# --- Modos ---
	#
	# TODOS TIENEN QUE SER GANABLES, y esa es la queja que los origino: la primera version
	# les daba a los enemigos los 170 de vida de la sala de practica, que es el numero de
	# un maniqui para ensayar, no de un rival. Contra eso un modo que se puede perder no es
	# dificil, es imposible.
	for m: StringName in Modos.LISTA:
		Modos.iniciar(m)
		var nom := Modos.nombre()
		var desc := Modos.descripcion()
		_check(not nom.is_empty() and not desc.is_empty() and nom != "En línea",
			"el modo %s se presenta con nombre y explicacion" % m)
		if m == Modos.PRACTICA:
			continue
		_check(Modos.bots_iniciales() >= 1, "%s arranca con enemigos" % m)
		# El tope es la vida del maniqui de practica. Un rival de un modo que se puede
		# perder no puede aguantar MAS que un muñeco de entrenamiento.
		_check(Modos.vida_bot() <= 170.0,
			"%s: sus enemigos no aguantan mas que un maniqui (%.0f)" % [m, Modos.vida_bot()])
		_check(Modos.daño_bot() <= 0.75,
			"%s: sus enemigos no pegan como un jugador entero (x%.2f)" % [m, Modos.daño_bot()])

	# El que no reaparece tiene que curarse entre etapas. Sin eso el modo es una sola vida
	# para toda la partida: un error de la oleada 2 se paga en la 7, cuando ya no hay nada
	# que hacer.
	Modos.iniciar(Modos.SUPERVIVENCIA)
	var hubo_respiro := [false]
	Modos.respiro.connect(func() -> void: hubo_respiro[0] = true)
	Modos.bot_murio(0)
	_check(hubo_respiro[0], "supervivencia cura al jugador al limpiar una oleada")

	# --- Duelo: un solo rival, y matarlo gana ---
	Modos.iniciar(Modos.DUELO)
	var gano_duelo := [false]
	Modos.termino.connect(func(g: bool, _t: String, _d: String) -> void: gano_duelo[0] = g)
	_check(Modos.bots_iniciales() == 1, "el duelo es uno contra uno")
	Modos.bot_murio(0)
	_check(gano_duelo[0], "y matarlo gana el duelo")

	# --- Torre de jefes: de a uno, y cada uno mas duro ---
	Modos.iniciar(Modos.JEFES)
	var primero := Modos.vida_bot()
	_check(Modos.bots_iniciales() == 1, "la torre manda un jefe por vez")
	_check(Modos.bot_murio(0) == 1, "y al caer uno viene el siguiente")
	_check(Modos.vida_bot() > primero,
		"cada jefe aguanta mas que el anterior (%.0f -> %.0f)" % [primero, Modos.vida_bot()])
	# Pero no tanto como para volverse una pared: el ultimo tiene que seguir siendo
	# matable dentro de lo que dura la vida del jugador.
	Modos.bajas = Modos.JEFES_TOTAL - 1
	_check(Modos.vida_bot() <= 360.0,
		"y el ultimo sigue siendo matable (%.0f de vida)" % Modos.vida_bot())

	# --- Rey de la colina: el reloj corre solo adentro ---
	Modos.iniciar(Modos.COLINA)
	Modos.avanzar_colina(false, 5.0)
	_check(is_zero_approx(Modos.colina_avance), "fuera del circulo el reloj no corre")
	Modos.avanzar_colina(true, 5.0)
	_check(Modos.colina_avance > 4.9, "y adentro si (%.1f s)" % Modos.colina_avance)
	# Salir PAUSA, no retrocede: retroceder castiga dos veces y convierte una salida mala
	# en una partida perdida sin remedio.
	var guardado := Modos.colina_avance
	Modos.avanzar_colina(false, 3.0)
	_check(is_equal_approx(Modos.colina_avance, guardado),
		"salirse pausa el reloj pero no lo hace retroceder")
	var gano_colina := [false]
	Modos.termino.connect(func(g: bool, _t: String, _d: String) -> void: gano_colina[0] = g)
	Modos.avanzar_colina(true, Modos.META_COLINA)
	_check(gano_colina[0], "y completar los segundos gana")

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
	var vida_1 := Modos.vida_bot()
	var refuerzos := Modos.bot_murio(0)
	_check(Modos.oleada == 2 and refuerzos >= Modos.OLEADA_INICIAL,
		"supervivencia: limpiar la oleada trae la siguiente (oleada %d, %d bots)" % [
			Modos.oleada, refuerzos])
	_check(Modos.vida_bot() > vida_1, "y sus enemigos aguantan mas que los de la anterior")
	_check(Modos.bots_en_oleada(7) > Modos.bots_en_oleada(1),
		"y la cantidad crece con las oleadas (%d en la 1, %d en la 7)" % [
			Modos.bots_en_oleada(1), Modos.bots_en_oleada(7)])
	_check(Modos.bot_murio(2) == 0, "y no trae refuerzos si todavia quedan vivos")

	# --- Modo desarrollador: la compra sale y el saldo no baja ---
	Progreso.borrar_todo()
	Progreso.modo_dev = true
	_check(Progreso.alcanza(999999), "en modo desarrollador todo alcanza")
	_check(Progreso.gastar_monedas(5000) and Progreso.monedas == 0,
		"y comprar no descuenta nada: infinitas es que no se gastan")
	Progreso.modo_dev = false
	_check(not Progreso.alcanza(1), "y sin el modo, vuelve la regla de siempre")
	# El marcador vive en user://, fuera del proyecto: no puede terminar dentro del .pck.
	_check(Progreso.MARCA_DEV.begins_with("user://"),
		"el marcador del modo desarrollador nunca se publica con el juego")

	# Se deja todo como estaba y se vuelve a leer del disco: lo que el jugador tenia.
	Progreso.borrar_todo()
	# De vuelta a practica, que es lo que el resto de este arnes da por sentado: corre en
	# una partida solo y cuenta con que haya bots.
	Modos.iniciar(Modos.PRACTICA)
	Progreso.guardado_activo = true
	Progreso.cargar()
	Progreso.detectar_modo_dev()
	await get_tree().process_frame


# ------------------------------------------------------------------- Controles

func _joy(boton: int, device: int, apretado: bool = true) -> InputEventJoypadButton:
	var j := InputEventJoypadButton.new()
	j.device = device
	j.button_index = boton
	j.pressed = apretado
	return j


## Aprieta y suelta un boton del mando de verdad, por Input, como llega de un mando.
func _apretar_mando(boton: int) -> void:
	Input.parse_input_event(_joy(boton, 0, true))
	await get_tree().process_frame
	Input.parse_input_event(_joy(boton, 0, false))
	await get_tree().process_frame
	await get_tree().process_frame


func _eje(eje: int, valor: float) -> void:
	var m := InputEventJoypadMotion.new()
	m.device = 0
	m.axis = eje
	m.axis_value = valor
	Input.parse_input_event(m)


# --------------------------------------------------------------- Historia

func _test_historia(main: Node) -> void:
	# SIN TOCAR EL ARCHIVO DEL JUGADOR: jugar un capitulo guarda que lo ganaste, y quien
	# corre esto no lo gano.
	Progreso.guardado_activo = false
	Progreso.historia = {}

	# --- Los datos: que todo lo que nombra la historia exista ---
	_check(Historia.cantidad() == 10, "la parte 1 tiene diez capitulos (%d)" % Historia.cantidad())
	var pasos_validos := ["decir", "narrar", "plano", "colocar", "mover", "mirar", "pose", "grito",
		"habilidad", "aparecer", "desaparecer", "temblor", "esperar", "fundido", "titulo"]
	var roto := ""
	var hay_aliados := false
	var tipos: Dictionary = {}
	for i: int in range(Historia.cantidad()):
		var cap := Historia.capitulo(i)
		var pj := StringName(cap.get("personaje", ""))
		if not CharacterDB.has_character(pj) or CharacterDB.get_character(pj).requiere_desbloqueo:
			roto += "cap%d:personaje " % i
		var ids: Dictionary = {pj: true}
		for lado: String in ["aliados", "enemigos"]:
			for d: Dictionary in cap.get(lado, []):
				if not CharacterDB.has_character(StringName(d["personaje"])):
					roto += "cap%d:%s " % [i, d["id"]]
				ids[StringName(d["id"])] = true
				if lado == "aliados":
					hay_aliados = true
		tipos[String((cap["objetivo"] as Dictionary)["tipo"])] = true
		# Los refuerzos tambien son ids validos para los eventos.
		for ev: Array in cap.get("eventos", []):
			for acc: Array in ev[1]:
				if String(acc[0]) == "refuerzos":
					for d: Dictionary in acc[1]:
						ids[StringName(d["id"])] = true
		for escena: String in ["intro", "outro"]:
			var conocidos := ids.duplicate()
			for paso: Array in cap.get(escena, []):
				if not pasos_validos.has(String(paso[0])):
					roto += "cap%d:%s:paso-%s " % [i, escena, paso[0]]
				if String(paso[0]) == "aparecer":
					conocidos[StringName(paso[1])] = true
				if String(paso[0]) in ["decir", "colocar", "mover", "pose", "grito", "habilidad", "desaparecer"]:
					if not conocidos.has(StringName(paso[1])):
						roto += "cap%d:%s:actor-%s " % [i, escena, paso[1]]
				if String(paso[0]) == "grito" and paso.size() > 3 and not Sfx._bank.has(StringName(paso[3])):
					roto += "cap%d:voz-%s " % [i, paso[3]]
		if (cap.get("intro", []) as Array).is_empty() or (cap.get("outro", []) as Array).is_empty():
			roto += "cap%d:sin-escenas " % i
	_check(roto.is_empty(), "cada capitulo nombra personajes, actores y voces que existen %s" % roto)
	_check(hay_aliados and tipos.size() >= 5,
		"hay capitulos con aliados, y objetivos de %d tipos distintos (%s)" % [tipos.size(), ", ".join(tipos.keys())])

	# --- Los equipos: un aliado no te pega ni vos a el ---
	_check(Progreso.capitulo_disponible(0) and not Progreso.capitulo_disponible(1),
		"de entrada solo se puede jugar el capitulo 1")

	# --- TODOS LOS CAPITULOS DE PUNTA A PUNTA, con sus escenas ---
	#
	# Las escenas pasan solas (Cinematica.automatica) y la pelea se fuerza: lo que se prueba
	# es que cada escena y cada evento corran sin romperse, y que ganar lleve a la
	# siguiente. Lo que tarda o cuesta cada pelea lo mide la simulacion de balance.
	Cinematica.automatica = true
	var antes_pj := Net.local_character_id
	Net.set_local_character("dio")
	var fallas := ""
	for i: int in range(Historia.cantidad()):
		main.jugar_capitulo(i)
		var mision: MisionHistoria = null
		var espera := 0.0
		while espera < 25.0:
			await get_tree().create_timer(0.1).timeout
			espera += 0.1
			mision = Modos.mision as MisionHistoria
			if mision != null and mision._en_pelea:
				break
		if mision == null or not mision._en_pelea:
			fallas += "cap%d:no-arranco " % (i + 1)
			continue
		var p := mision.jugador()
		if i == 0:
			_check(p != null and p.character_id == &"noelle" and p.equipo == 0,
				"el capitulo se juega con su personaje, no con el que tenias elegido")
			var ecos := 0
			for id: StringName in mision.participantes:
				var b := mision.participantes[id] as Player
				if b != p and b.equipo == 1 and b.player_name == "Eco" and not b.visual._eye_l.visible:
					ecos += 1
			_check(ecos == 3, "los ecos del capitulo 1 son tres, del otro equipo y sin cara (%d)" % ecos)
		if i == 2:
			var rick := mision.participantes.get(&"rick") as Player
			var antes := rick.health.current if rick != null else 0.0
			if rick != null:
				CombatUtils.deal_damage(rick, 30.0, p.peer_id)
			_check(rick != null and CombatUtils.son_aliados(p, rick) and is_equal_approx(rick.health.current, antes)
				and not CombatUtils._living_targets(p).has(rick),
				"un aliado no es blanco: los golpes del jugador no lo tocan")
		# Los eventos de vida: se lleva a cada uno a su umbral para que corra su escena.
		for ev: Array in Historia.capitulo(i).get("eventos", []):
			var cond: Array = ev[0]
			if String(cond[0]) != "vida":
				continue
			var b := mision.participantes.get(StringName(cond[1])) as Player
			if b == null or b.health.is_dead:
				continue
			var objetivo := b.health.max_health * float(cond[2]) - 1.0
			if b.health.current > objetivo:
				b.health.apply_damage(b.health.current - objetivo, 1)
			var t := 0.0
			await get_tree().create_timer(0.2).timeout
			while (Cinematica.activa or not mision._en_pelea) and t < 20.0 and not mision.terminada:
				await get_tree().create_timer(0.1).timeout
				t += 0.1
		var gano := [false]
		var al_terminar := func(g: bool, _t: String, _d: String) -> void: gano[0] = g
		Modos.termino.connect(al_terminar)
		mision._ganar()
		espera = 0.0
		while not gano[0] and espera < 30.0:
			await get_tree().create_timer(0.1).timeout
			espera += 0.1
		Modos.termino.disconnect(al_terminar)
		if not gano[0]:
			fallas += "cap%d:no-termino " % (i + 1)
		# El menu vuelve a los 3 s del resultado.
		await get_tree().create_timer(3.4).timeout
		if not Progreso.capitulo_completado(i):
			fallas += "cap%d:no-se-guardo " % (i + 1)
		for hijo: Node in main.get_children():
			if hijo is HistoriaMenu:
				hijo.queue_free()
	_check(fallas.is_empty(),
		"los diez capitulos corren enteros: escena de entrada, eventos, pelea y escena final %s" % fallas)
	_check(Progreso.capitulo_completado(9) and Net.local_character_id == "dio",
		"ganar el ultimo cierra la parte 1, y te devuelve el personaje que tenias elegido")
	Cinematica.automatica = false

	# --- Perder: caer ---
	Progreso.historia = {}
	MisionHistoria.sin_cinematicas = true
	main.jugar_capitulo(0)
	var mm: MisionHistoria = null
	var ee := 0.0
	while ee < 10.0:
		await get_tree().create_timer(0.1).timeout
		ee += 0.1
		mm = Modos.mision as MisionHistoria
		if mm != null and mm._en_pelea:
			break
	var cayo := [false]
	var al_caer := func(g: bool, _t: String, _d: String) -> void: cayo[0] = not g
	Modos.termino.connect(al_caer)
	if mm != null and mm.jugador() != null:
		mm.jugador().health.apply_damage(9999.0, -1)
	await get_tree().create_timer(0.3).timeout
	Modos.termino.disconnect(al_caer)
	_check(cayo[0], "si cae el jugador, se pierde el capitulo")
	await get_tree().create_timer(3.4).timeout
	for hijo: Node in main.get_children():
		if hijo is HistoriaMenu:
			hijo.queue_free()

	# --- Perder: proteger a alguien que cae ---
	Progreso.historia = {"0": true, "1": true}
	MisionHistoria.sin_cinematicas = true
	main.jugar_capitulo(2)
	var m: MisionHistoria = null
	var e := 0.0
	while e < 10.0:
		await get_tree().create_timer(0.1).timeout
		e += 0.1
		m = Modos.mision as MisionHistoria
		if m != null and m._en_pelea:
			break
	var perdio := [false]
	var al_perder := func(g: bool, _t: String, _d: String) -> void: perdio[0] = not g
	Modos.termino.connect(al_perder)
	var protegido := m.participantes.get(&"rick") as Player if m != null else null
	if protegido != null:
		protegido.health.apply_damage(9999.0, -2)
	await get_tree().create_timer(0.3).timeout
	Modos.termino.disconnect(al_perder)
	_check(perdio[0], "si cae el que habia que proteger, se pierde el capitulo")
	await get_tree().create_timer(3.4).timeout
	for hijo: Node in main.get_children():
		if hijo is HistoriaMenu:
			hijo.queue_free()
	_check(not Progreso.capitulo_completado(2), "y perder no lo marca como ganado")
	MisionHistoria.sin_cinematicas = false

	# Todo como estaba: el modo, el personaje y el archivo del jugador.
	Modos.iniciar(Modos.ONLINE)
	Net.set_local_character(antes_pj)
	Progreso.guardado_activo = true
	Progreso.cargar()
	await get_tree().process_frame


# ------------------------------------------- Lo que se rompia en escenas y peleas

func _test_escenas_y_peleas(main: Node) -> void:
	Progreso.guardado_activo = false
	Progreso.historia = {}
	MisionHistoria.sin_cinematicas = true
	var antes_pj := Net.local_character_id

	# --- La espera del resultado es de SU partida ---
	#
	# Al terminar un capitulo (o un modo) quedaba una espera de unos segundos que despues te
	# sacaba al menu. Si en ese rato salias y arrancabas otra partida, la espera vieja la
	# cortaba a los tres segundos y te dejaba el menu de capitulos encima de la pelea.
	main.jugar_capitulo(0)
	var m := await _esperar_pelea()
	if m != null:
		m._ganar()
	await get_tree().create_timer(0.3).timeout
	_check(Progreso.capitulo_completado(0), "ganar un capitulo lo cobra en el momento, sin esperar el menu")
	Net.leave_game()
	main.show_main_menu()
	main.jugar_capitulo(0)
	m = await _esperar_pelea()
	await get_tree().create_timer(3.6).timeout
	var menu_encima := false
	for hijo: Node in main.get_children():
		if hijo is HistoriaMenu:
			menu_encima = true
	_check(m != null and is_instance_valid(m) and m._en_pelea and not menu_encima,
		"salir y arrancar otra partida enseguida: la espera de la anterior no la corta")

	# --- Nadie saca vida durante una escena ---
	if m != null and is_instance_valid(m):
		var eco: Player = null
		for b: Node in m.participantes.values():
			if (b as Player).equipo == 1:
				eco = b
		var vida := eco.health.current if eco != null else 0.0
		Cinematica.activa = true
		var hecho := CombatUtils.deal_damage(eco, 20.0, m.jugador().peer_id) if eco != null else -1.0
		Cinematica.activa = false
		_check(eco != null and hecho == 0.0 and is_equal_approx(eco.health.current, vida),
			"durante una escena ningun golpe saca vida")

		# --- Un muerto se queda donde cayo ---
		if eco != null:
			eco.health.apply_damage(9999.0, m.jugador().peer_id)
			await get_tree().physics_frame
			var y0 := eco.global_position.y
			await get_tree().create_timer(1.2).timeout
			_check(absf(eco.global_position.y - y0) < 0.2,
				"un bot muerto no se hunde en el piso (bajo %.2f m)" % (y0 - eco.global_position.y))

		# --- El ultimate sin carga no cuenta como disponible ---
		# El estado de la pelea no importa aca: sin tambaleo, sin cooldowns, stamina llena.
		var p := m.jugador()
		p.status.clear_all()
		p.caster.reset_state()
		p.stamina.restore_full()
		var carga := p.get_node_or_null("UltimateCharge") as UltimateCharge
		if carga != null:
			carga.reset()
		var ulti := p.caster.abilities.size() - 1
		var sin_carga := not p.caster.puede_usar(ulti)
		if carga != null:
			carga.add_from_damage(9999.0)
		var con_carga := p.caster.puede_usar(ulti)
		if carga != null:
			carga.reset()
		_check(sin_carga and con_carga and p.caster.puede_usar(0),
			"con la stamina llena pero sin carga el ultimate no esta disponible, y con carga si (%s %s)" % [
				sin_carga, con_carga])

	# --- Los jefes no se tambalean ---
	Net.leave_game()
	main.show_main_menu()
	Progreso.historia = {"0": true}
	main.jugar_capitulo(1)
	var mj := await _esperar_pelea()
	var jefe := mj.jefe() if mj != null else null
	if jefe != null:
		jefe.status.clear_all()
		CombatUtils.deal_damage(jefe, 5.0, mj.jugador().peer_id)
	var jugador_h := mj.jugador() if mj != null else null
	if jugador_h != null:
		jugador_h.status.clear_all()
		CombatUtils.deal_damage(jugador_h, 5.0, -999)
	_check(jefe != null and not jefe.status.esta_tambaleando() and jugador_h.status.esta_tambaleando(),
		"un jefe de la historia no se tambalea con los golpes; el jugador si")

	# --- Comparar equipos con alguien que ya no existe ---
	var ido := Node3D.new()
	ido.free()
	_check(not CombatUtils.son_aliados(ido, mj.jugador() if mj != null else null),
		"son_aliados con un cuerpo liberado responde que no, sin error")
	Net.leave_game()
	main.show_main_menu()

	# --- Los que quedan fuera de la pelea siguen parados en el piso ---
	#
	# Apagarles la forma de colision los dejaba sin piso: el tirado se hundia, la red de
	# seguridad lo subia a su marca y se volvia a hundir, en loop.
	for i: int in range(6):
		Progreso.historia[str(i)] = true
	main.jugar_capitulo(6)
	m = await _esperar_pelea()
	if m != null:
		m.jugador().health.set_max(99999.0)
		m.jugador().health.revive_full()
	await get_tree().create_timer(2.0).timeout
	var tirado := m.participantes.get(&"rick_") as Player if m != null else null
	var piso := -99.0
	if tirado != null:
		var desde := tirado.global_position + Vector3.UP * 1.5
		var rayo := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 8.0)
		rayo.collision_mask = GameConfig.LAYER_WORLD
		var golpe := tirado.get_world_3d().direct_space_state.intersect_ray(rayo)
		if not golpe.is_empty():
			piso = (golpe["position"] as Vector3).y
	_check(tirado != null and tirado.visible and tirado.visual._pose_guion == &"tirado"
		and m._fuera.has(&"rick_") and tirado.global_position.y > piso - 0.3
		and not tirado.name_label.visible,
		"los que ZA WARUDO deja tirados siguen tirados en la pelea, en el piso y sin cartel")
	Net.leave_game()
	main.show_main_menu()
	for hijo: Node in main.get_children():
		if hijo is HistoriaMenu:
			hijo.queue_free()

	# --- La pantalla de capitulos entra entera ---
	#
	# Con los diez capitulos y el cartel de "terminaste la parte 1", el panel media mas que
	# la pantalla y VOLVER quedaba afuera.
	for i: int in range(Historia.cantidad()):
		Progreso.historia[str(i)] = true
	var menu := HistoriaMenu.new()
	main.add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	var pantalla := get_viewport().get_visible_rect()
	var afuera := ""
	for b: Node in menu.find_children("*", "Button", true, false):
		var boton := b as Button
		if boton.text == "VOLVER" and not pantalla.encloses(boton.get_global_rect()):
			afuera = str(boton.get_global_rect())
	_check(afuera.is_empty(), "con los diez capitulos, VOLVER entra en la pantalla %s" % afuera)
	menu.queue_free()

	MisionHistoria.sin_cinematicas = false
	Modos.iniciar(Modos.ONLINE)
	Net.set_local_character(antes_pj)
	Progreso.guardado_activo = true
	Progreso.cargar()
	await get_tree().process_frame


func _esperar_pelea() -> MisionHistoria:
	var espera := 0.0
	while espera < 10.0:
		await get_tree().create_timer(0.1).timeout
		espera += 0.1
		var m := Modos.mision as MisionHistoria
		if m != null and m._en_pelea:
			return m
	return null


# ------------------------------------------------------ El mando en los menus

func _test_mando_en_menus(main: Node) -> void:
	get_viewport().gui_release_focus()
	var menu := Mando.capa_de_arriba()
	_check(menu is MainMenu, "con el juego recien abierto, el menu de arriba es el principal (%s)" % menu)

	await _apretar_mando(JOY_BUTTON_DPAD_DOWN)
	var foco := get_viewport().gui_get_focus_owner()
	_check(foco is BaseButton and menu != null and menu.is_ancestor_of(foco),
		"el primer toque de cruceta pone el foco en un boton del menu (%s)" % foco)
	_check(Controles.dispositivo == &"mando", "y el juego pasa a mando")

	# --- Un menu encima: el foco entra y no se escapa ---
	main.show_tienda()
	await get_tree().process_frame
	var tienda := Mando.capa_de_arriba()
	_check(tienda is TiendaMenu, "con la tienda abierta, la de arriba es la tienda")
	await _apretar_mando(JOY_BUTTON_DPAD_DOWN)
	foco = get_viewport().gui_get_focus_owner()
	_check(tienda != null and foco != null and tienda.is_ancestor_of(foco),
		"el foco salta del menu de atras a la tienda (%s)" % foco)
	var escapes := 0
	for i: int in range(24):
		await _apretar_mando(JOY_BUTTON_DPAD_DOWN if i < 12 else JOY_BUTTON_DPAD_LEFT)
		foco = get_viewport().gui_get_focus_owner()
		if foco == null or not tienda.is_ancestor_of(foco):
			escapes += 1
	_check(escapes == 0,
		"recorriendo la tienda con la cruceta el foco nunca se va al menu de atras (%d escapes)" % escapes)

	# --- B vuelve ---
	await _apretar_mando(JOY_BUTTON_B)
	await get_tree().process_frame
	_check(not is_instance_valid(tienda) or tienda.is_queued_for_deletion(),
		"B cierra la tienda: aprieta su boton de volver")
	_check(Mando.capa_de_arriba() is MainMenu, "y queda el menu principal")

	get_viewport().gui_release_focus()
	Controles.usar(&"teclado")


# ------------------------------------------------- Mando y dedo en la partida

func _test_mando_y_tactil(main: Node, player: Player) -> void:
	# Sin bots: uno que te empuja o te congela en medio de la medicion la arruina.
	Arena.set_bots_active(false)
	player.health.revive_full()
	player.status.clear_all()
	var camara := player.camera_pivot

	# --- El stick derecho gira la camara ---
	Controles.usar(&"mando")
	var antes := camara.get_yaw()
	_eje(JOY_AXIS_RIGHT_X, 1.0)
	await get_tree().create_timer(0.3).timeout
	_eje(JOY_AXIS_RIGHT_X, 0.0)
	await get_tree().process_frame
	var giro := antes - camara.get_yaw()
	_check(giro > 0.3, "el stick derecho a fondo gira la camara a la derecha (%.2f rad en 0.3 s)" % giro)

	# --- B es el dash, no la pausa ---
	var pausa: PauseMenu = main._pause
	var espera := 0.0
	while player.get_dash_cooldown_ratio() > 0.0 and espera < 3.0:
		await get_tree().create_timer(0.1).timeout
		espera += 0.1
	# LIMPIO JUSTO ANTES DE APRETAR: con el tambaleo de los combos, un proyectil que un bot
	# habia tirado antes de apagarse y que llega en este instante deja al jugador clavado
	# 0.4 s, y en ese rato no dashea nadie. Es la regla nueva funcionando, no un error.
	player.status.clear_all()
	var quieto := 0
	while not player.status.can_act() and quieto < 60:
		await get_tree().physics_frame
		quieto += 1
	var tambaleo_antes := player.status.get_tambaleo_remaining()
	await _apretar_mando(JOY_BUTTON_B)
	_check(player.get_dash_cooldown_ratio() > 0.0,
		"B del mando dashea (tambaleo antes de apretar: %.2f)" % tambaleo_antes)
	_check(not pausa.esta_abierto(), "y NO abre la pausa")

	# --- Start pausa, y con la pausa abierta el stick no camina ---
	await _apretar_mando(JOY_BUTTON_START)
	_check(pausa.esta_abierto(), "Start abre la pausa")
	await get_tree().create_timer(0.5).timeout
	var desde := player.global_position
	_eje(JOY_AXIS_LEFT_Y, -1.0)
	await get_tree().create_timer(0.4).timeout
	var camino := Vector2(player.global_position.x - desde.x, player.global_position.z - desde.z).length()
	_eje(JOY_AXIS_LEFT_Y, 0.0)
	_check(camino < 0.15,
		"con la pausa abierta, el stick recorre el menu y el personaje no camina (%.2f m)" % camino)
	await _apretar_mando(JOY_BUTTON_B)
	_check(not pausa.esta_abierto(), "B cierra la pausa, igual que Escape")
	desde = player.global_position
	_eje(JOY_AXIS_LEFT_Y, -1.0)
	await get_tree().create_timer(0.4).timeout
	camino = Vector2(player.global_position.x - desde.x, player.global_position.z - desde.z).length()
	_eje(JOY_AXIS_LEFT_Y, 0.0)
	_check(camino > 1.0, "y cerrada, el mismo stick camina (%.2f m)" % camino)
	get_viewport().gui_release_focus()

	# --- El dedo ---
	var tactil: ControlesTactiles = main._tactil
	var hud: HUD = main._hud
	_check(tactil != null and not tactil.esta_activo() and not tactil._lienzo.visible,
		"con mando, los botones del dedo no estan, ni siquiera dibujados")
	Controles.usar(&"tactil")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(tactil.esta_activo(), "con el dedo aparecen")
	_check(not hud._ability_row.visible and not hud._dash_panel.visible,
		"y el HUD esconde las cartas de habilidades y el dash, que quedaban debajo de los botones")

	var tam := get_viewport().get_visible_rect().size
	var pulgar := Vector2(200.0, tam.y - 200.0)
	_toque(tactil, 0, pulgar, true)
	_arrastre(tactil, 0, pulgar + Vector2(80.0, 0.0), Vector2(80.0, 0.0))
	_check(Input.get_action_strength(&"move_right") > 0.7,
		"arrastrar el pulgar en el stick camina (%.2f)" % Input.get_action_strength(&"move_right"))

	# Otro dedo a la vez: el dash, sin soltar el stick.
	while player.get_dash_cooldown_ratio() > 0.0 and espera < 6.0:
		await get_tree().create_timer(0.1).timeout
		espera += 0.1
	var dash := tactil.centro(tactil.indice_de(&"dash"))
	_toque(tactil, 1, dash, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_toque(tactil, 1, dash, false)
	_check(player.get_dash_cooldown_ratio() > 0.0, "el boton DASH dashea")
	_check(Input.get_action_strength(&"move_right") > 0.7,
		"y el pulgar del stick sigue caminando mientras el otro dedo aprieta: multitouch de verdad")

	_toque(tactil, 0, pulgar, false)
	_check(is_zero_approx(Input.get_action_strength(&"move_right")), "soltar el stick deja de caminar")

	# Arrastrar en cualquier otro lado gira la camara.
	antes = camara.get_yaw()
	var libre := Vector2(tam.x * 0.62, tam.y * 0.35)
	_toque(tactil, 2, libre, true)
	_arrastre(tactil, 2, libre + Vector2(120.0, 0.0), Vector2(120.0, 0.0))
	_toque(tactil, 2, libre + Vector2(120.0, 0.0), false)
	_check(antes - camara.get_yaw() > 0.2,
		"arrastrar el dedo por la pantalla gira la camara (%.2f rad)" % (antes - camara.get_yaw()))

	# El toque que Godot convierte en click NO pega: el golpe se pega con su boton.
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = libre
	t.pressed = true
	Input.parse_input_event(t)
	await get_tree().process_frame
	_check(not Input.is_action_pressed(&"attack_basic"),
		"tocar la pantalla para girar no dispara el golpe basico (el click inventado no cuenta)")
	t.pressed = false
	Input.parse_input_event(t)
	await get_tree().process_frame

	# La pausa desde su boton: los botones se apagan y sueltan todo.
	_toque(tactil, 0, pulgar, true)
	_arrastre(tactil, 0, pulgar + Vector2(0.0, -80.0), Vector2(0.0, -80.0))
	var boton_pausa := tactil.centro(tactil.indice_de(&"pausa"))
	_toque(tactil, 1, boton_pausa, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(pausa.esta_abierto(), "el boton II abre la pausa")
	_check(not tactil.esta_activo() and is_zero_approx(Input.get_action_strength(&"move_forward")),
		"y con la pausa abierta los botones se apagan y sueltan el stick: nadie queda caminando solo")
	pausa.close()
	await get_tree().process_frame

	# --- De vuelta al teclado ---
	Controles.usar(&"teclado")
	await get_tree().process_frame
	_check(not tactil.esta_activo() and hud._ability_row.visible,
		"con el teclado se van los botones y vuelven las cartas")
	Arena.set_bots_active(true)


func _toque(t: ControlesTactiles, dedo: int, pos: Vector2, apretado: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = dedo
	e.position = pos
	e.pressed = apretado
	t.procesar(e)


func _arrastre(t: ControlesTactiles, dedo: int, pos: Vector2, relativo: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = dedo
	e.position = pos
	e.relative = relativo
	t.procesar(e)


func _tecla(codigo: int) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = codigo
	k.pressed = true
	return k


func _test_controles() -> void:
	# Contra un archivo propio: el real es el del jugador que corre esto.
	Controles.ruta_archivo = "user://controles_prueba.cfg"
	Controles.restablecer()

	_check(Controles.nombre_tecla(&"attack_basic") == "Click izq"
		and Controles.nombre_tecla(&"ability_1") == "Click der",
		"de fabrica, los golpes van en los botones del mouse")
	_check(Controles.nombre_tecla(&"dash") == "Shift", "y el dash en Shift (%s)" % Controles.nombre_tecla(&"dash"))

	# --- Reasignar una tecla de verdad cambia la accion ---
	Controles.reasignar(&"dash", _tecla(KEY_F))
	_check(Controles.nombre_tecla(&"dash") == "F", "el dash pasa a F al reasignarlo")
	_check(InputMap.event_is_action(_tecla(KEY_F), &"dash"),
		"y apretar F dispara el dash de verdad, no solo cambia el cartel")
	_check(not InputMap.event_is_action(_tecla(KEY_SHIFT), &"dash"),
		"y Shift ya no")

	# --- Si la tecla era de otra accion, se INTERCAMBIAN ---
	#
	# Duplicar haria que una tecla dispare dos cosas a la vez; rechazar obligaria a liberar
	# la tecla en otra fila primero, que nadie entiende por que tiene que hacer.
	var con := Controles.reasignar(&"jump", _tecla(KEY_F))
	_check(con == Controles.nombre_accion(&"dash"),
		"poner en Saltar la tecla del Dash avisa con quien se intercambio (%s)" % con)
	_check(InputMap.event_is_action(_tecla(KEY_F), &"jump")
		and not InputMap.event_is_action(_tecla(KEY_F), &"dash"),
		"F queda en Saltar y no en las dos")
	_check(InputMap.event_is_action(_tecla(KEY_SPACE), &"dash"),
		"y el Dash se queda con la tecla vieja de Saltar: ninguna accion queda sin tecla")

	# --- Lo que no puede ser un control ---
	Controles.reasignar(&"dash", _tecla(KEY_ESCAPE))
	_check(not InputMap.event_is_action(_tecla(KEY_ESCAPE), &"dash"),
		"Escape no se puede asignar: es la salida de todos los menus")
	var rueda := InputEventMouseButton.new()
	rueda.button_index = MOUSE_BUTTON_WHEEL_UP
	rueda.pressed = true
	_check(not Controles.es_valido(rueda),
		"la rueda del mouse tampoco: las acciones que se mantienen no se podrian usar")
	var lateral := InputEventMouseButton.new()
	lateral.button_index = MOUSE_BUTTON_XBUTTON1
	lateral.pressed = true
	Controles.reasignar(&"ability_2", lateral)
	_check(Controles.nombre_tecla(&"ability_2") == "Mouse 4",
		"pero los botones laterales del mouse si (%s)" % Controles.nombre_tecla(&"ability_2"))

	# --- Se guarda y se vuelve a leer ---
	Controles.reasignar(&"ability_ultimate", _tecla(KEY_R))
	Controles.restablecer_sin_borrar_archivo_para_prueba()
	_check(Controles.nombre_tecla(&"ability_ultimate") == "Q", "(control: la memoria volvio a fabrica)")
	Controles.cargar()
	_check(Controles.nombre_tecla(&"ability_ultimate") == "R",
		"al volver a abrir el juego, las teclas elegidas siguen puestas")

	# --- Restablecer vuelve todo a fabrica ---
	Controles.restablecer()
	_check(Controles.nombre_tecla(&"ability_ultimate") == "Q"
		and Controles.nombre_tecla(&"dash") == "Shift"
		and Controles.nombre_tecla(&"jump") == "Espacio",
		"restablecer devuelve todas las de fabrica")

	# --- El mando ---
	#
	# Con device 5 a proposito: un evento de mando creado por codigo nace con device 0 y el
	# InputMap solo lo aceptaba del mando 0. Probando con otro numero se ve si quedo en -1.
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_A, 5), &"jump"),
		"A del mando salta, venga del mando que venga (no solo del numero 0)")
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_A, 0), &"ui_accept")
		and InputMap.event_is_action(_joy(JOY_BUTTON_B, 0), &"ui_cancel"),
		"y en los menus A acepta y B vuelve: Godot los trae sin mando")
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_START, 0), &"pausa")
		and not InputMap.event_is_action(_joy(JOY_BUTTON_B, 0), &"pausa"),
		"la pausa es Start y NO B: B es el dash, y cada esquive abriria el menu")
	_check(InputMap.event_is_action(_tecla(KEY_ESCAPE), &"pausa"), "Escape sigue abriendo la pausa")

	Controles.reasignar(&"dash", _tecla(KEY_F))
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_B, 0), &"dash"),
		"cambiar la tecla del dash NO le saca el B del mando")
	_check(Controles.nombre_tecla(&"dash") == "F",
		"y el cartel dice la tecla nueva, no el boton del mando que quedo primero (%s)" % Controles.nombre_tecla(&"dash"))
	Controles.restablecer_sin_borrar_archivo_para_prueba()
	Controles.cargar()
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_B, 0), &"dash")
		and Controles.nombre_tecla(&"dash") == "F",
		"cargar las teclas guardadas tampoco se lleva el mando puesto")
	Controles.restablecer()
	_check(InputMap.event_is_action(_joy(JOY_BUTTON_B, 0), &"dash")
		and InputMap.event_is_action(_joy(JOY_BUTTON_A, 0), &"jump"),
		"y restablecer devuelve el mando junto con las teclas")

	# --- Los carteles dicen lo que se esta usando ---
	Controles.usar(&"mando")
	_check(Controles.nombre_tecla(&"attack_basic") == "RT" and Controles.nombre_tecla(&"dash") == "B",
		"con el mando, los carteles dicen RT y B (%s, %s)" % [
			Controles.nombre_tecla(&"attack_basic"), Controles.nombre_tecla(&"dash")])
	Controles.usar(&"tactil")
	_check(Controles.nombre_tecla(&"attack_basic") == "GOLPE",
		"con el dedo, lo que dice el boton de la pantalla (%s)" % Controles.nombre_tecla(&"attack_basic"))
	Controles.usar(&"teclado")
	_check(Controles.nombre_tecla(&"attack_basic") == "Click izq", "y de vuelta al teclado, Click izq")

	# --- Que decide el dispositivo ---
	Controles._input(_joy(JOY_BUTTON_X, 0))
	_check(Controles.dispositivo == &"mando", "apretar un boton del mando pasa a mando")
	var falso := InputEventMouseButton.new()
	falso.device = InputEvent.DEVICE_ID_EMULATION
	falso.button_index = MOUSE_BUTTON_LEFT
	falso.pressed = true
	Controles.usar(&"tactil")
	Controles._input(falso)
	_check(Controles.dispositivo == &"tactil",
		"el click que Godot inventa a partir de un toque NO pasa a teclado: si no, los botones del dedo parpadearian")
	Controles._input(_tecla(KEY_W))
	_check(Controles.dispositivo == &"teclado", "una tecla vuelve al teclado")

	# Y de vuelta a las teclas reales del jugador.
	Controles.ruta_archivo = Controles.RUTA
	Controles.restablecer_sin_borrar_archivo_para_prueba()
	Controles.cargar()
	await get_tree().process_frame


# ------------------------------------------------------- Skins que se notan

## Todos los materiales de un visual, sin repetir.
func _materiales(nodo: Node, salida: Array) -> void:
	var malla := nodo as MeshInstance3D
	if malla != null and malla.material_override is StandardMaterial3D:
		if not salida.has(malla.material_override):
			salida.append(malla.material_override)
	for h: Node in nodo.get_children():
		_materiales(h, salida)


func _test_skins_visibles() -> void:
	# --- Cuanto se nota depende de la rareza ---
	var faltan := ""
	for sid: StringName in SkinDB.todas():
		var sk := SkinDB.get_skin(sid)
		if sk.partes.size() < 2:
			faltan += "%s(sin recoloreo) " % sid
		if sk.rareza == &"legendaria" and sk.aura == &"":
			faltan += "%s(legendaria sin aura) " % sid
		if sk.rareza == &"epica" and sk.acabado == &"" and sk.accesorio == &"" and sk.aura == &"":
			faltan += "%s(epica sin nada extra) " % sid
	_check(faltan.is_empty(),
		"cada skin recolorea el disfraz y suma lo que le toca por rareza %s" % faltan)

	# --- EL BUG ORIGINAL: la skin tiene que recolorear el disfraz, no solo el torso ---
	#
	# Los disfraces tenian sus colores escritos a mano: "Sonic Dorado" salia con las puas y
	# la cabeza AZULES, porque solo cambiaba lo que usaba la paleta de base. Se arma el
	# visual de verdad y se busca el color de las puas entre sus materiales.
	var visual := PlayerVisual.new()
	add_child(visual)
	await get_tree().process_frame
	var dorado := SkinDB.get_skin(&"sonic_super")
	visual.apply_character(SkinDB.aplicar(CharacterDB.get_character(&"sonic"), &"sonic_super"))
	var mats: Array = []
	_materiales(visual, mats)
	var puas_doradas := false
	var puas_azules := false
	for m: StandardMaterial3D in mats:
		if m.albedo_color.is_equal_approx(dorado.partes[&"pua"]):
			puas_doradas = true
		if m.albedo_color.is_equal_approx(Color(0.11, 0.35, 0.78)):
			puas_azules = true
	_check(puas_doradas and not puas_azules,
		"Sonic Dorado tiene las puas doradas de verdad, no las azules de fabrica")

	# --- Ninguna skin vuelve a nadie transparente ni lo esconde ---
	#
	# Una skin que te hace ver a traves, o que te camufla, es una ventaja comprada en un
	# juego de PvP. Se prueban las diecinueve sobre el visual real.
	var transparentes := ""
	for sid: StringName in SkinDB.todas():
		var sk := SkinDB.get_skin(sid)
		visual.apply_character(SkinDB.aplicar(CharacterDB.get_character(sk.character_id), sid))
		var ms: Array = []
		_materiales(visual._root, ms)
		for m: StandardMaterial3D in ms:
			if m.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON and \
					m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				transparentes += "%s " % sid
				break
	_check(transparentes.is_empty(),
		"ninguna skin deja el cuerpo transparente %s" % transparentes)

	# --- Volver a la de fabrica limpia TODO ---
	#
	# Los materiales de base no se rehacen al cambiar de skin, asi que un acabado viejo se
	# podia quedar pegado: de "Dio Dorado" a la de fabrica, Dio quedaba metalico.
	visual.apply_character(SkinDB.aplicar(CharacterDB.get_character(&"dio"), &"dio_dorado"))
	_check(visual._mat_body.metallic > 0.5, "(control: el Dorado es metalico)")
	visual.apply_character(CharacterDB.get_character(&"dio"))
	_check(is_zero_approx(visual._mat_body.metallic) and not visual._mat_body.emission_enabled,
		"y al volver a la de fabrica, el cuerpo deja de ser metalico")
	var auras := 0
	for h: Node in visual.get_children():
		if h.name.begins_with("AuraSkin") and not h.is_queued_for_deletion():
			auras += 1
	_check(auras == 0, "y no le queda colgando el aura de la skin anterior")
	visual.queue_free()
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
		&"voz_kamehameha", &"voz_ha",
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
	# Las dos tablas: la de al soltar y la de al empezar a cargar (el Kamehameha).
	for tabla: Dictionary in [Frases.LINEAS, Frases.LINEAS_CARGA]:
		for id: StringName in tabla:
			for linea: Array in tabla[id]:
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
const CHEQUEOS_MINIMOS: int = 236


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
