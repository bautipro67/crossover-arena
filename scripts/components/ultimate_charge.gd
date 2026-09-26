class_name UltimateCharge
extends Node
## Carga del ultimate. Se llena PEGANDO, no esperando.
##
## POR QUE EXISTE APARTE DE LA STAMINA: el ultimate cuesta la barra entera (100), pero
## la stamina se regenera sola. Si el costo fuera la unica condicion, tendrias ultimate
## cada siete segundos por no hacer nada. La carga es la condicion de verdad; el costo
## en stamina es lo que hace que tirarlo te deje seco y comprometido.
##
## Para tirar un ultimate necesitas LAS DOS COSAS:
##   - carga al 100% (te la ganaste peleando)
##   - stamina al 100% (no gastaste en habilidades justo antes)
##
## AUTORIDAD: el servidor lleva la cuenta y la empuja al dueño para el HUD.

signal changed(current: float, max_value: float)
signal became_ready()

const MAX_CHARGE: float = 100.0

## Carga por punto de daño infligido. Con 0.45 hacen falta ~222 de daño para llenarlo.
##
## Antes era 0.8 (125 de daño) y el ultimate salia casi una vez por vida. A 0.45 hay que
## ganarselo: son dos o tres intercambios completos, no uno.
@export var charge_per_damage: float = 0.45
## Bonus al matar: redondea el ciclo, pero ya no regala medio medidor.
@export var charge_on_kill: float = 20.0

var current: float = 0.0
var owner_peer_id: int = 1

var _was_ready: bool = false


## NO hay carga pasiva. El medidor sube UNICAMENTE pegando: es la condicion que hace
## que el ultimate se sienta ganado en vez de esperado. Si te quedas sin ideas, el golpe
## basico es gratis, asi que siempre hay una via de cargarlo.
##
## SOLO SERVIDOR. Lo llama CombatUtils cuando este jugador le pega a alguien.
func add_from_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	# En el modo caos, tres veces mas rapido: el ultimate sale cada rato.
	_add(amount * charge_per_damage * Modos.ritmo_carga(), true)


## SOLO SERVIDOR.
func add_kill_bonus() -> void:
	_add(charge_on_kill, true)


func is_ready() -> bool:
	return current >= MAX_CHARGE - 0.01


## SOLO SERVIDOR. Gasta la carga. Devuelve false si todavia no estaba lista.
func consume() -> bool:
	if not _is_server() or not is_ready():
		return false
	current = 0.0
	_was_ready = false
	changed.emit(current, MAX_CHARGE)
	_push_owner()
	return true


func get_ratio() -> float:
	return clampf(current / MAX_CHARGE, 0.0, 1.0)


## Al morir NO se pierde la carga.
##
## Es a proposito: la carga se gana peleando y borrarla al morir castiga dos veces al
## que va perdiendo. Dejarla es lo que le da al que pierde una herramienta para dar
## vuelta la pelea, que es justamente para lo que sirve un ultimate.
func reset() -> void:
	if not _is_server():
		return
	current = 0.0
	_was_ready = false
	changed.emit(current, MAX_CHARGE)
	_push_owner()


func _add(amount: float, push: bool) -> void:
	if not _is_server() or amount <= 0.0:
		return
	var before := current
	current = minf(MAX_CHARGE, current + amount)
	if is_equal_approx(before, current):
		return
	changed.emit(current, MAX_CHARGE)
	if is_ready() and not _was_ready:
		_was_ready = true
		became_ready.emit()
		_notify_ready()
	if push:
		_push_owner()


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _push_owner() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if owner_peer_id == 1:
		return
	Net.rpc_ready_id(self, owner_peer_id, &"_push_state", [current])


func _notify_ready() -> void:
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if owner_peer_id == 1:
		return
	Net.rpc_ready_id(self, owner_peer_id, &"_net_ready", [])


@rpc("authority", "call_remote", "unreliable_ordered")
func _push_state(value: float) -> void:
	current = value
	changed.emit(current, MAX_CHARGE)


@rpc("authority", "call_remote", "reliable")
func _net_ready() -> void:
	if not _was_ready:
		_was_ready = true
		became_ready.emit()
