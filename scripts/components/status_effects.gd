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

## TAMBALEO: el aturdimiento corto que deja cada golpe. Es lo que hace posible un combo.
##
## Sin esto, despues de un golpe el rival podia moverse, dashear o tirar una habilidad en
## el mismo instante, asi que cualquier cadena se cortaba en el primer eslabon: el
## segundo golpe ya no encontraba a nadie. Con el tambaleo, el que recibe queda clavado
## lo justo para que el siguiente golpe —el basico otra vez, o una habilidad— entre.
##
## ES OTRA COSA QUE EL ATURDIMIENTO DE ZA WARUDO, y a proposito no reusa stun_for: el de
## Dio es largo, tiene su efecto de tiempo detenido y cambia como se juega contra el. Este
## dura menos de medio segundo y no se ve como nada mas que un respingo. Y tampoco es
## congelar: Snowgrave no ejecuta a un tambaleado.
##
## Se RENUEVA con cada golpe (maxf, no suma): cada golpe deja al rival clavado TAMBALEO
## segundos a partir de ese golpe.
const TAMBALEO: float = 0.40
var _tamb_left: float = 0.0

## LA SALIDA DEL COMBO: despues de COMBO_MAXIMO segundos seguidos tambaleando, el que
## recibe se suelta y queda INMUNE_TRAS_COMBO sin poder ser tambaleado.
##
## Sin esto habia trabas infinitas, medidas (tests/combos_diag.tscn): el basico de Sonic
## sale cada 0.32 s —mas rapido que el tambaleo— y el de Dio cada 0.40, justo lo que dura,
## asi que spameando el basico dejaban al otro sin moverse para siempre. Y en los modos
## contra varios, los bots se turnaban para pegar y el jugador no salia nunca: Rey de la
## colina bajo de 60% a 27% de victorias y la torre de jefes a cero.
##
## El combo sigue igual —un segundo y medio de cadena da para basico, habilidades y otra
## vez basico— pero tiene final, y el que lo recibe tiene un segundo para escaparse.
const COMBO_MAXIMO: float = 1.5
const INMUNE_TRAS_COMBO: float = 1.0
## Cuanto lleva tambaleando sin cortarse.
var _combo_acumulado: float = 0.0
var _inmune_left: float = 0.0

## VULNERABLE: recibe mas daño por un rato.
##
## Lo deja "Here I Come, San Francisco" al terminar la carga. Es el precio de tirarse de
## cabeza: sin el, la carga seria un dash con daño y ninguna contra.
##
## Va aparte del multiplicador de congelado y se MULTIPLICAN entre si: congelar a
## alguien que acaba de cargar tiene que ser el castigo que es.
## IMPULSO: lo contrario de todo lo de arriba.
##
## Los efectos que habia eran todos hacia abajo —frenar, congelar, hacer mas fragil— y no
## servian para un buff ni poniendolos al reves: apply_slow recorta el resultado a 1.0 asi
## que no puede acelerar, y apply_vulnerable rechaza cualquier multiplicador menor a 1 asi
## que no puede proteger. Hizo falta al agregar Super Sonic, que es canonicamente mas
## rapido, mas fuerte y "casi invulnerable".
##
## Es UNO solo para las tres cosas y no tres efectos sueltos porque siempre vienen juntos:
## una transformacion no te hace mas rapido en un momento y mas resistente en otro.
var _imp_vel: float = 1.0
var _imp_resist: float = 1.0
var _imp_daño: float = 1.0
var _imp_left: float = 0.0
var _vuln_mult: float = 1.0
var _vuln_left: float = 0.0


func _process(delta: float) -> void:
	if _freeze_left > 0.0:
		_freeze_left = maxf(0.0, _freeze_left - delta)
		if is_zero_approx(_freeze_left):
			unfroze.emit()

	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		if is_zero_approx(_stun_left):
			unstunned.emit()

	if _tamb_left > 0.0:
		_tamb_left = maxf(0.0, _tamb_left - delta)
		_combo_acumulado += delta
		# Solo el servidor suelta: es el que decide el estado, y se lo avisa a todos.
		if _is_server() and _combo_acumulado >= COMBO_MAXIMO:
			_tamb_left = 0.0
			_combo_acumulado = 0.0
			_inmune_left = INMUNE_TRAS_COMBO
			_avisar_tambaleo()
	else:
		# Se corto la cadena antes del tope: el proximo combo empieza de cero.
		_combo_acumulado = 0.0
	if _inmune_left > 0.0:
		_inmune_left = maxf(0.0, _inmune_left - delta)

	if _slow_left > 0.0:
		_slow_left = maxf(0.0, _slow_left - delta)
		if is_zero_approx(_slow_left):
			_slow_percent = 0.0

	if _vuln_left > 0.0:
		_vuln_left = maxf(0.0, _vuln_left - delta)
	if _imp_left > 0.0:
		_imp_left = maxf(0.0, _imp_left - delta)
		if is_zero_approx(_imp_left):
			# Se resetean los tres al vencer. Dejarlos puestos con el reloj en cero
			# funcionaria igual —todo consulta _imp_left— pero el proximo impulso haria
			# maxf contra los valores viejos y heredaria el mejor de los dos.
			_imp_vel = 1.0
			_imp_resist = 1.0
			_imp_daño = 1.0
		if is_zero_approx(_vuln_left):
			_vuln_mult = 1.0

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


## SOLO SERVIDOR. El tambaleo de un golpe. Ver TAMBALEO.
func tambalear(duracion: float) -> void:
	if not _is_server() or duracion <= 0.0:
		return
	# Recien salido de un combo: el segundo de escape no se puede cortar.
	if _inmune_left > 0.0:
		return
	_tamb_left = maxf(_tamb_left, duracion)
	_avisar_tambaleo()


## EL TAMBALEO VIAJA A TODOS, y le importa sobre todo al que lo recibe: el movimiento lo
## decide el cliente de cada uno, asi que si su maquina no se entera de que esta
## tambaleando, sigue caminando y el combo se le escapa igual que antes.
##
## EN UN MENSAJE PROPIO, y no sumado a _push_state. Un RPC con un argumento de mas es
## incompatible con la version anterior del juego: el servidor se actualiza solo con cada
## push y la pagina de itch no, y un cliente viejo que recibe _push_state con doce
## argumentos cuando espera once lo descarta entero — dejaria de ver congelados y
## aturdidos, no solo el tambaleo. Separado, al cliente viejo solo le falta lo nuevo.
func _avisar_tambaleo() -> void:
	Net.rpc_ready(self, &"_push_tambaleo", [_tamb_left])


@rpc("authority", "call_remote", "reliable")
func _push_tambaleo(tamb_left: float) -> void:
	_tamb_left = tamb_left


## Recien salido de un combo largo, y por eso sin poder ser tambaleado.
func esta_inmune_al_tambaleo() -> bool:
	return _inmune_left > 0.0


func esta_tambaleando() -> bool:
	return _tamb_left > 0.0


func get_tambaleo_remaining() -> float:
	return _tamb_left


## SOLO SERVIDOR. Se queda con el slow mas fuerte que este activo.
func apply_slow(percent: float, duration: float) -> void:
	if not _is_server() or percent <= 0.0 or duration <= 0.0:
		return
	if percent >= _slow_percent:
		_slow_percent = clampf(percent, 0.0, 0.9)
	_slow_left = maxf(_slow_left, duration)
	_broadcast()


## SOLO SERVIDOR. Deja al objetivo recibiendo mas daño por un rato.
func apply_vulnerable(mult: float, duration: float) -> void:
	if not _is_server() or mult <= 1.0 or duration <= 0.0:
		return
	_vuln_mult = maxf(_vuln_mult, mult)
	_vuln_left = maxf(_vuln_left, duration)
	_broadcast()


## SOLO SERVIDOR. Un impulso temporal: mas veloz, mas resistente y pegando mas fuerte.
func impulsar(vel: float, resist: float, daño: float, duracion: float) -> void:
	if not _is_server() or duracion <= 0.0:
		return
	_imp_vel = maxf(_imp_vel, vel)
	_imp_resist = minf(_imp_resist, resist)
	_imp_daño = maxf(_imp_daño, daño)
	_imp_left = maxf(_imp_left, duracion)
	_broadcast()


func esta_impulsado() -> bool:
	return _imp_left > 0.0


## Cuanto MULTIPLICA el daño que este jugador reparte. Lo lee CombatUtils al pegar.
func get_damage_dealt_multiplier() -> float:
	return _imp_daño if _imp_left > 0.0 else 1.0


func is_vulnerable() -> bool:
	return _vuln_left > 0.0


func is_frozen() -> bool:
	return _freeze_left > 0.0


func is_stunned() -> bool:
	return _stun_left > 0.0


## Congelado, aturdido o tambaleando = no podes moverte, atacar, dashear ni tirar
## habilidades.
func can_act() -> bool:
	return not is_frozen() and not is_stunned() and not esta_tambaleando()


func get_move_speed_multiplier() -> float:
	if is_frozen() or is_stunned() or esta_tambaleando():
		return 0.0
	# EL TECHO SUBE A 2.5, pero el frenado se sigue aplicando encima del impulso: estar
	# acelerado no te vuelve inmune a que te frenen, solo hace que te frenen desde mas
	# arriba. Si el impulso ignorara el frenado, Noelle perderia su unica herramienta
	# contra alguien que se le escapa.
	var base := clampf(1.0 - _slow_percent, 0.1, 1.0)
	if _imp_left > 0.0:
		return clampf(base * _imp_vel, 0.1, 2.5)
	return base


func get_damage_taken_multiplier() -> float:
	var mult := FROZEN_DAMAGE_TAKEN_MULT if is_frozen() else 1.0
	if _imp_left > 0.0:
		mult *= _imp_resist
	return mult * _vuln_mult


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
	_tamb_left = 0.0
	_combo_acumulado = 0.0
	_inmune_left = 0.0
	_vuln_mult = 1.0
	_vuln_left = 0.0
	chill_changed.emit(0)
	if was_frozen:
		unfroze.emit()
	if was_stunned:
		unstunned.emit()
	_broadcast()
	# El tambaleo va aparte (ver _avisar_tambaleo): sin esto, un cliente que reaparece en
	# medio de un combo seguiria clavado lo que le quedaba.
	_avisar_tambaleo()
	_imp_vel = 1.0
	_imp_resist = 1.0
	_imp_daño = 1.0
	_imp_left = 0.0


func _is_server() -> bool:
	return multiplayer.multiplayer_peer == null or multiplayer.is_server()


func _broadcast() -> void:
	Net.rpc_ready(self, &"_push_state",
		[chill_stacks, _freeze_left, _slow_percent, _slow_left, _stun_left, _vuln_mult, _vuln_left,
		_imp_vel, _imp_resist, _imp_daño, _imp_left])


@rpc("authority", "call_remote", "reliable")
func _push_state(stacks: int, freeze_left: float, slow_percent: float, slow_left: float,
		stun_left: float, vuln_mult: float, vuln_left: float,
		imp_vel: float, imp_resist: float, imp_daño: float, imp_left: float) -> void:
	var was_frozen := is_frozen()
	var was_stunned := is_stunned()
	var old_stacks := chill_stacks
	chill_stacks = stacks
	_freeze_left = freeze_left
	_slow_percent = slow_percent
	_slow_left = slow_left
	_stun_left = stun_left
	_vuln_mult = vuln_mult
	_vuln_left = vuln_left
	_imp_vel = imp_vel
	_imp_resist = imp_resist
	_imp_daño = imp_daño
	_imp_left = imp_left
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
