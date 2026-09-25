extends Node
## Auditoria del modo historia. NO es un test: no afirma nada, mide y reporta.
##
##   godot --path . --resolution 1280x720 res://tests/auditoria_historia.tscn -- <carpeta> [1,4,10]
##
## Recorre los capitulos como los ve el jugador —la escena de entrada, un rato de pelea,
## las escenas de mitad de pelea y la final— y en CADA LINEA mide lo que una captura sola
## no dice: si el que habla sale en cuadro, si lo tapa una pared u otro personaje, si la
## camara quedo pegada a algo, si hay alguien flotando, hundido o encimado. Al terminar
## cada escena revisa que todo haya vuelto: la camara del jugador, el HUD, los carteles,
## los bots, las poses. Y durante la pelea, que nadie quede invisible peleando, trabado o
## fuera del mapa. Cada linea deja su captura en la carpeta.
##
## No guarda nada: el progreso del jugador queda como estaba.

var main: Node
var _salida: String = ""
var _solo: Array = []
var _problemas: Array[String] = []
var _cap: int = 0
var _etapa: String = ""

const BARRA: float = 86.0
const PANEL: float = 150.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_salida = String(args[0]) if args.size() > 0 else OS.get_user_data_dir().path_join("auditoria")
	if args.size() > 1:
		for n in String(args[1]).split(","):
			_solo.append(int(n) - 1)
	DirAccess.make_dir_recursive_absolute(_salida)
	Progreso.guardado_activo = false
	for i: int in range(Historia.cantidad()):
		Progreso.historia[str(i)] = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_correr.call_deferred()


func _mal(texto: String) -> void:
	var linea := "cap %d %s: %s" % [_cap + 1, _etapa, texto]
	_problemas.append(linea)
	print("[auditoria] MAL ", linea)


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for _i: int in range(n):
		await get_tree().process_frame


func _mision() -> MisionHistoria:
	return Modos.mision as MisionHistoria


func _cine() -> Cinematica:
	var m := _mision()
	if m == null:
		return null
	for hijo: Node in m.get_children():
		if hijo is Cinematica and not hijo.is_queued_for_deletion():
			return hijo
	return null


func _foto(nombre: String) -> void:
	await _frames(2)
	get_viewport().get_texture().get_image().save_png(_salida.path_join(nombre + ".png"))


func _correr() -> void:
	await _esperar(1.0)
	for c: int in range(Historia.cantidad()):
		if not _solo.is_empty() and not _solo.has(c):
			continue
		_cap = c
		await _capitulo(c)
		Net.leave_game()
		main.show_main_menu()
		await _esperar(0.8)
	print("")
	print("[auditoria] ==== %d problemas ====" % _problemas.size())
	for p: String in _problemas:
		print("  ", p)
	get_tree().quit()


func _capitulo(c: int) -> void:
	print("[auditoria] ---- capitulo %d" % (c + 1))
	main.jugar_capitulo(c)
	var espera := 0.0
	while _cine() == null and espera < 6.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	if _cine() == null:
		_etapa = "intro"
		_mal("la escena de entrada no arranco")
		return
	var m := _mision()
	var jugador := m.jugador()
	# El jugador no se defiende: que no se muera mientras se mira la pelea.
	jugador.health.set_max(99999.0)
	jugador.health.revive_full()

	_etapa = "intro"
	await _auditar_escena("c%02d_intro" % (c + 1))
	await _despues_de_escena(m)
	_etapa = "pelea"
	await _mirar_pelea(m, 6.0)

	# Las escenas de mitad de pelea, provocadas como en la pelea de verdad.
	var eventos: Array = m.datos.get("eventos", [])
	var n := 0
	for i: int in range(eventos.size()):
		var ev: Array = eventos[i]
		var tiene := false
		for a: Array in ev[1]:
			if String(a[0]) == "cinematica":
				tiene = true
		if not tiene or m._hechos.has(i) or m.terminada:
			continue
		n += 1
		_etapa = "mitad%d" % n
		_provocar(m, ev[0] as Array)
		espera = 0.0
		while _cine() == null and espera < 3.0:
			await get_tree().process_frame
			espera += get_process_delta_time()
		if _cine() == null:
			_mal("la escena de mitad de pelea no arranco (condicion %s)" % str(ev[0]))
			continue
		await _auditar_escena("c%02d_mitad%d" % [c + 1, n])
		await _despues_de_escena(m)
		_etapa = "pelea%d" % n
		await _mirar_pelea(m, 5.0)

	if m.terminada:
		_etapa = "final"
		_mal("el capitulo termino antes de la escena final")
		return
	_etapa = "final"
	m._ganar()
	espera = 0.0
	while _cine() == null and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	if _cine() == null:
		_mal("la escena final no arranco")
		return
	await _auditar_escena("c%02d_final" % (c + 1))
	await _esperar(0.5)
	if Cinematica.activa:
		_mal("Cinematica.activa sigue prendido despues de la escena final")


func _provocar(m: MisionHistoria, cond: Array) -> void:
	match String(cond[0]):
		"vida":
			var b := m.participantes.get(StringName(cond[1])) as Player
			if b != null:
				var falta := b.health.current - b.health.max_health * (float(cond[2]) - 0.03)
				if falta > 0.0:
					b.health.apply_damage(falta, m.jugador().peer_id)
		"tiempo":
			m.tiempo = maxf(m.tiempo, float(cond[1]))
		"muere":
			var b := m.participantes.get(StringName(cond[1])) as Player
			if b != null:
				b.health.apply_damage(b.health.current + 999.0, m.jugador().peer_id)
		"quedan":
			for b: Player in m.participantes.values():
				if m.enemigos_vivos() <= int(cond[1]):
					break
				if is_instance_valid(b) and b.equipo == 1 and not b.health.is_dead:
					b.health.apply_damage(b.health.current + 999.0, m.jugador().peer_id)


# ------------------------------------------------------------------ Escenas

## Linea por linea: espera a que la linea este en pantalla, mide, saca la foto y avanza.
func _auditar_escena(prefijo: String) -> void:
	var c := _cine()
	var lineas: Array = []
	for paso: Array in c.pasos:
		if String(paso[0]) in ["decir", "narrar"]:
			lineas.append(paso)
	var k := 0
	var tope := 0.0
	var ultimo_muestreo := 0.0
	while is_instance_valid(c) and not c.is_queued_for_deletion() and tope < 120.0:
		await get_tree().process_frame
		tope += get_process_delta_time()
		ultimo_muestreo += get_process_delta_time()
		if not is_instance_valid(c):
			break
		# Entre lineas tambien pasa cosas —gente que camina, que cae, que aparece—: se mira
		# la postura de todos cada medio segundo.
		if ultimo_muestreo > 0.5:
			ultimo_muestreo = 0.0
			_revisar_cuerpos(c, "entre lineas %d" % k)
		if c._esperando:
			await _esperar(0.45)
			if not is_instance_valid(c):
				break
			var paso: Array = lineas[k] if k < lineas.size() else ["?"]
			_revisar_linea(c, paso, k)
			_revisar_cuerpos(c, "linea %d" % k)
			await _foto("%s_%02d" % [prefijo, k])
			k += 1
			if is_instance_valid(c):
				c._avanzar()
				c._avanzar()
	if tope >= 120.0:
		_mal("la escena no termino en 120 s")
		if is_instance_valid(c):
			c.saltear()
	if k != lineas.size():
		_mal("se vieron %d lineas de %d" % [k, lineas.size()])


func _revisar_linea(c: Cinematica, paso: Array, k: int) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_mal("linea %d: no hay camara" % k)
		return
	if cam != c._camara:
		_mal("linea %d: la camara activa no es la de la escena" % k)
	var tam := get_viewport().get_visible_rect().size
	var espacio := cam.get_world_3d().direct_space_state
	var texto := String(paso[2]) if paso.size() > 2 else String(paso[1]) if paso.size() > 1 else ""
	var corto := texto.substr(0, 38)

	# ¿La camara mira una pared de cerca?
	var frente := -cam.global_transform.basis.z
	var r := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + frente * 1.6)
	r.collision_mask = GameConfig.LAYER_WORLD
	if not espacio.intersect_ray(r).is_empty():
		_mal("linea %d (%s): la camara mira una pared a menos de 1.6 m" % [k, corto])

	if String(paso[0]) != "decir":
		return
	var quien := StringName(paso[1])
	var a := c._actor(quien)
	if a == null:
		_mal("linea %d: habla '%s' y no es actor de la escena" % [k, quien])
		return
	if not a.visible:
		_mal("linea %d (%s): habla %s, que esta invisible" % [k, corto, quien])
		return
	var cabeza := c._cabeza(a)
	var dist := cam.global_position.distance_to(cabeza)
	if not cam.is_position_in_frustum(cabeza):
		_mal("linea %d (%s): %s habla fuera de cuadro" % [k, corto, quien])
		return
	var en_pantalla := cam.unproject_position(cabeza)
	if en_pantalla.y < BARRA or en_pantalla.y > tam.y - PANEL or en_pantalla.x < tam.x * 0.04 \
			or en_pantalla.x > tam.x * 0.96:
		_mal("linea %d (%s): la cara de %s queda bajo las barras o el texto (%d, %d)" % [
			k, corto, quien, int(en_pantalla.x), int(en_pantalla.y)])
	if dist < 0.9:
		_mal("linea %d (%s): camara pegada a la cara de %s (%.2f m)" % [k, corto, quien, dist])
	# ¿Se lo ve, o es un punto en el horizonte? Alto en pantalla de pies a cabeza.
	var pies := cam.unproject_position(a.global_position)
	var alto_px := absf(pies.y - en_pantalla.y)
	if alto_px < 70.0 and cam.is_position_in_frustum(a.global_position):
		_mal("linea %d (%s): %s se ve muy chico (%d px de alto, a %.1f m)" % [k, corto, quien,
			int(alto_px), dist])
	var rr := PhysicsRayQueryParameters3D.create(cam.global_position, cabeza)
	rr.collision_mask = GameConfig.LAYER_WORLD
	if not espacio.intersect_ray(rr).is_empty():
		_mal("linea %d (%s): una pared tapa a %s" % [k, corto, quien])
	# ¿Otro personaje parado entre la camara y el que habla?
	for otro: Node in c.actores.values():
		var o := otro as Player
		if o == null or not is_instance_valid(o) or o == a or not o.visible:
			continue
		for alto: float in [1.0, 1.5]:
			var punto := o.global_position + Vector3.UP * alto * o.visual.build_scale.y
			var seg := cabeza - cam.global_position
			var t := clampf((punto - cam.global_position).dot(seg) / seg.length_squared(), 0.0, 1.0)
			if t > 0.05 and t < 0.92 and (cam.global_position + seg * t).distance_to(punto) < 0.32:
				_mal("linea %d (%s): %s tapa a %s" % [k, corto, o.character_id, quien])
				break
	# De espaldas a la camara en un primer plano: se ve la nuca.
	var mira := -a.global_transform.basis.z
	var hacia_cam := cam.global_position - cabeza
	hacia_cam.y = 0.0
	if dist < 4.0 and mira.dot(hacia_cam.normalized()) < -0.3:
		_mal("linea %d (%s): %s habla de espaldas a la camara" % [k, corto, quien])


func _revisar_cuerpos(c: Cinematica, cuando: String) -> void:
	var espacio := get_viewport().get_world_3d().direct_space_state
	var vistos: Array[Player] = []
	for otro: Node in c.actores.values():
		var p := otro as Player
		if p == null or not is_instance_valid(p) or not p.visible:
			continue
		vistos.append(p)
		# El que esta cayendo (una entrada desde el cielo) no tiene piso cerca: es la escena.
		if absf(p.velocity.y) > 1.0:
			continue
		var desde := p.global_position + Vector3.UP * 0.6
		var r := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 8.0)
		r.collision_mask = GameConfig.LAYER_WORLD
		var golpe := espacio.intersect_ray(r)
		if golpe.is_empty():
			_mal("%s: %s no tiene piso abajo (y=%.1f)" % [cuando, p.character_id, p.global_position.y])
			continue
		var alto := p.global_position.y - (golpe["position"] as Vector3).y
		if alto > 0.45 and not p.is_on_floor() and absf(p.velocity.y) < 0.5:
			_mal("%s: %s flota %.2f m" % [cuando, p.character_id, alto])
	for i: int in range(vistos.size()):
		for j: int in range(i + 1, vistos.size()):
			var d := vistos[i].global_position - vistos[j].global_position
			d.y = 0.0
			if d.length() < 0.55:
				_mal("%s: %s y %s encimados (%.2f m)" % [cuando, vistos[i].character_id,
					vistos[j].character_id, d.length()])


## Lo que una escena tiene que dejar como estaba.
func _despues_de_escena(m: MisionHistoria) -> void:
	# Lo que la escena dejo, medido en el primer frame despues: un rato mas tarde ya es la
	# pelea la que pudo haber aturdido a alguien.
	var espera := 0.0
	while Cinematica.activa and espera < 3.0:
		await get_tree().process_frame
		espera += get_process_delta_time()
	for id: StringName in m.participantes:
		var b := m.participantes[id] as Player
		if is_instance_valid(b) and not m._fuera.has(id) and not b.health.is_dead \
				and not b.status.can_act():
			_mal("%s sale de la escena aturdido o congelado" % id)
	await _esperar(0.3)
	var p := m.jugador()
	if Cinematica.activa:
		_mal("Cinematica.activa sigue prendido")
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam != p.camera_pivot.camera:
		_mal("la camara no volvio a la del jugador")
	if not m.hud.visible:
		_mal("el HUD quedo escondido")
	if not BotBrain.globally_enabled:
		_mal("los bots quedaron apagados")
	for id: StringName in m.participantes:
		var b := m.participantes[id] as Player
		if not is_instance_valid(b) or m._fuera.has(id) or b.health.is_dead:
			continue
		if not b.visible:
			_mal("%s quedo invisible y en la pelea" % id)
		if b != p and not b.name_label.visible:
			_mal("%s quedo sin cartel de nombre" % id)
		var d := m._datos_de(b)
		if b.visual._pose_guion != &"" and not d.get("quieto", false):
			_mal("%s quedo en la pose '%s'" % [id, b.visual._pose_guion])
	for hijo: Node in m.arena.get_children():
		if hijo is Player and (hijo as Player).peer_id <= -900 and (hijo as Player).peer_id > -1000 \
				and not hijo.is_queued_for_deletion():
			_mal("quedo un actor de escena (%s) en la arena" % (hijo as Player).character_id)


## Un rato de pelea: nadie invisible peleando, nadie trabado, nadie fuera del mapa.
func _mirar_pelea(m: MisionHistoria, segundos: float) -> void:
	var antes: Dictionary = {}
	var quietos: Dictionary = {}
	var t := 0.0
	while t < segundos and not m.terminada:
		await _esperar(0.5)
		t += 0.5
		# Una escena que arranca sola en la pelea (un jefe que llego a media vida antes de
		# que la provoquemos): se la audita igual, y la pelea sigue despues.
		if _cine() != null:
			var etapa := _etapa
			_etapa = etapa + "+escena"
			await _auditar_escena("c%02d_%s" % [_cap + 1, _etapa.replace("+", "_")])
			await _despues_de_escena(m)
			_etapa = etapa
			antes.clear()
			quietos.clear()
			continue
		for id: StringName in m.participantes:
			var b := m.participantes[id] as Player
			if not is_instance_valid(b):
				continue
			# Los de afuera (tirados, de reserva) tambien: tienen que seguir en el piso.
			if b.visible and b.visual.visible and _hundido(b):
				_mal("%s esta hundido en el piso (y=%.2f)" % [id, b.global_position.y])
			if b.health.is_dead or m._fuera.has(id):
				continue
			if b.is_in_group("players") and not b.visible:
				_mal("%s pelea invisible" % id)
			if b.global_position.y < -2.0 or absf(b.global_position.x) > Arena.ARENA_SIZE * 0.6 \
					or absf(b.global_position.z) > Arena.ARENA_SIZE * 0.6:
				_mal("%s se fue del mapa (%s)" % [id, str(b.global_position)])
			if b == m.jugador() or m._datos_de(b).get("quieto", false):
				continue
			if antes.has(id) and (antes[id] as Vector3).distance_to(b.global_position) < 0.05:
				quietos[id] = int(quietos.get(id, 0)) + 1
			antes[id] = b.global_position
	for id: StringName in quietos:
		if int(quietos[id]) >= int(segundos / 0.5) - 1:
			_mal("%s no se movio en toda la pelea (%.0f s)" % [id, segundos])


func _hundido(p: Player) -> bool:
	var espacio := p.get_world_3d().direct_space_state
	var desde := p.global_position + Vector3.UP * 1.5
	var r := PhysicsRayQueryParameters3D.create(desde, desde + Vector3.DOWN * 8.0)
	r.collision_mask = GameConfig.LAYER_WORLD
	var golpe := espacio.intersect_ray(r)
	return golpe.is_empty() or p.global_position.y < (golpe["position"] as Vector3).y - 0.3
