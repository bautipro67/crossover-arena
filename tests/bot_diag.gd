extends Node
## Diagnostico de los bots. NO es un test: no afirma nada, solo mide y reporta.
##
## Correlo con:
##   godot --headless --path . res://tests/bot_diag.tscn
##
## Existe porque "los bots estan mal" puede ser diez cosas distintas y todas se ven
## parecidas desde afuera: uno que se traba contra una cobertura, tres amontonados en el
## mismo punto, uno que oscila sin decidirse, uno que nunca llega a pegar. Mirarlos no
## alcanza para distinguirlas; medirlas, si.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const DURACION: float = 26.0
const MUESTREO: float = 0.25

var _main: Node = null
var _muestras: Dictionary = {}


func _ready() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	Net.start_solo("Diag")
	Net.start_match()
	for _i: int in range(10):
		await get_tree().process_frame

	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if arena == null or player == null:
		print("no se pudo armar la partida")
		get_tree().quit(1)
		return

	# El jugador se queda quieto y aguanta: queremos medir a los bots, no una pelea.
	player.health.set_max(100000.0)
	player.respawn_at(arena.find_clear_spot(Vector3(0.0, 0.6, 16.0), 1.5), PI)
	await get_tree().process_frame

	var bots: Array[Player] = []
	for child: Node in arena.get_children():
		var p := child as Player
		if p != null and p.is_dummy:
			bots.append(p)
			_muestras[p.name] = {
				"prev": p.global_position,
				"quieto": 0.0,          # tiempo sin avanzar queriendo avanzar
				"recorrido": 0.0,
				"dist_min": 9999.0,
				"dist_max": 0.0,
				"ataques": 0,
				"cerca": 0.0,           # tiempo a distancia de pegar
				"giros": 0,             # cambios bruscos de direccion
				"dir_prev": Vector3.ZERO,
			}
			p.caster.ability_used.connect(func(_i: int) -> void:
				_muestras[p.name]["ataques"] += 1)

	# Estado real del servidor de navegacion: si el mapa esta vacio, el agente jamas va
	# a devolver un camino y todo lo demas que midamos es ruido.
	var mapa := get_viewport().world_3d.navigation_map
	print("[nav] mapa=%s  regiones=%d" % [
		str(mapa), NavigationServer3D.map_get_regions(mapa).size()])
	var cerca_bot := NavigationServer3D.map_get_closest_point(mapa, bots[0].global_position)
	print("[nav] punto navegable mas cercano al bot: %s (bot en %s)" % [
		cerca_bot, bots[0].global_position])
	var camino := NavigationServer3D.map_get_path(
		mapa, bots[0].global_position, player.global_position, true)
	print("[nav] camino directo del servidor: %d puntos" % camino.size())

	print("bots: %d   jugador en %s" % [bots.size(), player.global_position])
	print("")

	var t := 0.0
	while t < DURACION:
		await get_tree().create_timer(MUESTREO).timeout
		t += MUESTREO
		for bot: Player in bots:
			if not is_instance_valid(bot):
				continue
			var m: Dictionary = _muestras[bot.name]
			var pos := bot.global_position
			var avance := Vector2(pos.x - m["prev"].x, pos.z - m["prev"].z).length()
			m["recorrido"] += avance
			# "Quieto" = queria moverse y no se movio. Eso es trabado, no parado.
			if not bot.bot_move_dir.is_zero_approx() and avance < 0.05:
				m["quieto"] += MUESTREO
			var d := pos.distance_to(player.global_position)
			m["dist_min"] = minf(m["dist_min"], d)
			m["dist_max"] = maxf(m["dist_max"], d)
			if d <= BotBrain.MELEE_RANGE + 0.6:
				m["cerca"] += MUESTREO
			var dir: Vector3 = bot.bot_move_dir
			if not dir.is_zero_approx() and not m["dir_prev"].is_zero_approx():
				if dir.dot(m["dir_prev"]) < -0.3:
					m["giros"] += 1
			m["dir_prev"] = dir
			m["prev"] = pos

	print("=== %.0f segundos de observacion ===" % DURACION)
	for bot: Player in bots:
		var m: Dictionary = _muestras[bot.name]
		print("")
		print("%s (%s)" % [bot.name, bot.character_id])
		print("   recorrido total ....... %.1f m   (%.1f m/s de promedio)" % [
			m["recorrido"], m["recorrido"] / DURACION])
		print("   TRABADO ............... %.1f s  (%.0f%% del tiempo)" % [
			m["quieto"], 100.0 * m["quieto"] / DURACION])
		print("   distancia al jugador .. min %.1f m / max %.1f m" % [m["dist_min"], m["dist_max"]])
		print("   a distancia de pegar .. %.1f s  (%.0f%%)" % [
			m["cerca"], 100.0 * m["cerca"] / DURACION])
		print("   ataques tirados ....... %d" % m["ataques"])
		print("   cambios bruscos de rumbo %d" % m["giros"])

	# Y cuanto le sacaron al jugador entre los tres.
	var perdida := player.health.max_health - player.health.current
	print("")
	print("daño total al jugador: %.0f en %.0f s  (%.1f por segundo)" % [
		perdida, DURACION, perdida / DURACION])

	# Amontonamiento: si los tres estan en el mismo punto, se tapan y pelean como uno.
	if bots.size() >= 2:
		var minimo := 9999.0
		for i: int in range(bots.size()):
			for j: int in range(i + 1, bots.size()):
				minimo = minf(minimo, bots[i].global_position.distance_to(bots[j].global_position))
		print("distancia minima ENTRE bots al final: %.1f m" % minimo)

	get_tree().quit(0)
