extends Node
## Herramienta: ¿cuánto gana un jugador en cada modo?
##
## Simula peleas enteras: un HÉROE con las estadísticas del jugador —vida del personaje,
## daño sin la rebaja de bot— contra los enemigos del modo con SUS números. El héroe es
## un BotBrain, así que pelea peor que una persona que sabe jugar: esquiva mal y apunta
## regular. Por eso lo que importa no es que gane siempre, sino que la tasa de victoria
## tenga sentido para cada modo, y que un humano —que pelea mejor— gane más.
##
##     godot --headless --fixed-fps 60 --path . res://tests/balance_modos.tscn
##
## --fixed-fps hace que cada frame avance exactamente 1/60 de segundo de juego, sin
## importar cuánto tarde de verdad: la simulación corre tan rápido como da la máquina.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
## Cuantas peleas por modo. 15 por defecto; PRUEBAS_SIM=30 para calibrar: con 15, un modo
## sin cambios paso de 7 a 2 victorias entre dos corridas.
var PRUEBAS: int = int(OS.get_environment("PRUEBAS_SIM")) if OS.get_environment("PRUEBAS_SIM") != "" else 15
const TOPE_PELEA: float = 70.0
var _arena: Arena = null
var _siguiente_id: int = 7000
## Los enemigos van con id NEGATIVO, y no es un detalle: CombatUtils le aplica la rebaja de
## daño del modo solo a los peer negativos. La primera corrida les daba ids positivos, los
## enemigos pegaban al cien por ciento y el duelo salia 1 de 6 midiendo otra cosa.
var _siguiente_malo: int = -1000


func _ready() -> void:
	var m := MAIN_SCENE.instantiate(); m.name = "Main"
	get_tree().root.call_deferred("add_child", m)
	_correr.call_deferred()


func _correr() -> void:
	await get_tree().process_frame
	Progreso.guardado_activo = false
	# Un puerto por proceso: dos simulaciones a la vez no pueden escuchar en el mismo.
	var puerto := int(OS.get_environment("PUERTO_SIM")) if OS.get_environment("PUERTO_SIM") != "" \
		else GameConfig.DEFAULT_PORT + 52
	Net.host_game(puerto, "T")
	await get_tree().process_frame
	Net.start_match()
	for _i in range(20): await get_tree().physics_frame
	_arena = get_tree().root.get_node_or_null(^"Main/Arena") as Arena
	var local := _arena.get_local_player()
	# El jugador de verdad afuera del mapa: si queda cerca, los enemigos lo eligen a el.
	local.health.set_max(99999.0); local.health.revive_full()
	local._apply_respawn(Vector3(0, -200, 0), 0.0)
	local.set_physics_process(false)

	var args := OS.get_cmdline_user_args()
	var modos: Array = [Modos.DUELO, Modos.ULTIMO_EN_PIE, Modos.JEFES, Modos.SUPERVIVENCIA,
		Modos.CONTRARRELOJ, Modos.COLINA]
	if args.size() > 0:
		modos = [StringName(args[0])]
	print("")
	for m in modos:
		if m == Modos.HISTORIA:
			await _medir_historia()
		elif m == &"personajes":
			await _medir_personajes()
		else:
			await _medir(m)
	get_tree().quit()


## LOS PERSONAJES ENTRE SI: duelos uno contra uno, todos contra todos, y cada par la mitad
## de las veces de cada lado del mapa. Los dos son el mismo BotBrain y pegan al cien por
## ciento (ids positivos): lo unico que cambia es el kit. Un bot no juega como una persona,
## asi que lo que importa son las diferencias grandes, no un 52 contra 48.
##
##   -- personajes [duelos por par] [pares, ej. noelle-dio,rick-sonic]
func _medir_personajes() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[1]) if args.size() > 1 else 16
	var ids := CharacterDB.get_all_ids()
	var pares: Array = []
	if args.size() > 2:
		for par in String(args[2]).split(","):
			var dos := par.split("-")
			pares.append([StringName(dos[0]), StringName(dos[1])])
	else:
		for i in range(ids.size()):
			for j in range(i + 1, ids.size()):
				pares.append([ids[i], ids[j]])
	Modos.iniciar(Modos.DUELO)
	var ancla := MisionHistoria.lugar_despejado(_arena, Vector3.ZERO)
	for par in pares:
		var ganadas := 0.0
		var detalle := ""
		var tiempos := 0.0
		for k in range(n):
			var r: Array = await _duelo(par[0], par[1], ancla, k % 2 == 0)
			tiempos += r[1]
			if r[0] == 0:
				ganadas += 1.0
				detalle += "A"
			elif r[0] == 1:
				detalle += "B"
			else:
				ganadas += 0.5
				detalle += "="
		print("personajes %-8s vs %-8s  %4.1f/%d  (%2.0f%%)  %4.1fs  %s" % [String(par[0]), String(par[1]),
			ganadas, n, 100.0 * ganadas / n, tiempos / n, detalle])


## Un duelo entre dos kits. Devuelve [0 si gano a, 1 si gano b, -1 empate; segundos].
func _duelo(a: StringName, b: StringName, ancla: Vector3, lado: bool) -> Array:
	for id in _arena._players.keys().duplicate():
		if id == Net.local_id():
			continue
		var viejo = _arena._players[id]
		if is_instance_valid(viejo): viejo.queue_free()
		_arena._players.erase(id)
	for hijo in _arena.get_children():
		if hijo is Projectile:
			hijo.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var cuerpos: Array[Player] = []
	for i in range(2):
		var pj: StringName = a if i == 0 else b
		var x := -7.0 if (i == 0) == lado else 7.0
		var punto := _arena.find_clear_spot(ancla + Vector3(x, 0.0, 0.0), 1.0)
		var id := _siguiente_id; _siguiente_id += 1
		_arena._crear_bot(id, punto, pj)
		var p: Player = _arena._players[id]
		p.equipo = i
		p.health.set_max(CharacterDB.get_character(pj).max_health * GameConfig.VIDA)
		p.health.revive_full()
		p.stamina.restore_full()
		for conexion in p.died.get_connections():
			p.died.disconnect(conexion["callable"])
		var cerebro := p.get_node_or_null("BotBrain") as BotBrain
		if cerebro != null:
			cerebro.home = ancla
		cuerpos.append(p)
	Arena.set_bots_active(true)
	# DIAG=1: que usa cada uno, cuanto pega y a que distancia pelean. Para separar un kit
	# flojo de un bot que no sabe usarlo.
	var diag := OS.get_environment("DIAG") == "1"
	var usos: Array = [{}, {}]
	var recibido: Array = [0.0, 0.0]
	var cortes: Array = [0, 0]
	var absorbido: Array = [0.0, 0.0]
	var trabado: Array = [0.0, 0.0]
	if diag:
		for i in range(2):
			var yo := i
			cuerpos[i].caster.ability_used.connect(func(idx: int) -> void:
				var nombre := String(cuerpos[yo].caster.get_ability(idx).id)
				usos[yo][nombre] = int(usos[yo].get(nombre, 0)) + 1)
			cuerpos[i].caster.channel_cancelled.connect(func(_idx: int) -> void: cortes[yo] += 1)
			cuerpos[i].health.damaged.connect(func(cuanto: float, _de: int) -> void: recibido[yo] += cuanto)
			cuerpos[i].health.shield_absorbed.connect(func(cuanto: float, _q: float) -> void: absorbido[yo] += cuanto)
	var t := 0.0
	var dist_suma := 0.0
	var cuadros := 0
	var fin := -2
	while t < 90.0 and fin == -2:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		dist_suma += cuerpos[0].global_position.distance_to(cuerpos[1].global_position)
		cuadros += 1
		for i in range(2):
			if not cuerpos[i].status.can_act():
				trabado[i] += 1.0 / 60.0
		if cuerpos[0].health.is_dead:
			fin = 1
		elif cuerpos[1].health.is_dead:
			fin = 0
	if diag:
		print("  diag %s %s %4.1fs | %s pega %.0f (+%.0f al escudo), trabado %.1fs, usa %s | %s pega %.0f (+%.0f al escudo), trabado %.1fs, usa %s | dist %.1f m" % [
			"gana" if fin != -2 else "tiempo", "A" if fin == 0 else "B", t,
			a, recibido[1], absorbido[1], trabado[0], str(usos[0]),
			b, recibido[0], absorbido[0], trabado[1], str(usos[1]),
			dist_suma / maxf(1.0, float(cuadros))])
	if fin != -2:
		return [fin, t]
	# Empate por tiempo: gana el que tenga mas vida, en proporcion a su maximo.
	var va := cuerpos[0].health.current / cuerpos[0].health.max_health
	var vb := cuerpos[1].health.current / cuerpos[1].health.max_health
	if absf(va - vb) < 0.1:
		return [-1, t]
	return [0 if va > vb else 1, t]


## Los capitulos de la historia, con su MISION DE VERDAD: aliados, objetivo, eventos,
## refuerzos. Un bot hace de jugador (MisionHistoria.heroe) y las escenas se saltean.
func _medir_historia() -> void:
	MisionHistoria.sin_cinematicas = true
	# DIFICULTAD_SIM=0/1/2: la dificultad elegida. Sin ella, normal, y no la que haya
	# guardado quien corre la simulacion.
	Progreso.dificultad_historia = int(OS.get_environment("DIFICULTAD_SIM")) 		if OS.get_environment("DIFICULTAD_SIM") != "" else Historia.DIFICULTAD_NORMAL
	var args := OS.get_cmdline_user_args()
	# -- historia [heroe|-] [capitulos, ej. 4,6,7]
	var heroe: StringName = StringName(args[1]) if args.size() > 1 and args[1] != "-" else &""
	var solo: Array = []
	if args.size() > 2:
		for n in String(args[2]).split(","):
			solo.append(int(n) - 1)
	for c in range(Historia.cantidad()):
		if not solo.is_empty() and not solo.has(c):
			continue
		var cap := Historia.capitulo(c)
		var ganadas := 0
		var detalle := ""
		for _prueba in range(PRUEBAS):
			Modos.iniciar_historia(c)
			var r: Array = await _pelea_mision(c, cap, heroe)
			if r[0]:
				ganadas += 1
			detalle += "%s(%.0fs %d%%) " % ["G" if r[0] else "p", r[1], int(r[2] * 100.0)]
		print("historia %2d %-10s %2d/%d   %s" % [c + 1, String(cap["personaje"]), ganadas, PRUEBAS, detalle])
	MisionHistoria.sin_cinematicas = false


## Una pelea de capitulo. Con `heroe` se juega con ese personaje en vez del del capitulo:
## sirve para separar la dificultad del capitulo de lo bien que un bot maneja al personaje
## (el bot de Rick, por ejemplo, solo dispara de cerca).
func _pelea_mision(c: int, cap: Dictionary, heroe: StringName) -> Array:
	for id in _arena._players.keys().duplicate():
		if id == Net.local_id():
			continue
		var b = _arena._players[id]
		if is_instance_valid(b): b.queue_free()
		_arena._players.erase(id)
	for hijo in _arena.get_children():
		if hijo is MisionHistoria:
			hijo.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	var base: Vector3 = _arena.get_free_spawn_point().origin
	var personaje := heroe if heroe != &"" else StringName(cap["personaje"])
	var heroe_id := _siguiente_id; _siguiente_id += 1
	_arena._crear_bot(heroe_id, base, personaje)
	var h: Player = _arena._players[heroe_id]
	h.set_meta(&"heroe", true)
	h.health.set_max(CharacterDB.get_character(personaje).max_health * GameConfig.VIDA)
	h.health.revive_full()
	for conexion in h.died.get_connections():
		h.died.disconnect(conexion["callable"])

	var m := MisionHistoria.new()
	m.capitulo = c
	m.datos = cap
	m.arena = _arena
	m.heroe = h
	var fin := [null]
	var al_terminar := func(g: bool, _t: String, _d: String) -> void: fin[0] = g
	Modos.termino.connect(al_terminar)
	_arena.add_child(m)
	var t := 0.0
	var cerebro := h.get_node_or_null("BotBrain") as BotBrain
	# DIAG=1: que hace el jefe del capitulo y cuanto le entra al heroe.
	var diag := OS.get_environment("DIAG") == "1"
	var usos_jefe := {}
	var recibido := [0.0]
	var dist_jefe := [0.0, 0]
	var usos_heroe := {}
	if diag:
		h.health.damaged.connect(func(cuanto: float, _de: int) -> void: recibido[0] += cuanto)
		h.caster.ability_used.connect(func(idx: int) -> void:
			var n := String(h.caster.get_ability(idx).id)
			usos_heroe[n] = int(usos_heroe.get(n, 0)) + 1)
	var jefe_conectado := [false]
	while fin[0] == null and t < 200.0:
		if diag and not jefe_conectado[0] and m.jefe() != null:
			jefe_conectado[0] = true
			var j := m.jefe()
			j.caster.ability_used.connect(func(idx: int) -> void:
				var n := String(j.caster.get_ability(idx).id)
				usos_jefe[n] = int(usos_jefe.get(n, 0)) + 1)
		if diag and m.jefe() != null:
			dist_jefe[0] += m.jefe().global_position.distance_to(h.global_position)
			dist_jefe[1] += 1
		await get_tree().physics_frame
		t += 1.0 / 60.0
		# Una ZONA se gana parado adentro, y un bot solo persigue: sin esto nunca pisa el
		# circulo y el capitulo no termina. Se lo ata al centro, peleando desde ahi.
		if is_instance_valid(m._zona) and cerebro != null:
			cerebro.home = m._zona.global_position
			h.set_meta(&"correa", float(cap["objetivo"].get("radio", 6.0)) * 0.7)
	Modos.termino.disconnect(al_terminar)
	if diag:
		print("  diag cap %d: el heroe recibe %.0f y usa %s; el jefe usa %s, distancia media %.1f m" % [c + 1,
			recibido[0], str(usos_heroe), str(usos_jefe), dist_jefe[0] / maxf(1.0, float(dist_jefe[1]))])
	m.queue_free()
	return [fin[0] == true, t, h.health.current / maxf(1.0, h.health.max_health)]


## Una pelea: el héroe contra `enemigos` bots con la vida y el daño que diga el modo.
## Devuelve [gano, segundos, vida_que_le_quedo].
func _pelea(personaje: StringName, enemigos: int, vida_heroe: float, radio: float = 11.0) -> Array:
	for id in _arena._players.keys().duplicate():
		if id == Net.local_id():
			continue
		var b = _arena._players[id]
		if is_instance_valid(b): b.queue_free()
		_arena._players.erase(id)
	await get_tree().process_frame

	var base: Vector3 = _arena.get_free_spawn_point().origin
	var heroe_id := _siguiente_id; _siguiente_id += 1
	_arena._crear_bot(heroe_id, base, personaje)
	var heroe: Player = _arena._players[heroe_id]
	heroe.set_meta(&"heroe", true)
	# Vida de JUGADOR, no la del modo.
	heroe.health.set_max(CharacterDB.get_character(personaje).max_health * GameConfig.VIDA)
	heroe.health.revive_full()
	heroe.health.current = minf(vida_heroe, heroe.health.max_health)
	# Sin respawn ni refuerzos: se mide la pelea pelada.
	for c in heroe.died.get_connections():
		heroe.died.disconnect(c["callable"])

	var ids := CharacterDB.get_all_ids()
	var malos: Array = []
	for i in range(enemigos):
		var ang := TAU * float(i) / float(maxi(1, enemigos)) + 0.4
		var id := _siguiente_malo; _siguiente_malo -= 1
		_arena._crear_bot(id, _arena.find_clear_spot(base + Vector3(cos(ang), 0, sin(ang)) * radio, 1.0),
			ids[(i + 1) % ids.size()])
		var b: Player = _arena._players[id]
		# La vida del MODO, puesta a mano: fuera de una partida solo, _crear_bot les da los
		# 170 de la practica, que es justo el numero que se esta intentando no medir.
		b.health.set_max(Modos.vida_bot())
		b.health.revive_full()
		for c in b.died.get_connections():
			b.died.disconnect(c["callable"])
		malos.append(b)
	Arena.set_bots_active(true)

	var t := 0.0
	while t < TOPE_PELEA:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if heroe.health.is_dead:
			return [false, t, 0.0]
		var vivos := 0
		for b in malos:
			if is_instance_valid(b) and not b.health.is_dead:
				vivos += 1
		if vivos == 0:
			return [true, t, heroe.health.current]
	return [false, t, heroe.health.current]


## Una partida CON REAPARICION, como en caos y en la lluvia: el que cae vuelve a los pocos
## segundos. Devuelve [gano, segundos, bajas, muertes]. Con `meta_bajas` en 0 no se gana
## matando sino llegando vivo a `tope`; `max_muertes` 1 es una muerte y se termina.
func _pelea_continua(personaje: StringName, enemigos: int, tope: float, meta_bajas: int,
		max_muertes: int, lluvia: bool) -> Array:
	for id in _arena._players.keys().duplicate():
		if id == Net.local_id():
			continue
		var b = _arena._players[id]
		if is_instance_valid(b): b.queue_free()
		_arena._players.erase(id)
	await get_tree().process_frame

	var base: Vector3 = _arena.get_free_spawn_point().origin
	var heroe_id := _siguiente_id; _siguiente_id += 1
	_arena._crear_bot(heroe_id, base, personaje)
	var heroe: Player = _arena._players[heroe_id]
	heroe.set_meta(&"heroe", true)
	heroe.health.set_max(CharacterDB.get_character(personaje).max_health * GameConfig.VIDA)
	heroe.health.revive_full()
	for c in heroe.died.get_connections():
		heroe.died.disconnect(c["callable"])
	var ids := CharacterDB.get_all_ids()
	var malos: Array = []
	var puestos := {}
	for i in range(enemigos):
		var ang := TAU * float(i) / float(maxi(1, enemigos)) + 0.4
		var id := _siguiente_malo; _siguiente_malo -= 1
		var pos := _arena.find_clear_spot(base + Vector3(cos(ang), 0, sin(ang)) * 14.0, 1.0)
		_arena._crear_bot(id, pos, ids[(i + 1) % ids.size()])
		var b: Player = _arena._players[id]
		b.health.set_max(Modos.vida_bot())
		b.health.revive_full()
		for c in b.died.get_connections():
			b.died.disconnect(c["callable"])
		malos.append(b)
		puestos[b] = pos
	Arena.set_bots_active(true)
	if lluvia:
		_arena.blanco_lluvia = heroe
		_arena._lluvia_espera = 2.5
		_arena._lluvia_cuenta = 0

	# DIAG=1: de donde vino el daño que recibio el heroe (0 = la lluvia, negativo = bots).
	var daño_por := {"lluvia": 0.0, "bots": 0.0}
	if OS.get_environment("DIAG") == "1":
		heroe.health.damaged.connect(func(cuanto: float, fuente: int) -> void:
			daño_por["lluvia" if fuente == 0 else "bots"] += cuanto)
	var bajas := 0
	var muertes := 0
	var vuelven := {}
	var t := 0.0
	var fin: Array = [meta_bajas == 0, tope, 0, 0]
	while t < tope:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if heroe.health.is_dead and not vuelven.has(heroe):
			muertes += 1
			if muertes >= max_muertes:
				fin = [false, t, bajas, muertes]
				break
			vuelven[heroe] = t + GameConfig.RESPAWN_DELAY
		for b in malos:
			if b.health.is_dead and not vuelven.has(b):
				bajas += 1
				vuelven[b] = t + Arena.DUMMY_RESPAWN_DELAY
		if meta_bajas > 0 and bajas >= meta_bajas:
			fin = [true, t, bajas, muertes]
			break
		for q in vuelven.keys():
			if t < vuelven[q]:
				continue
			vuelven.erase(q)
			q.health.revive_full()
			q.stamina.restore_full()
			q.status.clear_all()
			q.caster.reset_state()
			var donde: Vector3 = _arena.get_free_spawn_point().origin if q == heroe else puestos[q]
			q._apply_respawn(_arena.find_clear_spot(donde, 1.0), 0.0)
	fin[2] = bajas
	fin[3] = muertes
	_arena.blanco_lluvia = null
	if OS.get_environment("DIAG") == "1":
		print("  %s: %.0fs, daño de la lluvia %.0f, de los bots %.0f" % [personaje, fin[1],
			daño_por["lluvia"], daño_por["bots"]])
	return fin


func _medir(modo: StringName) -> void:
	Modos.iniciar(modo)
	var personajes := CharacterDB.get_all_ids()
	var ganadas := 0
	var detalle := ""
	for prueba in range(PRUEBAS):
		var pj: StringName = personajes[prueba % personajes.size()]
		Modos.iniciar(modo)
		var gano := false
		var nota := ""
		match modo:
			Modos.DUELO, Modos.ULTIMO_EN_PIE:
				var r: Array = await _pelea(pj, Modos.bots_iniciales(), 999.0)
				gano = r[0]
				nota = "%.0fs" % r[1]
			Modos.JEFES:
				# De a uno, curandose entre jefe y jefe, como en el modo.
				var llego := 0
				for jefe in range(Modos.JEFES_TOTAL):
					Modos.bajas = jefe
					var r: Array = await _pelea(pj, 1, 999.0)
					if not r[0]:
						break
					llego += 1
				gano = llego >= Modos.JEFES_TOTAL
				nota = "%d/%d" % [llego, Modos.JEFES_TOTAL]
			Modos.SUPERVIVENCIA:
				var oleada := 1
				while oleada <= 8:
					Modos.oleada = oleada
					var n := Modos.bots_en_oleada(oleada)
					var r: Array = await _pelea(pj, n, 999.0)
					if not r[0]:
						break
					oleada += 1
				gano = oleada > 5
				nota = "oleada %d" % oleada
			Modos.CONTRARRELOJ, Modos.COLINA:
				var r: Array = await _pelea(pj, Modos.bots_iniciales(), 999.0)
				gano = r[0]
				nota = "%.0fs" % r[1]
			Modos.CAMPAL:
				# Repartidos lejos, como en la arena: si arrancan encima del heroe es otro modo.
				var r: Array = await _pelea(pj, Modos.BOTS_CAMPAL, 999.0, 30.0)
				gano = r[0]
				nota = "%.0fs" % r[1]
			Modos.CAOS:
				var r: Array = await _pelea_continua(pj, Modos.BOTS_CAOS, 150.0, Modos.META_CAOS,
					Modos.MUERTES_CAOS, false)
				gano = r[0]
				nota = "%d-%d" % [r[2], r[3]]
			Modos.METEORITOS:
				var r: Array = await _pelea_continua(pj, Modos.BOTS_METEORITOS, Modos.META_METEORITOS, 0, 1, true)
				gano = r[0]
				nota = "%.0fs" % r[1]
		if gano:
			ganadas += 1
		detalle += "%s:%s%s " % [String(pj).substr(0, 3), "G" if gano else "p", "(" + nota + ")"]
	print("%-15s %d/%d   %s" % [modo, ganadas, PRUEBAS, detalle])
