class_name StatusEffects
extends Node
## Escarcha, congelacion y ralentizaciones.
##
## Este es el corazon del kit de Noelle y la razon por la que Snowgrave se siente como
## en Deltarune: no es un nuke generico, es un remate. Le pegas escarcha al rival hasta
## congelarlo y recien ahi Snowgrave ejecuta.
##
## AUTORIDAD: el servidor aplica los efectos y los replica a todos (los clientes necesitan
## el estado para dibujar el hielo encima del jugador y para bloquear su propio input).

signal chill_changed(stacks: int)
signal froze()
signal unfroze()
signal stunned()
signal unstunned()

## Stacks necesarios para congelar.
const MAX_CHILL: int = 5
## Cada cuanto se pierde un stack si no te siguen pegando escarcha.
const CHILL_DECAY_INTERVAL: float = 2.0
const FREEZE_DURATION: float = 2.5
## Un objetivo congelado recibe 25% mas de daño de cualquier fuente.
const FROZEN_DAMAGE_TAKEN_MULT: float = 1.25

var chill_stacks: int = 0

var _freeze_left: float = 0.0
var _decay_left: float = CHILL_DECAY_INTERVAL
var _slow_percent: float = 0.0
var _slow_left: float = 0.0

## Aturdimiento. Es distinto de congelado a proposito: ZA WARUDO te deja quieto pero
## NO te marca como congelado, asi que no te vuelve ejecutable por Snowgrave.
## Si fuesen lo mismo, un Dio y una Noelle en el mismo equipo tendrian un combo
## de un solo boton que mata a todo el mundo.
var _stun_left: float = 0.0


func _process(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left = maxf(0.0, _freeze_left - delta)
		if is_zero_approx(_freeze_left):
			unfroze.emit()

	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		if is_zero_approx(_stun_left):
			unstunned.emit()

	if _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - delta)
		if is_zero_approx(_slow_left):
			_slow_percent = 0.0

	if chill_stacks > 0:
		_decay_left -= delta
		if _decay_left <= 0.0:
			_decay_left = CHILL_DECAY_INTERVAL
			chill_stacks = maxi(0, chill_stacks - 1)
			chill_changed.emit(chill_stacks)
			_broadcast()


## SOLO SERVIDOR. Suma escarcha; al llegar a MAX_CHILL congela y resetea los stacks.
func add_chill(stacks: int) -> void:
	if not _is_server() or stacks <= 0 or is_frozen():
		return
	chill_stacks += stacks
	_decay_left = CHILL_DECAY_INTERVAL
	if chill_stacks >= MAX_CHILL:
		chill_stacks = 0
		chill_changed.emit(chill_stacks)
		freeze_for(FREEZE_DURATION)
		return
	chill_changed.emit(chill_stacks)
	_broadcast()


## SOLO SERVIDOR.
func freeze_for(duration: float) -> void:
	if not _is_server() or duration <= 0.0:
		return
	var was_frozen := is_frozen()
	_freeze_left = maxf(_freeze_left, duration)
	if not was_frozen:
		froze.emit()
	_broadcast()


## SOLO SERVIDOR. Aturde sin congelar (ZA WARUDO, golpes que trabanan, etc).
func stun_for(duration: float) -> void:
	if not _is_server() or duration <= 0.0:
		return
	var was_stunned := is_stunned()
	_stun_left = maxf(_stun_left, duration)
	if not was_stunned:
		stunned.emit()
	_broadcast()


## SOLO SERVIDOR. Se queda con el slow mas fuerte que este activo.
func apply_slow(percent: float, duration: float) -> void:
	if not _is_server() or percent <= 0.0 or duration <= 0.0:
		return
	if percent >= _slow_percent:
		_slow_percent = clampf(percent, 0.0, 0.9)
	_slow_left = maxf(_slow_left, duration)
	_broadcast()


func is_frozen() -> bool:
	return _freeze_left > 0.0


func is_stunned() -> bool:
	return _stun_left > 0.0


## Congelado o aturdido = no podes moverte, atacar, dashear ni tirar habilidades.
func can_act() -> bool:
	return not is_frozen() and not is_stunned()


func get_move_speed_multiplier() -> float:
	if is_frozen() or is_stunned():
		return 0.0
	return clampf(1.0 - _slow_percent, 0.1, 1.0)


func get_damage_taken_multiplier() -> float:
	return FROZEN_DAMAGE_TAKEN_MULT if is_frozen() else 1.0


func get_freeze_remaining() -> float:
	return _freeze_left


func get_stun_remaining() -> float:
	return _stun_left


## SOLO SERVIDOR. Limpia todo (respawn).
func clear_all() -> void:
	var was_frozen := is_frozen()
	var was_stunned := is_stunned()
	chill_stacks = 0
	_freeze_left = 0.0
	_slow_percent = 0.0
	_slow_left = 0.0
	_stun_left = 0.0
	chill_changed.emit(0)
	if was_frozen:
		unfroze.emit()
	if was_stunned:
		unstunned.emit()
	_broadcast()


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _broadcast() -> void:
	Net.rpc_ready(self, &"_push_state", [chill_stacks, _freeze_left, _slow_percent, _slow_left, _stun_left])


@rpc("authority", "call_remote", "reliable")
func _push_state(stacks: int, freeze_left: float, slow_percent: float, slow_left: float, stun_left: float) -> void:
	var was_frozen := is_frozen()
	var was_stunned := is_stunned()
	var old_stacks := chill_stacks
	chill_stacks = stacks
	_freeze_left = freeze_left
	_slow_percent = slow_percent
	_slow_left = slow_left
	_stun_left = stun_left
	if old_stacks != chill_stacks:
		chill_changed.emit(chill_stacks)
	if is_frozen() and not was_frozen:
		froze.emit()
	elif not is_frozen() and was_frozen:
		unfroze.emit()
	if is_stunned() and not was_stunned:
		stunned.emit()
	elif not is_stunned() and was_stunned:
		unstunned.emit()
