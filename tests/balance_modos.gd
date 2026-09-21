extends Node
## Herramienta: ¿cuánto daño por segundo come el jugador en cada modo?
##
## NO SIMULA UNA PELEA ENTERA, a propósito. Lo intenté dos veces y las dos dieron números
## sin sentido: un BotBrain colgado del jugador no mueve nada porque _process_bot solo
## corre para maniquíes, y marcándolo maniquí los bots dejan de apuntarle. Simular a un
## humano es difícil y el resultado no sería confiable igual.
##
## Esto mide lo que sí define "injusto" y se puede medir sin trampas: el daño que entra
## por segundo. De ahí sale cuánto vive un jugador de 100 de vida que se come todo, que es
## el peor caso, y comparado contra lo que tarda en matar a uno da la relación de fuerzas.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
var _arena: Arena = null

func _ready() -> void:
	var m := MAIN_SCENE.instantiate(); m.name = "Main"
	get_tree().root.call_deferred("add_child", m)
	_correr.call_deferred()

func _correr() -> void:
	await get_tree().process_frame
	Progreso.guardado_activo = false
	Net.host_game(GameConfig.DEFAULT_PORT + 46, "T")
	await get_tree().process_frame
	Net.start_match()
	for _i in range(20): await get_tree().physics_frame
	_arena = get_tree().root.get_node_or_null(^"Main/Arena") as Arena
	print("")
	print("%-16s %5s %7s %8s %9s %9s" % ["modo","bots","vida","daño","dps","vive"])
	for m in [Modos.DUELO, Modos.CONTRARRELOJ, Modos.SUPERVIVENCIA, Modos.ULTIMO_EN_PIE,
			Modos.JEFES, Modos.PRACTICA]:
		Modos.iniciar(m)
		var dps := await _dps(Modos.bots_iniciales())
		var vive := 100.0 / maxf(dps, 0.01)
		print("%-16s %5d %7.0f %8.2f %8.1f %8.1fs" % [
			m, Modos.bots_iniciales(), Modos.vida_bot(), Modos.daño_bot(), dps, vive])
	Modos.iniciar(Modos.PRACTICA)
	get_tree().quit()

## Pone N bots alrededor de un jugador que no se defiende y mide cuánto le sacan.
func _dps(enemigos: int) -> float:
	for id in _arena._players.keys().duplicate():
		if id < 0:
			var b = _arena._players[id]
			if is_instance_valid(b): b.queue_free()
			_arena._players.erase(id)
	await get_tree().process_frame

	var p := _arena.get_local_player()
	# Vida enorme para medir sin que se muera a mitad de la muestra.
	p.health.set_max(100000.0)
	p.health.revive_full()
	p.status.clear_all()
	p._apply_respawn(_arena.find_clear_spot(Vector3.ZERO, 1.5), 0.0)
	for i in range(enemigos):
		var ang := TAU * float(i) / float(maxi(1, enemigos))
		_arena._crear_bot(-(i + 1), _arena.find_clear_spot(
			Vector3(cos(ang), 0, sin(ang)) * 7.0, 1.0), CharacterDB.get_all_ids()[i % 4])
	Arena.set_bots_active(true)
	for _i in range(30): await get_tree().physics_frame

	var antes := p.health.current
	var t := 0.0
	while t < 25.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	var perdido: float = antes - p.health.current
	p.health.set_max(100.0)
	p.health.revive_full()
	return perdido / t
