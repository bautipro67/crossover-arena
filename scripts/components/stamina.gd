class_name Stamina
extends Node
## Barra de stamina.
##
## ######################################################################
## REGLA CENTRAL DEL JUEGO: la stamina la consumen UNICAMENTE las habilidades.
## Correr (sprint), el golpe basico y el dash NO cuestan stamina NUNCA.
## Si en algun momento agregas un costo a esas acciones, estas rompiendo el diseño.
## ######################################################################
##
## AUTORIDAD: el servidor decide el gasto real. El cliente dueño hace una prediccion
## local (predict_spend) para que la barra reaccione al instante, y el servidor la
## corrige unas decenas de ms despues con _push_state().

signal changed(current: float, max_value: float)
signal depleted()

@export var max_stamina: float = 100.0
## Cuanta stamina se regenera sola por segundo.
##
## Deliberadamente baja: a 8/s tardas 12 segundos en llenar la barra parado. Esperar
## no es una estrategia. La via rapida es la de abajo.
@export var regen_per_second: float = 8.0
## Pausa de regeneracion despues de gastar, para que no sea gratis spamear.
@export var regen_delay: float = 0.8

## Stamina que devuelve cada punto de daño que INFLIGIS.
##
## Este es el corazon de la economia: la regeneracion pasiva es lenta, pero pegar te
## paga. Un Icicle Strike de 11 te devuelve ~4, un Ice Shock de 22 te devuelve ~8. O sea
## que el que pelea recupera y el que se esconde a esperar la barra, no.
##
## Los ultimates NO pagan (ver CombatUtils.deal_damage): un Snowgrave de 260 te
## devolveria la barra entera y se pagaria el siguiente solo.
@export var restore_per_damage: float = 0.35

var current: float = 0.0

## A que peer pertenece este jugador. El servidor le manda las correcciones solo a el.
var owner_peer_id: int = 1

var _regen_block_timer: float = 0.0


func _ready() -> void:
	current = max_stamina


func _process(delta: float) -> void:
	if _regen_block_timer > 0.0:
		_regen_block_timer = maxf(0.0, _regen_block_timer - delta)
		return
	if current >= max_stamina:
		return
	current = minf(max_stamina, current + regen_per_second * delta)
	changed.emit(current, max_stamina)


func set_max(value: float) -> void:
	max_stamina = maxf(1.0, value)
	current = max_stamina
	changed.emit(current, max_stamina)


func has_enough(amount: float) -> bool:
	return current >= amount


## SOLO SERVIDOR. Gasta si alcanza; si no alcanza no gasta nada y devuelve false.
func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current < amount:
		return false
	current -= amount
	_regen_block_timer = regen_delay
	changed.emit(current, max_stamina)
	if is_zero_approx(current):
		depleted.emit()
	_push_owner()
	return true


## Prediccion del lado del cliente dueño: mueve la barra ya, sin esperar al servidor.
func predict_spend(amount: float) -> void:
	if amount <= 0.0:
		return
	current = maxf(0.0, current - amount)
	_regen_block_timer = regen_delay
	changed.emit(current, max_stamina)


## SOLO SERVIDOR. Recompensa por pegar. Lo llama CombatUtils cuando este jugador daña.
##
## OJO: NO toca _regen_block_timer a proposito. La pausa post-gasto existe para que no
## spamees habilidades, no para castigarte por acertar; si el golpe no pagara durante
## esos 0.8s, el recurso se sentiria roto justo despues de castear, que es exactamente
## cuando lo necesitas.
func restore_from_damage(damage: float) -> void:
	if damage <= 0.0 or restore_per_damage <= 0.0:
		return
	var amount := damage * restore_per_damage
	if current >= max_stamina:
		return
	current = minf(max_stamina, current + amount)
	changed.emit(current, max_stamina)
	_push_owner()


## SOLO SERVIDOR. Devuelve stamina (por ejemplo al cancelarse un canalizado).
func refund(amount: float) -> void:
	if amount <= 0.0:
		return
	current = minf(max_stamina, current + amount)
	changed.emit(current, max_stamina)
	_push_owner()


func restore_full() -> void:
	current = max_stamina
	_regen_block_timer = 0.0
	changed.emit(current, max_stamina)
	_push_owner()


func get_ratio() -> float:
	return current / max_stamina if max_stamina > 0.0 else 0.0


func _push_owner() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if not multiplayer.is_server():
		return
	if owner_peer_id == 1:
		return
	Net.rpc_ready_id(self, owner_peer_id, &"_push_state", [current, max_stamina])


@rpc("authority", "call_remote", "unreliable_ordered")
func _push_state(value: float, max_value: float) -> void:
	current = value
	max_stamina = max_value
	changed.emit(current, max_stamina)
