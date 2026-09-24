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
const PRUEBAS: int = 15
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
	Net.host_game(GameConfig.DEFAULT_PORT + 52, "T")
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
		else:
			await _medir(m)
	get_tree().quit()


## Los capitulos de la historia: cada uno con SU personaje contra SUS enemigos.
##
## Los enemigos van con ids -1, -2... porque asi es como Modos encuentra la vida y el
## daño de cada uno en el capitulo. Los de los modos libres usan otra numeracion.
func _medir_historia() -> void:
	for c in range(Historia.cantidad()):
		var cap := Historia.capitulo(c)
		var ganadas := 0
		var detalle := ""
		for _prueba in range(PRUEBAS):
			Modos.iniciar_historia(c)
			var r: Array = await _pelea_historia(cap)
			if r[0]:
				ganadas += 1
			detalle += "%s(%.0fs) " % ["G" if r[0] else "p", r[1]]
		print("historia %d %-10s %d/%d   %s" % [c + 1, String(cap["personaje"]), ganadas, PRUEBAS, detalle])


func _pelea_historia(cap: Dictionary) -> Array:
	for id in _arena._players.keys().duplicate():
		if id == Net.local_id():
			continue
		var b = _arena._players[id]
		if is_instance_valid(b): b.queue_free()
		_arena._players.erase(id)
	await get_tree().process_frame
	await get_tree().process_frame

	var base: Vector3 = _arena.get_free_spawn_point().origin
	var personaje := StringName(cap["personaje"])
	# Con un segundo argumento se juegan todos los capitulos con ESE heroe. Sirve para medir
	# la dificultad del capitulo aparte de lo bien que un bot maneja al personaje: el bot de
	# Rick, por ejemplo, solo dispara de cerca, y un capitulo de Rick medido con el daria la
	# nota del bot y no la del capitulo.
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		personaje = StringName(args[1])
	var heroe_id := _siguiente_id; _siguiente_id += 1
	_arena._crear_bot(heroe_id, base, personaje)
	var heroe: Player = _arena._players[heroe_id]
	heroe.set_meta(&"heroe", true)
	heroe.health.set_max(CharacterDB.get_character(personaje).max_health)
	heroe.health.revive_full()
	for c in heroe.died.get_connections():
		heroe.died.disconnect(c["callable"])

	var enemigos: Array = cap["enemigos"]
	var malos: Array = []
	for i in range(enemigos.size()):
		var ang := TAU * float(i) / float(maxi(1, enemigos.size())) + 0.4
		var id := -(i + 1)
		_arena._crear_bot(id, _arena.find_clear_spot(base + Vector3(cos(ang), 0, sin(ang)) * 11.0, 1.0),
			StringName(enemigos[i]["personaje"]))
		var b: Player = _arena._players[id]
		b.health.set_max(Modos.vida_bot(id))
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
			return [false, t]
		var vivos := 0
		for b in malos:
			if is_instance_valid(b) and not b.health.is_dead:
				vivos += 1
		if vivos == 0:
			return [true, t]
	return [false, t]


## Una pelea: el héroe contra `enemigos` bots con la vida y el daño que diga el modo.
## Devuelve [gano, segundos, vida_que_le_quedo].
func _pelea(personaje: StringName, enemigos: int, vida_heroe: float) -> Array:
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
	heroe.health.set_max(CharacterDB.get_character(personaje).max_health)
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
		_arena._crear_bot(id, _arena.find_clear_spot(base + Vector3(cos(ang), 0, sin(ang)) * 11.0, 1.0),
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
		if gano:
			ganadas += 1
		detalle += "%s:%s%s " % [String(pj).substr(0, 3), "G" if gano else "p", "(" + nota + ")"]
	print("%-15s %d/%d   %s" % [modo, ganadas, PRUEBAS, detalle])
