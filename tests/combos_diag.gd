extends Node
## Diagnostico de los combos. NO es un test: no afirma nada, solo mide y reporta.
##
##   godot --headless --path . res://tests/combos_diag.tscn
##
## Mide, por personaje, dos cosas del tambaleo que deja cada golpe:
##   1. CADENA: cuantos golpes seguidos entran encadenando basico y habilidades, que es lo
##      que el tambaleo existe para permitir.
##   2. TRABA: cuanto tiempo seguido se puede dejar a alguien sin poder moverse spameando
##      SOLO el basico. Si llega al tope de la medicion, es una traba infinita.
## Las dos, con el atacante quieto y persiguiendo al rival como lo haria una persona.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MEDICION: float = 6.0

var _main: Node = null


func _ready() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	Arena.set_bots_active(false)
	Practica.set_bots(0)
	Modos.iniciar(Modos.PRACTICA)
	Net.start_solo("Diag")
	Net.start_match()
	for _i: int in range(20):
		await get_tree().process_frame
	var arena := _main.get_node_or_null("Arena") as Arena
	var player := arena.get_local_player() if arena != null else null
	if player == null:
		print("no se pudo armar la partida")
		get_tree().quit(1)
		return

	var victima: Player = Arena.PLAYER_SCENE.instantiate()
	victima.peer_id = -77
	victima.is_dummy = true
	victima.player_name = "Victima"
	arena.add_child(victima)
	victima.setup_character(CharacterDB.get_character(&"noelle"))
	victima.health.set_max(99999.0)

	print("\n=== COMBOS (tambaleo %.2f s) ===" % StatusEffects.TAMBALEO)
	for cid: StringName in CharacterDB.get_all_ids():
		var data := CharacterDB.get_character(cid)
		player.setup_character(data)
		for persigue: bool in [false, true]:
			var traba := await _medir(arena, player, victima, persigue, true)
			var cadena := await _medir(arena, player, victima, persigue, false)
			print("%-8s %-10s  solo basico: traba %.2f s de %.1f  |  basico + habilidades: %d golpes seguidos en %.2f s" % [
				cid, "persigue" if persigue else "quieto", traba[0], MEDICION, cadena[1], cadena[0]])
	get_tree().quit()


## Devuelve [el tramo mas largo sin poder actuar, cuantos golpes tuvo ese tramo].
func _medir(arena: Arena, player: Player, victima: Player, persigue: bool, solo_basico: bool) -> Array:
	var puesto := arena.find_clear_spot(Vector3(0.0, 0.6, 20.0), 1.5)
	var yaw := 0.0
	player.respawn_at(puesto, yaw)
	player.camera_pivot.set_yaw(yaw)
	player.aim_override = Vector3.FORWARD
	player.health.revive_full()
	player.status.clear_all()
	player.caster.reset_state()
	player.ultimate.current = 0.0
	victima.global_position = puesto + Vector3.FORWARD * 2.0
	victima.velocity = Vector3.ZERO
	victima.health.revive_full()
	victima.status.clear_all()
	for _i: int in range(20):
		await get_tree().physics_frame

	var golpes_antes := 0
	var vida := victima.health.current
	var tramo := 0.0
	var mejor := 0.0
	var golpes_tramo := 0
	var mejor_golpes := 0
	var t := 0.0
	while t < MEDICION:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		player.stamina.restore_full()
		var hacia := victima.global_position - player.global_position
		hacia.y = 0.0
		if hacia.length() > 0.05:
			player.aim_override = (hacia.normalized() + Vector3.UP * -0.05).normalized()
		# Perseguir: como una persona que se queda encima. Se lo acerca a 1.8 m del rival.
		if persigue and hacia.length() > 2.2:
			player.global_position = victima.global_position - hacia.normalized() * 1.8
		if not player.caster.is_channeling:
			var usado := false
			if not solo_basico:
				for i: int in [1, 2]:
					if not player.caster.is_on_cooldown(i):
						player.caster.request_use(i)
						usado = true
						break
			if not usado and not player.caster.is_on_cooldown(0):
				player.caster.request_use(0)
		if victima.health.current < vida - 0.01:
			golpes_tramo += 1
			vida = victima.health.current
		if not victima.status.can_act():
			tramo += dt
			if tramo > mejor:
				mejor = tramo
				mejor_golpes = golpes_tramo
		else:
			tramo = 0.0
			golpes_tramo = 0
	player.aim_override = Vector3.ZERO
	return [mejor, mejor_golpes]
