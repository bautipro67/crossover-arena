class_name MisionHistoria
extends Node
## La pelea de un capitulo: quien pelea y de que lado, que hay que hacer para ganar, y
## que pasa en el medio.
##
## COMO UNA MISION DE XENOVERSE: no siempre es "mata a todos". Hay capitulos donde hay que
## proteger a alguien mientras trabaja, aguantar en una zona, sobrevivir hasta que llegue
## ayuda, o bajarle la vida a alguien lo suficiente para que escuche. Y la pelea cambia en
## el medio: un jefe que se potencia a mitad de vida, refuerzos que llegan, un aliado que
## cae, alguien que grita algo. Todo eso sale de los datos del capitulo (ver Historia).
##
## LOS ALIADOS SON BOTS DEL MISMO EQUIPO: pelean solos contra los enemigos y siguen al
## jugador cuando no hay nadie cerca. Los golpes no se cruzan entre aliados (ver
## CombatUtils.son_aliados).
##
## OBJETIVOS ("tipo"):
##   derrotar_todos             ganar = no queda ningun enemigo en pie
##   derrotar  {id, hasta}      ganar = ese cae, o su vida baja de `hasta` (0-1)
##   proteger  {id, segundos}   ganar = aguantar esos segundos; perder = que caiga ese
##   sobrevivir {segundos}      ganar = seguir en pie esos segundos
##   zona {centro, radio, segundos}   ganar = estar adentro ese tiempo, acumulado
## Y en todos: perder si cae el jugador, y si hay "limite", perder al pasarlo.
##
## EVENTOS: [condicion, acciones]. Condiciones: ["inicio"], ["tiempo", s],
## ["vida", id, fraccion], ["muere", id], ["quedan", n]. Acciones: ["decir", quien, texto],
## ["refuerzos", [enemigos]], ["aliado", aliado], ["potenciar", id, segundos],
## ["curar", id], ["retirar", id], ["entrar", id], ["objetivo", objetivo],
## ["cinematica", pasos], ["ganar"], ["perder", texto]. Cada evento pasa una sola vez.
##
## PARTICIPANTES ("aliados" y "enemigos"): id, personaje, nombre, vida, daño, pos, y
## opcionales: eco (copia oscura), jefe (barra arriba), quieto (no pelea: trabaja o
## espera, con "pose"), oculto (escondido hasta la pelea o hasta que una escena lo haga
## aparecer) y reserva (fuera de la pelea hasta ["entrar", id]).

## Una linea dicha EN la pelea, sin cortarla: la muestra el HUD con el retrato.
signal dijo(quien: StringName, texto: String)

var capitulo: int = 0
var datos: Dictionary = {}
var arena: Arena = null
var hud: CanvasLayer = null
## En el simulador de balance, un bot hace de jugador. En el juego, null: es el local.
var heroe: Player = null

## id -> Player, incluido el jugador bajo su id de personaje.
var participantes: Dictionary = {}
## peer -> datos de ese participante (vida, daño, equipo...).
var _por_peer: Dictionary = {}
var _siguiente_peer: int = -1
var objetivo: Dictionary = {}
var tiempo: float = 0.0
var _zona_t: float = 0.0
var _zona: Node3D = null
var _hechos: Dictionary = {}
## Los que estan fuera de la pelea: los de reserva que todavia no entraron y los que una
## escena dejo tirados. id -> true. Siguen siendo actores de las escenas.
var _fuera: Dictionary = {}
var _en_pelea: bool = false
var terminada: bool = false
var ancla: Vector3 = Vector3.ZERO
## Para el arnes: se salta las escenas.
static var sin_cinematicas: bool = false


func _ready() -> void:
	Modos.mision = self
	objetivo = (datos.get("objetivo", {"tipo": "derrotar_todos"}) as Dictionary).duplicate(true)
	_arrancar.call_deferred()


func _exit_tree() -> void:
	if Modos.mision == self:
		Modos.mision = null
	# LO QUE LA MISION APAGO, SE PRENDE AL IRSE. Los bots se apagan con una llave global
	# —para las escenas y al terminar—, y si la mision se va con la llave cerrada, la
	# proxima partida arranca con bots que no se mueven.
	Arena.set_bots_active(true)
	Cinematica.activa = false


func jugador() -> Player:
	if is_instance_valid(heroe):
		return heroe
	return arena.get_local_player() if is_instance_valid(arena) else null


# ------------------------------------------------------------------- Armado

func _arrancar() -> void:
	var p := jugador()
	var espera := 0
	while p == null and espera < 300:
		await get_tree().process_frame
		espera += 1
		p = jugador()
	if p == null:
		return
	Arena.set_bots_active(false)
	p.equipo = 0
	var id_jugador := StringName(datos.get("personaje", p.character_id))
	participantes[id_jugador] = p
	# La muerte del jugador la escucha la mision: es la que sabe que eso pierde el capitulo.
	p.died.connect(func(_asesino: int) -> void: _al_morir(id_jugador))
	ancla = lugar_despejado(arena, p.global_position)
	p.global_position = ancla + Vector3.UP * 0.1
	if p.is_local_player():
		p.camera_pivot.set_yaw(0.0)
	for a: Dictionary in datos.get("aliados", []):
		_sumar(a, 0)
	for e: Dictionary in datos.get("enemigos", []):
		_sumar(e, 1)
	if objetivo.get("tipo", "") == "zona":
		_crear_zona()

	var intro: Array = [["titulo", "CAPÍTULO %d" % (capitulo + 1), String(datos.get("titulo", ""))]]
	intro.append_array(datos.get("intro", []))
	await _escena(intro)
	_comenzar()


## Un participante nuevo. Lo crea la arena, igual que a cualquier bot.
func _sumar(d: Dictionary, equipo: int) -> Player:
	var peer := _siguiente_peer
	_siguiente_peer -= 1
	var rel: Vector2 = d.get("pos", Vector2(0.0, -14.0))
	var punto := al_piso(arena, arena.find_clear_spot(ancla + Vector3(rel.x, 0.0, rel.y), 1.0))
	_por_peer[peer] = d
	arena._crear_bot(peer, punto, StringName(d["personaje"]))
	var b: Player = arena._players.get(peer)
	if b == null:
		return null
	b.equipo = equipo
	b.health.set_max(float(d.get("vida", 60.0)))
	b.health.revive_full()
	b.player_name = String(d.get("nombre", ""))
	b.name_label.text = b.player_name
	# Verde los tuyos, rojo los otros: con aliados en pantalla, saber a quien no pegarle
	# es lo primero.
	b.name_label.modulate = Color(0.55, 1.0, 0.6) if equipo == 0 else Color(1.0, 0.55, 0.5)
	if d.get("eco", false):
		b.visual.volverse_eco()
	# Los jefes no se tambalean: ver StatusEffects.sin_tambaleo.
	if d.get("jefe", false):
		b.status.sin_tambaleo = true
	if d.get("quieto", false):
		var cerebro := b.get_node_or_null("BotBrain")
		if cerebro != null:
			cerebro.set_process(false)
			cerebro.set_physics_process(false)
		if d.has("pose"):
			b.visual.actuar(StringName(d["pose"]))
	# El frente de los enemigos es hacia el jugador; el de los aliados, hacia adelante.
	var hacia := ancla - b.global_position
	if equipo == 1 and Vector2(hacia.x, hacia.z).length() > 0.1:
		b.rotation.y = atan2(-hacia.x, -hacia.z)
		b.bot_look_yaw = b.rotation.y
	if d.get("oculto", false):
		b.visible = false
	participantes[StringName(d["id"])] = b
	# DE RESERVA: esta en el capitulo desde el principio pero no pelea hasta que un evento
	# lo hace entrar (["entrar", id]). Es como llega un aliado a mitad de una pelea.
	if d.get("reserva", false):
		_apagar(b)
		b.visible = false
		_fuera[StringName(d["id"])] = true
	b.died.connect(func(_asesino: int) -> void: _al_morir(StringName(d["id"])))
	return b


## El punto, apoyado en el piso que tenga abajo.
##
## find_clear_spot busca un hueco libre pero conserva la altura que le pidieron, y el ancla
## de una escena tiene la altura del lugar donde cayo: dos metros al costado puede haber
## un escalon o una rampa. Sin esto el actor aparecia medio metro en el aire y caia, o
## adentro de una plataforma baja, y la fisica lo escupia para cualquier lado.
static func al_piso(arena: Arena, punto: Vector3) -> Vector3:
	var espacio := arena.get_world_3d().direct_space_state
	if espacio == null:
		return punto
	var desde := punto + Vector3.UP * 1.6
	var rayo := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 8.0)
	rayo.collision_mask = GameConfig.LAYER_WORLD
	var golpe := espacio.intersect_ray(rayo)
	if golpe.is_empty():
		return punto
	return Vector3(punto.x, (golpe["position"] as Vector3).y, punto.z)


## El lugar mas despejado del mapa, para que entren la escena y la pelea.
##
## LAS ESCENAS NECESITAN AIRE. Los guiones ponen gente a doce metros y camaras a cinco, y
## arrancando donde aparece el jugador —que puede ser contra una cobertura— media escena
## quedaba detras de una pared. Se prueban puntos por todo el mapa y gana el que tiene
## mas espacio libre alrededor, medido con rayos en ocho direcciones.
static func lugar_despejado(arena: Arena, cerca_de: Vector3) -> Vector3:
	var espacio := arena.get_world_3d().direct_space_state
	var mejor := al_piso(arena, arena.find_clear_spot(cerca_de, 2.5))
	var mejor_nota := -1.0
	var mitad := Arena.ARENA_SIZE * 0.5 - 14.0
	var paso := 10.0
	var x := -mitad
	while x <= mitad:
		var z := -mitad
		while z <= mitad:
			var punto := al_piso(arena, arena.find_clear_spot(Vector3(x, 0.6, z), 1.5))
			var nota := 99.0
			for k: int in range(8):
				var a := TAU * float(k) / 8.0
				var dir := Vector3(cos(a), 0.0, sin(a))
				var desde := punto + Vector3.UP * 1.2
				var rayo := PhysicsRayQueryParameters3D.create(desde, desde + dir * 20.0)
				rayo.collision_mask = GameConfig.LAYER_WORLD
				var golpe := espacio.intersect_ray(rayo)
				var d := 20.0 if golpe.is_empty() else desde.distance_to(golpe["position"] as Vector3)
				nota = minf(nota, d)
			# A igual espacio, el mas parejo al piso (sin plataformas: una escena en una
			# rampa tiene a la mitad de los actores flotando o hundidos).
			if absf(punto.y) > 0.9:
				nota -= 6.0
			if nota > mejor_nota:
				mejor_nota = nota
				mejor = punto
			z += paso
		x += paso
	return mejor


func _crear_zona() -> void:
	var rel: Vector2 = objetivo.get("centro", Vector2(0.0, -10.0))
	var radio := float(objetivo.get("radio", 6.0))
	var anillo := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = radio - 0.35
	toro.outer_radius = radio
	anillo.mesh = toro
	anillo.material_override = Art.glow(Color(0.45, 0.85, 1.0), 2.4)
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arena.add_child(anillo)
	anillo.global_position = ancla + Vector3(rel.x, 0.08, rel.y)
	_zona = anillo


# -------------------------------------------------------------------- Pelea

func _comenzar() -> void:
	if terminada:
		return
	# Los que la escena tenia escondidos entran a pelear. Los de reserva, no.
	for id: StringName in participantes:
		var p := participantes[id] as Player
		if is_instance_valid(p) and not _fuera.has(id):
			p.visible = true
	for id: StringName in participantes:
		var b := participantes[id] as Player
		var d: Dictionary = _datos_de(b)
		if d.get("quieto", false) and d.has("pose"):
			b.visual.actuar(StringName(d["pose"]))
	Arena.set_bots_active(true)
	_en_pelea = true
	if is_instance_valid(hud) and hud.has_method("anunciar"):
		hud.anunciar(String(objetivo.get("texto", "¡A pelear!")).to_upper(), 2.2)
	_revisar_eventos()


func _process(delta: float) -> void:
	if not _en_pelea or terminada or Cinematica.activa:
		return
	tiempo += delta
	var p := jugador()
	# Los aliados, cuando no tienen a quien pegarle, vuelven con el jugador y no a donde
	# nacieron: un compañero que se queda parado en la otra punta no acompaña.
	for b: Node in participantes.values():
		var bot := b as Player
		if bot == null or bot == p or bot.equipo != 0 or not is_instance_valid(bot):
			continue
		var cerebro := bot.get_node_or_null("BotBrain") as BotBrain
		if cerebro != null and p != null:
			cerebro.home = p.global_position
	if objetivo.get("tipo", "") == "zona" and p != null and is_instance_valid(_zona):
		var centro := _zona.global_position
		var dentro := Vector2(p.global_position.x - centro.x, p.global_position.z - centro.z).length() \
			<= float(objetivo.get("radio", 6.0))
		if dentro:
			_zona_t += delta
		var mat := _zona.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = mat.albedo_color.lerp(
				Color(0.45, 1.0, 0.55) if dentro else Color(0.45, 0.85, 1.0), delta * 6.0)
	_revisar_eventos()
	_revisar_objetivo()


func _revisar_objetivo() -> void:
	if terminada:
		return
	var limite := float(objetivo.get("limite", 0.0))
	if limite > 0.0 and tiempo >= limite:
		_perder("SE ACABÓ EL TIEMPO")
		return
	match String(objetivo.get("tipo", "derrotar_todos")):
		"derrotar_todos":
			if enemigos_vivos() == 0:
				_ganar()
		"derrotar":
			var b := participantes.get(StringName(objetivo.get("id", ""))) as Player
			var hasta := float(objetivo.get("hasta", 0.0))
			if b == null or b.health.is_dead or (hasta > 0.0 and _vida(b) <= hasta):
				_ganar()
		"proteger", "sobrevivir":
			if tiempo >= float(objetivo.get("segundos", 30.0)):
				_ganar()
		"zona":
			if _zona_t >= float(objetivo.get("segundos", 30.0)):
				_ganar()


func _al_morir(id: StringName) -> void:
	if terminada or not _en_pelea:
		return
	var p := jugador()
	if participantes.get(id) == p:
		_perder("CAÍSTE")
		return
	if objetivo.get("tipo", "") == "proteger" and StringName(objetivo.get("id", "")) == id:
		_perder("NO PUDISTE PROTEGER A %s" % Historia.nombre_de(_personaje_de(id)).to_upper())
		return
	_revisar_eventos()


func _vida(b: Player) -> float:
	return b.health.current / maxf(1.0, b.health.max_health)


func enemigos_vivos() -> int:
	var n := 0
	for b: Node in participantes.values():
		var bot := b as Player
		if bot != null and is_instance_valid(bot) and bot.equipo == 1 and not bot.health.is_dead:
			n += 1
	return n


## Los aliados, para las barras del HUD. Sin el jugador.
func aliados() -> Array[Player]:
	var out: Array[Player] = []
	var p := jugador()
	for b: Node in participantes.values():
		var bot := b as Player
		if bot != null and is_instance_valid(bot) and bot != p and bot.equipo == 0 and bot.visible \
				and not _fuera.has(StringName(participantes.find_key(bot))):
			out.append(bot)
	return out


## El jefe de la pelea, si hay: el que tenga "jefe" en sus datos y siga en pie.
func jefe() -> Player:
	for peer: int in _por_peer:
		if not (_por_peer[peer] as Dictionary).get("jefe", false):
			continue
		var b := arena._players.get(peer) as Player
		if b != null and is_instance_valid(b) and not b.health.is_dead and b.visible:
			return b
	return null


func _datos_de(b: Player) -> Dictionary:
	return _por_peer.get(b.peer_id, {})


func _personaje_de(id: StringName) -> StringName:
	var b := participantes.get(id) as Player
	return b.character_id if b != null else id


## Lo que pega un participante, como fraccion del daño normal. Lo pide CombatUtils.
func daño_de(peer: int) -> float:
	return float((_por_peer.get(peer, {}) as Dictionary).get("daño", 0.4))


func vida_de(peer: int) -> float:
	return float((_por_peer.get(peer, {}) as Dictionary).get("vida", 60.0))


## Lo que el HUD muestra arriba: que hay que hacer, y cuanto falta.
func texto_objetivo() -> String:
	var t := String(objetivo.get("texto", ""))
	match String(objetivo.get("tipo", "derrotar_todos")):
		"derrotar_todos":
			t += "   ·   quedan %d" % enemigos_vivos()
		"proteger", "sobrevivir":
			t += "   ·   %d s" % maxi(0, int(ceil(float(objetivo.get("segundos", 30.0)) - tiempo)))
		"zona":
			t += "   ·   %d / %d s" % [int(_zona_t), int(objetivo.get("segundos", 30.0))]
	var limite := float(objetivo.get("limite", 0.0))
	if limite > 0.0:
		t += "   ·   ⏱ %d s" % maxi(0, int(ceil(limite - tiempo)))
	return t


# ------------------------------------------------------------------ Eventos

func _revisar_eventos() -> void:
	var eventos: Array = datos.get("eventos", [])
	for i: int in range(eventos.size()):
		if _hechos.has(i) or terminada:
			continue
		var ev: Array = eventos[i]
		if _se_cumple(ev[0] as Array):
			_hechos[i] = true
			await _hacer(ev[1] as Array)


func _se_cumple(c: Array) -> bool:
	match String(c[0]):
		"inicio":
			return true
		"tiempo":
			return tiempo >= float(c[1])
		"vida":
			var b := participantes.get(StringName(c[1])) as Player
			return b != null and not b.health.is_dead and _vida(b) <= float(c[2])
		"muere":
			var b := participantes.get(StringName(c[1])) as Player
			return b != null and b.health.is_dead
		"quedan":
			return enemigos_vivos() <= int(c[1])
	return false


func _hacer(acciones: Array) -> void:
	for a: Array in acciones:
		if terminada:
			return
		match String(a[0]):
			"decir":
				dijo.emit(StringName(a[1]), String(a[2]))
			"refuerzos":
				for e: Dictionary in a[1]:
					var b := _sumar(e, 1)
					if b != null:
						FX.spawn_impact_burst(b, b.global_position + Vector3.UP, Color(0.3, 0.2, 0.5, 0.9))
			"aliado":
				var b := _sumar(a[1], 0)
				if b != null:
					FX.spawn_teletransporte(b, b.global_position)
			"potenciar":
				var b := participantes.get(StringName(a[1])) as Player
				if b != null:
					b.status.impulsar(1.25, 0.6, 1.3, float(a[2]) if a.size() > 2 else 12.0)
					FX.spawn_super_sonic(b, float(a[2]) if a.size() > 2 else 12.0)
			"curar":
				var b := participantes.get(StringName(a[1])) as Player
				if b != null:
					b.health.heal(b.health.max_health)
			"retirar":
				# Fuera de la pelea sin contar como baja: el que cae en una escena no "murio"
				# para el objetivo, quedo tirado. Sigue ahi —y habla en la escena final—
				# pero nadie lo elige de blanco ni le llega un golpe.
				var b := participantes.get(StringName(a[1])) as Player
				if b != null:
					_apagar(b)
					b.visible = true
					b.visual.actuar(&"tirado")
					# Sin cartel: un nombre verde flotando sobre alguien noqueado se lee como
					# un aliado que sigue en la pelea.
					b.name_label.visible = false
					_fuera[StringName(a[1])] = true
			"entrar":
				var b := participantes.get(StringName(a[1])) as Player
				if b != null:
					_prender(b)
					b.visible = true
					b.visual.dejar_de_actuar()
					_fuera.erase(StringName(a[1]))
			"objetivo":
				objetivo = (a[1] as Dictionary).duplicate(true)
				tiempo = 0.0
				_zona_t = 0.0
				if objetivo.get("tipo", "") == "zona":
					_crear_zona()
				if is_instance_valid(hud) and hud.has_method("anunciar"):
					hud.anunciar(String(objetivo.get("texto", "")).to_upper(), 2.2)
			"cinematica":
				await _escena(a[1])
				if not terminada:
					Arena.set_bots_active(true)
			"ganar":
				_ganar()
			"perder":
				_perder(String(a[1]) if a.size() > 1 else "PERDISTE")


## Fuera de la pelea: sin cerebro, fuera del grupo "players" y fuera de la capa de los
## jugadores, asi nadie lo elige de blanco ni le llega un golpe. Mandarlo bajo el mapa no
## servia: la red de seguridad de los bots lo devolvia a su marca.
##
## LA CAPA, NO LA FORMA. La primera version apagaba la forma de colision entera, y un
## cuerpo sin colision no tiene piso: el que quedaba tirado se hundia en el suelo, caia
## hasta la red de seguridad, volvia a su marca y se volvia a hundir, en loop, a la vista
## de todos. Sin capa sigue chocando con el mundo y parado donde cayo.
func _apagar(b: Player) -> void:
	b.remove_from_group("players")
	var cerebro := b.get_node_or_null("BotBrain")
	if cerebro != null:
		cerebro.set_process(false)
	b.bot_move_dir = Vector3.ZERO
	b.collision_layer = 0


func _prender(b: Player) -> void:
	if not b.is_in_group("players"):
		b.add_to_group("players")
	var cerebro := b.get_node_or_null("BotBrain")
	var d := _datos_de(b)
	if cerebro != null and not d.get("quieto", false):
		cerebro.set_process(true)
	b.collision_layer = GameConfig.LAYER_PLAYER
	b.name_label.visible = not b.health.is_dead


# ---------------------------------------------------------------- Escenas

func _escena(pasos: Array) -> void:
	if sin_cinematicas or pasos.is_empty():
		return
	var c := Cinematica.new()
	c.pasos = pasos
	c.actores = participantes.duplicate()
	c.ancla = ancla
	c.arena = arena
	c.hud = hud
	add_child(c)
	await c.reproducir()
	c.queue_free()


# ---------------------------------------------------------------- El final

func _ganar() -> void:
	if terminada:
		return
	terminada = true
	_en_pelea = false
	Arena.set_bots_active(false)
	# Todos de vuelta en pie para la escena final: el que perdio tambien habla, y el que
	# quedo tirado se levanta.
	#
	# Y EN FORMACION, cada uno en su lugar respecto del ancla, como al empezar. La pelea
	# termina donde termina —el jugador a veinte metros, un aliado en otra punta— y las
	# escenas se escriben respecto del ancla: sin esto, el plano general de la escena final
	# se abria hasta filmar desde cincuenta metros para que entraran todos.
	var p := jugador()
	for id: StringName in participantes:
		var b := participantes[id] as Player
		if b != null and is_instance_valid(b):
			if _fuera.has(id):
				_prender(b)
				b.visible = true
			var rel: Vector2 = Vector2.ZERO if b == p else _datos_de(b).get("pos", Vector2(0.0, -8.0))
			var lugar := al_piso(arena, arena.find_clear_spot(ancla + Vector3(rel.x, 0.0, rel.y), 1.0))
			var hacia := ancla - lugar
			# Los enemigos, mirando al ancla; los del jugador, hacia adelante.
			var yaw := 0.0
			if b.equipo == 1 and Vector2(hacia.x, hacia.z).length() > 0.1:
				yaw = atan2(-hacia.x, -hacia.z)
			if b.health.is_dead:
				b.respawn_at(lugar + Vector3.UP * 0.1, yaw)
			else:
				b.global_position = lugar + Vector3.UP * 0.1
				b.velocity = Vector3.ZERO
				b.rotation.y = yaw
			b.bot_look_yaw = yaw
			if b.is_local_player() and is_instance_valid(b.camera_pivot):
				b.camera_pivot.set_yaw(yaw)
			b.status.clear_all()
			b.caster.reset_state()
			b.visual.dejar_de_actuar()
			# La potencia se fue con clear_all, y su aura tiene que irse con ella: si no, la
			# escena final muestra al jefe metido en una capsula dorada que tapa todo.
			var aura := b.get_node_or_null(^"AuraSuper")
			if aura != null:
				aura.queue_free()
	_fuera.clear()
	await _escena(datos.get("outro", []))
	Modos.terminar_historia(true, "¡CAPÍTULO %d COMPLETADO!" % (capitulo + 1),
		String(datos.get("titulo", "")))


func _perder(titulo: String) -> void:
	if terminada:
		return
	terminada = true
	_en_pelea = false
	Arena.set_bots_active(false)
	Modos.terminar_historia(false, titulo, "El capítulo se puede volver a intentar cuando quieras.")
