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

## ESCUDO: bolsa de daño que se come los golpes ANTES que la vida.
##
## Va aca y no en StatusEffects porque aca es donde aterriza el daño; ponerlo en otro
## lado obligaria a que apply_damage fuera a preguntarle a un tercero en cada golpe.
##
## Es una bolsa con numero, no un porcentaje de reduccion, porque se lee: ves cuanto
## queda, sabes si te alcanza para aguantar el proximo golpe, y el rival ve que
## revienta. Una reduccion del 40% no la nota nadie.
var shield: float = 0.0
var shield_left: float = 0.0

## Lo emite el servidor cuando el escudo se come un golpe, para el efecto visual.
signal shield_absorbed(amount: float, remaining: float)
signal shield_changed(value: float)


func _ready() -> void:
	current = max_health


func _process(delta: float) -> void:
	if shield_left <= 0.0:
		return
	shield_left = maxf(0.0, shield_left - delta)
	if is_zero_approx(shield_left):
		_set_shield(0.0)


## Reconfigura la vida maxima (lo llama Player.setup_character con los datos del personaje).
func set_max(value: float) -> void:
	max_health = maxf(1.0, value)
	current = max_health
	is_dead = false
	changed.emit(current, max_health)


## SOLO SERVIDOR. Da escudo temporal. Si ya habia, se queda con el mas grande en vez
## de sumarlos: apilar dos Defensas de Hielo no tiene que volverte intocable.
func add_shield(amount: float, duration: float) -> void:
	if not _is_server() or amount <= 0.0 or duration <= 0.0 or is_dead:
		return
	shield_left = maxf(shield_left, duration)
	_set_shield(maxf(shield, amount))


func get_shield() -> float:
	return shield


## SOLO SERVIDOR. El daño que llega aca ya viene multiplicado por los status del objetivo.
func apply_damage(amount: float, source_id: int) -> void:
	if not _is_server() or is_dead or amount <= 0.0:
		return

	# El escudo va PRIMERO y el sobrante pasa a la vida. Que el sobrante pase importa:
	# si el escudo frenara el golpe entero, un escudo de 5 anularia un Snowgrave de 260.
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		amount -= absorbed
		_set_shield(shield - absorbed)
		shield_absorbed.emit(absorbed, shield)
		_notify_absorb(absorbed)
		if amount <= 0.0:
			return

	# Panel de practica: la vida BAJA Y SE VE BAJAR, pero se planta en 1.
	#
	# A proposito no es "no recibe daño": querer practicar sin morir no quiere decir
	# querer practicar sin enterarte de cuanto te estan pegando. Viendo la barra igual
	# aprendes que intercambios te convienen; lo unico que se saca es la interrupcion de
	# tener que esperar el respawn.
	# Solo al jugador, no a los bots: un bot inmortal no se puede matar y el modo
	# practica dejaria de servir para lo mas basico, que es rematar.
	var duenio := get_parent() as Player
	var protegido := Practica.invulnerable and duenio != null and not duenio.is_dummy
	var piso := 1.0 if protegido else 0.0
	current = clampf(current - amount, piso, max_health)
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
	shield_left = 0.0
	_set_shield(0.0)
	changed.emit(current, max_health)
	_broadcast(0)


func _set_shield(value: float) -> void:
	var before := shield
	shield = maxf(0.0, value)
	if is_equal_approx(before, shield):
		return
	if is_zero_approx(shield):
		shield_left = 0.0
	shield_changed.emit(shield)
	if _is_server():
		Net.rpc_ready(self, &"_push_shield", [shield, shield_left])


func _notify_absorb(amount: float) -> void:
	if amount <= 0.0:
		return
	Net.rpc_ready(self, &"_net_absorbed", [amount, shield])


@rpc("authority", "call_remote", "reliable")
func _push_shield(value: float, left: float) -> void:
	shield = value
	shield_left = left
	shield_changed.emit(shield)


@rpc("authority", "call_remote", "reliable")
func _net_absorbed(amount: float, remaining: float) -> void:
	shield_absorbed.emit(amount, remaining)


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
	var antes := current
	current = value
	max_health = max_value
	is_dead = dead
	# Los clientes tambien emiten `damaged`, no solo `changed`.
	#
	# POR QUE IMPORTA: `changed` no dice QUIEN pego. Sin el autor, el que dio el golpe
	# no puede sentirlo — ni temblor de camara ni impacto — y pegar se siente como
	# apretar un boton que cambia un numero en la pantalla del otro.
	if current < antes - 0.01:
		damaged.emit(antes - current, killer_id)
	changed.emit(current, max_health)
	if is_dead and not was_dead:
		died.emit(killer_id)
