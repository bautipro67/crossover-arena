class_name AbilityCaster
extends Node
## Motor de habilidades. Va como hijo del Player con el nombre exacto "AbilityCaster".
##
## FLUJO (server-authoritative):
##   1. El cliente dueño llama request_use(index).
##   2. Valida local SOLO para dar feedback instantaneo (barra roja, sonido de "no puedo")
##      y predice el gasto de stamina para que la barra se mueva sin esperar la red.
##   3. Manda la peticion al servidor.
##   4. El servidor REVALIDA todo de cero. El cliente no decide nada.
##   5. El servidor gasta stamina, arranca cooldown, ejecuta y avisa a todos.
##
## Si el servidor rechaza, le devuelve el motivo al cliente y se revierte la prediccion.

signal ability_used(index: int)
signal cooldown_started(index: int, duration: float)
signal channel_started(index: int, duration: float)
signal channel_finished(index: int)
signal channel_cancelled(index: int)
signal ability_failed(index: int, reason: String)

## Cuanta stamina se devuelve si te interrumpen el canalizado.
const CHANNEL_REFUND_RATIO: float = 0.5

var abilities: Array[Ability] = []
var is_channeling: bool = false

## Peer dueño de este jugador. Lo setea Player.
var owner_peer_id: int = 1

var _cooldowns: Array[float] = []
var _channel_index: int = -1
var _channel_left: float = 0.0
var _channel_total: float = 0.0
var _channel_origin: Vector3 = Vector3.ZERO
var _channel_dir: Vector3 = Vector3.FORWARD

var _caster: Node = null
var _stamina: Stamina = null
var _ultimate: UltimateCharge = null
var _status: StatusEffects = null
var _health: Health = null


func _ready() -> void:
	_caster = get_parent()
	_stamina = _caster.get_node_or_null("Stamina") as Stamina
	_ultimate = _caster.get_node_or_null("UltimateCharge") as UltimateCharge
	_status = _caster.get_node_or_null("StatusEffects") as StatusEffects
	_health = _caster.get_node_or_null("Health") as Health
	if _health != null:
		_health.died.connect(_on_owner_died)
	if _status != null:
		_status.froze.connect(_on_owner_frozen)


func setup(list: Array[Ability]) -> void:
	abilities = list
	_cooldowns.clear()
	for _a: Ability in abilities:
		_cooldowns.append(0.0)


func _process(delta: float) -> void:
	for i: int in range(_cooldowns.size()):
		if _cooldowns[i] > 0.0:
			_cooldowns[i] = maxf(0.0, _cooldowns[i] - delta)

	if is_channeling:
		_channel_left = maxf(0.0, _channel_left - delta)
		# Solo el servidor decide cuando termina realmente el canalizado.
		if _is_server() and is_zero_approx(_channel_left):
			_finish_channel()


# ---------------------------------------------------------------- API publica

## La llama el cliente dueño del jugador (o el host para su propio jugador).
func request_use(index: int) -> void:
	if index < 0 or index >= abilities.size():
		return
	var ability := abilities[index]

	# Validacion local: solo feedback, no es la que manda.
	var reason := _local_reject_reason(index, ability)
	if reason != "":
		ability_failed.emit(index, reason)
		return

	var origin: Vector3 = _caster.call("get_aim_origin")
	var dir: Vector3 = _caster.call("get_aim_direction")

	# Prediccion: la barra y el cooldown se mueven ya, sin esperar al servidor.
	if not _is_server():
		if _stamina != null and ability.stamina_cost > 0.0:
			_stamina.predict_spend(ability.stamina_cost)
		_start_cooldown_local(index, ability.cooldown)
		if ability.channel_time > 0.0:
			_begin_channel_local(index, ability.channel_time)

	if _is_server():
		_srv_request_use(index, origin, dir)
	else:
		_srv_request_use.rpc_id(1, index, origin, dir)


## Acorta el cooldown de una habilidad. Lo usa el encadenado del Homing Attack.
##
## SOLO ACORTA, nunca alarga: `maxf(0.0, min(...))` evita que un llamador distraido use
## esto para castigar a alguien poniendole un cooldown mas largo del que le toca. Es una
## recompensa por acertar, y el unico sentido en el que puede mover el numero es a favor.
func acortar_cooldown(index: int, restante: float) -> void:
	if index < 0 or index >= _cooldowns.size():
		return
	_cooldowns[index] = maxf(0.0, minf(_cooldowns[index], restante))


func get_cooldown_remaining(index: int) -> float:
	if index < 0 or index >= _cooldowns.size():
		return 0.0
	return _cooldowns[index]


func is_on_cooldown(index: int) -> bool:
	# Panel de practica: mirar una animacion veinte veces seguidas es imposible si hay
	# que esperar ocho segundos entre una y otra.
	if Practica.sin_cooldowns:
		return false
	return get_cooldown_remaining(index) > 0.0


func get_ability(index: int) -> Ability:
	if index < 0 or index >= abilities.size():
		return null
	return abilities[index]


func get_channel_ratio() -> float:
	if not is_channeling or _channel_total <= 0.0:
		return 0.0
	return 1.0 - (_channel_left / _channel_total)


func get_channel_index() -> int:
	return _channel_index


## Cancela el canalizado en curso. SOLO SERVIDOR (los clientes lo reflejan por rpc).
func cancel_channel() -> void:
	if not is_channeling or not _is_server():
		return
	var index := _channel_index
	var ability := get_ability(index)
	if ability != null and _stamina != null and ability.stamina_cost > 0.0:
		_stamina.refund(ability.stamina_cost * CHANNEL_REFUND_RATIO)
	_clear_channel()
	channel_cancelled.emit(index)
	Net.rpc_ready(self, &"_net_end_channel", [index, true])


## Limpia todo al morir o respawnear.
func reset_state() -> void:
	for i: int in range(_cooldowns.size()):
		_cooldowns[i] = 0.0
	if is_channeling:
		var index := _channel_index
		_clear_channel()
		channel_cancelled.emit(index)


# ------------------------------------------------------------------ Servidor

@rpc("any_peer", "call_remote", "reliable")
func _srv_request_use(index: int, origin: Vector3, dir: Vector3) -> void:
	if not _is_server():
		return

	# Quien pidio esto de verdad. Si viene por rpc, el sender id; si lo llamamos
	# directo (somos el host usando nuestro propio jugador), somos nosotros.
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = 1 if multiplayer.multiplayer_peer == null else multiplayer.get_unique_id()

	# Antitrampa basico: solo podes usar las habilidades de TU jugador.
	if sender != owner_peer_id:
		return

	if index < 0 or index >= abilities.size():
		return
	var ability := abilities[index]

	var reason := _local_reject_reason(index, ability)
	if reason != "":
		_reject_to_owner(index, reason)
		return

	# Sanitizamos la direccion que mando el cliente.
	var safe_dir := dir.normalized()
	if safe_dir.is_zero_approx():
		safe_dir = -_caster.global_transform.basis.z

	# La carga se gasta ANTES que la stamina: si esta primera falla queremos salir sin
	# haber tocado nada.
	if ability.requires_charge:
		if _ultimate == null or not _ultimate.consume():
			_reject_to_owner(index, "sin carga")
			return

	if ability.stamina_cost > 0.0:
		if _stamina == null or not _stamina.try_spend(ability.stamina_cost):
			_reject_to_owner(index, "sin stamina")
			return

	_start_cooldown_local(index, ability.cooldown)
	Net.rpc_ready(self, &"_net_cooldown", [index, ability.cooldown])

	if ability.channel_time > 0.0:
		_channel_origin = origin
		_channel_dir = safe_dir
		_begin_channel_local(index, ability.channel_time)
		Net.rpc_ready(self, &"_net_begin_channel", [index, ability.channel_time])
		# Solo el servidor grita: avisar_grito ya lo replica a todos.
		Frases.decir_al_cargar(_caster, ability.id)
	else:
		_fire(index, origin, safe_dir)


func _finish_channel() -> void:
	var index := _channel_index
	# Reapuntamos con la mira actual: canalizaste 1.5s, apuntas donde estas mirando ahora.
	var origin := _channel_origin
	var dir := _channel_dir
	if is_instance_valid(_caster):
		origin = _caster.call("get_aim_origin")
		dir = _caster.call("get_aim_direction")
	_clear_channel()
	channel_finished.emit(index)
	Net.rpc_ready(self, &"_net_end_channel", [index, false])
	_fire(index, origin, dir)


func _fire(index: int, origin: Vector3, dir: Vector3) -> void:
	var ability := get_ability(index)
	if ability == null:
		return
	# LA FRASE ANTES QUE EL ATAQUE, no despues.
	#
	# En los dos originales el grito viene primero y el golpe atras: "¡JARONA!" y recien
	# ahi la embestida, "ZA WARUDO" y recien ahi el tiempo parado. Ese orden es el que le
	# da al rival el instante para reaccionar, asi que invertirlo no seria un detalle de
	# presentacion sino sacarle al otro jugador su aviso.
	#
	# Se dispara solo desde aca —el servidor— porque avisar_grito ya replica sola; meterla
	# tambien en el camino cosmetico la diria dos veces en los clientes.
	Frases.decir(_caster, ability.id)
	ability.execute(_caster, origin, dir)
	ability_used.emit(index)
	Net.rpc_ready(self, &"_net_played", [index, origin, dir])


func _reject_to_owner(index: int, reason: String) -> void:
	if multiplayer.multiplayer_peer == null or owner_peer_id == 1:
		ability_failed.emit(index, reason)
		return
	Net.rpc_ready_id(self, owner_peer_id, &"_net_reject", [index, reason])


func _on_owner_died(_killer_id: int) -> void:
	if _is_server():
		cancel_channel()
	reset_state()


func _on_owner_frozen() -> void:
	# Si te congelan mientras canalizas Snowgrave, se cancela y recuperas media stamina.
	if _is_server() and is_channeling:
		cancel_channel()


# --------------------------------------------------------------------- Estado

func _local_reject_reason(index: int, ability: Ability) -> String:
	if ability == null:
		return "habilidad invalida"
	if _health != null and _health.is_dead:
		return "estas muerto"
	if _status != null and not _status.can_act():
		return "congelado"
	if is_channeling:
		return "canalizando"
	if is_on_cooldown(index):
		return "en cooldown"
	if ability.stamina_cost > 0.0 and (_stamina == null or not _stamina.has_enough(ability.stamina_cost)):
		return "sin stamina"
	if ability.requires_charge and (_ultimate == null or not _ultimate.is_ready()):
		return "sin carga"
	if not ability.can_use(_caster):
		return "no disponible"
	return ""


func _start_cooldown_local(index: int, duration: float) -> void:
	if index < 0 or index >= _cooldowns.size():
		return
	_cooldowns[index] = duration
	cooldown_started.emit(index, duration)


func _begin_channel_local(index: int, duration: float) -> void:
	is_channeling = true
	_channel_index = index
	_channel_total = duration
	_channel_left = duration
	if _caster is Node3D:
		Sfx.play_3d(_caster, &"channel", (_caster as Node3D).global_position, -5.0)
	channel_started.emit(index, duration)


func _clear_channel() -> void:
	is_channeling = false
	_channel_index = -1
	_channel_left = 0.0
	_channel_total = 0.0


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


# ------------------------------------------------------------------ Red (bajada)

@rpc("authority", "call_remote", "reliable")
func _net_cooldown(index: int, duration: float) -> void:
	_start_cooldown_local(index, duration)


@rpc("authority", "call_remote", "reliable")
func _net_begin_channel(index: int, duration: float) -> void:
	_begin_channel_local(index, duration)


@rpc("authority", "call_remote", "reliable")
func _net_end_channel(index: int, cancelled: bool) -> void:
	_clear_channel()
	if cancelled:
		channel_cancelled.emit(index)
	else:
		channel_finished.emit(index)


@rpc("authority", "call_remote", "reliable")
func _net_played(index: int, origin: Vector3, dir: Vector3) -> void:
	# En los clientes esto es solo visual: el daño ya lo resolvio el servidor.
	var ability := get_ability(index)
	if ability != null:
		FX.play_ability_cosmetic(_caster, ability.id, origin, dir)
	ability_used.emit(index)


@rpc("authority", "call_remote", "reliable")
func _net_reject(index: int, reason: String) -> void:
	# El servidor dijo que no: revertimos la prediccion.
	if index >= 0 and index < _cooldowns.size():
		_cooldowns[index] = 0.0
	if is_channeling and _channel_index == index:
		_clear_channel()
		channel_cancelled.emit(index)
	ability_failed.emit(index, reason)
