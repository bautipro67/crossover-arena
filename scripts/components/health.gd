class_name Health
extends Node
## Vida de una entidad.
## AUTORIDAD: solo el servidor (peer 1) llama apply_damage()/heal(). El resultado se
## replica a todos con _push_state(). Los clientes nunca deciden daño.

signal changed(current: float, max_value: float)
signal damaged(amount: float, source_id: int)
signal died(killer_id: int)

@export var max_health: float = 100.0

var current: float = 0.0
var is_dead: bool = false


func _ready() -> void:
	current = max_health


## Reconfigura la vida maxima (lo llama Player.setup_character con los datos del personaje).
func set_max(value: float) -> void:
	max_health = maxf(1.0, value)
	current = max_health
	is_dead = false
	changed.emit(current, max_health)


## SOLO SERVIDOR. El daño que llega aca ya viene multiplicado por los status del objetivo.
func apply_damage(amount: float, source_id: int) -> void:
	if not _is_server() or is_dead or amount <= 0.0:
		return
	current = clampf(current - amount, 0.0, max_health)
	damaged.emit(amount, source_id)
	changed.emit(current, max_health)
	if current <= 0.0:
		is_dead = true
		_broadcast(source_id)
		died.emit(source_id)
	else:
		_broadcast(source_id)


## SOLO SERVIDOR.
func heal(amount: float) -> void:
	if not _is_server() or is_dead or amount <= 0.0:
		return
	current = clampf(current + amount, 0.0, max_health)
	changed.emit(current, max_health)
	_broadcast(0)


## SOLO SERVIDOR. Respawn.
func revive_full() -> void:
	if not _is_server():
		return
	is_dead = false
	current = max_health
	changed.emit(current, max_health)
	_broadcast(0)


func get_ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0


func _broadcast(killer_id: int) -> void:
	Net.rpc_ready(self, &"_push_state", [current, max_health, is_dead, killer_id])


func _is_server() -> bool:
	# Sin peer = modo offline: nos tratamos como servidor para que todo funcione igual.
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


@rpc("authority", "call_remote", "reliable")
func _push_state(value: float, max_value: float, dead: bool, killer_id: int) -> void:
	var was_dead := is_dead
	current = value
	max_health = max_value
	is_dead = dead
	changed.emit(current, max_health)
	if is_dead and not was_dead:
		died.emit(killer_id)
